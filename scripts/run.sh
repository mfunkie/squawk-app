#!/bin/bash
set -euo pipefail

SCHEME="Squawk"
PROJECT="Squawk/Squawk.xcodeproj"

echo "Building Squawk (Debug)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    build

APP_PATH=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ *BUILT_PRODUCTS_DIR/ {print $2; exit}')

APP="$APP_PATH/Squawk.app"

if [ ! -d "$APP" ]; then
    echo "Could not find built app at $APP"
    exit 1
fi

echo "Killing any running instance..."
pkill -x Squawk || true

echo "Launching $APP"
open "$APP"
