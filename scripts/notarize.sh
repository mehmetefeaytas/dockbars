#!/bin/bash
# Build, sign (Developer ID), notarize and staple Dockbars for distribution.
#
# Prerequisites (you must provide these — they are not in the repo):
#   1. A "Developer ID Application" certificate in your login keychain.
#      Set DEV_ID to its identity, e.g.:
#        export DEV_ID="Developer ID Application: Your Name (TEAMID)"
#   2. A notarytool keychain profile created once with:
#        xcrun notarytool store-credentials dockbars-notary \
#          --apple-id "you@example.com" --team-id TEAMID \
#          --password "app-specific-password"
#
# Usage: DEV_ID="Developer ID Application: … (TEAMID)" ./scripts/notarize.sh
set -euo pipefail

: "${DEV_ID:?Set DEV_ID to your Developer ID Application identity}"
NOTARY_PROFILE="${NOTARY_PROFILE:-dockbars-notary}"
SCHEME="Dockbars"
BUILD_DIR="$(pwd)/build"
ARCHIVE="$BUILD_DIR/Dockbars.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

echo "▸ Generating project"
xcodegen generate

echo "▸ Archiving"
xcodebuild -project Dockbars.xcodeproj -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" archive \
  CODE_SIGN_IDENTITY="$DEV_ID" CODE_SIGN_STYLE=Manual

echo "▸ Exporting Developer ID app"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/Dockbars.app"
ZIP="$BUILD_DIR/Dockbars.zip"

echo "▸ Zipping for notarization"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling the ticket"
xcrun stapler staple "$APP"

echo "✓ Done. Notarized app at: $APP"
echo "  Verify with: spctl -a -vv \"$APP\""
