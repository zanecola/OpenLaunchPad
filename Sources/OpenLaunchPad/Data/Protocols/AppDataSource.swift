import Foundation

/// Produces the initial ordered pages of apps from some source (Launchpad DB, /Applications, etc.).
/// The ViewModel merges this with any user-saved custom layout from LayoutStoring.
protocol AppDataSource {
    /// `pageCapacity` is how many items a full-screen page holds; a source that chunks its own
    /// order uses it. The ViewModel moves anything that overflows a page onto the next.
    func loadPages(pageCapacity: Int) throws -> [[LaunchpadItem]]
}
