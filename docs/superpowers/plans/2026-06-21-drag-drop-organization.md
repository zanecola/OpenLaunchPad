# Drag-and-Drop Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent drag reordering, app-to-folder creation, folder insertion, folder-internal ordering, and drag-out with automatic folder dissolution.

**Architecture:** A pure `LaunchpadLayout` value type owns all graph mutations and invariants. Transferable payloads and drop-zone classification are independent domain types; `LaunchpadViewModel` only coordinates mutations and persistence; reusable SwiftUI drop adapters translate pointer activity into semantic calls.

**Tech Stack:** Swift 5.9, SwiftUI, CoreTransferable, UniformTypeIdentifiers, Observation, Swift Testing, SwiftPM on macOS 26.

---

## File Structure

- Create `Sources/OpenLaunchPad/Models/LaunchpadDragPayload.swift`: transferable drag identity and item kind.
- Create `Sources/OpenLaunchPad/Models/LaunchpadDropIntent.swift`: pure edge/center classification and placement semantics.
- Create `Sources/OpenLaunchPad/Models/LaunchpadLayout.swift`: pure page and folder graph mutations.
- Create `Sources/OpenLaunchPad/Views/LaunchpadItemDropView.swift`: reusable SwiftUI `DropDelegate` adapter and visual feedback.
- Create `Tests/OpenLaunchPadTests/LaunchpadDropIntentTests.swift`: pointer-zone classification tests.
- Create `Tests/OpenLaunchPadTests/LaunchpadLayoutTests.swift`: domain mutation and invariant tests.
- Modify `Sources/OpenLaunchPad/Models/LaunchpadItem.swift`: remove the superseded per-model transferable declarations.
- Modify `Sources/OpenLaunchPad/Data/Protocols/LayoutStoring.swift`: add persisted folder DTOs and backward-compatible decoding fields.
- Modify `Sources/OpenLaunchPad/Data/JSONLayoutStore.swift`: migrate legacy layouts and round-trip folder membership.
- Modify `Sources/OpenLaunchPad/ViewModel/LaunchpadViewModel.swift`: restore folder graphs and expose semantic mutation methods.
- Modify `Sources/OpenLaunchPad/Views/AppIconView.swift`: accept an optional unified drag payload instead of always exporting `AppItem`.
- Modify `Sources/OpenLaunchPad/Views/FolderView.swift`: accept a folder drag payload and support draggable apps in the expanded view.
- Modify `Sources/OpenLaunchPad/Views/AppGridView.swift`: install item-level drop surfaces and remove page-level append-only dropping.
- Modify `Sources/OpenLaunchPad/Views/LaunchpadView.swift`: wire full-screen folder drag-out.
- Modify `Sources/OpenLaunchPad/Views/MenuBarPanelView.swift`: wire popup folder drag-out.
- Modify `Tests/OpenLaunchPadTests/LaunchpadViewModelTests.swift`: verify orchestration, persistence count, and restoration.
- Modify `Tests/OpenLaunchPadTests/JSONLayoutStoreTests.swift`: verify both migrations and new schema round trips.
- Modify `README.md`: document organization gestures and persistence behavior.

### Task 0: Establish a Reviewable Source Baseline

**Files:**
- Create: `.gitignore`
- Add existing: `Package.swift`, `DESIGN.md`, `README.md`, `Sources/`, `Tests/`, `script/`

- [ ] **Step 1: Ignore local and generated artifacts**

Create `.gitignore` with:

```gitignore
.build/
.claude/
.codex/
dist/
.DS_Store
```

- [ ] **Step 2: Run the existing suite before recording the baseline**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test
```

Expected: the existing suite passes before drag-and-drop changes begin.

- [ ] **Step 3: Commit only human-authored project files**

```bash
git add .gitignore Package.swift DESIGN.md README.md Sources Tests script
git status --short
git commit -m "chore: establish open launchpad source baseline"
```

Expected: `.build`, `.claude`, `.codex`, and `dist` are absent from staged files.

### Task 1: Drag Identity and Drop Semantics

**Files:**
- Create: `Sources/OpenLaunchPad/Models/LaunchpadDragPayload.swift`
- Create: `Sources/OpenLaunchPad/Models/LaunchpadDropIntent.swift`
- Modify: `Sources/OpenLaunchPad/Models/LaunchpadItem.swift`
- Create: `Tests/OpenLaunchPadTests/LaunchpadDropIntentTests.swift`

- [ ] **Step 1: Write failing classification tests**

Add tests that establish the stable reusable API:

```swift
import CoreGraphics
import Testing
@testable import OpenLaunchPad

