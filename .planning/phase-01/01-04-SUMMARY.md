---
phase: 01-app-shell-video-browsing
plan: "04"
subsystem: integration
tags: [integration, app-shell, swiftui, avfoundation, photos]
dependency_graph:
  requires: ["01-01", "01-02", "01-03"]
  provides: ["complete-phase-1-walking-skeleton"]
  affects: ["AppViewModel.swift"]
tech_stack:
  added: []
  patterns: ["returning-user fetch on init", "xcodegen project file sync"]
key_files:
  created: []
  modified:
    - SurfvidApp/AppViewModel.swift
decisions:
  - "fetchVideos() called in AppViewModel.init() for returning users (authStatus .authorized/.limited)"
  - "xcodeproj regenerated via xcodegen to include PlayerView.swift — was missing from project sources"
metrics:
  duration: "~8 minutes"
  completed: "2026-05-09"
  tasks_completed: 1
  tasks_total: 2
  task_2_status: "checkpoint:human-verify — APPROVED by user 2026-05-10"
---

# Phase 1 Plan 04: Integration Fixes Summary (Partial — Checkpoint Pending)

**One-liner:** Applied returning-user fetchVideos() fix in AppViewModel.init() and repaired broken xcodeproj (PlayerView.swift was missing from project sources); build succeeded.

## Status

- Task 1 (auto): COMPLETE — committed `29f9489`
- Task 2 (checkpoint:human-verify): APPROVED — user confirmed all checklist items passed on device 2026-05-10

## Task 1: Integration Checks and Fixes Applied

Three integration checks were performed:

### Check 1: Row tap wiring — PASS (no change needed)

`SurfvidApp/Library/LibraryView.swift` line 116 already had:
```swift
LibraryCell(asset: asset)
    .onTapGesture { appViewModel.pickVideo(asset) }
```
No fix required.

### Check 2: LibraryCell title field — PASS (no change needed)

`SurfvidApp/Library/LibraryCell.swift` line 19 already used:
```swift
Text(asset.creationDate.map { relativeDate(for: $0) } ?? "Video")
```
Primary text shows a human-readable relative date, not a UUID. No fix required.

### Check 3: AppViewModel returning-user fetch — FIXED

`SurfvidApp/AppViewModel.swift` `init()` did not call `fetchVideos()` for returning users with previously granted Photos access. A user who had already granted permission would see an empty library until a permission prompt fired.

Fix applied:
```swift
init() {
    self.playerController = PlayerController()
    // D-06: Returning user with previously granted access sees library immediately,
    // without waiting for requestPhotosAccess() to trigger the fetch.
    if authStatus == .authorized || authStatus == .limited {
        fetchVideos()
    }
}
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated xcodeproj to include PlayerView.swift**
- **Found during:** Build check after applying integration fixes
- **Issue:** `xcodebuild build` failed with `error: cannot find 'PlayerView' in scope` in `SkimView.swift`. `PlayerView.swift` was created on disk in Wave 3 but was never added to the Xcode project file (xcodeproj was generated before the file was added).
- **Fix:** Ran `xcodegen generate` to regenerate `Surfvid.xcodeproj` from `project.yml`. The `project.yml` uses `sources: path: SurfvidApp` which globs all Swift files recursively — regeneration picks up `PlayerView.swift`.
- **Note:** `*.xcodeproj/` is in `.gitignore`, so the xcodeproj itself is not committed. The file is correct on disk and xcodegen will regenerate it correctly from `project.yml` on any fresh clone.
- **Build result:** BUILD SUCCEEDED after regeneration.

## Build Result

```
** BUILD SUCCEEDED **
```

Verified checks:
- `grep -c "appViewModel.pickVideo(asset)" SurfvidApp/Library/LibraryView.swift` → 1
- `grep -c "if authStatus == .authorized" SurfvidApp/AppViewModel.swift` → 1

## Task 2: Device Verification — APPROVED

User confirmed all checklist items passed on device (2026-05-10).

Two bugs were found and fixed during the checkpoint:
1. **Orientation lock** — `AppDelegate.orientationLock` was an instance var; the SwiftUI-created delegate instance and `AppDelegate.shared` were different objects. Fixed by making the property and method static (`fix(01-04): make AppDelegate orientation lock static`).
2. **Letterboxing** — `UILaunchScreen` key missing from Info.plist; iOS letterboxed the app with black bars at top and bottom. Fixed by adding `UILaunchScreen: {}` to project.yml (`fix(01-04): add UILaunchScreen to Info.plist to prevent letterboxing`).

## Notes for Phase 2 Planner

- **xcodeproj not in git:** `*.xcodeproj/` is gitignored. Any fresh clone must run `xcodegen generate` before opening in Xcode. This should be documented in README.md or a setup script.
- **PlayerController.load() is async:** `pickVideo()` dispatches `screen = .skim` on MainActor after the AVPlayer item is ready. No orientation race condition expected but worth monitoring on device.
- **Orientation lock via requestGeometryUpdate:** Implemented in `ContentView.swift` `.onChange(of: appViewModel.screen)`. If race condition is observed on device (orientation snap-back), fix via `DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)` as noted in T-04-02 threat entry.

## Self-Check: PASSED

- `SurfvidApp/AppViewModel.swift` modified: confirmed (5 lines added)
- Commit `29f9489` exists on worktree-agent-adb098ccd658232e5: confirmed
- LibraryView.swift tap wiring present: confirmed (grep count = 1)
- AppViewModel.swift returning-user guard present: confirmed (grep count = 1)
- Build result: BUILD SUCCEEDED
