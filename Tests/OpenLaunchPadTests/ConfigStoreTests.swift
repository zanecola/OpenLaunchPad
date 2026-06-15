import Carbon
import Foundation
import Testing
@testable import OpenLaunchPad

struct ConfigStoreTests {
    @Test
    func menuBarVisibilityChangesPersistAndNotify() throws {
        let suiteName = "OpenLaunchPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
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
        let suiteName = "OpenLaunchPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
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
}
