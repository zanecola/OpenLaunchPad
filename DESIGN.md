# OpenLaunchPad — Design Document

> macOS 26+ replacement for the removed Launchpad.  
> Last updated: 2026-05-22

---

## Requirements

| # | Requirement |
|---|-------------|
| 1 | Read existing Launchpad SQLite DB and respect its icon ordering |
| 2 | Full folder support (expand in-place, apps inside folders) |
| 3 | Search bar at top |
| 4 | Dock icon + menu bar icon (independent activation modes) |
| 5 | Liquid Glass visuals, follow system dark/light theme |
| 6 | Highly configurable: icon size, pane size, blur, shortcuts, menu bar toggle |
| 7 | Drag-to-rearrange, paginated grid |
| 8 | SwiftUI |

---

## Architecture Overview

Three-layer: **Data → ViewModel → Views**, with AppKit handling window/panel lifecycle at the edges.

```
┌─────────────────────────────────────────────────────┐
│  Activation                                         │
│  ┌─────────────┐   ┌────────────────────────────┐  │
│  │ Dock click  │   │ Menu bar icon click         │  │
│  │ (full-screen│   │ (always popup panel)        │  │
│  │  or popup)  │   │                             │  │
│  └──────┬──────┘   └──────────────┬──────────────┘  │
│         │ Global hotkey (Carbon)  │                  │
└─────────┼─────────────────────────┼─────────────────┘
          ▼                         ▼
┌─────────────────────────────────────────────────────┐
│  Window Layer (AppKit)                              │
│  FullScreenWindow (NSWindow)  PopupPanel (NSPanel)  │
│  NSHostingController wraps SwiftUI views            │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────┐
│  SwiftUI Views                                      │
│  LaunchpadView ─── AppGridView ─── AppIconView      │
│       │                 │               │           │
│  SearchBarView   PageIndicatorView  FolderView       │
│  MenuBarPanelView (compact variant)                 │
│  SettingsView                                       │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────┐
│  ViewModel                                          │
│  LaunchpadViewModel (@Observable)                   │
│  - pages: [[LaunchpadItem]]                         │
│  - searchQuery: String                              │
│  - expandedFolderID: UUID?                          │
│  - isEditMode: Bool                                 │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────┐
│  Data Layer                                         │
│  LaunchpadDB (SQLite3) ── AppIconLoader ── ConfigStore│
└─────────────────────────────────────────────────────┘
```

---

## Project File Structure

```
OpenLaunchPad/
├── OpenLaunchPadApp.swift          # @main SwiftUI App entry point
├── AppDelegate.swift               # NSApplicationDelegate: dock, hotkey, menu bar
│
├── Data/
│   ├── LaunchpadDB.swift           # Read-only SQLite reader for Dock DB
│   ├── AppIconLoader.swift         # Load NSImage icons from bundle ID
│   └── ConfigStore.swift           # ObservableObject, all settings via UserDefaults
│
├── Models/
│   ├── LaunchpadItem.swift         # enum: .app(AppItem) | .folder(FolderItem)
│   └── Settings.swift              # Typed settings struct (icon size, blur, etc.)
│
├── ViewModel/
│   └── LaunchpadViewModel.swift    # @Observable central state
│
├── Views/
│   ├── LaunchpadView.swift         # Full-screen root (blur backdrop + grid)
│   ├── MenuBarPanelView.swift      # Compact popup for menu bar activation
│   ├── AppGridView.swift           # Paginated SwiftUI grid
│   ├── AppIconView.swift           # Single icon cell (label, wiggle in edit mode)
│   ├── FolderView.swift            # Folder cell + expanded overlay
│   ├── SearchBarView.swift         # Top search field
│   └── PageIndicatorView.swift     # Dot row at bottom
│
├── Windows/
│   ├── FullScreenWindow.swift      # NSWindow subclass (covers full screen, no chrome)
│   └── PopupPanel.swift            # NSPanel: used for both dock-popup and menu bar
│
└── Settings/
    └── SettingsView.swift          # Preferences window (all ConfigStore knobs)
```

