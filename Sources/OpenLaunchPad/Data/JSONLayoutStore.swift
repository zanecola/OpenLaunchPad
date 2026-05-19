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
        if let layout = try? JSONDecoder().decode(StoredLayout.self, from: data) {
            return layout
        }
        if let legacyPageIDs = try? JSONDecoder().decode([[UUID]].self, from: data) {
            return StoredLayout(pageIDs: legacyPageIDs, folderNames: [:])
        }
        return nil
    }

    func saveCustomLayout(_ layout: StoredLayout) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(layout) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func clearCustomLayout() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
