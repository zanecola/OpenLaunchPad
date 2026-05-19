import Foundation

/// Produces the initial ordered pages of apps from some source (Launchpad DB, /Applications, etc.).
/// The ViewModel merges this with any user-saved custom layout from LayoutStoring.
protocol AppDataSource {
    func loadPages() throws -> [[LaunchpadItem]]
}
