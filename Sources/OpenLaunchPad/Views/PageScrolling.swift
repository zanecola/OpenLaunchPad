import AppKit
import SwiftUI

enum PageScrollDirection: Equatable {
    case previous
    case next
}

/// Turns mouse-wheel notches into page turns: one notch is one page, on either axis. Notches
/// within the cooldown of the last turn are dropped, so a fast spin turns a page at a time.
struct PageWheelStepper {
    static let cooldown: TimeInterval = 0.35
    private var lastTurn: TimeInterval?

    /// `time` is the event's timestamp, in seconds.
    mutating func step(deltaX: CGFloat, deltaY: CGFloat, at time: TimeInterval) -> PageScrollDirection? {
        let delta = abs(deltaX) >= abs(deltaY) ? deltaX : deltaY
        guard delta != 0 else { return nil }
        if let lastTurn, time - lastTurn < Self.cooldown { return nil }
        lastTurn = time
        // The way that scrolls a document down, or right, turns to the next page.
        return delta < 0 ? .next : .previous
    }
}

/// Tells when the full-screen pages came to rest after the user scrolled them, so the page they
/// rest on becomes current. Arrow keys, the dots and a resize scroll them to the current page,
/// and their scrolls are not reported, so a stale position can't turn the page back.
struct PageScrollSettling {
    private var userScrolled = false

    /// True when this phase ends a scroll the user made.
    mutating func phaseChanged(to phase: ScrollPhase) -> Bool {
        switch phase {
        case .interacting, .decelerating:
            userScrolled = true
            return false
        case .idle:
            defer { userScrolled = false }
            return userScrolled
        case .tracking, .animating:
            return false
        }
    }
}

/// Pages with the mouse wheel anywhere in the window this view is in. Trackpad and Magic Mouse
/// swipes come in phases and are left to the pages' scroll view, which follows the fingers.
struct PageWheelMonitor: NSViewRepresentable {
    /// Asked for each event; while false, the wheel scrolls whatever is under the pointer.
    let isEnabled: () -> Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onPrevious: onPrevious, onNext: onNext)
    }

    func makeNSView(context: Context) -> WindowAnchorView {
        let view = WindowAnchorView()
        view.onWindowChange = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.attach(to: view)
        }
        return view
    }

    func updateNSView(_ view: WindowAnchorView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onPrevious = onPrevious
        context.coordinator.onNext = onNext
        context.coordinator.attach(to: view)
    }

    final class Coordinator {
        var isEnabled: () -> Bool
        var onPrevious: () -> Void
        var onNext: () -> Void

        private weak var observedWindow: NSWindow?
        private var monitor: Any?
        private var stepper = PageWheelStepper()

        init(isEnabled: @escaping () -> Bool, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
            self.isEnabled = isEnabled
            self.onPrevious = onPrevious
            self.onNext = onNext
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func attach(to view: NSView) {
            guard let window = view.window, window !== observedWindow else { return }
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            observedWindow = window
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak window] event in
                guard let self, let window, event.window === window else { return event }
                return self.handle(event) ? nil : event
            }
        }

        /// Returns true for a wheel event it took, dropped ones included, so the scroll view
        /// doesn't also scroll by it.
        func handle(_ event: NSEvent) -> Bool {
            guard event.phase.isEmpty, event.momentumPhase.isEmpty, isEnabled() else { return false }
            switch stepper.step(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY, at: event.timestamp) {
            case .previous: onPrevious()
            case .next: onNext()
            case nil: break
            }
            return true
        }
    }
}

final class WindowAnchorView: NSView {
    var onWindowChange: () -> Void = {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange()
    }
}
