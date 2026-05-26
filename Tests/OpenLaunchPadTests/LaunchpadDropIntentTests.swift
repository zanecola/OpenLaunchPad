import CoreGraphics
import Testing
@testable import OpenLaunchPad

struct LaunchpadDropIntentTests {
    @Test(arguments: [
        (x: 0.0, expected: DropZone.leading),
        (x: 24.9, expected: DropZone.leading),
        (x: 25.0, expected: DropZone.center),
        (x: 74.9, expected: DropZone.center),
        (x: 75.0, expected: DropZone.trailing),
        (x: 100.0, expected: DropZone.trailing)
    ])
    func classifiesPointerPosition(x: Double, expected: DropZone) {
        #expect(DropZone.classify(x: x, width: 100) == expected)
    }

    @Test
    func nonPositiveWidthFallsBackToCenter() {
        #expect(DropZone.classify(x: 10, width: 0) == .center)
        #expect(DropZone.classify(x: 10, width: -100) == .center)
    }

    @Test(arguments: [LaunchpadDragKind.app, .folder], [LaunchpadDragKind.app, .folder])
    func leadingAlwaysReordersBefore(source: LaunchpadDragKind, target: LaunchpadDragKind) {
        #expect(LaunchpadDropIntent.resolve(source: source, target: target, zone: .leading) == .reorder(.before))
    }

    @Test(arguments: [LaunchpadDragKind.app, .folder], [LaunchpadDragKind.app, .folder])
    func trailingAlwaysReordersAfter(source: LaunchpadDragKind, target: LaunchpadDragKind) {
        #expect(LaunchpadDropIntent.resolve(source: source, target: target, zone: .trailing) == .reorder(.after))
    }

    @Test
    func centerOnlyGroupsApps() {
        #expect(LaunchpadDropIntent.resolve(source: .app, target: .app, zone: .center) == .combineApps)
        #expect(LaunchpadDropIntent.resolve(source: .app, target: .folder, zone: .center) == .addToFolder)
        #expect(LaunchpadDropIntent.resolve(source: .folder, target: .app, zone: .center) == .reorder(.after))
        #expect(LaunchpadDropIntent.resolve(source: .folder, target: .folder, zone: .center) == .reorder(.after))
    }
}
