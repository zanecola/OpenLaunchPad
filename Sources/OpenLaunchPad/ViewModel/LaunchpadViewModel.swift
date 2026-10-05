import Foundation
import AppKit
import Observation

/// Central state for the Launchpad UI.
/// @MainActor because all mutations drive SwiftUI view updates. (ADR-4)
@MainActor
@Observable
final class LaunchpadViewModel {

    // MARK: - Published state

    var pages: [[LaunchpadItem]] = []
    /// Typing closes an open folder: the results replace the grid behind it, and Return would
    /// otherwise launch one of them rather than anything in the folder.
    var searchQuery: String = "" {
        didSet {
            if searchQuery != oldValue && !searchQuery.isEmpty { closeFolder() }
        }
    }
    var expandedFolderID: UUID? = nil
    var isEditMode: Bool = false
    var currentPage: Int = 0
    var isLoading: Bool = false
    var loadError: String? = nil
    /// How many items a page holds: the full-screen grid's columns × rows. A change reloads, so
    /// the source is chunked again and a saved layout's overflow moves onto later pages.
    var pageCapacity: Int {
        didSet {
            if pageCapacity != oldValue { reload() }
        }
    }
    private var appUsageHistory: AppUsageHistory

    // MARK: - Derived state

    /// Results for the trimmed query; nil means show the paginated grid.
    /// Matching apps come first, including apps inside folders, ranked by how well they match,
    /// then by usage, then by name. Folders whose own title matches follow them.
    var searchResults: [LaunchpadItem]? {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        var apps: [(app: AppItem, match: SearchMatch)] = []
        var folders: [(folder: FolderItem, match: SearchMatch)] = []
        var seenBundleIDs = Set<String>()
        func consider(_ app: AppItem) {
            guard let match = ([app.title] + app.aliases).compactMap({ SearchMatch($0, query: query) }).min(),
                  seenBundleIDs.insert(app.bundleID).inserted else { return }
            apps.append((app, match))
        }
        for item in pages.joined() {
            switch item {
            case .app(let app):
                consider(app)
            case .folder(let folder):
                folder.apps.forEach(consider)
                if let match = SearchMatch(folder.title, query: query) {
                    folders.append((folder, match))
                }
            }
        }

        let usageRanks = Dictionary(uniqueKeysWithValues: appUsageHistory
            .rankedBundleIDs(limit: appUsageHistory.records.count)
            .enumerated()
            .map { ($0.element, $0.offset) })
        apps.sort { lhs, rhs in
            if lhs.match != rhs.match { return lhs.match < rhs.match }
            let lhsUsage = usageRanks[lhs.app.bundleID] ?? .max
            let rhsUsage = usageRanks[rhs.app.bundleID] ?? .max
            if lhsUsage != rhsUsage { return lhsUsage < rhsUsage }
            return lhs.app.title.localizedStandardCompare(rhs.app.title) == .orderedAscending
        }
        folders.sort { lhs, rhs in
            if lhs.match != rhs.match { return lhs.match < rhs.match }
            return lhs.folder.title.localizedStandardCompare(rhs.folder.title) == .orderedAscending
        }
        return apps.map { .app($0.app) } + folders.map { .folder($0.folder) }
    }

    var expandedFolder: FolderItem? {
        guard let expandedFolderID else { return nil }
        return pages.lazy
            .flatMap { $0 }
            .compactMap { item -> FolderItem? in
                guard case .folder(let folder) = item, folder.id == expandedFolderID else { return nil }
                return folder
            }
            .first
    }

    var hasAppUsageHistory: Bool {
        !appUsageHistory.records.isEmpty
    }

    func frequentlyUsedApps(limit: Int) -> [AppItem] {
        guard limit > 0 else { return [] }

        let apps = appsByBundleID
        return appUsageHistory
            .rankedBundleIDs(limit: appUsageHistory.records.count)
            .compactMap { apps[$0] }
            .prefix(limit)
            .map { $0 }
    }

    /// Every app, top level and in folders; the first tile wins for a duplicated bundle ID.
    private var appsByBundleID: [String: AppItem] {
        var appsByBundleID: [String: AppItem] = [:]
        for item in pages.flatMap({ $0 }) {
            switch item {
            case .app(let app):
                if appsByBundleID[app.bundleID] == nil {
                    appsByBundleID[app.bundleID] = app
                }
            case .folder(let folder):
                for app in folder.apps where appsByBundleID[app.bundleID] == nil {
                    appsByBundleID[app.bundleID] = app
                }
            }
        }
        return appsByBundleID
    }

