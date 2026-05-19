import AppKit

/// Resolves an NSImage icon for a given bundle ID.
/// Injected so it can be swapped for testing or alternate icon packs.
protocol AppIconProviding {
    func icon(for bundleID: String) -> NSImage
}
