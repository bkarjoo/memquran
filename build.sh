#!/bin/bash

# Build script for MemQuran Swift app

set -e

echo "Building MemQuran macOS app..."

# Kill existing app instance
killall MemQuran 2>/dev/null || true

# Build using xcodebuild
xcodebuild -project MemQuran.xcodeproj \
    -scheme MemQuran \
    -configuration Debug \
    build

echo "Build complete!"
echo "Launching app..."

# Get the built app path from DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MemQuran-*/Build/Products/Debug/MemQuran.app -maxdepth 0 2>/dev/null | head -1)

# Run the app
if [ -n "$APP_PATH" ]; then
    open "$APP_PATH"
    echo "App launched from: $APP_PATH"
else
    echo "Error: Could not find built app"
    exit 1
fi
