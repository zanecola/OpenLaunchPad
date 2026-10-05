import Foundation
import Observation

/// All user-configurable settings, backed by UserDefaults.
/// @Observable so SwiftUI views re-render automatically on any change. (ADR-4)
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    private let defaults: any KeyValueStoring
    @ObservationIgnored var onGlobalShortcutChange: (() -> Void)?
    @ObservationIgnored var onMenuBarVisibilityChange: (() -> Void)?
    @ObservationIgnored var onPageCapacityChange: (() -> Void)?
    @ObservationIgnored var onWallpaperSettingsChange: (() -> Void)?

    init(defaults: any KeyValueStoring = UserDefaults(suiteName: "com.openlaunchpad") ?? .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Settings (each triggers observation on write)

    /// Automatic sizes full-screen icons to their slots.
    var iconSizeMode: IconSizeMode = .automatic {
        didSet { defaults.set(iconSizeMode.rawValue, forKey: Keys.iconSizeMode) }
    }
    /// Used while the mode is Custom, and kept while it is Automatic.
    var customIconSize: Double = 80 {
        didSet { save(customIconSize, forKey: Keys.iconSize) }
    }
    static let iconSizeRange: ClosedRange<Double> = 48...160
    /// The popup has no slots to size icons to, so Automatic keeps it at the old default.
    var popupIconSize: Double {
        iconSizeMode == .custom ? customIconSize : 80
    }
    var iconLabelVisible: Bool = true {
        didSet { save(iconLabelVisible, forKey: Keys.iconLabelVisible) }
    }
    /// The full-screen page is a grid of gridColumns × gridRows slots.
    var gridColumns: Int = 7 {
        didSet {
            save(gridColumns, forKey: Keys.gridColumns)
            onPageCapacityChange?()
        }
    }
    static let gridColumnRange: ClosedRange<Int> = 4...12
    var gridRows: Int = 5 {
        didSet {
            save(gridRows, forKey: Keys.gridRows)
            onPageCapacityChange?()
        }
    }
    static let gridRowRange: ClosedRange<Int> = 4...7
    /// How many items a page holds.
    var pageCapacity: Int {
        gridColumns * gridRows
    }
    /// While full screen is open; off keeps the Dock and menu bar, as Launchpad did.
    var autoHidesDockAndMenuBar: Bool = false {
        didSet { save(autoHidesDockAndMenuBar, forKey: Keys.autoHidesDockAndMenuBar) }
    }
    var paneWidth: Double = 860 {
        didSet { save(paneWidth, forKey: Keys.paneWidth) }
    }
    var paneHeight: Double = 620 {
        didSet { save(paneHeight, forKey: Keys.paneHeight) }
    }
    var popupAppearance: PopupAppearance = .system {
        didSet { defaults.set(popupAppearance.rawValue, forKey: Keys.popupAppearance) }
    }
    var backgroundStyle: BackdropStyle = .wallpaper {
        didSet {
            defaults.set(backgroundStyle.rawValue, forKey: Keys.backgroundStyle)
            onWallpaperSettingsChange?()
        }
    }
    /// How far Wallpaper blurs the desktop picture, in points.
    var backgroundBlurRadius: Double = 48 {
        didSet {
            save(backgroundBlurRadius, forKey: Keys.backgroundBlurRadius)
            onWallpaperSettingsChange?()
        }
    }
    static let backgroundBlurRadiusRange: ClosedRange<Double> = 0...80
    /// Opacity of the black layer over the full-screen wallpaper or glass.
    var backgroundDim: Double = 0.25 {
        didSet { save(backgroundDim, forKey: Keys.backgroundDim) }
    }
    static let backgroundDimRange: ClosedRange<Double> = 0...0.6

    /// The dim that the old 0-60 "Blur intensity" value drew over its faded blur.
    static func backgroundDim(fromLegacyBlur blur: Double) -> Double {
        0.14 + 0.12 * min(max(blur / 60, 0), 1)
    }
    var showMenuBarIcon: Bool = true {
        didSet {
            save(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            onMenuBarVisibilityChange?()
        }
    }
    var frequentlyUsedPlacement: FrequentlyUsedPlacement = .popupAndFullScreen {
        didSet { defaults.set(frequentlyUsedPlacement.rawValue, forKey: Keys.frequentlyUsedPlacement) }
    }
    var dockClickMode: DockClickMode = .fullScreen {
        didSet { defaults.set(dockClickMode.rawValue, forKey: Keys.dockClickMode) }
    }
    var globalShortcut: KeyCombo? = nil {
        didSet {
            if let sc = globalShortcut, let data = try? JSONEncoder().encode(sc) {
                defaults.set(data, forKey: Keys.globalShortcut)
            } else {
                defaults.removeObject(forKey: Keys.globalShortcut)
            }
            onGlobalShortcutChange?()
        }
    }
    var animationSpeed: Double = 1.0 {
        didSet { save(animationSpeed, forKey: Keys.animationSpeed) }
    }
    static let animationSpeedRange: ClosedRange<Double> = 0.5...2.0
    /// Off turns pages and opens folders without a transition.
    var animatesTransitions: Bool = true {
        didSet { save(animatesTransitions, forKey: Keys.animatesTransitions) }
    }

    /// Length of a launcher transition that takes `base` seconds at 1×; higher speeds are shorter.
    /// nil when transitions are off.
    func animationDuration(_ base: Double) -> Double? {
        animatesTransitions ? base / animationSpeed : nil
    }
    // MARK: - Persistence helpers

    private enum Keys {
        static let iconSizeMode = "iconSizeMode"
        static let iconSize = "iconSize"
        static let iconLabelVisible = "iconLabelVisible"
        static let gridColumns = "gridColumns"
        static let gridRows = "gridRows"
        static let autoHidesDockAndMenuBar = "autoHidesDockAndMenuBar"
        static let paneWidth = "paneWidth"
        static let paneHeight = "paneHeight"
        static let popupAppearance = "popupAppearance"
        static let backgroundStyle = "backgroundStyle"
        static let backgroundBlurRadius = "backgroundBlurRadius"
        static let backgroundDim = "backgroundDim"
        static let legacyBackgroundBlur = "backgroundBlur"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let frequentlyUsedPlacement = "frequentlyUsedPlacement"
        static let legacyShowFrequentlyUsedApps = "showFrequentlyUsedApps"
        static let dockClickMode = "dockClickMode"
        static let globalShortcut = "globalShortcut"
        static let animationSpeed = "animationSpeed"
        static let animatesTransitions = "animatesTransitions"
    }

    private func save<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func load() {
        if defaults.object(forKey: Keys.iconSize) != nil {
            let storedSize = defaults.double(forKey: Keys.iconSize)
            customIconSize = min(max(storedSize, Self.iconSizeRange.lowerBound), Self.iconSizeRange.upperBound)
        }
        if let raw = defaults.string(forKey: Keys.iconSizeMode),
           let mode = IconSizeMode(rawValue: raw) {
            iconSizeMode = mode
        } else if defaults.object(forKey: Keys.iconSize) != nil {
            // A size saved before Automatic existed was picked on the slider, so it stays in use.
            iconSizeMode = .custom
        }
        if defaults.object(forKey: Keys.iconLabelVisible) != nil {
            iconLabelVisible = defaults.bool(forKey: Keys.iconLabelVisible)
        }
        if defaults.object(forKey: Keys.gridColumns) != nil {
            let storedColumns = defaults.integer(forKey: Keys.gridColumns)
            // 0 was the old Automatic; pages now have a fixed number of slots, so it takes the default.
            gridColumns = storedColumns == 0
                ? 7
                : min(max(storedColumns, Self.gridColumnRange.lowerBound), Self.gridColumnRange.upperBound)
        }
        if defaults.object(forKey: Keys.gridRows) != nil {
            let storedRows = defaults.integer(forKey: Keys.gridRows)
            gridRows = min(max(storedRows, Self.gridRowRange.lowerBound), Self.gridRowRange.upperBound)
        }
        if defaults.object(forKey: Keys.autoHidesDockAndMenuBar) != nil {
            autoHidesDockAndMenuBar = defaults.bool(forKey: Keys.autoHidesDockAndMenuBar)
        }
        if defaults.object(forKey: Keys.paneWidth) != nil {
            paneWidth = defaults.double(forKey: Keys.paneWidth)
        }
        if defaults.object(forKey: Keys.paneHeight) != nil {
            paneHeight = defaults.double(forKey: Keys.paneHeight)
        }
        if let raw = defaults.string(forKey: Keys.popupAppearance),
           let appearance = PopupAppearance(rawValue: raw) {
            popupAppearance = appearance
        }
        if let raw = defaults.string(forKey: Keys.backgroundStyle),
           let style = BackdropStyle(rawValue: raw) {
            backgroundStyle = style
        }
        if defaults.object(forKey: Keys.backgroundBlurRadius) != nil {
            let storedRadius = defaults.double(forKey: Keys.backgroundBlurRadius)
            backgroundBlurRadius = min(max(storedRadius, Self.backgroundBlurRadiusRange.lowerBound), Self.backgroundBlurRadiusRange.upperBound)
        }
        if defaults.object(forKey: Keys.backgroundDim) != nil {
            let storedDim = defaults.double(forKey: Keys.backgroundDim)
            backgroundDim = min(max(storedDim, Self.backgroundDimRange.lowerBound), Self.backgroundDimRange.upperBound)
        } else if defaults.object(forKey: Keys.legacyBackgroundBlur) != nil {
            backgroundDim = Self.backgroundDim(fromLegacyBlur: defaults.double(forKey: Keys.legacyBackgroundBlur))
            defaults.removeObject(forKey: Keys.legacyBackgroundBlur)
        }
        if defaults.object(forKey: Keys.showMenuBarIcon) != nil {
            showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        }
        if let raw = defaults.string(forKey: Keys.frequentlyUsedPlacement),
           let placement = FrequentlyUsedPlacement(rawValue: raw) {
            frequentlyUsedPlacement = placement
        } else if defaults.object(forKey: Keys.legacyShowFrequentlyUsedApps) != nil {
            // The old on/off switch showed the row on both surfaces.
            frequentlyUsedPlacement = defaults.bool(forKey: Keys.legacyShowFrequentlyUsedApps) ? .popupAndFullScreen : .off
            defaults.removeObject(forKey: Keys.legacyShowFrequentlyUsedApps)
        }
        if let raw = defaults.string(forKey: Keys.dockClickMode),
           let mode = DockClickMode(rawValue: raw) {
            dockClickMode = mode
        }
        if let data = defaults.data(forKey: Keys.globalShortcut),
           let sc = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            // Drops a Shift- or Option-only combo saved before validation existed.
            globalShortcut = sc.isAllowedGlobalShortcut ? sc : nil
        }
        if defaults.object(forKey: Keys.animationSpeed) != nil {
            let storedSpeed = defaults.double(forKey: Keys.animationSpeed)
            animationSpeed = min(max(storedSpeed, Self.animationSpeedRange.lowerBound), Self.animationSpeedRange.upperBound)
        }
        if defaults.object(forKey: Keys.animatesTransitions) != nil {
            animatesTransitions = defaults.bool(forKey: Keys.animatesTransitions)
        }
    }
}
