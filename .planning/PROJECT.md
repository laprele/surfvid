# Surfvid

## What This Is

A native SwiftUI iOS app for quickly skimming videos from your camera roll, marking In/Out points, reviewing clips, and exporting trimmed video files — all on-device without touching a laptop. The UI flow was validated in a browser prototype; this is the real implementation.

## Core Value

Get to your best moments and export them, without ever leaving your phone.

## Requirements

### Validated

- ✓ Library → skim → review → export screen flow — existing prototype
- ✓ Drag-to-scrub interaction model — existing prototype
- ✓ Volume-button In/Out marking concept — existing prototype
- ✓ Per-clip trim scrubbers in review — existing prototype

### Active

- [ ] Real video playback from iPhone camera roll (Photos framework)
- [ ] AVFoundation-based scrubbing with accurate playhead position
- [ ] Hardware volume button In/Out marking on actual device
- [ ] Mark multiple clips from a single video in one skim session
- [ ] Review screen with per-clip trim scrubbers
- [ ] Export each clip as a separate trimmed video file to Photos

### Out of Scope

- Merged/concatenated export — user wants individual clip files
- Live camera capture — camera roll only
- React Native / cross-platform — native SwiftUI only
- Social sharing flows — not needed for personal use

## Context

The prototype (`Surfvid/Surfvid.html`) was built as a cloud design session to nail the UX. It uses React 18 + Babel Standalone in the browser with mock video data. The screen flow, gesture model, and hardware button bridge are all proven. The iOS app will re-implement the same UX natively.

The problem being solved: cutting clips currently requires moving footage to a laptop. This app makes the full edit loop happen on the iPhone where the footage already lives.

Distribution: personal device first (sideload/Xcode), with App Store release as a possible future step if it proves useful.

## Constraints

- **Platform**: iOS (iPhone) only — no iPad or macOS target for v1
- **Tech stack**: SwiftUI + AVFoundation + PhotosKit — no third-party dependencies for v1
- **Distribution**: No App Store for v1 — personal device via Xcode; entitlements and signing kept simple

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI over React Native | Native iOS feel is the priority; prototype already proved the concept | — Pending |
| Individual clip export over merge | User explicitly wants separate files, not a joined video | — Pending |
| Camera roll only (no live capture) | Simpler scope; the workflow starts after footage exists | — Pending |

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
*Last updated: 2026-05-09 after initialization*
