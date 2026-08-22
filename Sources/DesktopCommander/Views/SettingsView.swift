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
                // A long text gets its own key, so a translator reads a whole
                // paragraph and no line of Swift decides where it breaks.
                Text(String(localized: "settings.general.keepAwakeFooter"))
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
                Text(String(localized: "settings.windows.layoutFooter"))
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
                Text(String(localized: "settings.windows.permissionFooter"))
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
                // The hint is the same sentence the menu row carries, so it is
                // written once and put into the paragraph here.
                Text(String(localized: "settings.switches.lockFooter \(KeyboardLock.unlockHint)"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(String(localized: "settings.switches.desktopText"))
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
                    KeyboardShortcuts.Recorder(entry.title + ":", name: entry.name)
                }
            }

            ForEach(WindowSlot.groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.slots, id: \.self) { slot in
                        KeyboardShortcuts.Recorder(slot.title + ":", name: .slot(slot))
                    }
                }
            }

            Section {
                // The same two titles the Windows submenu carries, so they are
                // translated once.
                KeyboardShortcuts.Recorder(
                    String(localized: "Move to the next display") + ":",
                    name: .nextScreen
                )
                KeyboardShortcuts.Recorder(
                    String(localized: "Undo the last move") + ":",
                    name: .undoMove
                )
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
