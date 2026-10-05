import Foundation
import Testing
@testable import OpenLaunchPad

struct LaunchpadDatabaseWatcherTests {
    @Test
    func watcherCoalescesRapidFileWrites() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadWatcherTests-\(UUID().uuidString).db")
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        try await confirmation("database change callback", expectedCount: 1) { confirm in
            // Off the main queue, which MainActor tests running alongside can hold past the wait.
            let watcher = LaunchpadDatabaseWatcher(
                path: url.path,
                debounceInterval: 0.03,
                queue: DispatchQueue(label: "LaunchpadDatabaseWatcherTests"),
                onChange: { confirm() }
            )
            #expect(watcher.start())

            let handle = try FileHandle(forWritingTo: url)
            try handle.write(contentsOf: Data("first".utf8))
            try handle.write(contentsOf: Data("second".utf8))
            try handle.synchronize()
            try handle.close()

            try await Task.sleep(for: .milliseconds(200))
            watcher.stop()
        }
    }

    @Test
    func watcherDoesNotStartForMissingFile() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadWatcherTests-\(UUID().uuidString).db")
            .path
        let watcher = LaunchpadDatabaseWatcher(path: path, onChange: {})

        #expect(!watcher.start())
    }
}
