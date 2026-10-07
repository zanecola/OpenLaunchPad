<div align="center">

# OpenLaunchPad

**A native, open-source Launchpad replacement for macOS 26.**

Search, launch, group, and rearrange your apps from a full-screen grid or a compact menu-bar popup.

[![Latest release](https://img.shields.io/github/v/release/zanecola/OpenLaunchPad?display_name=tag&style=flat-square)](https://github.com/zanecola/OpenLaunchPad/releases/latest)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111111?style=flat-square&logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)
[![MIT License](https://img.shields.io/badge/license-MIT-2ea44f?style=flat-square)](LICENSE)

[Download the latest release](https://github.com/zanecola/OpenLaunchPad/releases/latest) | [Build from source](#build-from-source) | [Report an issue](https://github.com/zanecola/OpenLaunchPad/issues)

</div>

![OpenLaunchPad in full screen: a search field, a Frequently Used shelf and a seven-by-five grid of macOS apps over the blurred desktop picture](assets/screenshots/full-screen.png)

Apple removed the classic Launchpad from macOS 26. OpenLaunchPad brings it back and adds a compact popup, configurable layouts, and persistent folders.

## Highlights

- **Two ways to launch:** a paginated full-screen grid, or a Liquid Glass popup from the menu bar or Dock.
- **Type to search** as soon as it opens; Return launches the top hit.
- **Frequently Used** apps up front.
- **Folders and drag-to-reorder**, saved across relaunches.
- **Native feel:** system icons, materials, context menus, and Finder integration.
- **Configurable:** grid and icon size, backgrounds, appearance, animations, a global shortcut, and more.
- **Private:** no account, analytics, or telemetry. Your layout stays on your Mac.

## Gallery

<table>
  <tr>
    <td width="50%">
      <img src="assets/screenshots/popup.png" alt="The OpenLaunchPad popup under the menu bar in Dark appearance, with Frequently Used above All Apps, over a frosted crop of the desktop picture">
    </td>
    <td width="50%">
      <img src="assets/screenshots/folders.png" alt="The Productivity folder open in full screen, its name above the panel, over the blurred and dimmed grid">
    </td>
  </tr>
  <tr>
    <td align="center"><strong>Compact popup</strong><br>Launch from the menu bar without leaving your current app.</td>
    <td align="center"><strong>Folders</strong><br>Rename, reorder, and drag apps back out.</td>
  </tr>
</table>

The popup is shown with its **Wallpaper** background; its default is Liquid Glass.

## Install

1. Download `OpenLaunchPad-<version>.dmg` from [GitHub Releases](https://github.com/zanecola/OpenLaunchPad/releases/latest).
2. Open the DMG and drag **OpenLaunchPad** into **Applications**.
3. Open it from Applications.

### First launch

Releases are ad-hoc signed and not notarized, so Gatekeeper blocks the first launch. Control-click > **Open** no longer works around this. Instead:

1. Open the app and click **Done** on the warning.
2. In **System Settings > Privacy & Security**, click **Open Anyway** next to OpenLaunchPad (it is shown for about an hour), then confirm.

Or, only for a copy from this repository's Releases page:

```bash
xattr -dr com.apple.quarantine /Applications/OpenLaunchPad.app
```

### Requirements

- macOS 26 or newer, Apple silicon or Intel (v0.1.0 is Apple silicon only).
- Runs unsandboxed so it can read every Applications folder and move apps you uninstall to the Trash.

## Usage

| Action | Result |
|---|---|
| Click the Dock icon | Opens full screen or the popup (set in Settings); click again to close |
| Click the menu-bar icon | Toggles the popup; right-click for Settings, About, and Quit |
| Global shortcut | Toggles the launcher from any app |
| Type | Searches app names, including apps inside folders |
| Return | Opens the top result |
| Escape | Steps back: cancels a rename, closes the folder, clears the search, closes the launcher |
| Swipe, mouse wheel, page dots, Command-[ / Command-], or Left/Right with Search empty | Turns pages in full screen |
| Click empty space | Closes an open folder, or full screen |

Each open starts with Search focused. Launching an app closes the launcher; closing it without launching returns you to the previous app.

### Organize apps

- Drag onto the edge of an icon to reorder, onto its center to make a folder, or onto a folder to add to it.
- In an open folder, drag to reorder, or drag an app outside to move it back.
- Click an open folder's name to rename it. Return saves, Escape cancels, and closing the folder saves.
- Right-click an app for **Open**, **Show in Finder**, **Get Info**, and **Uninstall…**. Uninstall moves the app to the Trash after confirming, and leaves its documents and support files in place. System apps and OpenLaunchPad itself are protected.

Changes save immediately. Search results can't be rearranged, so filtering never changes your layout.

### Settings

Open Settings from the gear in full screen, the menu-bar icon's right-click menu, or Command-comma. Changes apply immediately.

| Setting | Default | Options |
|---|---|---|
| Dock icon click action | Full Screen | Popup |
| Show menu bar icon | On | |
| Frequently Used | Popup and Full Screen | Popup Only, Off; Clear Usage History |
| Icon size | Automatic | Custom, 48–160 pt |
| Show app labels | On | |
| Columns × rows | 7 × 5 | 4–12 columns, 4–7 rows (full screen) |
| Page control | Dots | Dots + Arrows |
| Hide menu bar and Dock while open | Off | Full screen only; macOS hides both together |
| Popup appearance | System | Light, Dark; full screen is always dark |
| Popup background | Glass | Wallpaper, Solid |
| Popup hover effect | Highlight | None, Lift |
| Popup width and height | 860 × 620 pt | |
| Full-screen background | Wallpaper | Glass, Solid |
| Blur radius | 48 pt | 0–80 pt, for Wallpaper |
| Dim | 25% | 0–60% |
| Animate transitions | On | |
| Animation speed | 1.0× | 0.5–2.0× |
| Global shortcut | None | Must use Command or Control, or F1–F12 |
| Reset Layout… | | Removes folders and custom order, after backing up the layout |

## Data and Privacy

OpenLaunchPad scans `/Applications`, `~/Applications`, and `/System/Applications`, and picks up installed or removed apps within about a second. It does not import your old Launchpad layout and never writes to Apple's Dock database.

Your layout is stored in `~/Library/Application Support/OpenLaunchPad/layout.json`. Reset Layout backs it up to a `Backups` folder beside it first (the 10 most recent are kept), and a `layout.json` it can't read is moved there instead of being overwritten.

Settings and launch history (bundle IDs, launch counts, last-launch times) are stored in the `com.openlaunchpad` UserDefaults suite. The wallpaper background only reads your desktop picture and wallpaper settings. There are no network services.

## Build from Source

Requires Xcode with the macOS 26 SDK.

```bash
git clone https://github.com/zanecola/OpenLaunchPad.git
cd OpenLaunchPad
swift test                          # run the tests
./script/build_and_run.sh --verify  # build and launch a local .app
./script/build_dmg.sh 0.2.0         # universal, ad-hoc-signed DMG in dist/
```

If SwiftPM cache permissions are restricted, prefix commands with `env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"`.

## Architecture

```text
Applications folders, scanned and watched
(a legacy Dock database first, if present)
                    |
                    v
            CompositeDataSource
                    |
                    v
          LaunchpadViewModel
           /              \
          v                v
 LaunchpadLayout      SwiftUI views
 (pure mutations)          |
                          v
              AppKit windows and status item
```

- `LaunchpadLayout`: deterministic page and folder mutations.
- `LaunchpadViewModel`: state, persistence, icons, and app actions.
- SwiftUI views: full screen, popup, folders, search, and Settings.
- AppKit: windows, the status item, system services, and the global hotkey.

## Known Limitations

- Not Developer ID signed or notarized.
- Dragging to a page edge doesn't switch pages yet.
- Trackpad swipes turn pages only over the app grid.
- Adding grid slots doesn't pull apps back onto pages you have already arranged.
- Your old Launchpad layout isn't imported.
- No per-display layouts or iCloud sync.
- The wallpaper background approximates Aerials and dynamic wallpapers, and the popup's version doesn't show the windows behind it.
- With Reduce Transparency on, the popup's Glass is opaque; choose **Wallpaper** to keep a frosted look.

## Contributing

Issues and pull requests are welcome. Please describe the user-facing behavior, keep layout rules in `LaunchpadLayout` and orchestration in `LaunchpadViewModel`, add focused tests, and run `swift test` and `./script/build_and_run.sh --verify`. CI runs `swift build` and `swift test` on every push and pull request.

## License

OpenLaunchPad is available under the [MIT License](LICENSE).
