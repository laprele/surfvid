import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                Color.clear

                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                }
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    private var topChrome: some View {
        HStack(alignment: .center) {
            Button(action: { appViewModel.screen = .skim }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .regular))
                    Text("Skim")
                        .font(.body)
                }
                .foregroundColor(.white)
            }
            .accessibilityLabel("Back to Skim")

            Spacer()

            Text("Review")
                .font(.body.weight(.medium))
                .foregroundColor(Color.white.opacity(0.9))

            Spacer()

            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
