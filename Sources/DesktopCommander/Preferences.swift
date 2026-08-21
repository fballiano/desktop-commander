import Foundation
import Observation

/// The user settings, stored in `UserDefaults`.
///
/// The settings of the system itself are not here. "Hide the desktop icons"
/// lives in `com.apple.finder`, so `DefaultsSwitch` owns it and this type never
/// copies it. Two copies of one truth always fall out of step.
@MainActor
@Observable
final class Preferences {
    enum Key {
        static let windowGap = "windowGap"
        static let keepAwakeDuration = "keepAwakeDuration"
        static let keyboardLockTimeout = "keyboardLockTimeout"
        static let showNotifications = "showNotifications"
        static let appliedDefaultLoginItem = "appliedDefaultLoginItem"
        static let appliedDefaultShortcuts = "appliedDefaultShortcuts"
    }

    /// The default space between a window and the edge of the screen.
    static let defaultWindowGap = 0

    /// The largest gap the settings offer. More than this wastes the screen.
    static let maximumWindowGap = 40

    /// The default length of the keyboard lock, in seconds.
    static let defaultKeyboardLockTimeout = 60

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Key.windowGap: Self.defaultWindowGap,
            Key.keepAwakeDuration: KeepAwake.Duration.forever.rawValue,
            Key.keyboardLockTimeout: Self.defaultKeyboardLockTimeout,
            Key.showNotifications: true,
            Key.appliedDefaultLoginItem: false,
            Key.appliedDefaultShortcuts: false,
        ])

        storedWindowGap = max(0, defaults.integer(forKey: Key.windowGap))
        keepAwakeDuration = KeepAwake.Duration(
            rawValue: defaults.string(forKey: Key.keepAwakeDuration) ?? ""
        ) ?? .forever
        storedKeyboardLockTimeout = max(0, defaults.integer(forKey: Key.keyboardLockTimeout))
        showNotifications = defaults.bool(forKey: Key.showNotifications)
        appliedDefaultLoginItem = defaults.bool(forKey: Key.appliedDefaultLoginItem)
        appliedDefaultShortcuts = defaults.bool(forKey: Key.appliedDefaultShortcuts)
    }

    // MARK: - The windows

    /// The backing value. Never assign to a property inside its own `didSet`:
    /// the `@Observable` macro routes the assignment back through the setter,
    /// which recurses until the stack overflows.
    private var storedWindowGap: Int {
        didSet { defaults.set(storedWindowGap, forKey: Key.windowGap) }
    }

    /// The space between a window and the edge of the screen, in points. `0`
    /// gives windows that touch.
    var windowGap: Int {
        get { storedWindowGap }
        set { storedWindowGap = min(max(0, newValue), Self.maximumWindowGap) }
    }

    // MARK: - The switches

    var keepAwakeDuration: KeepAwake.Duration {
        didSet { defaults.set(keepAwakeDuration.rawValue, forKey: Key.keepAwakeDuration) }
    }

    private var storedKeyboardLockTimeout: Int {
        didSet { defaults.set(storedKeyboardLockTimeout, forKey: Key.keyboardLockTimeout) }
    }

    /// How long the keyboard lock lasts before it ends by itself, in seconds.
    /// The smallest value is 10 seconds, so a mistake never locks the keyboard
    /// for a moment too short to notice or too long to bear.
    var keyboardLockTimeout: Int {
        get { storedKeyboardLockTimeout }
        set { storedKeyboardLockTimeout = min(max(10, newValue), 600) }
    }

    // MARK: - The application

    /// Show a banner after a command of a hot key.
    var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: Key.showNotifications) }
    }

    /// `true` after the app has registered the login item once.
    ///
    /// The app starts at login by default, so the first launch registers the
    /// login item. This flag stops it from doing that a second time. Without it
    /// the app would switch the setting back on at every launch, and a user who
    /// turned it off could never keep it off.
    var appliedDefaultLoginItem: Bool {
        didSet { defaults.set(appliedDefaultLoginItem, forKey: Key.appliedDefaultLoginItem) }
    }

    /// `true` after the app has written its three starting hot keys once.
    ///
    /// The same rule as the login item: write a default once, then never touch
    /// the value again. A user who clears a shortcut must find it cleared at the
    /// next launch.
    var appliedDefaultShortcuts: Bool {
        didSet { defaults.set(appliedDefaultShortcuts, forKey: Key.appliedDefaultShortcuts) }
    }
}
