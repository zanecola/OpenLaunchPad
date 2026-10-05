import Foundation

/// Decides whether a click on the Dock icon or the status item closes the launcher. The click's
/// mouse-down can close it first: the outside-click monitor sees a Dock click, the popup can resign
/// key, and full screen can resign active. The Dock reopens the app on mouse-up, so without this
/// the same click would show the launcher again.
struct LauncherToggle {
    /// Longer than a click holds the button down, shorter than a deliberate second click.
    static let implicitDismissalWindow: TimeInterval = 0.4

    private let now: () -> TimeInterval
    private var lastImplicitDismissal: TimeInterval?

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    /// Call when the launcher closes on its own: an outside click, resign key or resign active.
    mutating func recordImplicitDismissal() {
        lastImplicitDismissal = now()
    }

    /// Each click uses up the recorded dismissal, so the next click opens the launcher again.
    mutating func clickCloses(launcherIsVisible: Bool) -> Bool {
        defer { lastImplicitDismissal = nil }
        if launcherIsVisible { return true }
        guard let lastImplicitDismissal else { return false }
        return now() - lastImplicitDismissal < Self.implicitDismissalWindow
    }
}
