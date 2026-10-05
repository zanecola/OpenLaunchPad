import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

struct FolderPanelLayoutTests {
    private static let roomy = CGSize(width: 1_400, height: 800)

    private func layout(apps: Int, iconSize: CGFloat = 80, in size: CGSize = roomy) -> FolderPanelLayout {
        FolderPanelLayout(appCount: apps, iconSize: iconSize, showsLabels: true, availableSize: size)
    }

    private func panelSize(_ layout: FolderPanelLayout) -> CGSize {
        CGSize(
            width: layout.gridWidth + FolderPanelLayout.horizontalPadding * 2,
            height: layout.gridHeight + FolderPanelLayout.verticalPadding * 2
                + FolderPanelLayout.titleHeight + FolderPanelLayout.titleSpacing
        )
    }

    @Test(arguments: [(2, 3), (3, 3), (4, 4), (5, 5), (10, 5), (40, 5)])
    func columnsFollowTheAppCountBetweenThreeAndFive(apps: Int, columns: Int) {
        #expect(layout(apps: apps).columnCount == columns)
    }

    @Test
    func panelIsSizedToItsAppsRatherThanTheSpace() {
        let folder = layout(apps: 10)
        let onLargeDisplay = layout(apps: 10, in: CGSize(width: 2_560, height: 1_440))

        #expect(folder.gridWidth == 5 * folder.cellWidth + 4 * FolderPanelLayout.columnSpacing)
        #expect(folder.gridHeight == 2 * folder.cellHeight + FolderPanelLayout.rowSpacing)
        #expect(panelSize(onLargeDisplay) == panelSize(folder))
    }

    @Test
    func appsUseTheGridIconSizeAndCells() {
        let folder = layout(apps: 6, iconSize: 64)
        let grid = AppGridLayout(size: Self.roomy, iconSize: 64, requestedColumns: 7)

        #expect(folder.iconSize == 64)
        #expect(folder.cellWidth == grid.cellWidth)
        #expect(folder.cellHeight == grid.cellHeight)
    }

    @Test
    func moreThanThreeRowsScroll() {
        let folder = layout(apps: 20)

        #expect(folder.columnCount == 5)
        #expect(folder.gridHeight == 3 * folder.cellHeight + 2 * FolderPanelLayout.rowSpacing)
    }

    @Test(arguments: [400.0, 520.0, 640.0])
    func narrowPopupUsesTheColumnsThatFit(paneWidth: Double) {
        // The popup's folder area: the pane minus 16 pt at the sides and 64 pt for the search header.
        let space = CGSize(width: paneWidth - 32, height: 620 - 80)
        let folder = layout(apps: 10, in: space)

        #expect(folder.columnCount < 5)
        #expect(panelSize(folder).width <= space.width)
    }

    @Test
    func shortSpaceClampsTheGridSoThePanelFits() {
        let space = CGSize(width: 828, height: 300 - 80)
        let folder = layout(apps: 10, in: space)

        #expect(folder.gridHeight < folder.cellHeight * 2)
        #expect(panelSize(folder).height <= space.height)
    }
}

@MainActor
struct FolderTileTests {
    @Test(arguments: [true, false], [CGFloat(48), 80, 128])
    func folderTileTakesTheSameSpaceAsAnAppTile(showsLabel: Bool, iconSize: CGFloat) {
        let apps = (0..<9).map { AppItem(id: UUID(), bundleID: "com.example.app\($0)", title: "App \($0)") }
        let viewModel = LaunchpadViewModel(
            dataSource: EmptyDataSource(),
            layoutStore: EmptyLayoutStore(),
            iconProvider: BlankIconProvider(),
            appUsageStore: EmptyUsageStore()
        )
        let appTile = NSHostingView(rootView: AppIconView(
            app: apps[0],
            icon: NSImage(size: NSSize(width: 1, height: 1)),
            iconSize: iconSize,
            showLabel: showsLabel,
            isEditMode: false
        )
        .environment(LaunchpadDragState())
        .environment(viewModel))
        let folderTile = NSHostingView(rootView: FolderView(
            folder: FolderItem(id: UUID(), title: "Productivity", apps: apps),
            iconSize: iconSize,
            showLabel: showsLabel,
            isEditMode: false,
            iconProvider: { _ in NSImage(size: NSSize(width: 1, height: 1)) }
        )
        .environment(LaunchpadDragState())
        .environment(viewModel))

        #expect(folderTile.fittingSize == appTile.fittingSize)
    }
}

private struct EmptyDataSource: AppDataSource {
    func loadPages() throws -> [[LaunchpadItem]] { [] }
}

private struct EmptyLayoutStore: LayoutStoring {
    func loadCustomLayout() -> StoredLayout? { nil }
    func saveCustomLayout(_ layout: StoredLayout) {}
    func clearCustomLayout() {}
}

private struct BlankIconProvider: AppIconProviding {
    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage { NSImage(size: NSSize(width: 1, height: 1)) }
}

private struct EmptyUsageStore: AppUsageStoring {
    func loadHistory() -> AppUsageHistory { AppUsageHistory() }
    func saveHistory(_ history: AppUsageHistory) {}
}
