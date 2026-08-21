import CoreGraphics
import Foundation
import Testing
@testable import DesktopCommander

/// Only the key matching is tested here. The tap itself is one call into
/// CoreGraphics and it needs a real session and the Accessibility permission,
/// so it is checked by hand.
@Suite("KeyboardLock keys")
struct KeyboardLockTests {
    private let keyDown = CGEventType.keyDown.rawValue
    private let keyUp = CGEventType.keyUp.rawValue

    private let allThree: UInt64 = CGEventFlags([.maskControl, .maskAlternate, .maskCommand]).rawValue
    private let forceQuit: UInt64 = CGEventFlags([.maskCommand, .maskAlternate]).rawValue

    @Test("Control, Option, Command and U unlock")
    func unlocks() {
        #expect(KeyboardLock.isUnlock(kind: keyDown, key: KeyboardLock.unlockKey, flags: allThree))
    }

    @Test("The same keys going up do not unlock")
    func onlyKeyDown() {
        #expect(!KeyboardLock.isUnlock(kind: keyUp, key: KeyboardLock.unlockKey, flags: allThree))
    }

    @Test("U on its own does not unlock")
    func needsModifiers() {
        #expect(!KeyboardLock.isUnlock(kind: keyDown, key: KeyboardLock.unlockKey, flags: 0))
    }

    @Test("Two of the three modifiers are not enough")
    func needsEveryModifier() {
        let two = CGEventFlags([.maskControl, .maskCommand]).rawValue

        #expect(!KeyboardLock.isUnlock(kind: keyDown, key: KeyboardLock.unlockKey, flags: two))
    }

    @Test("Another key with the same modifiers does not unlock")
    func needsTheRightKey() {
        #expect(!KeyboardLock.isUnlock(kind: keyDown, key: 0, flags: allThree))
    }

    @Test("An extra modifier still unlocks")
    func extraModifier() {
        let withShift = CGEventFlags(
            [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        ).rawValue

        #expect(KeyboardLock.isUnlock(kind: keyDown, key: KeyboardLock.unlockKey, flags: withShift))
    }

    // MARK: - Force Quit

    @Test("Command, Option and Escape are Force Quit")
    func forceQuitIsRecognised() {
        #expect(KeyboardLock.isForceQuit(kind: keyDown, key: 53, flags: forceQuit))
    }

    @Test("Force Quit and the unlock keys are not the same combination")
    func differentCombinations() {
        #expect(!KeyboardLock.isUnlock(kind: keyDown, key: 53, flags: forceQuit))
        #expect(!KeyboardLock.isForceQuit(kind: keyDown, key: KeyboardLock.unlockKey, flags: allThree))
    }

    @Test("The hint names the keys that unlock")
    func hint() {
        #expect(KeyboardLock.unlockHint.contains("U"))
    }
}
