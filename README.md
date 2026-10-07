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

- **Full screen or popup:** a paginated grid over your blurred wallpaper, or a Liquid Glass popup from the menu bar or Dock.
- **Type to search** as soon as it opens; Return launches the top hit.
- **Frequently Used** apps up front.
- **Folders and drag-to-reorder**, saved across relaunches.
- **Configurable:** grid and icon size, backgrounds, appearance, animations, and a global shortcut.
- **Private:** no account, analytics, or telemetry.

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
    <td align="center"><strong>Popup</strong><br>Shown with the Wallpaper background; the default is Glass.</td>
    <td align="center"><strong>Folders</strong><br>Rename, reorder, and drag apps back out.</td>
  </tr>
</table>

## Install

Download `OpenLaunchPad-<version>.dmg` from [Releases](https://github.com/zanecola/OpenLaunchPad/releases/latest), open it, and drag **OpenLaunchPad** into **Applications**. Requires macOS 26 or newer on Apple silicon or Intel.

**First launch:** releases are not notarized, so macOS blocks the first open. Click **Done** on the warning, then **Open Anyway** in **System Settings > Privacy & Security**. Or clear the quarantine flag, but only for a copy from this repository's Releases page:

```bash
xattr -dr com.apple.quarantine /Applications/OpenLaunchPad.app
```

## Usage

| Do this | To |
|---|---|
| Click the Dock icon | Open full screen (or the popup, set in Settings); click again to close |
| Click the menu-bar icon | Toggle the popup; right-click for Settings, About, and Quit |
| Press your global shortcut | Toggle the launcher from any app (set one in Settings) |
| Click the gear, or press Command-comma | Open Settings |
| Type, then press Return | Search, then open the top result |
| Press Escape | Step back: cancel a rename, close a folder, clear search, then close |
| Swipe, scroll, or press Command-[ / Command-] | Turn pages in full screen |

To organize:

- Drag an app onto the edge of another to reorder, or onto its center to make a folder.
- Click an open folder's name to rename it; drag an app outside the folder to move it back.
- Right-click an app for **Open**, **Show in Finder**, **Get Info**, and **Uninstall…** (moves it to the Trash).

## Privacy

OpenLaunchPad makes no network requests and has no accounts or telemetry. Your layout is stored in `~/Library/Application Support/OpenLaunchPad/layout.json`, and settings and launch history (counts and last-launch times) in UserDefaults (`com.openlaunchpad`).

## Build from Source

Requires macOS 26 or newer and Xcode with the macOS 26 SDK.

```bash
swift test                    # run the tests
./script/build_and_run.sh     # build and launch a local .app
./script/build_dmg.sh 0.2.1   # universal, ad-hoc-signed DMG in dist/
```

## Contributing

Issues and pull requests are welcome. Keep layout rules in `LaunchpadLayout` and orchestration in `LaunchpadViewModel`, add focused tests, and run `swift test` before opening a pull request.

## License

OpenLaunchPad is available under the [MIT License](LICENSE).
