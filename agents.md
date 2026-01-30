# agents.md

Goal: build a macOS-first proof-of-concept (PoC) desktop app for learning English, using **Tauri + Rust core engine + macOS Swift plugins**, designed so the core can later be reused for Windows.

Environment: Command `gh`(Github client) is installed. Also a `GH_TOKEN` environment variable is set with permission to query Github action run. You should be able to set up Github workflows for testing and push the code to Github to compile and test your implementation in Github workflow. Example commands:

```bash
gh run list
gh run rerun
gh run view
gh run watch
```

You can add `--help` flag to any command to see more details.

```bash

---

## 0. High-level Product Description

We are building a desktop assistant that helps users understand English words or phrases they **just saw on screen** or **just heard from system audio**.

Core idea:

- The app continuously observes the screen (OCR) and system audio output (speech recognition).
- It keeps a **short rolling cache** of recent content.
- When the user presses a global shortcut, they can ask questions like:
  - “What does _carry out_ mean?”
  - “Explain the word that just appeared on screen.”
  - “What did the speaker mean by _X_ just now?”

- The app retrieves relevant recent context and uses an LLM to explain meaning, usage, and pronunciation.

This document defines **exact architecture, responsibilities, APIs, and acceptance criteria**.

---

## 1. Scope and Non-goals

### In scope (PoC requirements)

- **macOS only** (Windows is future work)
- Screen capture → OCR → cache last **3 seconds** of text
- System audio output capture (via virtual audio device) → ASR → cache last **10 seconds** of text
- Global keyboard shortcut to bring app to foreground
- User text input to ask about recent content
- LLM-based explanation (real API or mock)
- Text-to-speech (TTS) for pronunciation

### Explicit non-goals

- No Windows implementation
- No mobile version
- No custom audio driver (use BlackHole or similar)
- No wake-word detection (use push-to-talk or text input)
- No advanced NLP retrieval; simple matching is acceptable

---

## 2. Final Acceptance Criteria (Coding Test Definition)

The implementation is considered successful if **all items below work on a real macOS machine**.

### 2.1 Required

1. **Screen OCR pipeline**
   - App continuously captures the screen (reduced FPS is fine)
   - Uses macOS Vision OCR to extract text
   - Rust engine stores OCR results in a rolling buffer covering the **last 3 seconds only**

2. **System audio ASR pipeline**
   - User sets system output to **BlackHole** (or equivalent virtual audio device)
   - App captures that audio stream
   - Local speech recognition via **whisper.cpp**
   - Rust engine stores ASR results in a rolling buffer covering the **last 10 seconds only**

3. **Global shortcut**
   - A default global shortcut (e.g. `Option + Space`)
   - Pressing it brings the app window to the foreground and focuses the input field

4. **Query recent context**
   - User types a question about a word/phrase
   - App retrieves relevant recent OCR / ASR text
   - App sends question + context to an LLM (or mock)
   - App displays a structured explanation

5. **Text-to-speech**
   - App can speak the word or explanation aloud using macOS TTS

### 2.2 Optional (bonus)

- OCR only runs when screen content changes
- Pause / resume capture
- App whitelist
- Simple history stored locally

---

## 3. Fixed Technology Stack (Do Not Change)

### UI layer

- **Tauri v2**
- Frontend: React / Svelte / Vue (any is acceptable)

### Core engine

- **Rust**
- Responsible for:
  - Rolling caches
  - Retrieval logic
  - ASR orchestration
  - LLM calls

### macOS native plugins (Swift)

- Screen capture: **ScreenCaptureKit**
- OCR: **Vision (VNRecognizeTextRequest)**
- TTS: **AVSpeechSynthesizer**

### Speech recognition

- **whisper.cpp**, running locally

### Audio capture

- Prefer Rust-side capture using `cpal`
- Audio input device = BlackHole

---

## 4. Repository Structure (Recommended)

```

repo/
src-tauri/
src/
main.rs
engine/
mod.rs
cache.rs
retrieve.rs
llm.rs
asr/
mod.rs
whisper.rs
commands.rs
tauri.conf.json
Cargo.toml

src/
ui/
App.tsx
components/

macos-plugin/
Sources/
ScreenOcrPlugin/
ScreenOcrPlugin.swift
TtsPlugin/
TtsPlugin.swift
AudioCapturePlugin/ (optional)

agents.md

````

---

## 5. Core Data Model (Rust)

### 5.1 Text chunk