struct LaunchpadDropIntentTests {
    @Test(arguments: [
        (x: 0.0, expected: DropZone.leading),
        (x: 24.9, expected: DropZone.leading),
        (x: 25.0, expected: DropZone.center),
        (x: 74.9, expected: DropZone.center),
        (x: 75.0, expected: DropZone.trailing),
        (x: 100.0, expected: DropZone.trailing)
    ])
    func classifiesPointerPosition(x: Double, expected: DropZone) {
        #expect(DropZone.classify(x: x, width: 100) == expected)
    }

    @Test
    func nonPositiveWidthFallsBackToCenter() {
        #expect(DropZone.classify(x: 10, width: 0) == .center)
    }

    @Test
    func centerOnlyGroupsApps() {
        #expect(LaunchpadDropIntent.resolve(source: .app, target: .app, zone: .center) == .combineApps)
        #expect(LaunchpadDropIntent.resolve(source: .app, target: .folder, zone: .center) == .addToFolder)
        #expect(LaunchpadDropIntent.resolve(source: .folder, target: .app, zone: .center) == .reorder(.after))
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadDropIntentTests
```

Expected: compilation fails because `DropZone` and `LaunchpadDropIntent` do not exist.

- [ ] **Step 3: Add unified payload and pure drop types**

Implement these public-to-module shapes:

```swift
enum LaunchpadDragKind: String, Codable, Hashable, Sendable {
    case app
    case folder
}

struct LaunchpadDragPayload: Codable, Hashable, Sendable, Transferable {
    let itemID: UUID
    let kind: LaunchpadDragKind

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadItem)
    }
}

enum ItemPlacement: Equatable, Sendable {
    case before
    case after
}

enum DropZone: Equatable, Sendable {
    case leading
    case center
    case trailing

    static func classify(x: Double, width: Double) -> Self {
        guard width > 0 else { return .center }
        let fraction = min(max(x / width, 0), 1)
        if fraction < 0.25 { return .leading }
        if fraction >= 0.75 { return .trailing }
        return .center
    }
}

enum LaunchpadDropIntent: Equatable, Sendable {
    case reorder(ItemPlacement)
    case combineApps
    case addToFolder

    static func resolve(source: LaunchpadDragKind, target: LaunchpadDragKind, zone: DropZone) -> Self {
        switch zone {
        case .leading: return .reorder(.before)
        case .trailing: return .reorder(.after)
        case .center where source == .app && target == .app: return .combineApps
        case .center where source == .app && target == .folder: return .addToFolder
        case .center: return .reorder(.after)
        }
    }
}
```

Define `UTType.launchpadItem` in the payload file. Remove `AppItem: Transferable`, `FolderItem: Transferable`, and their two old UTTypes from `LaunchpadItem.swift`.

- [ ] **Step 4: Run the focused tests and confirm they pass**

Run the Task 1 test command. Expected: all `LaunchpadDropIntentTests` pass.

- [ ] **Step 5: Commit the domain vocabulary**

```bash
git add Sources/OpenLaunchPad/Models Tests/OpenLaunchPadTests/LaunchpadDropIntentTests.swift
git commit -m "feat: add reusable launchpad drag semantics"
```

### Task 2: Pure Layout Mutation Engine

**Files:**
- Create: `Sources/OpenLaunchPad/Models/LaunchpadLayout.swift`
- Create: `Tests/OpenLaunchPadTests/LaunchpadLayoutTests.swift`

- [ ] **Step 1: Write failing layout mutation tests**

Cover the complete domain contract using fixed UUIDs:

```swift
@Test func reordersTopLevelItemsBeforeAndAfterTarget()
@Test func combinesTwoTopLevelAppsAtTargetPosition()
@Test func movesTopLevelAppIntoExistingFolder()
@Test func reordersAppsWithinFolder()
@Test func removesAppFromFolderAfterFolderOnPage()
@Test func dissolvesFolderWhenOneAppRemains()
@Test func removesEmptySourcePageAndClampsSuggestedPage()
@Test func rejectsFolderNestingAndMissingIdentifiers()
@Test func leavesLayoutUnchangedForNoOpMove()
```

Each test should compare the entire `pages` value before and after and assert the returned `Bool`.

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadLayoutTests
```

Expected: compilation fails because `LaunchpadLayout` does not exist.

- [ ] **Step 3: Implement the pure layout engine**

