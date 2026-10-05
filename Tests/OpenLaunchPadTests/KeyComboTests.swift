import Carbon
import Testing
@testable import OpenLaunchPad

struct KeyComboTests {
    @Test
    func displayStringUsesReadableKeyNames() {
        #expect(KeyCombo(keyCode: 0x00, modifiers: UInt32(cmdKey)).displayString == "⌘A")
        #expect(KeyCombo(keyCode: 0x12, modifiers: UInt32(optionKey)).displayString == "⌥1")
        #expect(KeyCombo(keyCode: 0x24, modifiers: UInt32(controlKey)).displayString == "⌃Return")
        #expect(KeyCombo(keyCode: 0x7B, modifiers: UInt32(shiftKey)).displayString == "⇧←")
        #expect(KeyCombo(keyCode: 0x7A, modifiers: 0).displayString == "F1")
    }

    @Test
    func globalShortcutRequiresCommandOrControl() {
        let l = UInt32(kVK_ANSI_L)
        #expect(KeyCombo(keyCode: l, modifiers: UInt32(cmdKey)).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: l, modifiers: UInt32(controlKey)).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: l, modifiers: UInt32(cmdKey | shiftKey)).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: l, modifiers: UInt32(optionKey | controlKey)).isAllowedGlobalShortcut)
        #expect(KeyCombo(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | optionKey)
        ).isAllowedGlobalShortcut)
    }

    @Test
    func globalShortcutRejectsCombosThatType() {
        let l = UInt32(kVK_ANSI_L)
        #expect(!KeyCombo(keyCode: l, modifiers: 0).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: l, modifiers: UInt32(shiftKey)).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(optionKey)).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: l, modifiers: UInt32(optionKey | shiftKey)).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: UInt32(shiftKey)).isAllowedGlobalShortcut)
    }

    @Test
    func globalShortcutAllowsFunctionKeysWithAnyModifiers() {
        #expect(KeyCombo(keyCode: UInt32(kVK_F1), modifiers: 0).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: UInt32(kVK_F12), modifiers: 0).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: UInt32(kVK_F5), modifiers: UInt32(shiftKey)).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: UInt32(kVK_F5), modifiers: UInt32(optionKey)).isAllowedGlobalShortcut)
    }
}
