# Surfvid — State

## Project Reference
See: .planning/PROJECT.md

**Core value:** Get to your best moments and export them, without ever leaving your phone.
**Current phase:** Phase 2 — Skim Interactions
**Status:** Ready to execute

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | App Shell & Video Browsing | Complete ✓ (2026-05-10) |
| 2 | Skim Interactions | Planned ◆ (2026-05-10) |
| 3 | Review Screen | Not started |
| 4 | Export | Not started |

## Current Position

**Phase:** 2 — Skim Interactions
**Plan:** 3 plans (Wave 1→2→3)
**Progress:** 1/4 phases complete

```
[Phase 1] [Phase 2] [Phase 3] [Phase 4]
   ^
   Current
```

## Accumulated Context

### Key Decisions
- AVPlayer must stream from Photos asset URL — never load full file into memory (PERF-01)
- Export uses AVAssetExportPresetPassthrough — no re-encode
- PlayerController kept alive across Skim→Review transition to avoid re-load stutter
- No third-party dependencies for v1
- ZStack screen swap (not NavigationStack push) for Library→Skim due to landscape orientation
- Flat MVVM with single AppViewModel @StateObject as root; no TCA

### Known Risks
- Volume button In/Out marking (deferred to v2): sandboxed gray-area hack via AVAudioSession KVO; on-screen tap buttons are the v1 interaction
- seek() with zero tolerance is slower — must be throttled during drag, applied precisely on mark commitment
- Overlapping seek() calls must be serialized via pending-seek flag pattern

### Todos
- None yet

### Blockers
- None

## Performance Metrics

- Phases completed: 1/4
- Plans completed: 4
- Requirements delivered: 3/19 (LIB-01, LIB-02, PERF-01)

## Session Continuity

Last updated: 2026-05-10 (Phase 2 planned — 3 plans, verification passed)
Stopped at: Phase 2 planning complete; checker passed with 0 blockers
Next action: `/clear` then `/gsd-execute-phase 2`
