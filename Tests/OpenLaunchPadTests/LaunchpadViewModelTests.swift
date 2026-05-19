import AppKit
import Testing
@testable import OpenLaunchPad

@MainActor
struct LaunchpadViewModelTests {
    @Test
    func loadClampsCurrentPageWhenReloadHasFewerPages() async {
        let dataSource = StubDataSource(pages: [
            [.app(Self.app("Mail"))]
        ])
        let viewModel = LaunchpadViewModel(
            dataSource: dataSource,
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider()
        )
        viewModel.currentPage = 2

        await viewModel.load()

        #expect(viewModel.currentPage == 0)
    }

    @Test
    func moveClampsCurrentPageWhenSourcePageIsRemoved() {
        let sourceApp = Self.app("Mail")
        let targetApp = Self.app("Calendar")
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider()
        )
        viewModel.pages = [
            [.app(targetApp)],
            [.app(sourceApp)]
        ]
        viewModel.currentPage = 1

        viewModel.move(itemID: sourceApp.id, toPage: 0, at: 1)

        #expect(viewModel.pages.count == 1)
        #expect(viewModel.currentPage == 0)
    }

    @Test
    func loadAppliesCustomLayoutAndAppendsNewApps() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let notes = Self.app("Notes")
        let layoutStore = StubLayoutStore(customLayout: [
            [calendar.id],
            [mail.id]
        ])
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: [
                [.app(mail), .app(calendar), .app(notes)]
            ]),
            layoutStore: layoutStore,
            iconProvider: StubIconProvider()
        )

        await viewModel.load()

        #expect(viewModel.pages.map { $0.map(\.title) } == [
            ["Calendar"],
            ["Mail", "Notes"]
        ])
    }

    @Test
    func movePersistsUpdatedLayout() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let layoutStore = StubLayoutStore()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: layoutStore,
            iconProvider: StubIconProvider()
        )
        viewModel.pages = [
            [.app(mail), .app(calendar)]
        ]

        viewModel.move(itemID: mail.id, toPage: 0, at: 2)

        #expect(layoutStore.savedLayouts == [[
            [calendar.id, mail.id]
        ]])
    }

    @Test
    func resetToDefaultClearsCustomLayoutAndReloadsSourceOrder() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let layoutStore = StubLayoutStore(customLayout: [
            [calendar.id],
            [mail.id]
        ])
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: [
                [.app(mail), .app(calendar)]
            ]),
            layoutStore: layoutStore,
            iconProvider: StubIconProvider()
        )

        await viewModel.load()
        await viewModel.resetToDefault()

        #expect(layoutStore.didClear)
        #expect(viewModel.pages.map { $0.map(\.title) } == [
            ["Mail", "Calendar"]
        ])
    }

    @Test
    func pageNavigationStopsAtBounds() {
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider()
        )
        viewModel.pages = [
            [.app(Self.app("Mail"))],
            [.app(Self.app("Calendar"))],
            [.app(Self.app("Notes"))]
        ]

        viewModel.showPreviousPage()
        #expect(viewModel.currentPage == 0)

        viewModel.showNextPage()
        viewModel.showNextPage()
        viewModel.showNextPage()
        #expect(viewModel.currentPage == 2)

        viewModel.showPreviousPage()
        #expect(viewModel.currentPage == 1)
    }

    @Test
    func expandedFolderResolvesFromPagesAndCloses() {
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [Self.app("Terminal")]
        )
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider()
        )
        viewModel.pages = [[.folder(folder)]]

        viewModel.toggleFolder(folder.id)
        #expect(viewModel.expandedFolder == folder)

        viewModel.closeFolder()
        #expect(viewModel.expandedFolder == nil)
    }

    @Test
    func renameFolderUpdatesExpandedFolderAndPersists() {
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [Self.app("Terminal")]
        )
        let layoutStore = StubLayoutStore()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: layoutStore,
            iconProvider: StubIconProvider()
        )
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)

        viewModel.renameFolder(folder.id, to: "Developer Tools")

        #expect(viewModel.expandedFolder?.title == "Developer Tools")
        #expect(layoutStore.savedFolderNames[folder.id] == "Developer Tools")
    }

    @Test
    func loadAppliesPersistedFolderName() async {
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [Self.app("Terminal")]
        )
        let layoutStore = StubLayoutStore(
            customLayout: [[folder.id]],
            folderNames: [folder.id: "Developer Tools"]
        )
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: [[.folder(folder)]]),
            layoutStore: layoutStore,
            iconProvider: StubIconProvider()
        )

        await viewModel.load()

        #expect(viewModel.pages.first?.first?.title == "Developer Tools")
    }

    private static func app(_ title: String) -> AppItem {
        AppItem(id: UUID(), bundleID: "com.example.\(title)", title: title)
    }
}

private final class StubDataSource: AppDataSource {
    var pages: [[LaunchpadItem]]

    init(pages: [[LaunchpadItem]]) {
        self.pages = pages
    }

    func loadPages() throws -> [[LaunchpadItem]] {
        pages
    }
}

private final class StubLayoutStore: LayoutStoring {
    var customLayout: StoredLayout?
    var savedLayouts: [[[UUID]]] = []
    var savedFolderNames: [UUID: String] = [:]
    var didClear = false

    init(customLayout: [[UUID]]? = nil, folderNames: [UUID: String] = [:]) {
        if let customLayout {
            self.customLayout = StoredLayout(pageIDs: customLayout, folderNames: folderNames)
        }
    }

    func loadCustomLayout() -> StoredLayout? {
        customLayout
    }

    func saveCustomLayout(_ layout: StoredLayout) {
        customLayout = layout
        savedLayouts.append(layout.pageIDs)
        savedFolderNames = layout.folderNames
    }

    func clearCustomLayout() {
        didClear = true
        customLayout = nil
    }
}

private final class StubIconProvider: AppIconProviding {
    func icon(for bundleID: String) -> NSImage {
        NSImage(size: NSSize(width: 1, height: 1))
    }
}
