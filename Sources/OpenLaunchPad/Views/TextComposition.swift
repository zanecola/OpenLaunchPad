import AppKit

enum TextComposition {
    /// True while an input method holds uncommitted (marked) text, such as Pinyin before a
    /// candidate is chosen, in the window receiving the current key event. The launcher's
    /// `onKeyPress` handlers run before the focused field editor, so they must then leave
    /// Escape and the arrows to the input method, which cancels or edits the composition.
    @MainActor static var isActive: Bool {
        isActive(in: NSApp.currentEvent?.window ?? NSApp.keyWindow)
    }

    /// Marked text never reaches the field's binding, so the window's field editor is asked.
    @MainActor static func isActive(in window: NSWindow?) -> Bool {
        (window?.firstResponder as? NSTextView)?.hasMarkedText() == true
    }
}
