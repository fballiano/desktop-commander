import SwiftUI

/// The menu that drops down from the menu bar.
///
/// The order follows the two halves of the application: the switches that change
/// the state of the Mac, the two commands that take over the screen, then the
/// window commands in a submenu. Seventeen window commands in the first level
/// would bury the switches.
struct MenuContent: View {
    let model: AppModel

    var body: some View {
        Menu {
            ForEach(KeepAwake.Duration.allCases) { duration in
                Button {
                    model.setKeepAwakeDuration(duration)
                    model.setKeepAwake(true)
                } label: {
                    if duration == model.preferences.keepAwakeDuration {
                        Label(duration.title, systemImage: "checkmark")
                    } else {
                        Text(duration.title)
                    }
                }
            }
        } label: {
            Text(keepAwakeTitle)
        } primaryAction: {
            model.toggleKeepAwake()
        }

        Toggle("Hide the desktop widgets", isOn: Binding(
            get: { model.desktopWidgets.isOn },
            set: { model.setDesktopWidgets($0) }
        ))

        Toggle("Hide the desktop icons", isOn: Binding(
            get: { model.desktopIcons.isOn },
            set: { model.setDesktopIcons($0) }
        ))

        Toggle("Show the hidden files", isOn: Binding(
            get: { model.hiddenFiles.isOn },
            set: { model.setHiddenFiles($0) }
        ))

        Toggle("Hide the windows", isOn: Binding(
            get: { model.hiddenWindows.isOn },
            set: { model.setHiddenWindows($0) }
        ))

        // The lock swallows every key, so the way out has to be on screen
        // before the user turns it on. The application posts no notification,
        // so the row itself carries the hint.
        Toggle(keyboardLockTitle, isOn: Binding(
            get: { model.keyboardLock.isOn },
            set: { model.setKeyboardLock($0) }
        ))

        if let error = model.keyboardLock.lastError {
            Text(error)
        }

        Divider()

        Button("Screen saver") { model.startScreenSaver() }
        Button("Clean the screen") { model.toggleScreenCleaning() }

        Divider()

        Menu("Windows") {
            ForEach(WindowSlot.groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.slots, id: \.self) { slot in
                        Button(slot.title) { model.move(to: slot) }
                    }
                }
            }

            Divider()

            Button("Move to the next display") { model.moveToNextScreen() }
            Button("Undo the last move") { model.undoMove() }
                .disabled(!model.canUndoMove)
        }

        Divider()

        Button("Preferences…") { model.showSettings() }
            .keyboardShortcut(",", modifiers: .command)

        Button("About desktop-commander") { model.showAbout() }

        Divider()

        Button("Quit desktop-commander") { model.quit() }
            .keyboardShortcut("q", modifiers: .command)
    }

    /// The row of the lock names the keys that end it.
    private var keyboardLockTitle: String {
        "Keyboard lock — \u{2303}\u{2325}\u{2318}U to unlock"
    }

    /// The first row says what the switch does and for how long, as OneSwitch
    /// does. A submenu holds the lengths.
    private var keepAwakeTitle: String {
        guard model.keepAwake.isOn else { return "Keep awake" }

        return "Keep awake — \(model.preferences.keepAwakeDuration.subtitle.lowercased())"
    }
}
