import AppKit
import Foundation
import Observation

/// Stops the keyboard from reaching any application.
///
/// It is for cleaning the keys, so the mouse keeps working and the screen keeps
/// showing what it showed.
///
/// A `CGEventTap` is the only way to swallow a key before an application sees
/// it, and it needs the Accessibility permission.
///
/// Three ways out, because a keyboard that cannot be unlocked is a broken Mac:
///
/// 1. Control, Option, Command and U together end the lock.
/// 2. A timer ends the lock, whatever happens.
/// 3. Command, Option and Escape together are **never** swallowed, so Force
///    Quit always works. The tap dies with the process, so ending the
///    application gives the keyboard back at once.
@MainActor
@Observable
final class KeyboardLock {
    /// How long the lock lasts before it ends by itself.
    nonisolated static let defaultTimeout: TimeInterval = 60

    /// The key that ends the lock, together with every modifier below.
    nonisolated static let unlockKey: CGKeyCode = 32 // U.

    /// The modifiers that must be held with the key.
    nonisolated static let unlockModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    /// Escape, the key of Force Quit.
    nonisolated private static let escapeKey: CGKeyCode = 53

    /// The modifiers of Force Quit.
    nonisolated private static let forceQuitModifiers: CGEventFlags = [.maskCommand, .maskAlternate]

    private(set) var isOn = false

    /// Set when the lock could not start, so the menu can say why.
    private(set) var lastError: String?

    /// How long the lock lasts. `0` means no end, which the settings do not
    /// offer, but the type accepts.
    var timeout: TimeInterval = KeyboardLock.defaultTimeout

    /// Called each time the lock ends, however it ended.
    var onUnlock: (() -> Void)?

    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var timer: Timer?

    func set(_ on: Bool) {
        on ? lock() : unlock()
    }

    func toggle() {
        set(!isOn)
    }

    // MARK: - The lock

    private func lock() {
        guard !isOn, !RuntimeEnvironment.isRunningTests else { return }

        guard Accessibility.request() else {
            lastError = String(
                localized: "Deskyard needs the Accessibility permission to lock the keyboard."
            )
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: KeyboardLock.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = String(
                localized: "macOS refused the keyboard tap. Check the Accessibility permission."
            )
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        lastError = nil
        isOn = true

        startTimer()
    }

    private func unlock() {
        timer?.invalidate()
        timer = nil

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        tap = nil
        source = nil

        guard isOn else { return }

        isOn = false
        onUnlock?()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = nil

        guard timeout > 0 else { return }

        let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.unlock() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - One event

    /// The C callback of the tap.
    ///
    /// It runs on the main run loop, because that is where the source was added.
    /// A `CGEvent` is not `Sendable`, so nothing but plain numbers crosses into
    /// the main actor: the kind of the event, the key and the modifiers.
    private static let tapCallback: CGEventTapCallBack = { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }

        let lock = Unmanaged<KeyboardLock>.fromOpaque(context).takeUnretainedValue()

        let key = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        let kind = type.rawValue

        let letThrough = MainActor.assumeIsolated {
            lock.decide(kind: kind, key: key, flags: flags)
        }

        return letThrough ? Unmanaged.passUnretained(event) : nil
    }

    /// `true` lets the event through, `false` swallows it.
    fileprivate func decide(kind: UInt32, key: CGKeyCode, flags: UInt64) -> Bool {
        // macOS turns a tap off when it takes too long or when the user denies
        // the permission later. Turning it on again is the documented answer.
        if kind == CGEventType.tapDisabledByTimeout.rawValue
            || kind == CGEventType.tapDisabledByUserInput.rawValue {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        }

        // Force Quit always goes through. It is the way out that does not need
        // this application to be working.
        if Self.isForceQuit(kind: kind, key: key, flags: flags) {
            return true
        }

        if Self.isUnlock(kind: kind, key: key, flags: flags) {
            unlock()
            return false
        }

        return false
    }

    nonisolated static func isUnlock(kind: UInt32, key: CGKeyCode, flags: UInt64) -> Bool {
        matches(kind: kind, key: key, flags: flags, wanted: unlockKey, modifiers: unlockModifiers)
    }

    nonisolated static func isForceQuit(kind: UInt32, key: CGKeyCode, flags: UInt64) -> Bool {
        matches(kind: kind, key: key, flags: flags, wanted: escapeKey, modifiers: forceQuitModifiers)
    }

    nonisolated private static func matches(
        kind: UInt32,
        key: CGKeyCode,
        flags: UInt64,
        wanted: CGKeyCode,
        modifiers: CGEventFlags
    ) -> Bool {
        guard kind == CGEventType.keyDown.rawValue else { return false }
        guard key == wanted else { return false }

        return CGEventFlags(rawValue: flags).isSuperset(of: modifiers)
    }

    /// The text that tells the user how to get the keyboard back.
    nonisolated static var unlockHint: String {
        String(localized: "Press Control, Option, Command and U together to unlock the keyboard.")
    }
}
