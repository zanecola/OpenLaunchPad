import AppKit
import SwiftUI

enum PageScrollDirection: Equatable {
    case previous
    case next
}

struct HorizontalPageScrollAccumulator {
    let threshold: CGFloat
    private var accumulatedX: CGFloat = 0
    private var didTrigger = false

    init(threshold: CGFloat = 32) {
        self.threshold = threshold
    }

    mutating func process(deltaX: CGFloat, deltaY: CGFloat) -> PageScrollDirection? {
        guard abs(deltaX) > abs(deltaY) else { return nil }
        accumulatedX += deltaX
        guard !didTrigger, abs(accumulatedX) >= threshold else { return nil }

        didTrigger = true
        return accumulatedX < 0 ? .next : .previous
    }

    mutating func endGesture() {
        accumulatedX = 0
        didTrigger = false
    }
}

/// Observes horizontal wheel and trackpad events for the window containing this view.
struct HorizontalPageScrollMonitor: NSViewRepresentable {
    let onPrevious: () -> Void
    let onNext: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPrevious: onPrevious, onNext: onNext)
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
        context.coordinator.onPrevious = onPrevious
        context.coordinator.onNext = onNext
        context.coordinator.attach(to: view)
    }

    final class Coordinator {
        var onPrevious: () -> Void
        var onNext: () -> Void

        private weak var observedWindow: NSWindow?
        private var monitor: Any?
        private var resetWorkItem: DispatchWorkItem?
        private var accumulator = HorizontalPageScrollAccumulator()

        init(onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
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
                self.handle(event)
                return event
            }
        }

        func handle(_ event: NSEvent) {
            // Momentum after the fingers lift belongs to the gesture that already paged.
            guard event.momentumPhase.isEmpty else { return }
            if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
                accumulator.endGesture()
            }

            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 40
            let direction = accumulator.process(
                deltaX: event.scrollingDeltaX * multiplier,
                deltaY: event.scrollingDeltaY * multiplier
            )
            switch direction {
            case .previous: onPrevious()
            case .next: onNext()
            case nil: break
            }

            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                accumulator.endGesture()
            } else if event.phase.isEmpty {
                resetWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.accumulator.endGesture()
                }
                resetWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
            }
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
