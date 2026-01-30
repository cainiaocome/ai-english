#!/bin/bash
# Integration Test Runner
# Runs all integration tests for AI English app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=============================================="
echo "AI English - Integration Test Suite"
echo "=============================================="
echo ""
echo "Project root: $PROJECT_ROOT"
echo "Date: $(date)"
echo "macOS Version: $(sw_vers -productVersion 2>/dev/null || echo 'N/A')"
echo ""

cd "$PROJECT_ROOT"

PASSED=0
FAILED=0
SKIPPED=0

# Function to run a test and track results
run_test() {
    local name="$1"
    local command="$2"
    
    echo ""
    echo "----------------------------------------------"
    echo "Running: $name"
    echo "----------------------------------------------"
    
    if eval "$command"; then
        echo ""
        echo "→ $name: PASSED"
        ((PASSED++))
        return 0
    else
        echo ""
        echo "→ $name: FAILED"
        ((FAILED++))
        return 1
    fi
}

# Function to skip a test
skip_test() {
    local name="$1"
    local reason="$2"
    
    echo ""
    echo "----------------------------------------------"
    echo "Skipping: $name"
    echo "Reason: $reason"
    echo "----------------------------------------------"
    ((SKIPPED++))
}

# ============================================
# Test 1: Rust Engine Tests
# ============================================
run_test "Rust Engine Tests" "cargo test -p ai-english-engine --all-features 2>&1" || true

# ============================================
# Test 2: OCR Integration Test (Vision Framework)
# ============================================
if [[ "$(uname)" == "Darwin" ]]; then
    run_test "OCR Integration Test" "swift ${SCRIPT_DIR}/ocr_test.swift 2>&1" || true
else
    skip_test "OCR Integration Test" "Requires macOS"
fi

# ============================================
# Test 3: Screen Capture Test
# ============================================
if [[ "$(uname)" == "Darwin" ]]; then
    run_test "Screen Capture Test" "swift ${SCRIPT_DIR}/screen_capture_test.swift 2>&1" || true
else
    skip_test "Screen Capture Test" "Requires macOS"
fi

# ============================================
# Test 4: Audio Transcription Test
# ============================================
if [[ "$(uname)" == "Darwin" ]]; then
    # Check if we should run the full audio test (it downloads whisper.cpp)
    if [[ "${RUN_AUDIO_TEST:-false}" == "true" ]]; then
        chmod +x "${SCRIPT_DIR}/audio_test.sh"
        run_test "Audio Transcription Test" "${SCRIPT_DIR}/audio_test.sh 2>&1" || true
    else
        skip_test "Audio Transcription Test" "Set RUN_AUDIO_TEST=true to enable (downloads ~150MB)"
    fi
else
    skip_test "Audio Transcription Test" "Requires macOS"
fi

# ============================================
# Test 5: Swift Plugin Build Test
# ============================================
if [[ "$(uname)" == "Darwin" ]]; then
    run_test "Swift Plugin Build" "cd ${PROJECT_ROOT}/macos-plugin && swift build 2>&1" || true
else
    skip_test "Swift Plugin Build" "Requires macOS"
fi

# ============================================
# Test 6: TTS Integration Test
# ============================================
if [[ "$(uname)" == "Darwin" ]]; then
    echo ""
    echo "----------------------------------------------"
    echo "Running: TTS Integration Test"
    echo "----------------------------------------------"
    
    # Test that 'say' command works (used for TTS)
    if command -v say &> /dev/null; then
        # Generate speech to a file (doesn't require audio output)
        TEMP_TTS="/tmp/tts_test_$$.aiff"
        if say -o "$TEMP_TTS" "Testing text to speech" 2>/dev/null; then
            if [ -f "$TEMP_TTS" ] && [ -s "$TEMP_TTS" ]; then
                echo "✓ TTS generated audio file successfully"
                echo "  File size: $(stat -f%z "$TEMP_TTS" 2>/dev/null || stat --printf=%s "$TEMP_TTS" 2>/dev/null) bytes"
                rm -f "$TEMP_TTS"
                echo ""
                echo "→ TTS Integration Test: PASSED"
                ((PASSED++))
            else
                echo "✗ TTS file was not created"
                echo ""
                echo "→ TTS Integration Test: FAILED"
                ((FAILED++))
            fi
        else
            echo "✗ TTS command failed"
            echo ""
            echo "→ TTS Integration Test: FAILED"
            ((FAILED++))
        fi
    else
        echo "✗ 'say' command not available"
        echo ""
        echo "→ TTS Integration Test: FAILED"
        ((FAILED++))
    fi
else
    skip_test "TTS Integration Test" "Requires macOS"
fi

# ============================================
# Test 7: LLM Client Test (Mock Mode)
# ============================================
echo ""
echo "----------------------------------------------"
echo "Running: LLM Client Test (Mock Mode)"
echo "----------------------------------------------"

# Run engine tests that include LLM mock tests
if cargo test -p ai-english-engine llm --all-features 2>&1 | tee /tmp/llm_test_output.txt | tail -20; then
    echo ""
    echo "→ LLM Client Test: PASSED"
    ((PASSED++))
else
    echo ""
    echo "→ LLM Client Test: FAILED"
    ((FAILED++))
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=============================================="
echo "Integration Test Summary"
echo "=============================================="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"
echo "=============================================="

if [ $FAILED -gt 0 ]; then
    echo "RESULT: SOME TESTS FAILED"
    exit 1
else
    echo "RESULT: ALL TESTS PASSED"
    exit 0
fi
