import Foundation
import Testing
@testable import OpenLaunchPad

struct LaunchpadLayoutTests {
    private static let appA = app(1, "A")
    private static let appB = app(2, "B")
    private static let appC = app(3, "C")
    private static let appD = app(4, "D")
    private static let folderID = id(100)
    private static let otherFolderID = id(101)
    private static let missingID = id(999)

    @Test
    func reordersTopLevelBeforeTargetOnSamePage() {
        var layout = LaunchpadLayout(pages: [[.app(Self.appA), .app(Self.appB), .app(Self.appC)]])

        let changed = layout.reorderTopLevel(
            itemID: Self.appC.id,
            relativeTo: Self.appA.id,
            placement: .before
        )

        #expect(changed)
        #expect(layout.pages == [[.app(Self.appC), .app(Self.appA), .app(Self.appB)]])
    }

    @Test
    func reordersTopLevelAfterTargetOnSamePage() {
        var layout = LaunchpadLayout(pages: [[.app(Self.appA), .app(Self.appB), .app(Self.appC)]])

        let changed = layout.reorderTopLevel(
            itemID: Self.appA.id,
            relativeTo: Self.appC.id,
            placement: .after
        )

        #expect(changed)
        #expect(layout.pages == [[.app(Self.appB), .app(Self.appC), .app(Self.appA)]])
    }

