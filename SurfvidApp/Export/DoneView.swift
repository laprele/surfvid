import SwiftUI

// Placeholder DoneView — full implementation in Plan 04-02
// Shows a minimal dark screen; auto-returns to library after 2.5s
struct DoneView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundColor(.white)
                    Text("\(appViewModel.clips.count) clip\(appViewModel.clips.count == 1 ? "" : "s") exported")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Returning to library…")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    appViewModel.resetForNewVideo()
                    appViewModel.screen = .library
                }
            }
        }
    }
}
