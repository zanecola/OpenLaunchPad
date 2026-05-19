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

    // MARK: - Icon cache (bundleID → NSImage)

    private var iconCache: [String: NSImage] = [:]

    // MARK: - Init

    init(
        dataSource: any AppDataSource,
        layoutStore: any LayoutStoring,
        iconProvider: any AppIconProviding
    ) {
        self.dataSource = dataSource
        self.layoutStore = layoutStore
        self.iconProvider = iconProvider
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let sourcedPages = try dataSource.loadPages()
            pages = applyCustomLayout(to: sourcedPages)
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

        let allItems = Dictionary(
            uniqueKeysWithValues: sourcedPages.flatMap { $0 }.map { item in
                guard case .folder(var folder) = item,
                      let storedName = storedLayout.folderNames[folder.id] else {
                    return (item.id, item)
                }
                folder.title = storedName
                return (item.id, .folder(folder))
            }
        )
        var placed = Set<UUID>()

        var result: [[LaunchpadItem]] = storedLayout.pageIDs.map { ids in
            ids.compactMap { id -> LaunchpadItem? in
                guard let item = allItems[id] else { return nil }
                placed.insert(id)
                return item
            }
        }

        // Append any new items (added to the system since last save) to the last page
        let unplaced = sourcedPages.flatMap { $0 }.filter { !placed.contains($0.id) }
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

    /// Moves an item from its current position to `targetPageIndex` at `targetIndex`.
    func move(itemID: UUID, toPage targetPageIndex: Int, at targetIndex: Int) {
        guard let (srcPage, srcIndex) = location(of: itemID) else { return }

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

    private func location(of itemID: UUID) -> (page: Int, index: Int)? {
        for (p, page) in pages.enumerated() {
            if let i = page.firstIndex(where: { $0.id == itemID }) {
                return (p, i)
            }
        }
        return nil
    }

    // MARK: - Layout persistence

    private func persistLayout() {
        let folderNames = Dictionary(uniqueKeysWithValues: pages
            .flatMap { $0 }
            .compactMap { item -> (UUID, String)? in
                guard case .folder(let folder) = item else { return nil }
                return (folder.id, folder.title)
            })
        layoutStore.saveCustomLayout(StoredLayout(
            pageIDs: pages.map { $0.map { $0.id } },
            folderNames: folderNames
        ))
    }

    func resetToDefault() async {
        layoutStore.clearCustomLayout()
        await load()
    }
}
