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
}
