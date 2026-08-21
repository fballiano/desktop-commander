import AppKit
import Foundation
import Observation

/// A switch that lives in the settings of another application.
///
/// Three of the switches work the same way: write a key into a preference domain
/// of the system, then make the application that owns it read the new value.
/// `com.apple.finder` needs a restart. `com.apple.WindowManager` reads the change
/// by itself.
///
/// The domain and the restart come in through the initialiser, so a test gives a
/// throw-away `UserDefaults` and counts the restarts without ending Finder.
@MainActor
@Observable
final class DefaultsSwitch {
    /// Asks the owner of the domain to read its settings again.
    typealias Restart = @MainActor () -> Void

    /// The bundle identifier of the domain, for example `com.apple.finder`.
    let domain: String

    /// The keys to write. Some switches need two: the widgets have one key for
    /// the ordinary desktop and one for Stage Manager.
    let keys: [String]

    /// `true` when the switch being **on** means writing `false`.
    ///
    /// "Hide the desktop icons" is on when `CreateDesktop` is `false`, so the
    /// menu and the key disagree. This flag holds that difference in one place.
    let isInverted: Bool

    /// What the key means when it was never written.
    let systemDefault: Bool

    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let restart: Restart

    /// The value the menu shows. It is read from the system at each launch.
    private(set) var isOn: Bool = false

    init(
        domain: String,
        keys: [String],
        isInverted: Bool = false,
        systemDefault: Bool = false,
        defaults: UserDefaults? = nil,
        restart: @escaping Restart = {}
    ) {
        self.domain = domain
        self.keys = keys
        self.isInverted = isInverted
        self.systemDefault = systemDefault
        self.defaults = defaults ?? UserDefaults(suiteName: domain)
        self.restart = restart

        isOn = read()
    }

    /// Reads the state of the system.
    func read() -> Bool {
        guard let defaults, let first = keys.first else { return false }

        let stored = defaults.object(forKey: first) as? Bool ?? systemDefault

        return isInverted ? !stored : stored
    }

    /// Reads the system again. The user can change the same setting in System
    /// Settings or in Finder, so the menu must not trust its own memory.
    func refresh() {
        isOn = read()
    }

    func set(_ on: Bool) {
        guard let defaults else { return }
        guard on != read() else {
            isOn = on
            return
        }

        let stored = isInverted ? !on : on

        for key in keys {
            defaults.set(stored, forKey: key)
        }
        defaults.synchronize()

        isOn = on
        restart()
    }

    func toggle() {
        set(!isOn)
    }
}

extension DefaultsSwitch {
    /// Hide the widgets of the desktop.
    ///
    /// `StandardHideWidgets` is the ordinary desktop and `StageManagerHideWidgets`
    /// is Stage Manager. System Settings writes both, so this writes both.
    /// WindowManager reads the change on its own.
    static func desktopWidgets(defaults: UserDefaults? = nil) -> DefaultsSwitch {
        DefaultsSwitch(
            domain: "com.apple.WindowManager",
            keys: ["StandardHideWidgets", "StageManagerHideWidgets"],
            defaults: defaults
        )
    }

    /// Hide the icons of the desktop.
    ///
    /// The key says whether Finder **draws** the desktop, so the switch is
    /// inverted: hidden icons mean `CreateDesktop` is `false`.
    static func desktopIcons(defaults: UserDefaults? = nil, restart: @escaping Restart = restartFinder) -> DefaultsSwitch {
        DefaultsSwitch(
            domain: "com.apple.finder",
            keys: ["CreateDesktop"],
            isInverted: true,
            systemDefault: true,
            defaults: defaults,
            restart: restart
        )
    }

    /// Show the files whose name starts with a point.
    static func hiddenFiles(defaults: UserDefaults? = nil, restart: @escaping Restart = restartFinder) -> DefaultsSwitch {
        DefaultsSwitch(
            domain: "com.apple.finder",
            keys: ["AppleShowAllFiles"],
            defaults: defaults,
            restart: restart
        )
    }

    /// Ends Finder. macOS starts it again at once, and it then reads the new
    /// settings. `NSRunningApplication` does the same as `killall Finder`,
    /// without a shell.
    static func restartFinder() {
        guard !RuntimeEnvironment.isRunningTests else { return }

        for app in NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ) {
            app.terminate()
        }
    }
}
