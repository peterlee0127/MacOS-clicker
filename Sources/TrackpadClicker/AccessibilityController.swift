import ApplicationServices
import AppKit
import Foundation

enum AccessibilityController {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func request() {
        // The exported constant is imported as mutable global state in Swift 6.
        // Its documented string value avoids crossing that concurrency boundary.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openTrackpadSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
