#!/bin/bash
set -euo pipefail

SCHEME="Squawk"
PROJECT="Squawk/Squawk.xcodeproj"
ARCHIVE_PATH="build/Squawk.xcarchive"
EXPORT_PATH="build/export"

echo "Building archive..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO

echo "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

echo "Build complete: $EXPORT_PATH/Squawk.app"
