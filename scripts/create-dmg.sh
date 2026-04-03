#!/bin/bash
set -euo pipefail

APP_PATH="build/export/Squawk.app"
DMG_PATH="build/Squawk.dmg"
VOLUME_NAME="Squawk"

# Using create-dmg (install: brew install create-dmg)
create-dmg \
    --volname "$VOLUME_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Squawk.app" 175 190 \
    --hide-extension "Squawk.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

echo "DMG created: $DMG_PATH"
