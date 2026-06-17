import AppKit
import Foundation

@MainActor
protocol ApplicationManaging {
    func canUninstall(_ app: AppItem) -> Bool
    func revealInFinder(_ app: AppItem) throws
    func showInfo(_ app: AppItem) throws
    func uninstall(_ app: AppItem) throws
}

enum ApplicationManagerError: LocalizedError {
    case applicationNotFound(String)
    case protectedApplication(String)
    case finderRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let title):
            return "Could not find \(title) on this Mac."
        case .protectedApplication(let title):
            return "\(title) is a protected application and cannot be uninstalled here."
        case .finderRequestFailed(let message):
            return "Finder could not show the app information: \(message)"
        }
    }
}

@MainActor
final class SystemApplicationManager: ApplicationManaging {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func canUninstall(_ app: AppItem) -> Bool {
        guard let url = applicationURL(for: app) else { return false }
        return !Self.isProtectedApplication(at: url)
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
        let url = try requiredApplicationURL(for: app)
        guard !Self.isProtectedApplication(at: url) else {
            throw ApplicationManagerError.protectedApplication(app.title)
        }
        _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
    }

    static func isProtectedApplication(at url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        return standardizedURL == Bundle.main.bundleURL.standardizedFileURL
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

    private func applicationURL(for app: AppItem) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: app.bundleID)
    }
}
