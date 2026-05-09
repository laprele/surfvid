# Surfvid — Project Guide

## What This Is

A native SwiftUI iOS app for quickly skimming videos from the iPhone camera roll, marking In/Out points, reviewing clips, and exporting trimmed video files — all on-device without touching a laptop.

## GSD Workflow

This project uses the GSD (Get Shit Done) planning workflow. All planning artifacts live in `.planning/`.

### Key files
- `.planning/PROJECT.md` — project context, requirements, constraints
- `.planning/REQUIREMENTS.md` — scoped v1 requirements with REQ-IDs
- `.planning/ROADMAP.md` — 4-phase execution plan
- `.planning/STATE.md` — current phase and status
- `.planning/research/` — domain research (stack, features, architecture, pitfalls)
- `.planning/codebase/` — codebase map (from browser prototype)

### Commands
- `/gsd-discuss-phase N` — gather context before planning a phase
- `/gsd-plan-phase N` — create a detailed execution plan for a phase
- `/gsd-execute-phase N` — execute a phase plan
- `/gsd-progress` — check current status

## Critical Constraints

- **iOS 16+, SwiftUI only** — no UIKit except a single `UIViewRepresentable` for `AVPlayerLayer`
- **Zero third-party dependencies** — Apple frameworks only (AVFoundation, PhotosKit, AVKit)
- **Large file support** — source videos are 1 hour / 15-20 GB; `AVPlayer` must stream from Photos asset URL, never load into memory
- **Passthrough export** — use `AVAssetExportPresetPassthrough` to avoid re-encoding
- **No volume button marking in v1** — deferred to v2; on-screen In/Out buttons are the primary interaction

## Architecture (planned)

- Flat MVVM: one `AppViewModel` as `@EnvironmentObject`, screen enum drives ZStack swap
- `PlayerController` owns `AVPlayer` and survives screen transitions (shared between Skim and Review)
- `HardwareVolumeObserver` — deferred to v2
- `ExportManager` runs one `AVAssetExportSession` per clip
- ~15 Swift files total; no modularization needed for personal tool
