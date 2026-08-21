import Foundation
import Testing
@testable import DesktopCommander

@MainActor
@Suite("DefaultsSwitch")
struct DefaultsSwitchTests {
    private func makeDefaults() -> UserDefaults {
        let name = "desktop-commander.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Counts how many times the owner of the domain was asked to reload.
    private final class Counter {
        var count = 0
    }

    // MARK: - A plain switch

    @Test("A key that was never written reads the value of the system")
    func systemDefault() {
        let plain = DefaultsSwitch(
            domain: "test", keys: ["k"], systemDefault: false, defaults: makeDefaults()
        )
        #expect(!plain.isOn)

        let onByDefault = DefaultsSwitch(
            domain: "test", keys: ["k"], systemDefault: true, defaults: makeDefaults()
        )
        #expect(onByDefault.isOn)
    }

    @Test("On writes true, off writes false")
    func writesThrough() {
        let defaults = makeDefaults()
        let plain = DefaultsSwitch(domain: "test", keys: ["k"], defaults: defaults)

        plain.set(true)
        #expect(defaults.bool(forKey: "k"))
        #expect(plain.isOn)

        plain.set(false)
        #expect(!defaults.bool(forKey: "k"))
        #expect(!plain.isOn)
    }

    @Test("Two keys are written together")
    func twoKeys() {
        let defaults = makeDefaults()
        let plain = DefaultsSwitch(domain: "test", keys: ["a", "b"], defaults: defaults)

        plain.set(true)

        #expect(defaults.bool(forKey: "a"))
        #expect(defaults.bool(forKey: "b"))
    }

    @Test("The switch goes both ways")
    func toggles() {
        let plain = DefaultsSwitch(domain: "test", keys: ["k"], defaults: makeDefaults())

        plain.toggle()
        #expect(plain.isOn)

        plain.toggle()
        #expect(!plain.isOn)
    }

    // MARK: - An inverted switch

    @Test("An inverted switch writes the opposite value")
    func inverted() {
        let defaults = makeDefaults()
        // "Hide the desktop icons" is on when CreateDesktop is false.
        let hide = DefaultsSwitch(
            domain: "test",
            keys: ["CreateDesktop"],
            isInverted: true,
            systemDefault: true,
            defaults: defaults
        )

        #expect(!hide.isOn) // The icons are there, so "hide" is off.

        hide.set(true)
        #expect(defaults.bool(forKey: "CreateDesktop") == false)
        #expect(hide.isOn)

        hide.set(false)
        #expect(defaults.bool(forKey: "CreateDesktop") == true)
        #expect(!hide.isOn)
    }

    // MARK: - The restart

    @Test("The owner is asked to reload only when the value really changed")
    func restartsOnce() {
        let counter = Counter()
        let plain = DefaultsSwitch(
            domain: "test",
            keys: ["k"],
            defaults: makeDefaults(),
            restart: { counter.count += 1 }
        )

        plain.set(true)
        #expect(counter.count == 1)

        // The same value again changes nothing, so Finder is left alone.
        plain.set(true)
        #expect(counter.count == 1)

        plain.set(false)
        #expect(counter.count == 2)
    }

    // MARK: - Reading the system again

    @Test("A change made elsewhere is picked up")
    func refresh() {
        let defaults = makeDefaults()
        let plain = DefaultsSwitch(domain: "test", keys: ["k"], defaults: defaults)

        #expect(!plain.isOn)

        // The user changed the same setting in System Settings.
        defaults.set(true, forKey: "k")

        plain.refresh()
        #expect(plain.isOn)
    }

    // MARK: - The three real switches

    @Test("The widgets switch writes both keys of WindowManager")
    func widgets() {
        let defaults = makeDefaults()
        let widgets = DefaultsSwitch.desktopWidgets(defaults: defaults)

        widgets.set(true)

        #expect(defaults.bool(forKey: "StandardHideWidgets"))
        #expect(defaults.bool(forKey: "StageManagerHideWidgets"))
    }

    @Test("The icons switch is inverted, the hidden files switch is not")
    func finderSwitches() {
        let defaults = makeDefaults()
        let icons = DefaultsSwitch.desktopIcons(defaults: defaults, restart: {})
        let files = DefaultsSwitch.hiddenFiles(defaults: defaults, restart: {})

        #expect(icons.isInverted)
        #expect(!files.isInverted)
        #expect(icons.systemDefault)   // Finder draws the desktop by default.
        #expect(!files.systemDefault)  // The hidden files are hidden by default.
        #expect(icons.domain == "com.apple.finder")
        #expect(files.domain == "com.apple.finder")
    }
}
