import AppKit
import Testing
@testable import OpenLaunchPad

@MainActor
struct TextCompositionTests {
    @Test
    func onlyMarkedTextInTheFocusedTextViewCounts() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        window.contentView = textView
        #expect(!TextComposition.isActive(in: nil))
        #expect(!TextComposition.isActive(in: window))

        #expect(window.makeFirstResponder(textView))
        textView.insertText("ji", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!TextComposition.isActive(in: window))

        // What an input method holds while the user is still typing Pinyin.
        textView.setMarkedText(
            "suan",
            selectedRange: NSRange(location: 4, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(TextComposition.isActive(in: window))

        textView.unmarkText()
        #expect(!TextComposition.isActive(in: window))
    }
}
