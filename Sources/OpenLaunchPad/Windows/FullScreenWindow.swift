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
        // Launchpad always drew white labels over a darkened backdrop, whatever the system appearance.
        appearance = NSAppearance(named: .darkAqua)
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

    /// The window covers the whole screen for the backdrop, but the menu bar and the Dock draw
    /// above it, so content keeps out of the strips that `visibleFrame` leaves out. When both auto-hide
    /// while the launcher is open, only the camera housing remains.
    static func contentInsets(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsets: NSEdgeInsets,
        autoHidesDockAndMenuBar: Bool
    ) -> EdgeInsets {
        if autoHidesDockAndMenuBar {
            return EdgeInsets(
                top: safeAreaInsets.top,
                leading: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                trailing: safeAreaInsets.right
            )
        }
        return EdgeInsets(
            top: max(screenFrame.maxY - visibleFrame.maxY, safeAreaInsets.top),
            leading: max(visibleFrame.minX - screenFrame.minX, safeAreaInsets.left),
            bottom: max(visibleFrame.minY - screenFrame.minY, safeAreaInsets.bottom),
            trailing: max(screenFrame.maxX - visibleFrame.maxX, safeAreaInsets.right)
        )
    }

    /// Insets for the screen `show(hostingView:)` covers.
    static func contentInsets(autoHidesDockAndMenuBar: Bool) -> EdgeInsets {
        guard let screen = NSScreen.main else { return EdgeInsets() }
        return contentInsets(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsets: screen.safeAreaInsets,
            autoHidesDockAndMenuBar: autoHidesDockAndMenuBar
        )
    }
}
