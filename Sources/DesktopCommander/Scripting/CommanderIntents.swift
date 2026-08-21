import AppIntents
import Foundation

/// The Shortcuts and Spotlight actions.
///
/// App Intents are the modern equivalent of the AppleScript suite. Both are
/// present, and both call the same methods on `AppModel`.

/// The place of a window, as a list the Shortcuts app can show.
///
/// AppleScript takes the same values as text. Here they get a proper picker,
/// which is why the two entry points read differently for this one command.
extension WindowSlot: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Window Place"
    }

    /// The list is written out case by case. The tool that builds the App
    /// Intents metadata reads this at build time, so it cannot be a loop over
    /// `allCases`. `WindowSlotTests` checks that the list and `WindowSlot.groups`
    /// hold every case, so a new slot cannot be forgotten in silence.
    public static var caseDisplayRepresentations: [WindowSlot: DisplayRepresentation] {[
        .leftHalf: "Left half",
        .rightHalf: "Right half",
        .topHalf: "Top half",
        .bottomHalf: "Bottom half",
        .topLeftQuarter: "Top left quarter",
        .topRightQuarter: "Top right quarter",
        .bottomLeftQuarter: "Bottom left quarter",
        .bottomRightQuarter: "Bottom right quarter",
        .leftThird: "Left third",
        .centreThird: "Centre third",
        .rightThird: "Right third",
        .firstTwoThirds: "First two thirds",
        .lastTwoThirds: "Last two thirds",
        .maximize: "Maximize",
        .centre: "Centre",
    ]}
}

// MARK: - The switches

struct KeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Keep Awake"
    static let description = IntentDescription("Stops the Mac from going to sleep, or lets it sleep again.")
    static let openAppWhenRun = false

    @Parameter(title: "Keep awake")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setKeepAwake(enabled)
        return .result()
    }
}

struct HideDesktopIconsIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Hide Desktop Icons"
    static let description = IntentDescription("Hides or shows the icons of the desktop.")
    static let openAppWhenRun = false

    @Parameter(title: "Hide the icons")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setDesktopIcons(enabled)
        return .result()
    }
}

struct ShowHiddenFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Show Hidden Files"
    static let description = IntentDescription("Shows or hides the files whose name starts with a point.")
    static let openAppWhenRun = false

    @Parameter(title: "Show the hidden files")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setHiddenFiles(enabled)
        return .result()
    }
}

struct HideWindowsIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Hide Windows"
    static let description = IntentDescription("Hides the windows of every application, or brings back the ones it hid.")
    static let openAppWhenRun = false

    @Parameter(title: "Hide the windows")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setHiddenWindows(enabled)
        return .result()
    }
}

struct KeyboardLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Keyboard Lock"
    static let description = IntentDescription("Stops the keyboard from reaching any application, or gives it back.")
    static let openAppWhenRun = false

    @Parameter(title: "Lock the keyboard")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setKeyboardLock(enabled)
        return .result()
    }
}

struct StartScreenSaverIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Screen Saver"
    static let description = IntentDescription("Starts the screen saver.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.startScreenSaver()
        return .result()
    }
}

struct CleanScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Clean the Screen"
    static let description = IntentDescription("Covers every screen with black, so you can wipe it.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.setScreenCleaning(true)
        return .result()
    }
}

// MARK: - The windows

struct ArrangeWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Arrange Window"
    static let description = IntentDescription("Puts the front window into a place on the screen.")
    static let openAppWhenRun = false

    @Parameter(title: "Place")
    var place: WindowSlot

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: AppModel.shared.move(to: place))
    }
}

struct NextDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Window to Next Display"
    static let description = IntentDescription("Sends the front window to the next display, in the same relative place.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: AppModel.shared.moveToNextScreen())
    }
}

struct UndoWindowMoveIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Window Move"
    static let description = IntentDescription("Puts the last moved window back where it was.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: AppModel.shared.undoMove())
    }
}

struct DesktopCommanderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ArrangeWindowIntent(),
            phrases: ["Arrange a window with \(.applicationName)"],
            shortTitle: "Arrange Window",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: StartScreenSaverIntent(),
            phrases: ["Start the screen saver with \(.applicationName)"],
            shortTitle: "Screen Saver",
            systemImageName: "display"
        )
        AppShortcut(
            intent: CleanScreenIntent(),
            phrases: ["Clean the screen with \(.applicationName)"],
            shortTitle: "Clean the Screen",
            systemImageName: "sparkles"
        )
    }
}
