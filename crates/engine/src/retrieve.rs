use super::cache::{AudioTextBuffer, ScreenTextBuffer, TextChunk};
use serde::{Deserialize, Serialize};

/// Combined context from both screen and audio sources
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Context {
    pub screen: Vec<TextChunk>,
    pub audio: Vec<TextChunk>,
}

impl Context {
    pub fn new(screen: Vec<TextChunk>, audio: Vec<TextChunk>) -> Self {
        Self { screen, audio }
    }

    pub fn is_empty(&self) -> bool {
        self.screen.is_empty() && self.audio.is_empty()
    }

    /// Combine all text into a single string for LLM context
    pub fn combined_text(&self) -> String {
        let mut parts = Vec::new();

        if !self.screen.is_empty() {
            let screen_text: Vec<&str> = self.screen.iter().map(|c| c.text.as_str()).collect();
            parts.push(format!("Screen text: {}", screen_text.join(" | ")));
        }

        if !self.audio.is_empty() {
            let audio_text: Vec<&str> = self.audio.iter().map(|c| c.text.as_str()).collect();
            parts.push(format!("Audio text: {}", audio_text.join(" | ")));
        }

        parts.join("\n")
    }
}

/// Retrieves relevant context based on a user query
pub struct ContextRetriever<'a> {
    screen_buffer: &'a ScreenTextBuffer,
    audio_buffer: &'a AudioTextBuffer,
}

impl<'a> ContextRetriever<'a> {
    pub fn new(screen_buffer: &'a ScreenTextBuffer, audio_buffer: &'a AudioTextBuffer) -> Self {
        Self {
            screen_buffer,
            audio_buffer,
        }
    }

    /// Retrieve context relevant to the query
    /// If query matches content, return matching chunks
    /// Otherwise, return most recent chunks as fallback
    pub fn retrieve(&self, query: &str, now_ms: u64, limit_per_source: usize) -> Context {
        // Try to find matching content first
        let screen_matches = self
            .screen_buffer
            .search_recent(query, now_ms, limit_per_source);
        let audio_matches = self
            .audio_buffer
            .search_recent(query, now_ms, limit_per_source);

        // If we found matches, use them
        if !screen_matches.is_empty() || !audio_matches.is_empty() {
            return Context::new(screen_matches, audio_matches);
        }

        // Fallback to most recent content
        let mut screen_recent = self.screen_buffer.recent(now_ms);
        let mut audio_recent = self.audio_buffer.recent(now_ms);

        // Limit results
        screen_recent.truncate(limit_per_source);
        audio_recent.truncate(limit_per_source);

        Context::new(screen_recent, audio_recent)
    }

    /// Get all recent context without filtering
    pub fn get_all_recent(&self, now_ms: u64) -> Context {
        Context::new(
            self.screen_buffer.recent(now_ms),
            self.audio_buffer.recent(now_ms),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_context_retrieval_with_matches() {
        let screen_buf = ScreenTextBuffer::new();
        let audio_buf = AudioTextBuffer::new();

        screen_buf.push(1000, "The word ephemeral means temporary".to_string(), None);
        screen_buf.push(2000, "Another sentence here".to_string(), None);
        audio_buf.push(1500, "I heard ephemeral used in speech".to_string(), None);

        let retriever = ContextRetriever::new(&screen_buf, &audio_buf);
        let context = retriever.retrieve("ephemeral", 3000, 5);

        assert_eq!(context.screen.len(), 1);
        assert_eq!(context.audio.len(), 1);
        assert!(context.screen[0].text.contains("ephemeral"));
        assert!(context.audio[0].text.contains("ephemeral"));
    }

    #[test]
    fn test_context_retrieval_fallback() {
        let screen_buf = ScreenTextBuffer::new();
        let audio_buf = AudioTextBuffer::new();

        screen_buf.push(1000, "Some screen text".to_string(), None);
        audio_buf.push(1500, "Some audio text".to_string(), None);

        let retriever = ContextRetriever::new(&screen_buf, &audio_buf);
        let context = retriever.retrieve("nonexistent", 2000, 5);

        // Should fallback to recent content
        assert_eq!(context.screen.len(), 1);
        assert_eq!(context.audio.len(), 1);
    }

    #[test]
    fn test_combined_text() {
        let screen_buf = ScreenTextBuffer::new();
        let audio_buf = AudioTextBuffer::new();

        screen_buf.push(1000, "Screen one".to_string(), None);
        screen_buf.push(2000, "Screen two".to_string(), None);
        audio_buf.push(1500, "Audio one".to_string(), None);

        let retriever = ContextRetriever::new(&screen_buf, &audio_buf);
        let context = retriever.get_all_recent(3000);

        let combined = context.combined_text();
        assert!(combined.contains("Screen text:"));
        assert!(combined.contains("Audio text:"));
        assert!(combined.contains("Screen one"));
        assert!(combined.contains("Screen two"));
        assert!(combined.contains("Audio one"));
    }
}
