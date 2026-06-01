import Foundation

/// Persists user-customized ordering as JSON under ~/Library/Application Support/OpenLaunchPad/.
/// Completely separate from the Dock DB — never touches it. (ADR-2)
final class JSONLayoutStore: LayoutStoring {
    private let fileURL: URL

    init(fileURL: URL = JSONLayoutStore.defaultURL) {
        self.fileURL = fileURL
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

    func clearCustomLayout() {
        try? FileManager.default.removeItem(at: fileURL)
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
