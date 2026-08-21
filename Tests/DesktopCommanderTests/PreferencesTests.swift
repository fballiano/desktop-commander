import Foundation
import Testing
@testable import DesktopCommander

@MainActor
@Suite("Preferences")
struct PreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let name = "desktop-commander.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("The application starts with a safe set of values")
    func defaultValues() {
        let preferences = Preferences(defaults: makeDefaults())

        #expect(preferences.windowGap == Preferences.defaultWindowGap)
        #expect(preferences.keepAwakeDuration == .forever)
        #expect(preferences.keyboardLockTimeout == Preferences.defaultKeyboardLockTimeout)
        #expect(preferences.showNotifications)

        // Both defaults are applied at the first launch, so both flags start
        // false and become true once.
        #expect(!preferences.appliedDefaultLoginItem)
        #expect(!preferences.appliedDefaultShortcuts)
    }

    @Test("A change is written to the store")
    func writesThrough() {
        let defaults = makeDefaults()
        let preferences = Preferences(defaults: defaults)

        preferences.windowGap = 12
        preferences.keepAwakeDuration = .twoHours
        preferences.showNotifications = false

        #expect(defaults.integer(forKey: Preferences.Key.windowGap) == 12)

        // A new instance reads the same values back.
        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.windowGap == 12)
        #expect(reloaded.keepAwakeDuration == .twoHours)
        #expect(!reloaded.showNotifications)
    }

    @Test("The gap has two ends")
    func gapLimits() {
        let preferences = Preferences(defaults: makeDefaults())

        preferences.windowGap = -5
        #expect(preferences.windowGap == 0)

        preferences.windowGap = 1000
        #expect(preferences.windowGap == Preferences.maximumWindowGap)
    }

    @Test("The keyboard lock never lasts less than ten seconds")
    func lockTimeoutLimits() {
        let preferences = Preferences(defaults: makeDefaults())

        preferences.keyboardLockTimeout = 0
        #expect(preferences.keyboardLockTimeout == 10)

        preferences.keyboardLockTimeout = 10_000
        #expect(preferences.keyboardLockTimeout == 600)
    }

    @Test("An unknown length falls back to no end")
    func unknownDuration() {
        let defaults = makeDefaults()
        defaults.set("something else", forKey: Preferences.Key.keepAwakeDuration)

        #expect(Preferences(defaults: defaults).keepAwakeDuration == .forever)
    }

    @Test("The two flags are written once and stay")
    func appliedFlags() {
        let defaults = makeDefaults()
        let preferences = Preferences(defaults: defaults)

        preferences.appliedDefaultLoginItem = true
        preferences.appliedDefaultShortcuts = true

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.appliedDefaultLoginItem)
        #expect(reloaded.appliedDefaultShortcuts)
    }
}
