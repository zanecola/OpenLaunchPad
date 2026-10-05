import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

struct WindowHideTrackerTests {
    private final class Log {
        var entries: [String] = []
    }

    @Test
    func aFinishedHideRunsItsCompletion() throws {
        let log = Log()
        var tracker = WindowHideTracker()

        let hide = tracker.beginHide { log.entries.append("hidden") }
        let generation = try #require(hide)
        let completions = tracker.finishHide(generation)
        try #require(completions).forEach { $0() }

        #expect(log.entries == ["hidden"])
        #expect(!tracker.isHiding)
    }

    @Test
    func aShowDuringAHideCancelsIt() throws {
        let log = Log()
        var tracker = WindowHideTracker()
        let hide = tracker.beginHide { log.entries.append("hidden") }
        let generation = try #require(hide)

        _ = tracker.beginShow()
        let completions = tracker.finishHide(generation)

        #expect(completions == nil)
        #expect(log.entries.isEmpty)
        #expect(!tracker.isHiding)
    }

    @Test
    func aSecondHideJoinsTheRunningOne() throws {
        let log = Log()
        var tracker = WindowHideTracker()
        let hide = tracker.beginHide { log.entries.append("first") }
        let generation = try #require(hide)

        let second = tracker.beginHide { log.entries.append("second") }
        let completions = tracker.finishHide(generation)
        try #require(completions).forEach { $0() }

        #expect(second == nil)
        #expect(log.entries == ["first", "second"])
    }

    @Test
    func aHideAfterACancelledOneStartsAfresh() throws {
        let log = Log()
        var tracker = WindowHideTracker()
        let cancelledHide = tracker.beginHide { log.entries.append("cancelled") }
        let cancelled = try #require(cancelledHide)
        _ = tracker.beginShow()
        let hide = tracker.beginHide { log.entries.append("hidden") }
        let generation = try #require(hide)

        let staleCompletions = tracker.finishHide(cancelled)
        let completions = tracker.finishHide(generation)
        try #require(completions).forEach { $0() }

        #expect(staleCompletions == nil)
        #expect(log.entries == ["hidden"])
    }

    @Test
    func aHideSupersedesTheShowBeforeIt() {
        var tracker = WindowHideTracker()
        let show = tracker.beginShow()

        _ = tracker.beginHide {}

        #expect(!tracker.isCurrent(show))
    }
}

@MainActor
struct LauncherWindowAnimatorTests {
    @Test
    func scalingKeepsThePivotInPlace() {
        let transform = CATransform3DGetAffineTransform(LauncherWindowAnimator.scaleTransform(
            1.06,
            about: CGPoint(x: 400, y: 300),
            position: CGPoint(x: 0, y: 0)
        ))

        // Offsets from the position, as the layer's transform sees them.
        #expect(CGPoint(x: 400, y: 300).applying(transform) == CGPoint(x: 400, y: 300))
        let corner = CGPoint(x: 0, y: 0).applying(transform)
        #expect(abs(corner.x - -24) < 0.001)
        #expect(abs(corner.y - -18) < 0.001)
    }

    @Test
    func thePopupGrowsFromTheEdgeNearestItsAnchor() throws {
        let panel = PopupPanel(width: 800, height: 600)
        panel.setContent(NSHostingController(rootView: EmptyView()))
        panel.fit(to: NSSize(width: 800, height: 600))
        panel.setFrameOrigin(NSPoint(x: 100, y: 100))
        panel.displayIfNeeded()
        let content = try #require(panel.contentView)
        let layer = try #require(content.layer)
        let superlayer = try #require(layer.superlayer)

        // The status item sits above the panel's top edge.
        let pivot = panel.growthPoint(for: NSPoint(x: 500, y: 720))
        let before = superlayer.convert(pivot, from: layer)
        layer.transform = LauncherWindowAnimator.scaleTransform(0.96, of: layer, about: pivot)
        let after = superlayer.convert(pivot, from: layer)
        layer.transform = CATransform3DIdentity

        // In window coordinates, y up: the top center.
        #expect(before == CGPoint(x: 400, y: 600))
        #expect(abs(after.x - before.x) < 0.001)
        #expect(abs(after.y - before.y) < 0.001)
    }

    @Test
    func thePopupGrowsFromItsCenterWithoutAnAnchor() {
        let panel = PopupPanel(width: 800, height: 600)
        panel.setContent(NSHostingController(rootView: EmptyView()))
        panel.fit(to: NSSize(width: 800, height: 600))

        #expect(panel.growthPoint(for: nil) == CGPoint(x: 400, y: 300))
    }

    @Test
    func hidingAWindowThatIsNotShownFinishesAtOnce() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.borderless], backing: .buffered, defer: true)
        let animator = LauncherWindowAnimator(window: window)
        var finished = false

        animator.hide(LaunchpadMotion().popupClose, content: window.contentView, pivot: .zero) { finished = true }

        #expect(finished)
        #expect(!animator.isHiding)
        #expect(window.alphaValue == 1)
        #expect(!window.ignoresMouseEvents)
    }
}
