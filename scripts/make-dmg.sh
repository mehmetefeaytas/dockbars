#!/bin/bash
# Build a signed Release .app and package it into a drag-to-install DMG.
#
# Signing: uses your "Apple Development" identity by default (set SIGN_ID to
# override, e.g. a "Developer ID Application" identity for a notarizable build).
# Without a Developer ID + notarization, Gatekeeper shows a warning on first
# open — users right-click the app and choose Open (see the README).
#
# Usage: ./scripts/make-dmg.sh   (or SIGN_ID="Developer ID Application: … (TEAM)" ./scripts/make-dmg.sh)
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
SIGN_ID="${SIGN_ID:-Apple Development: Mehmet Efe Ayta (3CF5VQ9QUD)}"
DD="build/dd"
APP="$DD/Build/Products/Release/Dockbars.app"
STAGE="build/dmg-stage"
DMG="build/Dockbars-$VERSION.dmg"

echo "▸ Generating project"
xcodegen generate

echo "▸ Building Release (ad-hoc), then re-signing"
xcodebuild -project Dockbars.xcodeproj -scheme Dockbars -configuration Release \
  -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build >/dev/null

codesign --deep --force --options runtime --timestamp \
  --entitlements Dockbars/App/Dockbars.entitlements -s "$SIGN_ID" "$APP"
codesign -dv "$APP" 2>&1 | grep -E "Authority=Apple|TeamIdentifier" | head -2

echo "▸ Packaging DMG"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Dockbars" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "✓ DMG ready: $DMG"
ls -lh "$DMG"
