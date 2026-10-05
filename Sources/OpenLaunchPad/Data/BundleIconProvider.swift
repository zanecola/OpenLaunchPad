import AppKit

/// Loads app icons from their bundle using NSWorkspace.
/// Returns a generic app icon when the bundle can't be found.
final class BundleIconProvider: AppIconProviding {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    /// Prefers the tile's own copy, so a duplicate shows the icon of the bundle it opens.
    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage {
        if let bundleURL, FileManager.default.fileExists(atPath: bundleURL.path) {
            return workspace.icon(forFile: bundleURL.path)
        }
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return workspace.icon(forFile: url.path)
    }
}
