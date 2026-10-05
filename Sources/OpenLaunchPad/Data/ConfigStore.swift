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

    init(defaults: any KeyValueStoring = UserDefaults(suiteName: "com.openlaunchpad") ?? .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Settings (each triggers observation on write)

    var iconSize: Double = 80 {
        didSet { save(iconSize, forKey: Keys.iconSize) }
    }
    var iconLabelVisible: Bool = true {
        didSet { save(iconLabelVisible, forKey: Keys.iconLabelVisible) }
    }
    var gridColumns: Int = 7 {
        didSet { save(gridColumns, forKey: Keys.gridColumns) }
    }
    var paneWidth: Double = 860 {
        didSet { save(paneWidth, forKey: Keys.paneWidth) }
    }
    var paneHeight: Double = 620 {
        didSet { save(paneHeight, forKey: Keys.paneHeight) }
    }
    /// Opacity of the black layer over the full-screen blur.
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
    var showFrequentlyUsedApps: Bool = true {
        didSet { save(showFrequentlyUsedApps, forKey: Keys.showFrequentlyUsedApps) }
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
    static let animationSpeedRange: ClosedRange<Double> = 0.2...2.0

    /// Length of a launcher transition that takes `base` seconds at 1×; higher speeds are shorter.
    func animationDuration(_ base: Double) -> Double {
        base / animationSpeed
    }
    // MARK: - Persistence helpers

    private enum Keys {
        static let iconSize = "iconSize"
        static let iconLabelVisible = "iconLabelVisible"
        static let gridColumns = "gridColumns"
        static let paneWidth = "paneWidth"
        static let paneHeight = "paneHeight"
        static let backgroundDim = "backgroundDim"
        static let legacyBackgroundBlur = "backgroundBlur"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let showFrequentlyUsedApps = "showFrequentlyUsedApps"
        static let dockClickMode = "dockClickMode"
        static let globalShortcut = "globalShortcut"
        static let animationSpeed = "animationSpeed"
    }

    private func save<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func load() {
        if defaults.object(forKey: Keys.iconSize) != nil {
            iconSize = defaults.double(forKey: Keys.iconSize)
        }
        if defaults.object(forKey: Keys.iconLabelVisible) != nil {
            iconLabelVisible = defaults.bool(forKey: Keys.iconLabelVisible)
        }
        if defaults.object(forKey: Keys.gridColumns) != nil {
            let storedColumns = defaults.integer(forKey: Keys.gridColumns)
            gridColumns = storedColumns == 0 ? 0 : min(max(storedColumns, 4), 12)
        }
        if defaults.object(forKey: Keys.paneWidth) != nil {
            paneWidth = defaults.double(forKey: Keys.paneWidth)
        }
        if defaults.object(forKey: Keys.paneHeight) != nil {
            paneHeight = defaults.double(forKey: Keys.paneHeight)
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
        if defaults.object(forKey: Keys.showFrequentlyUsedApps) != nil {
            showFrequentlyUsedApps = defaults.bool(forKey: Keys.showFrequentlyUsedApps)
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
    }
}
