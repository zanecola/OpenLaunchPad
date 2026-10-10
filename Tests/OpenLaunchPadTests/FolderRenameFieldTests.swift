import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

@MainActor
struct FolderRenameFieldTests {
    @Test
    func theFieldTakesFocusWithTheNameSelectedOnceInAWindow() async throws {
        var name = "Utilities"
        let window = makeWindow(text: Binding(get: { name }, set: { name = $0 }))

        let editor = try #require(await fieldEditor(of: window))
        #expect(editor.delegate is FocusingTextField)
        #expect(editor.string == "Utilities")
        #expect(editor.selectedRange() == NSRange(location: 0, length: 9))
    }

    @Test
    func typingReplacesTheNameAndReturnCommits() async throws {
        var name = "Utilities"
        var commits = 0
        let window = makeWindow(text: Binding(get: { name }, set: { name = $0 }), onCommit: { commits += 1 })
        let editor = try #require(await fieldEditor(of: window))

        editor.insertText("Tools", replacementRange: editor.selectedRange())
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        #expect(name == "Tools")
        #expect(commits == 1)
    }

    @Test
    func escapeCancelsWithoutCommitting() async throws {
        var name = "Utilities"
        var commits = 0
        var cancels = 0
        let window = makeWindow(
            text: Binding(get: { name }, set: { name = $0 }),
            onCommit: { commits += 1 },
            onCancel: { cancels += 1 }
        )
        let editor = try #require(await fieldEditor(of: window))

        editor.insertText("Tools", replacementRange: editor.selectedRange())
        editor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))

        #expect(cancels == 1)
        #expect(commits == 0)
    }

    @Test
    func leavingTheFieldMidCompositionKeepsTheComposedText() async throws {
        var name = "Utilities"
        var committedName: String?
        let window = makeWindow(text: Binding(get: { name }, set: { name = $0 }), onCommit: { committedName = name })
        let editor = try #require(await fieldEditor(of: window))

        editor.insertText("Ab", replacementRange: editor.selectedRange())
        editor.setMarkedText(
            "suan",
            selectedRange: NSRange(location: 4, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        window.makeFirstResponder(nil)

        #expect(committedName == "Absuan")
    }

    /// Never ordered front, so it can't receive the user's keystrokes.
    private func makeWindow(
        text: Binding<String>,
        onCommit: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: FolderRenameField(
            text: text,
            font: .systemFont(ofSize: 15),
            onCommit: onCommit,
            onCancel: onCancel
        ))
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    /// Waits up to a second, yielding the main actor, for the field to take focus.
    private func fieldEditor(of window: NSWindow) async -> NSTextView? {
        for _ in 0..<50 {
            if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor {
                return editor
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }
}
