import AppKit
import Foundation

@MainActor
protocol ApplicationManaging {
    /// The bundle Uninstall would move to the Trash, or nil when it can't be uninstalled.
    func uninstallURL(for app: AppItem) -> URL?
    func revealInFinder(_ app: AppItem) throws
    func showInfo(_ app: AppItem) throws
    func uninstall(_ app: AppItem) throws
}

enum ApplicationManagerError: LocalizedError {
    case applicationNotFound(String)
    case protectedApplication(String)
    case multipleCopies(String)
    case finderRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let title):
            return "Could not find \(title) on this Mac."
        case .protectedApplication(let title):
            return "\(title) is a protected application and cannot be uninstalled here."
        case .multipleCopies(let title):
            return "Several copies of \(title) are installed. Move the one you want to the Trash in Finder."
        case .finderRequestFailed(let message):
            return "Finder could not show the app information: \(message)"
        }
    }
}

@MainActor
final class SystemApplicationManager: ApplicationManaging {
    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let currentAppURL: URL
    private let currentBundleID: String?
    private let registeredURLs: (String) -> [URL]
    private let moveToTrash: (URL) throws -> Void

    init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default,
        currentAppURL: URL = Bundle.main.bundleURL,
        currentBundleID: String? = Bundle.main.bundleIdentifier,
        registeredURLs: ((String) -> [URL])? = nil,
        moveToTrash: ((URL) throws -> Void)? = nil
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
        self.currentAppURL = currentAppURL
        self.currentBundleID = currentBundleID
        self.registeredURLs = registeredURLs ?? { workspace.urlsForApplications(withBundleIdentifier: $0) }
        self.moveToTrash = moveToTrash ?? { _ = try fileManager.trashItem(at: $0, resultingItemURL: nil) }
    }

    func uninstallURL(for app: AppItem) -> URL? {
        try? uninstallTarget(for: app)
    }

    func revealInFinder(_ app: AppItem) throws {
        let url = try requiredApplicationURL(for: app)
        workspace.activateFileViewerSelecting([url])
    }

    func showInfo(_ app: AppItem) throws {
        let url = try requiredApplicationURL(for: app)
        let path = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        set targetItem to POSIX file "\(path)" as alias
        tell application "Finder"
            activate
            open information window of targetItem
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ApplicationManagerError.finderRequestFailed(message)
        }
    }

    func uninstall(_ app: AppItem) throws {
        try moveToTrash(try uninstallTarget(for: app))
    }

    /// The scanned copy with symlinks resolved, so /Applications/Safari.app counts as the
    /// system app it links to. Without a scanned copy, only an unambiguous one qualifies.
    private func uninstallTarget(for app: AppItem) throws -> URL {
        let url: URL
        if app.bundleURL == nil {
            let copies = registeredURLs(app.bundleID)
            guard !copies.isEmpty else { throw ApplicationManagerError.applicationNotFound(app.title) }
            guard copies.count == 1 else { throw ApplicationManagerError.multipleCopies(app.title) }
            url = copies[0]
        } else {
            url = try requiredApplicationURL(for: app)
        }
        let target = url.resolvingSymlinksInPath()
        guard !isProtected(target, bundleID: app.bundleID) else {
            throw ApplicationManagerError.protectedApplication(app.title)
        }
        return target
    }

    /// System locations and every copy of OpenLaunchPad, not just the running one.
    private func isProtected(_ url: URL, bundleID: String) -> Bool {
        let path = url.path
        return path == currentAppURL.resolvingSymlinksInPath().path
            || bundleID == currentBundleID
            || path == "/System"
            || path.hasPrefix("/System/")
            || path.hasPrefix("/usr/")
            || path.hasPrefix("/bin/")
            || path.hasPrefix("/sbin/")
    }

    private func requiredApplicationURL(for app: AppItem) throws -> URL {
        guard let url = applicationURL(for: app) else {
            throw ApplicationManagerError.applicationNotFound(app.title)
        }
        return url
    }

    /// The scanned copy while it exists; otherwise LaunchServices' preferred copy.
    private func applicationURL(for app: AppItem) -> URL? {
        guard let url = app.bundleURL else {
            return workspace.urlForApplication(withBundleIdentifier: app.bundleID)
        }
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
