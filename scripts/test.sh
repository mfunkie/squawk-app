#!/bin/bash
set -euo pipefail

SCHEME="Squawk"
PROJECT="Squawk/Squawk.xcodeproj"

echo "Running tests..."
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS'
