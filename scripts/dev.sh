#!/bin/bash
set -euo pipefail

SCHEME="Squawk"
PROJECT="Squawk/Squawk.xcodeproj"

echo "Building Squawk (Debug)..."

if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        build | xcbeautify
else
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        build
fi

echo "Build complete."
