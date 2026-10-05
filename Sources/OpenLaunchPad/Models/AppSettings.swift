import Foundation
import Carbon

enum DockClickMode: String, Codable, CaseIterable, Sendable {
    case fullScreen = "Full Screen"
    case popup = "Popup"
}

enum PopupAppearance: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum IconSizeMode: String, CaseIterable, Sendable {
    case automatic = "Automatic"
    case custom = "Custom"
}

/// Where the Frequently Used apps appear.
enum FrequentlyUsedPlacement: String, CaseIterable, Sendable {
    case off = "Off"
    case popupOnly = "Popup Only"
    case popupAndFullScreen = "Popup and Full Screen"

    var showsInPopup: Bool { self != .off }
    var showsInFullScreen: Bool { self == .popupAndFullScreen }
}

/// What full screen's page control shows.
enum PageControlStyle: String, CaseIterable, Sendable {
    /// Only the dots, as Launchpad drew them.
    case dots = "Dots"
    /// The dots, with previous and next arrows while the pointer is over them.
    case dotsAndArrows = "Dots + Arrows"

    func showsArrows(whileHovered isHovered: Bool) -> Bool {
        self == .dotsAndArrows && isHovered
    }
}

/// What a popup tile shows while the pointer is over it. Full screen shows nothing, as Launchpad did.
enum TileHoverEffect: String, CaseIterable, Sendable {
    case off = "None"
    /// A rounded plate behind the tile.
    case highlight = "Highlight"
    /// The tile grows slightly.
    case lift = "Lift"
}

/// What full screen draws behind its content.
enum BackdropStyle: String, CaseIterable, Sendable {
    /// The desktop picture, blurred.
    case wallpaper = "Wallpaper"
    /// The material that blurs the windows and desktop behind full screen.
    case glass = "Glass"
    case solid = "Solid"

    /// What full screen draws for this choice. The rendered wallpaper is opaque, so it stays
    /// under Reduce Transparency; Glass does not. Without a usable wallpaper, Wallpaper falls
    /// back as Glass does.
    func resolved(reduceTransparency: Bool, wallpaperAvailable: Bool) -> BackdropStyle {
        switch self {
        case .wallpaper where wallpaperAvailable: .wallpaper
        case .wallpaper, .glass: reduceTransparency ? .solid : .glass
        case .solid: .solid
        }
    }
}

enum LaunchpadSortOrder: Sendable {
    case ascending
    case descending
}

struct KeyCombo: Codable, Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32  // Carbon modifier flags

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyCode.keyDisplayName)
        return parts.joined()
    }

    /// A global hotkey swallows its keystroke in every app, so it must not be something people
    /// type: Shift- or Option-only combos produce text. Require Command or Control, except for
    /// function keys, which never type.
    var isAllowedGlobalShortcut: Bool {
        Self.isFunctionKey(keyCode) || modifiers & UInt32(cmdKey | controlKey) != 0
    }

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        switch Int(keyCode) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
             kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            return true
        default:
            return false
        }
    }
}

private extension UInt32 {
    var keyDisplayName: String {
        switch self {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x24: return "Return"
        case 0x30: return "Tab"
        case 0x31: return "Space"
        case 0x33: return "Delete"
        case 0x35: return "Escape"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        case 0x69: return "F13"
        case 0x6B: return "F14"
        case 0x71: return "F15"
        case 0x6A: return "F16"
        case 0x40: return "F17"
        case 0x4F: return "F18"
        case 0x50: return "F19"
        case 0x5A: return "F20"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        default: return "(\(self))"
        }
    }
}
