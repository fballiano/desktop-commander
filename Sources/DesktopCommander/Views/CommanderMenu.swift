import AppKit

/// The menu that drops down from the menu bar.
///
/// The order follows the two halves of the application: the switches that change
/// the state of the Mac, the two commands that take over the screen, then the
/// window commands in a submenu. Seventeen window commands in the first level
/// would bury the switches.
///
/// AppKit builds this menu, and SwiftUI does not, because of one row. "Keep
/// awake" needs a checkmark in the same column as the switches under it, and it
/// needs a submenu of lengths. A SwiftUI row that opens a submenu has no state
/// gutter, so its checkmark lands inside the title and makes a second column.
/// An `NSMenuItem` holds a state and a submenu together.
///
/// AppKit gives that row no action: a click on a row that has a submenu opens
/// the submenu. The submenu therefore carries an "Off" row, and the checkmark
/// inside it always sits on the row that runs now.
@MainActor
final class CommanderMenu: NSObject, NSMenuDelegate {
    /// What a row does. `NSMenuItem` takes a selector, so the closure travels in
    /// `representedObject`.
    @MainActor
    private final class Action {
        let run: () -> Void

        init(_ run: @escaping () -> Void) {
            self.run = run
        }
    }

    let menu = NSMenu()

    private let model: AppModel

    /// The row that counts down, and the timer that moves it.
    private var keepAwakeItem: NSMenuItem?
    private var tick: Timer?

    init(model: AppModel) {
        self.model = model
        super.init()

        menu.delegate = self
        // The rows carry their own state, so AppKit must not decide which one
        // is grey. Without this, every row with a closure looks disabled.
        menu.autoenablesItems = false
    }

    // MARK: - The rows

    /// macOS calls this each time the menu opens.
    ///
    /// The rows are built again from nothing, so no row can hold a state that
    /// the Mac left behind. A menu of thirty rows costs nothing to build.
    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refreshSwitches()

        menu.removeAllItems()
        build(into: menu)
        startTick()
    }

    /// The menu is gone, so nothing counts.
    func menuDidClose(_ menu: NSMenu) {
        stopTick()
    }

    private func build(into menu: NSMenu) {
        let keepAwake = add(keepAwakeTitle, to: menu, state: model.keepAwake.isOn)
        keepAwake.submenu = keepAwakeMenu()
        keepAwakeItem = keepAwake

        add("Hide the desktop widgets", to: menu, state: model.desktopWidgets.isOn) { [model] in
            model.setDesktopWidgets(!model.desktopWidgets.isOn)
        }

        add("Hide the desktop icons", to: menu, state: model.desktopIcons.isOn) { [model] in
            model.setDesktopIcons(!model.desktopIcons.isOn)
        }

        add("Show the hidden files", to: menu, state: model.hiddenFiles.isOn) { [model] in
            model.setHiddenFiles(!model.hiddenFiles.isOn)
        }

        add("Hide the windows", to: menu, state: model.hiddenWindows.isOn) { [model] in
            model.setHiddenWindows(!model.hiddenWindows.isOn)
        }

        // The lock swallows every key, so the way out has to be on screen
        // before the user turns it on. The application posts no notification,
        // so the row itself carries the hint.
        add(keyboardLockTitle, to: menu, state: model.keyboardLock.isOn) { [model] in
            model.setKeyboardLock(!model.keyboardLock.isOn)
        }

        if let error = model.keyboardLock.lastError {
            add(error, to: menu, enabled: false)
        }

        menu.addItem(.separator())

        add("Screen saver", to: menu) { [model] in model.startScreenSaver() }
        add("Clean the screen", to: menu) { [model] in model.toggleScreenCleaning() }

        menu.addItem(.separator())

        add("Windows", to: menu).submenu = windowsMenu()

        menu.addItem(.separator())

        add("Preferences…", to: menu, key: ",") { [model] in model.showSettings() }
        add("About desktop-commander", to: menu) { [model] in model.showAbout() }

        menu.addItem(.separator())

        add("Quit desktop-commander", to: menu, key: "q") { [model] in model.quit() }
    }

    /// The lengths of the keep awake switch.
    ///
    /// One row always holds the checkmark: "Off" while the switch is off, and
    /// the length that runs while it is on. A checkmark beside a length while
    /// the switch is off would say "the switch is on".
    private func keepAwakeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        add("Off", to: menu, state: !model.keepAwake.isOn) { [model] in
            model.setKeepAwake(false)
        }

        menu.addItem(.separator())

        for duration in KeepAwake.Duration.allCases {
            let isOn = model.keepAwake.isOn && duration == model.preferences.keepAwakeDuration

            add(duration.title, to: menu, state: isOn) { [model] in
                model.setKeepAwakeDuration(duration)
                model.setKeepAwake(true)
            }
        }

        return menu
    }

    private func windowsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for group in WindowSlot.groups {
            menu.addItem(.sectionHeader(title: group.name))

            for slot in group.slots {
                add(slot.title, to: menu) { [model] in model.move(to: slot) }
            }
        }

        menu.addItem(.separator())

        add("Move to the next display", to: menu) { [model] in model.moveToNextScreen() }
        add("Undo the last move", to: menu, enabled: model.canUndoMove) { [model] in
            model.undoMove()
        }

        return menu
    }

    // MARK: - The countdown

    /// The row counts down once a second while the menu stays open.
    ///
    /// A menu tracks the mouse in its own run loop mode, so the timer goes into
    /// the common modes. Without that it would not fire before the menu closes.
    ///
    /// Only a length counts. "Forever" never changes, and a switch that is off
    /// shows no time, so neither needs a timer.
    private func startTick() {
        stopTick()

        guard model.keepAwake.isOn, model.keepAwake.endsAt != nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
    }

    private func stopTick() {
        tick?.invalidate()
        tick = nil
    }

    /// The length can also run out while the menu is open. The row then loses
    /// its checkmark and its time, and the timer stops.
    private func step() {
        keepAwakeItem?.title = keepAwakeTitle
        keepAwakeItem?.state = model.keepAwake.isOn ? .on : .off

        if !model.keepAwake.isOn {
            stopTick()
        }
    }

    // MARK: - One row

    @discardableResult
    private func add(
        _ title: String,
        to menu: NSMenu,
        state: Bool = false,
        key: String = "",
        enabled: Bool = true,
        action: (() -> Void)? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: key)
        item.state = state ? .on : .off
        item.isEnabled = enabled

        if let action {
            item.representedObject = Action(action)
            item.target = self
            item.action = #selector(run(_:))
        }

        menu.addItem(item)
        return item
    }

    @objc private func run(_ sender: NSMenuItem) {
        (sender.representedObject as? Action)?.run()
    }

    // MARK: - The titles

    /// The row of the lock names the keys that end it.
    private var keyboardLockTitle: String {
        "Keyboard lock (\u{2303}\u{2325}\u{2318}U to unlock)"
    }

    /// The row says how much time is left, or "forever" when the switch has no
    /// end. It says nothing while the switch is off, because the checkmark
    /// already gives the state.
    private var keepAwakeTitle: String {
        guard model.keepAwake.isOn else { return "Keep awake" }

        guard let endsAt = model.keepAwake.endsAt else { return "Keep awake (forever)" }

        return "Keep awake (\(Self.countdown(to: endsAt)))"
    }

    /// The time left, as h:mm:ss, or as m:ss under one hour. The menu is built
    /// each time it opens, so the clock is read at that moment.
    nonisolated static func countdown(to end: Date, from now: Date = Date()) -> String {
        let left = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
        let hours = left / 3600
        let minutes = (left % 3600) / 60
        let seconds = left % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
