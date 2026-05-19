import AppKit

/// Loads app icons from their bundle using NSWorkspace.
/// Returns a generic app icon when the bundle can't be found.
final class BundleIconProvider: AppIconProviding {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func icon(for bundleID: String) -> NSImage {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return workspace.icon(forFile: url.path)
    }
}
