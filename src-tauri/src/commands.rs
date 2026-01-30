use parking_lot::RwLock;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::State;

use ai_english_engine::{
    AudioTextBuffer, Context, ContextRetriever, ExplainResult, LlmClient, ScreenTextBuffer,
};

/// Application state shared across commands
pub struct AppState {
    pub screen_buffer: ScreenTextBuffer,
    pub audio_buffer: AudioTextBuffer,
    pub llm_client: LlmClient,
    pub paused: RwLock<bool>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            screen_buffer: ScreenTextBuffer::new(),
            audio_buffer: AudioTextBuffer::new(),
            llm_client: LlmClient::from_env(),
            paused: RwLock::new(false),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

/// Get current timestamp in milliseconds
fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

/// Ask for an explanation of a word or phrase
#[tauri::command]
pub async fn ask_explain(
    query: String,
    state: State<'_, Arc<AppState>>,
) -> Result<ExplainResult, String> {
    let now = now_ms();
    let retriever = ContextRetriever::new(&state.screen_buffer, &state.audio_buffer);
    let context = retriever.retrieve(&query, now, 5);

    state.llm_client.explain(&query, &context).await
}

/// Get recent context for debugging
#[tauri::command]
pub fn get_recent_context(state: State<'_, Arc<AppState>>) -> Context {
    let now = now_ms();
    let retriever = ContextRetriever::new(&state.screen_buffer, &state.audio_buffer);
    retriever.get_all_recent(now)
}

/// Set pause state for capture
#[tauri::command]
pub fn set_paused(paused: bool, state: State<'_, Arc<AppState>>) {
    *state.paused.write() = paused;
}

/// Check if capture is paused
#[tauri::command]
pub fn is_paused(state: State<'_, Arc<AppState>>) -> bool {
    *state.paused.read()
}

/// Speak text using TTS (macOS only - calls Swift plugin)
/// For non-macOS platforms, this is a no-op
#[tauri::command]
pub fn tts_speak(text: String) -> Result<(), String> {
    // On macOS, this would call the Swift TTS plugin
    // For the PoC running on other platforms, we just log
    #[cfg(target_os = "macos")]
    {
        // Would call Swift plugin here
        println!("TTS: {}", text);
    }

    #[cfg(not(target_os = "macos"))]
    {
        println!("TTS (mock): {}", text);
    }

    Ok(())
}

/// Handle OCR chunk from Swift plugin
#[tauri::command]
pub fn handle_ocr_chunk(
    ts_ms: u64,
    text: String,
    confidence: Option<f32>,
    state: State<'_, Arc<AppState>>,
) {
    if !*state.paused.read() {
        state.screen_buffer.push(ts_ms, text, confidence);
    }
}

/// Handle ASR chunk from whisper
#[tauri::command]
pub fn handle_asr_chunk(
    ts_ms: u64,
    text: String,
    confidence: Option<f32>,
    state: State<'_, Arc<AppState>>,
) {
    if !*state.paused.read() {
        state.audio_buffer.push(ts_ms, text, confidence);
    }
}

/// Add mock data for testing
#[tauri::command]
pub fn add_mock_data(state: State<'_, Arc<AppState>>) {
    let now = now_ms();

    // Add some mock screen text
    state.screen_buffer.push(
        now - 2000,
        "The word 'ephemeral' means lasting for a very short time.".to_string(),
        Some(0.95),
    );
    state.screen_buffer.push(
        now - 1000,
        "Example: The ephemeral nature of cherry blossoms makes them precious.".to_string(),
        Some(0.92),
    );

    // Add some mock audio text
    state.audio_buffer.push(
        now - 5000,
        "Today we're going to discuss vocabulary words.".to_string(),
        Some(0.88),
    );
    state.audio_buffer.push(
        now - 3000,
        "The first word is ephemeral, which describes something temporary.".to_string(),
        Some(0.90),
    );
}