    // MARK: - Dependencies (injected, enabling testability)

    private let dataSource: any AppDataSource
    private let layoutStore: any LayoutStoring
    private let iconProvider: any AppIconProviding
    private let applicationManager: any ApplicationManaging
    private let appUsageStore: any AppUsageStoring
    private let makeUUID: () -> UUID
    private let now: () -> Date

    // MARK: - Icon cache (bundleID → NSImage)

    /// Filled from view bodies, so it isn't observed: a miss would otherwise re-render every
    /// view that shows an icon.
    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    /// The copy each loaded app opens, so its icon comes from the same bundle.
    @ObservationIgnored private var bundleURLs: [String: URL] = [:]

    // MARK: - Init

    init(
        dataSource: any AppDataSource,
        layoutStore: any LayoutStoring,
        iconProvider: any AppIconProviding,
        applicationManager: (any ApplicationManaging)? = nil,
        appUsageStore: any AppUsageStoring,
        pageCapacity: Int = 35,  // the default 7 × 5 grid
        makeUUID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.dataSource = dataSource
        self.layoutStore = layoutStore
        self.iconProvider = iconProvider
        self.applicationManager = applicationManager ?? SystemApplicationManager()
        self.appUsageStore = appUsageStore
        self.pageCapacity = pageCapacity
        appUsageHistory = appUsageStore.loadHistory()
        self.makeUUID = makeUUID
        self.now = now
    }

    // MARK: - Loading

    func load() async {
        reload()
    }

