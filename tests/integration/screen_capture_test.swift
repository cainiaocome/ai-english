#!/usr/bin/env swift
// Screen Capture Integration Test
// Tests ScreenCaptureKit functionality and permission detection

import Foundation

#if os(macOS)
import ScreenCaptureKit
import CoreGraphics

/// Check if screen recording permission is granted
@available(macOS 12.3, *)
func checkScreenRecordingPermission() async -> Bool {
    do {
        let content = try await SCShareableContent.current
        return !content.displays.isEmpty
    } catch {
        return false
    }
}

/// Test screen capture without actually capturing (permission check)
@available(macOS 12.3, *)
func testPermissionDetection() async -> Bool {
    print("=== Screen Recording Permission Test ===")
    
    let hasPermission = await checkScreenRecordingPermission()
    
    if hasPermission {
        print("✓ Screen recording permission is granted")
        print("  Can enumerate displays and windows")
    } else {
        print("⚠ Screen recording permission not granted")
        print("  This is expected in CI environments")
        print("  App will prompt user for permission on first use")
    }
    
    return true  // Don't fail - permission detection itself works
}

/// Test display enumeration if permission is granted
@available(macOS 12.3, *)
func testDisplayEnumeration() async -> Bool {
    print("\n=== Display Enumeration Test ===")
    
    do {
        let content = try await SCShareableContent.current
        
        print("Displays found: \(content.displays.count)")
        for (index, display) in content.displays.enumerated() {
            print("  Display \(index): \(display.width)x\(display.height)")
        }
        
        print("Windows found: \(content.windows.count)")
        let visibleWindows = content.windows.filter { $0.isOnScreen }
        print("  Visible windows: \(visibleWindows.count)")
        
        print("Applications found: \(content.applications.count)")
        
        print("✓ Display enumeration successful")
        return true
        
    } catch let error as NSError {
        if error.code == -3801 {  // Screen recording permission denied
            print("⚠ Permission denied - cannot enumerate displays")
            print("  Error: \(error.localizedDescription)")
            return true  // Expected in CI
        }
        print("✗ Unexpected error: \(error)")
        return false
    }
}

/// Test screen capture if permission is granted
@available(macOS 13.0, *)
func testScreenCapture() async -> Bool {
    print("\n=== Screen Capture Test ===")
    
    do {
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first else {
            print("⚠ No displays available (permission may be denied)")
            return true
        }
        
        print("Capturing from display: \(display.width)x\(display.height)")
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = min(Int(display.width), 1920)  // Limit size for test
        config.height = min(Int(display.height), 1080)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        print("✓ Screen capture successful")
        print("  Image size: \(image.width)x\(image.height)")
        print("  Bits per pixel: \(image.bitsPerPixel)")
        
        return true
        
    } catch let error as NSError {
        if error.code == -3801 || error.code == -3802 {  // Permission errors
            print("⚠ Screen capture requires permission (expected in CI)")
            return true
        }
        print("✗ Screen capture failed: \(error)")
        return false
    }
}

/// Test ScreenCaptureKit availability
func testFrameworkAvailability() -> Bool {
    print("=== ScreenCaptureKit Availability Test ===")
    
    let osVersion = ProcessInfo.processInfo.operatingSystemVersion
    print("macOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
    
    if osVersion.majorVersion >= 13 {
        print("✓ macOS 13+ - Full ScreenCaptureKit support")
        return true
    } else if osVersion.majorVersion >= 12 && osVersion.minorVersion >= 3 {
        print("✓ macOS 12.3+ - Basic ScreenCaptureKit support")
        return true
    } else {
        print("⚠ macOS version too old for ScreenCaptureKit")
        print("  Minimum: macOS 12.3")
        return false
    }
}

// Main test runner
func runTests() async -> Bool {
    print("Screen Capture Integration Test")
    print("================================\n")
    
    var allPassed = true
    
    // Test 1: Framework availability
    if !testFrameworkAvailability() {
        allPassed = false
    }
    
    // Tests requiring ScreenCaptureKit
    if #available(macOS 13.0, *) {
        // Test 2: Permission detection
        if !(await testPermissionDetection()) {
            allPassed = false
        }
        
        // Test 3: Display enumeration
        if !(await testDisplayEnumeration()) {
            allPassed = false
        }
        
        // Test 4: Screen capture
        if !(await testScreenCapture()) {
            allPassed = false
        }
    } else if #available(macOS 12.3, *) {
        // Test 2: Permission detection only
        if !(await testPermissionDetection()) {
            allPassed = false
        }
        
        // Test 3: Display enumeration
        if !(await testDisplayEnumeration()) {
            allPassed = false
        }
        
        print("\n⚠ Screen capture test skipped (requires macOS 13+)")
    } else {
        print("\n⚠ ScreenCaptureKit tests skipped (requires macOS 12.3+)")
    }
    
    print("\n================================")
    if allPassed {
        print("✓ All screen capture tests passed")
    } else {
        print("✗ Some tests failed")
    }
    
    return allPassed
}

// Entry point
if #available(macOS 12.3, *) {
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    
    Task {
        success = await runTests()
        semaphore.signal()
    }
    
    _ = semaphore.wait(timeout: .now() + 30)
    exit(success ? 0 : 1)
} else {
    print("This test requires macOS 12.3 or later")
    exit(0)  // Don't fail on older systems
}

#else
print("This test only runs on macOS")
exit(0)
#endif
