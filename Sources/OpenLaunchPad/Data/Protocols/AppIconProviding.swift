import AppKit

/// Resolves an NSImage icon for a given bundle ID.
/// Injected so it can be swapped for testing or alternate icon packs.
protocol AppIconProviding {
    /// `bundleURL` is the copy the tile opens, when the data source found one.
    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage
}
