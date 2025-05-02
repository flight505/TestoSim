#!/bin/bash
# TestoSim test launcher - uses a single simulator instance
# Usage: ./launch-test.sh [device_name]
# Example: ./launch-test.sh "iPhone 16"

set -o pipefail

# Default device if not specified
DEFAULT_DEVICE="iPhone 16"
DEVICE="${1:-$DEFAULT_DEVICE}"

echo "📱 Using device: $DEVICE"

# Check for any running simulators first
RUNNING_SIMS=$(xcrun simctl list devices | grep -i "booted" | wc -l)
if [ $RUNNING_SIMS -gt 0 ]; then
    echo "⚠️ Found running simulators. Shutting them down first..."
    xcrun simctl shutdown all
    sleep 2
fi

# Boot the specific simulator
echo "🚀 Booting simulator: $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || echo "ℹ️ Device may already be booted"

# Build the app
echo "🔨 Building TestoSim..."
xcodebuild -project TestoSim.xcodeproj -scheme TestoSim -destination "platform=iOS Simulator,name=$DEVICE" build | xcbeautify

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Exiting."
    exit 1
fi

# Install and launch
echo "📲 Installing and launching app..."
APP_PATH=$(find ${HOME}/Library/Developer/Xcode/DerivedData/TestoSim-*/Build/Products/Debug-iphonesimulator -name "TestoSim.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app. Path may be different."
    exit 1
fi

xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl launch "$DEVICE" "$(defaults read "$APP_PATH/Info" CFBundleIdentifier)"

echo "✅ App launched in a single simulator instance."
echo "📝 To close all simulators when done, run: ./close-simulators.sh" 