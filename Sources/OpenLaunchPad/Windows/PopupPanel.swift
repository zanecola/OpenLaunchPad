import AppKit

enum PopupPlacement {
    static func origin(
        anchor: NSPoint,
        panelSize: NSSize,
        screenFrame: NSRect,
        visibleFrame: NSRect
    ) -> NSPoint {
        let inset: CGFloat = 8
        let edge: NSRectEdge
        if anchor.y < visibleFrame.minY {
            edge = .minY
        } else if anchor.y > visibleFrame.maxY {
            edge = .maxY
        } else if anchor.x < visibleFrame.minX {
            edge = .minX
        } else if anchor.x > visibleFrame.maxX {
            edge = .maxX
        } else {
            let distances: [(NSRectEdge, CGFloat)] = [
                (.minY, anchor.y - screenFrame.minY),
                (.maxY, screenFrame.maxY - anchor.y),
                (.minX, anchor.x - screenFrame.minX),
                (.maxX, screenFrame.maxX - anchor.x)
            ]
            edge = distances.min(by: { $0.1 < $1.1 })?.0 ?? .minY
        }

        let minimumX = visibleFrame.minX + inset
        let maximumX = max(minimumX, visibleFrame.maxX - panelSize.width - inset)
        let minimumY = visibleFrame.minY + inset
        let maximumY = max(minimumY, visibleFrame.maxY - panelSize.height - inset)

        switch edge {
        case .minX:
            return NSPoint(
                x: minimumX,
                y: min(max(anchor.y - panelSize.height / 2, minimumY), maximumY)
            )
        case .maxX:
            return NSPoint(
                x: maximumX,
                y: min(max(anchor.y - panelSize.height / 2, minimumY), maximumY)
            )
        case .maxY:
            return NSPoint(
                x: min(max(anchor.x - panelSize.width / 2, minimumX), maximumX),
                y: maximumY
            )
        default:
            return NSPoint(
                x: min(max(anchor.x - panelSize.width / 2, minimumX), maximumX),
                y: minimumY
            )
        }
    }
}

extension PopupAppearance {
    /// nil follows the system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Floating panel shared by Dock and menu-bar popup modes.
final class PopupPanel: NSPanel {
    init(width: CGFloat, height: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        hasShadow = true
        // Each show places the panel; these keep the wallpaper lined up when the system moves it
        // or its screen changes while it is open.
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(frameOrScreenDidChange), name: name, object: self)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(frameOrScreenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    override var canBecomeKey: Bool { true }

    /// Which screen the panel is on and where, for the wallpaper behind its content.
    let wallpaperPlacement = WallpaperPlacement()

    /// Escape that no view handled, for example when nothing in the window has focus.
    var onCancel: () -> Void = {}
    var onResignKey: () -> Void = {}
    private lazy var transitions = LauncherWindowAnimator(window: self)

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        if transitions.ignores(event) { return }
        super.sendEvent(event)
    }

    /// Installs the content once; it stays for the app's lifetime.
    func setContent(_ controller: NSViewController) {
        contentViewController = controller
        controller.view.wantsLayer = true
        controller.view.layer?.cornerRadius = 18
        controller.view.layer?.masksToBounds = true
    }

    /// A size that is already right is left alone, so a show costs no layout.
    func fit(to size: NSSize) {
        if frame.size != size {
            setContentSize(size)
        }
    }

    /// The screen the panel opens on for `anchorPoint`: the one holding it, else the main screen.
    static func screen(for anchorPoint: NSPoint?) -> NSScreen? {
        anchorPoint.flatMap { point in NSScreen.screens.first { $0.frame.contains(point) } } ?? NSScreen.main
    }

    /// The content stays installed between shows, so this only places the panel and orders it in.
    /// It grows from `anchorPoint`, and a show during a hide turns the hide back.
    func show(anchorPoint: NSPoint?, transition: WindowTransition?) {
        // Before the layout below, so the first frame already shows the desktop under the panel.
        place(anchorPoint: anchorPoint)

        // Applies what the show reset, such as search focus, before the panel appears rather
        // than a frame later.
        contentView?.layoutSubtreeIfNeeded()
        transitions.show(transition, content: contentView, pivot: growthPoint(for: anchorPoint)) {
            orderFrontRegardless()
            // A non-activating panel can be key without activating the app, so typing reaches
            // the search field instead of the app the user was in.
            makeKey()
        }
    }

    /// `completion` runs once the panel is ordered out; never if a show comes first.
    func hide(_ transition: WindowTransition?, then completion: @escaping () -> Void = {}) {
        transitions.hide(transition, content: contentView, pivot: growthPoint(for: nil), completion: completion)
    }

    /// False until the first show: the panel sits where it was created, at the primary screen's
    /// origin, and installing the content resizes it there.
    private var hasBeenPlaced = false

    /// Places the panel against `anchorPoint` on the screen holding it, centered without one, and
    /// publishes where for the wallpaper behind its content.
    func place(anchorPoint: NSPoint?) {
        guard let screen = Self.screen(for: anchorPoint) else { return }
        let size = frame.size
        if let anchorPoint {
            setFrameOrigin(PopupPlacement.origin(
                anchor: anchorPoint,
                panelSize: size,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            ))
        } else {
            setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }
        hasBeenPlaced = true
        wallpaperPlacement.update(for: self, on: screen)
    }

    @objc private func frameOrScreenDidChange() {
        guard hasBeenPlaced, let screen else { return }
        wallpaperPlacement.update(for: self, on: screen)
    }

    /// The point of the content nearest `anchorPoint`, in the content's coordinates; its center
    /// without one.
    func growthPoint(for anchorPoint: NSPoint?) -> CGPoint {
        guard let contentView else { return .zero }
        let bounds = contentView.bounds
        guard let anchorPoint else { return CGPoint(x: bounds.midX, y: bounds.midY) }
        let point = contentView.convert(convertPoint(fromScreen: anchorPoint), from: nil)
        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
