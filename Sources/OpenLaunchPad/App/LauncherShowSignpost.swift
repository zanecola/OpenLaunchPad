import Foundation
import os

/// Times a launcher show for Instruments' Points of Interest. "Show" runs from the show starting
/// until its window is ordered in; "Show to first commit" runs on until the Core Animation commit
/// that follows, which hands the first frame to the window server. "Hotkey" marks the global
/// shortcut's press, which reaches the show a main-actor hop later.
struct LauncherShowSignpost {
    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.openlaunchpad",
        category: .pointsOfInterest
    )

    private let toOrderFront: OSSignpostIntervalState
    private let toFirstCommit: OSSignpostIntervalState

    static func hotkeyPressed() {
        signposter.emitEvent("Hotkey")
    }

    init(_ surface: String) {
        let id = Self.signposter.makeSignpostID()
        toOrderFront = Self.signposter.beginInterval("Show", id: id, "\(surface, privacy: .public)")
        toFirstCommit = Self.signposter.beginInterval("Show to first commit", id: id, "\(surface, privacy: .public)")
    }

    /// Call once the window is ordered in.
    func end() {
        let signposter = Self.signposter
        let toFirstCommit = toFirstCommit
        signposter.endInterval("Show", toOrderFront)
        // Core Animation commits from a main run loop observer (before waiting, and on exit); one
        // ordered after every other runs once that commit is done. It fires once.
        let observer = CFRunLoopObserverCreateWithHandler(
            nil,
            CFRunLoopActivity([.beforeWaiting, .exit]).rawValue,
            false,
            CFIndex.max
        ) { _, _ in
            signposter.endInterval("Show to first commit", toFirstCommit)
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
}
