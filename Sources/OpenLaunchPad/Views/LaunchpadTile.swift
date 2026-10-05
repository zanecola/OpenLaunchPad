import SwiftUI
import AppKit

extension EnvironmentValues {
    /// Full screen leaves it off, as Launchpad had no hover effect; the popup sets it from its setting.
    @Entry var launchpadTileHoverEffect: TileHoverEffect = .off
}

/// A press on a tile, which works like a button's click: the tile looks pressed from mouse-down
/// and opens on mouse-up. Moving the pointer as far as a drag needs to start ends the click, on
/// tiles that can't be dragged too and even if the pointer comes back; so does Control, since a
/// Control-click opens the context menu.
struct TilePress: Equatable {
    private(set) var isPressed = false
    private var isCancelled = false

    /// `translation` is how far the pointer is from where the press began.
    mutating func track(_ translation: CGSize, isControlClick: Bool) {
        let distance = hypot(translation.width, translation.height)
        if isControlClick || distance >= LaunchpadDragGestureModifier.minimumDistance {
            isCancelled = true
        }
        isPressed = !isCancelled
    }

    /// Whether the press opens the tile when it is released `translation` from where it began.
    func opens(releasedAt translation: CGSize) -> Bool {
        var released = self
        released.track(translation, isControlClick: false)
        return released.isPressed
    }
}

/// How a tile is drawn while it is pressed or under the pointer.
struct TileFeedback: Equatable {
    static let pressedScale: CGFloat = 0.92
    static let pressedBrightness = -0.15
    static let liftScale: CGFloat = 1.04
    /// How far the hover highlight reaches past the tile.
    static let highlightOutset: CGFloat = 6

    var scale: CGFloat = 1
    var brightness: Double = 0
    var showsHighlight = false
}

extension TileFeedback {
    /// Reduce Motion keeps tiles at their size: a pressed tile only darkens, and Lift shows nothing.
    init(isPressed: Bool, isHovered: Bool, hoverEffect: TileHoverEffect, reduceMotion: Bool) {
        if isPressed {
            brightness = Self.pressedBrightness
            if !reduceMotion { scale = Self.pressedScale }
        } else if isHovered && hoverEffect == .lift && !reduceMotion {
            scale = Self.liftScale
        }
        showsHighlight = isHovered && hoverEffect == .highlight
    }
}

extension View {
    /// Makes a launcher tile work like a button: it looks pressed while the pointer is down on it,
    /// runs `action` on release (see `TilePress`), and shows the popup's hover effect. Apply it
    /// outside the tile's organization drag, so the press runs alongside the drag rather than
    /// after it fails.
    func launchpadTile(showsHover: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(LaunchpadTileModifier(showsHover: showsHover, action: action))
    }
}

private struct LaunchpadTileModifier: ViewModifier {
    let showsHover: Bool
    let action: () -> Void

    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(LaunchpadDragState.self) private var dragState
    @Environment(\.launchpadTileHoverEffect) private var hoverEffect
    @Environment(\.launchpadMotion) private var motion
    @GestureState private var press = TilePress()
    /// The gesture state is reset when the press ends, so the release reads the press from here.
    @State private var lastPress = PressRecord()
    @State private var hover = LauncherHover()

    func body(content: Content) -> some View {
        // Reads the presentation and the drag only while hovered, so they re-render just this tile.
        let isHovered = hoverEffect != .off && showsHover
            && hover.isActive(in: vm.presentationID) && !dragState.isDragging
        let feedback = TileFeedback(
            isPressed: press.isPressed,
            isHovered: isHovered,
            hoverEffect: hoverEffect,
            reduceMotion: motion.reduceMotion
        )

        content
            .background {
                ZStack {
                    if feedback.showsHighlight {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .padding(-TileFeedback.highlightOutset)
                            .transition(.opacity)
                    }
                }
            }
            .scaleEffect(feedback.scale)
            .brightness(feedback.brightness)
            .animation(motion.tileHover, value: hover)
            .animation(motion.tilePress(isPressed: press.isPressed), value: press)
            .onHover { hover.update(isHovering: $0, presentationID: vm.presentationID) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($press) { value, press, _ in
                        press.track(value.translation, isControlClick: NSEvent.modifierFlags.contains(.control))
                        lastPress.press = press
                    }
                    .onEnded { value in
                        if lastPress.press.opens(releasedAt: value.translation) { action() }
                    }
            )
    }
}

private final class PressRecord {
    var press = TilePress()
}
