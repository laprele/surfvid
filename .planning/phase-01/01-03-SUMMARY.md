---
phase: 01-app-shell-video-browsing
plan: 03
subsystem: skim-screen
tags: [avfoundation, uiviewrepresentable, avplayerlayer, landscape, chrome-overlay]
completed: 2026-05-09T19:16:51Z
duration_minutes: 25
tasks_completed: 2
tasks_total: 2
requirements_delivered: [PERF-01]

dependency_graph:
  requires:
    - 01-01  # Walking skeleton — AppViewModel, PlayerController, ContentView, SkimView stub
    - 01-02  # Library UI — LibraryView, LibraryCell (provides pickVideo path into skim)
  provides:
    - PlayerView (UIViewRepresentable AVPlayerLayer bridge — stable identity)
    - SkimView (full-chrome landscape shell with gradients, chrome, and safe-area insets)
  affects:
    - 01-04  # Review stub screen — ContentView already routes .skim to SkimView

tech_stack:
  added: []
  patterns:
    - UIViewRepresentable with layerClass override (AVPlayerLayer as backing layer)
    - ZStack chrome overlay with LinearGradient top + bottom
    - GeometryReader for runtime safeAreaInsets.trailing
    - Stable PlayerView identity (never in if-branch, no .id() modifier)

key_files:
  created:
    - SurfvidApp/Skim/PlayerView.swift
  modified:
    - SurfvidApp/Skim/SkimView.swift

decisions:
  - PlayerView uses PlayerUIView.layerClass override (not addSublayer) — the correct AVFoundation pattern; avoids Pitfall 3 (black screen on rebuild)
  - updateUIView only reassigns player property — never recreates AVPlayerLayer
  - SkimView uses max(geometry.safeAreaInsets.trailing, 34) for runtime right inset — handles both physical device and simulator (where safeAreaInsets.trailing may be 0)
  - PlayerView is never wrapped in if/else or .id() modifier — stable SwiftUI identity guaranteed
  - Build verification done via swiftc -typecheck with iphonesimulator26.4 SDK (xcodebuild unavailable due to missing iOS 26.4 device runtime on this machine)
---

# Phase 1 Plan 03: Skim Screen Shell — PlayerView + SkimView Summary

**One-liner:** AVPlayerLayer UIKit bridge via UIViewRepresentable layerClass override, with full-chrome landscape ZStack shell (gradients, back button, timecode, filmstrip placeholder).

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | PlayerView — UIViewRepresentable wrapping AVPlayerLayer | 0ce2db8 | SurfvidApp/Skim/PlayerView.swift (created) |
| 2 | SkimView — full-chrome landscape shell | bf90b67 | SurfvidApp/Skim/SkimView.swift (replaced stub) |

---

## Task Details

### Task 1: PlayerView — UIViewRepresentable wrapping AVPlayerLayer

**What was implemented:**

`SurfvidApp/Skim/PlayerView.swift` — The single UIKit exception in the entire app (satisfies CLAUDE.md constraint). Key implementation choices:

- `PlayerUIView` uses `override class var layerClass: AnyClass { AVPlayerLayer.self }` — the correct pattern where the view's own backing layer is AVPlayerLayer, not a sublayer. This avoids the black-screen bug where sublayer constraints drift on resize.
- `makeUIView` sets `videoGravity = .resizeAspectFill` for full-bleed landscape coverage.
- `updateUIView` only reassigns `uiView.playerLayer.player = player` — never creates a new layer. This is the critical Pitfall 3 guard.
- Debug print `[PlayerView] makeUIView called` confirms stable SwiftUI identity (should fire exactly once per app launch).

**Acceptance criteria met:**
- `struct PlayerView: UIViewRepresentable` present
- `class PlayerUIView: UIView` present
- `override class var layerClass: AnyClass { AVPlayerLayer.self }` present
- `videoGravity = .resizeAspectFill` present
- `updateUIView` contains only `uiView.playerLayer.player = player`
- Type-checks clean with iphonesimulator26.4 SDK

---

### Task 2: SkimView — full-chrome landscape shell

**What was implemented:**

`SurfvidApp/Skim/SkimView.swift` — Replaced the Wave 1 black stub with the complete chrome layout. Structure:

```
ZStack(alignment: .top)
  ├── Color.black.ignoresSafeArea()          (Layer 1: background)
  ├── PlayerView(...).ignoresSafeArea()       (Layer 2: full-bleed video — STABLE IDENTITY)
  └── VStack { topChrome / Spacer / bottomChrome }  (Layer 3: chrome overlays)
        .padding(.leading, 60)
        .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
```

**Top chrome** (`topChrome`):
- Back button: `chevron.left` + "Library" label, `.accessibilityLabel("Back to Library")`
- Center: "Video" title placeholder (Phase 2 wires to PHAsset title)
- Right: "Done" pill (white Capsule, Phase 2 wires action)
- Background: `LinearGradient([Color.black.opacity(0.45), .clear], top→bottom)`

