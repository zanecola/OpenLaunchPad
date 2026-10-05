import CoreServices
import Foundation

/// Watches the application folders so installs, removals, and updates reload the launcher.
/// FSEvents is recursive, can watch folders that do not exist yet (e.g. ~/Applications),
/// and its latency coalesces the burst of writes an install produces into a few callbacks.
final class ApplicationsFolderWatcher {
    private let paths: [String]
    private let latency: CFTimeInterval
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(
        paths: [String] = ApplicationsFolderDataSource.defaultSearchPaths,
        latency: CFTimeInterval = 1.0,
        onChange: @escaping () -> Void
    ) {
        self.paths = paths.map(Self.realPath)
        self.latency = latency
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<ApplicationsFolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else {
            return false
        }

        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }
        self.stream = stream
        return true
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// FSEvents resolves existing roots itself, but a missing root under a symlink
    /// (/var -> /private/var) would never match, so resolve through its nearest existing ancestor.
    private static func realPath(_ path: String) -> String {
        if let resolved = realpath(path, nil) {
            defer { free(resolved) }
            return String(cString: resolved)
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard parent != path else { return path }
        return (realPath(parent) as NSString).appendingPathComponent((path as NSString).lastPathComponent)
    }
}