Create a value type with no UI or storage imports:

```swift
struct LaunchpadLayout: Equatable, Sendable {
    private(set) var pages: [[LaunchpadItem]]

    init(pages: [[LaunchpadItem]]) { self.pages = pages }

    mutating func reorderTopLevel(
        itemID: UUID,
        relativeTo targetID: UUID,
        placement: ItemPlacement
    ) -> Bool

    mutating func combineApps(
        draggedAppID: UUID,
        targetAppID: UUID,
        folderID: UUID,
        title: String = "Folder"
    ) -> Bool

    mutating func addApp(_ appID: UUID, toFolder folderID: UUID) -> Bool

    mutating func reorderApp(
        _ appID: UUID,
        inFolder folderID: UUID,
        relativeTo targetAppID: UUID,
        placement: ItemPlacement
    ) -> Bool

    mutating func removeApp(_ appID: UUID, fromFolder folderID: UUID) -> Bool
}
```

Use private location enums for top-level and folder-contained apps. Validate every source and target before changing `pages`; perform mutations on a local copy and assign it only after success. Normalize empty pages after cross-page removal. During drag-out, insert after the folder; if one app remains, replace the folder with that app and place the removed app immediately after it.

- [ ] **Step 4: Run layout and existing view-model tests**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadLayoutTests
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadViewModelTests
```

Expected: both suites pass; the new engine has not changed existing view-model behavior yet.

- [ ] **Step 5: Commit the mutation engine**

```bash
git add Sources/OpenLaunchPad/Models/LaunchpadLayout.swift Tests/OpenLaunchPadTests/LaunchpadLayoutTests.swift
git commit -m "feat: add launchpad layout mutation engine"
```

### Task 3: Persisted Folder Graph and Migration

**Files:**
- Modify: `Sources/OpenLaunchPad/Data/Protocols/LayoutStoring.swift`
- Modify: `Sources/OpenLaunchPad/Data/JSONLayoutStore.swift`
- Modify: `Tests/OpenLaunchPadTests/JSONLayoutStoreTests.swift`

- [ ] **Step 1: Write failing persistence tests**

Add tests for:

```swift
@Test func roundTripsOrderedFolderDefinitions()
@Test func migratesCurrentPageIDsAndFolderNamesSchema()
@Test func migratesLegacyRawPageIDsSchema()
```

The current-schema fixture must be encoded from a local legacy struct with `pageIDs` and `folderNames`, ensuring the test does not accidentally use the new encoder.

- [ ] **Step 2: Run the store tests and confirm the new assertions fail**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter JSONLayoutStoreTests
```

Expected: compilation fails because `StoredFolder` and `StoredLayout.folders` do not exist.

- [ ] **Step 3: Introduce the versioned storage DTOs**

Use ordered arrays rather than dictionaries so encoded output remains readable:

```swift
struct StoredFolder: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var appIDs: [UUID]
}

struct StoredLayout: Codable, Equatable, Sendable {
    var pageIDs: [[UUID]]
    var folders: [StoredFolder]

    init(pageIDs: [[UUID]], folders: [StoredFolder] = []) {
        self.pageIDs = pageIDs
        self.folders = folders
    }
}
```

In `JSONLayoutStore.loadCustomLayout()`, decode in this order:

1. new `StoredLayout`;
2. private `LegacyNamedLayout { pageIDs; folderNames }`, converted into name-only `StoredFolder` values with empty `appIDs`;
3. raw `[[UUID]]`, converted to `StoredLayout(pageIDs:)`.

Name-only folder records signal that source membership must be retained during restoration.

- [ ] **Step 4: Run store tests and confirm all migrations pass**

Run the Task 3 test command. Expected: all `JSONLayoutStoreTests` pass.

- [ ] **Step 5: Commit the schema migration**

```bash
git add Sources/OpenLaunchPad/Data Tests/OpenLaunchPadTests/JSONLayoutStoreTests.swift
git commit -m "feat: persist launchpad folder membership"
```

### Task 4: View-Model Restoration and Orchestration

**Files:**
- Modify: `Sources/OpenLaunchPad/ViewModel/LaunchpadViewModel.swift`
- Modify: `Tests/OpenLaunchPadTests/LaunchpadViewModelTests.swift`

- [ ] **Step 1: Write failing restoration and orchestration tests**

Add focused tests for:

