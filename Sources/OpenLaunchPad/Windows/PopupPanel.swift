import AppKit
import SwiftUI

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
        becomesKeyOnlyIfNeeded = true
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }

    func show(
        anchorPoint: NSPoint?,
        hostingView: NSHostingController<some View>,
        width: CGFloat,
        height: CGFloat
    ) {
        setContentSize(NSSize(width: width, height: height))
        contentViewController = hostingView
        hostingView.view.wantsLayer = true
        hostingView.view.layer?.cornerRadius = 18
        hostingView.view.layer?.masksToBounds = true

        if let anchorPoint,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main {
            setFrameOrigin(PopupPlacement.origin(
                anchor: anchorPoint,
                panelSize: NSSize(width: width, height: height),
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            ))
        } else if let screen = NSScreen.main {
            setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - width / 2,
                y: screen.visibleFrame.midY - height / 2
            ))
        }

        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}
