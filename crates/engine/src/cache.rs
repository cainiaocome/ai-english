use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;

/// Source of text content
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SourceKind {
    Screen,
    Audio,
}

/// A chunk of recognized text with metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextChunk {
    pub ts_ms: u64,
    pub source: SourceKind,
    pub text: String,
    pub confidence: Option<f32>,
}

impl TextChunk {
    pub fn new(ts_ms: u64, source: SourceKind, text: String, confidence: Option<f32>) -> Self {
        Self {
            ts_ms,
            source,
            text,
            confidence,
        }
    }
}

/// Generic rolling buffer for text chunks
pub struct RollingBuffer {
    chunks: RwLock<VecDeque<TextChunk>>,
    retention_ms: u64,
}

impl RollingBuffer {
    pub fn new(retention_ms: u64) -> Self {
        Self {
            chunks: RwLock::new(VecDeque::new()),
            retention_ms,
        }
    }

    /// Add a new chunk and remove expired ones
    pub fn push(&self, chunk: TextChunk) {
        let mut chunks = self.chunks.write();
        let cutoff = chunk.ts_ms.saturating_sub(self.retention_ms);

        // Remove expired chunks
        while let Some(front) = chunks.front() {
            if front.ts_ms < cutoff {
                chunks.pop_front();
            } else {
                break;
            }
        }

        chunks.push_back(chunk);
    }

    /// Get all chunks within the retention window
    pub fn recent(&self, now_ms: u64) -> Vec<TextChunk> {
        let chunks = self.chunks.read();
        let cutoff = now_ms.saturating_sub(self.retention_ms);

        chunks
            .iter()
            .filter(|c| c.ts_ms >= cutoff)
            .cloned()
            .collect()
    }

    /// Search for chunks containing the query string (case-insensitive)
    pub fn search_recent(&self, query: &str, now_ms: u64, limit: usize) -> Vec<TextChunk> {
        let chunks = self.chunks.read();
        let cutoff = now_ms.saturating_sub(self.retention_ms);
        let query_lower = query.to_lowercase();

        chunks
            .iter()
            .filter(|c| c.ts_ms >= cutoff && c.text.to_lowercase().contains(&query_lower))
            .take(limit)
            .cloned()
            .collect()
    }

    /// Clear all chunks
    pub fn clear(&self) {
        self.chunks.write().clear();
    }

    /// Get the number of chunks currently stored
    pub fn len(&self) -> usize {
        self.chunks.read().len()
    }

    /// Check if buffer is empty
    pub fn is_empty(&self) -> bool {
        self.chunks.read().is_empty()
    }
}

/// Screen text buffer with 3-second retention
pub struct ScreenTextBuffer(RollingBuffer);

impl ScreenTextBuffer {
    pub fn new() -> Self {
        Self(RollingBuffer::new(3000)) // 3 seconds
    }

    pub fn push(&self, ts_ms: u64, text: String, confidence: Option<f32>) {
        self.0
            .push(TextChunk::new(ts_ms, SourceKind::Screen, text, confidence));
    }

    pub fn recent(&self, now_ms: u64) -> Vec<TextChunk> {
        self.0.recent(now_ms)
    }

    pub fn search_recent(&self, query: &str, now_ms: u64, limit: usize) -> Vec<TextChunk> {
        self.0.search_recent(query, now_ms, limit)
    }

    pub fn clear(&self) {
        self.0.clear();
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

impl Default for ScreenTextBuffer {
    fn default() -> Self {
        Self::new()
    }
}

/// Audio text buffer with 10-second retention
pub struct AudioTextBuffer(RollingBuffer);

impl AudioTextBuffer {
    pub fn new() -> Self {
        Self(RollingBuffer::new(10000)) // 10 seconds
    }

    pub fn push(&self, ts_ms: u64, text: String, confidence: Option<f32>) {
        self.0
            .push(TextChunk::new(ts_ms, SourceKind::Audio, text, confidence));
    }

    pub fn recent(&self, now_ms: u64) -> Vec<TextChunk> {
        self.0.recent(now_ms)
    }

    pub fn search_recent(&self, query: &str, now_ms: u64, limit: usize) -> Vec<TextChunk> {
        self.0.search_recent(query, now_ms, limit)
    }

    pub fn clear(&self) {
        self.0.clear();
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

impl Default for AudioTextBuffer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_screen_buffer_retention() {
        let buffer = ScreenTextBuffer::new();

        // Add chunks at different times
        buffer.push(1000, "first".to_string(), Some(0.9));
        buffer.push(2000, "second".to_string(), Some(0.8));
        buffer.push(5000, "third".to_string(), Some(0.95));

        // At t=5000, only chunks from t>=2000 should be visible (3-second window)
        let recent = buffer.recent(5000);
        assert_eq!(recent.len(), 2);
        assert_eq!(recent[0].text, "second");
        assert_eq!(recent[1].text, "third");
    }

    #[test]
    fn test_audio_buffer_retention() {
        let buffer = AudioTextBuffer::new();

        buffer.push(1000, "early".to_string(), None);
        buffer.push(8000, "middle".to_string(), None);
        buffer.push(12000, "late".to_string(), None);

        // At t=12000, only chunks from t>=2000 should be visible (10-second window)
        let recent = buffer.recent(12000);
        assert_eq!(recent.len(), 2);
        assert_eq!(recent[0].text, "middle");
        assert_eq!(recent[1].text, "late");
    }

    #[test]
    fn test_search_recent() {
        let buffer = ScreenTextBuffer::new();

        buffer.push(1000, "The quick brown fox".to_string(), None);
        buffer.push(2000, "jumps over the lazy dog".to_string(), None);
        buffer.push(3000, "Hello World".to_string(), None);

        let results = buffer.search_recent("quick", 3500, 10);
        assert_eq!(results.len(), 1);
        assert!(results[0].text.contains("quick"));

        // Case-insensitive search
        let results = buffer.search_recent("WORLD", 3500, 10);
        assert_eq!(results.len(), 1);
        assert!(results[0].text.contains("World"));
    }

    #[test]
    fn test_buffer_expiration_on_push() {
        let buffer = ScreenTextBuffer::new();

        buffer.push(1000, "old".to_string(), None);
        buffer.push(2000, "older".to_string(), None);

        // This push should trigger cleanup of old chunks
        buffer.push(6000, "new".to_string(), None);

        // Buffer should only contain the new chunk
        assert_eq!(buffer.len(), 1);
        let recent = buffer.recent(6000);
        assert_eq!(recent[0].text, "new");
    }
}
