import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

struct FolderPanelLayoutTests {
    private static let roomy = CGSize(width: 1_400, height: 800)

    private func layout(
        apps: Int,
        iconSize: CGFloat = 80,
        in size: CGSize = roomy,
        backdrop: LaunchpadBackdropMode = .fullScreen
    ) -> FolderPanelLayout {
        FolderPanelLayout(appCount: apps, iconSize: iconSize, showsLabels: true, availableSize: size, backdrop: backdrop)
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
        #expect(onLargeDisplay.size == folder.size)
    }

    @Test
    func theNameSitsAboveThePanelOutsideIt() {
        let fullScreen = layout(apps: 6)
        let popup = layout(apps: 6, backdrop: .popup)

        #expect(fullScreen.panelSize.height == fullScreen.gridHeight + 2 * FolderPanelLayout.verticalPadding)
        #expect(fullScreen.size.height == fullScreen.titleHeight + FolderPanelLayout.titleSpacing + fullScreen.panelSize.height)
        #expect(fullScreen.titleHeight > popup.titleHeight)
    }

    @Test
    func appsUseTheGridIconSizeAndCells() {
        let folder = layout(apps: 6, iconSize: 64)
        let grid = AppGridLayout(size: Self.roomy, iconSize: 64, requestedColumns: 7)

        #expect(folder.iconSize == 64)
        #expect(folder.cellWidth == grid.cellWidth)
        #expect(folder.cellHeight == grid.cellHeight)
    }

    @Test(arguments: [LaunchpadBackdropMode.fullScreen, .popup])
    func moreThanThreeRowsScroll(backdrop: LaunchpadBackdropMode) {
        let folder = layout(apps: 20, backdrop: backdrop)

        #expect(folder.columnCount == 5)
        #expect(folder.gridHeight == 3 * folder.cellHeight + 2 * FolderPanelLayout.rowSpacing)
    }

    @Test(arguments: [400.0, 520.0, 640.0])
    func narrowPopupUsesTheColumnsThatFit(paneWidth: Double) {
        // The popup's folder area: the pane minus 16 pt at the sides and 64 pt for the search header.
        let space = CGSize(width: paneWidth - 32, height: 620 - 80)
        let folder = layout(apps: 10, in: space, backdrop: .popup)

        #expect(folder.columnCount < 5)
        #expect(folder.size.width <= space.width)
    }

    @Test
    func shortPopupClampsTheGridSoTheFolderFits() {
        let space = CGSize(width: 828, height: 300 - 80)
        let folder = layout(apps: 10, in: space, backdrop: .popup)

        #expect(folder.gridHeight < folder.cellHeight * 2)
        #expect(folder.size.height <= space.height)
    }

    @Test
    func thePanelIsCenteredBelowItsName() {
        let folder = layout(apps: 6)
        let area = CGRect(x: 24, y: 100, width: 1_200, height: 700)
        let panel = folder.panelFrame(centeredIn: area)

        #expect(panel.size == folder.panelSize)
        #expect(panel.midX == area.midX)
        #expect(panel.maxY - folder.size.height == area.midY - folder.size.height / 2)
    }
}

struct FolderZoomTests {
    private static let bounds = CGSize(width: 1_600, height: 1_000)

    @Test
    func thePanelStartsShrunkOntoItsTile() {
        let tile = CGRect(x: 100, y: 200, width: 64, height: 64)
        let panel = CGRect(x: 400, y: 300, width: 640, height: 320)

        let zoom = FolderZoom(tile: tile, panel: panel, in: Self.bounds)

        #expect(zoom.scale == 0.1)
        #expect(zoom.offset == CGSize(width: 132 - 720, height: 232 - 460))
        #expect(zoom.anchor == UnitPoint(x: 720.0 / 1_600, y: 460.0 / 1_000))
        #expect(zoom.settled == FolderZoom(tile: panel, panel: panel, in: Self.bounds))
    }

    @Test
    func aTallPanelFitsTheTileByItsHeight() {
        let zoom = FolderZoom(
            tile: CGRect(x: 0, y: 0, width: 60, height: 60),
            panel: CGRect(x: 0, y: 0, width: 300, height: 600),
            in: Self.bounds
        )

        #expect(zoom.scale == 0.1)
    }

    @Test
    func neverGrowsNorCollapses() {
        let panel = CGRect(x: 0, y: 0, width: 300, height: 300)
        let big = FolderZoom(tile: CGRect(x: 0, y: 0, width: 900, height: 900), panel: panel, in: Self.bounds)
        let empty = FolderZoom(tile: .zero, panel: panel, in: Self.bounds)

        #expect(big.scale == 1)
        #expect(empty.scale > 0)
    }

    @Test
    func withoutATileThePanelGrowsInPlace() {
        let panel = CGRect(x: 400, y: 300, width: 640, height: 320)

        let zoom = FolderZoom(tile: nil, panel: panel, in: Self.bounds)

        #expect(zoom.scale == 0.85)
        #expect(zoom.offset == .zero)
        #expect(zoom.anchor == UnitPoint(x: 720.0 / 1_600, y: 460.0 / 1_000))
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
    func loadPages(pageCapacity: Int) throws -> [[LaunchpadItem]] { [] }
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
