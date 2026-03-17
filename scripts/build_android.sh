#!/usr/bin/env bash
# Build DABPlayer for Android.
# Usage:
#   ./scripts/build_android.sh          # APK (debug-signed, sideload)
#   ./scripts/build_android.sh release  # APK + AAB (Play Store)

set -e
cd "$(dirname "$0")/.."

MODE="${1:-debug}"

echo "==> flutter pub get"
flutter pub get

if [ "$MODE" = "release" ]; then
  echo "==> Building release APK..."
  flutter build apk --release
  echo "    Output: build/app/outputs/flutter-apk/app-release.apk"

  echo "==> Building release AAB (Play Store bundle)..."
  flutter build appbundle --release
  echo "    Output: build/app/outputs/bundle/release/app-release.aab"
else
  echo "==> Building debug APK (sideload)..."
  flutter build apk --debug
  echo "    Output: build/app/outputs/flutter-apk/app-debug.apk"
fi

echo "==> Done!"
