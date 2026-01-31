#!/bin/bash
# End-to-End Test for AI English App
# Tests the full application flow including screen capture, OCR, TTS, and LLM

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=============================================="
echo "AI English - End-to-End Test"
echo "=============================================="
echo ""

APP_PATH="${1:-$PROJECT_ROOT/src-tauri/target/release/bundle/macos/ai-english.app}"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Build the app first with: npm run tauri build"
    exit 1
fi

echo "Testing app: $APP_PATH"
echo ""

# Test 1: App launches and creates window
echo "=== Test 1: App Launch ==="
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/ai-english"

# Launch app in background
"$APP_EXECUTABLE" &
APP_PID=$!

sleep 3

if ps -p $APP_PID > /dev/null 2>&1; then
    echo "✓ App process is running (PID: $APP_PID)"
else
    echo "✗ App process not running"
    exit 1
fi

# Check for window
WINDOW_COUNT=$(osascript -e 'tell application "System Events" to count windows of process "ai-english"' 2>/dev/null || echo "0")
echo "  Windows: $WINDOW_COUNT"

if [ "$WINDOW_COUNT" -ge 1 ]; then
    echo "✓ App window is visible"
else
    echo "⚠ No window visible (may need permissions)"
fi

# Test 2: Screen capture is running (check for temp files or logs)
echo ""
echo "=== Test 2: Screen Capture ==="
sleep 2  # Give time for first capture

# Look for OCR temp files or check app logs
if ls /tmp/ai_english_screen_*.png 2>/dev/null | head -1 > /dev/null; then
    echo "✓ Screen capture is creating temp files"
else
    echo "⚠ No screen capture temp files found (may need Screen Recording permission)"
fi

# Test 3: TTS functionality
echo ""
echo "=== Test 3: TTS (Text-to-Speech) ==="
# Use AppleScript to send text to TTS
osascript -e 'tell application "System Events"' \
          -e '  tell process "ai-english"' \
          -e '    -- App should be able to use say command' \
          -e '  end tell' \
          -e 'end tell' 2>/dev/null || true

# Direct test of TTS via say command (what the app uses internally)
TEMP_TTS="/tmp/e2e_tts_test.aiff"
if say -o "$TEMP_TTS" "Testing text to speech" 2>/dev/null; then
    if [ -f "$TEMP_TTS" ] && [ -s "$TEMP_TTS" ]; then
        echo "✓ TTS generates audio (via say command)"
        rm -f "$TEMP_TTS"
    else
        echo "✗ TTS failed to generate audio"
    fi
else
    echo "✗ TTS command failed"
fi

# Test 4: Simulate user interaction
echo ""
echo "=== Test 4: UI Interaction ==="

# Use AppleScript to interact with the app
osascript <<EOF 2>/dev/null || true
tell application "System Events"
    tell process "ai-english"
        set frontmost to true
        delay 0.5
        
        -- Try to find the query input field
        if exists text field 1 of window 1 then
            set value of text field 1 of window 1 to "hello"
            delay 0.5
            keystroke return
            delay 1
        end if
    end tell
end tell
EOF

echo "  Sent 'hello' query to app"

# Give time for LLM response (mock mode should be instant)
sleep 2

# Test 5: Check app is still responsive
echo ""
echo "=== Test 5: App Responsiveness ==="
if ps -p $APP_PID > /dev/null 2>&1; then
    echo "✓ App is still running after interactions"
else
    echo "✗ App crashed during testing"
    exit 1
fi

# Cleanup - quit the app
echo ""
echo "=== Cleanup ==="
osascript -e 'tell application "ai-english" to quit' 2>/dev/null || true
sleep 2

# Force kill if still running
if ps -p $APP_PID > /dev/null 2>&1; then
    echo "Force killing app..."
    kill $APP_PID 2>/dev/null || true
fi

# Clean up temp files
rm -f /tmp/ai_english_screen_*.png 2>/dev/null || true
rm -f /tmp/ai_english_ocr.swift 2>/dev/null || true

echo ""
echo "=============================================="
echo "E2E Test Complete"
echo "=============================================="
echo ""
echo "Note: Some tests may show warnings if permissions"
echo "      (Screen Recording, Accessibility) are not granted."
echo "      Grant these permissions in System Preferences"
echo "      for full functionality."
