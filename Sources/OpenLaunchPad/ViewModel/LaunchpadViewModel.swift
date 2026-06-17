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
    var searchQuery: String = ""
    var expandedFolderID: UUID? = nil
    var isEditMode: Bool = false
    var currentPage: Int = 0
    var isLoading: Bool = false
    var loadError: String? = nil

    // MARK: - Derived state

    /// Flat search results when query is active; nil means show paginated grid.
    var searchResults: [LaunchpadItem]? {
        guard !searchQuery.isEmpty else { return nil }
        let q = searchQuery.lowercased()
        return pages.flatMap { $0 }.filter { item in
            switch item {
            case .app(let a): return a.title.lowercased().contains(q)
            case .folder(let f):
                return f.title.lowercased().contains(q)
                    || f.apps.contains { $0.title.lowercased().contains(q) }
            }
        }
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

    // MARK: - Dependencies (injected, enabling testability)

    private let dataSource: any AppDataSource
    private let layoutStore: any LayoutStoring
    private let iconProvider: any AppIconProviding
    private let applicationManager: any ApplicationManaging
    private let makeUUID: () -> UUID

    // MARK: - Icon cache (bundleID → NSImage)

    private var iconCache: [String: NSImage] = [:]

    // MARK: - Init

    init(
        dataSource: any AppDataSource,
        layoutStore: any LayoutStoring,
        iconProvider: any AppIconProviding,
        applicationManager: (any ApplicationManaging)? = nil,
        makeUUID: @escaping () -> UUID = UUID.init
    ) {
        self.dataSource = dataSource
        self.layoutStore = layoutStore
        self.iconProvider = iconProvider
        self.applicationManager = applicationManager ?? SystemApplicationManager()
        self.makeUUID = makeUUID
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let sourcedPages = try dataSource.loadPages()
            pages = applyCustomLayout(to: sourcedPages)
            if expandedFolderID != nil, expandedFolder == nil {
                closeFolder()
            }
            clampCurrentPage()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Merges the data source's default ordering with any saved custom layout.
    /// Items absent from the custom layout are appended to the last page.
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
            guard let item = sourceItemsByID[id] else { return nil }
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
                for app in sourceFolder.apps where !placedAppIDs.contains(app.id) && seenAppIDs.insert(app.id).inserted {
                    folderApps.append(app)
                }
            }

            return normalized(FolderItem(
                id: storedFolder.id,
                title: storedFolder.title,
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
        let image = iconProvider.icon(for: bundleID)
        iconCache[bundleID] = image
        return image
    }

    // MARK: - Launch

    func launch(_ app: AppItem) {
        NSWorkspace.shared.openApplication(
            at: NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) ?? URL(fileURLWithPath: "/"),
            configuration: .init()
        )
    }

    func canUninstall(_ app: AppItem) -> Bool {
        applicationManager.canUninstall(app)
    }

    func revealInFinder(_ app: AppItem) throws {
        try applicationManager.revealInFinder(app)
    }

    func showInfo(_ app: AppItem) throws {
        try applicationManager.showInfo(app)
    }

    func uninstall(_ app: AppItem) throws {
        try applicationManager.uninstall(app)

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
              case .folder(var folder) = pages[pageIndex][itemIndex] else {
            return
        }
        folder.title = name
        pages[pageIndex][itemIndex] = .folder(folder)
        persistLayout()
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

        pages = layout.pages
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
