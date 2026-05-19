# OpenLaunchPad

OpenLaunchPad is a SwiftUI and AppKit macOS app that recreates a Launchpad-style app launcher for macOS 26+. It reads the existing Dock Launchpad database in read-only mode, falls back to scanning system application folders, and stores any custom icon ordering in its own JSON file.

## Requirements

- macOS 26.0 or newer
- Xcode with the macOS 26 SDK installed
- SwiftPM, available through Xcode's toolchain
- A non-sandboxed runtime if you want Launchpad database access and global hotkeys

The package uses Swift tools version 5.9 but targets macOS 26 with `platforms: [.macOS("26.0")]`.

## Build

From the repository root:

```bash
swift build
```

In the Codex desktop sandbox, SwiftPM may try to write caches outside the workspace. If that happens, use workspace-local cache paths:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift build
```

## Run

Build a local `.app` bundle and launch it:

```bash
./script/build_and_run.sh
```

The script stages `dist/OpenLaunchPad.app`, stops an existing instance, and launches the fresh build. The Codex project Run action uses this same script.

To launch and confirm that the process remains alive:

```bash
./script/build_and_run.sh --verify
```

The generated bundle is for local development. Regular distribution still requires signing, notarization, and release packaging.

## Test

Run the SwiftPM test suite from the repository root:

```bash
swift test
```

The current tests cover key `LaunchpadViewModel` behavior:

- loading pages and clamping the selected page
- merging custom layout with new apps from the source data
- persisting rearranged layouts
- resetting to the source order
- reconstructing ordered pages, folders, and folder contents from SQLite fixtures
- skipping the Dock database's holding hierarchy
- rejecting malformed Launchpad databases
- coalescing rapid database file writes into one reload notification
- formatting and persisting recorded global shortcuts

## How It Works

OpenLaunchPad is split into four main areas:

- `Sources/OpenLaunchPad/App`: app entry point and `NSApplicationDelegate` lifecycle handling.
- `Sources/OpenLaunchPad/Data`: Launchpad database reading, `/Applications` fallback scanning, icon loading, config persistence, and custom layout storage.
- `Sources/OpenLaunchPad/ViewModel`: central observable state for pages, search, folders, icons, launch actions, and layout persistence.
- `Sources/OpenLaunchPad/Views` and `Sources/OpenLaunchPad/Windows`: SwiftUI launcher UI plus small AppKit wrappers for full-screen and popup windows.
- `Tests/OpenLaunchPadTests`: Swift Testing coverage for view-model behavior.

The main data flow is:

```text
LaunchpadDBDataSource or ApplicationsFolderDataSource
    -> CompositeDataSource
    -> LaunchpadViewModel
    -> SwiftUI views
```

User ordering is merged on load:

```text
system app list + ~/Library/Application Support/OpenLaunchPad/layout.json
    -> visible pages
```

## Data Sources

The primary data source reads the Dock Launchpad SQLite database:

```text
~/Library/Application Support/Dock/desktopproperties.db
```

It opens the database with `SQLITE_OPEN_READONLY` and never writes to it.

If that database cannot be opened or queried, the fallback source scans:

```text
/Applications
~/Applications
/System/Applications
```

The fallback preserves immediate application directories as folders, removes duplicate bundle identifiers, and derives stable IDs so custom ordering survives reloads. On macOS 26 systems where the legacy Dock Launchpad database no longer exists, old user-created Launchpad groups are not available to import.

## Stored Data

User settings are stored in `UserDefaults` with the suite name:

```text
com.openlaunchpad
```

Custom layout is stored separately from the Dock database:

```text
~/Library/Application Support/OpenLaunchPad/layout.json
```

Deleting `layout.json` resets icon order back to the data source order. The Settings window also exposes a reset action.
Folder names are edited directly in the expanded folder header and are persisted in the same file. Legacy layout files containing only page IDs are migrated automatically when next saved.

## Features

- Full-screen Launchpad-style overlay
- Menu bar popup panel
- Dock click mode: full-screen or an opaque popup anchored beside the clicked Dock icon
- AppKit-backed shortcut recorder with immediate Carbon hotkey registration
- Full-screen paging with controls, horizontal wheel/trackpad gestures, and `Command-Left` / `Command-Right`
- Continuous vertical scrolling in the menu-bar popup
- Search by app name, folder name, or app inside folder
- Folder preview and expanded folder overlay
- App launch automatically dismisses the active launcher surface
- Scrollable folder overlays in both full-screen and popup modes
- Configurable icon size, labels, grid columns, popup dimensions, blur, animation speed, and menu bar visibility
- Drag-to-rearrange support with layout persistence
- Read-only Launchpad database access with `/Applications` fallback
- Automatic reload when the Dock Launchpad database changes
- Filesystem-folder preservation and app deduplication when using the applications fallback

## Current Limitations

- There is no packaged `.app` target yet.
- Test coverage currently focuses on the view model and database parsing. UI and window behavior still need coverage.
- Cross-page drag behavior is intentionally simple and may need a custom gesture implementation later.
- Legacy user-created Launchpad folders cannot be recovered when macOS has removed `desktopproperties.db`; filesystem application folders remain available.
- The app does not write changes back to the Dock Launchpad database by design.

## Troubleshooting

If `swift build` fails with cache or module-cache permission errors, use workspace-local cache paths:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift build
```

If Launchpad data is missing, verify that this file exists and is readable:

```text
~/Library/Application Support/Dock/desktopproperties.db
```

If it is not readable, OpenLaunchPad should fall back to scanning `/Applications` and `/System/Applications`.

If the global shortcut does not work, open Settings, record it again, and verify that another application has not already registered the same combination.

## Project Notes

- `DESIGN.md` contains the functional design and architectural decisions.
- The app intentionally keeps AppKit at the edges for windows, panels, icons, app launching, and global hotkeys.
- The Dock database is treated as source data only. All OpenLaunchPad-specific state lives under the app's own support path or user defaults.
