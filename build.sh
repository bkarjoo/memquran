#!/bin/bash

# Build script for MemQuran Swift app

set -e

echo "Building MemQuran macOS app..."

# Build using xcodebuild
xcodebuild -project MemQuran.xcodeproj \
    -scheme MemQuran \
    -configuration Release \
    -derivedDataPath build \
    build

echo "Build complete!"
echo "Launching app..."

# Run the app
open build/Build/Products/Release/MemQuran.app
