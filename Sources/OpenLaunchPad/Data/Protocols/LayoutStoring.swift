import Foundation

struct StoredLayout: Codable, Equatable {
    var pageIDs: [[UUID]]
    var folderNames: [UUID: String]
}

/// Persists user-customized ordering and folder names outside the system database.
protocol LayoutStoring {
    func loadCustomLayout() -> StoredLayout?
    func saveCustomLayout(_ layout: StoredLayout)
    func clearCustomLayout()
}
