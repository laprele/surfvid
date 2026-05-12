import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                if appViewModel.clips.isEmpty {
                    emptyState
                        .padding(.leading, 60)
                        .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
                } else {
                    clipList
                        .padding(.leading, 60)
                        .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
                }

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

    private var clipList: some View {
        List {
            ForEach(appViewModel.clips) { clip in
                clipRow(clip)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.white.opacity(0.12))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = appViewModel.clips.firstIndex(where: { $0.id == clip.id }) {
                                appViewModel.clips.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 56)
    }

    private func clipRow(_ clip: AppViewModel.Clip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatTimecode(clip.start)) → \(formatTimecode(clip.end))")
                    .font(.body.monospacedDigit())
                    .foregroundColor(.white)
                Text(formatTimecode(clip.end - clip.start))
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color.white.opacity(0.3))
            Text("No clips marked")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            Text("Tap Skim to return and mark clips from this video.")
                .font(.body)
                .foregroundColor(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
