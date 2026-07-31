#!/usr/bin/env bash
#
# MouseDance 打包脚本：构建 App 并生成 DMG。
#
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
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

# 脚本退出（含失败/中断）时清理临时目录，避免残留
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

validate_xcode_environment() {
  local developer_dir=""
  local detected_xcode_dir=""

  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    detected_xcode_dir="/Applications/Xcode.app/Contents/Developer"
  else
    local candidate=""
    for candidate in /Applications/Xcode*.app/Contents/Developer; do
      if [[ -d "$candidate" ]]; then
        detected_xcode_dir="$candidate"
        break
      fi
    done
  fi

  developer_dir="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"

  if [[ -z "$developer_dir" ]]; then
    echo "Unable to determine the active Xcode developer directory." >&2
    echo "Install Xcode and select it before running this script." >&2
    exit 1
  fi

  if [[ "$developer_dir" == "/Library/Developer/CommandLineTools" ]]; then
    if [[ -n "$detected_xcode_dir" ]]; then
      echo "Active developer directory points to CommandLineTools; using Xcode instead:" >&2
      echo "  $detected_xcode_dir" >&2
      developer_dir="$detected_xcode_dir"
    else
      echo "This script requires the full Xcode app, but the active developer directory is:" >&2
      echo "  $developer_dir" >&2
      echo >&2
      echo "Install Xcode, then run one of the following commands:" >&2
      echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
      echo "  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer $0" >&2
      echo "If your app has a different name, replace Xcode.app with that app name." >&2
      exit 1
    fi
  fi

  # 统一导出，确保后续所有 xcodebuild 调用使用同一套工具链
  export DEVELOPER_DIR="$developer_dir"

  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is installed but not usable with the current developer directory:" >&2
    echo "  $developer_dir" >&2
    echo "Check your Xcode installation or set DEVELOPER_DIR to a valid Xcode path." >&2
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

require_command xcode-select
require_command xcodebuild
require_command hdiutil
validate_xcode_environment

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

# 打包后的 App 和 DMG 固定命名，避免产物名随版本变化
APP_NAME="MouseDance.app"
DMG_NAME="MouseDance.dmg"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="${DMG_VOLUME_NAME:-MouseDance}"

echo "Cleaning previous artifacts..."
rm -rf "$DERIVED_DATA_PATH"
rm -f "$DMG_PATH"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

echo "Building $APP_NAME ($CONFIGURATION)..."
# 派生数据目录已整体清空，无需再执行 xcodebuild clean
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app was not found: $APP_PATH" >&2
  exit 1
fi

echo "Preparing DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
# 直接从目录生成 UDZO 压缩镜像，省略中间可写镜像与二次转换
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

echo
echo "DMG created successfully."
echo "Version: $MARKETING_VERSION ($CURRENT_PROJECT_VERSION)"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo
echo "Tips:"
echo "- Default build disables code signing for local packaging."
echo "- Use CODE_SIGNING_ALLOWED=YES if you want to package a signed app."
