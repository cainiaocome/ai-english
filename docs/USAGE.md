# Usage Guide

This guide explains how to use the AI English Learning Assistant.

## Getting Started

### Launch the App

1. Open the AI English application
2. Grant required permissions when prompted (Screen Recording, Microphone)
3. The app will start capturing screen content automatically

### Global Shortcut

Press **Option + Space** from anywhere to:
- Bring the app window to focus
- Place cursor in the query input field

## Basic Usage

### Ask About a Word

1. Type a word or phrase in the input field
2. Press Enter or click "Explain"
3. View the structured explanation:
   - **Term**: The word/phrase you asked about
   - **Pronunciation**: How to say it
   - **Meaning**: Clear definition
   - **Usage**: How and when to use it
   - **Examples**: Sample sentences

### Text-to-Speech

- Click the 🔊 button next to the term to hear its pronunciation
- Click "🔊 Read Explanation" to hear the full meaning read aloud

## Context-Aware Queries

The app maintains context from recent screen and audio content:

### Screen Context (Last 3 seconds)

The app continuously captures and OCRs your screen. When you ask about a word, it checks if that word appeared recently on screen and uses that context.

**Example**:
1. You're reading an article containing "The ephemeral nature of..."
2. Press Option + Space
3. Type "ephemeral"
4. The app recognizes it from recent screen text and provides context-aware explanation

### Audio Context (Last 10 seconds)

When system audio is routed through BlackHole, the app transcribes it.

**Example**:
1. Watching a video where speaker says "ubiquitous"
2. Press Option + Space  
3. Type "ubiquitous" or "what did they just say"
4. The app includes the audio context in the explanation

## Setting Up Audio Capture

### Configure BlackHole

1. Open **Audio MIDI Setup** (Finder → Applications → Utilities)
2. Click **+** at bottom left → **Create Multi-Output Device**
3. Check both:
   - Your speakers/headphones
   - BlackHole 2ch
4. Right-click the Multi-Output Device → **Use This Device For Sound Output**

Now you'll hear audio normally while the app captures it.

## Debug Panel

Click "Show Debug Context" to view:

### Buffer Contents

See what text the app has captured:
- **Screen Buffer**: Recent OCR results with timestamps
- **Audio Buffer**: Recent transcriptions with timestamps

### Add Mock Data

Click "Add Mock Data" to populate buffers with test content. Useful for testing the app without real screen/audio capture.

### Refresh

Click "Refresh" to update the buffer display.

## Tips for Best Results

### For Screen OCR

- Works best with clear, readable text
- High-contrast text is easier to capture
- Reduce screen clutter for better accuracy

### For Audio ASR

- Clear audio with minimal background noise works best
- English content is optimized
- Allow 1-2 seconds after speech for transcription

### Query Tips

- Be specific: "What does 'carry out' mean?" 
- Reference context: "Explain the word that just appeared"
- Ask for usage: "How do I use 'albeit' in a sentence?"

## Pause/Resume Capture

The app supports pausing capture to save resources:

```
// Via debug panel or API
set_paused(true)   // Stop capturing
set_paused(false)  // Resume capturing
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Option + Space | Bring app to focus |
| Enter | Submit query |
| Escape | Clear input |

## Troubleshooting

### "No context found"

- Ensure the app has been running for a few seconds
- Check that Screen Recording permission is granted
- Try adding mock data to test

### Audio not being captured

- Verify BlackHole is configured correctly
- Check that system output is set to Multi-Output Device
- Ensure Microphone permission is granted

### Explanations seem generic

- The app may be in mock mode (no LLM API configured)
- Set `LLM_API_KEY` environment variable for real explanations
- Check that recent context contains relevant text

## Privacy

- All processing happens locally on your device
- Screen captures are not stored, only temporary text buffers
- Audio is transcribed locally via whisper.cpp
- LLM queries (if using API mode) are sent to your configured endpoint
