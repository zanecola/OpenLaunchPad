import CoreGraphics
import Testing
@testable import OpenLaunchPad

struct AppGridLayoutTests {
    @Test
    func popupUsesAutomaticColumnsWhileFullScreenUsesPreference() {
        #expect(AppGridMode.scrolling.requestedColumns(configuredColumns: 12) == 0)
        #expect(AppGridMode.paged.requestedColumns(configuredColumns: 12) == 12)
    }

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
        #expect(layout.cellHeight >= 120)
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

    @Test
    func largeIconsReserveTwoAlignedLabelLines() {
        let layout = AppGridLayout(
            size: CGSize(width: 1_400, height: 900),
            iconSize: 128,
            requestedColumns: 7,
            showsLabels: true
        )

        #expect(layout.cellHeight >= 128 + 6 + LaunchpadIconMetrics.labelHeight(for: 128))
    }
}
