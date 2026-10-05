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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
    func sortByNamePreservesPageSizesSortsFolderAppsAndPersists() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let terminal = Self.app("Terminal")
        let activityMonitor = Self.app("Activity Monitor")
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [terminal, activityMonitor]
        )
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [
            [.app(mail), .folder(folder)],
            [.app(calendar)]
        ]

        viewModel.sortByName(.ascending)

        #expect(viewModel.pages.map(\.count) == [2, 1])
        #expect(viewModel.pages.flatMap { $0 }.map(\.title) == ["Calendar", "Mail", "Utilities"])
        guard case .folder(let sortedFolder) = viewModel.pages[1][0] else {
            Issue.record("Expected sorted folder")
            return
        }
        #expect(sortedFolder.apps.map(\.title) == ["Activity Monitor", "Terminal"])
        #expect(store.savedLayouts.count == 1)
    }

    @Test
    func sortByNameDescendingUsesReverseOrder() {
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[
            .app(Self.app("Calendar")),
            .app(Self.app("Mail")),
            .app(Self.app("App Store"))
        ]]

        viewModel.sortByName(.descending)

        #expect(viewModel.pages[0].map(\.title) == ["Mail", "Calendar", "App Store"])
    }

    @Test
    func uninstallRemovesAppNormalizesFolderAndPersistsAfterTrashSucceeds() throws {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let notes = Self.app("Notes")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [mail, calendar])
        let store = StubLayoutStore()
        let applicationManager = StubApplicationManager()
        let launchDate = Date(timeIntervalSince1970: 100)
        let usageStore = StubAppUsageStore(history: AppUsageHistory(records: [
            AppUsageRecord(bundleID: mail.bundleID, launchCount: 3, lastLaunchedAt: launchDate),
            AppUsageRecord(bundleID: notes.bundleID, launchCount: 1, lastLaunchedAt: launchDate)
        ]))
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: store,
            iconProvider: StubIconProvider(),
            applicationManager: applicationManager,
            appUsageStore: usageStore
        )
        viewModel.pages = [[.folder(folder), .app(notes)]]

        try viewModel.uninstall(mail)

        #expect(applicationManager.uninstalledApps == [mail])
        #expect(viewModel.pages == [[.app(calendar), .app(notes)]])
        #expect(store.savedLayouts == [StoredLayout(pageIDs: [[calendar.id, notes.id]])])
        #expect(usageStore.savedHistories.last?.records.map(\.bundleID) == [notes.bundleID])
    }

    @Test
    func failedUninstallLeavesLayoutUntouched() {
        let mail = Self.app("Mail")
        let applicationManager = StubApplicationManager(uninstallError: TestApplicationError.failed)
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            applicationManager: applicationManager,
            appUsageStore: StubAppUsageStore()
        )
        viewModel.pages = [[.app(mail)]]

        #expect(throws: TestApplicationError.self) {
            try viewModel.uninstall(mail)
        }
        #expect(viewModel.pages == [[.app(mail)]])
    }

    @Test
    func launchCountsUsageOnlyWhenTheAppCanBeFound() {
        let mail = Self.app("Mail")
        let deleted = Self.app("Deleted")
        let applicationManager = StubApplicationManager(missingBundleIDs: [deleted.bundleID])
        let usageStore = StubAppUsageStore()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            applicationManager: applicationManager,
            appUsageStore: usageStore
        )
        viewModel.pages = [[.app(mail), .app(deleted)]]

        #expect(!viewModel.launch(deleted))
        #expect(usageStore.savedHistories.isEmpty)

        #expect(viewModel.launch(mail))
        #expect(applicationManager.launchedApps == [mail])
        #expect(usageStore.savedHistories.last?.records.map(\.bundleID) == [mail.bundleID])
    }

    @Test
    func removeFromLayoutDropsAMissingAppWithoutTrashingAnything() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let notes = Self.app("Notes")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [mail, calendar])
        let store = StubLayoutStore()
        let applicationManager = StubApplicationManager()
        let usageStore = StubAppUsageStore(history: AppUsageHistory(records: [
            AppUsageRecord(bundleID: mail.bundleID, launchCount: 2, lastLaunchedAt: Date(timeIntervalSince1970: 100))
        ]))
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: store,
            iconProvider: StubIconProvider(),
            applicationManager: applicationManager,
            appUsageStore: usageStore
        )
        viewModel.pages = [[.folder(folder), .app(notes)]]
        viewModel.toggleFolder(folder.id)

        viewModel.removeFromLayout(mail)

        #expect(applicationManager.uninstalledApps.isEmpty)
        #expect(viewModel.pages == [[.app(calendar), .app(notes)]])
        #expect(viewModel.expandedFolderID == nil)
        #expect(store.savedLayouts == [StoredLayout(pageIDs: [[calendar.id, notes.id]])])
        #expect(usageStore.savedHistories.last?.records.isEmpty == true)
    }

    @Test
    func frequentlyUsedAppsResolveFoldersAndIgnoreMissingApps() {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [calendar])
        let usageStore = StubAppUsageStore(history: AppUsageHistory(records: [
            AppUsageRecord(
                bundleID: "com.example.missing",
                launchCount: 100,
                lastLaunchedAt: Date(timeIntervalSince1970: 500)
            ),
            AppUsageRecord(
                bundleID: calendar.bundleID,
                launchCount: 4,
                lastLaunchedAt: Date(timeIntervalSince1970: 300)
            ),
            AppUsageRecord(
                bundleID: mail.bundleID,
                launchCount: 2,
                lastLaunchedAt: Date(timeIntervalSince1970: 400)
            )
        ]))
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: usageStore
        )
        viewModel.pages = [[.app(mail), .folder(folder)]]

        #expect(viewModel.frequentlyUsedApps(limit: 2) == [calendar, mail])
        #expect(viewModel.hasAppUsageHistory)
    }

    @Test
    func recordingAndClearingUsagePersistsAndUpdatesSuggestions() {
        let mail = Self.app("Mail")
        let usageStore = StubAppUsageStore()
        let launchDate = Date(timeIntervalSince1970: 600)
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: usageStore,
            now: { launchDate }
        )
        viewModel.pages = [[.app(mail)]]

        viewModel.recordLaunch(of: mail)

        #expect(viewModel.frequentlyUsedApps(limit: 1) == [mail])
        #expect(usageStore.savedHistories.last?.records == [
            AppUsageRecord(
                bundleID: mail.bundleID,
                launchCount: 1,
                lastLaunchedAt: launchDate
            )
        ])

        viewModel.clearAppUsageHistory()

        #expect(viewModel.frequentlyUsedApps(limit: 1).isEmpty)
        #expect(!viewModel.hasAppUsageHistory)
        #expect(usageStore.savedHistories.last?.records.isEmpty == true)
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
    func renameFolderToItsCurrentTitleDoesNotPersist() {
        let folder = FolderItem(
            id: UUID(),
            title: "Utilities",
            apps: [Self.app("Terminal"), Self.app("Console")]
        )
        let layoutStore = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: layoutStore)
        viewModel.pages = [[.folder(folder)]]

        viewModel.renameFolder(folder.id, to: " Utilities ")
        viewModel.renameFolder(folder.id, to: "   ")

        #expect(viewModel.pages == [[.folder(folder)]])
        #expect(layoutStore.savedLayouts.isEmpty)
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
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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
    func orphanStoredFolderDoesNotConsumeAppsFromSourceOrder() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let orphanFolderID = UUID()
        let stored = StoredLayout(
            pageIDs: [[mail.id]],
            folders: [StoredFolder(id: orphanFolderID, title: "Orphan", appIDs: [calendar.id])]
        )
        let viewModel = Self.viewModel(
            pages: [[.app(mail), .app(calendar)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.app(mail), .app(calendar)]])
    }

    @Test
    func duplicateStoredFolderMembershipOnlyConsumesWhenPlaced() async {
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let placedFolderID = UUID()
        let orphanFolderID = UUID()
        let stored = StoredLayout(
            pageIDs: [[placedFolderID]],
            folders: [
                StoredFolder(id: orphanFolderID, title: "Orphan", appIDs: [mail.id]),
                StoredFolder(id: placedFolderID, title: "Work", appIDs: [calendar.id, mail.id])
            ]
        )
        let viewModel = Self.viewModel(
            pages: [[.app(mail), .app(calendar)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.folder(FolderItem(
            id: placedFolderID,
            title: "Work",
            apps: [calendar, mail]
        ))]])
    }

    @Test
    func restoredSourceFolderKeepsNewlyDiscoveredChildren() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let activityMonitor = Self.app("Activity Monitor")
        let folderID = UUID()
        let sourceFolder = FolderItem(id: folderID, title: "Utilities", apps: [
            terminal,
            console,
            activityMonitor
        ])
        let stored = StoredLayout(
            pageIDs: [[folderID]],
            folders: [StoredFolder(id: folderID, title: "Developer Tools", appIDs: [console.id, terminal.id])]
        )
        let viewModel = Self.viewModel(
            pages: [[.folder(sourceFolder)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages == [[.folder(FolderItem(
            id: folderID,
            title: "Developer Tools",
            apps: [console, terminal, activityMonitor]
        ))]])
    }

    @Test
    func appDraggedOutOfSourceFolderStaysOutAfterReload() async {
        let mail = Self.app("Mail")
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let monitor = Self.app("Activity Monitor")
        let utilities = FolderItem(id: UUID(), title: "Utilities", apps: [terminal, console, monitor])
        let viewModel = Self.viewModel(pages: [[.app(mail), .folder(utilities)]], store: StubLayoutStore())
        await viewModel.load()

        #expect(viewModel.removeApp(terminal.id, fromFolder: utilities.id))
        let edited = viewModel.pages
        await viewModel.load()

        #expect(viewModel.pages == edited)
    }

    @Test
    func dissolvedSourceFolderStaysDissolvedAfterReload() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let mail = Self.app("Mail")
        let notes = Self.app("Notes")
        let utilities = FolderItem(id: UUID(), title: "Utilities", apps: [terminal, console])
        let viewModel = Self.viewModel(
            pages: [[.folder(utilities), .app(mail)], [.app(notes)]],
            store: StubLayoutStore()
        )
        await viewModel.load()

        #expect(viewModel.removeApp(terminal.id, fromFolder: utilities.id))
        let edited = viewModel.pages
        await viewModel.load()

        #expect(viewModel.pages == edited)
    }

    @Test
    func sourceFolderAppMovedIntoLaterUserFolderStaysThereAfterReload() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let monitor = Self.app("Activity Monitor")
        let mail = Self.app("Mail")
        let calendar = Self.app("Calendar")
        let utilities = FolderItem(id: UUID(), title: "Utilities", apps: [terminal, console, monitor])
        let viewModel = Self.viewModel(
            pages: [[.folder(utilities), .app(mail), .app(calendar)]],
            store: StubLayoutStore()
        )
        await viewModel.load()

        #expect(viewModel.combineApps(draggedID: calendar.id, targetID: mail.id))
        let userFolderID = viewModel.pages[0][1].id
        #expect(viewModel.removeApp(terminal.id, fromFolder: utilities.id))
        #expect(viewModel.addApp(terminal.id, toFolder: userFolderID))
        let edited = viewModel.pages
        await viewModel.load()

        #expect(viewModel.pages == edited)
    }

    @Test
    func newAppInSourceFolderJoinsItWithoutPullingBackMovedApps() async {
        let mail = Self.app("Mail")
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let monitor = Self.app("Activity Monitor")
        let installed = Self.app("Disk Utility")
        let folderID = UUID()
        let source = StubDataSource(pages: [[
            .app(mail),
            .folder(FolderItem(id: folderID, title: "Utilities", apps: [terminal, console, monitor]))
        ]])
        let viewModel = LaunchpadViewModel(
            dataSource: source,
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
        )
        await viewModel.load()
        #expect(viewModel.removeApp(terminal.id, fromFolder: folderID))

        source.pages = [[
            .app(mail),
            .folder(FolderItem(id: folderID, title: "Utilities", apps: [terminal, console, monitor, installed]))
        ]]
        await viewModel.load()

        #expect(viewModel.pages == [[
            .app(mail),
            .folder(FolderItem(id: folderID, title: "Utilities", apps: [console, monitor, installed])),
            .app(terminal)
        ]])
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
            appUsageStore: StubAppUsageStore(),
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

    @Test
    func searchMatchesAppAliases() {
        let calendar = AppItem(id: UUID(), bundleID: "com.example.calendar", title: "日历", aliases: ["Calendar"])
        let code = AppItem(id: UUID(), bundleID: "com.example.code", title: "Visual Studio Code", aliases: ["Code"])
        let mail = Self.app("Mail")
        let folder = FolderItem(id: UUID(), title: "Tools", apps: [code, mail])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.app(calendar), .folder(folder)]]

        viewModel.searchQuery = "calendar"
        #expect(viewModel.searchResults?.map(\.id) == [calendar.id])

        viewModel.searchQuery = "CODE"
        #expect(viewModel.searchResults?.map(\.id) == [folder.id])
    }

    private static func viewModel(
        pages: [[LaunchpadItem]],
        store: StubLayoutStore
    ) -> LaunchpadViewModel {
        LaunchpadViewModel(
            dataSource: StubDataSource(pages: pages),
            layoutStore: store,
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore()
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

private final class StubAppUsageStore: AppUsageStoring {
    var history: AppUsageHistory
    var savedHistories: [AppUsageHistory] = []

    init(history: AppUsageHistory = AppUsageHistory()) {
        self.history = history
    }

    func loadHistory() -> AppUsageHistory {
        history
    }

    func saveHistory(_ history: AppUsageHistory) {
        self.history = history
        savedHistories.append(history)
    }
}

private enum TestApplicationError: Error {
    case failed
}

@MainActor
private final class StubApplicationManager: ApplicationManaging {
    var uninstalledApps: [AppItem] = []
    var launchedApps: [AppItem] = []
    let uninstallError: Error?
    let missingBundleIDs: Set<String>

    init(uninstallError: Error? = nil, missingBundleIDs: Set<String> = []) {
        self.uninstallError = uninstallError
        self.missingBundleIDs = missingBundleIDs
    }

    func uninstallURL(for app: AppItem) -> URL? { app.bundleURL }

    func launch(_ app: AppItem) throws {
        if missingBundleIDs.contains(app.bundleID) {
            throw ApplicationManagerError.applicationNotFound(app.title)
        }
        launchedApps.append(app)
    }
    func revealInFinder(_ app: AppItem) throws {}
    func showInfo(_ app: AppItem) throws {}

    func uninstall(_ app: AppItem) throws {
        if let uninstallError { throw uninstallError }
        uninstalledApps.append(app)
    }
}
