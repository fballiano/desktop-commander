import AppKit
import Foundation
import KeyboardShortcuts
import Observation

/// The one controller of the app.
///
/// Every way in calls the same methods here: the menu, a global hot key, an
/// AppleScript command, a Shortcuts action. So each command has exactly one
/// code path.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let preferences: Preferences
    let loginItem: LoginItem

    // The switches.
    let keepAwake: KeepAwake
    let desktopWidgets: DefaultsSwitch
    let desktopIcons: DefaultsSwitch
    let hiddenFiles: DefaultsSwitch
    let hiddenWindows: HiddenWindows
    let keyboardLock: KeyboardLock
    let screenCleaning: ScreenCleaning

    // The windows.
    @ObservationIgnored let windows: WindowMover

    @ObservationIgnored private let settingsWindow = SettingsWindowController()
    @ObservationIgnored private var didBootstrap = false

    init(
        preferences: Preferences? = nil,
        keepAwake: KeepAwake? = nil,
        windows: WindowMover? = nil
    ) {
        let preferences = preferences ?? Preferences()

        self.preferences = preferences
        self.loginItem = LoginItem()
        self.keepAwake = keepAwake ?? KeepAwake()
        self.desktopWidgets = .desktopWidgets()
        self.desktopIcons = .desktopIcons()
        self.hiddenFiles = .hiddenFiles()
        self.hiddenWindows = HiddenWindows()
        self.keyboardLock = KeyboardLock()
        self.screenCleaning = ScreenCleaning()
        self.windows = windows ?? WindowMover(
            window: FocusedWindow(),
            gap: CGFloat(preferences.windowGap)
        )

        self.keepAwake.duration = preferences.keepAwakeDuration
        self.keyboardLock.timeout = TimeInterval(preferences.keyboardLockTimeout)
    }

    // MARK: - Launch

    /// Wires the hot keys and the login item.
    func bootstrap() {
        guard !didBootstrap, !RuntimeEnvironment.isRunningTests else { return }
        didBootstrap = true

        applyDefaultLoginItem()
        applyDefaultShortcuts()
        registerHotKeys()
    }

    /// Starts the app at login, once.
    ///
    /// The app has no dock icon and no window, so a user who does not find it
    /// after a restart thinks it is gone. The first launch therefore registers
    /// the login item. A later change by the user stays: the flag says that the
    /// default was applied, so the app never sets it again.
    private func applyDefaultLoginItem() {
        guard !preferences.appliedDefaultLoginItem else { return }

        if loginItem.isEnabled {
            preferences.appliedDefaultLoginItem = true
            return
        }

        loginItem.isEnabled = true

        // Only a registration that worked counts. A failure is tried again at
        // the next launch.
        preferences.appliedDefaultLoginItem = loginItem.isEnabled
    }

    /// Writes the three starting hot keys, once.
    ///
    /// Only three of the seventeen window commands get one, and only at the
    /// first launch. The same rule as the login item: a user who clears a
    /// shortcut must find it cleared at the next launch.
    private func applyDefaultShortcuts() {
        guard !preferences.appliedDefaultShortcuts else { return }
        preferences.appliedDefaultShortcuts = true

        let modifiers: NSEvent.ModifierFlags = [.control, .option, .command]
        let defaults: [(WindowSlot, KeyboardShortcuts.Key)] = [
            (.leftHalf, .leftArrow),
            (.rightHalf, .rightArrow),
            (.maximize, .f),
        ]

        for (slot, key) in defaults {
            let name = KeyboardShortcuts.Name.slot(slot)

            // A shortcut the user already recorded is never overwritten.
            guard KeyboardShortcuts.getShortcut(for: name) == nil else { continue }

            KeyboardShortcuts.setShortcut(
                .init(key, modifiers: modifiers),
                for: name
            )
        }
    }

    private func registerHotKeys() {
        KeyboardShortcuts.onKeyDown(for: .keepAwake) { [weak self] in
            MainActor.assumeIsolated { self?.toggleKeepAwake() }
        }
        KeyboardShortcuts.onKeyDown(for: .desktopWidgets) { [weak self] in
            MainActor.assumeIsolated { self?.toggleDesktopWidgets() }
        }
        KeyboardShortcuts.onKeyDown(for: .desktopIcons) { [weak self] in
            MainActor.assumeIsolated { self?.toggleDesktopIcons() }
        }
        KeyboardShortcuts.onKeyDown(for: .hiddenFiles) { [weak self] in
            MainActor.assumeIsolated { self?.toggleHiddenFiles() }
        }
        KeyboardShortcuts.onKeyDown(for: .hiddenWindows) { [weak self] in
            MainActor.assumeIsolated { self?.toggleHiddenWindows() }
        }
        KeyboardShortcuts.onKeyDown(for: .keyboardLock) { [weak self] in
            MainActor.assumeIsolated { self?.toggleKeyboardLock() }
        }
        KeyboardShortcuts.onKeyDown(for: .screenSaver) { [weak self] in
            MainActor.assumeIsolated { self?.startScreenSaver() }
        }
        KeyboardShortcuts.onKeyDown(for: .screenCleaning) { [weak self] in
            MainActor.assumeIsolated { self?.toggleScreenCleaning() }
        }

        for slot in WindowSlot.allCases {
            KeyboardShortcuts.onKeyDown(for: .slot(slot)) { [weak self] in
                MainActor.assumeIsolated { _ = self?.move(to: slot) }
            }
        }
        KeyboardShortcuts.onKeyDown(for: .nextScreen) { [weak self] in
            MainActor.assumeIsolated { _ = self?.moveToNextScreen() }
        }
        KeyboardShortcuts.onKeyDown(for: .undoMove) { [weak self] in
            MainActor.assumeIsolated { _ = self?.undoMove() }
        }
    }

    // MARK: - The switches

    func setKeepAwake(_ on: Bool) {
        keepAwake.set(on, duration: preferences.keepAwakeDuration)
    }

    func toggleKeepAwake() {
        setKeepAwake(!keepAwake.isOn)
    }

    /// Changes the length and, when the switch is already on, applies it now.
    func setKeepAwakeDuration(_ duration: KeepAwake.Duration) {
        preferences.keepAwakeDuration = duration

        guard keepAwake.isOn else {
            keepAwake.duration = duration
            return
        }

        keepAwake.set(true, duration: duration)
    }

    func setDesktopWidgets(_ on: Bool) { desktopWidgets.set(on) }
    func toggleDesktopWidgets() { desktopWidgets.toggle() }

    func setDesktopIcons(_ on: Bool) { desktopIcons.set(on) }
    func toggleDesktopIcons() { desktopIcons.toggle() }

    func setHiddenFiles(_ on: Bool) { hiddenFiles.set(on) }
    func toggleHiddenFiles() { hiddenFiles.toggle() }

    func setHiddenWindows(_ on: Bool) { hiddenWindows.set(on) }
    func toggleHiddenWindows() { hiddenWindows.toggle() }

    func setKeyboardLock(_ on: Bool) {
        keyboardLock.timeout = TimeInterval(preferences.keyboardLockTimeout)
        keyboardLock.set(on)
    }

    func toggleKeyboardLock() {
        setKeyboardLock(!keyboardLock.isOn)
    }

    func startScreenSaver() {
        ScreenSaver.start()
    }

    func setScreenCleaning(_ on: Bool) { screenCleaning.set(on) }
    func toggleScreenCleaning() { screenCleaning.toggle() }

    /// Reads the settings of the system again.
    ///
    /// The user can change the same thing in System Settings or in Finder, so
    /// the menu reads the truth each time it opens instead of trusting what it
    /// wrote last.
    func refreshSwitches() {
        desktopWidgets.refresh()
        desktopIcons.refresh()
        hiddenFiles.refresh()
    }

    // MARK: - The windows

    /// Puts the front window into the slot.
    ///
    /// The Accessibility prompt appears here, at the first window command, and
    /// never at launch. A user who only wants the switches never sees it.
    @discardableResult
    func move(to slot: WindowSlot) -> Bool {
        guard requestAccessibility() else { return false }

        windows.gap = CGFloat(preferences.windowGap)

        return windows.move(to: slot)
    }

    @discardableResult
    func moveToNextScreen() -> Bool {
        guard requestAccessibility() else { return false }

        return windows.moveToNextScreen()
    }

    @discardableResult
    func undoMove() -> Bool {
        guard requestAccessibility() else { return false }

        return windows.undo()
    }

    var canUndoMove: Bool { windows.canUndo }

    var isAccessibilityTrusted: Bool { Accessibility.isTrusted }

    func openAccessibilitySettings() {
        Accessibility.openSettings()
    }

    private func requestAccessibility() -> Bool {
        guard !Accessibility.isTrusted else { return true }

        // macOS shows its own sheet at most once for each launch, so a second
        // hot key after a refusal would do nothing at all and look broken. This
        // alert always appears, and it carries the button that opens the pane.
        Accessibility.request()
        Accessibility.showAlert()

        return false
    }

    // MARK: - Panels

    func showSettings() {
        settingsWindow.present(model: self)
    }

    func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
