pub mod asr;
pub mod commands;

pub use ai_english_engine as engine;

use std::sync::Arc;
use tauri::Manager;

use commands::{
    add_mock_data, ask_explain, get_recent_context, handle_asr_chunk, handle_ocr_chunk,
    is_paused, set_paused, tts_speak, AppState,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = Arc::new(AppState::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            ask_explain,
            get_recent_context,
            set_paused,
            is_paused,
            tts_speak,
            handle_ocr_chunk,
            handle_asr_chunk,
            add_mock_data,
        ])
        .setup(|app| {
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

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
