import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

struct PageScrollingTests {
    @Test
    func oneWheelNotchTurnsOnePageOnEitherAxis() {
        var stepper = PageWheelStepper()

        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 0) == .next)
        #expect(stepper.step(deltaX: 0, deltaY: 1, at: 1) == .previous)
        #expect(stepper.step(deltaX: -1, deltaY: 0, at: 2) == .next)
        #expect(stepper.step(deltaX: 2, deltaY: 0, at: 3) == .previous)
        // The larger delta picks the axis.
        #expect(stepper.step(deltaX: -1, deltaY: 3, at: 4) == .previous)
    }

    @Test
    func notchesWithinTheCooldownOfTheLastTurnAreDropped() {
        var stepper = PageWheelStepper()

        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 10) == .next)
        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 10.1) == nil)
        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 10.34) == nil)
        // Measured from the last turn, not the last notch, so a fast spin turns a page every 0.35 s.
        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 10.36) == .next)
    }

    @Test
    func anEventWithoutMovementStartsNoCooldown() {
        var stepper = PageWheelStepper()

        #expect(stepper.step(deltaX: 0, deltaY: 0, at: 0) == nil)
        #expect(stepper.step(deltaX: 0, deltaY: -1, at: 0.1) == .next)
    }

    @Test
    func monitorTakesWheelEventsAndLeavesSwipesToTheScrollView() throws {
        var turns: [PageScrollDirection] = []
        let coordinator = PageWheelMonitor.Coordinator(
            isEnabled: { true },
            onPrevious: { turns.append(.previous) },
            onNext: { turns.append(.next) }
        )
        let flick: [(Int32, CGScrollPhase?, CGMomentumScrollPhase)] = [
            (0, .mayBegin, .none),
            (-5, .began, .none),
            (-20, .changed, .none),
            (0, .ended, .none),
            (-30, nil, .begin),
            (-10, nil, .continuous),
            (0, nil, .end)
        ]

        // A trackpad flick and its momentum: the scroll view's to follow, and to turn one page.
        for (deltaX, phase, momentum) in flick {
            #expect(!coordinator.handle(try Self.scrollEvent(deltaX: deltaX, phase: phase, momentum: momentum)))
        }
        #expect(turns.isEmpty)

        #expect(coordinator.handle(try Self.wheelEvent(deltaY: -1, at: 100)))
        #expect(coordinator.handle(try Self.wheelEvent(deltaY: -1, at: 100.1)))
        #expect(coordinator.handle(try Self.wheelEvent(deltaX: 1, at: 101)))
        #expect(turns == [.next, .previous])
    }

    @Test
    func monitorLeavesTheWheelAloneWhileDisabled() throws {
        var isEnabled = false
        var turns = 0
        let coordinator = PageWheelMonitor.Coordinator(
            isEnabled: { isEnabled },
            onPrevious: { turns += 1 },
            onNext: { turns += 1 }
        )

        #expect(!coordinator.handle(try Self.wheelEvent(deltaY: -1, at: 0)))
        #expect(turns == 0)

        isEnabled = true
        #expect(coordinator.handle(try Self.wheelEvent(deltaY: -1, at: 0.1)))
        #expect(turns == 1)
    }

    @Test
    func pagesSettleOnlyAfterTheUserScrolledThem() {
        // Shown, then scrolled to the current page by an arrow key, a dot or a resize.
        #expect(Self.settles([.idle, .animating, .idle]) == [false, false, false])
        // A swipe, its momentum and the rest; another idle is not another settle.
        #expect(Self.settles([.tracking, .interacting, .decelerating, .idle, .idle]) == [false, false, false, true, false])
        // A key turns the page while a swipe decelerates: it settles where the key sent it.
        #expect(Self.settles([.interacting, .decelerating, .animating, .idle]) == [false, false, false, true])
        // Touched without moving.
        #expect(Self.settles([.tracking, .idle]) == [false, false])
    }

    @Test
    func currentDotFollowsTheScrollPositionBetweenTheEndDots() {
        let box = PageIndicatorView.dotBoxSize.width

        #expect(PageIndicatorView.currentDotOffset(position: 0, pageCount: 3) == 0)
        #expect(PageIndicatorView.currentDotOffset(position: 1.5, pageCount: 3) == 1.5 * box)
        #expect(PageIndicatorView.currentDotOffset(position: 2, pageCount: 3) == 2 * box)
        // Rubber-banding past either end.
        #expect(PageIndicatorView.currentDotOffset(position: -0.3, pageCount: 3) == 0)
        #expect(PageIndicatorView.currentDotOffset(position: 2.4, pageCount: 3) == 2 * box)
        #expect(PageIndicatorView.currentDotOffset(position: 0.5, pageCount: 1) == 0)
    }

    private static func settles(_ phases: [ScrollPhase]) -> [Bool] {
        var settling = PageScrollSettling()
        return phases.map { settling.phaseChanged(to: $0) }
    }

    private static func scrollEvent(
        deltaX: Int32,
        phase: CGScrollPhase?,
        momentum: CGMomentumScrollPhase
    ) throws -> NSEvent {
        let cgEvent = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: deltaX,
            wheel3: 0
        ))
        cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase?.rawValue ?? 0))
        cgEvent.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(momentum.rawValue))
        return try #require(NSEvent(cgEvent: cgEvent))
    }

    /// A notch of a mouse wheel: in lines, with no phase. `time` is in seconds.
    private static func wheelEvent(deltaX: Int32 = 0, deltaY: Int32 = 0, at time: TimeInterval) throws -> NSEvent {
        let cgEvent = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ))
        cgEvent.timestamp = CGEventTimestamp(time * 1_000_000_000)
        return try #require(NSEvent(cgEvent: cgEvent))
    }
}
