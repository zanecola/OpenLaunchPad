import Foundation

/// Persists user-customized ordering as JSON under ~/Library/Application Support/OpenLaunchPad/.
/// Completely separate from the Dock DB — never touches it. (ADR-2)
final class JSONLayoutStore: LayoutStoring {
    static let maxResetBackups = 10

    private let fileURL: URL
    private let backupDirectory: URL
    private let now: () -> Date

    /// Backups default to a `Backups` folder beside `fileURL`, so a store on a temporary file
    /// never writes into the real Application Support folder.
    init(
        fileURL: URL = JSONLayoutStore.defaultURL,
        backupDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.backupDirectory = backupDirectory
            ?? fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        self.now = now
    }

    static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appendingPathComponent("OpenLaunchPad", isDirectory: true)
            .appendingPathComponent("layout.json")
    }

    func loadCustomLayout() -> StoredLayout? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        if let marker = try? decoder.decode(LayoutVersionMarker.self, from: data), marker.isVersioned {
            guard let envelope = try? decoder.decode(VersionedStoredLayout.self, from: data),
                  envelope.version == VersionedStoredLayout.currentVersion else {
                return nil
            }
            return envelope.layout
        }
        if let layout = try? decoder.decode(StoredLayout.self, from: data) {
            return layout
        }
        if let legacyLayout = try? decoder.decode(LegacyNamedLayout.self, from: data) {
            return legacyLayout.migrated()
        }
        if let legacyPageIDs = try? decoder.decode([[UUID]].self, from: data) {
            return StoredLayout(pageIDs: legacyPageIDs)
        }
        return nil
    }

    func saveCustomLayout(_ layout: StoredLayout) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(VersionedStoredLayout(layout: layout)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Moves layout.json to `Backups/layout-<timestamp>.json` and keeps the newest backups.
    /// If the move fails, the layout stays in place rather than being deleted.
    func clearCustomLayout() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              moveToBackups(prefix: "layout") else { return }
        pruneBackups(prefix: "layout", keeping: Self.maxResetBackups)
    }

    // MARK: - Backups

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private func moveToBackups(prefix: String) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            try fileManager.moveItem(at: fileURL, to: newBackupURL(prefix: prefix))
            return true
        } catch {
            return false
        }
    }

    /// Never reuses a name, so a second backup in the same second cannot replace the first.
    private func newBackupURL(prefix: String) -> URL {
        let stem = "\(prefix)-\(Self.timestampFormatter.string(from: now()))"
        var url = backupDirectory.appendingPathComponent("\(stem).json")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = backupDirectory.appendingPathComponent("\(stem)-\(counter).json")
            counter += 1
        }
        return url
    }

    private func pruneBackups(prefix: String, keeping limit: Int) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backupDirectory.path)) ?? []
        // Timestamped names sort oldest first once the extension is dropped.
        let backups = names
            .filter { $0.hasPrefix("\(prefix)-") && $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
        for stem in backups.dropLast(limit) {
            try? FileManager.default.removeItem(at: backupDirectory.appendingPathComponent("\(stem).json"))
        }
    }
}

private struct LayoutVersionMarker: Decodable {
    let isVersioned: Bool

    private enum CodingKeys: String, CodingKey {
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isVersioned = container.contains(.version)
    }
}

private struct VersionedStoredLayout: Codable {
    static let currentVersion = 1

    var version: Int
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]

    init(layout: StoredLayout) {
        version = Self.currentVersion
        pageIDs = layout.pageIDs
        folders = layout.folders
    }

    var layout: StoredLayout {
        StoredLayout(pageIDs: pageIDs, folders: folders)
    }
}

private struct LegacyNamedLayout: Decodable {
    var pageIDs: [[UUID]]
    var folderNames: [UUID: String]

    func migrated() -> StoredLayout {
        var orderedFolderIDs: [UUID] = []
        var seenFolderIDs = Set<UUID>()

        for id in pageIDs.joined() where folderNames[id] != nil {
            if seenFolderIDs.insert(id).inserted {
                orderedFolderIDs.append(id)
            }
        }

        orderedFolderIDs.append(contentsOf: folderNames.keys
            .filter { !seenFolderIDs.contains($0) }
            .sorted { $0.uuidString < $1.uuidString })

        let folders = orderedFolderIDs.map { id in
            StoredFolder(id: id, title: folderNames[id]!, appIDs: [])
        }
        return StoredLayout(pageIDs: pageIDs, folders: folders)
    }
}
