import Foundation
import ScreenCaptureKit
import Vision

/// Screen OCR Plugin for capturing screen content and performing OCR
/// Uses ScreenCaptureKit for capture and Vision framework for text recognition
@available(macOS 13.0, *)
public class ScreenOcrPlugin {
    
    /// Callback type for OCR results
    public typealias OcrCallback = (UInt64, String, Float?) -> Void
    
    private var isCapturing = false
    private var captureInterval: TimeInterval = 1.0  // Capture every second
    private var callback: OcrCallback?
    private var timer: Timer?
    
    public init() {}
    
    /// Start screen capture and OCR
    /// - Parameters:
    ///   - interval: Time between captures in seconds
    ///   - callback: Called with (timestamp_ms, text, confidence) for each OCR result
    public func startCapture(interval: TimeInterval = 1.0, callback: @escaping OcrCallback) {
        self.captureInterval = interval
        self.callback = callback
        self.isCapturing = true
        
        // Start periodic capture
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureAndProcess()
        }
    }
    
    /// Stop screen capture
    public func stopCapture() {
        isCapturing = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Check if currently capturing
    public var capturing: Bool {
        return isCapturing
    }
    
    private func captureAndProcess() {
        guard isCapturing else { return }
        
        Task {
            await performCapture()
        }
    }
    
    @available(macOS 14.0, *)
    private func captureWithScreenshotManager() async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenOcrPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
    
    private func performCapture() async {
        do {
            let image: CGImage
            if #available(macOS 14.0, *) {
                image = try await captureWithScreenshotManager()
            } else {
                // Fallback for macOS 13.x - use CGWindowListCreateImage
                guard let cgImage = CGWindowListCreateImage(
                    CGRect.infinite,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    .bestResolution
                ) else {
                    print("Screen capture failed: CGWindowListCreateImage returned nil")
                    return
                }
                image = cgImage
            }
            
            await performOCR(on: image)
            
        } catch {
            print("Screen capture error: \(error)")
        }
    }
    
    private func performOCR(on image: CGImage) async {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            var fullText = ""
            var totalConfidence: Float = 0
            var count = 0
            
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    fullText += topCandidate.string + " "
                    totalConfidence += topCandidate.confidence
                    count += 1
                }
            }
            
            let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return }
            
            let avgConfidence = count > 0 ? totalConfidence / Float(count) : nil
            let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
            
            self?.callback?(timestamp, trimmedText, avgConfidence)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("OCR error: \(error)")
        }
    }
}

/// C-compatible interface for FFI
@_cdecl("screen_ocr_create")
public func screenOcrCreate() -> UnsafeMutableRawPointer? {
    if #available(macOS 13.0, *) {
        let plugin = ScreenOcrPlugin()
        return Unmanaged.passRetained(plugin).toOpaque()
    }
    return nil
}

@_cdecl("screen_ocr_destroy")
public func screenOcrDestroy(_ ptr: UnsafeMutableRawPointer) {
    if #available(macOS 13.0, *) {
        let _ = Unmanaged<ScreenOcrPlugin>.fromOpaque(ptr).takeRetainedValue()
    }
}
