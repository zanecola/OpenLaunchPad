import SwiftUI
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

struct FullScreenPageLayoutTests {
    /// Width, height and menu-bar height (camera housing included) of common displays.
    static let displays: [(CGFloat, CGFloat, CGFloat)] = [
        (1_280, 800, 24),
        (1_440, 900, 24),
        (1_470, 956, 38),
        (1_512, 982, 38),
        (1_920, 1_080, 24),
        (2_560, 1_440, 24)
    ]

    private func layout(
        width: CGFloat,
        height: CGFloat,
        insets: EdgeInsets,
        requestedColumns: Int = 7,
        showsPageIndicator: Bool = true,
        wantsFrequentlyUsed: Bool
    ) -> FullScreenPageLayout {
        FullScreenPageLayout(
            size: CGSize(width: width, height: height),
            insets: insets,
            iconSize: 80,
            requestedColumns: requestedColumns,
            showsLabels: true,
            largestPageItemCount: 35,
            showsPageIndicator: showsPageIndicator,
            wantsFrequentlyUsed: wantsFrequentlyUsed
        )
    }

    private func bottomDockInsets(menuBar: CGFloat) -> EdgeInsets {
        EdgeInsets(top: menuBar, leading: 0, bottom: 70, trailing: 0)
    }

    @Test(arguments: displays, [false, true])
    func fullPageFitsAboveTheDotsAndTheDock(display: (CGFloat, CGFloat, CGFloat), wantsFrequentlyUsed: Bool) {
        let (width, height, menuBar) = display
        let insets = bottomDockInsets(menuBar: menuBar)
        let page = layout(width: width, height: height, insets: insets, wantsFrequentlyUsed: wantsFrequentlyUsed)

        let rowHeight = page.showsFrequentlyUsed
            ? FrequentlyUsedAppsLayout.rowHeight(
                configuredIconSize: page.grid.iconSize,
                showsLabels: true,
                presentation: .fullScreen
            )
            : 0
        let stackHeight = insets.top + FullScreenPageLayout.searchTopPadding
            + FullScreenPageLayout.searchBarHeight + FullScreenPageLayout.searchBottomPadding
            + rowHeight + page.gridHeight
            + FullScreenPageLayout.pageIndicatorHeight + FullScreenPageLayout.bottomPadding + insets.bottom

        #expect(page.grid.contentHeight(itemCount: 35) <= page.gridHeight)
        #expect(abs(stackHeight - height) < 0.001)
        #expect(page.grid.iconSize >= FullScreenPageLayout.minimumIconSize)
        #expect(page.grid.iconSize <= 80)
        #expect(page.grid.columnCount == 7)
    }

    @Test
    func thirteenInchAirKeepsFrequentlyUsedWithSmallerIcons() {
        let page = layout(width: 1_470, height: 956, insets: bottomDockInsets(menuBar: 38), wantsFrequentlyUsed: true)

        #expect(page.showsFrequentlyUsed)
        #expect(page.grid.iconSize < 80)
        #expect(page.grid.iconSize > 52)
    }

    @Test
    func thirteenInchAirWithoutFrequentlyUsedKeepsTheConfiguredSize() {
        let page = layout(width: 1_470, height: 956, insets: bottomDockInsets(menuBar: 38), wantsFrequentlyUsed: false)

        #expect(page.grid.iconSize == 80)
    }

    @Test
    func shortDisplayLeavesOutFrequentlyUsedRatherThanHidingRows() {
        let page = layout(width: 1_280, height: 800, insets: bottomDockInsets(menuBar: 24), wantsFrequentlyUsed: true)

        #expect(!page.showsFrequentlyUsed)
        #expect(page.grid.iconSize > 56)
    }

    @Test
    func largeDisplayKeepsTheConfiguredSizeAndTheRow() {
        let page = layout(width: 2_560, height: 1_440, insets: bottomDockInsets(menuBar: 24), wantsFrequentlyUsed: true)

        #expect(page.showsFrequentlyUsed)
        #expect(page.grid.iconSize == 80)
    }

    @Test
    func singlePageGivesTheDotsSpaceToTheGrid() {
        let insets = bottomDockInsets(menuBar: 24)
        let paged = layout(width: 1_440, height: 900, insets: insets, wantsFrequentlyUsed: false)
        let single = layout(width: 1_440, height: 900, insets: insets, showsPageIndicator: false, wantsFrequentlyUsed: false)

        #expect(single.gridHeight - paged.gridHeight == FullScreenPageLayout.pageIndicatorHeight)
        #expect(single.grid.iconSize > paged.grid.iconSize)
    }

    @Test
    func sideDockNarrowsTheGrid() {
        let page = layout(
            width: 1_440,
            height: 900,
            insets: EdgeInsets(top: 24, leading: 70, bottom: 0, trailing: 0),
            wantsFrequentlyUsed: false
        )

        #expect(page.grid.contentWidth <= 1_440 - 70)
        #expect(page.grid.iconSize == 80)
    }

    @Test(arguments: [(CGFloat(1_280), CGFloat(320)), (1_728, 414.72), (2_000, 480), (5_120, 480)])
    func searchFieldIsAQuarterOfTheWidthWithinLimits(contentWidth: CGFloat, fieldWidth: CGFloat) {
        #expect(abs(FullScreenPageLayout.searchFieldWidth(contentWidth: contentWidth) - fieldWidth) < 0.001)
    }

    @Test
    func pageThatCannotFitStopsAtTheMinimumIconSize() {
        // Four columns put 35 items in 9 rows, more than any laptop fits until pages get a capacity.
        let page = layout(
            width: 1_280,
            height: 800,
            insets: bottomDockInsets(menuBar: 24),
            requestedColumns: 4,
            wantsFrequentlyUsed: true
        )

        #expect(page.grid.iconSize == FullScreenPageLayout.minimumIconSize)
        #expect(!page.showsFrequentlyUsed)
    }
}
