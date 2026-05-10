---
phase: 02-skim-interactions
plan: "01"
subsystem: view-model-controller
tags: [swiftui, avfoundation, cadisplaylink, seek, state-machine]
dependency_graph:
  requires: []
  provides: ["clip-state-machine", "seek-layer", "playback-control"]
  affects:
    - SurfvidApp/AppViewModel.swift
    - SurfvidApp/PlayerController.swift
tech_stack:
  added:
    - QuartzCore (CADisplayLink for 60fps seek throttle)
  patterns:
    - "QA1820 chase-time seek — one seek in-flight, tail-chase on completion"
    - "CADisplayLink retain-cycle-safe proxy (DisplayLinkTarget: NSObject)"
    - "Periodic time observer with isScrubbing guard (Pitfall 2)"
key_files:
  created: []
  modified:
    - SurfvidApp/AppViewModel.swift
    - SurfvidApp/PlayerController.swift
decisions:
  - "Non-zero seek tolerance (0.5s each side) in flushPendingSeek — D-05 permits fast keyframe seek during drag"
  - "Zero-tolerance seekExact only on In/Out commit — D-05 exact frame required for clip boundaries"
  - "Double-In replaces pendingIn — D-08: no confirmation, no append"
  - "Out-before-In: autoIn = max(0, t - 15s) — D-07 enables single-tap Out marking"
  - "Zero-duration guard in markOut — Pitfall 7: guard end > start else return"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-10T15:05:00Z"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 2 Plan 01: Behavioral Substrate Summary

**One-liner:** AppViewModel Clip state machine (markIn/markOut/resetForNewVideo) and PlayerController seek layer (CADisplayLink proxy, QA1820 chase-time seek, seekExact, periodic time observer, togglePlayPause) — all 6 seek pitfalls guarded.

## Tasks Completed

| Task | Name | Files |
|------|------|-------|
| 1 | AppViewModel — Clip type and marking state machine | SurfvidApp/AppViewModel.swift |
| 2 | PlayerController — CADisplayLink throttle, chase-time seek, time observer, play/pause | SurfvidApp/PlayerController.swift |

## What Was Built

### Task 1: AppViewModel — Clip state machine

Added to `AppViewModel`:
- `struct Clip: Identifiable` with `start: Double`, `end: Double` fields
- `@Published var clips: [Clip] = []` — list of all marked clip ranges
- `@Published var pendingIn: Double? = nil` — pending In-point before Out is tapped
- `func markIn(at time: Double)` — sets pendingIn (D-08: double-In replaces, no confirmation)
- `func markOut(at time: Double)` — appends Clip; handles both In-then-Out and Out-before-In (D-07: autoIn = max(0, t-15s)); zero-duration guard (Pitfall 7)
- `func resetForNewVideo()` — zeroes clips and pendingIn; called at top of pickVideo(_:)

Behavioral guarantees:
- `markOut` when `pendingIn != nil` → creates Clip(start: min(in, out), end: max(in, out))
- `markOut` when `pendingIn == nil` → creates Clip(start: max(0, t-15), end: t)
- `markOut` where end == start → guard fires, clips unchanged
- `pickVideo(_:)` always calls `resetForNewVideo()` first — clean state per video

### Task 2: PlayerController — Seek layer and playback control

Added to `PlayerController`:

**Published state:**
- `@Published var currentTime: Double = 0` — updated at 60fps during scrub, 10fps during playback
- `@Published var isPlaying: Bool = false` — toggled by togglePlayPause and synced on load

**Properties:**
- `var duration: Double` — populated from AVAsset after load(); consumed by SkimView
- `var isScrubbing: Bool` — set by SkimView DragGesture; guards periodic time observer (Pitfall 2)

**CADisplayLink (QA1820 chase-time pattern):**
- `class DisplayLinkTarget: NSObject` — retain-cycle-safe proxy; CADisplayLink retains proxy, not self (Pitfall 4)
- `startDisplayLink()` / `stopDisplayLink()` — called on drag start/end by SkimView
- `onDisplayLinkTick()` → calls `flushPendingSeek()` and updates `currentTime`

**Seek methods:**
- `updateSeekTarget(_ time: Double)` — accumulates chaseTime from DragGesture; no direct seek call
- `flushPendingSeek()` — fires one seek per tick; non-zero tolerance (0.5s); guard: `currentItem.status == .readyToPlay` (Pitfall 1); chase-on-completion for in-flight seeks
- `seekExact(to: time: Double)` — zero-tolerance seek; called only on In/Out commit (D-05)

**Time observer:**
- `setupTimeObserver()` — removes existing token before adding new one; `addPeriodicTimeObserver` at 0.1s; callback guarded by `!isScrubbing` (Pitfall 2)

**Playback:**
- `togglePlayPause()` — checks `player.timeControlStatus` (not `isPlaying`) for ground truth
- `load(asset:)` integration — sets `duration` and calls `setupTimeObserver()` after `replaceCurrentItem`; sets `isPlaying = false` in status sink

**Lifecycle:**
- `deinit` — `stopDisplayLink()` + `player.removeTimeObserver(token)` (Pitfall 6)

## Pitfall Coverage

All 6 seek pitfalls from RESEARCH.md guarded:
1. **Pitfall 1** — `guard currentItem?.status == .readyToPlay` in `flushPendingSeek`
2. **Pitfall 2** — `guard !isScrubbing` in periodic time observer callback
3. **Pitfall 3** — N/A for this plan (gesture split handled in Plan 02)
4. **Pitfall 4** — `DisplayLinkTarget` proxy breaks CADisplayLink retain cycle; `displayLink = nil` after invalidate
5. **Pitfall 5** — non-zero tolerance in `flushPendingSeek`; zero tolerance only in `seekExact`
6. **Pitfall 6** — `player.removeTimeObserver(token)` in `deinit`

## Deviations from Plan

None. All code matches the plan specifications exactly.

## Self-Check: PASSED

Verification checks:
- `grep -c "struct Clip: Identifiable" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "func markIn(at time: Double)" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "func markOut(at time: Double)" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "func resetForNewVideo()" SurfvidApp/AppViewModel.swift` → 2 (definition + call in pickVideo) ✓
- `grep -c "@Published var clips" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "@Published var pendingIn" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "guard end > start else" SurfvidApp/AppViewModel.swift` → 1 ✓
- `grep -c "class DisplayLinkTarget: NSObject" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "func flushPendingSeek()" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "func seekExact(to time: Double)" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "func togglePlayPause()" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "timeObserverToken = player.addPeriodicTimeObserver" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "player.removeTimeObserver" SurfvidApp/PlayerController.swift` → 2 ✓
- `grep -c "!self.isScrubbing" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "toleranceBefore: .zero" SurfvidApp/PlayerController.swift` → 1 (seekExact only) ✓
- `grep -c "import QuartzCore" SurfvidApp/PlayerController.swift` → 1 ✓
- `grep -c "self.duration = avAsset.duration.seconds" SurfvidApp/PlayerController.swift` → 1 ✓
