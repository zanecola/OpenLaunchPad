import Dispatch
import Foundation
import Darwin

/// Watches the Dock Launchpad database and coalesces rapid SQLite writes into one reload.
final class LaunchpadDatabaseWatcher {
    private let path: String
    private let debounceInterval: TimeInterval
    private let queue: DispatchQueue
    private let onChange: () -> Void

    private var source: DispatchSourceFileSystemObject?
    private var notificationWorkItem: DispatchWorkItem?
    private var restartWorkItem: DispatchWorkItem?
    private var isRunning = false

    init(
        path: String = LaunchpadDBDataSource.defaultPath,
        debounceInterval: TimeInterval = 0.3,
        queue: DispatchQueue = .main,
        onChange: @escaping () -> Void
    ) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.queue = queue
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard source == nil else { return true }
        isRunning = true

        guard installSource() else {
            isRunning = false
            return false
        }
        return true
    }

    func stop() {
        isRunning = false
        notificationWorkItem?.cancel()
        notificationWorkItem = nil
        restartWorkItem?.cancel()
        restartWorkItem = nil
        source?.cancel()
        source = nil
    }

    private func installSource() -> Bool {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return false }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            self.handle(events: source.data)
        }
        source.setCancelHandler {
            close(descriptor)
        }

        self.source = source
        source.resume()
        return true
    }

    private func handle(events: DispatchSource.FileSystemEvent) {
        scheduleNotification()

        if events.contains(.rename) || events.contains(.delete) {
            source?.cancel()
            source = nil
            scheduleRestart()
        }
    }

    private func scheduleNotification() {
        notificationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        notificationWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func scheduleRestart() {
        restartWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            if !self.installSource() {
                self.scheduleRestart()
            }
        }
        restartWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
