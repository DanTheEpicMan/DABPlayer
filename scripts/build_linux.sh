#!/usr/bin/env bash
# Build DABPlayer for Linux desktop.
# Usage: ./scripts/build_linux.sh

set -e
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> Building Linux release..."
flutter build linux --release

echo "==> Done!"
echo "    Output: build/linux/x64/release/bundle/"
echo "    Run with: ./build/linux/x64/release/bundle/dabplayer"
