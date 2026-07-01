# OpenLaunchPad Design

> macOS 26+ replacement for the removed Launchpad.
> Last updated: 2026-07-21

## Product Contract

OpenLaunchPad provides a fast macOS app launcher with two presentation modes:

- a borderless full-screen launcher with horizontal pagination;
- a non-activating popup opened from the menu bar or Dock.

It reads Apple's Launchpad database when available, falls back to application-folder scanning, and stores all OpenLaunchPad-specific organization separately. It never writes to Apple's Dock database.

The current interaction contract includes search, folders, persistent drag organization, app context actions, settings, a global shortcut, responsive layout, and appearance controls.

## Architecture

The project uses a layered SwiftUI and AppKit architecture:

```text
Dock click / status item / global shortcut / app commands
                         |
                         v
             AppDelegate and window controllers
                         |
          +--------------+--------------+
          |                             |
          v                             v
 FullScreenWindow                 PopupPanel
 LaunchpadView                    MenuBarPanelView
          |                             |
          +--------------+--------------+
                         |
                         v
                LaunchpadViewModel
                 /       |       \
                v        v        v
      data sources   layout store  app/icon services
                         |
                         v
                 LaunchpadLayout
              pure mutation/invariants
```

### App and Activation

`AppDelegate` owns the single `ConfigStore`, `LaunchpadViewModel`, status item, global hotkey, database watcher, and launcher surfaces.

- Dock reopen uses the configured full-screen or popup mode.
- Left-clicking the status item toggles a popup below the icon.
- Right-clicking the status item opens a standard menu containing Settings, About, and Quit.
- The popup is a non-activating `NSPanel` at `.popUpMenu` level. It remains usable over another app and dismisses on an outside click.
- The full-screen window stays at normal level and closes when OpenLaunchPad resigns active, so it cannot trap the user above other apps.
- Settings use a retained `SettingsWindowController`, shared by the search-bar gear, status menu, and Command-comma.

### Domain and View Model

`LaunchpadItem` is either an `AppItem` or `FolderItem`. Models contain stable identity and metadata, not UI state or icons.

`LaunchpadLayout` is a pure value type responsible for:

- same-page and cross-page top-level reorder;
- app-to-app folder creation;
- moving an app into an existing folder;
- reordering apps inside a folder;
- moving an app out beside its folder;
- removing empty pages and dissolving undersized folders.

`LaunchpadDragPayload` carries only item identity and kind. `DropZone` and `LaunchpadDropIntent` convert pointer position into semantic operations. SwiftUI views produce those intents; they do not directly mutate page arrays.

`LaunchpadViewModel` resolves current item locations, applies one atomic layout mutation, updates observable state, clamps pagination, and persists once after a successful operation. It also coordinates loading, search, app launch, Finder/Info actions, uninstall, icon lookup, folder state, and reset.

### Data and Persistence

The preferred source is:

```text
~/Library/Application Support/Dock/desktopproperties.db
```

`LaunchpadDBDataSource` opens SQLite read-only. `LaunchpadDatabaseWatcher` coalesces database changes and reloads the shared view model.

If the database is missing or invalid, `ApplicationsFolderDataSource` scans:

```text
/Applications
~/Applications
/System/Applications
```

The fallback preserves immediate application directories as folders, deduplicates bundle identifiers, and derives stable IDs.

User organization is stored in a versioned file:

```text
~/Library/Application Support/OpenLaunchPad/layout.json
```

The schema stores ordered page IDs and full folder definitions. The decoder migrates unversioned folder layouts, legacy folder-name layouts, and the oldest raw page-ID format. Loading merges persisted placement with currently discovered apps so newly installed apps are not hidden.

Settings are stored in the `com.openlaunchpad` `UserDefaults` suite.

### Views and Interaction

Full-screen mode renders one page at a time. Users can navigate with page controls, horizontal wheel or trackpad input, Left/Right, or Command-Left/Command-Right. Popup mode flattens pages into one vertically scrolling grid. These modes intentionally avoid combining pagination and vertical scrolling on the same surface.

`AppGridLayout` computes a fitting column count from available width and icon size. Full-screen mode treats the configured column count as a preference and reduces it when necessary. Popup columns are always automatic, avoiding conflicts between icon size, column count, and panel width.

Gesture-based drag handling supplies a visible floating preview and target feedback. Leading/trailing target zones reorder; center zones create or add to folders. Expanded folders support internal reorder, rename, scrolling, and drag-out.

App context menus provide Open, Show in Finder, Get Info, and confirmed Uninstall. Protected system and current-app bundles cannot be uninstalled. A successful uninstall updates layout only after the bundle is moved to Trash.

`LaunchpadBackdropView` is shared by popup and full-screen surfaces. It normalizes the configured blur value and blends `NSVisualEffectView` material with mode-specific tinting. Both host windows are transparent and non-opaque so macOS can composite the material.

## Settings

| Setting | Default | Behavior |
|---|---:|---|
| Icon size | 80 pt | Shared icon scale; range 48-128 pt |
| Show labels | On | Reserves a consistent two-line label area |
| Full-screen columns | 7 | Preferred count; 0 selects automatic fitting |
| Popup width | 860 pt | Popup columns adapt automatically |
| Popup height | 620 pt | Controls the vertical viewport |
| Blur intensity | 20 | Applies to popup and full-screen backdrops |
| Show menu bar icon | On | Applies immediately |
| Dock click mode | Full Screen | Full Screen or Popup |
| Global shortcut | None | Registered immediately through Carbon |
| Animation speed | 1.0x | Scales launcher transitions |

## Extension Boundaries

- Add new data sources behind `AppDataSource` and compose them with `CompositeDataSource`.
- Add persistence implementations behind `LayoutStoring`; map through `StoredLayout` rather than exposing storage details to views.
- Add icon implementations behind `AppIconProviding`.
- Add system app operations through `ApplicationManager`, keeping workspace mutation in the view model.
- Add organization destinations by reusing `LaunchpadDragPayload`, drop intent, and `LaunchpadLayout` operations.
- Keep AppKit limited to lifecycle, windows, status items, shortcuts, system services, and visual-effect bridges.

## Decisions

1. Use SwiftUI for declarative UI and AppKit only where macOS lifecycle or window behavior requires it.
2. Treat Apple's Launchpad database as read-only source data.
3. Use system SQLite directly and avoid a database package dependency.
4. Use Observation's `@Observable` for shared state.
5. Use Carbon hardware key codes for a global shortcut without Accessibility permission.
6. Use a custom non-activating `NSPanel` instead of `MenuBarExtra` so left/right status-item clicks and cross-app behavior are controllable.
7. Use separate navigation models: pagination for full-screen and vertical scrolling for popup.
8. Keep organization rules in a pure mutation engine and render gesture feedback in reusable SwiftUI adapters.
9. Persist OpenLaunchPad state separately with a versioned, migratable schema.
10. Keep the full-screen window at normal level and dismiss it on app deactivation.

## Known Limits

- Local builds are unsigned; signing, notarization, release packaging, and auto-update are not configured.
- Page-edge drag navigation, nested folders, multi-select, and cross-window dragging are not implemented.
- SwiftUI gesture behavior still needs manual UX verification even though domain rules are unit tested.
- Legacy user folders cannot be recovered when macOS no longer provides the legacy Dock database.
- Uninstall moves only the app bundle to Trash and leaves user data intact.
- Multiple-monitor per-display layouts and iCloud layout sync are not implemented.
