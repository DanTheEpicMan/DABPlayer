#!/bin/bash
# DABPlayer Linux Build Script
# Ensure you have flutter and linux-specific dependencies installed:
# sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

echo "Building DABPlayer for Linux..."
flutter build linux
echo "Build complete. Output found in build/linux/x64/release/bundle/"
