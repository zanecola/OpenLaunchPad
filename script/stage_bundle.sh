#!/usr/bin/env bash
# Builds the OpenLaunchPad executable and stages it into a .app bundle at
# dist/OpenLaunchPad.app. Shared by build_and_run.sh (local dev) and
# build_dmg.sh (release packaging) so both ship the identical bundle layout.
# APP_VERSION sets the bundle version (default 0.0.0 for local builds).
set -euo pipefail

APP_NAME="OpenLaunchPad"
BUNDLE_ID="com.openlaunchpad"
MIN_SYSTEM_VERSION="26.0"

# Bundle versions must be numeric (1.2.3). Labels of unreleased builds, such as
# git describe's "v0.1.0-3-gabc1234" or CI's "0.0.0-abc1234", become 0.0.0.
BUNDLE_VERSION="${APP_VERSION:-0.0.0}"
BUNDLE_VERSION="${BUNDLE_VERSION#v}"
if [[ ! "$BUNDLE_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    BUNDLE_VERSION="0.0.0"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Sources/OpenLaunchPad/Resources/AppIcon.icns"

# Stop any running instance so the staged binary can be replaced cleanly.
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

env HOME="$ROOT_DIR/.build" \
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" \
    swift build
BUILD_DIR="$(env HOME="$ROOT_DIR/.build" \
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" \
    swift build --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$BUNDLE_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUNDLE_VERSION</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleAllowMixedLocalizations</key>
  <true/>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Staged bundle at $APP_BUNDLE"
