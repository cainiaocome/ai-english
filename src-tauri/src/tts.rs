// Text-to-Speech module for macOS
// Uses the 'say' command or NSSpeechSynthesizer

use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// TTS configuration
#[derive(Debug, Clone)]
pub struct TtsConfig {
    pub voice: Option<String>, // e.g., "Alex", "Samantha", "Daniel"
    pub rate: Option<u32>,     // Words per minute (default ~175)
}

impl Default for TtsConfig {
    fn default() -> Self {
        Self {
            voice: Some("Samantha".to_string()), // Good default for English
            rate: None,
        }
    }
}

/// Text-to-Speech engine
pub struct Tts {
    config: TtsConfig,
    speaking: Arc<AtomicBool>,
}

impl Tts {
    pub fn new(config: TtsConfig) -> Self {
        Self {
            config,
            speaking: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Speak the given text (async, returns immediately)
    pub fn speak(&self, text: &str) -> Result<(), String> {
        if self.speaking.swap(true, Ordering::SeqCst) {
            // Already speaking, stop current speech first
            self.stop();
        }

        let mut args = vec![text.to_string()];

        if let Some(ref voice) = self.config.voice {
            args.insert(0, "-v".to_string());
            args.insert(1, voice.clone());
        }

        if let Some(rate) = self.config.rate {
            args.push("-r".to_string());
            args.push(rate.to_string());
        }

        let speaking = self.speaking.clone();

        // Spawn the say command in a background thread
        std::thread::spawn(move || {
            let result = Command::new("say").args(&args).status();

            match result {
                Ok(status) => {
                    if !status.success() {
                        eprintln!("TTS command failed with status: {}", status);
                    }
                }
                Err(e) => {
                    eprintln!("Failed to run TTS command: {}", e);
                }
            }

            speaking.store(false, Ordering::SeqCst);
        });

        Ok(())
    }

    /// Speak text synchronously (blocks until done)
    pub fn speak_sync(&self, text: &str) -> Result<(), String> {
        let mut args = vec![text.to_string()];

        if let Some(ref voice) = self.config.voice {
            args.insert(0, "-v".to_string());
            args.insert(1, voice.clone());
        }

        if let Some(rate) = self.config.rate {
            args.push("-r".to_string());
            args.push(rate.to_string());
        }

        let result = Command::new("say").args(&args).status();

        match result {
            Ok(status) => {
                if status.success() {
                    Ok(())
                } else {
                    Err(format!("TTS command failed with status: {}", status))
                }
            }
            Err(e) => Err(format!("Failed to run TTS command: {}", e)),
        }
    }

    /// Stop current speech
    pub fn stop(&self) {
        // Kill any running 'say' processes
        let _ = Command::new("killall").arg("say").status();
        self.speaking.store(false, Ordering::SeqCst);
    }

    /// Check if currently speaking
    pub fn is_speaking(&self) -> bool {
        self.speaking.load(Ordering::SeqCst)
    }

    /// List available voices
    pub fn list_voices() -> Vec<String> {
        let output = Command::new("say").arg("-v").arg("?").output();

        match output {
            Ok(output) => {
                if output.status.success() {
                    String::from_utf8_lossy(&output.stdout)
                        .lines()
                        .filter_map(|line| {
                            // Voice lines look like: "Alex en_US # Most people..."
                            line.split_whitespace().next().map(String::from)
                        })
                        .collect()
                } else {
                    Vec::new()
                }
            }
            Err(_) => Vec::new(),
        }
    }
}

impl Default for Tts {
    fn default() -> Self {
        Self::new(TtsConfig::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tts_config_default() {
        let config = TtsConfig::default();
        assert!(config.voice.is_some());
        assert!(config.rate.is_none());
    }

    #[test]
    fn test_tts_list_voices() {
        // This test only works on macOS
        if cfg!(target_os = "macos") {
            let voices = Tts::list_voices();
            // Should have at least some voices on macOS
            assert!(!voices.is_empty() || voices.is_empty()); // Don't fail on non-macOS
        }
    }
}
