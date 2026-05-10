# Phase 2: Skim Interactions - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire all skim interactions into the existing `SkimView` shell: drag-to-scrub (velocity-driven), play/pause, In/Out marking with on-screen buttons, timecode display, and a visual timeline bar showing playhead position and marked clip ranges. The chrome layout and `PlayerController` already exist from Phase 1 — Phase 2 makes them live with real gesture handling, seek integration, and clip state management.

No export (Phase 4). No review screen (Phase 3). No volume button marking (v2). Scope is the skim session only.

</domain>

<decisions>
## Implementation Decisions

### Tap Gesture Split
- **D-01:** Tap on the video surface = **hide/show chrome**. The overlay chrome (buttons, timecode, timeline) fades out on tap and back in on the next tap. Matches the existing hint copy "Drag to skim · Tap to hide" in `SkimView`.
- **D-02:** Play/pause lives in the **bottom chrome**, next to the timecode readout. It is a dedicated button — not a tap-on-video gesture.
- **D-03:** Scrubbing (drag gesture on video surface) **always pauses playback**. Releasing the drag does NOT auto-resume — user must tap play manually.

### Scrub Feel
- **D-04:** Velocity-driven scrubbing — drag speed and direction drive seek rate; finger X position is irrelevant (QuickTime-style, confirmed from Phase 1 specifics). Target feel: **match the prototype** — fast and direct. Prototype used `PX_PER_S ≈ 0.6` with exponential smoothing (`vSmooth = vSmooth * 0.7 + rawV * 0.3`). Planner tunes exact values.
- **D-05:** **Throttle seek() to CADisplayLink rate** during drag (not every gesture event). On In or Out tap, fire a final `seek(to:toleranceBefore:.zero, toleranceAfter:.zero)` to commit the exact frame. Pending-seek flag prevents overlapping seeks.

### In/Out Button Layout
- **D-06:** In and Out buttons sit in the **bottom chrome, flanking the timeline bar**: `[ IN ] [====timeline====] [ OUT ]`. Both are thumb-reachable in landscape.
- **D-07:** **Out before In** → auto-set `In = max(0, currentTime − 15s)`, save the clip. Matches prototype behavior.
- **D-08:** **Double-In** (In tapped while a pending In already exists) → reset pending In to the new position. First mark is cancelled; no confirmation needed.

### Timeline Bar (replaces filmstrip thumbnails)
- **D-09:** No thumbnail images in the timeline bar. The 28pt bar is a **visual-only progress timeline**: full video duration = full bar width. Shows: (a) colored range overlays for each marked clip (In→Out), (b) a pending-In marker line when In is set but Out hasn't been tapped yet, (c) a white playhead scrubber line that tracks the current position in real time.
- **D-10:** Timeline bar is **display-only** — not tappable. All seeking happens via drag on the video surface.
- **D-11:** No `AVAssetImageGenerator` — no async thumbnail work needed. The timeline is pure SwiftUI drawing over the existing `RoundedRectangle` placeholder.

### Clip Data Model
- **D-12:** Clip list lives in `AppViewModel` as `@Published var clips: [Clip]` and `@Published var pendingIn: Double?`. `Clip` is a plain struct `{ id: UUID, start: Double, end: Double }`. No separate store object — flat MVVM per project architecture.

### Claude's Discretion
- Exact `PX_PER_S` value and smoothing coefficients — planner picks values targeting the prototype feel for hour-long videos.
- Timeline bar color tokens for clip ranges and pending-In marker — should follow Phase 1 UI-SPEC accent color (`oklch(0.65 0.14 30 / 0.45)` fill, `oklch(0.7 0.16 30)` border) for consistency.
- Play/pause SF Symbol choice (`play.fill` / `pause.fill`) and button sizing — follow Phase 1 UI-SPEC SF Symbols table.
- HUD flash visual for In/Out confirmation (SKIM-07) — prototype used a colored band from the top edge; planner may use that or a centered overlay. Must be non-blocking and auto-dismiss.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Requirements
- `.planning/ROADMAP.md` — Phase 2 entry: goal, success criteria, requirements SKIM-01, SKIM-03, SKIM-04, SKIM-05, SKIM-06, SKIM-07, SKIM-08, PERF-02
- `.planning/REQUIREMENTS.md` — Full requirement definitions for all SKIM-* and PERF-02

