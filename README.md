# AI English Learning Assistant

A macOS desktop application that helps users learn English by capturing screen text (OCR) and system audio (ASR), then explaining words and phrases using an LLM.

## Features

- 🖥️ **Screen OCR**: Continuously captures screen content using macOS Vision framework
- 🎧 **Audio ASR**: Transcribes system audio using whisper.cpp
- 📝 **Rolling Context**: Maintains recent text buffers (3s screen, 10s audio)
- 🤖 **LLM Explanations**: Provides structured explanations of English words and phrases
- 🔊 **Text-to-Speech**: Pronounces words and reads explanations aloud
- ⌨️ **Global Shortcut**: Press `Option + Space` to bring the app to focus

## Quick Start

### Prerequisites

- macOS 13.0 or later
- Node.js 18+
- Rust (latest stable)
- [BlackHole](https://existential.audio/blackhole/) virtual audio device (for audio capture)

### Installation

```bash
# Clone the repository
git clone https://github.com/cainiaocome/ai-english.git
cd ai-english

# Install dependencies
npm install

# Run in development mode
npm run tauri dev

# Build for production
npm run tauri build
```

### macOS Permissions

Grant these permissions in **System Settings → Privacy & Security**:
- **Screen Recording**: For capturing screen content
- **Microphone**: For capturing audio from BlackHole

## Documentation

- [Setup Guide](docs/SETUP.md) - Detailed installation instructions
- [Architecture](docs/ARCHITECTURE.md) - Technical architecture overview
- [Usage Guide](docs/USAGE.md) - How to use the application

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Tauri v2 + React + TypeScript |
| Core Engine | Rust |
| Native Plugins | Swift (ScreenCaptureKit, Vision, AVSpeechSynthesizer) |
| Speech Recognition | whisper.cpp |

## Project Structure

```
ai-english/
├── src/                    # React frontend
├── src-tauri/              # Tauri + Rust backend
│   └── src/
│       ├── commands.rs     # Tauri commands
│       ├── asr/            # Speech recognition
│       └── lib.rs          # App entry point
├── crates/engine/          # Core engine (platform-independent)
│   └── src/
│       ├── cache.rs        # Rolling text buffers
│       ├── retrieve.rs     # Context retrieval
│       └── llm.rs          # LLM integration
├── macos-plugin/           # Swift native plugins
│   └── Sources/
│       ├── ScreenOcrPlugin/
│       └── TtsPlugin/
└── docs/                   # Documentation
```

## Configuration

### LLM API (Optional)

Set environment variables to use a real LLM:

```bash
export LLM_API_KEY="your-api-key"
export LLM_BASE_URL="https://api.openai.com/v1"
export LLM_MODEL="gpt-4o-mini"
```

Without these, the app runs in mock mode with placeholder responses.

## Development

```bash
# Run tests
cargo test -p ai-english-engine

# Check code style
cargo fmt -p ai-english-engine -- --check
cargo clippy -p ai-english-engine -- -D warnings

# TypeScript check
npm run lint
```

## License

MIT
