#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ClaudeUsageWidgetApp"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="io.github.sergei-matheson.claudeusagewidget.extension"
INSTALL_DIR="/Applications"

echo "==> Checking prerequisites..."

if ! command -v xcodegen &>/dev/null; then
  echo "Error: xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  echo "Error: Xcode command-line tools not found. Run: xcode-select --install" >&2
  exit 1
fi

cd "$(dirname "$0")"

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Building ${APP_NAME}..."
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

xcodebuild build \
  -project ClaudeUsageWidget.xcodeproj \
  -scheme "${APP_NAME}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -quiet

APP_SRC=$(find "$BUILD_DIR/Build/Products" -name "${APP_BUNDLE}" -maxdepth 3 | head -1)

if [[ -z "$APP_SRC" ]]; then
  echo "Error: Built app not found in derived data." >&2
  exit 1
fi

echo "==> Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
cp -R "$APP_SRC" "${INSTALL_DIR}/"

echo "==> Clearing quarantine..."
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_BUNDLE}"

echo "==> Registering widget extension..."
pluginkit -e use -i "$BUNDLE_ID"

echo ""
echo "Done. Open ${INSTALL_DIR}/${APP_BUNDLE} to enter your session token."
