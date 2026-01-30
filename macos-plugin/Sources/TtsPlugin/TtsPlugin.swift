import Foundation
import AVFoundation

/// Text-to-Speech Plugin using AVSpeechSynthesizer
public class TtsPlugin: NSObject {
    
    private let synthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speak the given text
    /// - Parameters:
    ///   - text: The text to speak
    ///   - language: Language code (default: "en-US")
    ///   - rate: Speech rate (0.0 to 1.0, default: 0.5)
    public func speak(_ text: String, language: String = "en-US", rate: Float = 0.5) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// Stop speaking
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    /// Check if currently speaking
    public var speaking: Bool {
        return synthesizer.isSpeaking
    }
    
    /// Get available voices for a language
    public static func availableVoices(for language: String) -> [String] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: language) }
            .map { $0.name }
    }
}

extension TtsPlugin: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

/// C-compatible interface for FFI
@_cdecl("tts_create")
public func ttsCreate() -> UnsafeMutableRawPointer {
    let plugin = TtsPlugin()
    return Unmanaged.passRetained(plugin).toOpaque()
}

@_cdecl("tts_destroy")
public func ttsDestroy(_ ptr: UnsafeMutableRawPointer) {
    let _ = Unmanaged<TtsPlugin>.fromOpaque(ptr).takeRetainedValue()
}

@_cdecl("tts_speak")
public func ttsSpeak(_ ptr: UnsafeMutableRawPointer, _ text: UnsafePointer<CChar>) {
    let plugin = Unmanaged<TtsPlugin>.fromOpaque(ptr).takeUnretainedValue()
    let string = String(cString: text)
    plugin.speak(string)
}

@_cdecl("tts_stop")
public func ttsStop(_ ptr: UnsafeMutableRawPointer) {
    let plugin = Unmanaged<TtsPlugin>.fromOpaque(ptr).takeUnretainedValue()
    plugin.stop()
}
