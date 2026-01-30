#!/usr/bin/env swift
// OCR Integration Test - Tests Vision framework text recognition
// This test verifies OCR works without needing Screen Recording permission

import Foundation
import Vision
import CoreGraphics
import ImageIO

/// Create a test image with text
func createTestImage(withText text: String, width: Int = 400, height: Int = 100) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        print("Failed to create CGContext")
        return nil
    }
    
    // White background
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    
    // Black text
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    
    // Draw text using Core Text
    let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ]
    
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)
    
    context.textPosition = CGPoint(x: 20, y: height / 3)
    CTLineDraw(line, context)
    
    return context.makeImage()
}

/// Perform OCR on an image
func performOCR(on image: CGImage) -> (text: String, confidence: Float)? {
    var result: (String, Float)?
    let semaphore = DispatchSemaphore(value: 0)
    
    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            print("OCR error: \(error)")
            semaphore.signal()
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            semaphore.signal()
            return
        }
        
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
        let avgConfidence = count > 0 ? totalConfidence / Float(count) : 0
        
        result = (trimmedText, avgConfidence)
        semaphore.signal()
    }
    
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    
    do {
        try handler.perform([request])
        _ = semaphore.wait(timeout: .now() + 10)
    } catch {
        print("Failed to perform OCR: \(error)")
    }
    
    return result
}

/// Test OCR with sample text
func testOCR() -> Bool {
    print("=== OCR Integration Test ===")
    
    let testCases = [
        "Hello World",
        "Learning English is fun",
        "The quick brown fox jumps",
        "ABC123 Testing OCR"
    ]
    
    var passed = 0
    var failed = 0
    
    for testText in testCases {
        print("\nTest: '\(testText)'")
        
        guard let image = createTestImage(withText: testText) else {
            print("  ✗ Failed to create test image")
            failed += 1
            continue
        }
        print("  ✓ Created test image (\(image.width)x\(image.height))")
        
        guard let result = performOCR(on: image) else {
            print("  ✗ OCR returned no result")
            failed += 1
            continue
        }
        
        print("  ✓ OCR result: '\(result.text)' (confidence: \(String(format: "%.2f", result.confidence)))")
        
        // Check if the main words are recognized (OCR might have minor variations)
        let testWords = testText.lowercased().split(separator: " ")
        let resultWords = result.text.lowercased().split(separator: " ")
        
        let matchedWords = testWords.filter { testWord in
            resultWords.contains { resultWord in
                resultWord.contains(testWord) || testWord.contains(resultWord)
            }
        }
        
        let matchRatio = Float(matchedWords.count) / Float(testWords.count)
        
        if matchRatio >= 0.5 && result.confidence > 0.5 {
            print("  ✓ PASSED (match ratio: \(String(format: "%.0f%%", matchRatio * 100)))")
            passed += 1
        } else {
            print("  ✗ FAILED (match ratio: \(String(format: "%.0f%%", matchRatio * 100)))")
            failed += 1
        }
    }
    
    print("\n=== Results: \(passed) passed, \(failed) failed ===")
    return failed == 0
}

/// Test with an external image file if provided
func testWithImageFile(_ path: String) -> Bool {
    print("\n=== Testing with image file: \(path) ===")
    
    guard let dataProvider = CGDataProvider(filename: path) else {
        print("Failed to load image file")
        return false
    }
    
    var image: CGImage?
    
    if path.hasSuffix(".png") {
        image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    } else if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") {
        image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
    
    guard let cgImage = image else {
        print("Failed to create CGImage from file")
        return false
    }
    
    print("Image loaded: \(cgImage.width)x\(cgImage.height)")
    
    if let result = performOCR(on: cgImage) {
        print("OCR Result: '\(result.text)'")
        print("Confidence: \(String(format: "%.2f", result.confidence))")
        return !result.text.isEmpty
    }
    
    return false
}

// Main
print("Vision Framework OCR Integration Test")
print("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("")

var success = testOCR()

// Test with command line argument image if provided
if CommandLine.arguments.count > 1 {
    let imagePath = CommandLine.arguments[1]
    success = testWithImageFile(imagePath) && success
}

exit(success ? 0 : 1)
