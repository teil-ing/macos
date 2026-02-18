#!/bin/bash
set -euo pipefail

# build-dmg.sh — Full build pipeline: archive, sign, notarize, staple, create DMG, GitHub Release
#
# Usage: ./build-dmg.sh <version>
# Example: ./build-dmg.sh 1.0.0
#
# Prerequisites:
#   - Xcode 16 with Developer ID Application certificate
#   - create-dmg (brew install create-dmg)
#   - gh CLI (brew install gh) — for GitHub Release creation
#   - notarytool credentials stored: xcrun notarytool store-credentials "notarytool-profile" ...
#
# Required GitHub Secrets (for CI use via release.yml):
#   DEVELOPER_ID_CERTIFICATE_BASE64  — Base64-encoded Developer ID Application .p12 from Keychain Access export
#   DEVELOPER_ID_CERTIFICATE_PASSWORD — Password used when exporting the .p12
#   CI_KEYCHAIN_PASSWORD             — Any strong random password (used only for temporary CI keychain)
#   NOTARIZATION_APPLE_ID            — Apple ID email for the developer account
#   NOTARIZATION_TEAM_ID             — 10-character Team ID (Apple Developer membership page)
#   NOTARIZATION_APP_PASSWORD        — App-specific password from appleid.apple.com
#
# Steps:
#   1. Archive with xcodebuild
#   2. Export signed .app with xcodebuild -exportArchive
#   3. Verify code signature
#   4. Notarize with xcrun notarytool submit --wait
#   5. Staple notarization ticket
#   6. Verify Gatekeeper acceptance
#   7. Create branded DMG with create-dmg
#   8. Create GitHub Release with DMG attached

VERSION="${1:?Usage: ./build-dmg.sh <version>}"
APP_NAME="teil.ing-client"
SCHEME="teil.ing-client"
PROJECT="teil.ing-client.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
BACKGROUND="Resources/dmg-background.png"
EXPORT_OPTIONS="ExportOptions.plist"

# Clean previous build artifacts
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> [1/8] Archiving..."
xcodebuild -project "${PROJECT}" \
           -scheme "${SCHEME}" \
           -configuration Release \
           -archivePath "${ARCHIVE_PATH}" \
           -quiet \
           archive

echo "==> [2/8] Exporting signed app..."
xcodebuild -exportArchive \
           -archivePath "${ARCHIVE_PATH}" \
           -exportPath "${EXPORT_PATH}" \
           -exportOptionsPlist "${EXPORT_OPTIONS}" \
           -quiet

echo "==> [3/8] Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "==> [4/8] Notarizing..."
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
xcrun notarytool submit "${ZIP_PATH}" \
      --keychain-profile "notarytool-profile" \
      --wait

echo "==> [5/8] Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

echo "==> [6/8] Verifying Gatekeeper acceptance..."
spctl -a -vvv -t install "${APP_PATH}"

echo "==> [7/8] Creating DMG..."
create-dmg \
  --volname "teil.ing" \
  --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
  --background "${BACKGROUND}" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 130 185 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 410 185 \
  "${DMG_PATH}" \
  "${EXPORT_PATH}/"

echo "==> [8/8] Creating GitHub Release..."
gh release create "v${VERSION}" \
  --title "teil.ing v${VERSION}" \
  --generate-notes \
  "${DMG_PATH}"

echo ""
echo "==> Done! Released teil.ing v${VERSION}"
echo "    DMG: ${DMG_PATH}"
echo "    Release: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/v${VERSION}"
