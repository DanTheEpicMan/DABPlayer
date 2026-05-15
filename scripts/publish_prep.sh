#!/bin/bash
# DABPlayer Production Preparation Script
# This helps automate the tedious parts of release preparation.

echo "--- Release Prep ---"

# 1. Check for icon
if [ ! -f "assets/logo.png" ]; then
    echo "Warning: assets/logo.png not found. Default Flutter icon will be used."
else
    echo "Generating Launcher Icons..."
    flutter pub run flutter_launcher_icons
fi

# 2. Check for keystore
if [ ! -f "android/key.properties" ]; then
    echo "Error: android/key.properties not found."
    echo "Please follow the GOOGLE_PLAY_PUBLISHING.md guide to set up app signing."
    exit 1
fi

# 3. Clean and build
echo "Cleaning old builds..."
flutter clean
flutter pub get

echo "Building Release APK (Fat APK) for side-loading..."
flutter build apk --release

echo "Done! Upload this file to your GitHub Release:"
echo "build/app/outputs/flutter-apk/app-release.apk"
