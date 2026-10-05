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
    private lazy var transitions = LauncherWindowAnimator(window: self)
    /// Scaled by the transitions; the backdrop behind it only fades.
    private var content: NSView?

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func sendEvent(_ event: NSEvent) {
        if transitions.ignores(event) { return }
        super.sendEvent(event)
    }

    /// Installs the backdrop and the content once, as sibling views, so a transition can scale the
    /// content alone: Launchpad zoomed its icons over a backdrop that only faded.
    func setContent(backdrop: NSView, content: NSView) {
        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.wantsLayer = true
        for view in [backdrop, content] {
            view.frame = container.bounds
            view.autoresizingMask = [.width, .height]
            view.wantsLayer = true
            container.addSubview(view)
        }
        contentView = container
        initialFirstResponder = content
        self.content = content
    }

    /// Covers `screen`. A frame that is already right is left alone, so a show costs no layout.
    func fit(to screen: NSScreen) {
        if frame != screen.frame {
            setFrame(screen.frame, display: false)
        }
    }

    /// The content stays installed between shows, so this only orders the window in. A show during
    /// a hide turns the hide back.
    func show(_ transition: WindowTransition?) {
        level = .normal
        // Applies what the show reset, such as search focus, before the window appears rather
        // than a frame later.
        contentView?.layoutSubtreeIfNeeded()
        transitions.show(transition, content: content, pivot: contentCenter) {
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// `completion` runs once the window is ordered out; never if a show comes first.
    func hide(_ transition: WindowTransition?, then completion: @escaping () -> Void = {}) {
        transitions.hide(transition, content: content, pivot: contentCenter) { [weak self] in
            self?.level = .normal
            completion()
        }
    }

    /// Hiding the app hands activation back, and the app that gets it brings its windows forward,
    /// so the fading launcher rises above them until it is ordered out. It ignores the mouse
    /// meanwhile, so it can't trap anyone (Decision 10).
    func staysInFrontWhileHiding() {
        if transitions.isHiding {
            level = .floating
        }
    }

    private var contentCenter: CGPoint {
        content.map { CGPoint(x: $0.bounds.midX, y: $0.bounds.midY) } ?? .zero
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

    static func contentInsets(for screen: NSScreen, autoHidesDockAndMenuBar: Bool) -> EdgeInsets {
        contentInsets(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsets: screen.safeAreaInsets,
            autoHidesDockAndMenuBar: autoHidesDockAndMenuBar
        )
    }
}
