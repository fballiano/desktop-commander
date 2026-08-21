import SwiftUI

/// What the black screen shows.
///
/// A black screen with nothing on it looks like a Mac that died, so the view
/// says what is happening and how to leave. The words fade after a few seconds,
/// because a bright line of text is exactly what a person cleaning a screen does
/// not want.
struct ScreenCleaningView: View {
    @State private var showsHint = true

    var body: some View {
        ZStack {
            Color.black

            if showsHint {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)

                    Text("Clean the screen")
                        .font(.title2)

                    Text("Press any key to finish.")
                        .font(.callout)
                }
                .foregroundStyle(.white.opacity(0.35))
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 1)) { showsHint = false }
        }
    }
}
