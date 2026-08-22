import SwiftUI

/// What the menu bar shows.
///
/// The sliders, always the same outline. See `CommanderGlyph.menuBar` for why
/// the state of the switches does not change it.
struct MenuBarLabel: View {
    var body: some View {
        Image(nsImage: CommanderGlyph.menuBar)
            .renderingMode(.template)
    }
}
