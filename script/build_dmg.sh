#!/usr/bin/env bash
# Builds dist/OpenLaunchPad.app, ad-hoc signs it, and packages it into a
# downloadable dist/OpenLaunchPad-<version>.dmg with a drag-to-Applications
# layout. The DMG is unsigned (no Developer ID), so macOS Gatekeeper will
# prompt users the first time — see README for the one-time bypass.
set -euo pipefail

APP_NAME="OpenLaunchPad"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

# Version: explicit arg/env wins, else git tag, else 0.0.0.
VERSION="${1:-${VERSION:-$(git -C "$ROOT_DIR" describe --tags --always 2>/dev/null || echo 0.0.0)}}"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

APP_VERSION="$VERSION" bash "$(dirname "${BASH_SOURCE[0]}")/stage_bundle.sh"

# Ad-hoc sign so the bundle has a stable signature structure (not a Developer
# ID — Gatekeeper still warns on first launch).
codesign --force --deep --sign - "$APP_BUNDLE"

# Assemble a staging folder with the app and an Applications symlink.
STAGING="$DIST_DIR/.dmg-staging"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create a read-only DMG from the staging folder.
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" \
    -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING"
echo "Created $DMG_PATH"
