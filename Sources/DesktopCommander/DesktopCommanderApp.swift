import SwiftUI

@main
struct DesktopCommanderApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel.shared
        model.bootstrap()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
                .onAppear { model.refreshSwitches() }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
