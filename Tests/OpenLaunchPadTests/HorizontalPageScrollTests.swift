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
}
