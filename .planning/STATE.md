# Surfvid — State

## Project Reference
See: .planning/PROJECT.md

**Core value:** Get to your best moments and export them, without ever leaving your phone.
**Current phase:** Phase 3 — Review Screen
**Status:** Context gathered, ready to plan

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | App Shell & Video Browsing | Complete ✓ (2026-05-10) |
| 2 | Skim Interactions | Complete ✓ (2026-05-10) |
| 3 | Review Screen | Ready to execute (2026-05-11) |
| 4 | Export | Not started |

## Current Position

**Phase:** 3 — Review Screen
**Plan:** 2 plans, 2 waves (ready to execute)
**Progress:** 2/4 phases complete; Phase 3 planned

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
- objectWillChange forwarding: AppViewModel must forward playerController.objectWillChange so views observe PlayerController changes

### Known Risks
- Volume button In/Out marking (deferred to v2): sandboxed gray-area hack via AVAudioSession KVO; on-screen tap buttons are the v1 interaction
- seek() with zero tolerance is slower — must be throttled during drag, applied precisely on mark commitment
- Overlapping seek() calls must be serialized via pending-seek flag pattern

### Todos
- None

### Blockers
- None

## Performance Metrics

- Phases completed: 2/4
- Plans completed: 7
- Requirements delivered: 11/19 (LIB-01, LIB-02, PERF-01, SKIM-01, SKIM-03, SKIM-04, SKIM-05, SKIM-06, SKIM-07, SKIM-08, PERF-02)

## Session Continuity

Last updated: 2026-05-11 (Phase 3 planned)
Stopped at: Phase 3 plans created and verified; 2 plans across 2 waves
Next action: `/gsd-execute-phase 3` to run all plans
