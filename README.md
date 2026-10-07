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

![OpenLaunchPad full-screen launcher](assets/screenshots/full-screen.png)

Apple removed the classic Launchpad experience from macOS 26. OpenLaunchPad brings back the parts that made it useful while adding a compact popup, configurable layouts, persistent folders, and familiar macOS controls.

## Highlights

- **Two ways to launch.** Use a paginated full-screen grid or a non-activating popup from the menu bar or Dock.
- **Recent favorites up front.** Apps launched most often through OpenLaunchPad appear in a responsive first row, with recent use breaking frequency ties.
- **Organize naturally.** Drag to reorder, drop apps together to create folders, rename folders, reorder inside them, and drag apps back out.
- **Fast navigation.** Type to search the moment it opens and press Return to launch the top hit, or page with gestures, page controls, or the keyboard.
- **Native macOS behavior.** System app icons, materials, context menus, Finder integration, Get Info, and Move to Trash all feel at home.
- **Make it yours.** Configure icon size (automatic or custom), labels, the full-screen grid of columns and rows, the page control, whether full screen hides the menu bar and Dock, popup size, appearance (System, Light or Dark), background and hover effect, the full-screen background (your blurred wallpaper, glass, or solid) with its blur and dim, animations and their speed, where Frequently Used appears, Dock behavior, and a global shortcut.
- **Private by design.** No account, analytics, telemetry, or cloud service. Layout data stays on your Mac.

## Gallery

<table>
  <tr>
    <td width="50%">
      <img src="assets/screenshots/popup.png" alt="OpenLaunchPad compact popup">
    </td>
    <td width="50%">
      <img src="assets/screenshots/folders.png" alt="OpenLaunchPad expanded folder">
    </td>
  </tr>
  <tr>
    <td align="center"><strong>Compact popup</strong><br>Open without leaving the app you are using.</td>
    <td align="center"><strong>Folders</strong><br>Group, rename, reorder, and drag apps back out.</td>
  </tr>
</table>

Screenshots were rendered from the SwiftUI views with curated macOS system apps shortly after v0.1.0, so they predate the current search bar, folder tiles, open folders, and blurred background.

## Install

### Download a release

