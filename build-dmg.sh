#!/bin/bash
set -euo pipefail

# build-dmg.sh — Build pipeline: build unsigned app, create DMG
#
# Usage: ./build-dmg.sh <version>
# Example: ./build-dmg.sh 1.0.0
#
# Prerequisites:
#   - Xcode 16.3+
#   - create-dmg (brew install create-dmg)

VERSION="${1:?Usage: ./build-dmg.sh <version>}"
APP_NAME="teil.ing-client"
SCHEME="teil.ing-client"
PROJECT="teil.ing-client.xcodeproj"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
BACKGROUND="Resources/dmg-background.png"
VOLICON="Resources/AppIcon.icns"

# Clean previous build artifacts
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> [1/2] Building..."
xcodebuild -project "${PROJECT}" \
           -scheme "${SCHEME}" \
           -configuration Release \
           -derivedDataPath "${DERIVED_DATA}" \
           -quiet \
           CODE_SIGN_IDENTITY=- \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

# Copy .app out of DerivedData
cp -R "${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app" "${APP_PATH}"

echo "==> [2/2] Creating DMG..."
create-dmg \
  --volname "teil.ing" \
  --volicon "${VOLICON}" \
  --background "${BACKGROUND}" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 130 185 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 410 185 \
  "${DMG_PATH}" \
  "${APP_PATH}"

echo ""
echo "==> Done! Packaged teil.ing v${VERSION}"
echo "    DMG: ${DMG_PATH}"
