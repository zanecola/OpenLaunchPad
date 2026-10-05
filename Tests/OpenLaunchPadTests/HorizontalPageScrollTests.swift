import AppKit
import Testing
@testable import OpenLaunchPad

struct HorizontalPageScrollTests {
    @Test
    func accumulatedHorizontalScrollTriggersOncePerGesture() {
        var accumulator = HorizontalPageScrollAccumulator(threshold: 30)

        #expect(accumulator.process(deltaX: -18, deltaY: 2) == nil)
        #expect(accumulator.process(deltaX: -18, deltaY: 2) == .next)
        #expect(accumulator.process(deltaX: -40, deltaY: 0) == nil)

        accumulator.endGesture()

        #expect(accumulator.process(deltaX: 35, deltaY: 0) == .previous)
    }

    @Test
    func verticalScrollDoesNotChangePages() {
        var accumulator = HorizontalPageScrollAccumulator(threshold: 30)

        #expect(accumulator.process(deltaX: 8, deltaY: 40) == nil)
        #expect(accumulator.process(deltaX: -8, deltaY: -40) == nil)
    }

    @Test
    func trackpadFlickWithMomentumTurnsOnePagePerFlick() throws {
        var nextCount = 0
        let coordinator = HorizontalPageScrollMonitor.Coordinator(
            onPrevious: {},
            onNext: { nextCount += 1 }
        )
        let flick: [(Int32, CGScrollPhase?, CGMomentumScrollPhase)] = [
            (0, .mayBegin, .none),
            (-5, .began, .none),
            (-20, .changed, .none),
            (-15, .changed, .none),
            (0, .ended, .none),
            (-30, nil, .begin),
            (-25, nil, .continuous),
            (-18, nil, .continuous),
            (-10, nil, .continuous),
            (0, nil, .end)
        ]

        for (deltaX, phase, momentum) in flick {
            coordinator.handle(try Self.scrollEvent(deltaX: deltaX, phase: phase, momentum: momentum))
        }
        #expect(nextCount == 1)

        for (deltaX, phase, momentum) in flick {
            coordinator.handle(try Self.scrollEvent(deltaX: deltaX, phase: phase, momentum: momentum))
        }
        #expect(nextCount == 2)
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
}