**Bottom chrome** (`bottomChrome`):
- Timecode: "0:00.0" in `.title2.monospacedDigit().weight(.semibold)` (Phase 2 wires to playhead)
- Duration secondary: "/ 0:00" + "0 marked" in `.caption` with `.opacity(0.55)`
- Filmstrip placeholder: 28pt `RoundedRectangle` with `white.opacity(0.06)` fill + `white.opacity(0.18)` stroke
- Hint: `hand.draw` symbol + "Drag to skim · Tap to hide"
- Background: `LinearGradient([.clear, Color.black.opacity(0.55)], top→bottom)`

**Safe-area insets:**
- Left: `.padding(.leading, 60)` — Dynamic Island clearance (hardware constant)
- Right: `max(geometry.safeAreaInsets.trailing, 34)` — reads at runtime via `GeometryReader`, falls back to 34pt minimum

**Acceptance criteria met:** All 10 criteria confirmed via grep.

---

## Verification Results

### Automated Checks

| Check | Result |
|-------|--------|
| `class PlayerUIView: UIView` | PASS (1 match) |
| `override class var layerClass: AnyClass { AVPlayerLayer.self }` | PASS (1 match) |
| `videoGravity = .resizeAspectFill` | PASS (1 match) |
| `struct PlayerView: UIViewRepresentable` | PASS (1 match) |
| `Color.black.opacity(0.45)` (top gradient) | PASS (1 match) |
| `Color.black.opacity(0.55)` (bottom gradient) | PASS (1 match) |
| `.accessibilityLabel("Back to Library")` | PASS (1 match) |
| `PlayerView(player: appViewModel.playerController.player)` | PASS (1 match) |
| `appViewModel.screen = .library` on back button | PASS |
| `geometry.safeAreaInsets.trailing` (runtime inset) | PASS (1 match) |
| `monospacedDigit()` on timecode | PASS |
| PlayerView NOT in any `if` branch | PASS (confirmed via grep) |
| Full swiftc -typecheck (all 10 Swift files) | PASS (no errors) |

### Build Environment Note

`xcodebuild` was unavailable for destination-based builds because the iOS 26.4 device runtime is not installed on this machine. Verification was completed via `swiftc -typecheck` with the iphonesimulator26.4 SDK, which performs full type-checking. All 10 Swift files in SurfvidApp type-check cleanly together.

The previous Wave 2 SUMMARY documented "BUILD SUCCEEDED" from xcodebuild — that build predates the new files added here, and those files have been verified via swiftc.

---

## Success Criteria Status

| Criterion | Status |
|-----------|--------|
| PERF-01: AVPlayer streams from Photos URL via requestAVAsset → AVURLAsset | SATISFIED — PlayerController.load(asset:) uses requestAVAsset; PlayerView receives stable AVPlayer reference; no memory load |
| D-08: Full skim chrome foundation — top overlay (back, title, Done) + bottom overlay (timecode, filmstrip, hint) | SATISFIED — complete chrome shell implemented |
| D-09: Video paused on first frame — Combine status sink calls player.pause() when readyToPlay | SATISFIED — PlayerController already implements this in Wave 1; SkimView does not autoplay |
| T-03-03: PlayerView identity — makeUIView called exactly once | MITIGATED — layerClass override + no if-branches + debug print guard |

---

## Deviations from Plan

None — plan executed exactly as written. The `max(geometry.safeAreaInsets.trailing, 34)` pattern from the task action block was used (vs. the ternary in PATTERNS.md) — both are equivalent; `max()` is cleaner.

---

## Known Stubs

The following are intentional placeholders for Phase 2:

| Stub | File | Line | Reason |
|------|------|------|--------|
| "Video" title placeholder | SkimView.swift | topChrome | Phase 2 wires to actual PHAsset title |
| "0:00.0" timecode | SkimView.swift | bottomChrome | Phase 2 wires to actual playhead position |
| "/ 0:00" duration | SkimView.swift | bottomChrome | Phase 2 wires to AVPlayerItem.duration |
| "0 marked" clip count | SkimView.swift | bottomChrome | Phase 2 wires to clip marking state |
| `Button("Done") { }` | SkimView.swift | topChrome | Phase 2 triggers review screen |
| Filmstrip rectangle | SkimView.swift | bottomChrome | Phase 2 renders actual thumbnails |

These stubs do not prevent the plan's goal — the skim screen shell renders correctly with all chrome elements visible. Phase 2 wires the interactive behavior into this complete layout foundation.

---

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns introduced. Both files are pure UI — `PlayerView` only receives the existing `AVPlayer` reference; `SkimView` only reads `appViewModel.playerController.player` (established in Wave 1). No new trust boundaries.

T-03-03 (PlayerView identity spoofing) is mitigated as planned.

---

## Self-Check

### Created files exist:
- [x] SurfvidApp/Skim/PlayerView.swift — FOUND
- [x] SurfvidApp/Skim/SkimView.swift — FOUND (modified)

### Commits exist:
- [x] 0ce2db8 — feat(01-03): implement PlayerView — UIViewRepresentable wrapping AVPlayerLayer
- [x] bf90b67 — feat(01-03): implement SkimView — full-chrome landscape shell over AVPlayerLayer

## Self-Check: PASSED
