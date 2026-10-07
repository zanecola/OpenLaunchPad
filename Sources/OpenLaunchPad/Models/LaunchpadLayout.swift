import Foundation

struct LaunchpadLayout: Equatable, Sendable {
    private(set) var pages: [[LaunchpadItem]]

    init(pages: [[LaunchpadItem]]) {
        self.pages = pages
    }

    mutating func reorderTopLevel(
        itemID: UUID,
        relativeTo targetID: UUID,
        placement: ItemPlacement
    ) -> Bool {
        guard itemID != targetID,
              let source = Self.topLevelLocation(of: itemID, in: pages),
              Self.topLevelLocation(of: targetID, in: pages) != nil else {
            return false
        }

        var updatedPages = pages
        let item = Self.removeTopLevel(at: source, from: &updatedPages)

        guard let target = Self.topLevelLocation(of: targetID, in: updatedPages) else {
            return false
        }
        let insertionIndex = target.item + (placement == .after ? 1 : 0)
        updatedPages[target.page].insert(item, at: insertionIndex)

        return apply(updatedPages)
    }

    mutating func combineApps(
        draggedAppID: UUID,
        targetAppID: UUID,
        folderID: UUID,
        title: String = "Folder"
    ) -> Bool {
        guard draggedAppID != targetAppID,
              !Self.contains(id: folderID, in: pages),
              let draggedLocation = Self.topLevelAppLocation(of: draggedAppID, in: pages),
              let targetLocation = Self.topLevelAppLocation(of: targetAppID, in: pages),
              case .app(let draggedApp) = pages[draggedLocation.page][draggedLocation.item],
              case .app(let targetApp) = pages[targetLocation.page][targetLocation.item] else {
            return false
        }

        var updatedPages = pages
        Self.removeTopLevel(at: draggedLocation, from: &updatedPages)

        guard let updatedTarget = Self.topLevelAppLocation(of: targetAppID, in: updatedPages) else {
            return false
        }
        updatedPages[updatedTarget.page][updatedTarget.item] = .folder(FolderItem(
            id: folderID,
            title: title,
            apps: [targetApp, draggedApp]
        ))

        return apply(updatedPages)
    }

    mutating func addApp(_ appID: UUID, toFolder folderID: UUID) -> Bool {
        guard let appLocation = Self.topLevelAppLocation(of: appID, in: pages),
              Self.folderLocation(of: folderID, in: pages) != nil,
              case .app(let app) = pages[appLocation.page][appLocation.item] else {
            return false
        }

        var updatedPages = pages
        Self.removeTopLevel(at: appLocation, from: &updatedPages)

        guard let updatedFolderLocation = Self.folderLocation(of: folderID, in: updatedPages),
              case .folder(var folder) = updatedPages[updatedFolderLocation.page][updatedFolderLocation.item] else {
            return false
        }
        folder.apps.append(app)
        updatedPages[updatedFolderLocation.page][updatedFolderLocation.item] = .folder(folder)

        return apply(updatedPages)
    }

    mutating func reorderApp(
        _ appID: UUID,
        inFolder folderID: UUID,
        relativeTo targetAppID: UUID,
        placement: ItemPlacement
    ) -> Bool {
        guard appID != targetAppID,
              let folderLocation = Self.folderLocation(of: folderID, in: pages),
              case .folder(var folder) = pages[folderLocation.page][folderLocation.item],
              let sourceIndex = folder.apps.firstIndex(where: { $0.id == appID }),
              folder.apps.contains(where: { $0.id == targetAppID }) else {
            return false
        }

        let app = folder.apps.remove(at: sourceIndex)
        guard let targetIndex = folder.apps.firstIndex(where: { $0.id == targetAppID }) else {
            return false
        }
        let insertionIndex = targetIndex + (placement == .after ? 1 : 0)
        folder.apps.insert(app, at: insertionIndex)

        var updatedPages = pages
        updatedPages[folderLocation.page][folderLocation.item] = .folder(folder)
        return apply(updatedPages)
    }

    mutating func removeApp(_ appID: UUID, fromFolder folderID: UUID) -> Bool {
        guard let folderLocation = Self.folderLocation(of: folderID, in: pages),
              case .folder(var folder) = pages[folderLocation.page][folderLocation.item],
              folder.apps.count >= 2,
              let appIndex = folder.apps.firstIndex(where: { $0.id == appID }) else {
            return false
        }

        let removedApp = folder.apps.remove(at: appIndex)
        var updatedPages = pages

        if folder.apps.count == 1 {
            updatedPages[folderLocation.page][folderLocation.item] = .app(folder.apps[0])
        } else {
            updatedPages[folderLocation.page][folderLocation.item] = .folder(folder)
        }
        updatedPages[folderLocation.page].insert(
            .app(removedApp),
            at: folderLocation.item + 1
        )

        return apply(updatedPages)
    }

    /// Moves what overflows each page onto the start of the next, adding pages at the end as
    /// needed, so no page holds more than `capacity` items. Nothing moves back to fill free slots.
    static func reflow(_ pages: [[LaunchpadItem]], capacity: Int) -> [[LaunchpadItem]] {
        var reflowed: [[LaunchpadItem]] = []
        var overflow: [LaunchpadItem] = []
        for page in pages {
            let items = overflow + page
            reflowed.append(Array(items.prefix(capacity)))
            overflow = Array(items.dropFirst(capacity))
        }
        while !overflow.isEmpty {
            reflowed.append(Array(overflow.prefix(capacity)))
            overflow = Array(overflow.dropFirst(capacity))
        }
        return reflowed
    }

    private mutating func apply(_ updatedPages: [[LaunchpadItem]]) -> Bool {
        guard updatedPages != pages else { return false }
        pages = updatedPages
        return true
    }

    private static func topLevelLocation(
        of id: UUID,
        in pages: [[LaunchpadItem]]
    ) -> TopLevelLocation? {
        for (pageIndex, page) in pages.enumerated() {
            if let itemIndex = page.firstIndex(where: { $0.id == id }) {
                return TopLevelLocation(page: pageIndex, item: itemIndex)
            }
        }
        return nil
    }

    private static func topLevelAppLocation(
        of id: UUID,
        in pages: [[LaunchpadItem]]
    ) -> TopLevelLocation? {
        guard let location = topLevelLocation(of: id, in: pages),
              case .app = pages[location.page][location.item] else {
            return nil
        }
        return location
    }

    private static func folderLocation(
        of id: UUID,
        in pages: [[LaunchpadItem]]
    ) -> TopLevelLocation? {
        guard let location = topLevelLocation(of: id, in: pages),
              case .folder = pages[location.page][location.item] else {
            return nil
        }
        return location
    }

    private static func contains(id: UUID, in pages: [[LaunchpadItem]]) -> Bool {
        pageIndex(of: id, in: pages) != nil
    }

    /// The page holding `id`, at top level or in a folder.
    static func pageIndex(of id: UUID, in pages: [[LaunchpadItem]]) -> Int? {
        pages.firstIndex { page in
            page.contains { item in
                if item.id == id { return true }
                guard case .folder(let folder) = item else { return false }
                return folder.apps.contains(where: { $0.id == id })
            }
        }
    }

    @discardableResult
    private static func removeTopLevel(
        at location: TopLevelLocation,
        from pages: inout [[LaunchpadItem]]
    ) -> LaunchpadItem {
        let item = pages[location.page].remove(at: location.item)
        if pages[location.page].isEmpty {
            pages.remove(at: location.page)
        }
        return item
    }

    private struct TopLevelLocation {
        let page: Int
        let item: Int
    }
}
