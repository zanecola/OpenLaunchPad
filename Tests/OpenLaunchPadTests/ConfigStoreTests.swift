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
    func frequentlyUsedAppsVisibilityPersists() {
        let defaults = InMemoryKeyValueStore()
        let config = ConfigStore(defaults: defaults)

        config.showFrequentlyUsedApps = false

        #expect(defaults.bool(forKey: "showFrequentlyUsedApps") == false)
        #expect(ConfigStore(defaults: defaults).showFrequentlyUsedApps == false)
    }
}
