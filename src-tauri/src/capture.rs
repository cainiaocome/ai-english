// Screen capture module for macOS
// Uses screencapture + OCR via Vision framework

use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;
use tokio::time::interval;

/// OCR result from screen capture
#[derive(Debug, Clone)]
pub struct OcrResult {
    pub ts_ms: u64,
    pub text: String,
    pub confidence: Option<f32>,
}

/// Screen capture configuration
#[derive(Debug, Clone)]
pub struct ScreenCaptureConfig {
    pub interval_ms: u64,
    pub capture_selection: bool, // If true, capture selection area; otherwise full screen
}

impl Default for ScreenCaptureConfig {
    fn default() -> Self {
        Self {
            interval_ms: 1000,
            capture_selection: false,
        }
    }
}

/// Screen capture manager
pub struct ScreenCapture {
    running: Arc<AtomicBool>,
    config: ScreenCaptureConfig,
}

impl ScreenCapture {
    pub fn new(config: ScreenCaptureConfig) -> Self {
        Self {
            running: Arc::new(AtomicBool::new(false)),
            config,
        }
    }

    /// Start screen capture loop, sending OCR results through the channel
    pub fn start(&self, tx: mpsc::Sender<OcrResult>) {
        if self.running.swap(true, Ordering::SeqCst) {
            return; // Already running
        }

        let running = self.running.clone();
        let interval_ms = self.config.interval_ms;

        tokio::spawn(async move {
            let mut tick = interval(Duration::from_millis(interval_ms));

            while running.load(Ordering::SeqCst) {
                tick.tick().await;

                match capture_and_ocr().await {
                    Ok(result) => {
                        if !result.text.is_empty() {
                            if tx.send(result).await.is_err() {
                                break;
                            }
                        }
                    }
                    Err(e) => {
                        eprintln!("Screen capture error: {}", e);
                    }
                }
            }
        });
    }

    /// Stop screen capture loop
    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
    }

    /// Check if capture is running
    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::SeqCst)
    }
}

/// Capture screen and perform OCR
async fn capture_and_ocr() -> Result<OcrResult, String> {
    let ts_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;

    // Create temp file for screenshot
    let temp_path = format!("/tmp/ai_english_screen_{}.png", ts_ms);

    // Capture screen using screencapture command (macOS)
    // -x: no sound, -C: capture cursor, -t png: PNG format
    let capture_result = Command::new("screencapture")
        .args(["-x", "-C", "-t", "png", &temp_path])
        .output();

    match capture_result {
        Ok(output) => {
            if !output.status.success() {
                // Clean up temp file
                let _ = std::fs::remove_file(&temp_path);
                return Err("screencapture command failed".to_string());
            }
        }
        Err(e) => {
            return Err(format!("Failed to run screencapture: {}", e));
        }
    }

    // Perform OCR using Swift/Vision framework via a helper script
    let ocr_result = perform_ocr(&temp_path).await;

    // Clean up temp file
    let _ = std::fs::remove_file(&temp_path);

    ocr_result.map(|text| OcrResult {
        ts_ms,
        text,
        confidence: Some(0.9), // Vision framework doesn't easily expose confidence per-word
    })
}

/// Perform OCR on an image file using Vision framework
async fn perform_ocr(image_path: &str) -> Result<String, String> {
    // Use a Swift script to perform OCR
    // This is more reliable than trying to call Vision framework from Rust directly
    let script = r#"
import Vision
import Foundation
import CoreGraphics
import ImageIO

let imagePath = CommandLine.arguments[1]
guard let url = URL(string: "file://" + imagePath) else {
    print("")
    exit(0)
}

guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("")
    exit(0)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try? handler.perform([request])

guard let observations = request.results else {
    print("")
    exit(0)
}

var texts: [String] = []
for observation in observations {
    if let topCandidate = observation.topCandidates(1).first {
        texts.append(topCandidate.string)
    }
}

print(texts.joined(separator: " "))
"#;

    // Write the Swift script to a temp file
    let script_path = "/tmp/ai_english_ocr.swift";
    if let Err(e) = std::fs::write(script_path, script) {
        return Err(format!("Failed to write OCR script: {}", e));
    }

    // Run the Swift script
    let output = Command::new("swift")
        .args([script_path, image_path])
        .output();

    match output {
        Ok(output) => {
            if output.status.success() {
                let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
                Ok(text)
            } else {
                let stderr = String::from_utf8_lossy(&output.stderr);
                Err(format!("OCR failed: {}", stderr))
            }
        }
        Err(e) => Err(format!("Failed to run OCR: {}", e)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_screen_capture_config_default() {
        let config = ScreenCaptureConfig::default();
        assert_eq!(config.interval_ms, 1000);
        assert!(!config.capture_selection);
    }
}