```swift
@Test func loadReconstructsUserCreatedFolderFromStoredAppIDs() async
@Test func loadRetainsSourceMembershipForMigratedNameOnlyFolder() async
@Test func loadDissolvesStoredFolderWhenOnlyOneAppStillExists() async
@Test func combineAppsPersistsExactlyOnce()
@Test func addAppToFolderPersistsExactlyOnce()
@Test func reorderFolderAppPersistsExactlyOnce()
@Test func removeAppFromFolderDissolvesAndClosesExpandedFolder()
@Test func invalidMutationDoesNotPersist()
```

Update `StubLayoutStore` to retain `[StoredLayout]` rather than separate page/name arrays.

- [ ] **Step 2: Run view-model tests and confirm they fail**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadViewModelTests
```

Expected: compilation fails for the new semantic methods and folder schema.

- [ ] **Step 3: Restore complete layouts without duplicating apps**

Refactor `applyCustomLayout` to build:

```swift
let sourceApps: [UUID: AppItem]
let sourceTopLevelItems: [UUID: LaunchpadItem]
let sourceFolders: [UUID: FolderItem]
```

Reconstruct stored folders in their `appIDs` order. For an empty `appIDs` migration record, take membership from the matching source folder and apply only its stored title. Track app IDs consumed by reconstructed folders so those apps cannot also appear as top-level unplaced items. Normalize reconstructed folders with zero or one available app before appending newly sourced items.

- [ ] **Step 4: Add semantic view-model mutation methods**

Use one coordinator helper:

```swift
private func mutateLayout(_ mutation: (inout LaunchpadLayout) -> Bool) -> Bool {
    var layout = LaunchpadLayout(pages: pages)
    guard mutation(&layout) else { return false }
    pages = layout.pages
    if expandedFolderID != nil && expandedFolder == nil { closeFolder() }
    persistLayout()
    clampCurrentPage()
    return true
}
```

Expose:

```swift
func reorderTopLevel(itemID: UUID, relativeTo targetID: UUID, placement: ItemPlacement) -> Bool
func combineApps(draggedID: UUID, targetID: UUID) -> Bool
func addApp(_ appID: UUID, toFolder folderID: UUID) -> Bool
func reorderApp(_ appID: UUID, inFolder folderID: UUID, relativeTo targetID: UUID, placement: ItemPlacement) -> Bool
func removeApp(_ appID: UUID, fromFolder folderID: UUID) -> Bool
```

Generate the folder UUID only in `combineApps`; inject `makeUUID: () -> UUID = UUID.init` through the view-model initializer for deterministic tests. Persist `StoredFolder` records including ordered membership. Retain `move(itemID:toPage:at:)` only if a current caller or test still needs it; otherwise remove it with the superseded page-level drop code.

- [ ] **Step 5: Run all domain, store, and view-model tests**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadLayoutTests
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter JSONLayoutStoreTests
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --filter LaunchpadViewModelTests
```

Expected: all three suites pass.

- [ ] **Step 6: Commit view-model integration**

```bash
git add Sources/OpenLaunchPad/ViewModel Tests/OpenLaunchPadTests/LaunchpadViewModelTests.swift
git commit -m "feat: orchestrate persistent launchpad organization"
```

### Task 5: Reusable Top-Level Drop Surface

**Files:**
- Create: `Sources/OpenLaunchPad/Views/LaunchpadItemDropView.swift`
- Modify: `Sources/OpenLaunchPad/Views/AppIconView.swift`
- Modify: `Sources/OpenLaunchPad/Views/FolderView.swift`
- Modify: `Sources/OpenLaunchPad/Views/AppGridView.swift`

- [ ] **Step 1: Add the reusable drop adapter**

Create a generic view that owns hover feedback but no layout rules:

```swift
struct LaunchpadItemDropView<Content: View>: View {
    let payload: LaunchpadDragPayload
    let onDrop: (LaunchpadDragPayload, DropZone) -> Bool
    @ViewBuilder let content: () -> Content
    @State private var activeZone: DropZone?
}
```

Back it with `LaunchpadItemDropDelegate: DropDelegate`. In `dropUpdated`, classify `info.location.x` against the supplied cell width and publish the zone. In `performDrop`, call `NSItemProvider.loadTransferable(type: LaunchpadDragPayload.self)`, dispatch the result to `@MainActor`, and invoke `onDrop`. Clear feedback in `dropExited` and after completion. Render a narrow leading/trailing insertion bar for edge zones and a rounded outline for center.

- [ ] **Step 2: Make icon dragging payload-driven**

