use serde::{Deserialize, Serialize};

/// ASR transcription result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranscriptionResult {
    pub text: String,
    pub confidence: Option<f32>,
    pub start_ms: u64,
    pub end_ms: u64,
}

/// Whisper ASR configuration
#[derive(Debug, Clone)]
pub struct WhisperConfig {
    pub model_path: Option<String>,
    pub language: String,
}

impl Default for WhisperConfig {
    fn default() -> Self {
        Self {
            model_path: None,
            language: "en".to_string(),
        }
    }
}

/// Whisper ASR wrapper
/// Note: Full whisper.cpp integration requires native compilation on macOS
/// This provides the interface that will be implemented with actual whisper.cpp bindings
pub struct WhisperAsr {
    config: WhisperConfig,
    initialized: bool,
}

impl WhisperAsr {
    /// Create a new Whisper ASR instance
    pub fn new(config: WhisperConfig) -> Self {
        Self {
            config,
            initialized: false,
        }
    }

    /// Initialize the whisper model
    /// On macOS, this would load the actual whisper.cpp model
    pub fn initialize(&mut self) -> Result<(), String> {
        // In a full implementation, this would:
        // 1. Load the whisper model from model_path
        // 2. Initialize the whisper context
        // For now, we just mark as initialized for the mock implementation
        self.initialized = true;
        Ok(())
    }

    /// Check if ASR is initialized
    pub fn is_initialized(&self) -> bool {
        self.initialized
    }

    /// Transcribe audio samples
    /// Input: PCM f32 samples at 16kHz
    /// For the PoC, this returns a mock result
    pub fn transcribe(&self, _samples: &[f32], timestamp_ms: u64) -> Result<TranscriptionResult, String> {
        if !self.initialized {
            return Err("Whisper ASR not initialized".to_string());
        }

        // Mock implementation - in production this would call whisper.cpp
        Ok(TranscriptionResult {
            text: String::new(), // No audio in mock mode
            confidence: None,
            start_ms: timestamp_ms,
            end_ms: timestamp_ms + 1000,
        })
    }

    /// Get the configured language
    pub fn language(&self) -> &str {
        &self.config.language
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_whisper_config_default() {
        let config = WhisperConfig::default();
        assert_eq!(config.language, "en");
        assert!(config.model_path.is_none());
    }

    #[test]
    fn test_whisper_initialization() {
        let mut asr = WhisperAsr::new(WhisperConfig::default());
        assert!(!asr.is_initialized());

        asr.initialize().unwrap();
        assert!(asr.is_initialized());
    }

    #[test]
    fn test_transcribe_requires_initialization() {
        let asr = WhisperAsr::new(WhisperConfig::default());
        let result = asr.transcribe(&[], 0);
        assert!(result.is_err());
    }

    #[test]
    fn test_transcribe_mock() {
        let mut asr = WhisperAsr::new(WhisperConfig::default());
        asr.initialize().unwrap();

        let result = asr.transcribe(&[0.0; 16000], 1000).unwrap();
        assert_eq!(result.start_ms, 1000);
    }
}