---

## Key Data Model

### Launchpad SQLite DB

**Path:** `~/Library/Application Support/Dock/desktopproperties.db`

| Table | Key Columns | Notes |
|-------|-------------|-------|
| `items` | `ROWID`, `uuid`, `type`, `parent_id`, `ordering` | type: 1=app, 2=page, 3=folder, 4=root |
| `apps` | `item_id`, `title`, `bundleid` | Maps item to app bundle |
| `groups` | `item_id`, `title` | Folder display name |

**Read strategy:** Open read-only with `SQLITE_OPEN_READONLY`. `LaunchpadDatabaseWatcher` observes writes, renames, and deletes with `DispatchSource`, debounces rapid SQLite events, and reloads through the shared view model. It reopens the event source when the database file is replaced.

### App Models

```swift
enum LaunchpadItem: Identifiable {
    case app(AppItem)
    case folder(FolderItem)
}

struct AppItem: Identifiable {
    let id: UUID
    let bundleID: String
    let title: String
    var icon: NSImage?
    var ordering: Int
}

struct FolderItem: Identifiable {
    let id: UUID
    let title: String
    var items: [AppItem]
    var ordering: Int
}
```

### Custom Layout Override

When user drags to rearrange, the new order is written to:
`~/Library/Application Support/OpenLaunchPad/layout.json`

On startup: merge Launchpad DB order (source of truth for app existence) with layout.json overrides (source of truth for user ordering). New apps from DB that aren't in layout.json get appended to last page.

---

## Settings (ConfigStore)

All backed by `UserDefaults` under suite `com.openlaunchpad`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `iconSize` | CGFloat | 80 | App icon size in points (48–128) |
| `iconLabelVisible` | Bool | true | Show app name below icon |
| `gridColumns` | Int | 7 | Columns per page (0 = auto-fit) |
| `paneWidth` | CGFloat | 800 | Popup mode width |
| `paneHeight` | CGFloat | 600 | Popup mode height |
| `backgroundBlur` | CGFloat | 20 | Blur radius for full-screen backdrop |
| `showMenuBarIcon` | Bool | true | Toggle menu bar icon visibility |
| `dockClickMode` | Enum | .fullScreen | fullScreen or .popup |
| `globalShortcut` | KeyCombo | nil | User-set global hotkey |
| `animationSpeed` | CGFloat | 1.0 | Scale for all transition durations |
| Theme | System | n/a | Materials and text follow the active macOS appearance |

---

## Architectural Decisions

### ADR-1: SwiftUI + AppKit Hybrid
**Decision:** Pure SwiftUI for all UI. AppKit only for `NSWindow`/`NSPanel` lifecycle.  
**Why:** SwiftUI handles all the layout, animation, and theming. AppKit is unavoidable for borderless overlay windows and `NSPanel` popup behavior. The full-screen window stays at normal level, remains on the active Space, and dismisses when the app resigns active so it never traps the user above other applications.

### ADR-2: Read Launchpad DB, Never Write It
**Decision:** Open `desktopproperties.db` as read-only. Persist custom ordering in a separate JSON file.  
**Why:** Modifying the Dock DB risks corrupting the system Dock. The DB schema is undocumented and may be absent on macOS 26. Keeping a separate layout store avoids this risk entirely. When the database is unavailable, the fallback scans application roots, preserves immediate app directories as folders, deduplicates bundle IDs, and assigns stable IDs.

### ADR-3: SQLite3 C API Directly (No External Dependency)
**Decision:** Use the system `SQLite3` C library via Swift's bridging header. No SQLite.swift or GRDB.  
**Why:** The DB access pattern is simple (two reads on startup + file watch). An external dependency for this is overkill. Keeping zero Swift Package Manager dependencies for the DB layer reduces supply-chain surface.

