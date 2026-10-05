import Carbon
import Foundation
import Testing
@testable import OpenLaunchPad

struct ConfigStoreTests {
    @Test
    func legacyColumnPreferenceIsNormalizedIntoSupportedRange() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(2, forKey: "gridColumns")

        let config = ConfigStore(defaults: defaults)

        #expect(config.gridColumns == 4)
        #expect(defaults.integer(forKey: "gridColumns") == 4)
    }

    @Test
    func freshSettingsUseTheLaunchpadGrid() {
        let config = ConfigStore(defaults: InMemoryKeyValueStore())

        #expect(config.gridColumns == 7)
        #expect(config.gridRows == 5)
        #expect(config.pageCapacity == 35)
    }

    @Test
    func columnsSavedBeforeRowsExistedAreKept() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(11, forKey: "gridColumns")

        let config = ConfigStore(defaults: defaults)

        #expect(config.gridColumns == 11)
        #expect(config.gridRows == 5)
        #expect(config.pageCapacity == 55)
    }

    @Test
    func automaticColumnsBecomeTheDefaultSeven() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(0, forKey: "gridColumns")

        #expect(ConfigStore(defaults: defaults).gridColumns == 7)
        #expect(defaults.integer(forKey: "gridColumns") == 7)
    }

    @Test
    func storedRowsAreClampedIntoTheSupportedRange() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(9, forKey: "gridRows")

        #expect(ConfigStore(defaults: defaults).gridRows == 7)

        defaults.set(1, forKey: "gridRows")

        #expect(ConfigStore(defaults: defaults).gridRows == 4)
    }

    @Test
    func gridChangesPersistAndNotify() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        var notificationCount = 0
        config.onPageCapacityChange = {
            notificationCount += 1
        }

        config.gridColumns = 8
        config.gridRows = 6

        #expect(notificationCount == 2)
        #expect(config.pageCapacity == 48)
        #expect(ConfigStore(defaults: defaults).pageCapacity == 48)
    }

    @Test
    func menuBarVisibilityChangesPersistAndNotify() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        var notificationCount = 0
        config.onMenuBarVisibilityChange = {
            notificationCount += 1
        }

        config.showMenuBarIcon = false

        #expect(defaults.bool(forKey: "showMenuBarIcon") == false)
        #expect(notificationCount == 1)
    }

    @Test
    func shortcutChangesPersistAndNotify() throws {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        var notificationCount = 0
        config.onGlobalShortcutChange = {
            notificationCount += 1
        }
        let shortcut = KeyCombo(keyCode: 0x00, modifiers: UInt32(cmdKey))

        config.globalShortcut = shortcut

        let storedData = try #require(defaults.data(forKey: "globalShortcut"))
        #expect(try JSONDecoder().decode(KeyCombo.self, from: storedData) == shortcut)
        #expect(notificationCount == 1)

        config.globalShortcut = nil

        #expect(defaults.data(forKey: "globalShortcut") == nil)
        #expect(notificationCount == 2)
    }

    @Test
    func storedShortcutThatWouldTypeIsDroppedOnLoad() throws {
        let defaults = InMemoryKeyValueStore()
        let shiftL = KeyCombo(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(shiftKey))
        defaults.set(try JSONEncoder().encode(shiftL), forKey: "globalShortcut")

        let config = ConfigStore(defaults: defaults)

        #expect(config.globalShortcut == nil)
        #expect(defaults.data(forKey: "globalShortcut") == nil)
    }

    @Test
    func storedValidShortcutIsKeptOnLoad() throws {
        let defaults = InMemoryKeyValueStore()
        let commandShiftL = KeyCombo(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | shiftKey))
        defaults.set(try JSONEncoder().encode(commandShiftL), forKey: "globalShortcut")

        #expect(ConfigStore(defaults: defaults).globalShortcut == commandShiftL)
    }

    @Test
    func fasterAnimationSpeedShortensTransitions() {
        let config = ConfigStore(defaults: InMemoryKeyValueStore())

        config.animationSpeed = 2
        #expect(config.animationDuration(0.3) == 0.15)

        config.animationSpeed = 0.5
        #expect(config.animationDuration(0.3) == 0.6)
    }

    @Test
    func turningTransitionsOffRemovesTheirAnimationAndPersists() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        #expect(config.animatesTransitions)

        config.animatesTransitions = false

        #expect(config.animationDuration(0.3) == nil)
        #expect(ConfigStore(defaults: defaults).animatesTransitions == false)
    }

    @Test
    func storedAnimationSpeedIsClampedIntoSupportedRange() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(0.2, forKey: "animationSpeed")

        #expect(ConfigStore(defaults: defaults).animationSpeed == 0.5)

        defaults.set(10, forKey: "animationSpeed")

        #expect(ConfigStore(defaults: defaults).animationSpeed == ConfigStore.animationSpeedRange.upperBound)
    }

    @Test
    func backgroundDimDefaultsToAQuarter() {
        #expect(ConfigStore(defaults: InMemoryKeyValueStore()).backgroundDim == 0.25)
    }

    @Test(arguments: [
        (-10.0, 0.14),
        (0.0, 0.14),
        (30.0, 0.20),
        (60.0, 0.26),
        (90.0, 0.26)
    ])
    func legacyBlurIsMigratedOnceToTheDimItDrew(blur: Double, expectedDim: Double) {
        let defaults = InMemoryKeyValueStore()
        defaults.set(blur, forKey: "backgroundBlur")

        let config = ConfigStore(defaults: defaults)

        #expect(abs(config.backgroundDim - expectedDim) < 0.000_001)
        #expect(abs(defaults.double(forKey: "backgroundDim") - expectedDim) < 0.000_001)
        #expect(defaults.object(forKey: "backgroundBlur") == nil)
    }

    @Test
    func storedDimWinsOverLegacyBlurAndIsClamped() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(60.0, forKey: "backgroundBlur")
        defaults.set(0.9, forKey: "backgroundDim")

        #expect(ConfigStore(defaults: defaults).backgroundDim == ConfigStore.backgroundDimRange.upperBound)
    }

    @Test
    func popupAppearanceFollowsTheSystemByDefaultAndPersists() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        #expect(config.popupAppearance == .system)

        config.popupAppearance = .dark

        #expect(defaults.string(forKey: "popupAppearance") == "Dark")
        #expect(ConfigStore(defaults: defaults).popupAppearance == .dark)
    }

    @Test
    func unknownStoredPopupAppearanceFallsBackToSystem() {
        let defaults = InMemoryKeyValueStore()
        defaults.set("Sepia", forKey: "popupAppearance")

        #expect(ConfigStore(defaults: defaults).popupAppearance == .system)
    }

    @Test
    func storedIconSizeIsClampedIntoTheSliderRange() {
        let defaults = InMemoryKeyValueStore()
        defaults.set(1e9, forKey: "iconSize")

        #expect(ConfigStore(defaults: defaults).iconSize == ConfigStore.iconSizeRange.upperBound)

        defaults.set(10, forKey: "iconSize")

        #expect(ConfigStore(defaults: defaults).iconSize == ConfigStore.iconSizeRange.lowerBound)
    }

    @Test
    func fullScreenKeepsTheDockAndMenuBarByDefault() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)
        #expect(!config.autoHidesDockAndMenuBar)

        config.autoHidesDockAndMenuBar = true

        #expect(ConfigStore(defaults: defaults).autoHidesDockAndMenuBar)
    }

    @Test
    func frequentlyUsedAppsVisibilityPersists() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)

        config.showFrequentlyUsedApps = false

        #expect(defaults.bool(forKey: "showFrequentlyUsedApps") == false)
        #expect(ConfigStore(defaults: defaults).showFrequentlyUsedApps == false)
    }
}
