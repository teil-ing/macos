#!/bin/bash
set -euo pipefail

# build-dmg.sh — Build, sign, create DMG, optionally notarize & staple
#
# Usage: ./build-dmg.sh <version>
#
# Environment:
#   CODE_SIGN_IDENTITY  — Signing identity (default: "Developer ID Application: Tillmann Hubner (5A7M476YY2)")
#                         Set to "-" for unsigned dev builds.
#   NOTARIZE            — Set to "1" to notarize and staple (default: 0)
#   ASC_KEY_ID          — App Store Connect API Key ID (required if NOTARIZE=1)
#   ASC_ISSUER_ID       — App Store Connect Issuer ID (required if NOTARIZE=1)
#   ASC_KEY_PATH        — Path to .p8 API key file (required if NOTARIZE=1)
#
# Prerequisites:
#   - Xcode 16.3+
#   - create-dmg (brew install create-dmg)
#   - Developer ID Application certificate in keychain (for signed builds)

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

IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: Tillmann Hubner (5A7M476YY2)}"
SHOULD_SIGN=true
if [ "${IDENTITY}" = "-" ]; then
    SHOULD_SIGN=false
fi

STEPS=4
if [ "${NOTARIZE:-0}" = "1" ]; then
    STEPS=6
    : "${ASC_KEY_ID:?ASC_KEY_ID required when NOTARIZE=1}"
    : "${ASC_ISSUER_ID:?ASC_ISSUER_ID required when NOTARIZE=1}"
    : "${ASC_KEY_PATH:?ASC_KEY_PATH required when NOTARIZE=1}"
fi

# Clean previous build artifacts
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 1: Build
echo "==> [1/${STEPS}] Building..."
if [ "${SHOULD_SIGN}" = true ]; then
    xcodebuild -project "${PROJECT}" \
               -scheme "${SCHEME}" \
               -configuration Release \
               -derivedDataPath "${DERIVED_DATA}" \
               -quiet \
               CODE_SIGN_STYLE=Manual \
               CODE_SIGN_IDENTITY="${IDENTITY}" \
               DEVELOPMENT_TEAM=5A7M476YY2 \
               CODE_SIGNING_REQUIRED=YES \
               CODE_SIGNING_ALLOWED=YES \
               OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"
else
    xcodebuild -project "${PROJECT}" \
               -scheme "${SCHEME}" \
               -configuration Release \
               -derivedDataPath "${DERIVED_DATA}" \
               -quiet \
               CODE_SIGN_IDENTITY=- \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO
fi

cp -R "${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app" "${APP_PATH}"

# Step 2: Verify signature
if [ "${SHOULD_SIGN}" = true ]; then
    echo "==> [2/${STEPS}] Verifying code signature..."
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
    echo "    Signature OK"
else
    echo "==> [2/${STEPS}] Skipping signature verification (unsigned build)"
fi

# Step 3: Create DMG
echo "==> [3/${STEPS}] Creating DMG..."
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

# Step 4: Sign DMG
if [ "${SHOULD_SIGN}" = true ]; then
    echo "==> [4/${STEPS}] Signing DMG..."
    codesign --force --sign "${IDENTITY}" --timestamp "${DMG_PATH}"
else
    echo "==> [4/${STEPS}] Skipping DMG signing (unsigned build)"
fi

# Step 5: Notarize
if [ "${NOTARIZE:-0}" = "1" ]; then
    echo "==> [5/${STEPS}] Submitting for notarization..."
    xcrun notarytool submit "${DMG_PATH}" \
        --key "${ASC_KEY_PATH}" \
        --key-id "${ASC_KEY_ID}" \
        --issuer "${ASC_ISSUER_ID}" \
        --wait \
        --timeout 900
fi

# Step 6: Staple
if [ "${NOTARIZE:-0}" = "1" ]; then
    echo "==> [6/${STEPS}] Stapling notarization ticket..."
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
fi

echo ""
echo "==> Done! Packaged teil.ing v${VERSION}"
echo "    DMG: ${DMG_PATH}"
if [ "${SHOULD_SIGN}" = true ]; then
    echo "    Signed with: ${IDENTITY}"
fi
if [ "${NOTARIZE:-0}" = "1" ]; then
    echo "    Notarized and stapled"
fi
