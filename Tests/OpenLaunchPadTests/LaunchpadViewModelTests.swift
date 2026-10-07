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
    func aSettledSwipeMakesTheNearestPageCurrent() {
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

        for (position, page) in [(1.0, 1), (1.4, 1), (1.6, 2), (-0.3, 0), (2.7, 2)] {
            viewModel.pagePosition = position
            viewModel.settlePageScroll()
            #expect(viewModel.currentPage == page, "position \(position)")
        }
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
    func uninstallKeepsTheTileInPlaceWhileAnotherCopyStaysInstalled() async throws {
        let scanned = URL(fileURLWithPath: "/Applications/Mail 2.app", isDirectory: true)
        let remaining = URL(fileURLWithPath: "/Applications/Mail.app", isDirectory: true)
        var mail = Self.app("Mail")
        mail.bundleURL = scanned
        let calendar = Self.app("Calendar")
        let dataSource = StubDataSource(pages: [[.app(mail), .app(calendar)]])
        let store = StubLayoutStore(customLayout: [[calendar.id, mail.id]])
        let usageStore = StubAppUsageStore(history: AppUsageHistory(records: [
            AppUsageRecord(bundleID: mail.bundleID, launchCount: 3, lastLaunchedAt: Date(timeIntervalSince1970: 100))
        ]))
        let applicationManager = StubApplicationManager(otherCopies: [remaining])
        let viewModel = LaunchpadViewModel(
            dataSource: dataSource,
            layoutStore: store,
            iconProvider: StubIconProvider(),
            applicationManager: applicationManager,
            appUsageStore: usageStore
        )
        await viewModel.load()

        // After the trash, the scan finds the remaining copy under the same ID.
        var remainingMail = mail
        remainingMail.bundleURL = remaining
        dataSource.pages = [[.app(remainingMail), .app(calendar)]]
        try viewModel.uninstall(mail)

        #expect(applicationManager.uninstalledApps == [mail])
        #expect(viewModel.pages == [[.app(calendar), .app(remainingMail)]])
        #expect(store.savedLayouts.isEmpty)
        #expect(usageStore.savedHistories.isEmpty)
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

        #expect(viewModel.frequentlyUsedApps == [calendar, mail])
        #expect(viewModel.hasAppUsageHistory)
    }

    @Test
    func launchesRankAtTheNextShowAndClearingTheHistoryEmptiesSuggestionsAtOnce() {
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

        #expect(viewModel.frequentlyUsedApps.isEmpty)
        #expect(usageStore.savedHistories.last?.records == [
            AppUsageRecord(
                bundleID: mail.bundleID,
                launchCount: 1,
                lastLaunchedAt: launchDate
            )
        ])

        viewModel.beginPresentation()

        #expect(viewModel.frequentlyUsedApps == [mail])

        viewModel.clearAppUsageHistory()

        #expect(viewModel.frequentlyUsedApps.isEmpty)
        #expect(!viewModel.hasAppUsageHistory)
        #expect(usageStore.savedHistories.last?.records.isEmpty == true)
    }

    @Test
    func frequentlyUsedOrderHoldsThroughAShowButFollowsThePages() {
        let mail = Self.app("Mail")
        let notes = Self.app("Notes")
        let work = FolderItem(id: UUID(), title: "Work", apps: [mail, Self.app("Calendar")])
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore(history: AppUsageHistory(records: [
                AppUsageRecord(bundleID: mail.bundleID, launchCount: 2, lastLaunchedAt: Date(timeIntervalSince1970: 100)),
                AppUsageRecord(bundleID: notes.bundleID, launchCount: 1, lastLaunchedAt: Date(timeIntervalSince1970: 100))
            ]))
        )
        viewModel.pages = [[.app(mail), .app(notes)]]
        viewModel.beginPresentation()

        viewModel.recordLaunch(of: notes)
        viewModel.recordLaunch(of: notes)

        #expect(viewModel.frequentlyUsedApps == [mail, notes])

        viewModel.pages = [[.folder(work), .app(notes)]]
        #expect(viewModel.frequentlyUsedApps == [mail, notes])

        viewModel.pages = [[.app(notes)]]
        #expect(viewModel.frequentlyUsedApps == [notes])

        viewModel.pages = [[.app(mail), .app(notes)]]
        viewModel.beginPresentation()
        #expect(viewModel.frequentlyUsedApps == [notes, mail])
    }

    @Test
    func rearrangingPagesDoesNotInvalidateViewsShowingFrequentlyUsedApps() {
        let mail = Self.app("Mail")
        let notes = Self.app("Notes")
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore(history: AppUsageHistory(records: [
                AppUsageRecord(bundleID: mail.bundleID, launchCount: 1, lastLaunchedAt: Date(timeIntervalSince1970: 100))
            ]))
        )
        viewModel.pages = [[.app(mail), .app(notes)]]

        #expect(!observationFires(
            when: { viewModel.pages = [[.app(notes)], [.app(mail)]] },
            reading: { _ = viewModel.frequentlyUsedApps }
        ))
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
    func storedRawDirectoryNameShowsTheLocalizedFolderTitleButARenameStays() async {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let docs = Self.app("Docs")
        let sheets = Self.app("Sheets")
        let utilities = FolderItem(id: UUID(), title: "实用工具", apps: [console, terminal], directoryName: "Utilities")
        let webApps = FolderItem(id: UUID(), title: "Chrome Apps", apps: [docs, sheets], directoryName: "Chrome Apps.localized")
        // Saved before scanned folders were titled with their localized names.
        let stored = StoredLayout(
            pageIDs: [[utilities.id, webApps.id]],
            folders: [
                StoredFolder(id: utilities.id, title: "Utilities", appIDs: [console.id, terminal.id]),
                StoredFolder(id: webApps.id, title: "Web", appIDs: [docs.id, sheets.id])
            ]
        )
        let viewModel = Self.viewModel(
            pages: [[.folder(utilities), .folder(webApps)]],
            store: StubLayoutStore(layout: stored)
        )

        await viewModel.load()

        #expect(viewModel.pages.flatMap { $0 }.map(\.title) == ["实用工具", "Web"])
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

    // MARK: - Page capacity

    @Test
    func loadAsksForPagesOfTheCapacityAndSavesNothingWhenTheyFit() async {
        let source = StubDataSource(pages: [[.app(Self.app("Mail")), .app(Self.app("Notes"))]])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(source: source, store: store, pageCapacity: 2)

        await viewModel.load()

        #expect(source.requestedCapacities == [2])
        #expect(viewModel.pages.map { $0.map(\.title) } == [["Mail", "Notes"]])
        #expect(store.savedLayouts.isEmpty)
    }

    @Test
    func loadMovesASavedPagesOverflowOntoTheNextPageAndSavesIt() async {
        let apps = ["A", "B", "C", "D", "E"].map(Self.app)
        let store = StubLayoutStore(customLayout: [apps.prefix(3).map(\.id), apps.suffix(2).map(\.id)])
        let viewModel = Self.viewModel(
            source: StubDataSource(pages: [apps.map { .app($0) }]),
            store: store,
            pageCapacity: 2
        )

        await viewModel.load()

        #expect(viewModel.pages.map { $0.map(\.title) } == [["A", "B"], ["C", "D"], ["E"]])
        #expect(store.savedLayouts.count == 1)
        #expect(store.savedLayouts.last?.pageIDs == viewModel.pages.map { $0.map(\.id) })
    }

    @Test
    func newAppsFillTheLastPagesFreeSlotsThenANewPage() async {
        let apps = ["A", "B", "C", "D"].map(Self.app)
        let store = StubLayoutStore(customLayout: [[apps[0].id], [apps[1].id]])
        let viewModel = Self.viewModel(
            source: StubDataSource(pages: [apps.map { .app($0) }]),
            store: store,
            pageCapacity: 2
        )

        await viewModel.load()

        // The first page keeps its free slot.
        #expect(viewModel.pages.map { $0.map(\.title) } == [["A"], ["B", "C"], ["D"]])
    }

    @Test
    func capacityChangesReloadAndNeverPullAppsBack() async {
        let apps = ["A", "B", "C", "D", "E"].map(Self.app)
        let source = StubDataSource(pages: [apps.map { .app($0) }])
        let store = StubLayoutStore(customLayout: [apps.prefix(3).map(\.id), apps.suffix(2).map(\.id)])
        let viewModel = Self.viewModel(source: source, store: store, pageCapacity: 3)
        await viewModel.load()
        #expect(store.savedLayouts.isEmpty)

        viewModel.pageCapacity = 2

        #expect(viewModel.pages.map { $0.map(\.title) } == [["A", "B"], ["C", "D"], ["E"]])
        #expect(store.savedLayouts.count == 1)

        viewModel.pageCapacity = 4

        #expect(source.requestedCapacities == [3, 2, 4])
        #expect(viewModel.pages.map { $0.map(\.title) } == [["A", "B"], ["C", "D"], ["E"]])
        #expect(store.savedLayouts.count == 1)
    }

    @Test
    func capacityChangesRefillPagesNeverArrangedInTheSourcesOrder() async {
        let apps = ["A", "B", "C", "D", "E"].map(Self.app)
        let source = StubDataSource(chunking: apps.map { .app($0) })
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(source: source, store: store, pageCapacity: 2)
        await viewModel.load()
        #expect(viewModel.pages.map { $0.map(\.title) } == [["A", "B"], ["C", "D"], ["E"]])

        viewModel.pageCapacity = 3

        // Nothing was saved, so the source's pages are chunked again and C moves back.
        #expect(viewModel.pages.map { $0.map(\.title) } == [["A", "B", "C"], ["D", "E"]])
        #expect(store.savedLayouts.isEmpty)
    }

    @Test
    func appDraggedOutOfAFolderOnAFullPagePushesTheLastItemOntoTheNextPage() {
        let mail = Self.app("Mail")
        let notes = Self.app("Notes")
        let music = Self.app("Music")
        let folder = FolderItem(id: UUID(), title: "Work", apps: [notes, Self.app("Calendar"), Self.app("Maps")])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(source: StubDataSource(pages: []), store: store, pageCapacity: 2)
        viewModel.pages = [[.app(mail), .folder(folder)], [.app(music)]]

        #expect(viewModel.removeApp(notes.id, fromFolder: folder.id))

        #expect(viewModel.pages.map { $0.map(\.title) } == [["Mail", "Work"], ["Notes", "Music"]])
        #expect(store.savedLayouts.count == 1)
    }

    @Test
    func aDropThatEmptiesAnEarlierPageKeepsTheTargetPageShowing() {
        let dragged = Self.app("Mail")
        let target = Self.app("Notes")
        let folderID = UUID()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore(),
            pageCapacity: 2,
            makeUUID: { folderID }
        )
        viewModel.pages = [
            [.app(Self.app("Maps")), .app(Self.app("Music"))],
            [.app(dragged)],
            [.app(target), .app(Self.app("Photos"))],
            [.app(Self.app("Books"))]
        ]
        viewModel.currentPage = 2

        #expect(viewModel.combineApps(draggedID: dragged.id, targetID: target.id))

        #expect(viewModel.pages.count == 3)
        #expect(viewModel.pages[1].first?.id == folderID)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    func aDropThatEmptiesAnEarlierPageFollowsTheTargetPageThroughAnOverflow() {
        let dragged = Self.app("Mail")
        let target = Self.app("Notes")
        let viewModel = Self.viewModel(source: StubDataSource(pages: []), store: StubLayoutStore(), pageCapacity: 2)
        viewModel.pages = [
            [.app(Self.app("Maps")), .app(Self.app("Music"))],
            [.app(dragged)],
            [.app(target), .app(Self.app("Photos"))],
            [.app(Self.app("Books"))]
        ]
        viewModel.currentPage = 2

        #expect(viewModel.reorderTopLevel(itemID: dragged.id, relativeTo: target.id, placement: .after))

        #expect(viewModel.pages.map { $0.map(\.title) } == [["Maps", "Music"], ["Notes", "Mail"], ["Photos", "Books"]])
        #expect(viewModel.currentPage == 1)
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
    func stepBackClosesFolderThenClearsSearchThenLeavesEditMode() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(folder)]]
        viewModel.isEditMode = true
        viewModel.searchQuery = "work"
        viewModel.toggleFolder(folder.id)

        #expect(viewModel.stepBack())
        #expect(viewModel.expandedFolderID == nil)
        #expect(viewModel.searchQuery == "work")

        #expect(viewModel.stepBack())
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.isEditMode)

        #expect(viewModel.stepBack())
        #expect(!viewModel.isEditMode)

        #expect(!viewModel.stepBack())
    }

    @Test
    func aFolderRemembersTheTileItOpenedFrom() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(folder)]]
        let tile = CGRect(x: 120, y: 340, width: 64, height: 64)

        viewModel.toggleFolder(folder.id, from: tile)
        #expect(viewModel.expandedFolderTileFrame == tile)
        // Return on the open folder's search result opens nothing new.
        viewModel.openFolder(folder.id)
        #expect(viewModel.expandedFolderTileFrame == tile)

        viewModel.closeFolder()
        viewModel.openFolder(folder.id)
        #expect(viewModel.expandedFolderID == folder.id)
        #expect(viewModel.expandedFolderTileFrame == nil)
    }

    @Test
    func returnSavesTheEditedFolderName() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)

        viewModel.beginRenamingFolder()
        #expect(viewModel.folderTitleDraft == "Work")
        viewModel.folderTitleDraft = " Office "
        viewModel.commitFolderRename()

        #expect(viewModel.folderTitleDraft == nil)
        #expect(viewModel.expandedFolder?.title == "Office")
        #expect(store.savedLayouts.last?.folders.first?.title == "Office")
    }

    @Test
    func escapeCancelsTheRenameBeforeClosingTheFolder() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)
        viewModel.beginRenamingFolder()
        viewModel.folderTitleDraft = "Office"

        #expect(viewModel.stepBack())
        #expect(viewModel.folderTitleDraft == nil)
        #expect(viewModel.expandedFolderID == folder.id)

        #expect(viewModel.stepBack())
        #expect(viewModel.expandedFolderID == nil)
        #expect(viewModel.pages == [[.folder(folder)]])
        #expect(store.savedLayouts.isEmpty)
    }

    enum FolderClose: CaseIterable {
        case clickOutside
        case hideLauncher
        case typeASearch
    }

    @Test(arguments: FolderClose.allCases)
    func closingTheFolderSavesTheEditedName(close: FolderClose) {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)
        viewModel.beginRenamingFolder()
        viewModel.folderTitleDraft = "Office"

        switch close {
        case .clickOutside: viewModel.closeFolder()
        case .hideLauncher: viewModel.endPresentation()
        case .typeASearch: viewModel.searchQuery = "m"
        }

        #expect(viewModel.expandedFolderID == nil)
        #expect(viewModel.folderTitleDraft == nil)
        #expect(viewModel.pages.first?.first?.title == "Office")
    }

    @Test
    func anEmptyNameKeepsTheOldOne() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let store = StubLayoutStore()
        let viewModel = Self.viewModel(pages: [], store: store)
        viewModel.pages = [[.folder(folder)]]
        viewModel.toggleFolder(folder.id)
        viewModel.beginRenamingFolder()
        viewModel.folderTitleDraft = "   "

        viewModel.commitFolderRename()

        #expect(viewModel.folderTitleDraft == nil)
        #expect(viewModel.expandedFolder?.title == "Work")
        #expect(store.savedLayouts.isEmpty)
    }

    @Test
    func everyShowGetsANewPresentationID() {
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        let beforeFirstShow = viewModel.presentationID

        viewModel.beginPresentation()
        let firstShow = viewModel.presentationID
        viewModel.endPresentation()
        viewModel.beginPresentation()

        #expect(firstShow != beforeFirstShow)
        #expect(viewModel.presentationID != firstShow)
    }

    @Test
    func endingAPresentationClearsSearchAndClosesTheFolderButKeepsThePage() {
        let folder = FolderItem(id: UUID(), title: "Work", apps: [Self.app("Mail"), Self.app("Calendar")])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.app(Self.app("Notes"))], [.folder(folder)]]
        viewModel.currentPage = 1
        viewModel.searchQuery = "mail"
        viewModel.toggleFolder(folder.id)

        viewModel.endPresentation()

        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.expandedFolderID == nil)
        #expect(viewModel.currentPage == 1)
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
        #expect(viewModel.searchResults?.map(\.id) == [code.id])
    }

    @Test
    func searchFindsAppsInsideFoldersOnceEach() {
        let terminal = Self.app("Terminal")
        let terminalCopy = AppItem(id: UUID(), bundleID: terminal.bundleID, title: "Terminal")
        let console = Self.app("Console")
        let utilities = FolderItem(id: UUID(), title: "Utilities", apps: [terminal, console])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(utilities)], [.app(terminalCopy)]]

        viewModel.searchQuery = "term"

        #expect(viewModel.searchResults == [.app(terminal)])
    }

    @Test
    func searchRanksExactThenPrefixThenWordPrefixThenSubstring() {
        let gmail = Self.app("Gmail")
        let sparkMail = Self.app("Spark Mail")
        let mailspring = Self.app("Mailspring")
        let mail = Self.app("Mail")
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.app(gmail), .app(sparkMail)], [.app(mailspring), .app(mail)]]

        viewModel.searchQuery = "mail"

        #expect(viewModel.searchResults?.map(\.id) == [mail.id, mailspring.id, sparkMail.id, gmail.id])
    }

    @Test
    func searchIgnoresCaseDiacriticsWidthAndSurroundingWhitespace() {
        let settings = Self.app("Réglages Système")
        let mail = Self.app("Mail")
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.app(settings), .app(mail)]]

        viewModel.searchQuery = "  REGLAGES "
        #expect(viewModel.searchResults?.map(\.id) == [settings.id])

        viewModel.searchQuery = "ｍａｉｌ"
        #expect(viewModel.searchResults?.map(\.id) == [mail.id])

        viewModel.searchQuery = "   "
        #expect(viewModel.searchResults == nil)
    }

    @Test
    func searchBreaksTiesByUsageThenName() {
        let notes = Self.app("Notes")
        let notepad = Self.app("Notepad")
        let notebook10 = Self.app("Notebook 10")
        let notebook9 = Self.app("Notebook 9")
        let usageStore = StubAppUsageStore(history: AppUsageHistory(records: [
            AppUsageRecord(bundleID: notes.bundleID, launchCount: 1, lastLaunchedAt: Date(timeIntervalSince1970: 100)),
            AppUsageRecord(bundleID: notepad.bundleID, launchCount: 3, lastLaunchedAt: Date(timeIntervalSince1970: 50))
        ]))
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: []),
            layoutStore: StubLayoutStore(),
            iconProvider: StubIconProvider(),
            appUsageStore: usageStore
        )
        viewModel.pages = [[.app(notebook10), .app(notes), .app(notebook9), .app(notepad)]]

        viewModel.searchQuery = "note"

        #expect(viewModel.searchResults?.map(\.id) == [notepad.id, notes.id, notebook9.id, notebook10.id])
    }

    @Test
    func searchListsMatchingFoldersAfterApps() {
        let terminal = Self.app("Terminal")
        let console = Self.app("Console")
        let utilities = FolderItem(id: UUID(), title: "Utilities", apps: [terminal, console])
        let utilityBelt = Self.app("Utility Belt")
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(utilities), .app(utilityBelt)]]

        viewModel.searchQuery = "util"

        #expect(viewModel.searchResults == [.app(utilityBelt), .folder(utilities)])
    }

    @Test
    func searchWithoutMatchesIsEmptyRatherThanNil() {
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.app(Self.app("Mail"))]]

        viewModel.searchQuery = "xyz"

        #expect(viewModel.searchResults == [])
    }

    @Test
    func typingASearchClosesTheOpenFolderButAFolderOpenedFromResultsStays() {
        let folder = FolderItem(id: UUID(), title: "Utilities", apps: [Self.app("Terminal"), Self.app("Console")])
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())
        viewModel.pages = [[.folder(folder), .app(Self.app("Mail"))]]

        viewModel.toggleFolder(folder.id)
        viewModel.searchQuery = "ma"
        #expect(viewModel.expandedFolderID == nil)

        viewModel.searchQuery = "util"
        viewModel.toggleFolder(folder.id)
        viewModel.searchQuery = "util"
        #expect(viewModel.expandedFolderID == folder.id)

        viewModel.searchQuery = ""
        #expect(viewModel.expandedFolderID == folder.id)
    }

    @Test
    func iconCacheMissDoesNotInvalidateViewsShowingOtherIcons() {
        let viewModel = Self.viewModel(pages: [], store: StubLayoutStore())

        #expect(!observationFires(
            when: { _ = viewModel.icon(for: "com.example.Notes") },
            reading: { _ = viewModel.icon(for: "com.example.Mail") }
        ))
    }

    @Test
    func loadReloadsTheIconsOfChangedOrRemovedAppsOnly() async {
        var mail = Self.app("Mail")
        let notes = Self.app("Notes")
        let dataSource = StubDataSource(pages: [[.app(mail), .app(notes)]])
        let icons = CountingIconProvider()
        let viewModel = LaunchpadViewModel(
            dataSource: dataSource,
            layoutStore: StubLayoutStore(),
            iconProvider: icons,
            appUsageStore: StubAppUsageStore()
        )
        func showIcons() {
            _ = viewModel.icon(for: mail.bundleID)
            _ = viewModel.icon(for: notes.bundleID)
        }

        await viewModel.load()
        showIcons()
        await viewModel.load()
        showIcons()
        #expect(icons.requests == [mail.bundleID, notes.bundleID])

        mail.bundleVersion = "2"
        dataSource.pages = [[.app(mail), .app(notes)]]
        await viewModel.load()
        showIcons()
        #expect(icons.requests == [mail.bundleID, notes.bundleID, mail.bundleID])

        dataSource.pages = [[.app(mail)]]
        await viewModel.load()
        _ = viewModel.icon(for: notes.bundleID)
        #expect(icons.requests.last == notes.bundleID)
        #expect(icons.requests.count == 4)
    }

    @Test
    func iconsComeFromTheCopyTheTileOpens() async {
        var mail = Self.app("Mail")
        mail.bundleURL = URL(fileURLWithPath: "/Applications/Mail.app", isDirectory: true)
        let icons = CountingIconProvider()
        let viewModel = LaunchpadViewModel(
            dataSource: StubDataSource(pages: [[.app(mail)]]),
            layoutStore: StubLayoutStore(),
            iconProvider: icons,
            appUsageStore: StubAppUsageStore()
        )

        await viewModel.load()
        _ = viewModel.icon(for: mail.bundleID)

        #expect(icons.requestedURLs == [mail.bundleURL])
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

    private static func viewModel(
        source: StubDataSource,
        store: StubLayoutStore,
        pageCapacity: Int
    ) -> LaunchpadViewModel {
        LaunchpadViewModel(
            dataSource: source,
            layoutStore: store,
            iconProvider: StubIconProvider(),
            appUsageStore: StubAppUsageStore(),
            pageCapacity: pageCapacity
        )
    }

    private static func app(_ title: String) -> AppItem {
        AppItem(id: UUID(), bundleID: "com.example.\(title)", title: title)
    }
}

