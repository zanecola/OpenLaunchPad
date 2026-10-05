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
    /// Common displays with a visible 70 pt Dock: size, and the insets the menu bar (camera
    /// housing included) and the Dock leave.
    static let displays: [(CGSize, EdgeInsets)] = [
        (CGSize(width: 1_280, height: 800), EdgeInsets(top: 24, leading: 0, bottom: 70, trailing: 0)),
        (CGSize(width: 1_470, height: 956), EdgeInsets(top: 38, leading: 0, bottom: 70, trailing: 0)),
        (CGSize(width: 1_512, height: 982), EdgeInsets(top: 38, leading: 70, bottom: 0, trailing: 0)),
        (CGSize(width: 2_560, height: 1_440), EdgeInsets(top: 24, leading: 0, bottom: 70, trailing: 0))
    ]

    private func layout(
        _ display: (CGSize, EdgeInsets),
        customIconSize: CGFloat? = nil,
        columns: Int = 7,
        rows: Int = 5,
        showsPageIndicator: Bool = true,
        wantsFrequentlyUsed: Bool = false
    ) -> FullScreenPageLayout {
        FullScreenPageLayout(
            size: display.0,
            insets: display.1,
            customIconSize: customIconSize,
            columns: columns,
            rows: rows,
            showsLabels: true,
            showsPageIndicator: showsPageIndicator,
            wantsFrequentlyUsed: wantsFrequentlyUsed
        )
    }

    private func frequentlyUsedRowHeight(_ page: FullScreenPageLayout) -> CGFloat {
        page.showsFrequentlyUsed
            ? FrequentlyUsedAppsLayout.rowHeight(
                configuredIconSize: page.grid.iconSize,
                showsLabels: true,
                presentation: .fullScreen
            )
            : 0
    }

    @Test(arguments: displays, [false, true])
    func slotsFillTheSpaceBetweenTheSearchBarAndTheDots(display: (CGSize, EdgeInsets), wantsFrequentlyUsed: Bool) {
        let (size, insets) = display
        let page = layout(display, wantsFrequentlyUsed: wantsFrequentlyUsed)
        let grid = page.grid

        let stackHeight = insets.top + FullScreenPageLayout.searchTopPadding
            + FullScreenPageLayout.searchBarHeight + FullScreenPageLayout.searchBottomPadding
            + frequentlyUsedRowHeight(page) + page.gridHeight
            + FullScreenPageLayout.pageIndicatorHeight + FullScreenPageLayout.bottomPadding + insets.bottom
        #expect(abs(stackHeight - size.height) < 0.001)
        // Five rows of slots take exactly the grid's height, whatever the page holds.
        #expect(abs(5 * grid.cellHeight - page.gridHeight) < 0.001)
        #expect(abs(grid.contentHeight(itemCount: 35) - page.gridHeight) < 0.001)

        let safeWidth = size.width - insets.leading - insets.trailing
        #expect(grid.columnCount == 7)
        #expect(grid.contentWidth <= safeWidth - 2 * 48)

        #expect(grid.iconSize >= FullScreenPageLayout.minimumIconSize)
        #expect(grid.iconSize <= FullScreenPageLayout.maximumAutomaticIconSize)
        #expect(LaunchpadIconMetrics.contentHeight(for: grid.iconSize, showsLabel: true) <= grid.cellHeight)
        #expect(grid.iconSize + 16 <= grid.cellWidth)
    }

    @Test
    func automaticIconsGrowWithTheDisplay() {
        let sizes = Self.displays.map { layout($0).grid.iconSize }

        #expect((60...76).contains(sizes[0]))
        #expect((80...90).contains(sizes[1]))
        #expect((90...105).contains(sizes[2]))
        #expect(sizes[3] == FullScreenPageLayout.maximumAutomaticIconSize)
        #expect(sizes == sizes.sorted())
    }

    @Test
    func customSizeIsKeptWhereItFits() {
        // The 56 pt, 11-column setup a user had before rows existed.
        let large = Self.displays[3]

        #expect(layout(large, customIconSize: 56, columns: 11).grid.iconSize == 56)

        let withRow = layout(large, customIconSize: 56, columns: 11, wantsFrequentlyUsed: true)
        #expect(withRow.showsFrequentlyUsed)
        #expect(withRow.grid.iconSize == 56)
    }

    @Test
    func customSizeShrinksOnlyAsFarAsItsSlotsNeed() {
        let page = layout(Self.displays[0], customIconSize: 160)
        let grid = page.grid
        let contentHeight = LaunchpadIconMetrics.contentHeight(for: grid.iconSize, showsLabel: true)

        #expect(grid.iconSize < 160)
        #expect(grid.iconSize > layout(Self.displays[0]).grid.iconSize)
        #expect(grid.iconSize + 24 <= grid.cellWidth)
        #expect(contentHeight + 8 <= grid.cellHeight)
        #expect(LaunchpadIconMetrics.contentHeight(for: grid.iconSize + 1, showsLabel: true) + 8 > grid.cellHeight)
    }

    @Test
    func densestGridKeepsEveryRowInsideTheGrid() {
        let page = layout(Self.displays[0], columns: 12, rows: 7, wantsFrequentlyUsed: true)
        let grid = page.grid

        #expect(!page.showsFrequentlyUsed)
        #expect(grid.iconSize == FullScreenPageLayout.minimumIconSize)
        #expect(abs(7 * grid.cellHeight - page.gridHeight) < 0.001)
        #expect(LaunchpadIconMetrics.contentHeight(for: grid.iconSize, showsLabel: true) <= grid.cellHeight)
        #expect(grid.iconSize + 16 <= grid.cellWidth)
    }

    @Test
    func thirteenInchAirKeepsFrequentlyUsedWithSmallerIcons() {
        let air = Self.displays[1]
        let page = layout(air, wantsFrequentlyUsed: true)

        #expect(page.showsFrequentlyUsed)
        #expect(page.grid.iconSize < layout(air).grid.iconSize)
        #expect(page.grid.iconSize > 52)
    }

    @Test
    func shortDisplayLeavesOutFrequentlyUsedRatherThanShrinkingIconsPastTheMinimum() {
        let short = Self.displays[0]
        let page = layout(short, wantsFrequentlyUsed: true)

        #expect(!page.showsFrequentlyUsed)
        #expect(page.grid.iconSize == layout(short).grid.iconSize)
    }

    @Test
    func largeDisplayKeepsTheRowAndLargeIcons() {
        let page = layout(Self.displays[3], wantsFrequentlyUsed: true)

        #expect(page.showsFrequentlyUsed)
        #expect(page.grid.iconSize >= 100)
    }

    @Test
    func singlePageGivesTheDotsSpaceToTheGrid() {
        let display = Self.displays[1]
        let paged = layout(display)
        let single = layout(display, showsPageIndicator: false)

        #expect(single.gridHeight - paged.gridHeight == FullScreenPageLayout.pageIndicatorHeight)
        #expect(single.grid.iconSize > paged.grid.iconSize)
    }

    @Test
    func sideDockNarrowsTheGrid() {
        let display = Self.displays[2]
        let page = layout(display)
        let safeWidth = display.0.width - display.1.leading
        let margin = max(48, safeWidth * 0.09)

        #expect(abs(page.grid.contentWidth - (safeWidth - 2 * margin)) < 0.001)
        #expect(abs(page.grid.cellWidth * 7 - page.grid.contentWidth) < 0.001)
    }

    @Test(arguments: [(CGFloat(1_280), CGFloat(320)), (1_728, 414.72), (2_000, 480), (5_120, 480)])
    func searchFieldIsAQuarterOfTheWidthWithinLimits(contentWidth: CGFloat, fieldWidth: CGFloat) {
        #expect(abs(FullScreenPageLayout.searchFieldWidth(contentWidth: contentWidth) - fieldWidth) < 0.001)
    }

    @Test
    func slotsDivideTheSpaceInsideTheirMargins() {
        let grid = AppGridLayout(slotsIn: CGSize(width: 1_000, height: 500), columns: 5, rows: 4, iconSize: 80)

        #expect(grid.cellWidth == 164)
        #expect(grid.cellHeight == 125)
        #expect(grid.contentWidth == 820)
        #expect(grid.columnSpacing == 0)
        #expect(grid.rowSpacing == 0)
    }
}
