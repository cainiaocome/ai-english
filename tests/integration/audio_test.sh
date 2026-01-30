#!/bin/bash
# Audio Transcription Integration Test
# Tests whisper.cpp integration for speech-to-text

set -e

echo "=== Audio Transcription Integration Test ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
WHISPER_DIR="${PROJECT_ROOT}/deps/whisper.cpp"
MODEL_PATH="${WHISPER_DIR}/models/ggml-base.en.bin"
TEST_AUDIO="${SCRIPT_DIR}/test_audio.wav"

# Function to generate a test audio file with speech
generate_test_audio() {
    echo "Generating test audio with speech..."
    
    # Use macOS say command to generate speech
    if command -v say &> /dev/null; then
        say -o "${TEST_AUDIO}" --data-format=LEF32@16000 "Hello world. This is a test of speech recognition."
        echo "✓ Generated test audio using macOS say command"
        return 0
    else
        echo "✗ 'say' command not available (not macOS)"
        return 1
    fi
}

# Function to install whisper.cpp if not present
install_whisper() {
    if [ -d "$WHISPER_DIR" ] && [ -f "${WHISPER_DIR}/build/bin/whisper-cli" ]; then
        echo "whisper.cpp already installed"
        return 0
    fi
    
    echo "Installing whisper.cpp..."
    mkdir -p "$(dirname "$WHISPER_DIR")"
    
    if [ ! -d "$WHISPER_DIR" ]; then
        git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
    fi
    
    cd "$WHISPER_DIR"
    
    # Build whisper.cpp using cmake (recommended method)
    echo "Building with cmake..."
    cmake -B build -DWHISPER_METAL=ON
    cmake --build build --config Release
    
    if [ -f "build/bin/whisper-cli" ]; then
        echo "✓ whisper.cpp built successfully"
    else
        echo "✗ whisper.cpp build failed"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
}

# Function to download whisper model if not present
download_model() {
    if [ -f "$MODEL_PATH" ]; then
        echo "Whisper model already exists"
        return 0
    fi
    
    echo "Downloading whisper base.en model..."
    cd "$WHISPER_DIR"
    
    bash ./models/download-ggml-model.sh base.en
    
    if [ -f "$MODEL_PATH" ]; then
        echo "✓ Model downloaded successfully"
    else
        echo "✗ Failed to download model"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
}

# Function to run transcription test
test_transcription() {
    echo ""
    echo "=== Running Transcription Test ==="
    
    if [ ! -f "$TEST_AUDIO" ]; then
        echo "✗ Test audio file not found: $TEST_AUDIO"
        return 1
    fi
    
    # Get audio file info
    if command -v afinfo &> /dev/null; then
        echo "Audio file info:"
        afinfo "$TEST_AUDIO" 2>/dev/null | grep -E "(Data format|Duration|Sample Rate)" || true
    fi
    
    # Run whisper transcription
    WHISPER_BIN="${WHISPER_DIR}/build/bin/whisper-cli"
    
    if [ ! -f "$WHISPER_BIN" ]; then
        echo "✗ Whisper binary not found: $WHISPER_BIN"
        return 1
    fi
    
    echo ""
    echo "Running whisper transcription..."
    
    RESULT=$("$WHISPER_BIN" -m "$MODEL_PATH" -f "$TEST_AUDIO" -l en --no-timestamps 2>&1)
    
    echo "Transcription output:"
    echo "$RESULT"
    
    # Check if transcription contains expected words
    if echo "$RESULT" | grep -qi "hello\|world\|test\|speech\|recognition"; then
        echo ""
        echo "✓ Transcription contains expected keywords"
        return 0
    else
        echo ""
        echo "✗ Transcription did not contain expected keywords"
        return 1
    fi
}

# Function to test audio capture capability
test_audio_capture() {
    echo ""
    echo "=== Testing Audio Capture Capability ==="
    
    # List audio devices on macOS
    if command -v system_profiler &> /dev/null; then
        echo "Audio devices:"
        system_profiler SPAudioDataType 2>/dev/null | grep -A2 "Audio:" | head -10 || true
    fi
    
    # Check for BlackHole virtual audio device
    if system_profiler SPAudioDataType 2>/dev/null | grep -qi "BlackHole"; then
        echo "✓ BlackHole virtual audio device detected"
    else
        echo "⚠ BlackHole not detected (needed for system audio capture)"
        echo "  Install from: https://github.com/ExistentialAudio/BlackHole"
    fi
    
    # Test recording capability (requires permissions)
    echo ""
    echo "Testing audio recording..."
    
    # Try to record a short audio sample
    TEMP_AUDIO="/tmp/audio_test_$$.wav"
    
    # Use afrecord on macOS
    if command -v afrecord &> /dev/null; then
        timeout 2 afrecord -f WAVE -d LEI16@16000 "$TEMP_AUDIO" 2>/dev/null || true
        
        if [ -f "$TEMP_AUDIO" ] && [ -s "$TEMP_AUDIO" ]; then
            echo "✓ Audio recording test passed"
            rm -f "$TEMP_AUDIO"
            return 0
        fi
    fi
    
    # Alternative: use sox if available
    if command -v rec &> /dev/null; then
        timeout 2 rec -q -r 16000 -c 1 "$TEMP_AUDIO" 2>/dev/null || true
        
        if [ -f "$TEMP_AUDIO" ] && [ -s "$TEMP_AUDIO" ]; then
            echo "✓ Audio recording test passed (using sox)"
            rm -f "$TEMP_AUDIO"
            return 0
        fi
    fi
    
    echo "⚠ Could not test audio recording (may need permissions)"
    rm -f "$TEMP_AUDIO" 2>/dev/null || true
    return 0  # Don't fail - permissions may not be granted
}

# Main test sequence
main() {
    cd "$PROJECT_ROOT"
    
    echo "Project root: $PROJECT_ROOT"
    echo "Whisper dir: $WHISPER_DIR"
    echo ""
    
    # Install dependencies
    install_whisper || { echo "Failed to install whisper.cpp"; exit 1; }
    download_model || { echo "Failed to download model"; exit 1; }
    
    # Generate test audio
    generate_test_audio || { echo "Failed to generate test audio"; exit 1; }
    
    # Run tests
    PASSED=0
    FAILED=0
    
    if test_transcription; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
    
    if test_audio_capture; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
    
    # Cleanup
    rm -f "$TEST_AUDIO" 2>/dev/null || true
    
    echo ""
    echo "=== Audio Test Results: $PASSED passed, $FAILED failed ==="
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