### ADR-4: @Observable (Swift 5.9+ Observation Framework)
**Decision:** Use `@Observable` macro on `LaunchpadViewModel`, `ConfigStore`.  
**Why:** macOS 26 targets Swift 5.9+. `@Observable` is more efficient than `ObservableObject` + `@Published` (no per-property publishers, no AnyPublisher overhead). No need for Combine.

### ADR-5: Carbon RegisterEventHotKey for Global Shortcut
**Decision:** Capture shortcuts through a focused `NSButton` bridge that reads `NSEvent.keyCode`, then register the resulting `KeyCombo` with Carbon's `RegisterEventHotKey` API. Changes are persisted and re-registered immediately.  
**Why:** Carbon requires hardware key codes that SwiftUI's higher-level key events do not reliably expose. The narrow AppKit bridge keeps SwiftUI as the settings source of truth while avoiding Accessibility entitlements and third-party dependencies.

### ADR-6: Liquid Glass via glassBackgroundEffect()
**Decision:** Use SwiftUI's `.glassBackgroundEffect()` (macOS 26) for panels and folder overlays. Use `NSVisualEffectView` (`.underWindowBackground` material) for the full-screen backdrop with configurable blur.  
**Why:** `.glassBackgroundEffect()` automatically adapts to dark/light and gives the correct macOS 26 Liquid Glass look. The full-screen backdrop needs `NSVisualEffectView` because SwiftUI's glass modifiers apply to foreground elements, not window-covering backgrounds.

### ADR-7: Custom macOS Pagination
**Decision:** Full-screen mode renders one page with custom page controls, `Command-Left` / `Command-Right`, drag gestures, and a window-scoped horizontal scroll monitor. The menu-bar popup flattens all pages into one vertically scrolling grid.  
**Why:** SwiftUI's `.page` tab style is unavailable on macOS, and combining vertical scrolling with pagination creates conflicting navigation. Each activation surface now uses one primary navigation model suited to its available space.

### ADR-8: Drag-to-Rearrange via onDrag/onDrop
**Decision:** Use SwiftUI `onDrag` / `onDrop` with `NSItemProvider` carrying the item UUID.  
**Why:** Native SwiftUI DnD. Sufficient for icon rearranging. More complex approaches (custom gesture + geometry readers) are needed only if SwiftUI DnD proves insufficient for cross-page drag — defer that complexity.

### ADR-9: MenuBarExtra WindowMenuBarExtraStyle
**Decision:** Use SwiftUI `MenuBarExtra` with `WindowMenuBarExtraStyle`.  
**Why:** Native popover-style panel anchored to menu bar icon. Toggle visibility of the entire `MenuBarExtra` based on `showMenuBarIcon` setting.

Dock popup mode remains separate from `MenuBarExtra`: `applicationShouldHandleReopen` captures the Dock click's mouse location and positions an opaque `PopupPanel` beside that point, clamped to the visible screen and current Dock edge.

### ADR-10: Folder Expand In-Place (Classic Style)
**Decision:** Folder tap opens an overlay within the current view (not navigation push). Same animation as classic Launchpad — folder expands to reveal a floating grid.  
**Why:** Matches user muscle memory from macOS Launchpad. Navigation push would feel wrong for this pattern.

---

## Out of Scope for v1

- Writing layout back to the Dock DB
- App deletion / uninstall
- App download progress badges
- iCloud sync of layout
- Spotlight / semantic search
- Widgets or non-app items
- Multiple monitor per-display pages

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Dock DB schema changes across macOS updates | Version-check on DB read; fail gracefully by falling back to `/Applications` scan |
| Sandbox restrictions on DB read | Ship as non-sandboxed (needed for DB access + global hotkey); no App Store distribution in v1 |
| `.glassBackgroundEffect()` API availability | Guard with `#available(macOS 26, *)` — the app targets macOS 26 only, so this is a compile-time guarantee |
