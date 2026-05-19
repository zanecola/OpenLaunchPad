import Foundation
import AppKit
import CryptoKit

/// Fallback data source: scans /Applications alphabetically.
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

        for path in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(atPath: path) else { continue }
            for entry in entries.sorted() {
                let fullPath = (path as NSString).appendingPathComponent(entry)
                if entry.hasSuffix(".app"), let app = appItem(at: fullPath, seenBundleIDs: &seenBundleIDs) {
                    items.append(.app(app))
                } else if let folder = folderItem(at: fullPath, title: entry, seenBundleIDs: &seenBundleIDs) {
                    items.append(.folder(folder))
                }
            }
        }

        // Chunk into pages
        return stride(from: 0, to: items.count, by: itemsPerPage).map { start in
            let end = min(start + itemsPerPage, items.count)
            return Array(items[start..<end])
        }
    }

    private func folderItem(
        at path: String,
        title: String,
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
            title: title,
            apps: apps
        )
    }

    private func appItem(at path: String, seenBundleIDs: inout Set<String>) -> AppItem? {
        guard let bundle = Bundle(path: path), let bundleID = bundle.bundleIdentifier,
              seenBundleIDs.insert(bundleID).inserted else {
            return nil
        }
        let filename = (path as NSString).lastPathComponent
        let name = bundle.infoDictionary?["CFBundleName"] as? String
            ?? (filename as NSString).deletingPathExtension
        return AppItem(
            id: stableUUID(for: "app:\(bundleID)"),
            bundleID: bundleID,
            title: name
        )
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
