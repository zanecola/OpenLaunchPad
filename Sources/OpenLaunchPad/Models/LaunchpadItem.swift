import Foundation

// MARK: - Core models

struct AppItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let bundleID: String
    let title: String
    /// Other names search matches, such as CFBundleName and the file name.
    var aliases: [String] = []
    /// The bundle the data source found, so app actions target this copy rather than
    /// LaunchServices' preferred one. Not persisted: layout.json stores IDs only.
    var bundleURL: URL? = nil
}

struct FolderItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var apps: [AppItem]
}

enum LaunchpadItem: Identifiable, Hashable, Codable, Sendable {
    case app(AppItem)
    case folder(FolderItem)

    var id: UUID {
        switch self {
        case .app(let a): return a.id
        case .folder(let f): return f.id
        }
    }

    var title: String {
        switch self {
        case .app(let a): return a.title
        case .folder(let f): return f.title
        }
    }
}
