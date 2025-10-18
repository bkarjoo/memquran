#!/bin/bash

# Script to add AudioPlayer.swift and AudioMemorizationView.swift to Xcode project
# This uses xcodebuild and pbxproj manipulation

echo "Adding AudioPlayer.swift and AudioMemorizationView.swift to Xcode project..."

# Check if files exist
if [ ! -f "MemQuran/AudioPlayer.swift" ]; then
    echo "Error: AudioPlayer.swift not found"
    exit 1
fi

if [ ! -f "MemQuran/AudioMemorizationView.swift" ]; then
    echo "Error: AudioMemorizationView.swift not found"
    exit 1
fi

echo "Files found. Please add them to Xcode manually:"
echo ""
echo "1. Open MemQuran.xcodeproj in Xcode"
echo "2. Right-click on the MemQuran folder in the project navigator"
echo "3. Select 'Add Files to MemQuran...'"
echo "4. Navigate to and select:"
echo "   - AudioPlayer.swift"
echo "   - AudioMemorizationView.swift"
echo "5. Make sure these options are checked:"
echo "   ✓ Copy items if needed (should be unchecked since files are already there)"
echo "   ✓ Create groups"
echo "   ✓ Add to targets: MemQuran iOS, MemQuran macOS, MemQuran visionOS, MemQuran tvOS"
echo "6. Click 'Add'"
echo ""
echo "Alternatively, you can drag the files from Finder directly into the MemQuran folder in Xcode."