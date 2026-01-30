# Setup Guide

This guide provides detailed instructions for setting up the AI English Learning Assistant.

## System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later
- **Processor**: Apple Silicon (M1/M2/M3) or Intel
- **Memory**: 8GB RAM minimum (16GB recommended for whisper.cpp)
- **Storage**: 2GB free space

## Prerequisites

### 1. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Node.js

```bash
brew install node@20
```

### 3. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### 4. Install BlackHole Virtual Audio Device

BlackHole is required to capture system audio output.

```bash
brew install blackhole-2ch
```

After installation:
1. Open **Audio MIDI Setup** (Applications → Utilities)
2. Click **+** → **Create Multi-Output Device**
3. Check both your speakers and **BlackHole 2ch**
4. Set this as your system output in **System Settings → Sound**

## Installation

### Clone and Install

```bash
git clone https://github.com/cainiaocome/ai-english.git
cd ai-english
npm install
```

### Development Mode

```bash
npm run tauri dev
```

### Production Build

```bash
npm run tauri build
```

The built application will be in `src-tauri/target/release/bundle/macos/`.

## Configuration

### LLM API (Optional)

To use a real LLM instead of mock responses, set these environment variables:

```bash
export LLM_API_KEY="your-api-key"
export LLM_BASE_URL="https://api.openai.com/v1"  # or compatible endpoint
export LLM_MODEL="gpt-4o-mini"
```

You can add these to your `~/.zshrc` or `~/.bashrc`.

### Whisper Model (Optional)

For ASR, download a whisper model:

```bash
# Download base English model
curl -L -o ~/.local/share/whisper/base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

## macOS Permissions

### Screen Recording

1. Open **System Settings**
2. Go to **Privacy & Security** → **Screen Recording**
3. Enable **AI English** (or add it if not listed)

### Microphone (for BlackHole)

1. Open **System Settings**
2. Go to **Privacy & Security** → **Microphone**
3. Enable **AI English**

### Accessibility (for Global Shortcut)

1. Open **System Settings**
2. Go to **Privacy & Security** → **Accessibility**
3. Enable **AI English**

## Troubleshooting

### App not capturing screen

- Ensure Screen Recording permission is granted
- Restart the app after granting permission

### No audio transcription

- Verify BlackHole is installed and configured
- Check that system output is set to Multi-Output Device
- Ensure Microphone permission is granted

### Global shortcut not working

- Grant Accessibility permission
- Try restarting the app
- Check for conflicts with other apps using `Option + Space`

### Build errors

```bash
# Clean and rebuild
rm -rf node_modules target
npm install
npm run tauri build
```

## Updating

```bash
cd ai-english
git pull
npm install
npm run tauri build
```
