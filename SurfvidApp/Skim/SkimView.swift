import SwiftUI
import AVFoundation

struct SkimView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    // MARK: - Local state

    @State private var chromeVisible: Bool = true
    @State private var isScrubbing: Bool = false
    @State private var lastDragX: CGFloat = 0
    @State private var hudFlash: HUDKind? = nil
    @State private var savedClipInfo: String? = nil
    @State private var zoom: CGFloat = 1.0
    @State private var committedPan: CGSize = .zero
    @GestureState private var livePanDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    enum HUDKind { case inPoint, outPoint }

    // D-04: Velocity-driven — right drag = earlier, left drag = later (prototype direction)
    // Higher value = slower seek per pixel; lower value = faster.
    private let PX_PER_S: Double = 1.2

    private var effectiveZoom: CGFloat { zoom * pinchDelta }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Layer 1: Full-bleed black background
                Color.black.ignoresSafeArea()

                // Layer 2: AVPlayerLayer — STABLE IDENTITY CRITICAL (Pitfall 3)
                // Do NOT wrap in if/else or apply .id() that changes per video.
                PlayerView(player: appViewModel.playerController.player)
                    .ignoresSafeArea()
                    .scaleEffect(effectiveZoom)
                    .offset(x: committedPan.width + livePanDelta.width,
                            y: committedPan.height + livePanDelta.height)

                // Layer 3: Gesture capture surface (between video and chrome)
                // D-01: tap toggles chrome. D-04: drag scrubs or pans. Pinch zooms.
                // Pattern 4: gesture split — minimumDistance:8 avoids tap/drag conflict.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .gesture(scrubOrPanGesture)
                    .simultaneousGesture(pinchGesture)
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded { resetZoom() }
                            .exclusively(before: TapGesture(count: 1)
                                .onEnded {
                                    withAnimation(.easeOut(duration: 0.2)) { chromeVisible.toggle() }
                                }
                            )
                    )

                // Zoom indicator — shows while effectiveZoom > 1
                if effectiveZoom > 1.01 {
                    Text(String(format: "%.2g×", effectiveZoom))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 56)
                        .padding(.trailing, 18)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Layer 4: Pending-In pill — visible when In is marked but Out not yet tapped
                if let inTime = appViewModel.pendingIn, chromeVisible {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.80, green: 0.38, blue: 0.18))
                            .frame(width: 6, height: 6)
                        Text("MARKING · IN @ \(formatTimecode(inTime))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(red: 0.72, green: 0.32, blue: 0.14))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 56)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // Layer 4b: Saved-clip pill — brief confirmation after OUT tap
                if let info = savedClipInfo, chromeVisible {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 6, height: 6)
                        Text(info)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 56)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // Layer 5: HUD flash overlay — auto-dismissed after 700ms (Pattern 7)
                hudFlashOverlay

                // Layer 6: Chrome overlays — VStack pinned top and bottom
                // D-01: opacity toggled by chromeVisible; animated 0.2s ease-out
                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                    bottomChrome
                }
                // Skim insets per UI-SPEC:
                // Left: 60pt (Dynamic Island clearance)
                // Right: safeAreaInsets.trailing at runtime (home indicator)
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
                .opacity(chromeVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: chromeVisible)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onChange(of: appViewModel.currentAsset) { _ in resetZoom() }
    }

    // MARK: - Top chrome

    // Top chrome: ← Library   [Video Title]   [Done]
    // UI-SPEC Color: gradient black.opacity(0.45) → clear (top to bottom)
    private var topChrome: some View {
        HStack(alignment: .center) {
            // Back button — UI-SPEC SF Symbols: chevron.left, regular weight
            Button(action: { appViewModel.screen = .library }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .regular))
                    Text("Library")
                        .font(.body)
                }
                .foregroundColor(.white)
            }
            .accessibilityLabel("Back to Library")

            Spacer()

            // Video title placeholder — Phase 3 wires to actual PHAsset title
            Text("Video")
                .font(.body.weight(.medium))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Done pill — navigates to Review screen; disabled when no clips marked
            Button("Done") { appViewModel.screen = .review }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .foregroundColor(Color.black)
                .clipShape(Capsule())
                .disabled(appViewModel.clips.isEmpty)
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

    // MARK: - Bottom chrome

    // Bottom chrome: timecode / play-pause / [ IN ] [timeline] [ OUT ] / hint
    // UI-SPEC Color: gradient clear → black.opacity(0.55) (top to bottom)
    private var bottomChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timecode row — SKIM-06: live playhead position from PlayerController.currentTime
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                // Live timecode — formatTimecode is a top-level func in Formatters.swift
                Text(formatTimecode(appViewModel.playerController.currentTime))
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)

                Spacer()

                // Total duration
                Text("/ \(formatTimecode(appViewModel.playerController.duration))")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))

                // Clip count — SKIM-08
                Text("\(appViewModel.clips.count) marked")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))

                // Play/Pause button — D-02: dedicated button, NOT tap-on-video
                // UI-SPEC SF Symbols: play.fill / pause.fill, medium weight
                Button(action: { appViewModel.playerController.togglePlayPause() }) {
                    Image(systemName: appViewModel.playerController.isPlaying
                          ? "pause.fill"
                          : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(appViewModel.playerController.isPlaying ? "Pause" : "Play")
            }

            // D-06: [ IN ] [====timeline====] [ OUT ]
            HStack(spacing: 8) {
                // IN button — SKIM-03
                // D-05: seekExact before markIn for exact frame commitment
                Button("IN") {
                    let t = appViewModel.playerController.currentTime
                    appViewModel.playerController.seekExact(to: t)
                    appViewModel.markIn(at: t)
                    showHUD(.inPoint)
                }
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(minWidth: 36, minHeight: 36)
                .accessibilityLabel("Mark In point")

                // Timeline bar — SKIM-05, D-09: Canvas, display-only
                TimelineBar(
                    duration: appViewModel.playerController.duration,
                    currentTime: appViewModel.playerController.currentTime,
                    clips: appViewModel.clips,
                    pendingIn: appViewModel.pendingIn
                )

                // OUT button — SKIM-03
                // D-05: seekExact before markOut for exact frame commitment
                // D-07: markOut handles Out-before-In automatically (autoIn = t-15s)
                Button("OUT") {
                    let t = appViewModel.playerController.currentTime
                    appViewModel.playerController.seekExact(to: t)
                    appViewModel.markOut(at: t)
                    showHUD(.outPoint)
                    if let clip = appViewModel.clips.last {
                        showSavedPill(clip: clip)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(minWidth: 36, minHeight: 36)
                .accessibilityLabel("Mark Out point")
            }

            // Hint text — UI-SPEC Copywriting: "Drag to skim · Tap to hide"
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                Text("Drag to skim · Pinch to zoom · Tap to hide")
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

    // MARK: - Scrub / pan gesture

    // D-04: Velocity-driven — drag right = earlier (negative dSec), drag left = later (positive dSec)
    // D-03: Scrubbing pauses playback on first event; no auto-resume on end.
    // D-05: CADisplayLink throttles seek; not every gesture event triggers a seek.
    // iOS 16 compatible: no DragGesture.Value.velocity (iOS 17+ only).
    // Pattern 4: minimumDistance:8 avoids tap/drag conflict.
    // When zoom > 1 the gesture pans instead of scrubbing. Pan offset is accumulated in
    // .updating($livePanDelta) (auto-resets via @GestureState) and committed in .onEnded.
    private var scrubOrPanGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($livePanDelta) { value, state, _ in
                guard zoom > 1 else { return }
                state = value.translation
            }
            .onChanged { value in
                // When zoomed, pan is handled by .updating above; skip scrub.
                guard zoom <= 1 else { return }
                let dx: Double
                if !isScrubbing {
                    isScrubbing = true
                    appViewModel.playerController.isScrubbing = true
                    appViewModel.playerController.player.pause()   // D-03: always pause
                    appViewModel.playerController.isPlaying = false
                    appViewModel.playerController.startDisplayLink()
                    // Anchor lastDragX to first touch so the first delta is 0,
                    // not (touch.x - 0) which would seek to the beginning.
                    lastDragX = value.location.x
                    dx = 0
                } else {
                    dx = Double(value.location.x - lastDragX)
                    lastDragX = value.location.x
                }
                // dSec = -dx / PX_PER_S → right drag (positive dx) → earlier in video
                let dSec = -dx / PX_PER_S
                let current = appViewModel.playerController.currentTime
                let dur = appViewModel.playerController.duration
                // Clamp to [0, duration] — T-02-01 clamp enforced here
                let newTime = max(0, min(dur > 0 ? dur : Double.greatestFiniteMagnitude, current + dSec))
                appViewModel.playerController.updateSeekTarget(newTime)
            }
            .onEnded { value in
                // Clean up scrub state unconditionally (safe no-op if scrub was not active)
                if isScrubbing {
                    isScrubbing = false
                    appViewModel.playerController.isScrubbing = false
                    lastDragX = 0
                    appViewModel.playerController.stopDisplayLink()
                    // D-03: do NOT resume playback automatically
                }
                // Commit pan offset when zoomed
                if zoom > 1 {
                    committedPan.width += value.translation.width
                    committedPan.height += value.translation.height
                    clampPan()
                }
                // livePanDelta auto-resets to .zero via @GestureState — no manual reset needed
            }
    }

    // MARK: - HUD flash (SKIM-07)

    // Pattern 7: @State flag + timed auto-dismiss
    // Prototype timing: 700ms total, easeOut (SVFlashBandLandscape)
    private func showHUD(_ kind: HUDKind) {
        withAnimation(.easeIn(duration: 0.12)) { hudFlash = kind }
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { hudFlash = nil }
            }
        }
    }

    // Brief saved-clip pill after OUT tap — shows time range, auto-dismisses after 1.5s
    private func showSavedPill(clip: AppViewModel.Clip) {
        withAnimation(.easeIn(duration: 0.12)) {
            savedClipInfo = "CLIP · \(formatTimecode(clip.start)) → \(formatTimecode(clip.end))"
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { savedClipInfo = nil }
            }
        }
    }

    // Flash band from top edge — matches prototype SVFlashBandLandscape
    // IN = left side, accent orange. OUT = right side, white.
    // Flash band must NOT block gestures or buttons — hit testing disabled
    @ViewBuilder
    private var hudFlashOverlay: some View {
        if let kind = hudFlash {
            GeometryReader { geo in
                let color: Color = kind == .inPoint
                    ? Color(red: 0.87, green: 0.42, blue: 0.20)  // UI-SPEC accent
                    : Color.white
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 80, height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: kind == .inPoint ? .topLeading : .topTrailing)
                    // Prototype offsets: IN at 36% from left edge, OUT at 52% from right edge
                    .padding(kind == .inPoint
                        ? EdgeInsets(top: 0, leading: geo.size.width * 0.36, bottom: 0, trailing: 0)
                        : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: geo.size.width * 0.52))
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Pinch-to-zoom gesture

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newZoom = min(4, max(1, zoom * value))
                zoom = newZoom
                if newZoom <= 1 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        committedPan = .zero
                    }
                } else {
                    clampPan()
                }
            }
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.25)) {
            zoom = 1.0
            committedPan = .zero
        }
    }

    private func clampPan() {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let maxX = w * (zoom - 1) / 2
        let maxY = h * (zoom - 1) / 2
        committedPan.width = min(maxX, max(-maxX, committedPan.width))
        committedPan.height = min(maxY, max(-maxY, committedPan.height))
    }
}
