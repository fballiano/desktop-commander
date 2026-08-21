import Foundation
import Testing
@testable import DesktopCommander

/// An application that lives in memory.
@MainActor
private final class FakeApplication: HideableApplication {
    let bundleIdentifier: String?
    let isRegular: Bool
    var isHidden: Bool

    /// `false` makes `hide()` fail, as an application that is quitting does.
    var canHide: Bool

    init(
        bundleIdentifier: String?,
        isRegular: Bool = true,
        isHidden: Bool = false,
        canHide: Bool = true
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.isRegular = isRegular
        self.isHidden = isHidden
        self.canHide = canHide
    }

    @discardableResult
    func hideApplication() -> Bool {
        guard canHide else { return false }
        isHidden = true
        return true
    }

    @discardableResult
    func unhideApplication() -> Bool {
        isHidden = false
        return true
    }
}

@MainActor
@Suite("HiddenWindows")
struct HiddenWindowsTests {
    @Test("It hides every ordinary application")
    func hidesEveryone() {
        let safari = FakeApplication(bundleIdentifier: "com.apple.Safari")
        let mail = FakeApplication(bundleIdentifier: "com.apple.mail")
        let switcher = HiddenWindows(applications: { [safari, mail] })

        switcher.set(true)

        #expect(switcher.isOn)
        #expect(safari.isHidden)
        #expect(mail.isHidden)
    }

    @Test("It leaves an agent application alone, because it has no window")
    func skipsAgents() {
        let agent = FakeApplication(bundleIdentifier: "com.example.agent", isRegular: false)
        let switcher = HiddenWindows(applications: { [agent] })

        switcher.set(true)

        #expect(!agent.isHidden)
    }

    @Test("An application without a bundle identifier is left alone")
    func skipsUnnamed() {
        let unnamed = FakeApplication(bundleIdentifier: nil)
        let switcher = HiddenWindows(applications: { [unnamed] })

        switcher.set(true)

        #expect(!unnamed.isHidden)
    }

    @Test("Off brings back only what it hid")
    func bringsBackOnlyItsOwn() {
        // The user had already hidden Mail before the switch was used.
        let safari = FakeApplication(bundleIdentifier: "com.apple.Safari")
        let mail = FakeApplication(bundleIdentifier: "com.apple.mail", isHidden: true)
        let switcher = HiddenWindows(applications: { [safari, mail] })

        switcher.set(true)
        #expect(switcher.hidden == ["com.apple.Safari"])

        switcher.set(false)

        #expect(!safari.isHidden)
        // Mail stays hidden. The user hid it, not the switch.
        #expect(mail.isHidden)
    }

    @Test("An application that refuses to hide is not brought back later")
    func skipsFailures() {
        let stubborn = FakeApplication(bundleIdentifier: "com.example.stubborn", canHide: false)
        let switcher = HiddenWindows(applications: { [stubborn] })

        switcher.set(true)

        #expect(switcher.hidden.isEmpty)
    }

    @Test("The switch goes both ways")
    func toggles() {
        let safari = FakeApplication(bundleIdentifier: "com.apple.Safari")
        let switcher = HiddenWindows(applications: { [safari] })

        switcher.toggle()
        #expect(switcher.isOn)

        switcher.toggle()
        #expect(!switcher.isOn)
        #expect(switcher.hidden.isEmpty)
    }
}
