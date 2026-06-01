#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_NAME="ClaudeUsageWidget"
APP_NAME="ClaudeUsageWidgetApp"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "==> Removing DerivedData for ${PROJECT_NAME}..."
find "$DERIVED_DATA" -maxdepth 1 -name "${PROJECT_NAME}-*" -o -name "${APP_NAME}-*" | \
  while read -r dir; do
    echo "    rm -rf $dir"
    rm -rf "$dir"
  done

echo "==> Removing local build/ and DerivedData/ directories..."
rm -rf build/ DerivedData/

echo ""
echo "Done. Run ./test.sh or ./install.sh to rebuild."
