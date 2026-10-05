import SwiftUI
import AppKit

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

/// How a tile is drawn while it is pressed.
struct TileFeedback: Equatable {
    static let pressedScale: CGFloat = 0.92
    static let pressedBrightness = -0.15

    var scale: CGFloat = 1
    var brightness: Double = 0
}

extension TileFeedback {
    /// Reduce Motion keeps tiles at their size: a pressed tile only darkens.
    init(isPressed: Bool, reduceMotion: Bool) {
        if isPressed {
            brightness = Self.pressedBrightness
            if !reduceMotion { scale = Self.pressedScale }
        }
    }
}

extension View {
    /// Makes a launcher tile work like a button: it looks pressed while the pointer is down on it,
    /// and runs `action` on release (see `TilePress`). Apply it outside the tile's organization
    /// drag, so the press runs alongside the drag rather than after it fails.
    func launchpadTile(action: @escaping () -> Void) -> some View {
        modifier(LaunchpadTileModifier(action: action))
    }
}

private struct LaunchpadTileModifier: ViewModifier {
    let action: () -> Void

    @Environment(\.launchpadMotion) private var motion
    @GestureState private var press = TilePress()
    /// The gesture state is reset when the press ends, so the release reads the press from here.
    @State private var lastPress = PressRecord()

    func body(content: Content) -> some View {
        let feedback = TileFeedback(isPressed: press.isPressed, reduceMotion: motion.reduceMotion)

        content
            .scaleEffect(feedback.scale)
            .brightness(feedback.brightness)
            .animation(motion.tilePress(isPressed: press.isPressed), value: press)
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
