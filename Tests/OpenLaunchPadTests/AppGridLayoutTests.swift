import CoreGraphics
import Testing
@testable import OpenLaunchPad

struct AppGridLayoutTests {
    @Test
    func fullScreenLayoutUsesAvailableWidth() {
        let layout = AppGridLayout(
            size: CGSize(width: 2_000, height: 1_000),
            iconSize: 80,
            requestedColumns: 7
        )

        #expect(layout.columnCount == 7)
        #expect(layout.columnSpacing >= 64)
        #expect(layout.contentWidth >= 1_200)
        #expect(layout.contentWidth <= 1_800)
    }

    @Test
    func compactLayoutFitsInsidePanel() {
        let layout = AppGridLayout(
            size: CGSize(width: 600, height: 500),
            iconSize: 80,
            requestedColumns: 7
        )

        #expect(layout.contentWidth <= 552)
        #expect(layout.columnCount < 7)
        #expect(layout.contentHeight(itemCount: 35) > 500)
    }
}