### Design Contract
- `.planning/phase-01/01-UI-SPEC.md` — Phase 1 design contract. Defines color tokens (accent, skim dark theme), typography, spacing scale, and SF Symbols usage that Phase 2 must extend. The skim screen dark theme section is the authoritative source.

### Prototype Reference
- `Surfvid/surfvid-paper-skim-landscape.jsx` — Skim screen prototype. Contains the velocity-driven scrub model (`PX_PER_S`, exponential smoothing), In/Out mark logic, pending-In pill UI, mini filmstrip visual (adapt the clip-range and playhead overlay logic; discard the thumbnail ticks). **Use as interaction and visual reference — do not re-implement React; map to SwiftUI equivalents.**

### Existing Implementation
- `SurfvidApp/Skim/SkimView.swift` — Phase 1 chrome shell (topChrome + bottomChrome). Phase 2 wires gestures and controls into this file. Do not restructure the ZStack layer order.
- `SurfvidApp/PlayerController.swift` — Owns `AVPlayer`. Phase 2 adds seek throttle logic here (CADisplayLink + pending-seek flag).
- `SurfvidApp/AppViewModel.swift` — Owns `screen`, `assets`, `playerController`. Phase 2 adds `clips: [Clip]` and `pendingIn: Double?`.
- `SurfvidApp/Shared/Formatters.swift` — `formatTimecode(_:)` stub already implemented. Wire it to the timecode label in Phase 2.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `formatTimecode(_:)` in `Formatters.swift` — already implemented for `0:MM:SS.f` format; just needs wiring to the live playhead position
- `PlayerView` (`PlayerUIView`) — stable `AVPlayerLayer` bridge; do not touch in Phase 2
- Bottom chrome `RoundedRectangle` placeholder — the 28pt bar becomes the timeline bar; replace fill logic only, keep frame and border

### Established Patterns
- **Flat MVVM:** All new state (`clips`, `pendingIn`) goes into `AppViewModel` — no new ViewModel classes
- **@EnvironmentObject:** `SkimView` already receives `appViewModel` via `@EnvironmentObject`; new controls read from and write to it the same way
- **ZStack layer order:** `PlayerView` → chrome overlays — MUST NOT change (Pitfall 3 from Phase 1: recreating AVPlayerLayer causes black screen)
- **Screen swap:** `appViewModel.screen = .skim` / `.library` already wired; `Done` button in topChrome will route to `.review` in Phase 3 — leave it as a no-op stub for now

### Integration Points
- `PlayerController.player` — Phase 2 calls `player.seek(to:toleranceBefore:toleranceAfter:)` and `player.play()` / `player.pause()` directly
- `AppViewModel.pickVideo(_:)` already loads the asset and transitions to `.skim`; Phase 2 resets `clips = []` and `pendingIn = nil` here on each new video load
- Timecode label in `bottomChrome` already rendered as `Text("0:00.0")` — replace with a `@State` or computed binding to the live `AVPlayer` time observer

</code_context>

<specifics>
## Specific Ideas

- **QuickTime-style scrubbing:** User explicitly specified velocity-driven model matching QuickTime Player on Mac with trackpad. Slow drag = near frame-by-frame; fast flick = large seek. Finger X position on screen is irrelevant — only speed and direction matter. Prototype implementation in `surfvid-paper-skim-landscape.jsx` is the reference.
- **Timeline bar simplification:** User explicitly chose a plain visual timeline (no thumbnail images) over an image-based filmstrip. The bar shows only playhead position and clip range overlays. This eliminates all `AVAssetImageGenerator` complexity and resolves PERF-02 by avoiding the problem entirely.

</specifics>

<deferred>
## Deferred Ideas

- **Tappable timeline** — User chose display-only. Could be added in v2 as a quick-jump gesture.
- **Volume button In/Out marking** — Deferred to v2 per PROJECT.md and CLAUDE.md. Sandboxed gray-area hack via `AVAudioSession` KVO.
- **Filmstrip thumbnail images** — Replaced by plain timeline bar in v1. Could be added as a visual enhancement in a future phase.

</deferred>

---

*Phase: 2-Skim Interactions*
*Context gathered: 2026-05-10*
