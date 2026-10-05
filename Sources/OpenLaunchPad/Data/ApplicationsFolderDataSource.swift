import Foundation
import AppKit
import CryptoKit

/// Fallback data source: scans the Applications folders, sorted by displayed name.
/// Used when the Launchpad DB is absent or unreadable (ADR-2 fallback).
final class ApplicationsFolderDataSource: AppDataSource {
    private let searchPaths: [String]
    private let itemsPerPage: Int

    static var defaultSearchPaths: [String] {
        [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
            "/System/Applications"
        ]
    }

    init(
        searchPaths: [String] = ApplicationsFolderDataSource.defaultSearchPaths,
        itemsPerPage: Int = 35  // 5×7 default grid
    ) {
        self.searchPaths = searchPaths
        self.itemsPerPage = itemsPerPage
    }

    func loadPages() throws -> [[LaunchpadItem]] {
        let fm = FileManager.default
        var items: [LaunchpadItem] = []
        var seenBundleIDs = Set<String>()

        // Scan order only decides which copy of a duplicate bundle ID wins.
        for path in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(atPath: path) else { continue }
            for entry in entries.sorted() {
                let fullPath = (path as NSString).appendingPathComponent(entry)
                if entry.hasSuffix(".app"), let app = appItem(at: fullPath, seenBundleIDs: &seenBundleIDs) {
                    items.append(.app(app))
                } else if let folder = folderItem(at: fullPath, seenBundleIDs: &seenBundleIDs) {
                    items.append(.folder(folder))
                }
            }
        }
        items.sort { Self.isOrderedBefore($0.title, $1.title) }

        // Chunk into pages
        return stride(from: 0, to: items.count, by: itemsPerPage).map { start in
            let end = min(start + itemsPerPage, items.count)
            return Array(items[start..<end])
        }
    }

    private func folderItem(
        at path: String,
        seenBundleIDs: inout Set<String>
    ) -> FolderItem? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue,
              let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return nil
        }

        let apps = entries.sorted().compactMap { entry -> AppItem? in
            guard entry.hasSuffix(".app") else { return nil }
            let appPath = (path as NSString).appendingPathComponent(entry)
            return appItem(at: appPath, seenBundleIDs: &seenBundleIDs)
        }
        guard !apps.isEmpty else { return nil }

        return FolderItem(
            id: stableUUID(for: "folder:\(path)"),
            // displayName drops ".localized" and localizes system folders such as Utilities.
            title: FileManager.default.displayName(atPath: path),
            apps: apps.sorted { Self.isOrderedBefore($0.title, $1.title) }
        )
    }

    private func appItem(at path: String, seenBundleIDs: inout Set<String>) -> AppItem? {
        // Read Info.plist directly: Bundle(path:) caches per path for the process lifetime,
        // so an app scanned mid-install would stay hidden after the install finished.
        let url = URL(fileURLWithPath: path) as CFURL
        guard let info = CFBundleCopyInfoDictionaryInDirectory(url) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String,
              seenBundleIDs.insert(bundleID).inserted else {
            return nil
        }
        // Finder's name (localized, e.g. 计算器), not the internal CFBundleName ("Code").
        // displayName keeps ".app" when the extension is shown.
        var title = FileManager.default.displayName(atPath: path)
        if title.hasSuffix(".app") { title.removeLast(4) }
        let fileStem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        var aliases: [String] = []
        for alias in [info["CFBundleName"] as? String, fileStem].compactMap({ $0 })
        where alias != title && !aliases.contains(alias) {
            aliases.append(alias)
        }
        return AppItem(
            id: stableUUID(for: "app:\(bundleID)"),
            bundleID: bundleID,
            title: title,
            aliases: aliases
        )
    }

    private static func isOrderedBefore(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func stableUUID(for value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
