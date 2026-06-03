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
    func loadClosesExpandedFolderWhenReloadRemovesIt() async {
        let folderID = UUID()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: [[.app(Self.app("Mail"))]]),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider()
        )
        viewModel.expandedFolderID = folderID

        await viewModel.load()

        #expect(viewModel.expandedFolderID == nil)
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

        #expect(layoutStore.savedLayouts == [StoredLayout(
            pageIDs: [[calendar.id, mail.id]]
        )])
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
        #expect(layoutStore.savedLayouts == [StoredLayout(
            pageIDs: [[folder.id]],
            folders: [StoredFolder(
                id: folder.id,
                title: "Developer Tools",
                appIDs: folder.apps.map(\.id)
            )]
        )])
    }

    @Test
    func loadAppliesPersistedFolderName() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [terminal, console]
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

    @Test
    func loadReconstructsUserFolderFromStoredAppIDs() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let folderID = UUID()
        let stored = StoredLayout(
            pageIDs: [[folderID]],
            folders: [StoredFolder(id: folderID, title: "Work", appIDs: [calendar.id, mail.id])]
        )
        let viewModel = Self.viewModel(
            pages: [[.app(mail), .app(calendar)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.folder(FolderItem(
            id: folderID,
            title: "Work",
            apps: [calendar, mail]
        ))]])
    }

    @Test
    func loadMigratedFolderUsesSourceMembershipAndStoredTitle() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let folderID = UUID()
        let sourceFolder = FolderItem(id: folderID, title: "Utilities", apps: [terminal, console])
        let stored = StoredLayout(
            pageIDs: [[folderID]],
            folders: [StoredFolder(id: folderID, title: "Developer Tools", appIDs: [])]
        )
        let viewModel = Self.viewModel(
            pages: [[.folder(sourceFolder)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.folder(FolderItem(
            id: folderID,
            title: "Developer Tools",
            apps: [terminal, console]
        ))]])
    }

    @Test
    func loadResolvesStoredMembershipAcrossTopLevelAndSourceFolders() async {
        let mail = Self.app("Mail")
        let terminal = Self.app("Terminal")
        let missing = Self.app("Missing")
        let sourceFolder = FolderItem(id: UUID(), title: "Utilities", apps: [terminal])
        let folderID = UUID()
        let stored = StoredLayout(
            pageIDs: [[folderID]],
            folders: [StoredFolder(
                id: folderID,
                title: "Mixed",
                appIDs: [terminal.id, missing.id, mail.id]
            )]
        )
        let viewModel = Self.viewModel(
            pages: [[.app(mail), .folder(sourceFolder)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.folder(FolderItem(
            id: folderID,
            title: "Mixed",
            apps: [terminal, mail]
        ))]])
    }

    @Test
    func loadNormalizesSparseStoredFoldersAndAppendsUnplacedItemsWithoutDuplicates() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let notes = Self.app("Notes")
        let missingID = UUID()
        let survivingFolderID = UUID()
        let emptyFolderID = UUID()
        let stored = StoredLayout(
            pageIDs: [[emptyFolderID, survivingFolderID], []],
            folders: [
                StoredFolder(id: emptyFolderID, title: "Gone", appIDs: [missingID]),
                StoredFolder(id: survivingFolderID, title: "Solo", appIDs: [calendar.id, missingID])
            ]
        )
        let viewModel = Self.viewModel(
            pages: [[.app(mail), .app(calendar)], [.app(notes)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [
            [.app(calendar)],
            [.app(mail), .app(notes)]
        ])
    }

    @Test
    func successfulMutationsPersistExactlyOnceAndUseInjectedFolderID() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let notes = Self.app("Notes")
        let folderID = UUID()
        let store = StubLayoutStore()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: store,
            iconProvider: StubIconProvider(),
            makeUUID: { folderID }
        )
        viewModel.pages = [[.app(mail), .app(calendar), .app(notes)]]

        #expect(viewModel.combineApps(draggedID: mail.id, targetID: calendar.id))
        #expect(viewModel.pages[0][0].id == folderID)
        #expect(store.savedLayouts.count == 1)
        #expect(viewModel.addApp(notes.id, toFolder: folderID))
        #expect(store.savedLayouts.count == 2)
        #expect(viewModel.reorderApp(mail.id, inFolder: folderID, relativeTo: notes.id, placement: .after))
        #expect(store.savedLayouts.count == 3)
        #expect(viewModel.removeApp(mail.id, fromFolder: folderID))
        #expect(store.savedLayouts.count == 4)
        #expect(store.savedLayouts.last == StoredLayout(
            pageIDs: [[folderID, mail.id]],
            folders: [StoredFolder(id: folderID, title: "Folder", appIDs: [calendar.id, notes.id])]
        ))
    }

    @Test
    func reorderTopLevelPersistsOnce() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.app(mail), .app(calendar)]]

        #expect(viewModel.reorderTopLevel(
            itemID: calendar.id,
            relativeTo: mail.id,
            placement: .before
        ))
        #expect(store.savedLayouts.count == 1)
    }

    @Test
    func invalidMutationsPersistZeroTimes() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [calendar])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.app(mail), .folder(folder)]]
        let missingID = UUID()

        #expect(!viewModel.reorderTopLevel(
            itemID: missingID,
            relativeTo: mail.id,
            placement: .before
        ))
        #expect(!viewModel.combineApps(draggedID: missingID, targetID: mail.id))
        #expect(!viewModel.addApp(missingID, toFolder: folder.id))
        #expect(!viewModel.reorderApp(
            missingID,
            inFolder: folder.id,
            relativeTo: calendar.id,
            placement: .after
        ))
        #expect(!viewModel.removeApp(missingID, fromFolder: folder.id))
        #expect(store.savedLayouts.isEmpty)
    }

    @Test
    func removingAppThatDissolvesExpandedFolderClosesIt() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [mail, calendar])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)

        #expect(viewModel.removeApp(mail.id, fromFolder: folder.id))

        #expect(viewModel.expandedFolderID == nil)
        #expect(store.savedLayouts.count == 1)
    }

    private static func viewModel(
        pages: [[LaunchpadItem]],
        store: StubLayoutStore
    ) -> LaunchpadViewModel {
        LaunchpadViewModel(
            dataSource: StubDataSource(pages: pages),
            layoutStore: store,
            iconProvider: StubIconProvider()
        )
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
    var savedLayouts: [StoredLayout] = []
    var didClear = false

    init(customLayout: [[UUID]]? = nil, folderNames: [UUID: String] = [:]) {
        if let customLayout {
            self.customLayout = StoredLayout(
                pageIDs: customLayout,
                folders: folderNames.map { StoredFolder(id: $0.key, title: $0.value, appIDs: []) }
            )
        }
    }

    init(layout: StoredLayout) {
        customLayout = layout
    }

    func loadCustomLayout() -> StoredLayout? {
        customLayout
    }

    func saveCustomLayout(_ layout: StoredLayout) {
        customLayout = layout
        savedLayouts.append(layout)
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
