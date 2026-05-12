---
phase: 04-export
plan: 02
subsystem: ui
tags: [swiftui, avfoundation, uiactivityviewcontroller, export, share-sheet]

# Dependency graph
requires:
  - phase: 04-export/04-01
    provides: ExportManager, AppViewModel.startExport(), isExporting, exportProgress, exportedURL, Screen.done
provides:
  - ReviewView Export All / Exporting… / Share All three-state top chrome button
  - Per-clip ProgressView with orange accent tint during export
  - Per-clip Share button (square.and.arrow.up) after exportedURL is set
  - Share All button sharing all exported URLs via UIActivityViewController
  - DoneView full-screen implementation (checkmark, clip count, safe-area padding, auto-return)
  - ActivityViewController UIViewControllerRepresentable bridge
  - allExported computed property on AppViewModel
affects: [library-view-improvements, skim-sensitivity-backlog]

# Tech tracking
tech-stack:
  added: [UIActivityViewController, UIViewControllerRepresentable]
  patterns: [three-state top-chrome button, per-row @State in private struct, Share Sheet via .sheet modifier]

key-files:
  created:
    - SurfvidApp/Export/DoneView.swift
    - SurfvidApp/Review/ActivityViewController.swift
  modified:
    - SurfvidApp/Review/ReviewView.swift
    - SurfvidApp/AppViewModel.swift

key-decisions:
  - "Stay on ReviewView after export — auto-navigation to DoneView removed after device testing revealed users want to share from the clip list"
  - "Three-state top chrome: Export All → Exporting… (text) → Share All (capsule) — discovered during device checkpoint"
  - "Export All hidden (not just disabled) when clips list is empty"
  - "await MainActor.run wraps all @Published mutations in startExport() Task — AVFoundation continuation resumes on background thread"
  - "ExportClipRow as private struct to hold @State showingShareSheet per row"
  - "Share All compactMap { $0.exportedURL } — safely handles partial export failures"

patterns-established:
  - "UIViewControllerRepresentable bridge: ActivityViewController with let activityItems: [Any], no Coordinator needed"
  - "Three-state button in Group: if/else if/else if chain with distinct states"
  - "await MainActor.run after async continuation that resumes off main thread"

requirements-completed: [EXP-01, EXP-02, EXP-03, EXP-04, PERF-03]

# Metrics
duration: ~35min (including device testing and UX fixes)
completed: 2026-05-12
---

# Phase 4 Plan 02: Export UX Summary

**ReviewView export flow with three-state top chrome, per-clip progress bars, Share All button, and ActivityViewController Share Sheet bridge — device-verified**

## Performance

- **Duration:** ~35 min (auto tasks + device checkpoint + 3 UX fixes)
- **Started:** 2026-05-12T16:39:00Z
- **Completed:** 2026-05-12T17:10:00Z
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- ReviewView top chrome cycles through Export All → Exporting… → Share All based on export state
- Per-clip `ProgressView` with orange accent (`0.87, 0.42, 0.20`) appears during and after export
- Per-clip Share button appears only once `clip.exportedURL` is set; opens ActivityViewController sheet
- Share All button shares all exported clip URLs in a single UIActivityViewController
- `ActivityViewController` UIViewControllerRepresentable wrapping UIActivityViewController
- DoneView full implementation: dark scaffold, checkmark.circle 72pt thin, clip count, safe-area padding, 2.5s auto-return
- Fixed MainActor bug: `await MainActor.run` wraps all @Published mutations after AVFoundation awaits

## Task Commits

Each task was committed atomically:

1. **Task 1: ReviewView Export All button, progress bars, Share buttons** - `1e03ed8` (feat)
2. **Task 2: DoneView full implementation + ActivityViewController** - `abdb71d` (feat)
3. **Checkpoint: Human device verification** — approved after UX fixes

**Post-checkpoint fixes:**
- `70f0307` — fix MainActor export bug, remove auto-nav, add Share All
- `7db2fe1` — hide Export All button when clip list is empty

## Files Created/Modified

- `SurfvidApp/Review/ReviewView.swift` (modified) — three-state top chrome, ExportClipRow struct with @State sheet, progress bar, Share button, Share All sheet
- `SurfvidApp/Export/DoneView.swift` (modified) — full dark-theme implementation replacing Plan 04-01 stub
- `SurfvidApp/Review/ActivityViewController.swift` (created) — UIViewControllerRepresentable wrapping UIActivityViewController
- `SurfvidApp/AppViewModel.swift` (modified) — allExported computed property, MainActor-safe startExport() Task, removed screen = .done

## Decisions Made

- **No auto-navigation after export:** Device testing revealed users want to stay on ReviewView to share clips immediately. `screen = .done` removed from `startExport()`.
- **Three-state button instead of disabled state:** "Export All" hidden when no clips (not just disabled), "Exporting…" as plain text during export, "Share All" capsule after completion.
- **await MainActor.run required:** `AVAssetExportSession.exportAsynchronously` resumes its continuation on an AVFoundation background thread. All @Published mutations after this await must be dispatched to the MainActor explicitly — omitting this caused the first export's state updates to be dropped silently.

## Deviations from Plan

### Auto-fixed Issues (post-checkpoint)

**1. [Device test] MainActor mutation bug**
- **Found during:** Human verification on real device
- **Issue:** `isExporting = false` and `onClipComplete` callback called off MainActor — AVFoundation continuation resumes on a background thread; first export's UI updates were lost
- **Fix:** Wrapped all @Published mutations in `await MainActor.run {}` in `startExport()` Task
- **Files modified:** SurfvidApp/AppViewModel.swift
- **Committed in:** `70f0307`

**2. [Device test] Auto-navigation UX mismatch**
- **Found during:** Human verification on real device
- **Issue:** Navigating to DoneView after export prevented users from sharing clips immediately from the ReviewView list
- **Fix:** Removed `screen = .done` from `startExport()`. Added `allExported` computed property and "Share All" button that appears after export completes.
- **Files modified:** SurfvidApp/AppViewModel.swift, SurfvidApp/Review/ReviewView.swift
- **Committed in:** `70f0307`

**3. [Device test] Export All visible with empty list**
- **Found during:** Human verification on real device
- **Issue:** "Export All" button showed (disabled) when clip list was empty — confusing UI
- **Fix:** Changed condition from `.disabled(clips.isEmpty)` to `else if !appViewModel.clips.isEmpty` — button is now hidden when no clips
- **Files modified:** SurfvidApp/Review/ReviewView.swift
- **Committed in:** `7db2fe1`

---

**Total deviations:** 3 post-checkpoint fixes (1 bug, 2 UX corrections from device testing)
**Impact on plan:** All fixes improved the shipped experience. MainActor fix was a correctness bug; UX fixes were validated by the user on device.

## Issues Encountered

- XcodeGen regeneration required after each wave merge — `*.xcodeproj/` is gitignored; new files in `SurfvidApp/Export/` and `SurfvidApp/Review/` were not picked up until `xcodegen generate` ran locally.

## Next Phase Readiness

- All Phase 4 requirements delivered: EXP-01, EXP-02, EXP-03, EXP-04, PERF-03
- Full export flow verified on real device: progress bars, Camera Roll write, Share Sheet, Share All
- Backlog item 999.1 captured: skim sensitivity for granular point definition
- Todo captured: Library view improvements

---
*Phase: 04-export*
*Completed: 2026-05-12*
