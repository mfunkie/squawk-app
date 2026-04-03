#!/bin/bash
set -euo pipefail

APP_PATH="build/export/Squawk.app"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-squawk-notarize}"

echo "Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "build/Squawk.zip"

echo "Submitting for notarization..."
xcrun notarytool submit "build/Squawk.zip" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "Stapling ticket..."
xcrun stapler staple "$APP_PATH"

echo "Notarization complete!"
