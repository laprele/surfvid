import SwiftUI

/// Canvas-based timeline bar for the skim screen.
/// D-09: Visual-only. Shows playhead (white), clip ranges (accent fill+border), pending-In marker (accent).
/// D-10: Display-only — no tap targets.
/// D-11: No image generator calls — pure Canvas drawing.
/// PERF-02: Canvas is one GPU pass per frame; no per-clip view nodes.
struct TimelineBar: View {
    let duration: Double
    let currentTime: Double
    let clips: [AppViewModel.Clip]
    let pendingIn: Double?

    // UI-SPEC accent: oklch(0.65 0.14 30 / 0.45) fill → sRGB(0.83, 0.35, 0.15) @ 45%
    // UI-SPEC accent: oklch(0.7 0.16 30) border → sRGB(0.87, 0.42, 0.20)
    private static let clipFill    = Color(red: 0.83, green: 0.35, blue: 0.15).opacity(0.45)
    private static let clipBorder  = Color(red: 0.87, green: 0.42, blue: 0.20)
    private static let pendingColor = Color(red: 0.87, green: 0.42, blue: 0.20)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard duration > 0 else { return }

            // 1. Clip ranges — prototype JSX SVMiniFilmstrip lines 246-254
            for clip in clips {
                let x      = CGFloat(clip.start / duration) * w
                let clipW  = max(2, CGFloat((clip.end - clip.start) / duration) * w)
                let rect   = CGRect(x: x, y: 0, width: clipW, height: h)
                context.fill(Path(rect), with: .color(Self.clipFill))
                context.stroke(Path(rect), with: .color(Self.clipBorder), lineWidth: 1.5)
            }

            // 2. Pending-In marker — prototype JSX SVMiniFilmstrip lines 256-266
            if let inTime = pendingIn {
                let x = CGFloat(inTime / duration) * w
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: h))
                context.stroke(line, with: .color(Self.pendingColor), lineWidth: 1.5)
                // 7×7 diamond cap at top — prototype: top: -2, left: -3, width: 7, height: 7
                let cap = CGRect(x: x - 3.5, y: -3.5, width: 7, height: 7)
                context.fill(Path(roundedRect: cap, cornerRadius: 1), with: .color(Self.pendingColor))
            }

            // 3. Playhead — prototype JSX SVMiniFilmstrip lines 268-280
            let px = CGFloat(currentTime / duration) * w
            var playhead = Path()
            playhead.move(to: CGPoint(x: px, y: -3))
            playhead.addLine(to: CGPoint(x: px, y: h + 3))
            context.stroke(playhead, with: .color(.white), lineWidth: 1.5)
            // 9×9 square cap — prototype: top: -3, left: -4, width: 9, height: 9
            let cap = CGRect(x: px - 4.5, y: -3 - 4.5, width: 9, height: 9)
            context.fill(Path(roundedRect: cap, cornerRadius: 1), with: .color(.white))
        }
        // Background track — matches the RoundedRectangle placeholder from SkimView lines 106-112
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
        .frame(height: 28)
        .allowsHitTesting(false)  // D-10: display-only
    }
}
