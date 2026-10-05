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
    }

    override var canBecomeKey: Bool { true }

    /// Escape that no view handled, for example when nothing in the window has focus.
    var onCancel: () -> Void = {}
    var onResignKey: () -> Void = {}

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func resignKey() {
        super.resignKey()
        onResignKey()
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

    /// The content stays installed between shows, so this only places the panel and orders it in.
    func show(anchorPoint: NSPoint?) {
        let size = frame.size
        if let anchorPoint,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main {
            setFrameOrigin(PopupPlacement.origin(
                anchor: anchorPoint,
                panelSize: size,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            ))
        } else if let screen = NSScreen.main {
            setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }

        // Applies what the show reset, such as search focus, before the panel appears rather
        // than a frame later.
        contentView?.layoutSubtreeIfNeeded()
        orderFrontRegardless()
        // A non-activating panel can be key without activating the app, so typing reaches
        // the search field instead of the app the user was in.
        makeKey()
    }

    func hide() {
        orderOut(nil)
    }
}
