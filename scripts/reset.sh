#!/bin/bash
set -euo pipefail

echo "Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Squawk-*/

echo "Resetting user defaults..."
defaults delete com.squawk.Squawk 2>/dev/null || true

echo "Done. In Xcode:"
echo "  1. File → Packages → Resolve Package Versions"
echo "  2. ⌘R to rebuild"
