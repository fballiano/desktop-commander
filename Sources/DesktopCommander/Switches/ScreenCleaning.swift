import AppKit
import Foundation
import Observation
import SwiftUI

/// Covers every screen with a black window, so you can wipe the screen.
///
/// The window takes the mouse and the keys itself, so a cloth over the display
/// presses nothing and clicks nothing. This needs no permission: a window that
/// covers the screen and is the key window already receives the events.
///
/// The keyboard lock is the other half of the same idea. That one leaves the
/// screen alone and needs a tap, so it needs the Accessibility permission.
@MainActor
@Observable
final class ScreenCleaning {
    private(set) var isOn = false

    /// Called when the overlay closes, whatever closed it.
    var onEnd: (() -> Void)?

    @ObservationIgnored private var windows: [NSWindow] = []
    @ObservationIgnored private var monitor: Any?

    func set(_ on: Bool) {
        on ? start() : stop()
    }

    func toggle() {
        set(!isOn)
    }

    // MARK: - The overlay

    private func start() {
        guard !isOn, !RuntimeEnvironment.isRunningTests else { return }

        windows = NSScreen.screens.map(makeWindow)
        isOn = true

        NSApp.activate()
        windows.first?.makeKeyAndOrderFront(nil)

        // The overlay is the key window, so it receives the keys of the user.
        // Any key ends it, which is what a person does when they are finished:
        // they press something.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        for window in windows {
            window.orderOut(nil)
        }
        windows = []

        guard isOn else { return }

        isOn = false
        onEnd?()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = CleaningWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false

        // Above everything, including a full screen application, and on every
        // Space, so a wipe of the screen never uncovers a window.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        window.contentView = NSHostingView(rootView: ScreenCleaningView())
        window.setFrame(screen.frame, display: true)

        return window
    }
}

/// A borderless window cannot become key unless it says that it can. Without
/// this the keys go to the application behind the black screen.
private final class CleaningWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