    private func reload() {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let sourcedPages = try dataSource.loadPages(pageCapacity: pageCapacity)
            let previousApps = appsByBundleID
            let mergedPages = applyCustomLayout(to: sourcedPages)
            pages = LaunchpadLayout.reflow(mergedPages, capacity: pageCapacity)
            // Saved, so apps moved onto later pages stay there if pages get more slots.
            if pages != mergedPages {
                persistLayout()
            }
            // A moved or updated bundle changes its AppItem, which re-renders its tiles;
            // drop its icon so they load the new one.
            let loadedApps = appsByBundleID
            iconCache = iconCache.filter { bundleID, _ in
                loadedApps[bundleID] != nil && loadedApps[bundleID] == previousApps[bundleID]
            }
            bundleURLs = loadedApps.compactMapValues(\.bundleURL)
            if expandedFolderID != nil, expandedFolder == nil {
                closeFolder()
            }
            clampCurrentPage()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Merges the data source's default ordering with any saved custom layout.
    /// Items absent from the custom layout are appended to the last page; reload then moves what
    /// overflows it onto new pages.
    private func applyCustomLayout(to sourcedPages: [[LaunchpadItem]]) -> [[LaunchpadItem]] {
        guard let storedLayout = layoutStore.loadCustomLayout() else {
            return sourcedPages
        }

        let sourceItems = sourcedPages.flatMap { $0 }
        var sourceItemsByID: [UUID: LaunchpadItem] = [:]
        var sourceFoldersByID: [UUID: FolderItem] = [:]
        var appsByID: [UUID: AppItem] = [:]

        for item in sourceItems {
            if sourceItemsByID[item.id] == nil {
                sourceItemsByID[item.id] = item
            }
            switch item {
            case .app(let app):
                if appsByID[app.id] == nil { appsByID[app.id] = app }
            case .folder(let folder):
                if sourceFoldersByID[folder.id] == nil { sourceFoldersByID[folder.id] = folder }
                for app in folder.apps where appsByID[app.id] == nil {
                    appsByID[app.id] = app
                }
            }
        }

        let storedFoldersByID = Dictionary(
            storedLayout.folders.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // Apps the stored layout places itself; source folders must not pull them back in.
        let topLevelIDs = Set(storedLayout.pageIDs.joined())
        var storedAppIDs = topLevelIDs
        for folder in storedLayout.folders where topLevelIDs.contains(folder.id) {
            storedAppIDs.formUnion(folder.appIDs)
        }
        var placedItemIDs = Set<UUID>()
        var placedAppIDs = Set<UUID>()

        func normalized(_ folder: FolderItem) -> LaunchpadItem? {
            switch folder.apps.count {
            case 0: return nil
            case 1: return .app(folder.apps[0])
            default: return .folder(folder)
            }
        }

        func sourceItem(for id: UUID) -> LaunchpadItem? {
            guard let item = sourceItemsByID[id] else {
                // A stored top-level app may live inside a folder in the source.
                guard let app = appsByID[id], !placedAppIDs.contains(id) else { return nil }
                return .app(app)
            }
            switch item {
            case .app(let app):
                return placedAppIDs.contains(app.id) ? nil : item
            case .folder(var folder):
                folder.apps.removeAll { placedAppIDs.contains($0.id) }
                return normalized(folder)
            }
        }

        func storedFolderItem(for id: UUID) -> LaunchpadItem? {
            guard let storedFolder = storedFoldersByID[id] else { return nil }

            let requestedIDs: [UUID]
            if storedFolder.appIDs.isEmpty, let sourceFolder = sourceFoldersByID[id] {
                requestedIDs = sourceFolder.apps.map(\.id)
            } else {
                requestedIDs = storedFolder.appIDs
            }

            var seenAppIDs = Set<UUID>()
            var folderApps: [AppItem] = []
            for appID in requestedIDs where !placedAppIDs.contains(appID) && seenAppIDs.insert(appID).inserted {
                guard let app = appsByID[appID] else { continue }
                folderApps.append(app)
            }

            if !storedFolder.appIDs.isEmpty, let sourceFolder = sourceFoldersByID[id] {
                for app in sourceFolder.apps
                where !storedAppIDs.contains(app.id) && !placedAppIDs.contains(app.id) && seenAppIDs.insert(app.id).inserted {
                    folderApps.append(app)
                }
            }

            // A title saved as the raw directory name was never a rename, so show the localized one.
            let sourceFolder = sourceFoldersByID[id]
            let title = sourceFolder.flatMap { $0.directoryName == storedFolder.title ? $0.title : nil }
            return normalized(FolderItem(
                id: storedFolder.id,
                title: title ?? storedFolder.title,
                apps: folderApps
            ))
        }

        func recordPlacement(of item: LaunchpadItem) {
            placedItemIDs.insert(item.id)
            switch item {
            case .app(let app):
                placedAppIDs.insert(app.id)
            case .folder(let folder):
                placedAppIDs.formUnion(folder.apps.map(\.id))
            }
        }

        func resolve(_ id: UUID) -> LaunchpadItem? {
            let item: LaunchpadItem?
            if let storedFolder = storedFolderItem(for: id) {
                item = storedFolder
            } else {
                item = sourceItem(for: id)
            }
            guard let item,
                  !placedItemIDs.contains(item.id) else { return nil }

            switch item {
            case .app(let app):
                guard !placedAppIDs.contains(app.id) else { return nil }
            case .folder(var folder):
                folder.apps.removeAll { placedAppIDs.contains($0.id) }
                guard let deduplicated = normalized(folder),
                      !placedItemIDs.contains(deduplicated.id) else { return nil }
                recordPlacement(of: deduplicated)
                return deduplicated
            }

            recordPlacement(of: item)
            return item
        }

        var result: [[LaunchpadItem]] = storedLayout.pageIDs.map { ids in
            ids.compactMap(resolve)
        }

        let unplaced: [LaunchpadItem] = sourceItems.compactMap { item -> LaunchpadItem? in
            guard !placedItemIDs.contains(item.id) else { return nil }
            return resolve(item.id)
        }
        if !unplaced.isEmpty {
            if result.isEmpty { result.append([]) }
            result[result.count - 1].append(contentsOf: unplaced)
        }

        return result.filter { !$0.isEmpty }
    }

    // MARK: - Icon access

    func icon(for bundleID: String) -> NSImage {
        if let cached = iconCache[bundleID] { return cached }
        let image = iconProvider.icon(for: bundleID, at: bundleURLs[bundleID])
        iconCache[bundleID] = image
        return image
    }

    // MARK: - Launch

    /// Opens the app and counts the launch. Returns false, counting nothing, when its bundle can't be found.
    @discardableResult
    func launch(_ app: AppItem) -> Bool {
        do {
            try applicationManager.launch(app)
        } catch {
            return false
        }
        recordLaunch(of: app)
        return true
    }

    func recordLaunch(of app: AppItem) {
        appUsageHistory.recordLaunch(bundleID: app.bundleID, at: now())
        appUsageStore.saveHistory(appUsageHistory)
    }

    func clearAppUsageHistory() {
        appUsageHistory.removeAll()
        appUsageStore.saveHistory(appUsageHistory)
    }

    func uninstallURL(for app: AppItem) -> URL? {
        applicationManager.uninstallURL(for: app)
    }

    func otherCopyURLs(of app: AppItem) -> [URL] {
        applicationManager.otherCopyURLs(of: app)
    }

    func revealInFinder(_ app: AppItem) throws {
        try applicationManager.revealInFinder(app)
    }

    func showInfo(_ app: AppItem) throws {
        try applicationManager.showInfo(app)
    }

    /// While another copy stays installed the app keeps its tile, place and usage: the reload
    /// points the tile at a copy the scan still finds, or leaves it out of the grid until one is.
    func uninstall(_ app: AppItem) throws {
        let keepsTile = !applicationManager.otherCopyURLs(of: app).isEmpty
        try applicationManager.uninstall(app)
        if keepsTile {
            reload()
        } else {
            removeFromLayout(app)
        }
    }

    /// Removes every tile and the usage record of an app; its bundle is left alone.
    func removeFromLayout(_ app: AppItem) {
        appUsageHistory.remove(bundleID: app.bundleID)
        appUsageStore.saveHistory(appUsageHistory)

        let oldPages = pages
        pages = pages.compactMap { page in
            let updatedPage = page.compactMap { item -> LaunchpadItem? in
                switch item {
                case .app(let existingApp):
                    return existingApp.bundleID == app.bundleID ? nil : item
                case .folder(var folder):
                    folder.apps.removeAll { $0.bundleID == app.bundleID }
                    switch folder.apps.count {
                    case 0: return nil
                    case 1: return .app(folder.apps[0])
                    default: return .folder(folder)
                    }
                }
            }
            return updatedPage.isEmpty ? nil : updatedPage
        }

        iconCache.removeValue(forKey: app.bundleID)
        if pages != oldPages {
            if expandedFolderID != nil, expandedFolder == nil {
                closeFolder()
            }
            persistLayout()
            clampCurrentPage()
        }
    }

    // MARK: - Folder expand/collapse

    func toggleFolder(_ id: UUID) {
        expandedFolderID = expandedFolderID == id ? nil : id
    }

    func closeFolder() {
        expandedFolderID = nil
    }

    func renameFolder(_ id: UUID, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let (pageIndex, itemIndex) = location(of: id),
              case .folder(var folder) = pages[pageIndex][itemIndex],
              folder.title != name else {
            return
        }
        folder.title = name
        pages[pageIndex][itemIndex] = .folder(folder)
        persistLayout()
    }

    // MARK: - Escape

    /// Steps back one level: closes the open folder, then clears the search, then leaves edit mode.
    /// Returns false when there is nothing left to step back from, so the launcher should close.
    func stepBack() -> Bool {
        if expandedFolderID != nil {
            closeFolder()
        } else if !searchQuery.isEmpty {
            searchQuery = ""
        } else if isEditMode {
            toggleEditMode()
        } else {
            return false
        }
        return true
    }

    // MARK: - Presentation

    /// Bumped on every show. Both launcher surfaces stay alive between shows, so views refocus
    /// search, drop a hover left from the last show and scroll back to the top when it changes.
    private(set) var presentationID = 0

    func beginPresentation() {
        presentationID += 1
    }

    /// The launcher is hiding: it opens next time with no query and no open folder.
    func endPresentation() {
        searchQuery = ""
        closeFolder()
    }

    // MARK: - Edit mode

    func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode { closeFolder() }
    }

    // MARK: - Rearranging

    @discardableResult
    func reorderTopLevel(
        itemID: UUID,
        relativeTo targetID: UUID,
        placement: ItemPlacement
    ) -> Bool {
        mutateLayout {
            $0.reorderTopLevel(itemID: itemID, relativeTo: targetID, placement: placement)
        }
    }

    @discardableResult
    func combineApps(draggedID: UUID, targetID: UUID) -> Bool {
        let folderID = makeUUID()
        return mutateLayout {
            $0.combineApps(
                draggedAppID: draggedID,
                targetAppID: targetID,
                folderID: folderID
            )
        }
    }

    @discardableResult
    func addApp(_ appID: UUID, toFolder folderID: UUID) -> Bool {
        mutateLayout { $0.addApp(appID, toFolder: folderID) }
    }

    @discardableResult
    func reorderApp(
        _ appID: UUID,
        inFolder folderID: UUID,
        relativeTo targetAppID: UUID,
        placement: ItemPlacement
    ) -> Bool {
        mutateLayout {
            $0.reorderApp(
                appID,
                inFolder: folderID,
                relativeTo: targetAppID,
                placement: placement
            )
        }
    }

    @discardableResult
    func removeApp(_ appID: UUID, fromFolder folderID: UUID) -> Bool {
        mutateLayout { $0.removeApp(appID, fromFolder: folderID) }
    }

    private func mutateLayout(_ mutation: (inout LaunchpadLayout) -> Bool) -> Bool {
        var layout = LaunchpadLayout(pages: pages)
        guard mutation(&layout) else { return false }

        // An app dropped onto a full page, or dragged out of a folder on one, pushes the page's
        // last item onto the next page.
        pages = LaunchpadLayout.reflow(layout.pages, capacity: pageCapacity)
        if expandedFolderID != nil, expandedFolder == nil {
            closeFolder()
        }
        persistLayout()
        clampCurrentPage()
        return true
    }

    /// Moves an item from its current position to `targetPageIndex` at `targetIndex`.
    func move(itemID: UUID, toPage targetPageIndex: Int, at targetIndex: Int) {
        guard pages.indices.contains(targetPageIndex),
              let (srcPage, srcIndex) = location(of: itemID) else { return }

        var item: LaunchpadItem
        // Remove from source
        if srcPage == targetPageIndex {
            item = pages[srcPage].remove(at: srcIndex)
            let adjustedTarget = targetIndex > srcIndex ? targetIndex - 1 : targetIndex
            pages[srcPage].insert(item, at: min(adjustedTarget, pages[srcPage].count))
        } else {
            item = pages[srcPage].remove(at: srcIndex)
            pages[targetPageIndex].insert(item, at: min(targetIndex, pages[targetPageIndex].count))
            if pages[srcPage].isEmpty { pages.remove(at: srcPage) }
        }

        persistLayout()
        clampCurrentPage()
    }

    private func clampCurrentPage() {
        currentPage = min(currentPage, max(pages.count - 1, 0))
    }

    func showNextPage() {
        currentPage = min(currentPage + 1, max(pages.count - 1, 0))
    }

    func showPreviousPage() {
        currentPage = max(currentPage - 1, 0)
    }

    func sortByName(_ order: LaunchpadSortOrder) {
        let pageSizes = pages.map(\.count)
        var sortedItems = pages.flatMap { $0 }.map { item -> LaunchpadItem in
            guard case .folder(var folder) = item else { return item }
            folder.apps.sort { compareTitles($0.title, $1.title, order: order) }
            return .folder(folder)
        }
        sortedItems.sort { compareTitles($0.title, $1.title, order: order) }

        var nextItemIndex = 0
        pages = pageSizes.compactMap { pageSize in
            let endIndex = min(nextItemIndex + pageSize, sortedItems.count)
            guard nextItemIndex < endIndex else { return nil }
            defer { nextItemIndex = endIndex }
            return Array(sortedItems[nextItemIndex..<endIndex])
        }
        persistLayout()
        clampCurrentPage()
    }

    private func location(of itemID: UUID) -> (page: Int, index: Int)? {
        for (p, page) in pages.enumerated() {
            if let i = page.firstIndex(where: { $0.id == itemID }) {
                return (p, i)
            }
        }
        return nil
    }

    private func compareTitles(
        _ lhs: String,
        _ rhs: String,
        order: LaunchpadSortOrder
    ) -> Bool {
        let comparison = lhs.localizedStandardCompare(rhs)
        if comparison == .orderedSame {
            return order == .ascending ? lhs < rhs : lhs > rhs
        }
        return order == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    // MARK: - Layout persistence

    private func persistLayout() {
        let folders = pages
            .flatMap { $0 }
            .compactMap { item -> StoredFolder? in
                guard case .folder(let folder) = item else { return nil }
                return StoredFolder(
                    id: folder.id,
                    title: folder.title,
                    appIDs: folder.apps.map(\.id)
                )
            }
        layoutStore.saveCustomLayout(StoredLayout(
            pageIDs: pages.map { $0.map { $0.id } },
            folders: folders
        ))
    }

    func resetToDefault() async {
        layoutStore.clearCustomLayout()
        await load()
    }
}
