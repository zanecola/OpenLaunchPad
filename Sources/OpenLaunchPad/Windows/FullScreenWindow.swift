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
