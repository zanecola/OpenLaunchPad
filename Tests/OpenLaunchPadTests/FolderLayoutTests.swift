import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

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
        .environment(LaunchpadDragState()))

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
    func icon(for bundleID: String) -> NSImage { NSImage(size: NSSize(width: 1, height: 1)) }
}

private struct EmptyUsageStore: AppUsageStoring {
    func loadHistory() -> AppUsageHistory { AppUsageHistory() }
    func saveHistory(_ history: AppUsageHistory) {}
}
