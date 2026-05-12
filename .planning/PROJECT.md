# Surfvid

## What This Is

A native SwiftUI iOS app for quickly skimming videos from your camera roll, marking In/Out points, reviewing clips, and exporting trimmed video files — all on-device without touching a laptop. The UI flow was validated in a browser prototype; this is the real implementation.

## Core Value

Get to your best moments and export them, without ever leaving your phone.

## Requirements

### Validated

- ✓ Library → skim → review → export screen flow — Phase 1–4
- ✓ Drag-to-scrub with frame-accurate seeks — Phase 2, Phase 5
- ✓ Mark multiple clips in one session, export each as separate file — Phase 2–4
- ✓ Real video playback from iPhone camera roll (Photos framework) — Phase 1
- ✓ AVFoundation passthrough export — Phase 4
- ✓ Pinch-to-zoom + pan while skimming — Phase 6
- ✓ Volume-button In/Out marking concept — existing prototype (v2 implementation)

### Active

- [ ] Hardware volume button In/Out marking on actual device (v2)
- [ ] Per-clip trim scrubbers in review screen (deferred — current review shows fixed In/Out times)

### Out of Scope

- Merged/concatenated export — user wants individual clip files
- Live camera capture — camera roll only
- React Native / cross-platform — native SwiftUI only
- Social sharing flows — Share Sheet covers all destinations
- Volume button In/Out marking (v1) — sandboxed gray-area hack; deferred to v2 after device spike

## Context

The prototype (`Surfvid/Surfvid.html`) was built as a cloud design session to nail the UX. It uses React 18 + Babel Standalone in the browser with mock video data. The screen flow, gesture model, and hardware button bridge are all proven. The iOS app will re-implement the same UX natively.

The problem being solved: cutting clips currently requires moving footage to a laptop. This app makes the full edit loop happen on the iPhone where the footage already lives.

Distribution: personal device first (sideload/Xcode), with App Store release as a possible future step if it proves useful.

## Constraints

- **Platform**: iOS (iPhone) only — no iPad or macOS target for v1
- **Tech stack**: SwiftUI + AVFoundation + PhotosKit — no third-party dependencies for v1
- **Distribution**: No App Store for v1 — personal device via Xcode; entitlements and signing kept simple
- **File size**: Source videos are typically 1 hour / 15-20 GB — AVPlayer must stream from Photos asset URL; no in-memory loading; thumbnail generation must be async and selective

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI over React Native | Native iOS feel is the priority; prototype already proved the concept | ✓ Good — no friction, full AVFoundation access |
| Individual clip export over merge | User explicitly wants separate files, not a joined video | ✓ Good — simpler ExportManager, clear UX |
| Camera roll only (no live capture) | Simpler scope; the workflow starts after footage exists | ✓ Good — correct scope for v1 |
| ZStack screen swap over NavigationStack | Landscape orientation lock incompatible with NavigationStack push | ✓ Good — clean transitions, no orientation edge cases |
| AVPlayer streams from Photos asset URL | Large files (15-20 GB) must not load into memory | ✓ Good — no memory pressure on hour-long files |
| AVAssetExportPresetPassthrough | No re-encode; export time proportional to clip length only | ✓ Good — fast export verified on device |
| objectWillChange forwarding (PlayerController → AppViewModel) | Views that observe AppViewModel need to react to PlayerController changes | ✓ Good — prevents stale UI without TCA or Combine chains |
| @GestureState for in-flight gesture values | Auto-resets on gesture end; prevents committed state from being mutated mid-gesture | ✓ Good — clean pinch + pan implementation |
| Stay on ReviewView after export (no DoneView auto-nav) | Device testing revealed users want to share immediately from clip list | ✓ Good — user validated on device |
| await MainActor.run after AVFoundation awaits | AVFoundation continuation resumes on background thread; @Published mutations must be on MainActor | ✓ Good — prevents silent dropped UI updates |
| Single DragGesture routes scrub vs pan (guard zoom <= 1) | Avoids needing a second DragGesture and conflicting gesture recognition | ✓ Good — no gesture ambiguity |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-12 — v1.1 milestone archived, all 6 phases shipped and human-verified*
