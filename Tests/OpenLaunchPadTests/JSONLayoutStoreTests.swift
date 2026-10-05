import Foundation
import Testing
@testable import OpenLaunchPad

struct JSONLayoutStoreTests {
    @Test
    func currentSchemaEncodesVersionAndRoundTripsRealisticFolderGraph() throws {
        try withStore { store, fileURL in
            let appA = UUID()
            let appB = UUID()
            let appC = UUID()
            let appD = UUID()
            let firstFolder = StoredFolder(id: UUID(), title: "Developer Tools", appIDs: [appB, appA])
            let secondFolder = StoredFolder(id: UUID(), title: "Writing", appIDs: [appD])
            let layout = StoredLayout(
                pageIDs: [[firstFolder.id, appC], [secondFolder.id]],
                folders: [firstFolder, secondFolder]
            )

            store.saveCustomLayout(layout)

            let object = try #require(
                JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
            )
            #expect(object["version"] as? Int == 1)
            #expect(store.loadCustomLayout() == layout)
        }
    }

    @Test
    func unversionedNewSchemaMigratesFolderGraph() throws {
        try withStore { store, fileURL in
            let folder = StoredFolder(id: UUID(), title: "Utilities", appIDs: [UUID(), UUID()])
            let fixture = UnversionedLayoutFixture(
                pageIDs: [[folder.id, UUID()]],
                folders: [folder]
            )
            try JSONEncoder().encode(fixture).write(to: fileURL)

            #expect(store.loadCustomLayout() == StoredLayout(
                pageIDs: fixture.pageIDs,
                folders: fixture.folders
            ))
        }
    }

    @Test
    func unsupportedFutureVersionReturnsNil() throws {
        try withStore { store, fileURL in
            let fixture = VersionedLayoutFixture(
                version: 2,
                pageIDs: [[UUID()]],
                folders: [StoredFolder(id: UUID(), title: "Future", appIDs: [UUID()])]
            )
            try JSONEncoder().encode(fixture).write(to: fileURL)

            #expect(store.loadCustomLayout() == nil)
        }
    }

    @Test
    func futureHybridPayloadDoesNotFallThroughToLegacyMigration() throws {
        try withStore { store, fileURL in
            let folderID = UUID()
            let fixture = HybridFutureLayoutFixture(
                version: 2,
                pageIDs: [[folderID]],
                folders: [StoredFolder(id: folderID, title: "Future", appIDs: [UUID()])],
                folderNames: [folderID: "Legacy trap"]
            )
            try JSONEncoder().encode(fixture).write(to: fileURL)

            #expect(store.loadCustomLayout() == nil)
        }
    }

    @Test
    func legacyNamedLayoutMigratesEveryFolderWithEmptyMembership() throws {
        try withStore { store, fileURL in
            let appID = UUID()
            let folderID = UUID()
            let absentFolderID = UUID()
            let legacy = LegacyNamedLayout(
                pageIDs: [[folderID, appID]],
                folderNames: [folderID: "Developer Tools", absentFolderID: "Writing"]
            )
            try JSONEncoder().encode(legacy).write(to: fileURL)

            let migrated = store.loadCustomLayout()

            #expect(migrated?.pageIDs == legacy.pageIDs)
            #expect(Set(migrated?.folders.map(\.id) ?? []) == Set(legacy.folderNames.keys))
            #expect(migrated?.folders.allSatisfy { $0.appIDs.isEmpty } == true)
            #expect(migrated?.folders.first { $0.id == folderID }?.title == "Developer Tools")
            #expect(migrated?.folders.first { $0.id == absentFolderID }?.title == "Writing")
        }
    }

    @Test
    func legacyNamedLayoutUsesPageAppearanceThenUUIDOrder() throws {
        try withStore { store, fileURL in
            let firstAbsentID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let secondAbsentID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let firstPageFolderID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
            let secondPageFolderID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
            let legacy = LegacyNamedLayout(
                pageIDs: [[firstPageFolderID, secondPageFolderID, firstPageFolderID]],
                folderNames: [
                    secondPageFolderID: "Second on page",
                    firstAbsentID: "First absent",
                    firstPageFolderID: "First on page",
                    secondAbsentID: "Second absent",
                ]
            )
            try JSONEncoder().encode(legacy).write(to: fileURL)

            let migrated = store.loadCustomLayout()

            #expect(migrated?.folders.map(\.id) == [
                firstPageFolderID,
                secondPageFolderID,
                firstAbsentID,
                secondAbsentID,
            ])
        }
    }

    @Test
    func oldestRawPageIDsMigrateWithoutFolders() throws {
        try withStore { store, fileURL in
            let pageIDs = [[UUID(), UUID()], [UUID()]]
            try JSONEncoder().encode(pageIDs).write(to: fileURL)

            #expect(store.loadCustomLayout() == StoredLayout(pageIDs: pageIDs))
        }
    }

    @Test
    func malformedLayoutReturnsNil() throws {
        try withStore { store, fileURL in
            try Data("not json".utf8).write(to: fileURL)

            #expect(store.loadCustomLayout() == nil)
        }
    }

    @Test
    func clearMovesLayoutIntoTimestampedBackup() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try withStore(now: { date }) { store, fileURL in
            let layout = StoredLayout(pageIDs: [[UUID()]])
            store.saveCustomLayout(layout)
            let savedData = try Data(contentsOf: fileURL)

            store.clearCustomLayout()

            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            #expect(store.loadCustomLayout() == nil)
            let backupURL = Self.backupDirectory(for: fileURL)
                .appendingPathComponent("layout-\(Self.timestamp(date)).json")
            #expect(try Data(contentsOf: backupURL) == savedData)
        }
    }

    @Test
    func clearKeepsOnlyTheNewestTenBackups() throws {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        try withStore(now: { date }) { store, fileURL in
            for _ in 0..<12 {
                store.saveCustomLayout(StoredLayout(pageIDs: [[UUID()]]))
                store.clearCustomLayout()
                date += 1
            }

            let expected = (2..<12).map {
                "layout-\(Self.timestamp(Date(timeIntervalSince1970: 1_800_000_000 + Double($0)))).json"
            }
            let names = try Self.backupNames(for: fileURL)
            #expect(names == expected)
        }
    }

    @Test
    func clearInTheSameSecondKeepsBothBackups() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try withStore(now: { date }) { store, fileURL in
            let first = StoredLayout(pageIDs: [[UUID()]])
            let second = StoredLayout(pageIDs: [[UUID()]])
            store.saveCustomLayout(first)
            store.clearCustomLayout()
            store.saveCustomLayout(second)
            store.clearCustomLayout()

            let stem = "layout-\(Self.timestamp(date))"
            let names = try Self.backupNames(for: fileURL)
            #expect(names == ["\(stem)-2.json", "\(stem).json"])
        }
    }

    @Test
    func clearWithoutLayoutCreatesNoBackup() throws {
        try withStore { store, fileURL in
            store.clearCustomLayout()

            #expect(!FileManager.default.fileExists(atPath: Self.backupDirectory(for: fileURL).path))
        }
    }

    private func withStore(
        now: @escaping () -> Date = Date.init,
        _ operation: (JSONLayoutStore, URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadLayoutTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("layout.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JSONLayoutStore(
            fileURL: fileURL,
            backupDirectory: Self.backupDirectory(for: fileURL),
            now: now
        )
        try operation(store, fileURL)
    }

    private static func backupDirectory(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    private static func backupNames(for fileURL: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: backupDirectory(for: fileURL).path).sorted()
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

private struct LegacyNamedLayout: Codable {
    var pageIDs: [[UUID]]
    var folderNames: [UUID: String]
}

private struct VersionedLayoutFixture: Codable {
    var version: Int
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]
}

private struct UnversionedLayoutFixture: Codable {
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]
}

private struct HybridFutureLayoutFixture: Codable {
    var version: Int
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]
    var folderNames: [UUID: String]
}
