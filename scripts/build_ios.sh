#!/usr/bin/env bash
# Build DABPlayer for iOS (unsigned, for simulator or manual signing).
# Usage: ./scripts/build_ios.sh

set -e
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> Building iOS (no codesign)..."
flutter build ios --release --no-codesign

echo "==> Done!"
echo "    Output: build/ios/iphoneos/Runner.app"
echo ""
echo "    To install on device, open ios/Runner.xcworkspace in Xcode,"
echo "    set your team/signing, and run from there."
