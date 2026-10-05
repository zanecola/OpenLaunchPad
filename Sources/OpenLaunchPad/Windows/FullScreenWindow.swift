import AppKit
import SwiftUI

/// Borderless, full-screen overlay window — covers the entire display without entering
/// macOS full-screen mode (no Mission Control involvement). (ADR-1)
final class FullScreenWindow: NSWindow {
    init() {
        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
            return
        }
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .normal
        collectionBehavior = [.ignoresCycle]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        hasShadow = false
    }

    // Allow key events (Escape, typing in search)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Escape that no view handled, for example when nothing in the window has focus.
    var onCancel: () -> Void = {}

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    func show(hostingView: NSHostingController<some View>) {
        contentViewController = hostingView
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: false)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        orderOut(nil)
    }
}
