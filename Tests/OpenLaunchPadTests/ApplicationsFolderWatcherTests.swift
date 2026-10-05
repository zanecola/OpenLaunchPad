import Foundation
import Testing
@testable import OpenLaunchPad

@MainActor
struct ApplicationsFolderWatcherTests {
    @Test
    func watcherReportsAppInstalledIntoWatchedFolder() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let applications = root + "/Applications"
        try FileManager.default.createDirectory(atPath: applications, withIntermediateDirectories: true)

        var changeCount = 0
        let watcher = ApplicationsFolderWatcher(paths: [applications], latency: 0.05) { changeCount += 1 }
        #expect(watcher.start())
        defer { watcher.stop() }

        try FileManager.default.createDirectory(
            atPath: applications + "/New.app/Contents",
            withIntermediateDirectories: true
        )

        #expect(await waitUntil { changeCount > 0 })
    }

    @Test
    func watcherReportsAppsInFolderCreatedAfterStart() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let userApplications = root + "/Applications"

        var changeCount = 0
        let watcher = ApplicationsFolderWatcher(paths: [userApplications], latency: 0.05) { changeCount += 1 }
        #expect(watcher.start())
        defer { watcher.stop() }

        try FileManager.default.createDirectory(
            atPath: userApplications + "/New.app/Contents",
            withIntermediateDirectories: true
        )

        #expect(await waitUntil { changeCount > 0 })
    }

    /// Uses the symlinked temporary path (/var/...) so a folder created after start
    /// only matches if the watcher resolves it to the real path (/private/var/...).
    private func makeTemporaryRoot() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadWatcherTests-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    private func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }
}
