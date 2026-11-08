import AppKit
import SwiftUI

/// Shows `SettingsView` in its own window.
///
/// SwiftUI has a `Settings` scene and a `SettingsLink` button, but they do not
/// work in an agent app. The app is never the active application while the user
/// uses the menu bar, and `SettingsLink` opens the window without activating the
/// app. The window therefore opened behind the windows of the front application
/// and looked like it never opened at all. It appeared only later, together with
/// the About panel, because `showAbout()` calls `NSApp.activate()`.
///
/// This controller follows `ScreenCleaningController`: AppKit owns the window, so the
/// code activates the app and orders the window to the front by hand.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    /// Shows the window, and creates it on the first call. A second call brings
    /// the same window forward instead of opening another one.
    func present(model: AppModel) {
        let window = window ?? makeWindow(model: model)
        self.window = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        // `NSHostingView.fittingSize` measures the SwiftUI layout once, so the
        // window opens at the right size. The other way, an
        // `NSHostingController` with `sizingOptions = [.preferredContentSize]`,
        // makes the window and the SwiftUI layout resize each other without
        // end, and AppKit then throws "more Update Constraints in Window passes
        // than there are views in the window".
        let content = NSHostingView(rootView: SettingsView(model: model))
        content.setFrameSize(content.fittingSize)

        let window = NSWindow(
            contentRect: content.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = content
        window.title = String(localized: "Deskyard Preferences")
        // The window is kept for the next call, so it must survive its close.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
