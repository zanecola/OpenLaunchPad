# OpenLaunchPad Progress

Last updated: 2026-07-21

## Current State

- Worktree: `/Users/zane/Projects/OpenLaunchPad/.worktrees/drag-drop-organization`
- Branch: `codex/drag-drop-organization`
- Implementation baseline for this documentation pass: `39e96bc`
- Build status: `./script/build_and_run.sh --verify` passes and launches the worktree app.
- Test status: `swift test` passes with 75 tests in 15 suites.

## Completed Work

### Architecture and Data

- Established a modular Data -> Domain -> ViewModel -> View architecture with AppKit at the macOS integration edges.
- Added read-only Dock Launchpad database loading plus `/Applications` fallback scanning, source-folder preservation, stable IDs, and app deduplication.
- Added database change watching with coalesced reloads.
- Added versioned JSON layout persistence with migrations, full folder membership, atomic writes, and robust restoration when apps are added or removed.
- Added protocols for data sources, layout storage, and icon providers so implementations can be replaced or extended.

### Organization

- Added identity-only drag payloads, deterministic drop zones/intents, and a pure `LaunchpadLayout` mutation engine.
- Implemented top-level reorder, cross-page domain reorder, app-to-app folder creation, app-to-folder insertion, folder-internal reorder, drag-out, empty-page cleanup, and automatic folder dissolution.
- Added gesture-driven drag handling with a visible floating preview, source fading, insertion indicators, and folder grouping feedback.
- Added persistent folder rename and backward-compatible layout restoration.

### Launcher UX

- Separated full-screen pagination from popup vertical scrolling.
- Added page controls, horizontal mouse/trackpad navigation, arrow-key navigation, and Command-Left/Command-Right commands.
- Removed intrusive popup and folder scrollbars while retaining scrolling.
- Added responsive grid sizing, aligned two-line labels, and automatic popup columns so panel width and icon size do not conflict.
- Fixed launcher dismissal after app launch and kept the full-screen window from floating above other apps.
- Added a shared, working material blur backdrop for popup and full-screen modes.

### macOS Integration

- Replaced split menu-bar implementations with one AppKit status item.
- Made left-click open a non-activating popup directly below the status icon, including when another app is active.
- Made right-click show only Settings, About, and Quit.
- Added a retained Settings window opened from the search-bar gear, status menu, and Command-comma.
- Added immediate menu-bar visibility and global-shortcut updates.
- Added Dock full-screen/popup selection and Dock-edge popup placement.
- Added a bundled application icon for local `.app` builds.

### App Actions

- Added app context menus with Open, Show in Finder, Get Info, and confirmed Uninstall.
- Added protected-app checks, visible errors, Move to Trash behavior, and layout updates only after successful uninstall.

### Documentation and Verification

- Updated `README.md` with build, run, test, data, usage, persistence, troubleshooting, and limitation instructions.
- Updated `DESIGN.md` to describe the current architecture and extension boundaries.
- Added 75 tests across layout rules, view-model orchestration, persistence migrations, data sources, settings, window policies, paging input, app actions, and blur normalization.

## Manual UX Checklist

- Reorder a top-level app before and after another app and relaunch to confirm persistence.
- Create a folder, add another app, reorder inside it, rename it, and relaunch.
- Drag an app out of a two-app folder and confirm the folder dissolves.
- Verify drag preview and target indicators at several icon sizes.
- Verify full-screen paging with controls, horizontal input, arrows, and Command-arrow shortcuts.
- Verify popup vertical scrolling has no visible native scrollbar.
- Left-click the menu bar icon while another app is active and confirm the popup opens below it without activating OpenLaunchPad.
- Right-click the menu bar icon and exercise Settings, About, and Quit.
- Open Settings from the search-bar gear and confirm the launcher closes behind it.
- Move the blur slider through low and high values in both launcher modes.
- Exercise app context actions; use only a disposable app when testing Uninstall.
- Verify the Dock icon after macOS refreshes its icon cache.

## Next Steps

1. Complete the manual UX checklist and record any reproducible failures with screen size, icon size, and activation mode.
2. Add UI automation for status-item activation, Settings presentation, and representative drag gestures where macOS test APIs are reliable.
3. Decide whether sorting needs a launcher-local control near Search; it is intentionally not part of the status-item right-click menu.
4. Add page-edge auto-navigation during full-screen dragging if cross-page organization is required from the UI.
5. Prepare release signing, notarization, packaging, and installation instructions.

## Historical Notes

The files under `docs/superpowers/` are the original drag-and-drop design and implementation plan. They are retained as historical planning records; `README.md`, `DESIGN.md`, and this file describe the current implementation.
