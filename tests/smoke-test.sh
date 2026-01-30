#!/bin/bash
# E2E smoke test for AI English app
# This script tests that the app launches and basic functionality works

set -e

APP_PATH="${1:-src-tauri/target/release/bundle/macos/ai-english.app}"

echo "=== AI English E2E Smoke Test ==="

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    exit 1
fi

echo "✓ App bundle exists"

# Check app structure
if [ ! -f "$APP_PATH/Contents/MacOS/ai-english" ]; then
    echo "ERROR: Main executable not found"
    exit 1
fi
echo "✓ Main executable exists"

if [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "ERROR: Info.plist not found"
    exit 1
fi
echo "✓ Info.plist exists"

# Check code signature
if codesign -v "$APP_PATH" 2>/dev/null; then
    echo "✓ App is code signed"
else
    echo "⚠ App is not properly signed (expected for CI builds)"
fi

# Try to launch app in background and check it starts
echo "Launching app..."
open -a "$APP_PATH" &
APP_PID=$!

# Wait a moment for app to start
sleep 3

# Check if process is running
if pgrep -f "ai-english" > /dev/null; then
    echo "✓ App process is running"
    
    # Get window info
    if command -v osascript &> /dev/null; then
        WINDOW_COUNT=$(osascript -e 'tell application "System Events" to count windows of process "ai-english"' 2>/dev/null || echo "0")
        echo "  Window count: $WINDOW_COUNT"
    fi
else
    echo "ERROR: App process not found"
    exit 1
fi

# Cleanup - quit the app
if command -v osascript &> /dev/null; then
    osascript -e 'tell application "ai-english" to quit' 2>/dev/null || true
fi

# Wait for quit
sleep 2

# Verify it quit
if pgrep -f "ai-english" > /dev/null; then
    echo "⚠ App still running, force killing..."
    pkill -f "ai-english" || true
fi

echo ""
echo "=== Smoke Test Passed ==="