Change `AppIconView` to accept `dragPayload: LaunchpadDragPayload? = nil`. Apply `.draggable(payload)` only when non-nil by using a small `View` extension or `@ViewBuilder`, keeping search-result icons launch-only. Apply the same optional payload pattern to `FolderView`.

- [ ] **Step 3: Wire semantic drops in the paged and scrolling grids**

Wrap each top-level item in `LaunchpadItemDropView`. Resolve intent with:

```swift
let intent = LaunchpadDropIntent.resolve(
    source: payload.kind,
    target: item.dragKind,
    zone: zone
)
```

Dispatch `.reorder` to `vm.reorderTopLevel`, `.combineApps` to `vm.combineApps`, and `.addToFolder` to `vm.addApp`. Reject self-drops. Remove the old page-level `.dropDestination(for: AppItem.self)` append behavior. Do not wrap search results in drop surfaces.

- [ ] **Step 4: Build and run all tests**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift build
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test
```

Expected: build succeeds and the full test suite passes.

- [ ] **Step 5: Commit top-level drag/drop UI**

```bash
git add Sources/OpenLaunchPad/Views
git commit -m "feat: add reusable launchpad drop surfaces"
```

### Task 6: Folder-Internal Reorder and Drag-Out

**Files:**
- Modify: `Sources/OpenLaunchPad/Views/FolderView.swift`
- Modify: `Sources/OpenLaunchPad/Views/LaunchpadView.swift`
- Modify: `Sources/OpenLaunchPad/Views/MenuBarPanelView.swift`

- [ ] **Step 1: Add folder callbacks with reusable signatures**

Extend `FolderExpandedView` with:

```swift
var onReorder: (UUID, UUID, ItemPlacement) -> Bool = { _, _, _ in false }
var onDragOut: (UUID) -> Bool = { _ in false }
```

Give each folder app a `.app` payload and wrap it in `LaunchpadItemDropView`. Map leading and center to `.before`, trailing to `.after`; center does not create nested folders inside an open folder.

- [ ] **Step 2: Make only the surrounding backdrop a drag-out target**

Add a reusable `FolderDragOutDropView` around each overlay backdrop. Accept only `.app` payloads and call `onDragOut(payload.itemID)`. Keep the material folder panel above this surface so dropping inside unused panel space cannot eject an app.

Wire both launcher surfaces:

```swift
onReorder: { appID, targetID, placement in
    vm.reorderApp(appID, inFolder: folder.id, relativeTo: targetID, placement: placement)
},
onDragOut: { appID in
    vm.removeApp(appID, fromFolder: folder.id)
}
```

- [ ] **Step 3: Build and run all tests**

Run:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift build
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test
```

Expected: build succeeds and the full suite passes.

- [ ] **Step 4: Launch and manually exercise both surfaces**

Run:

```bash
./script/build_and_run.sh --verify
```

Verify in full-screen and popup modes:

1. Drag before and after an app.
2. Drop one app in another app's center and confirm a folder appears.
3. Drop a third app on the folder.
4. Open the folder and reorder its apps.
5. Drag an app to the backdrop and confirm it appears after the folder.
6. Drag out again until one app remains and confirm the folder dissolves.
7. Relaunch and confirm order, names, and membership remain.

- [ ] **Step 5: Commit folder drag interactions**

```bash
git add Sources/OpenLaunchPad/Views
git commit -m "feat: support folder reorder and drag out"
```

### Task 7: Documentation and Final Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update user and architecture documentation**

Document edge versus center drops, drag-out behavior, auto-dissolution, and the new full folder-membership schema. Update the architecture section to identify `LaunchpadLayout`, drop semantics, view-model coordination, and SwiftUI adapters as separate extension points. Remove the limitation claiming cross-page drag is the only organization behavior if it is no longer accurate.

- [ ] **Step 2: Run formatting-sensitive checks and the complete suite**

Run:

```bash
rg -n 'launchpadApp|launchpadFolder|draggable\(app\)|dropDestination\(for: AppItem' Sources Tests
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift build
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test
./script/build_and_run.sh --verify
```

Expected: the search returns no superseded drag implementation, build succeeds, all tests pass, and the app process remains alive.

- [ ] **Step 3: Inspect the final diff for modularity and scope**

Run:

```bash
git diff --stat 61b5550..HEAD
git status --short
```

Confirm domain files do not import SwiftUI or AppKit, views do not mutate `vm.pages`, persistence DTOs do not depend on SwiftUI, and generated `.build` or `dist` artifacts are not staged.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md
git commit -m "docs: explain drag and drop organization"
```
