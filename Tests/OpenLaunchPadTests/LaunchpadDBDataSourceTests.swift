import Foundation
import SQLite3
import Testing
@testable import OpenLaunchPad

struct LaunchpadDBDataSourceTests {
    @Test
    func loadPagesSkipsHoldingRoot() throws {
        let fixture = try SQLiteFixture()
        defer { fixture.remove() }

        try fixture.execute("""
            INSERT INTO items (ROWID, uuid, type, parent_id, ordering) VALUES
                (1, '00000000-0000-0000-0000-000000000001', 4, 0, 0),
                (2, '00000000-0000-0000-0000-000000000002', 3, 1, 0),
                (10, '00000000-0000-0000-0000-000000000010', 4, 0, 1),
                (11, '00000000-0000-0000-0000-000000000011', 3, 10, 0),
                (12, '00000000-0000-0000-0000-000000000012', 2, 11, 0),
                (13, '00000000-0000-0000-0000-000000000013', 1, 12, 0);
            INSERT INTO groups (item_id, title) VALUES
                (2, 'holding'),
                (11, 'Launchpad');
            INSERT INTO apps (item_id, title, bundleid) VALUES
                (13, 'Mail', 'com.apple.mail');
            """)

        let pages = try LaunchpadDBDataSource(dbPath: fixture.path).loadPages(pageCapacity: 35)

        #expect(pages.map { $0.map(\.title) } == [["Mail"]])
    }

    @Test
    func loadPagesReconstructsOrderedAppsAndFolders() throws {
        let fixture = try SQLiteFixture()
        defer { fixture.remove() }

        try fixture.execute("""
            INSERT INTO items (ROWID, uuid, type, parent_id, ordering) VALUES
                (1, '10000000-0000-0000-0000-000000000001', 4, 0, 0),
                (2, '10000000-0000-0000-0000-000000000002', 3, 1, 0),
                (3, '10000000-0000-0000-0000-000000000003', 2, 2, 0),
                (4, '10000000-0000-0000-0000-000000000004', 1, 3, 1),
                (5, '10000000-0000-0000-0000-000000000005', 3, 3, 0),
                (6, '10000000-0000-0000-0000-000000000006', 1, 5, 1),
                (7, '10000000-0000-0000-0000-000000000007', 1, 5, 0),
                (8, '10000000-0000-0000-0000-000000000008', 2, 2, 1),
                (9, '10000000-0000-0000-0000-000000000009', 1, 8, 0);
            INSERT INTO groups (item_id, title) VALUES
                (2, 'Launchpad'),
                (5, 'Work');
            INSERT INTO apps (item_id, title, bundleid) VALUES
                (4, 'Mail', 'com.apple.mail'),
                (6, 'Notes', 'com.apple.Notes'),
                (7, 'Calendar', 'com.apple.iCal'),
                (9, 'Maps', 'com.apple.Maps');
            """)

        let pages = try LaunchpadDBDataSource(dbPath: fixture.path).loadPages(pageCapacity: 35)

        #expect(pages.count == 2)
        #expect(pages[0].map(\.title) == ["Work", "Mail"])
        #expect(pages[1].map(\.title) == ["Maps"])

        guard case .folder(let folder) = pages[0][0] else {
            Issue.record("Expected the first item to be a folder")
            return
        }
        #expect(folder.apps.map(\.title) == ["Calendar", "Notes"])
    }

    @Test
    func loadPagesThrowsForMalformedDatabase() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadTests-\(UUID().uuidString).sqlite")
            .path
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(throws: LaunchpadDBError.self) {
            try LaunchpadDBDataSource(dbPath: path).loadPages(pageCapacity: 35)
        }
    }
}

private final class SQLiteFixture {
    let path: String
    private var database: OpaquePointer?

    init() throws {
        path = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadTests-\(UUID().uuidString).sqlite")
            .path

        guard sqlite3_open(path, &database) == SQLITE_OK else {
            throw FixtureError.cannotOpen
        }

        try execute("""
            CREATE TABLE items (
                uuid TEXT NOT NULL,
                type INTEGER NOT NULL,
                parent_id INTEGER NOT NULL,
                ordering INTEGER NOT NULL
            );
            CREATE TABLE apps (
                item_id INTEGER NOT NULL,
                title TEXT,
                bundleid TEXT
            );
            CREATE TABLE groups (
                item_id INTEGER NOT NULL,
                title TEXT
            );
            """)
    }

    deinit {
        sqlite3_close(database)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw FixtureError.executionFailed(message)
        }
    }

    func remove() {
        sqlite3_close(database)
        database = nil
        try? FileManager.default.removeItem(atPath: path)
    }
}

private enum FixtureError: Error {
    case cannotOpen
    case executionFailed(String)
}
