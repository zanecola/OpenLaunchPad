import AppKit
import Carbon
import SwiftUI

/// A small AppKit bridge that captures the hardware key code required by Carbon.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyCombo?

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(title: "", target: context.coordinator, action: #selector(Coordinator.beginRecording(_:)))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.onShortcut = { context.coordinator.shortcut.wrappedValue = $0 }
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.shortcut = $shortcut
        button.displayTitle = shortcut?.displayString ?? "Record Shortcut"
    }

    final class Coordinator: NSObject {
        var shortcut: Binding<KeyCombo?>

        init(shortcut: Binding<KeyCombo?>) {
            self.shortcut = shortcut
        }

        @objc func beginRecording(_ sender: ShortcutRecorderButton) {
            sender.beginRecording()
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var onShortcut: (KeyCombo) -> Void = { _ in }
    var displayTitle = "Record Shortcut" {
        didSet {
            if !isRecording { title = displayTitle }
        }
    }

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    func beginRecording() {
        isRecording = true
        title = "Type Shortcut"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            finishRecording()
            return
        }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 || Self.isFunctionKey(event.keyCode) else {
            NSSound.beep()
            return
        }

        onShortcut(KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        finishRecording()
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording {
            isRecording = false
            title = displayTitle
        }
        return result
    }

    private func finishRecording() {
        isRecording = false
        title = displayTitle
        window?.makeFirstResponder(nil)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12:
            return true
        default:
            return false
        }
    }
}
