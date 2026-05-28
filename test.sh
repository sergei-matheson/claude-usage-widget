#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Running tests..."
xcodebuild test \
  -project ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidgetTests \
  -destination 'platform=macOS' \
  ${1:+-only-testing:"$1"} | xcbeautify
