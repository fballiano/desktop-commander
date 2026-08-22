import SwiftUI

@main
struct DesktopCommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The application shows no window of its own. The menu bar item and its
        // menu belong to `AppDelegate`, because AppKit builds the menu. See
        // `CommanderMenu` for the reason. `App` still needs one scene, and a
        // `Settings` scene opens nothing by itself.
        Settings {
            EmptyView()
        }
    }
}

/// Puts the item in the menu bar and gives it its menu.
///
/// `MenuBarExtra` did this before. It builds the menu with SwiftUI, and a
/// SwiftUI row that opens a submenu can hold no checkmark. See `CommanderMenu`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: CommanderMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        model.bootstrap()

        // The tests load into this application, so a test run would put a
        // second item in the menu bar of the user.
        guard !RuntimeEnvironment.isRunningTests else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = CommanderGlyph.menuBar

        let menu = CommanderMenu(model: model)
        item.menu = menu.menu

        statusItem = item
        self.menu = menu
    }
}
