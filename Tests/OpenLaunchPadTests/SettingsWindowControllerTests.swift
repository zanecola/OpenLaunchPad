import AppKit
import Testing
@testable import OpenLaunchPad

/// The window is created but never shown.
@MainActor
struct SettingsWindowControllerTests {
    @Test
    func panesAreToolbarTabsInPaneOrder() throws {
        let tabs = try #require(makeController().window?.contentViewController as? NSTabViewController)

        #expect(tabs.tabStyle == .toolbar)
        #expect(tabs.tabViewItems.map(\.label) == SettingsPane.allCases.map(\.title))
    }

    @Test
    func windowOpensSizedToTheGeneralPane() throws {
        let window = try #require(makeController().window)
        let tabs = try #require(window.contentViewController as? NSTabViewController)
        let general = try #require(tabs.tabViewItems.first?.viewController).preferredContentSize

        let content = window.contentRect(forFrameRect: window.frame).size
        // The window keeps its frame on whole points, and the pane's height can be fractional.
        #expect(content.width == general.width)
        #expect(abs(content.height - general.height) < 1)
        #expect(general.width == SettingsWindowController.paneWidth)
        // Below the cap, so the pane shows its last caption instead of scrolling.
        #expect(general.height < SettingsWindowController.maxPaneHeight)
    }

    @Test
    func noPaneGrowsTheWindowPastTheCap() throws {
        let tabs = try #require(makeController().window?.contentViewController as? NSTabViewController)
        let heights = tabs.tabViewItems.compactMap { $0.viewController?.preferredContentSize.height }

        #expect(heights.count == SettingsPane.allCases.count)
        #expect(heights.allSatisfy { $0 > 0 && $0 <= SettingsWindowController.maxPaneHeight })
    }

    private func makeController() -> SettingsWindowController {
        let viewModel = LaunchpadViewModel(
            dataSource: EmptyDataSource(),
            layoutStore: NullLayoutStore(),
            iconProvider: BlankIconProvider(),
            appUsageStore: NullAppUsageStore()
        )
        return SettingsWindowController(
            viewModel: viewModel,
            config: ConfigStore(defaults: InMemoryKeyValueStore())
        )
    }
}

private final class EmptyDataSource: AppDataSource {
    func loadPages(pageCapacity: Int) throws -> [[LaunchpadItem]] { [] }
}

private final class NullLayoutStore: LayoutStoring {
    func loadCustomLayout() -> StoredLayout? { nil }
    func saveCustomLayout(_ layout: StoredLayout) {}
    func clearCustomLayout() {}
}

private final class BlankIconProvider: AppIconProviding {
    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage {
        NSImage(size: NSSize(width: 1, height: 1))
    }
}

private final class NullAppUsageStore: AppUsageStoring {
    func loadHistory() -> AppUsageHistory { AppUsageHistory() }
    func saveHistory(_ history: AppUsageHistory) {}
}
