import SwiftUI

/// What the menu bar shows.
///
/// The sliders, and the sliders filled while any switch is on. The user must see
/// that something is changed without opening the menu, because a Mac that never
/// sleeps or a desktop with no icons is easy to forget.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        Image(nsImage: model.isAnySwitchOn ? CommanderGlyph.menuBarActive : CommanderGlyph.menuBar)
            .renderingMode(.template)
    }
}
