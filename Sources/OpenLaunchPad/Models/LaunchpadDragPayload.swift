import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum LaunchpadDragKind: String, Codable, Hashable, Sendable {
    case app
    case folder
}

struct LaunchpadDragPayload: Codable, Hashable, Sendable, Transferable {
    let itemID: UUID
    let kind: LaunchpadDragKind

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadItem)
    }
}

extension UTType {
    static let launchpadItem = UTType(exportedAs: "com.openlaunchpad.item")
}
