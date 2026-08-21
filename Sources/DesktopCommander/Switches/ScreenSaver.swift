import AppKit
import Foundation

/// Starts the screen saver.
///
/// This is a command, not a switch. The screen saver ends when the user moves
/// the mouse, so there is nothing to turn off.
@MainActor
enum ScreenSaver {
    static let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")

    /// `true` when the engine is where macOS keeps it.
    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func start() {
        guard !RuntimeEnvironment.isRunningTests, isAvailable else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
