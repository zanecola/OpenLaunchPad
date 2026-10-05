import SwiftUI

/// The launcher's one motion policy, for SwiftUI animations and the windows' own transitions alike.
/// Animate transitions off makes every transition instant, the speed divides durations, and Reduce
/// Motion keeps fades but drops zooming and sliding.
struct LaunchpadMotion: Equatable, Sendable {
    var animatesTransitions = true
    /// Higher is faster.
    var speed: Double = 1
    var reduceMotion = false

    init(animatesTransitions: Bool = true, speed: Double = 1, reduceMotion: Bool = false) {
        self.animatesTransitions = animatesTransitions
        self.speed = speed
        self.reduceMotion = reduceMotion
    }

    init(config: ConfigStore, reduceMotion: Bool) {
        self.init(animatesTransitions: config.animatesTransitions, speed: config.animationSpeed, reduceMotion: reduceMotion)
    }

    /// How long a transition that takes `base` seconds at 1x lasts; nil when transitions are off.
    func duration(_ base: Double) -> Double? {
        animatesTransitions ? base / speed : nil
    }

    /// For a fade, or for an insertion whose transition goes through `transition(_:)`: Reduce
    /// Motion keeps it.
    func animation(_ base: Double, _ curve: (Double) -> Animation) -> Animation? {
        duration(base).map(curve)
    }

    /// For something that moves or resizes: Reduce Motion removes it.
    func movement(_ base: Double, _ curve: (Double) -> Animation) -> Animation? {
        reduceMotion ? nil : animation(base, curve)
    }

    /// Reduce Motion keeps only the fade.
    func transition(_ transition: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// A page turn from the keys, a dot or the wheel, in the grid or in a folder.
    var pageTurn: Animation? {
        movement(0.38) { .spring(response: $0, dampingFraction: 0.9) }
    }

    /// An open folder grows out of its tile and shrinks back into it on a spring; under Reduce
    /// Motion it crossfades instead.
    var folderZoom: Animation? {
        movement(0.35) { .spring(response: $0, dampingFraction: 0.86) } ?? animation(0.22) { .easeInOut(duration: $0) }
    }

    /// The dim and blur behind an open folder.
    var folderBackdropFade: Animation? {
        animation(0.22) { .easeOut(duration: $0) }
    }

    // MARK: - Launcher windows

    /// Full screen fades in while its content settles from 1.06x, as Launchpad zoomed its icons into place.
    var fullScreenShow: WindowTransition? {
        window(0.18, .easeOut, scale: 1.06, spring: WindowTransition.Spring(response: 0.32, dampingFraction: 0.88))
    }

    /// Escape, a background click, a toggle, or another app or window taking over.
    var fullScreenClose: WindowTransition? {
        window(0.14, .easeIn, scale: 1.04)
    }

    /// Only a short fade, so the launcher is gone by the time the app it opened shows a window.
    var fullScreenLaunch: WindowTransition? {
        window(0.12, .easeIn)
    }

    /// Grows from where it was opened: the status item, or the pointer on the Dock.
    var popupShow: WindowTransition? {
        window(0.16, .easeOut, scale: 0.96)
    }

    var popupClose: WindowTransition? {
        window(0.12, .easeIn)
    }

    private func window(
        _ base: Double,
        _ curve: WindowTransition.Curve,
        scale: CGFloat = 1,
        spring: WindowTransition.Spring? = nil
    ) -> WindowTransition? {
        guard let duration = duration(base) else { return nil }
        guard !reduceMotion else { return WindowTransition(duration: duration, curve: curve) }
        return WindowTransition(
            duration: duration,
            curve: curve,
            scale: scale,
            spring: spring.map { WindowTransition.Spring(response: $0.response / speed, dampingFraction: $0.dampingFraction) }
        )
    }
}

/// How a launcher window comes or goes: its alpha fades over `duration` on `curve`, while its
/// content scales from `scale` on the way in, or to it on the way out.
struct WindowTransition: Equatable, Sendable {
    enum Curve: Sendable {
        case easeOut
        case easeIn
    }

    /// As SwiftUI's `spring(response:dampingFraction:)`.
    struct Spring: Equatable, Sendable {
        var response: Double
        var dampingFraction: Double
    }

    var duration: Double
    var curve: Curve
    /// 1 fades without scaling.
    var scale: CGFloat = 1
    /// Settles the scale on the way in, in place of `curve`.
    var spring: Spring? = nil
}

extension EnvironmentValues {
    @Entry var launchpadMotion = LaunchpadMotion()
}

extension View {
    /// Gives the launcher's views the motion policy, from the settings and Reduce Motion.
    func launchpadMotion() -> some View {
        modifier(LaunchpadMotionEnvironment())
    }
}

private struct LaunchpadMotionEnvironment: ViewModifier {
    @Environment(ConfigStore.self) private var config
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(\.launchpadMotion, LaunchpadMotion(config: config, reduceMotion: reduceMotion))
    }
}
