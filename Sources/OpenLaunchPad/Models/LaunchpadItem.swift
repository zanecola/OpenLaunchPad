import Foundation
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Core models

struct AppItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let bundleID: String
    let title: String
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

// MARK: - Transferable (drag-and-drop)

extension UTType {
    static let launchpadApp = UTType(exportedAs: "com.openlaunchpad.appitem")
    static let launchpadFolder = UTType(exportedAs: "com.openlaunchpad.folderitem")
}

extension AppItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadApp)
    }
}

extension FolderItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadFolder)
    }
}
