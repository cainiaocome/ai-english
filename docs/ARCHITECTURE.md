# Architecture

This document describes the technical architecture of the AI English Learning Assistant.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Tauri Application                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │   React UI      │◄──►│         Rust Core Engine            │ │
│  │   (TypeScript)  │    │                                     │ │
│  └─────────────────┘    │  ┌─────────────┐ ┌──────────────┐   │ │
│                         │  │ Screen      │ │ Audio        │   │ │
│                         │  │ TextBuffer  │ │ TextBuffer   │   │ │
│                         │  │ (3 sec)     │ │ (10 sec)     │   │ │
│                         │  └──────┬──────┘ └──────┬───────┘   │ │
│                         │         │               │           │ │
│                         │         ▼               ▼           │ │
│                         │  ┌────────────────────────────────┐ │ │
│                         │  │      Context Retriever         │ │ │
│                         │  └────────────────┬───────────────┘ │ │
│                         │                   │                 │ │
│                         │                   ▼                 │ │
│                         │  ┌────────────────────────────────┐ │ │
│                         │  │         LLM Client             │ │ │
│                         │  │    (Mock / OpenAI API)         │ │ │
│                         │  └────────────────────────────────┘ │ │
│                         └─────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                      Swift Native Plugins                        │
│  ┌─────────────────────┐           ┌─────────────────────────┐  │
│  │   ScreenOcrPlugin   │           │      TtsPlugin          │  │
│  │   (ScreenCaptureKit │           │   (AVSpeechSynthesizer) │  │
│  │    + Vision OCR)    │           │                         │  │
│  └─────────────────────┘           └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                         ASR Module                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │   cpal (Audio Capture) ──► whisper.cpp (Speech Recognition) ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Frontend (React + TypeScript)

**Location**: `src/`

The UI layer built with React and TypeScript, bundled with Vite.

**Key Files**:
- `App.tsx` - Main application component
- `App.css` - Styling

**Features**:
- Query input field for asking about words/phrases
- Result display showing term, meaning, usage, examples
- TTS buttons for pronunciation
- Debug panel for viewing buffer contents

### Core Engine (Rust)

**Location**: `crates/engine/`

Platform-independent core logic that handles text caching, retrieval, and LLM integration.

**Modules**:

#### `cache.rs` - Rolling Text Buffers

```rust
struct TextChunk {
    ts_ms: u64,           // Timestamp in milliseconds
    source: SourceKind,   // Screen or Audio
    text: String,         // Recognized text
    confidence: Option<f32>,
}

struct ScreenTextBuffer  // 3-second retention
struct AudioTextBuffer   // 10-second retention
```

**Operations**:
- `push(chunk)` - Add new text, auto-expire old entries
- `recent(now_ms)` - Get all chunks in retention window
- `search_recent(query, now_ms, limit)` - Find matching chunks

#### `retrieve.rs` - Context Retrieval

```rust
struct Context {
    screen: Vec<TextChunk>,
    audio: Vec<TextChunk>,
}

struct ContextRetriever {
    fn retrieve(query, now_ms, limit) -> Context
    fn get_all_recent(now_ms) -> Context
}
```

**Strategy**:
1. Search for query matches in both buffers
2. If matches found, return matching chunks
3. If no matches, return most recent chunks as fallback

#### `llm.rs` - LLM Integration

```rust
struct ExplainResult {
    term: String,
    meaning: String,
    usage: Vec<String>,
    examples: Vec<String>,
    pronunciation: String,
}

struct LlmClient {
    fn explain(query, context) -> Result<ExplainResult>
}
```

**Modes**:
- **Mock mode**: Returns placeholder explanations (default)
- **API mode**: Calls OpenAI-compatible API when `LLM_API_KEY` is set

### Tauri Commands

**Location**: `src-tauri/src/commands.rs`

| Command | Description |
|---------|-------------|
| `ask_explain(query)` | Get LLM explanation for a word/phrase |
| `get_recent_context()` | Debug: get all buffered text |
| `tts_speak(text)` | Speak text using macOS TTS |
| `set_paused(bool)` | Pause/resume capture |
| `handle_ocr_chunk(...)` | Receive OCR result from Swift |
| `handle_asr_chunk(...)` | Receive ASR result from whisper |
| `add_mock_data()` | Debug: populate buffers with test data |

### Swift Plugins

**Location**: `macos-plugin/`

#### ScreenOcrPlugin

Uses ScreenCaptureKit to capture screen frames and Vision framework for OCR.

```swift
class ScreenOcrPlugin {
    func startCapture(interval: TimeInterval, callback: OcrCallback)
    func stopCapture()
}
```

**Flow**:
1. Capture screen frame via SCScreenshotManager
2. Run VNRecognizeTextRequest on the image
3. Extract text and confidence scores
4. Emit result to Rust via callback

#### TtsPlugin

Uses AVSpeechSynthesizer for text-to-speech.

```swift
class TtsPlugin {
    func speak(_ text: String, language: String, rate: Float)
    func stop()
}
```

### ASR Module

**Location**: `src-tauri/src/asr/`

Wraps whisper.cpp for local speech recognition.

```rust
struct WhisperAsr {
    fn initialize() -> Result<()>
    fn transcribe(samples: &[f32], timestamp: u64) -> Result<TranscriptionResult>
}
```

Audio is captured from BlackHole using the `cpal` crate.

## Data Flow

### Screen OCR Flow

```
ScreenCaptureKit → Vision OCR → Swift Plugin → Tauri Event
    → handle_ocr_chunk → ScreenTextBuffer
```

### Audio ASR Flow

```
BlackHole → cpal capture → whisper.cpp → handle_asr_chunk
    → AudioTextBuffer
```

### Query Flow

```
User Input → ask_explain command → ContextRetriever
    → LlmClient → ExplainResult → UI Display
```

## Threading Model

- **Main Thread**: Tauri/UI operations
- **Background Threads**: 
  - Screen capture timer
  - Audio capture loop
  - Whisper transcription

All buffer access is protected by `parking_lot::RwLock` for thread-safe concurrent access.

## Testing

Unit tests are in the engine crate:

```bash
cargo test -p ai-english-engine
```

Tests cover:
- Buffer retention and expiration
- Search functionality
- Context retrieval logic
- LLM mock responses
