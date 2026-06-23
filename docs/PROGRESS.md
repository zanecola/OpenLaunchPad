# OpenLaunchPad Progress

Last updated: 2026-07-21

## Current Branch

- Worktree: `/Users/zane/Projects/OpenLaunchPad/.worktrees/drag-drop-organization`
- Branch: `codex/drag-drop-organization`

## Completed

- Reworked drag identity around `LaunchpadDragPayload` instead of dragging full app/folder model snapshots.
- Added pure drop-zone and drop-intent semantics for leading, center, and trailing drops.
- Added `LaunchpadLayout` as the reusable mutation engine for top-level reorder, folder creation, folder insertion, folder-internal reorder, drag-out, and folder dissolution.
- Added versioned JSON layout persistence with folder membership and backward-compatible migrations.
- Hardened layout restoration so orphaned or duplicate stored folders cannot hide apps.
- Preserved newly discovered apps inside restored source folders.
- Wired top-level SwiftUI drag/drop for reorder, app-to-app folder creation, and app-to-folder insertion.
- Wired expanded folder app reordering and drag-out via the surrounding folder backdrop.
- Fixed launch dismissal paths for full-screen and popup launch surfaces.
- Kept full-screen mode at normal window level so other apps can come forward.
- Added an opaque popup panel background and Dock-edge popup placement.
- Added a custom Dock icon and bundled it into local `.app` builds.
- Replaced the split SwiftUI menu-bar implementation with one reusable AppKit status item.
- Added a right-click menu with Settings, name sorting, About, and Quit.
- Added a compact Settings button beside the search field and reused the same Settings opening path.
- Added persisted one-shot A–Z and Z–A sorting across pages and inside folders.
- Fixed menu-bar popup placement so the panel opens below the clicked status icon.
- Deferred menu-bar popup activation until status-item tracking releases the previously active app, then presents only after explicit activation completes.
- Made hidden menu-bar icon changes apply immediately without restarting the app.
- Added reusable app-icon context menus with Open, Show in Finder, Get Info, and Uninstall.
- Added protected-app checks, Move to Trash confirmation, visible error reporting, and atomic layout updates after uninstall.
- Top-aligned app and folder cells with a shared two-line label height so every icon in a row has the same top edge.
- Updated `README.md` with build, run, test, data, and organization instructions.

## Verified

- `swift test` passes with 71 tests.
- `./script/build_and_run.sh --verify` builds, bundles, launches, and confirms the process is alive.
- Bundle inspection confirms `CFBundleIconFile` is `AppIcon`.
- Bundle inspection confirms `dist/OpenLaunchPad.app/Contents/Resources/AppIcon.icns` is present.

## Still Needs Manual UX Pass

- Drag a top-level app before and after another app.
- Drop one app onto another app to create a folder.
- Drop a top-level app onto an existing folder.
- Open a folder and reorder apps inside it.
- Drag an app out of a folder onto the dimmed backdrop.
- Confirm folder dissolution when dragging out from a two-app folder.
- Confirm the new Dock icon appears after macOS refreshes the bundle icon cache.
- Left-click the menu bar icon and confirm the popup opens directly below it.
- Right-click the menu bar icon and exercise Settings, Sort By, About, and Quit.
- Open Settings from the button beside Search and confirm the launcher closes behind it.
- Right-click top-level, search-result, and folder app icons and verify the context actions.
- Confirm Uninstall moves a disposable test app to Trash and updates its folder without removing app data.
