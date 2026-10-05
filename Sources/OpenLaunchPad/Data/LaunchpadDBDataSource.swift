import Foundation
import SQLite3

/// Reads the macOS Dock/Launchpad SQLite database and reconstructs the page/folder hierarchy.
/// Opens in read-only mode; never writes to the Dock DB. (ADR-2)
final class LaunchpadDBDataSource: AppDataSource {
    let dbPath: String

    init(dbPath: String = LaunchpadDBDataSource.defaultPath) {
        self.dbPath = dbPath
    }

    static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Dock/desktopproperties.db")
            .path
    }

    /// Keeps the database's own pages.
    func loadPages(pageCapacity _: Int) throws -> [[LaunchpadItem]] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw LaunchpadDBError.cannotOpen(dbPath)
        }
        defer { sqlite3_close(db) }

        let rawItems = try queryItems(db: db)
        let appMap = try queryApps(db: db)
        let groupMap = try queryGroups(db: db)

        return buildPages(rawItems: rawItems, appMap: appMap, groupMap: groupMap)
    }

    // MARK: - Private

    private struct RawItem {
        let id: Int
        let uuid: String
        let type: Int       // 1=app, 2=page, 3=folder, 4=root
        let parentID: Int
        let ordering: Int
    }

    private func queryItems(db: OpaquePointer) throws -> [RawItem] {
        let sql = "SELECT ROWID, uuid, type, parent_id, ordering FROM items ORDER BY parent_id, ordering"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw LaunchpadDBError.queryFailed("items")
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RawItem(
                id: Int(sqlite3_column_int64(stmt, 0)),
                uuid: String(cString: sqlite3_column_text(stmt, 1)),
                type: Int(sqlite3_column_int(stmt, 2)),
                parentID: Int(sqlite3_column_int(stmt, 3)),
                ordering: Int(sqlite3_column_int(stmt, 4))
            ))
        }
        return results
    }

    private func queryApps(db: OpaquePointer) throws -> [Int: (title: String, bundleID: String)] {
        let sql = "SELECT item_id, title, bundleid FROM apps"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw LaunchpadDBError.queryFailed("apps")
        }
        defer { sqlite3_finalize(stmt) }

        var map: [Int: (title: String, bundleID: String)] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let itemID = Int(sqlite3_column_int64(stmt, 0))
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let bundleID = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            map[itemID] = (title: title, bundleID: bundleID)
        }
        return map
    }

    private func queryGroups(db: OpaquePointer) throws -> [Int: String] {
        let sql = "SELECT item_id, title FROM groups"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw LaunchpadDBError.queryFailed("groups")
        }
        defer { sqlite3_finalize(stmt) }

        var map: [Int: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let itemID = Int(sqlite3_column_int64(stmt, 0))
            if let title = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) {
                map[itemID] = title
            }
        }
        return map
    }

    private func buildPages(
        rawItems: [RawItem],
        appMap: [Int: (title: String, bundleID: String)],
        groupMap: [Int: String]
    ) -> [[LaunchpadItem]] {
        // Build children lookup: parentID → [RawItem sorted by ordering]
        var children: [Int: [RawItem]] = [:]
        for item in rawItems {
            children[item.parentID, default: []].append(item)
        }

        // A Dock database may contain a separate holding hierarchy. Search every root
        // for the first holder that represents visible Launchpad pages.
        let launchpadHolder = rawItems
            .filter { $0.type == 4 }
            .compactMap { root in
                (children[root.id] ?? [])
                    .filter { $0.type == 3 }
                    .first { groupMap[$0.id]?.lowercased() != "holding" }
            }
            .first

        guard let holder = launchpadHolder else { return [] }

        // Pages are type=2 children of the holder, ordered by `ordering`
        let pages = (children[holder.id] ?? []).filter { $0.type == 2 }

        return pages.map { page in
            let pageChildren = (children[page.id] ?? [])
            return pageChildren.compactMap { item -> LaunchpadItem? in
                switch item.type {
                case 1:  // app
                    guard let info = appMap[item.id], !info.bundleID.isEmpty else { return nil }
                    return .app(AppItem(
                        id: UUID(uuidString: item.uuid) ?? UUID(),
                        bundleID: info.bundleID,
                        title: info.title
                    ))
                case 3:  // folder
                    let folderTitle = groupMap[item.id] ?? "Folder"
                    let folderApps = (children[item.id] ?? []).compactMap { appItem -> AppItem? in
                        guard appItem.type == 1, let info = appMap[appItem.id], !info.bundleID.isEmpty else { return nil }
                        return AppItem(
                            id: UUID(uuidString: appItem.uuid) ?? UUID(),
                            bundleID: info.bundleID,
                            title: info.title
                        )
                    }
                    return .folder(FolderItem(
                        id: UUID(uuidString: item.uuid) ?? UUID(),
                        title: folderTitle,
                        apps: folderApps
                    ))
                default:
                    return nil
                }
            }
        }.filter { !$0.isEmpty }
    }
}

// MARK: -

enum LaunchpadDBError: LocalizedError {
    case cannotOpen(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let path): return "Cannot open Launchpad DB at \(path)"
        case .queryFailed(let table): return "Query failed on table: \(table)"
        }
    }
}
