import Foundation
import Observation

/// All user-configurable settings, backed by UserDefaults.
/// @Observable so SwiftUI views re-render automatically on any change. (ADR-4)
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    private let defaults: UserDefaults
    @ObservationIgnored var onGlobalShortcutChange: (() -> Void)?
    @ObservationIgnored var onMenuBarVisibilityChange: (() -> Void)?

    init(defaults: UserDefaults = UserDefaults(suiteName: "com.openlaunchpad") ?? .standard) {
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
    var backgroundBlur: Double = 20 {
        didSet { save(backgroundBlur, forKey: Keys.backgroundBlur) }
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
    // MARK: - Persistence helpers

    private enum Keys {
        static let iconSize = "iconSize"
        static let iconLabelVisible = "iconLabelVisible"
        static let gridColumns = "gridColumns"
        static let paneWidth = "paneWidth"
        static let paneHeight = "paneHeight"
        static let backgroundBlur = "backgroundBlur"
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
        if defaults.object(forKey: Keys.backgroundBlur) != nil {
            backgroundBlur = defaults.double(forKey: Keys.backgroundBlur)
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
            globalShortcut = sc
        }
        if defaults.object(forKey: Keys.animationSpeed) != nil {
            animationSpeed = defaults.double(forKey: Keys.animationSpeed)
        }
    }
}
