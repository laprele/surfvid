# Surfvid — State

## Project Reference
See: .planning/PROJECT.md

**Core value:** Get to your best moments and export them, without ever leaving your phone.
**Current phase:** Phase 5 — Skim Sensitivity
**Status:** Phase 5 added — not yet planned

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | App Shell & Video Browsing | Complete ✓ (2026-05-10) |
| 2 | Skim Interactions | Complete ✓ (2026-05-10) |
| 3 | Review Screen | Complete ✓ (2026-05-12) |
| 4 | Export | Complete ✓ (2026-05-12) |
| 5 | Skim Sensitivity | Not planned |
| 6 | Pinch-to-Zoom | Not planned |

## Current Position

**Phase:** 5 — Skim Sensitivity
**Progress:** 4/4 v1.0 phases complete · Phases 5–6 queued

```
[Phase 1] [Phase 2] [Phase 3] [Phase 4] [Phase 5] [Phase 6]
                                                  ^
                                                  Next
```

## Accumulated Context

### Key Decisions
- AVPlayer must stream from Photos asset URL — never load full file into memory (PERF-01)
- Export uses AVAssetExportPresetPassthrough — no re-encode
- PlayerController kept alive across Skim→Review transition to avoid re-load stutter
- No third-party dependencies for v1
- ZStack screen swap (not NavigationStack push) for Library→Skim due to landscape orientation
- Flat MVVM with single AppViewModel @StateObject as root; no TCA
- objectWillChange forwarding: AppViewModel must forward playerController.objectWillChange so views observe PlayerController changes

### Roadmap Evolution
- Phase 5 added: Skim Sensitivity (promoted from backlog 999.1, 2026-05-12)
- Phase 6 added: Pinch-to-Zoom (2026-05-12)

### Known Risks
- Volume button In/Out marking (deferred to v2): sandboxed gray-area hack via AVAudioSession KVO; on-screen tap buttons are the v1 interaction
- seek() with zero tolerance is slower — must be throttled during drag, applied precisely on mark commitment
- Overlapping seek() calls must be serialized via pending-seek flag pattern

### Todos
- None

### Blockers
- None

## Performance Metrics

- Phases completed: 4/4
- Plans completed: 11
- Requirements delivered: 19/19 (all)

## Session Continuity

Last updated: 2026-05-12 (shipped — pushed to origin/main)
Stopped at: v1.0 shipped to origin/main · Phases 5–6 queued
Next action: `/gsd-discuss-phase 5` or `/gsd-plan-phase 5`
