import Foundation
import KeyboardShortcuts

/// The global hot keys.
///
/// `KeyboardShortcuts` stores the chosen combinations in `UserDefaults` and turns
/// them off while the user records a new one.
extension KeyboardShortcuts.Name {
    // The switches.
    static let keepAwake = Self("keepAwake")
    static let desktopWidgets = Self("desktopWidgets")
    static let desktopIcons = Self("desktopIcons")
    static let hiddenFiles = Self("hiddenFiles")
    static let hiddenWindows = Self("hiddenWindows")
    static let keyboardLock = Self("keyboardLock")
    static let screenSaver = Self("screenSaver")
    static let screenCleaning = Self("screenCleaning")

    // The windows.
    static let nextScreen = Self("windowNextScreen")
    static let undoMove = Self("windowUndo")

    /// One name for each slot, built from the name of the case, so a new slot
    /// gets its hot key without a second list to keep in step.
    static func slot(_ slot: WindowSlot) -> Self {
        Self("window.\(slot.rawValue)")
    }

    /// Every name the Shortcuts tab shows for the switches, in order.
    ///
    /// This is computed, not stored, because the titles are translated. A stored
    /// property would read the language once and keep it.
    static var switchNames: [(name: Self, title: String)] {
        [
            (.keepAwake, String(localized: "Keep awake")),
            (.desktopWidgets, String(localized: "Hide the desktop widgets")),
            (.desktopIcons, String(localized: "Hide the desktop icons")),
            (.hiddenFiles, String(localized: "Show the hidden files")),
            (.hiddenWindows, String(localized: "Hide the windows")),
            (.keyboardLock, String(localized: "Keyboard lock")),
            (.screenSaver, String(localized: "Screen saver")),
            (.screenCleaning, String(localized: "Clean the screen")),
        ]
    }
}
