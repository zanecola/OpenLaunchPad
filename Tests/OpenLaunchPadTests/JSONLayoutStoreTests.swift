import Foundation
import Testing
@testable import OpenLaunchPad

struct JSONLayoutStoreTests {
    @Test
    func storeLoadsLegacyLayoutAndRoundTripsFolderNames() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadLayoutTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("layout.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let itemID = UUID()
        let folderID = UUID()
        try JSONEncoder().encode([[itemID]]).write(to: fileURL)
        let store = JSONLayoutStore(fileURL: fileURL)

        #expect(store.loadCustomLayout() == StoredLayout(pageIDs: [[itemID]], folderNames: [:]))

        let updated = StoredLayout(
            pageIDs: [[folderID, itemID]],
            folderNames: [folderID: "Developer Tools"]
        )
        store.saveCustomLayout(updated)

        #expect(store.loadCustomLayout() == updated)
    }
}
