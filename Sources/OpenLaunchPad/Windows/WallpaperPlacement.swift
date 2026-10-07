import AppKit
import Observation

/// Which screen a launcher window is on, and where, so it draws that screen's wallpaper lined up
/// with the desktop under it.
@MainActor
@Observable
final class WallpaperPlacement {
    /// The display's UUID, which keys its render in `WallpaperProvider`; nil until the window is placed.
    private(set) var screenID: String?
    /// In points.
    private(set) var screenSize: CGSize = .zero
    /// The window's frame, in points from the screen's top-left corner.
    private(set) var frameInScreen: CGRect = .zero

    /// `screenFrame` and `windowFrame` are in AppKit's global coordinates. Changes only what
    /// changed, so placing the window where it was redraws nothing.
    func update(screenID: String, screenFrame: CGRect, windowFrame: CGRect) {
        let frame = WallpaperCrop.frameInScreen(windowFrame: windowFrame, screenFrame: screenFrame)
        if self.screenID != screenID { self.screenID = screenID }
        if screenSize != screenFrame.size { screenSize = screenFrame.size }
        if frameInScreen != frame { frameInScreen = frame }
    }

    func update(for window: NSWindow, on screen: NSScreen) {
        update(screenID: WallpaperScreen.id(of: screen), screenFrame: screen.frame, windowFrame: window.frame)
    }
}

/// Where a screen's wallpaper lies under a window on it, so the window can draw the part of the
/// picture that is under it, as if it were frosted glass over the desktop.
enum WallpaperCrop {
    /// The image aspect-filled and centered on the screen, as full screen draws it, in points from
    /// the screen's top-left corner.
    static func aspectFillRect(imageSize: CGSize, screenSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: screenSize) }
        let scale = max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (screenSize.width - size.width) / 2,
            y: (screenSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// A window's frame from its screen's top-left corner, as SwiftUI lays out, given both frames in
    /// AppKit's global coordinates, whose origin is the bottom left of the primary screen.
    static func frameInScreen(windowFrame: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: windowFrame.minX - screenFrame.minX,
            y: screenFrame.maxY - windowFrame.maxY,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    /// Where the window draws the image, in its own coordinates, so the picture lines up with the
    /// same picture filling the screen.
    static func imageRect(imageSize: CGSize, screenSize: CGSize, frameInScreen: CGRect) -> CGRect {
        aspectFillRect(imageSize: imageSize, screenSize: screenSize)
            .offsetBy(dx: -frameInScreen.minX, dy: -frameInScreen.minY)
    }
}
