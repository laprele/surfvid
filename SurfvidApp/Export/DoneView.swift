import SwiftUI

struct DoneView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundColor(Color.white)
                    Text("\(appViewModel.clips.count) clip\(appViewModel.clips.count == 1 ? "" : "s") exported")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Returning to library…")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.55))
                    Spacer()
                }
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
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