private final class StubDataSource: AppDataSource {
    var pages: [[LaunchpadItem]]
    private(set) var requestedCapacities: [Int] = []

    /// Set by `init(chunking:)`.
    private var itemsToChunk: [LaunchpadItem]?

    init(pages: [[LaunchpadItem]]) {
        self.pages = pages
    }

    /// Pages of `items` at the capacity asked for, as the folder scan makes them.
    init(chunking items: [LaunchpadItem]) {
        pages = []
        itemsToChunk = items
    }

    func loadPages(pageCapacity: Int) throws -> [[LaunchpadItem]] {
        requestedCapacities.append(pageCapacity)
        guard let itemsToChunk else { return pages }
        return stride(from: 0, to: itemsToChunk.count, by: pageCapacity).map {
            Array(itemsToChunk[$0..<min($0 + pageCapacity, itemsToChunk.count)])
        }
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
    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage {
        NSImage(size: NSSize(width: 1, height: 1))
    }
}

private final class CountingIconProvider: AppIconProviding {
    var requests: [String] = []
    var requestedURLs: [URL?] = []

    func icon(for bundleID: String, at bundleURL: URL?) -> NSImage {
        requests.append(bundleID)
        requestedURLs.append(bundleURL)
        return NSImage(size: NSSize(width: 1, height: 1))
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
    let otherCopies: [URL]

    init(uninstallError: Error? = nil, missingBundleIDs: Set<String> = [], otherCopies: [URL] = []) {
        self.uninstallError = uninstallError
        self.missingBundleIDs = missingBundleIDs
        self.otherCopies = otherCopies
    }

    func uninstallURL(for app: AppItem) -> URL? { app.bundleURL }
    func otherCopyURLs(of app: AppItem) -> [URL] { otherCopies }

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
