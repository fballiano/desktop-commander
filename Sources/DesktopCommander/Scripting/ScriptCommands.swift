import AppKit
import Foundation

/// The AppleScript commands.
///
///     tell application "desktop-commander" to arrange window "leftHalf"
///
/// The class names are exported to the Objective-C runtime, because the
/// scripting definition refers to them by name. Every command calls one method
/// on `AppModel`, the same method that the menu calls.

// MARK: - The switches

@objc(KeepAwakeOnCommand)
final class KeepAwakeOnCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setKeepAwake(true) }
        return nil
    }
}

@objc(KeepAwakeOffCommand)
final class KeepAwakeOffCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setKeepAwake(false) }
        return nil
    }
}

@objc(HideDesktopIconsCommand)
final class HideDesktopIconsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setDesktopIcons(true) }
        return nil
    }
}

@objc(ShowDesktopIconsCommand)
final class ShowDesktopIconsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setDesktopIcons(false) }
        return nil
    }
}

@objc(ShowHiddenFilesCommand)
final class ShowHiddenFilesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setHiddenFiles(true) }
        return nil
    }
}

@objc(HideHiddenFilesCommand)
final class HideHiddenFilesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setHiddenFiles(false) }
        return nil
    }
}

@objc(HideWindowsCommand)
final class HideWindowsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setHiddenWindows(true) }
        return nil
    }
}

@objc(ShowWindowsCommand)
final class ShowWindowsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setHiddenWindows(false) }
        return nil
    }
}

@objc(StartScreenSaverCommand)
final class StartScreenSaverCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.startScreenSaver() }
        return nil
    }
}

@objc(CleanScreenCommand)
final class CleanScreenCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setScreenCleaning(true) }
        return nil
    }
}

@objc(LockKeyboardCommand)
final class LockKeyboardCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setKeyboardLock(true) }
        return nil
    }
}

@objc(UnlockKeyboardCommand)
final class UnlockKeyboardCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.setKeyboardLock(false) }
        return nil
    }
}

// MARK: - The windows

/// `arrange window "leftHalf"`.
///
/// The place is text, not an enumeration of the dictionary. Fifteen enumerators
/// each need their own four letter code, and the name of the case reads just as
/// well in a script.
@objc(ArrangeWindowCommand)
final class ArrangeWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let raw = (evaluatedArguments?["place"] as? String) ?? (directParameter as? String)

        guard let raw, let slot = WindowSlot(rawValue: raw) else {
            scriptErrorNumber = NSArgumentsWrongScriptError
            scriptErrorString = String(localized: "Unknown place. Use one of: ")
                + WindowSlot.allCases.map(\.rawValue).joined(separator: ", ")
            return false
        }

        return MainActor.assumeIsolated { AppModel.shared.move(to: slot) }
    }
}

@objc(NextDisplayCommand)
final class NextDisplayCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.moveToNextScreen() }
    }
}

@objc(UndoWindowMoveCommand)
final class UndoWindowMoveCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated { AppModel.shared.undoMove() }
    }
}
