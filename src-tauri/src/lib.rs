pub mod asr;
pub mod capture;
pub mod commands;
pub mod tts;

pub use ai_english_engine as engine;

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::Manager;
use tokio::sync::mpsc;

use commands::{
    add_mock_data, ask_explain, get_recent_context, handle_asr_chunk, handle_ocr_chunk,
    is_paused, set_paused, tts_speak, tts_stop, AppState,
};

use capture::{ScreenCapture, ScreenCaptureConfig};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = Arc::new(AppState::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .manage(app_state.clone())
        .invoke_handler(tauri::generate_handler![
            ask_explain,
            get_recent_context,
            set_paused,
            is_paused,
            tts_speak,
            tts_stop,
            handle_ocr_chunk,
            handle_asr_chunk,
            add_mock_data,
            start_screen_capture,
            stop_screen_capture,
        ])
        .setup(move |app| {
            // Register global shortcut (Option+Space on macOS)
            #[cfg(desktop)]
            {
                use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut};

                let shortcut = Shortcut::new(Some(Modifiers::ALT), Code::Space);
                let app_handle = app.handle().clone();

                app.global_shortcut().on_shortcut(shortcut, move |_app, _shortcut, _event| {
                    if let Some(window) = app_handle.get_webview_window("main") {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                })?;
            }

            // Start screen capture on macOS
            #[cfg(target_os = "macos")]
            {
                let state = app_state.clone();
                std::thread::spawn(move || {
                    let rt = tokio::runtime::Runtime::new().expect("Failed to create tokio runtime");
                    rt.block_on(async {
                        let (tx, mut rx) = mpsc::channel(100);
                        let screen_capture = ScreenCapture::new(ScreenCaptureConfig {
                            interval_ms: 1000, // Capture every second
                            ..Default::default()
                        });
                        
                        screen_capture.start(tx);
                        
                        while let Some(result) = rx.recv().await {
                            if !*state.paused.read() {
                                state.screen_buffer.push(result.ts_ms, result.text, result.confidence);
                            }
                        }
                    });
                });
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

/// Start screen capture
#[tauri::command]
pub fn start_screen_capture() -> Result<(), String> {
    // Screen capture is started automatically on app launch
    // This command is for manual control if needed
    Ok(())
}

/// Stop screen capture
#[tauri::command]
pub fn stop_screen_capture() -> Result<(), String> {
    // Would stop the capture thread
    Ok(())
}
