import Foundation

struct StoredFolder: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var appIDs: [UUID]
}

struct StoredLayout: Codable, Equatable, Sendable {
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]

    init(pageIDs: [[UUID]], folders: [StoredFolder] = []) {
        self.pageIDs = pageIDs
        self.folders = folders
    }
}

/// Persists user-customized ordering and folders outside the system database.
protocol LayoutStoring {
    func loadCustomLayout() -> StoredLayout?
    func saveCustomLayout(_ layout: StoredLayout)
    func clearCustomLayout()
}
