#!/bin/bash
set -euo pipefail

# build-dmg.sh — Build pipeline: archive, export, create DMG
#
# Usage: ./build-dmg.sh <version>
# Example: ./build-dmg.sh 1.0.0
#
# Prerequisites:
#   - Xcode 16
#   - create-dmg (brew install create-dmg)

VERSION="${1:?Usage: ./build-dmg.sh <version>}"
APP_NAME="teil.ing-client"
SCHEME="teil.ing-client"
PROJECT="teil.ing-client.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
BACKGROUND="Resources/dmg-background.png"
EXPORT_OPTIONS="ExportOptions.plist"

# Clean previous build artifacts
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> [1/3] Archiving..."
xcodebuild -project "${PROJECT}" \
           -scheme "${SCHEME}" \
           -configuration Release \
           -archivePath "${ARCHIVE_PATH}" \
           -quiet \
           archive

echo "==> [2/3] Exporting app..."
xcodebuild -exportArchive \
           -archivePath "${ARCHIVE_PATH}" \
           -exportPath "${EXPORT_PATH}" \
           -exportOptionsPlist "${EXPORT_OPTIONS}" \
           -quiet

echo "==> [3/3] Creating DMG..."
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

echo ""
echo "==> Done! Packaged teil.ing v${VERSION}"
echo "    DMG: ${DMG_PATH}"
