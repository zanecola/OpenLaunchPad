# Drag-and-Drop Organization Design

## Goal

Make app and folder organization behave predictably across the paged launcher and expanded folder view. Users can reorder top-level items, create folders by combining apps, add apps to folders, and drag apps back out. Every accepted operation persists immediately and survives relaunch.

## Chosen Approach

Use one lightweight drag payload that identifies the dragged item, then resolve its current location in `LaunchpadViewModel` when a drop occurs. Keep all layout mutations in the view model and treat SwiftUI views as drop-intent producers.

This is preferred over extending the existing separate `AppItem` and `FolderItem` handlers because a unified payload supports apps from both top-level pages and folders without copying stale model values. A custom AppKit drag coordinator would provide finer pointer control, but it would add unnecessary complexity when SwiftUI's transferable and drop APIs can express these interactions.

## Interaction Rules

- Dragging a top-level app or folder to an insertion edge before or after another top-level item reorders it.
- Dropping an app in the center of another app creates a new folder at the target app's position. The target app is first and the dragged app is second.
- Dropping an app on an existing folder appends it to that folder unless it is already there.
- Dragging a folder over an app never creates a nested folder. It only reorders at the nearest insertion edge.
- Folders cannot be placed inside other folders.
- Apps inside the expanded folder are draggable and reorderable within that folder.
- Dropping a folder app on the expanded view's surrounding backdrop removes it from the folder and inserts it immediately after that folder on the folder's page.
- If removal leaves one app in a folder, the folder dissolves and the remaining app takes the folder's former position. The dragged-out app remains immediately after it.
- An empty folder is removed. In normal operation this can occur only while resolving a mutation.
- Drops that reference missing items, invalid pages, or the same source and destination are ignored safely.
- Search results are launch-only and do not accept organization drops, avoiding ambiguous placement into filtered results.

## Architecture

### Extension Boundaries

Keep the feature split into four reusable layers instead of growing a single drag-and-drop implementation:

- `LaunchpadLayout` is a pure value type that owns item lookup, reordering, folder membership, normalization, and invariants. It has no SwiftUI, AppKit, persistence, or icon-loading dependencies.
- `LaunchpadDropIntent` and `DropZone` translate pointer position plus source/target kinds into semantic operations. Their classification is deterministic and unit-testable.
- `LaunchpadViewModel` coordinates a domain mutation, publishes the resulting pages, persists once, and maintains selected-page and expanded-folder state.
- SwiftUI drag/drop views render feedback and forward payloads and intents. They do not directly edit arrays or encode folder rules.

New destinations, such as page-edge navigation or a dedicated organizer window, can reuse the same payload, intent, and layout operations without rewriting folder behavior. New persistence formats can map through stored DTOs without leaking storage concerns into the domain model.

### Drag Payload

Add a `LaunchpadDragPayload` transferable containing the item UUID and kind (`app` or `folder`). It carries identity, not a full app or folder snapshot. The view model determines whether an app currently lives on a page or inside a folder, which prevents stale drag data from overwriting newer state.

### Mutation API

Add focused view-model operations for these semantic intents:

- move a top-level item before or after another item;
- combine one app with a top-level app;
- move an app into a folder;
- reorder an app within a folder;
- remove an app from a folder to the containing page.

Each public operation validates all locations before mutation, changes the in-memory graph atomically, normalizes empty pages and undersized folders, persists once, and clamps the current page. Existing general movement behavior can delegate to the same helpers.

### Drop Surfaces

Each top-level icon cell becomes both draggable and a drop target. The target divides its width into leading insertion, center action, and trailing insertion zones. Center action creates or adds to folders only when the dragged item is an app; otherwise it resolves to the nearest reorder edge. Visible highlighting distinguishes center grouping from edge insertion.

The expanded folder's app cells accept app payloads for internal reordering. The backdrop around the folder accepts app payloads originating in that folder and performs drag-out. The folder panel itself does not treat an accidental drop in unused space as drag-out.

## Persistence

Evolve `StoredLayout` from page IDs plus folder names to page IDs plus complete stored folder definitions. Each definition contains the folder UUID, title, and ordered app UUIDs.

When loading:

1. Build an app registry from both top-level source apps and apps nested in source folders.
2. Reconstruct every persisted folder whose app IDs still resolve.
3. Resolve persisted page IDs against source top-level items and reconstructed folders.
4. Append newly discovered, unplaced source items to the last page.
5. Normalize persisted folders with fewer than two available apps.

The decoder remains compatible with the current `folderNames` format and the older raw `[[UUID]]` layout. Existing source folders retain their membership when no stored folder definition overrides them.

## Feedback and Failure Handling

Accepted drops animate through the existing page animation and persist immediately. Invalid or stale payloads return `false` from the drop handler and leave state unchanged. Persistence remains best-effort under the existing `LayoutStoring` protocol; this feature does not introduce user-facing storage errors or modify the system Launchpad database.

## Testing

View-model tests cover same-page and cross-page reordering, app-on-app folder creation, app-on-folder insertion, folder-internal reordering, drag-out placement, one-app auto-dissolution, empty-page cleanup, invalid payloads, and one-save-per-operation behavior.

Store tests cover round-tripping folder definitions and migration from both existing formats. Loading tests verify reconstruction, missing-app cleanup, and merging newly installed apps. Pure drop-zone classification tests verify leading, center, and trailing intent without requiring UI automation.

## Scope

This work does not add nested folders, multi-selection, dragging between launcher windows, drag-to-page-edge auto-navigation, or organization while search is active. Those behaviors are deliberately excluded to keep the interaction reliable and macOS-like.
