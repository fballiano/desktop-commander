import ApplicationServices
import AppKit
import Foundation

/// The Accessibility permission.
///
/// Two features need it: every window command, and the keyboard lock. The other
/// six switches do not. The application therefore never asks at launch. It asks
/// the first time you use one of the two, so a user who only wants the switches
/// is never shown a permission sheet.
@MainActor
enum Accessibility {
    /// `true` when macOS lets this application drive other applications.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Reads the state and, when it is off, asks macOS to show the sheet that
    /// sends the user to System Settings.
    ///
    /// macOS shows the sheet at most once for each launch, so a second call
    /// after a refusal does nothing. `openSettings()` is the way back.
    @discardableResult
    static func request() -> Bool {
        guard !RuntimeEnvironment.isRunningTests else { return false }

        // `kAXTrustedCheckOptionPrompt` is a global `var` in the C header, so
        // Swift 6 refuses to read it. The string it holds is part of the public
        // interface and does not change.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    /// Says what is missing and offers the way to fix it.
    ///
    /// This is not a notification. The application posts none, so it never asks
    /// for the notification permission. An alert is also better here: a banner
    /// carries no button, and the one thing the user needs is the button that
    /// opens the pane.
    static func showAlert() {
        guard !RuntimeEnvironment.isRunningTests else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Deskyard needs the Accessibility permission")
        alert.informativeText = String(localized: "accessibility.alert.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Open Settings…"))
        alert.addButton(withTitle: String(localized: "Not now"))

        NSApp.activate()

        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    /// Opens System Settings at Privacy & Security → Accessibility.
    static func openSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}