1. Download `OpenLaunchPad-<version>.dmg` from [GitHub Releases](https://github.com/zanecola/OpenLaunchPad/releases/latest).
2. Open the DMG and drag **OpenLaunchPad** into **Applications**.
3. Open OpenLaunchPad from Applications.

### First launch on macOS

Current releases are ad-hoc signed, not notarized with an Apple Developer ID, so Gatekeeper blocks the first launch. Control-clicking the app and choosing **Open** no longer gets past it on current macOS. Instead:

1. Open OpenLaunchPad from Applications. When macOS says it can't verify the app, click **Done**.
2. Go to **System Settings > Privacy & Security**, scroll to **Security**, and click **Open Anyway** next to the message about OpenLaunchPad. The button stays there for about an hour after the blocked launch.
3. Confirm with **Open Anyway** and your password or Touch ID. macOS remembers this, so later launches open normally.

As a Terminal alternative:

```bash
xattr -dr com.apple.quarantine /Applications/OpenLaunchPad.app
```

Only use the command for a copy downloaded from this repository's official Releases page.

## Requirements

- macOS 26.0 or newer, on an Apple silicon or Intel Mac (releases after v0.1.0 are universal; v0.1.0 runs on Apple silicon only)
- Runs unsandboxed: it reads every Applications folder, including `~/Applications`, and moves apps you uninstall to the Trash

Building from source additionally requires Xcode with the macOS 26 SDK and SwiftPM.

## Using OpenLaunchPad

### Open the launcher

| Action | Result |
|---|---|
| Click the Dock icon | Opens full-screen or popup mode, depending on Settings; click again to close it |
| Left-click the menu-bar icon | Toggles the compact popup below the icon |
| Right-click the menu-bar icon | Shows Settings, About, and Quit |
| Press your configured global shortcut | Toggles the launcher from any app |
| Click the gear (top-right corner in full screen) | Opens Settings |

Launching an app automatically closes OpenLaunchPad so it stays out of your way. Closing it without launching anything returns you to the app you were using.

Both launchers are built once when OpenLaunchPad starts and kept ready, so opening one only brings it on screen. Each open still starts fresh: Search has focus, no folder is open, no alert or drag is left over from last time, and the popup is scrolled back to the top. Full screen reopens on the page you left.

### Navigate

- Start typing as soon as the launcher opens: Search already has focus, in the popup too. It ignores case and accents, and finds apps by the name Finder shows, their bundle name, or their file name, including apps inside folders. Exact and prefix matches come first, then apps you use most. Folders whose name matches are listed after the apps.
- **Frequently Used** shows the apps you open most often. In the popup it is a row lined up with the grid's columns, under a small "Frequently Used" header, and it scrolls away with the grid. In full screen it is a compact shelf of up to nine smaller icons below Search, without labels (hover an icon to see its name); full screen leaves it out when your apps would not fit beside it. The order is set each time the launcher opens, so icons don't move while you use it. Show it in both places, the popup only, or nowhere, and clear its local history, under **Settings > General > Suggestions**.
- In full screen, swipe sideways with two fingers on a trackpad (or one on a Magic Mouse) over the apps: the pages follow your fingers and settle on the nearest page, and one flick turns one page. A mouse wheel turns one page per notch, up and down or sideways, anywhere on the screen. Left/Right (while Search is empty), Command-[ / Command-] and a click on a page dot turn pages too. The page dots are bare, as in Launchpad, and the white one moves with the pages; choose **Dots + Arrows** in Settings to get previous and next arrows when you point at them.
- Scroll vertically in popup mode.
- Click an app or folder to open it. It darkens and shrinks slightly while you hold the button down and opens when you let go. A press that moves 8 pt or more opens nothing: it starts a drag instead, or, where an icon can't be dragged, it is ignored like a slipped click. Rest the pointer on an icon to see its full name in a tooltip. In the popup, the app under the pointer is highlighted; full screen has no hover effect, as in Launchpad.
- A folder opens out of its icon and closes back into it, while the page behind blurs and dims; with Reduce Motion on it fades in and out. Its name is above it. Close it with Escape or a click outside it; the popup also gives it a close button. A folder with more than three rows of apps has pages in full screen, which you swipe or turn with its dots or the mouse wheel, and scrolls in the popup.
- Press Return to open the top search result.
- Press Escape to step back one level: cancel renaming a folder, close an open folder, then clear the search, then close the launcher.
- Click empty space, including the space between icons, to close an open folder or the full-screen launcher.
- With VoiceOver, every app and folder is a button named after it, and folders also say how many apps they hold. The page dots are one control that says which page you are on ("Page, 2 of 3"); increase or decrease it to turn pages.

### Organize apps

- Drag to the left or right edge of another icon to reorder. Dropping onto a full page moves that page's last app to the start of the next page.
- Drop an app onto the center of another app to create a folder.
- Drop an app onto an existing folder to add it.
- Open a folder and drag apps to reorder them.
- Drag an app outside the expanded folder to move it back to the launcher.
- Click an open folder's name to rename it. The name is selected for you; Return saves it, Escape cancels, and closing the folder saves it too.

Changes are saved immediately and survive relaunches. Search results are launch-only, so filtering cannot accidentally change your layout.

### App context menu

Right-click an app for:

- Open
- Show in Finder
- Get Info (opens Finder's info window; no Automation permission needed)
- Uninstall… (moves the copy of the app that the tile shows to the Trash, after a confirmation that shows its path)

OpenLaunchPad protects system apps and every copy of itself from uninstall. Moving an app to Trash does not remove that app's documents or support files.

If an app was moved or deleted since OpenLaunchPad last looked, opening it says the app can't be found and offers **Remove from Layout**, instead of failing silently.

### Settings

Open Settings from the gear, the menu-bar icon's right-click menu, or Command-comma. Its General, Appearance, and Shortcuts tabs sit in the toolbar, and the window resizes to fit each one. Changes apply immediately.

| Setting | Default | Notes |
|---|---|---|
| Dock icon click action | Full Screen | Or Popup |
| Show menu bar icon | On | |
| Frequently Used | Popup and Full Screen | Or Popup Only, or Off. An earlier on/off choice is kept: on becomes Popup and Full Screen. **Clear Usage History** erases the launch history behind it |
| Reset Layout… | | Removes all folders and custom order after you confirm; the old layout is backed up first (see [Data and Privacy](#data-and-privacy)) |
| Icon size | Automatic | Automatic sizes full-screen icons to fill the grid, up to 144 pt, and keeps the popup at 80 pt. Custom is 48–160 pt for both; full screen draws it smaller, down to 48 pt, only where the grid has no room for it. A size set in an earlier version becomes Custom |
| Show app labels | On | |
| Columns × rows | 7 × 5 | Full screen; 4–12 columns and 4–7 rows. Each page holds columns × rows apps, and the rows spread evenly between Search and the page dots. Until you arrange your apps they fill the pages in name order, so a change refills every page. Once you have arranged them, fewer slots move the apps that no longer fit onto the next pages, and more slots leave your pages as they are. Automatic columns from an earlier version become 7, and columns set in an earlier version, when every page held 35 apps, get the fewest rows that hold 35 (4 rows for 9–12 columns) |
| Page control | Dots | Bare dots, as in Launchpad, or **Dots + Arrows**, which adds previous and next arrows while you point at the dots |
| Hide menu bar and Dock while open | Off | Full screen. Off, the grid is laid out between the menu bar and the Dock. On, both hide while full screen is open and the grid uses the whole screen; move the pointer to the screen edge to show them. macOS lets an app hide the menu bar only together with the Dock, so there is no menu-bar-only choice. An earlier "Auto-hide both" choice is kept |
| Popup appearance | System | Or Light or Dark. Full screen is always dark, like Launchpad |
| Popup background | Wallpaper | The part of your blurred desktop picture that lies under the popup, as if it were frosted glass over the desktop, lightened in Light and darkened in Dark so its text stays readable; it stays with Reduce Transparency on, and it uses the Blur radius below. Windows behind the popup don't show through it. Or **Glass**, the popup's earlier look, or **Solid**. When the picture can't be read, Wallpaper uses Glass |
| Popup hover effect | Highlight | A soft rounded highlight behind the app under the pointer, or **None**, or **Lift**, which makes it grow slightly (not with Reduce Motion on). Full screen has no hover effect, as in Launchpad |
| Popup width and height | 860 × 620 pt | Popup columns adapt automatically |
| Full-screen background | Wallpaper | Your desktop picture, blurred and dimmed, as Launchpad drew it; it stays with Reduce Transparency on. Or **Glass**, which blurs the windows behind full screen and becomes solid dark with Reduce Transparency, or **Solid**. When the picture can't be read, Wallpaper uses Glass, or solid dark with Reduce Transparency. An Aerial shows a still frame of its video. The popup has its own Popup background setting |
| Blur radius | 48 pt | 0–80 pt, for Wallpaper, in full screen and the popup |
| Dim | 25% | 0–60% black over the wallpaper or glass; Solid is not dimmed |
| Animate transitions | On | Full screen fades in as its icons settle from slightly larger, as in Launchpad, and fades out as they grow; the popup grows from the menu-bar icon or the Dock. Folders grow out of their icon and shrink back into it. Launching an app only fades the launcher, and pages slide when the keyboard, a dot or the wheel turns them. Off makes all of these instant. With Reduce Motion on, the launcher and folders fade without zooming, those page turns are instant, and a pressed app only darkens. Swiped pages always follow your fingers |
| Animation speed | 1.0× | 0.5–2.0×; higher is faster |
| Global shortcut | None | Must use Command or Control, or be a function key (F1–F12), so it can't capture ordinary typing. A Shift- or Option-only shortcut saved by an older version is cleared |

## Data and Privacy

OpenLaunchPad builds its app list by scanning `/Applications`, `~/Applications`, and `/System/Applications`. Apps use the same localized names as Finder and are sorted by name. Filesystem folders that hold two or more apps are preserved, and duplicate bundle identifiers are removed. These folders are watched, so newly installed or removed apps show up within about a second without restarting OpenLaunchPad, and an updated app shows its new icon.

It does not import your old Launchpad layout or folders. It first looks for a Dock database at `~/Library/Application Support/Dock/desktopproperties.db` and reads it read-only if one exists, but that file does not exist on macOS 26, so in practice the scan is the only source. OpenLaunchPad never writes to Apple's Dock database.

Your custom pages, folders, and ordering are stored separately:

```text
~/Library/Application Support/OpenLaunchPad/layout.json
```

Reset Layout in Settings asks first and saves the current layout to the `Backups` folder next to `layout.json`. The 10 most recent backups are kept. A `layout.json` that OpenLaunchPad cannot read, for example one written by a newer version, is also moved there instead of being overwritten.

To draw the wallpaper background, OpenLaunchPad reads your desktop picture and, for an Aerial, the wallpaper settings in `~/Library/Application Support/com.apple.wallpaper` and the downloaded Aerial in `/Library/Application Support/com.apple.idleassetsd`. It only reads them, and keeps the blurred image in memory.

Settings and frequently used app history are stored locally in the `com.openlaunchpad` UserDefaults suite. Usage history contains only bundle IDs, launch counts, and last-launch timestamps for apps opened through OpenLaunchPad. There are no network services, accounts, analytics, or telemetry.

## Build from Source

Clone and enter the repository:

```bash
git clone https://github.com/zanecola/OpenLaunchPad.git
cd OpenLaunchPad
```

Run the test suite:

```bash
swift test
```

Build a local `.app` bundle and launch it:

```bash
./script/build_and_run.sh --verify
```

Create an ad-hoc-signed DMG from a universal (Apple silicon and Intel) release build:

```bash
./script/build_dmg.sh 0.2.0
```

The version becomes the app's bundle version, shown in About. Local builds without a release version report 0.0.0.

Generated artifacts are written to `dist/`.

If SwiftPM cache permissions are restricted, use workspace-local paths:

```bash
env HOME="$PWD/.build" CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test
```

## Architecture

OpenLaunchPad is a SwiftUI and AppKit application with deliberately small boundaries:

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

- `LaunchpadLayout` owns deterministic page and folder mutations.
- `LaunchpadViewModel` coordinates state, persistence, icons, and app actions.
- SwiftUI views render full-screen, popup, folder, drag, search, and Settings experiences.
- AppKit handles windows, the status item, system services, and the Carbon global hotkey.
- JSON persistence is versioned and migrates earlier layout formats.

The test suite covers layout invariants, persistence migrations and backups, data sources and the folder watcher, view-model orchestration, search ranking, settings and shortcut validation, the animation rules and how a show cancels a closing launcher, popup placement, paging input, drag state, app actions, full-screen and folder layout fitting, how a folder zooms out of its tile and is renamed, how a click on a tile is told apart from a drag and how pressed and hovered tiles are drawn, and how the wallpaper background is found, cached for each display, and lined up under the popup.

## Known Limitations

- Releases are not yet Developer ID signed or notarized.
- Dragging to a page edge does not automatically switch pages yet.
- A trackpad swipe turns pages only over the apps, not over Search, the Frequently Used shelf or the page dots.
- Giving pages more slots does not pull apps back onto pages you have arranged, so pages arranged for a smaller grid keep their free slots until you rearrange them.
- Your old Launchpad layout and folders are not imported yet.
- Uninstall moves only the app bundle to Trash; user data remains in place.
- Per-display layouts and iCloud sync are not implemented.
- The wallpaper background approximates some wallpapers: an Aerial shows the first frame of its video, not necessarily the frame on your desktop (or the Aerial a shuffle picked); a built-in dynamic wallpaper shows a small thumbnail; and the picture always fills the screen, whatever its fit setting. A wallpaper changed while the launcher is closed fades in just after the next open. The popup's wallpaper shows the desktop picture alone, not the windows behind the popup, and while the popup grows in, its picture grows with it, settling into line with the desktop as it finishes.

## Contributing

Issues and pull requests are welcome. Before opening a pull request:

1. Describe the user-facing behavior and any macOS-specific tradeoffs.
2. Keep layout rules in `LaunchpadLayout`, orchestration in `LaunchpadViewModel`, reusable interaction in `Views`, and lifecycle behavior in `App` or `Windows`.
3. Add focused tests for deterministic behavior.
4. Run `swift test` and `./script/build_and_run.sh --verify`.

CI runs `swift build` and `swift test` on every push and pull request, and a release is built only after the tests pass.

Please use [GitHub Issues](https://github.com/zanecola/OpenLaunchPad/issues) for bugs and feature proposals.

## License

OpenLaunchPad is available under the [MIT License](LICENSE).
