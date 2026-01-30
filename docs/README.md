# AI English Learning Assistant

A macOS desktop application that helps users learn English by capturing screen text (OCR) and system audio (ASR), then explaining words and phrases using an LLM.

## Features

- **Screen OCR**: Continuously captures screen content and extracts text using macOS Vision framework
- **Audio ASR**: Transcribes system audio using whisper.cpp for speech recognition
- **Rolling Context**: Maintains recent text buffers (3s for screen, 10s for audio)
- **LLM Explanations**: Provides structured explanations of English words and phrases
- **Text-to-Speech**: Pronounces words and reads explanations aloud
- **Global Shortcut**: Press `Option + Space` to bring the app to focus

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

The app requires the following permissions:
- **Screen Recording**: For capturing screen content
- **Microphone**: For capturing audio from BlackHole

Go to **System Settings → Privacy & Security** to grant these permissions.

## Documentation

- [Setup Guide](docs/SETUP.md) - Detailed installation instructions
- [Architecture](docs/ARCHITECTURE.md) - Technical architecture overview
- [Usage Guide](docs/USAGE.md) - How to use the application

## Tech Stack

- **UI**: Tauri v2 + React + TypeScript
- **Core Engine**: Rust
- **Native Plugins**: Swift (ScreenCaptureKit, Vision, AVSpeechSynthesizer)
- **Speech Recognition**: whisper.cpp

## License

MIT
