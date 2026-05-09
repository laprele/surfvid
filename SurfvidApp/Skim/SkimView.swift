import SwiftUI
import AVFoundation

struct SkimView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Layer 1: Full-bleed black background (behind the video)
                Color.black.ignoresSafeArea()

                // Layer 2: AVPlayerLayer — STABLE IDENTITY CRITICAL (Pitfall 3)
                // Do NOT wrap in if/else or apply .id() that changes per video.
                // makeUIView must fire exactly once per app launch.
                PlayerView(player: appViewModel.playerController.player)
                    .ignoresSafeArea()

                // Layer 3: Chrome overlays — VStack pinned top and bottom
                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                    bottomChrome
                }
                // Skim insets per UI-SPEC:
                // Left: 60pt (Dynamic Island clearance — hardware constant from prototype INSET_LEFT = 60)
                // Right: safeAreaInsets.trailing at runtime (home indicator — do NOT hard-code 34pt)
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // Top chrome: ← Library   [Video Title]   [Done]
    // UI-SPEC Color: gradient black.opacity(0.45) → clear (top to bottom)
    private var topChrome: some View {
        HStack(alignment: .center) {
            // Back button — UI-SPEC SF Symbols: chevron.left, regular weight
            // Sets appViewModel.screen = .library which triggers ContentView .onChange → portrait lock
            Button(action: { appViewModel.screen = .library }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .regular))
                    Text("Library")
                        .font(.body)
                }
                .foregroundColor(.white)
            }
            .accessibilityLabel("Back to Library")  // UI-SPEC SF Symbols table

            Spacer()

            // Video title placeholder — Phase 2 wires to actual PHAsset title
            // UI-SPEC: body weight medium, white
            Text("Video")
                .font(.body.weight(.medium))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Done pill — Phase 2 wires action
            // UI-SPEC: white background, label foreground, capsule shape, caption semibold
            Button("Done") { /* Phase 2: trigger review screen */ }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .foregroundColor(Color(.label))
                .clipShape(Capsule())
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

    // Bottom chrome: timecode / filmstrip placeholder / hint
    // UI-SPEC Color: gradient clear → black.opacity(0.55) (top to bottom)
    private var bottomChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timecode row — Phase 2 wires to real playhead position
            // UI-SPEC Typography: .title2.monospacedDigit().weight(.semibold), white
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("0:00.0")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("/ 0:00")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                Text("0 marked")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
            }

            // Mini filmstrip placeholder — UI-SPEC: 28pt height, white.opacity(0.06) fill
            // Phase 2 renders actual filmstrip thumbnails here
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .frame(height: 28)

            // Hint text — UI-SPEC Copywriting: "Drag to skim · Tap to hide"
            // UI-SPEC SF Symbols: hand.draw
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                Text("Drag to skim · Tap to hide")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
