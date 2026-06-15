import AppKit
import Testing
@testable import OpenLaunchPad

struct PopupPlacementTests {
    private let screenFrame = NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
    private let visibleFrame = NSRect(x: 0, y: 70, width: 1_920, height: 986)
    private let panelSize = NSSize(width: 800, height: 600)

    @Test
    func bottomDockPlacementCentersOnClickedIcon() {
        let origin = PopupPlacement.origin(
            anchor: NSPoint(x: 1_400, y: 35),
            panelSize: panelSize,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == 1_000)
        #expect(origin.y == 78)
    }

    @Test
    func leftDockPlacementSitsInsideVisibleScreen() {
        let visible = NSRect(x: 80, y: 24, width: 1_840, height: 1_032)
        let origin = PopupPlacement.origin(
            anchor: NSPoint(x: 35, y: 700),
            panelSize: panelSize,
            screenFrame: screenFrame,
            visibleFrame: visible
        )

        #expect(origin.x == 88)
        #expect(origin.y == 400)
    }

    @Test
    func menuBarPlacementSitsBelowClickedIcon() {
        let origin = PopupPlacement.origin(
            anchor: NSPoint(x: 1_500, y: 1_068),
            panelSize: panelSize,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == 1_100)
        #expect(origin.y == 448)
    }
}
