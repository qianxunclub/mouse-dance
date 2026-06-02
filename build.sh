#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR/MouseDance.xcodeproj" ]]; then
  ROOT_DIR="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/../MouseDance.xcodeproj" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/MouseDance.xcodeproj}"
SCHEME="${SCHEME:-MouseDance}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_ROOT/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
STAGING_DIR="$BUILD_ROOT/dmg-staging"
TEMP_DMG_PATH="$BUILD_ROOT/${SCHEME}-temp.dmg"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

read_build_setting() {
  local key="$1"
  echo "$BUILD_SETTINGS" | awk -F ' = ' -v target_key="$key" '
    {
      current_key = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key)
      if (current_key == target_key) {
        print $2
        exit
      }
    }
  '
}

require_command xcodebuild
require_command hdiutil

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Xcode project not found: $PROJECT_PATH" >&2
  exit 1
fi

echo "Reading build settings..."
BUILD_SETTINGS="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings
)"

PRODUCT_NAME="$(read_build_setting PRODUCT_NAME)"
FULL_PRODUCT_NAME="$(read_build_setting FULL_PRODUCT_NAME)"
WRAPPER_NAME="$(read_build_setting WRAPPER_NAME)"
MARKETING_VERSION="$(read_build_setting MARKETING_VERSION)"
CURRENT_PROJECT_VERSION="$(read_build_setting CURRENT_PROJECT_VERSION)"

if [[ -z "$PRODUCT_NAME" ]]; then
  echo "Unable to resolve PRODUCT_NAME from xcodebuild settings." >&2
  exit 1
fi

if [[ -z "$MARKETING_VERSION" ]]; then
  MARKETING_VERSION="2026.6.2"
fi

if [[ -z "$CURRENT_PROJECT_VERSION" ]]; then
  CURRENT_PROJECT_VERSION="0"
fi

APP_NAME="$FULL_PRODUCT_NAME"
if [[ -z "$APP_NAME" ]]; then
  APP_NAME="$WRAPPER_NAME"
fi
if [[ -z "$APP_NAME" ]]; then
  APP_NAME="${PRODUCT_NAME}.app"
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
DMG_NAME="${PRODUCT_NAME}-${MARKETING_VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="${DMG_VOLUME_NAME:-${PRODUCT_NAME} ${MARKETING_VERSION}}"

echo "Cleaning previous artifacts..."
rm -rf "$DERIVED_DATA_PATH" "$STAGING_DIR"
rm -f "$TEMP_DMG_PATH" "$DMG_PATH"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  clean build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app was not found: $APP_PATH" >&2
  exit 1
fi

echo "Preparing DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating writable DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$TEMP_DMG_PATH"

echo "Compressing DMG..."
hdiutil convert \
  "$TEMP_DMG_PATH" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

rm -f "$TEMP_DMG_PATH"
rm -rf "$STAGING_DIR"

echo
echo "DMG created successfully."
echo "Version: $MARKETING_VERSION ($CURRENT_PROJECT_VERSION)"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo
echo "Tips:"
echo "- Default build disables code signing for local packaging."
echo "- Use CODE_SIGNING_ALLOWED=YES if you want to package a signed app."
