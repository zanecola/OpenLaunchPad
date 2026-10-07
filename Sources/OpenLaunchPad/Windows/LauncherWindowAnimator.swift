import AppKit
import QuartzCore

/// Which of a window's hide animations may still finish, and what runs when one does. Every show
/// and hide supersedes the animation before it, so a show during a hide cancels the hide.
struct WindowHideTracker {
    private var generation = 0
    private var completions: [() -> Void] = []
    private(set) var isHiding = false

    /// Starts a hide and returns the generation to finish it with, or nil when a hide is already
    /// running: `completion` then runs when that one finishes.
    mutating func beginHide(then completion: @escaping () -> Void) -> Int? {
        completions.append(completion)
        guard !isHiding else { return nil }
        isHiding = true
        generation += 1
        return generation
    }

    /// A show starts. A running hide never finishes and its completions never run.
    mutating func beginShow() -> Int {
        isHiding = false
        completions = []
        generation += 1
        return generation
    }

    func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation
    }

    /// The completions to run once hide `generation` has animated out, or nil when a show
    /// superseded it and the window stays up.
    mutating func finishHide(_ generation: Int) -> [() -> Void]? {
        guard isHiding, isCurrent(generation) else { return nil }
        isHiding = false
        defer { completions = [] }
        return completions
    }
}

/// Shows and hides a launcher window with a `WindowTransition`: the window's alpha fades and the
/// content view's layer scales, so no SwiftUI body runs per frame. A show while a hide is still
/// animating cancels the hide and turns back from wherever it got to.
@MainActor
final class LauncherWindowAnimator {
    private static let scaleKey = "launcherTransitionScale"

    private unowned let window: NSWindow
    /// The window server keeps a shadow's outline from before the content scaled, so the window
    /// drops its shadow while the content scales in.
    private let hasShadow: Bool
    private var tracker = WindowHideTracker()

    init(window: NSWindow) {
        self.window = window
        hasShadow = window.hasShadow
    }

    var isHiding: Bool {
        tracker.isHiding
    }

    /// While the window fades out the launcher is already closed, so typing, Return included,
    /// must not reach its search field. Menu shortcuts still work: they are handled before the
    /// window gets the event.
    func ignores(_ event: NSEvent) -> Bool {
        tracker.isHiding && (event.type == .keyDown || event.type == .keyUp)
    }

    /// `pivot` is the point of `content`, in its own coordinates, that stays put while it scales.
    /// `orderFront` orders the window in and gives it the keyboard.
    func show(_ transition: WindowTransition?, content: NSView?, pivot: CGPoint, orderFront: () -> Void) {
        let wasHiding = tracker.isHiding
        guard wasHiding || !window.isVisible else {
            // Already showing, or still animating in.
            orderFront()
            return
        }
        let generation = tracker.beginShow()
        window.ignoresMouseEvents = false
        window.canHide = true
        let layer = content?.layer
        guard let transition else {
            layer?.removeAnimation(forKey: Self.scaleKey)
            window.alphaValue = 1
            window.hasShadow = hasShadow
            orderFront()
            return
        }

        var scales = false
        if let layer {
            let from = wasHiding
                ? layer.presentation()?.transform ?? CATransform3DIdentity
                : Self.scaleTransform(transition.scale, of: layer, about: pivot)
            scales = !CATransform3DIsIdentity(from)
            if scales {
                layer.add(scaleAnimation(from: from, to: CATransform3DIdentity, transition), forKey: Self.scaleKey)
            } else {
                layer.removeAnimation(forKey: Self.scaleKey)
            }
        }
        if !wasHiding {
            window.alphaValue = 0
        }
        window.hasShadow = hasShadow && !scales
        orderFront()
        animateAlpha(to: 1, duration: transition.duration, curve: transition.curve) { [weak self] in
            guard let self, tracker.isCurrent(generation) else { return }
            window.hasShadow = hasShadow
        }
    }

