# Surfvid — State

## Project Reference
See: .planning/PROJECT.md

**Core value:** Get to your best moments and export them, without ever leaving your phone.
**Current phase:** Phase 1 — App Shell & Video Browsing
**Status:** Ready to execute

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | App Shell & Video Browsing | Ready to execute (4 plans) |
| 2 | Skim Interactions | Not started |
| 3 | Review Screen | Not started |
| 4 | Export | Not started |

## Current Position

**Phase:** 1 — App Shell & Video Browsing
**Plan:** 4 plans created (Waves 1-4)
**Progress:** 0/4 phases complete

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

- Phases completed: 0/4
- Plans completed: 0
- Requirements delivered: 0/19

## Session Continuity

Last updated: 2026-05-09 (Phase 1 planned — 4 plans in 4 waves)
Stopped at: Phase 1 planning complete
Next action: Run `/gsd-execute-phase 1` to execute Phase 1
