# Phase 2: Skim Interactions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 2-Skim Interactions
**Areas discussed:** Tap gesture split, In/Out buttons, Scrub feel, Filmstrip thumbnails

---

## Tap Gesture Split

| Option | Description | Selected |
|--------|-------------|----------|
| Tap = hide chrome | Tap hides/shows overlay chrome; play/pause gets a dedicated button | ✓ |
| Tap = play/pause | Tap plays or pauses; chrome hide moves elsewhere | |
| Tap = play/pause + auto-hide | Fused — tap plays/pauses and manages chrome visibility | |

**User's choice:** Tap = hide chrome

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom chrome, next to timecode | Play/pause button in the bottom overlay row | ✓ |
| Center of video surface | Floating button centered on video | |
| Top chrome, right side | Near Done pill in top overlay | |

**User's choice:** Play/pause in bottom chrome, next to timecode

| Option | Description | Selected |
|--------|-------------|----------|
| Scrubbing always pauses | Drag pauses playback; releasing drag does not auto-resume | ✓ |
| Video plays through while scrubbing | Video can play while user drags | |

**User's choice:** Scrubbing always pauses

---

## In/Out Buttons

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom chrome, flanking filmstrip | [ IN ] [====timeline====] [ OUT ] | ✓ |
| Top chrome, near Done pill | In and Out buttons near top-right | |
| Floating controls row | Dedicated row above bottom chrome with all controls | |

**User's choice:** Bottom chrome flanking the timeline bar

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-set In to 15 seconds back | Out without pending In → In = max(0, currentTime − 15s), save clip | ✓ |
| Ignore / show a hint | Out with no pending In does nothing | |
| Auto-set In at video start | Clips from beginning to current position | |

**User's choice:** Auto-set In to 15 seconds back (prototype behavior)

| Option | Description | Selected |
|--------|-------------|----------|
| Reset pending In to new position | Double-In cancels first mark, starts fresh from new position | ✓ |
| Ignore the second In tap | First-mark-wins | |
| Show confirmation | Second In prompts user to confirm reset | |

**User's choice:** Reset pending In to new position

---

## Scrub Feel

| Option | Description | Selected |
|--------|-------------|----------|
| Match the prototype — fast and direct | Keep prototype PX_PER_S ≈ 0.6 feel | ✓ |
| Slower / more precise as default | Reduce sensitivity for frame-accurate scrubbing | |
| Leave to Claude — tune for large files | Planner picks values for hour-long videos | |

**User's choice:** Match the prototype feel

| Option | Description | Selected |
|--------|-------------|----------|
| Throttle to display-link rate, commit precisely on mark | CADisplayLink cadence + zero-tolerance seek on mark | ✓ |
| Throttle to fixed interval (100ms) | Timer-based throttle | |
| No throttle — seek on every gesture event | Fire seek() on every pointermove | |

**User's choice:** Throttle to CADisplayLink rate, zero-tolerance seek on In/Out mark

---

## Filmstrip / Timeline

| Option | Description | Selected |
|--------|-------------|----------|
| AVAssetImageGenerator, async batch | Real thumbnails, ~30-40 frames for hour-long video | |
| PHImageManager per-frame | API reuse from library thumbnails | |
| Leave to Claude | Planner picks, just make PERF-02 pass | |

**User's choice (mid-question clarification):** None of the above — user changed approach.

**Notes:** User clarified they don't need thumbnail images in the filmstrip at all. A plain visual timeline is sufficient: shows current playhead position and marked In/Out clip ranges as colored overlays. No `AVAssetImageGenerator` needed. This simplification resolves PERF-02 by eliminating the async thumbnail generation problem entirely.

| Option | Description | Selected |
|--------|-------------|----------|
| Display only — not tappable | All seeking via drag on video surface | ✓ |
| Tappable — tap to jump | Tap position on bar to seek there | |

**User's choice:** Display only

---

## Claude's Discretion

- Exact `PX_PER_S` value and smoothing coefficients for velocity mapping
- Timeline bar color tokens for clip ranges (should follow Phase 1 UI-SPEC accent colors)
- Play/pause SF Symbol and button sizing (follow Phase 1 UI-SPEC)
- HUD flash visual for In/Out confirmation — prototype had a colored band from top; planner may use that or a centered overlay

## Deferred Ideas

- Tappable timeline bar — user chose display-only for v1; could be added in v2
- Volume button In/Out marking — deferred to v2 per PROJECT.md
- Filmstrip thumbnail images — replaced by plain timeline; could be added as enhancement later