    /// `completion` runs once the window is ordered out, at once if it is not on screen, and never
    /// if a show cancels the hide first.
    func hide(_ transition: WindowTransition?, content: NSView?, pivot: CGPoint, completion: @escaping () -> Void) {
        guard tracker.isHiding || window.isVisible else {
            // Hiding the app takes the window off screen but keeps it in the set an unhide brings
            // back. Ordering it out drops it from that set.
            window.orderOut(nil)
            completion()
            return
        }
        guard let generation = tracker.beginHide(then: completion) else { return }
        guard let transition else {
            finishHide(generation, content: content)
            return
        }
        // The launcher is already closed: clicks reach what is below, and the window stays on
        // screen when the app hides to hand activation back.
        window.ignoresMouseEvents = true
        window.canHide = false
        if let layer = content?.layer, transition.scale != 1 {
            let from = layer.presentation()?.transform ?? CATransform3DIdentity
            let to = Self.scaleTransform(transition.scale, of: layer, about: pivot)
            let animation = scaleAnimation(from: from, to: to, transition)
            // Holds the end until the window is ordered out.
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: Self.scaleKey)
        }
        animateAlpha(to: 0, duration: transition.duration, curve: transition.curve) { [weak self] in
            self?.finishHide(generation, content: content)
        }
    }

    private func finishHide(_ generation: Int, content: NSView?) {
        guard let completions = tracker.finishHide(generation) else { return }
        window.orderOut(nil)
        content?.layer?.removeAnimation(forKey: Self.scaleKey)
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        window.canHide = true
        completions.forEach { $0() }
    }

    /// A new alpha animation, or setting the alpha, stops the one running, whose completion then
    /// runs at once.
    private func animateAlpha(
        to alpha: CGFloat,
        duration: Double,
        curve: WindowTransition.Curve,
        completion: @escaping () -> Void
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = curve.timingFunction
            window.animator().alphaValue = alpha
        } completionHandler: {
            MainActor.assumeIsolated(completion)
        }
    }

    private func scaleAnimation(from: CATransform3D, to: CATransform3D, _ transition: WindowTransition) -> CABasicAnimation {
        let animation: CABasicAnimation
        if let spring = transition.spring {
            let springAnimation = CASpringAnimation(perceptualDuration: spring.response, bounce: 1 - spring.dampingFraction)
            springAnimation.duration = springAnimation.settlingDuration
            animation = springAnimation
        } else {
            animation = CABasicAnimation()
            animation.duration = transition.duration
            animation.timingFunction = transition.curve.timingFunction
        }
        animation.keyPath = "transform"
        animation.fromValue = NSValue(caTransform3D: from)
        animation.toValue = NSValue(caTransform3D: to)
        return animation
    }

    /// Scales `layer` by `scale` about `pivot`, a point in the layer's own coordinates. Its
    /// transform applies about its position in the superlayer's space, which can run the other way
    /// up: a hosting view's layer is flipped and its superlayer is not.
    static func scaleTransform(_ scale: CGFloat, of layer: CALayer, about pivot: CGPoint) -> CATransform3D {
        guard scale != 1, let superlayer = layer.superlayer else { return CATransform3DIdentity }
        return scaleTransform(scale, about: superlayer.convert(pivot, from: layer), position: layer.position)
    }

    /// Scales by `scale` about `pivot` for a layer at `position`, both in the superlayer's space.
    static func scaleTransform(_ scale: CGFloat, about pivot: CGPoint, position: CGPoint) -> CATransform3D {
        let offset = CGPoint(x: pivot.x - position.x, y: pivot.y - position.y)
        return CATransform3DMakeAffineTransform(
            CGAffineTransform(translationX: offset.x, y: offset.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -offset.x, y: -offset.y)
        )
    }
}

private extension WindowTransition.Curve {
    var timingFunction: CAMediaTimingFunction {
        switch self {
        case .easeOut: CAMediaTimingFunction(name: .easeOut)
        case .easeIn: CAMediaTimingFunction(name: .easeIn)
        }
    }
}
