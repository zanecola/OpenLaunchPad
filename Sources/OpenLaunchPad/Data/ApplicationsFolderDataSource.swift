import Foundation
import AppKit
import CryptoKit

/// Fallback data source: scans the Applications folders, sorted by displayed name.
/// Used when the Launchpad DB is absent or unreadable (ADR-2 fallback).
final class ApplicationsFolderDataSource: AppDataSource {
    private let searchPaths: [String]
    private let itemsPerPage: Int
    private let preferredURL: (String) -> URL?

    static var defaultSearchPaths: [String] {
        [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
            "/System/Applications"
        ]
    }

    /// `preferredURL` is LaunchServices' preferred copy of a bundle ID, asked only for duplicates.
    init(
        searchPaths: [String] = ApplicationsFolderDataSource.defaultSearchPaths,
        itemsPerPage: Int = 35,  // 5×7 default grid
        preferredURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    ) {
        self.searchPaths = searchPaths
        self.itemsPerPage = itemsPerPage
        self.preferredURL = preferredURL
    }

    func loadPages() throws -> [[LaunchpadItem]] {
        let fm = FileManager.default
        var entries: [ScannedEntry] = []
        for path in searchPaths {
            guard let names = try? fm.contentsOfDirectory(atPath: path) else { continue }
            for name in names.sorted() {
                let fullPath = (path as NSString).appendingPathComponent(name)
                if name.hasSuffix(".app") {
                    if let app = appItem(at: fullPath) {
                        entries.append(ScannedEntry(directory: nil, apps: [app]))
                    }
                } else if let apps = appsInDirectory(at: fullPath) {
                    entries.append(ScannedEntry(directory: fullPath, apps: apps))
                }
            }
        }

        let chosenPaths = chosenCopyPaths(among: entries.flatMap(\.apps))
        var items = entries.compactMap { item(for: $0, chosenPaths: chosenPaths) }
        items.sort { Self.isOrderedBefore($0.title, $1.title) }

        // Chunk into pages
        return stride(from: 0, to: items.count, by: itemsPerPage).map { start in
            let end = min(start + itemsPerPage, items.count)
            return Array(items[start..<end])
        }
    }

    /// A top-level app, or a directory's apps, before duplicate bundle IDs are resolved.
    private struct ScannedEntry {
        let directory: String?
        let apps: [AppItem]
    }

    /// The copy each bundle ID shows, launches and uninstalls. For duplicates that is the copy
    /// LaunchServices prefers, which `open -b` would launch, when the scan found it; otherwise
    /// the highest CFBundleVersion, then the first in search-path order.
    private func chosenCopyPaths(among apps: [AppItem]) -> [String: String] {
        Dictionary(grouping: apps, by: \.bundleID).compactMapValues { copies in
            guard copies.count > 1 else { return copies[0].bundleURL?.path }
            let preferredPath = preferredURL(copies[0].bundleID)?.resolvingSymlinksInPath().path
            let chosen = copies.first { $0.bundleURL?.resolvingSymlinksInPath().path == preferredPath }
                ?? copies.max { lhs, rhs in
                    (lhs.bundleVersion ?? "").compare(rhs.bundleVersion ?? "", options: .numeric) == .orderedAscending
                }
            return chosen?.bundleURL?.path
        }
    }

    /// A directory of apps becomes a folder; a lone app is shown at top level,
    /// because a one-app folder is one the app cannot be dragged out of.
    private func item(for entry: ScannedEntry, chosenPaths: [String: String]) -> LaunchpadItem? {
        let apps = entry.apps.filter { chosenPaths[$0.bundleID] == $0.bundleURL?.path }
        guard let directory = entry.directory, apps.count > 1 else {
            return apps.first.map { .app($0) }
        }
        return .folder(FolderItem(
            id: stableUUID(for: "folder:\(directory)"),
            // displayName drops ".localized" and localizes system folders such as Utilities.
            title: FileManager.default.displayName(atPath: directory),
            apps: apps.sorted { Self.isOrderedBefore($0.title, $1.title) },
            directoryName: (directory as NSString).lastPathComponent
        ))
    }

    private func appsInDirectory(at path: String) -> [AppItem]? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue,
              let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return nil
        }
        return names.sorted().compactMap { name in
            name.hasSuffix(".app") ? appItem(at: (path as NSString).appendingPathComponent(name)) : nil
        }
    }

    private func appItem(at path: String) -> AppItem? {
        // Read Info.plist directly: Bundle(path:) caches per path for the process lifetime,
        // so an app scanned mid-install would stay hidden after the install finished.
        let bundleURL = URL(fileURLWithPath: path, isDirectory: true)
        guard let info = CFBundleCopyInfoDictionaryInDirectory(bundleURL as CFURL) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String else {
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
            aliases: aliases,
            bundleURL: bundleURL,
            bundleVersion: info["CFBundleVersion"] as? String
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
