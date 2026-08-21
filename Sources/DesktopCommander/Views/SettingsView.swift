import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            WindowSettingsView(model: model)
                .tabItem { Label("Windows", systemImage: "macwindow.on.rectangle") }

            SwitchSettingsView(model: model)
                .tabItem { Label("Switches", systemImage: "switch.2") }

            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 540, height: 460)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences
        @Bindable var loginItem = model.loginItem

        Form {
            Section("Startup") {
                Toggle("Start desktop-commander at login", isOn: $loginItem.isEnabled)
                Toggle("Show notifications", isOn: $preferences.showNotifications)

                if let error = loginItem.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Keep awake for", selection: Binding(
                    get: { preferences.keepAwakeDuration },
                    set: { model.setKeepAwakeDuration($0) }
                )) {
                    ForEach(KeepAwake.Duration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
            } header: {
                Text("Keep awake")
            } footer: {
                Text("""
                The application holds a power assertion, the same way macOS does \
                itself. The assertion dies with the application, so a crash can \
                never leave a Mac that refuses to sleep.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Windows

private struct WindowSettingsView: View {
    let model: AppModel

    /// The permission can change while this window is open, so the view reads it
    /// again when the user comes back from System Settings.
    @State private var isTrusted = false

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                Stepper(value: $preferences.windowGap, in: 0 ... Preferences.maximumWindowGap) {
                    Text(preferences.windowGap == 0
                        ? "No gap between the windows"
                        : "A gap of \(preferences.windowGap) points")
                }
            } header: {
                Text("Layout")
            } footer: {
                Text("""
                The gap sits once at each edge of the screen and once between two \
                windows that meet.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        Image(systemName: isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isTrusted ? .green : .red)

                        Text(isTrusted ? "Granted" : "Not granted")

                        Button("Open Settings…") { model.openAccessibilitySettings() }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("""
                Every window command needs this permission, and so does the \
                keyboard lock. Nothing else does.

                The application is signed ad hoc, so its signature changes with \
                every update. macOS ties the permission to that signature, so \
                after an update you must remove desktop-commander from the list \
                and add it again.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { isTrusted = model.isAccessibilityTrusted }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            isTrusted = model.isAccessibilityTrusted
        }
    }
}

// MARK: - Switches

private struct SwitchSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                Stepper(value: $preferences.keyboardLockTimeout, in: 10 ... 600, step: 10) {
                    Text("Unlock by itself after \(preferences.keyboardLockTimeout) seconds")
                }
            } header: {
                Text("Keyboard lock")
            } footer: {
                Text("""
                Three ways out. \(KeyboardLock.unlockHint) The timer above ends \
                the lock whatever happens. Command, Option and Escape together \
                are never swallowed, so Force Quit always works.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section {
                Text("""
                A change made here also appears in System Settings and in Finder, \
                because the application writes the settings of the system itself. \
                It keeps no copy of its own.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text("The desktop switches")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Switches") {
                ForEach(KeyboardShortcuts.Name.switchNames, id: \.name) { entry in
                    KeyboardShortcuts.Recorder("\(entry.title):", name: entry.name)
                }
            }

            ForEach(WindowSlot.groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.slots, id: \.self) { slot in
                        KeyboardShortcuts.Recorder("\(slot.title):", name: .slot(slot))
                    }
                }
            }

            Section {
                KeyboardShortcuts.Recorder("Move to the next display:", name: .nextScreen)
                KeyboardShortcuts.Recorder("Undo the last move:", name: .undoMove)
            } header: {
                Text("Displays")
            } footer: {
                Text("These shortcuts work in every application.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