    @Test
    func reordersTopLevelBeforeTargetAcrossPages() {
        var layout = LaunchpadLayout(pages: [
            [.app(Self.appA), .app(Self.appB)],
            [.app(Self.appC), .app(Self.appD)]
        ])

        let changed = layout.reorderTopLevel(
            itemID: Self.appA.id,
            relativeTo: Self.appD.id,
            placement: .before
        )

        #expect(changed)
        #expect(layout.pages == [
            [.app(Self.appB)],
            [.app(Self.appC), .app(Self.appA), .app(Self.appD)]
        ])
    }

    @Test
    func reordersTopLevelAfterTargetAcrossPagesAndRemovesOnlyEmptySourcePage() {
        var layout = LaunchpadLayout(pages: [
            [.app(Self.appC)],
            [],
            [.app(Self.appA), .app(Self.appB)]
        ])

        let changed = layout.reorderTopLevel(
            itemID: Self.appC.id,
            relativeTo: Self.appA.id,
            placement: .after
        )

        #expect(changed)
        #expect(layout.pages == [
            [],
            [.app(Self.appA), .app(Self.appC), .app(Self.appB)]
        ])
    }

    @Test
    func combinesTopLevelAppsAtTargetPosition() {
        var layout = LaunchpadLayout(pages: [[.app(Self.appA), .app(Self.appB), .app(Self.appC)]])

        let changed = layout.combineApps(
            draggedAppID: Self.appA.id,
            targetAppID: Self.appB.id,
            folderID: Self.folderID,
            title: "Work"
        )

        #expect(changed)
        #expect(layout.pages == [[
            .folder(Self.folder(Self.folderID, "Work", [Self.appB, Self.appA])),
            .app(Self.appC)
        ]])
    }

    @Test
    func combinesAppsAcrossPagesAndRemovesEmptySourcePage() {
        var layout = LaunchpadLayout(pages: [
            [.app(Self.appC)],
            [.app(Self.appA), .app(Self.appB)]
        ])

        let changed = layout.combineApps(
            draggedAppID: Self.appC.id,
            targetAppID: Self.appB.id,
            folderID: Self.folderID
        )

        #expect(changed)
        #expect(layout.pages == [[
            .app(Self.appA),
            .folder(Self.folder(Self.folderID, "Folder", [Self.appB, Self.appC]))
        ]])
    }

    @Test
    func movesTopLevelAppIntoExistingFolder() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appB])
        var layout = LaunchpadLayout(pages: [
            [.app(Self.appC)],
            [.app(Self.appA), .folder(folder)]
        ])

        let changed = layout.addApp(Self.appC.id, toFolder: Self.folderID)

        #expect(changed)
        #expect(layout.pages == [[
            .app(Self.appA),
            .folder(Self.folder(Self.folderID, "Folder", [Self.appB, Self.appC]))
        ]])
    }

    @Test
    func reordersAppBeforeTargetWithinFolder() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appA, Self.appB, Self.appC])
        var layout = LaunchpadLayout(pages: [[.folder(folder)]])

        let changed = layout.reorderApp(
            Self.appC.id,
            inFolder: Self.folderID,
            relativeTo: Self.appA.id,
            placement: .before
        )

        #expect(changed)
        #expect(layout.pages == [[
            .folder(Self.folder(Self.folderID, "Folder", [Self.appC, Self.appA, Self.appB]))
        ]])
    }

    @Test
    func reordersAppAfterTargetWithinFolder() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appA, Self.appB, Self.appC])
        var layout = LaunchpadLayout(pages: [[.folder(folder)]])

        let changed = layout.reorderApp(
            Self.appA.id,
            inFolder: Self.folderID,
            relativeTo: Self.appC.id,
            placement: .after
        )

        #expect(changed)
        #expect(layout.pages == [[
            .folder(Self.folder(Self.folderID, "Folder", [Self.appB, Self.appC, Self.appA]))
        ]])
    }

    @Test
    func removesAppFromFolderImmediatelyAfterFolder() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appA, Self.appB, Self.appC])
        var layout = LaunchpadLayout(pages: [[.app(Self.appD), .folder(folder)]])

        let changed = layout.removeApp(Self.appB.id, fromFolder: Self.folderID)

        #expect(changed)
        #expect(layout.pages == [[
            .app(Self.appD),
            .folder(Self.folder(Self.folderID, "Folder", [Self.appA, Self.appC])),
            .app(Self.appB)
        ]])
    }

    @Test
    func dissolvesFolderWhenRemovingOneOfTwoApps() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appA, Self.appB])
        var layout = LaunchpadLayout(pages: [[.app(Self.appD), .folder(folder), .app(Self.appC)]])

        let changed = layout.removeApp(Self.appB.id, fromFolder: Self.folderID)

        #expect(changed)
        #expect(layout.pages == [[
            .app(Self.appD), .app(Self.appA), .app(Self.appB), .app(Self.appC)
        ]])
    }

    @Test
    func invalidAndNoOpTopLevelReordersAreAtomic() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appC, Self.appD])
        let original: [[LaunchpadItem]] = [[], [.app(Self.appA), .app(Self.appB), .folder(folder)]]
        var layout = LaunchpadLayout(pages: original)

        Self.expectRejected(&layout, original: original) {
            $0.reorderTopLevel(itemID: Self.missingID, relativeTo: Self.appA.id, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderTopLevel(itemID: Self.appA.id, relativeTo: Self.missingID, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderTopLevel(itemID: Self.appA.id, relativeTo: Self.appA.id, placement: .after)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderTopLevel(itemID: Self.appA.id, relativeTo: Self.appB.id, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderTopLevel(itemID: Self.appC.id, relativeTo: Self.appA.id, placement: .before)
        }
    }

    @Test
    func invalidCombinesAreAtomicAndRejectFolderNesting() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appC, Self.appD])
        let original: [[LaunchpadItem]] = [[.app(Self.appA), .app(Self.appB), .folder(folder)]]
        var layout = LaunchpadLayout(pages: original)

        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.missingID, targetAppID: Self.appB.id, folderID: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.appA.id, targetAppID: Self.missingID, folderID: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.appA.id, targetAppID: Self.appA.id, folderID: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.folderID, targetAppID: Self.appA.id, folderID: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.appA.id, targetAppID: Self.folderID, folderID: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.combineApps(draggedAppID: Self.appA.id, targetAppID: Self.appB.id, folderID: Self.folderID)
        }
    }

    @Test
    func invalidFolderMutationsAreAtomic() {
        let folder = Self.folder(Self.folderID, "Folder", [Self.appB, Self.appC])
        let otherFolder = Self.folder(Self.otherFolderID, "Other", [Self.appD])
        let original: [[LaunchpadItem]] = [[.app(Self.appA), .folder(folder), .folder(otherFolder)]]
        var layout = LaunchpadLayout(pages: original)

        Self.expectRejected(&layout, original: original) {
            $0.addApp(Self.missingID, toFolder: Self.folderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.addApp(Self.appA.id, toFolder: Self.missingID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.addApp(Self.folderID, toFolder: Self.otherFolderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.addApp(Self.appB.id, toFolder: Self.otherFolderID)
        }

        Self.expectRejected(&layout, original: original) {
            $0.reorderApp(Self.missingID, inFolder: Self.folderID, relativeTo: Self.appB.id, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderApp(Self.appB.id, inFolder: Self.folderID, relativeTo: Self.missingID, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderApp(Self.appB.id, inFolder: Self.folderID, relativeTo: Self.appB.id, placement: .after)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderApp(Self.appB.id, inFolder: Self.folderID, relativeTo: Self.appC.id, placement: .before)
        }
        Self.expectRejected(&layout, original: original) {
            $0.reorderApp(Self.appD.id, inFolder: Self.folderID, relativeTo: Self.appB.id, placement: .before)
        }

        Self.expectRejected(&layout, original: original) {
            $0.removeApp(Self.missingID, fromFolder: Self.folderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.removeApp(Self.appB.id, fromFolder: Self.missingID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.removeApp(Self.appA.id, fromFolder: Self.folderID)
        }
        Self.expectRejected(&layout, original: original) {
            $0.removeApp(Self.appD.id, fromFolder: Self.otherFolderID)
        }
    }

    private static func id(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private static func app(_ value: Int, _ title: String) -> AppItem {
        AppItem(id: id(value), bundleID: "com.example.\(title.lowercased())", title: title)
    }

    private static func folder(_ id: UUID, _ title: String, _ apps: [AppItem]) -> FolderItem {
        FolderItem(id: id, title: title, apps: apps)
    }

    private static func expectRejected(
        _ layout: inout LaunchpadLayout,
        original: [[LaunchpadItem]],
        mutation: (inout LaunchpadLayout) -> Bool
    ) {
        let changed = mutation(&layout)
        #expect(!changed)
        #expect(layout.pages == original)
    }
}
