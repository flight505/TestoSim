#!/bin/bash
# TestoSim build script - avoids launching multiple simulators
# Usage: ./build-test.sh [clean]

set -o pipefail

# Default simulator device
DEVICE="iPhone 16,OS=18.4"

# Check if xcbeautify is installed
if ! command -v xcbeautify &> /dev/null; then
    echo "xcbeautify not found. Installing..."
    brew install xcbeautify
fi

# Check if we need to clean
if [ "$1" == "clean" ]; then
    echo "Cleaning build..."
    xcodebuild -project TestoSim.xcodeproj -scheme TestoSim -destination "platform=iOS Simulator,name=$DEVICE" clean | xcbeautify
fi

# Build only, don't run
echo "Building TestoSim..."
xcodebuild -project TestoSim.xcodeproj -scheme TestoSim -destination "platform=iOS Simulator,name=$DEVICE" build | xcbeautify

# Check build status
if [ $? -eq 0 ]; then
    echo "✅ Build succeeded. Use SweetPad to run in simulator."
    echo ""
    echo "To run in SweetPad:"
    echo "1. Open VS Code with SweetPad extension"
    echo "2. Run task 'SweetPad: Build' from command palette or context menu"
    echo ""
    echo "This avoids launching multiple simulators."
else
    echo "❌ Build failed."
fi 