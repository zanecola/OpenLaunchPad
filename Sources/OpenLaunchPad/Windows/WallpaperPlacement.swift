import AppKit
import Observation

/// Which screen a launcher window is on, so it draws that screen's wallpaper.
@MainActor
@Observable
final class WallpaperPlacement {
    /// The display's UUID, which keys its render in `WallpaperProvider`; nil until the window is placed.
    private(set) var screenID: String?

    /// Changes only what changed, so placing the window where it was redraws nothing.
    func update(screenID: String) {
        if self.screenID != screenID { self.screenID = screenID }
    }
}