```rust
struct TextChunk {
    ts_ms: u64,
    source: SourceKind, // Screen | Audio
    text: String,
    confidence: Option<f32>,
}
````

### 5.2 Rolling buffers

- `ScreenTextBuffer`: retains only last **3 seconds**
- `AudioTextBuffer`: retains only last **10 seconds**

Required methods:

- `push(chunk)`
- `recent(now_ms) -> Vec<TextChunk>`
- `search_recent(query, now_ms, limit) -> Vec<TextChunk>`

Simple substring or token matching is sufficient.

---

## 6. Retrieval and Context Assembly (Rust)

Given a user query:

1. Search recent screen and audio buffers for matching chunks
2. If matches exist:
   - Return up to N chunks per source

3. If no matches:
   - Fallback to most recent chunks

Output structure:

```rust
struct Context {
    screen: Vec<TextChunk>,
    audio: Vec<TextChunk>,
}
```

---

## 7. LLM Integration (Rust)

### Modes

1. **Mock mode** (default for testing)
2. **Real API mode** (configured by env vars)

Environment variables:

- `LLM_API_KEY`
- `LLM_BASE_URL`
- `LLM_MODEL`

### Expected JSON output

```json
{
  "term": "carry out",
  "meaning": "...",
  "usage": ["..."],
  "examples": ["..."],
  "pronunciation": "..."
}
```

The UI should assume this structure.

---

## 8. Speech Recognition (whisper.cpp)

- Input: PCM audio from BlackHole
- Convert / resample to whisper-compatible format if needed
- Transcribe continuously or in small windows
- Push recognized text into `AudioTextBuffer`

Performance constraints (PoC):

- Transcription every 1–2 seconds is acceptable
- 1–3 seconds latency is acceptable

---

## 9. macOS Swift Plugins

### 9.1 Screen OCR Plugin

Responsibilities:

- Capture screen frames using ScreenCaptureKit
- Periodically run Vision OCR
- Emit OCR results to Tauri/Rust as events

Event name:

- `screen_ocr_chunk`

Payload example:

```json
{
  "ts_ms": 123456,
  "text": "Detected text",
  "confidence": 0.87
}
```

### 9.2 Text-to-Speech Plugin

Commands:

- `tts_speak(text: String)`
- `tts_stop()` (optional)

Uses `AVSpeechSynthesizer`.

### 9.3 Audio capture plugin

Optional.
Preferred approach:

- Rust captures audio directly via `cpal`
- Swift does NOT handle audio in PoC

---

## 10. Tauri Commands and Events

### Events (Swift → Rust)

- `screen_ocr_chunk`

### Commands (UI → Rust)

- `ask_explain(query: String) -> ExplainResult`
- `get_recent_context() -> Context` (debug)
- `set_paused(paused: bool)` (optional)

### Commands (Rust → Swift)

- `tts_speak(text: String)`

---

## 11. Prompt Design for LLM

System prompt:

- You are an English learning assistant
- Explain meanings in context
- Be concise
- Output valid JSON only

User prompt includes:

- User question
- Recent screen context
- Recent audio context

---

## 12. macOS Permissions (Required)

- Screen Recording
- Accessibility (for global shortcut / focus control, if needed)
- Microphone / audio input (for BlackHole)

App should:

- Detect missing permissions
- Show clear instructions directing user to System Settings

---

## 13. Test Checklist

1. Open a webpage or video containing English text
2. App runs in background for a few seconds
3. Press global shortcut
4. Type a word that just appeared on screen
5. Receive explanation
6. Hear pronunciation via TTS
7. Switch system output to BlackHole
8. Play English audio
9. After a few seconds, query a word from audio
10. App references recent audio context correctly

---

## 14. Implementation Order (Strongly Recommended)

1. Tauri UI + global shortcut
2. Screen capture + OCR (Swift) → event → Rust buffer
3. Rust rolling buffers + debug dump
4. `ask_explain` with mock LLM
5. Real LLM integration
6. TTS
7. Audio capture + whisper.cpp

---

## 15. Direct Instructions to Claude

You are the primary development agent for this repository.

Rules:

- Treat this document as the **single source of truth**.
- Do NOT assume any undocumented context.
- Keep platform-specific code isolated.
- Prioritize a working end-to-end pipeline over polish.

Deliverables:

1. Buildable, runnable macOS app
2. Minimal but functional UI
3. README explaining:
   - How to install BlackHole
   - Required macOS permissions
   - How to run the app

4. All required acceptance criteria must pass via testing.
