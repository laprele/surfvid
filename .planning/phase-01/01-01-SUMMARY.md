---
phase: 01-app-shell-video-browsing
plan: 01
subsystem: app-shell
tags: [scaffold, xcodegen, swift, avfoundation, photos, orientation]
dependency_graph:
  requires: []
  provides: [compilable-xcode-project, app-entry-point, screen-router, player-controller, photos-vm, formatters]
  affects: [01-02, 01-03, 01-04]
tech_stack:
  added: [XcodeGen 2.45.4, SwiftUI, AVFoundation, PhotosKit, Combine]
  patterns: [ZStack-screen-swap, UIApplicationDelegateAdaptor-orientation, PHImageManager-requestAVAsset-streaming, Combine-AnyCancellable-KVO]
key_files:
  created:
    - project.yml
    - .gitignore
    - SurfvidApp/SurfvidApp.swift
    - SurfvidApp/AppDelegate.swift
    - SurfvidApp/AppViewModel.swift
    - SurfvidApp/PlayerController.swift
    - SurfvidApp/ContentView.swift
    - SurfvidApp/Library/LibraryView.swift
    - SurfvidApp/Skim/SkimView.swift
    - SurfvidApp/Shared/Formatters.swift
  modified: []
decisions:
  - "Added explicit 'schemes' section to project.yml — XcodeGen 2.45.4 does not auto-generate xcshareddata/xcschemes/ without it, causing xcodebuild to report empty supported platforms"
  - "Build verified via xcodebuild with iphoneos26.4 SDK (no simulator runtime installed); swiftc type-check also passes for full confidence"
metrics:
  duration: 252s
  completed: "2026-05-09"
  tasks_completed: 2
  files_created: 10
---

# Phase 1 Plan 01: Walking Skeleton Summary

**One-liner:** XcodeGen scaffold + 6 core Swift files (AppViewModel, PlayerController, ContentView, AppDelegate, entry point, formatters) that compile clean against iOS 16 with AVFoundation+Photos streaming architecture.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create project.yml, .gitignore, and SurfvidApp/ directory structure | d40ac59 | project.yml, .gitignore |
| 2 | Write the six core Swift source files that form the compilable type graph | 5234bd3 | SurfvidApp/*.swift, Library/LibraryView.swift (stub), Skim/SkimView.swift (stub), Shared/Formatters.swift |

## Build Results

- **swiftc type-check:** PASSED (all 8 Swift files, targeting arm64-apple-ios16.0)
- **xcodebuild BUILD:** SUCCEEDED (iphoneos26.4 SDK, CODE_SIGNING_ALLOWED=NO)
- **Warnings (non-blocking):**
  - "All interface orientations must be supported unless the app requires full screen" — intentional; app supports portrait + landscape (not portrait upside-down). Not a defect.
  - "A launch configuration or launch storyboard or xib must be provided unless the app requires full screen" — acceptable for v1 personal tool without full-screen entitlement; does not affect functionality.

## XcodeGen Notes

- **Version used:** XcodeGen 2.45.4
- **Project.yml format quirk:** Explicit `schemes:` block required in project.yml. Without it, XcodeGen 2.45.4 generates an empty `xcshareddata/` directory and xcodebuild reports "Supported platforms for the buildables in the current scheme is empty." This is a deviation from the plan's original project.yml spec (which omitted `schemes:`).
- **Info.plist:** Generated automatically into `SurfvidApp/Info.plist` by XcodeGen; gitignored as specified.

## Swift 6 Concurrency Notes

No Swift 6 strict concurrency errors encountered. The code was written with Swift 5.9 (SWIFT_VERSION in project.yml) and uses `async/await` with `withCheckedContinuation` for callback-to-async bridges. The `@MainActor` dispatch pattern in `AppViewModel.requestPhotosAccess()` is correctly applied.

## Files Created

All 8 Swift files + project.yml + .gitignore = 10 files total:

| File | Role | Status |
|------|------|--------|
| project.yml | XcodeGen spec | Created — committed |
| .gitignore | Excludes *.xcodeproj/ and Info.plist | Created — committed |
| SurfvidApp/SurfvidApp.swift | @main entry with @UIApplicationDelegateAdaptor | Created |
| SurfvidApp/AppDelegate.swift | Orientation lock (orientationLock + requestGeometryUpdate) | Created |
| SurfvidApp/AppViewModel.swift | Screen enum + @Published state + Photos fetch | Created |
| SurfvidApp/PlayerController.swift | AVPlayer lifecycle + requestAVAsset streaming | Created |
| SurfvidApp/ContentView.swift | ZStack router + .onChange orientation trigger | Created |
| SurfvidApp/Library/LibraryView.swift | Compile stub (gray) — full impl in Wave 2 (Plan 02) | Created |
| SurfvidApp/Skim/SkimView.swift | Compile stub (black) — full impl in Wave 3 (Plan 03) | Created |
| SurfvidApp/Shared/Formatters.swift | formatDuration + relativeDate + formatTimecode (Phase 2 stub) | Created |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added explicit `schemes:` block to project.yml**
- **Found during:** Task 1 → Task 2 build attempt
- **Issue:** XcodeGen 2.45.4 without an explicit `schemes:` block generates no `.xcscheme` file. `xcodebuild -showdestinations` reported "Supported platforms for the buildables in the current scheme is empty" because there was no scheme to reference.
- **Fix:** Added `schemes: { Surfvid: { build: { targets: { Surfvid: all } }, ... } }` to project.yml and re-ran `xcodegen generate`. This produced `Surfvid.xcodeproj/xcshareddata/xcschemes/Surfvid.xcscheme`.
- **Files modified:** project.yml
- **Commit:** 5234bd3 (included in Task 2 commit)

**2. [Rule 3 - Blocking] Used iphoneos26.4 SDK instead of iphonesimulator for build verification**
- **Found during:** Task 2 build attempt
- **Issue:** `xcodebuild build -sdk iphonesimulator` failed with "iOS 26.4 is not installed" because no iOS simulator runtime disk images are installed on this machine (only the SDK headers, not the runtime). The simulator runtime and the SDK are separate things.
- **Fix:** Used `-sdk iphoneos26.4` with `CODE_SIGNING_ALLOWED=NO` to verify compilation against the real iphoneos SDK. Additionally ran `swiftc -typecheck` for belt-and-suspenders confirmation. BUILD SUCCEEDED.
- **Files modified:** None (build command only)

## Known Stubs

| File | Stub | Reason |
|------|------|--------|
| SurfvidApp/Library/LibraryView.swift | `Color.gray.ignoresSafeArea()` | Compile placeholder — full library UI (permission flow, video list, thumbnails) implemented in Plan 02 |
| SurfvidApp/Skim/SkimView.swift | `Color.black.ignoresSafeArea()` | Compile placeholder — full skim chrome (PlayerView, topChrome, bottomChrome) implemented in Plan 03 |
| SurfvidApp/Shared/Formatters.swift | `formatTimecode` has complete impl | Not actually a stub — formatTimecode is fully implemented; plan noted it as "Phase 2 stub" but the function body is correct and complete |

The two view stubs (LibraryView, SkimView) intentionally prevent the plan's goal from being
"visible UI" — but the plan's stated goal for Plan 01 is "compilable type graph," not visible UI.
The gray/black screens are the expected output per the plan's `<objective>`.

## Threat Flags

No new threat surface found beyond what is documented in the plan's threat model:
- T-01-01: NSPhotoLibraryUsageDescription is in project.yml (accurate, non-misleading)
- T-01-02: PHFetchRequest with lazy PHFetchResult — no large allocation at fetch time
- T-01-03: AppDelegate static singleton — single-process iOS app, acceptable pattern

## Self-Check: PASSED

- [x] project.yml exists at /Users/alexanderlaprell/repos/surfvid/project.yml
- [x] .gitignore exists at /Users/alexanderlaprell/repos/surfvid/.gitignore
- [x] SurfvidApp/SurfvidApp.swift exists
- [x] SurfvidApp/AppDelegate.swift exists
- [x] SurfvidApp/AppViewModel.swift exists
- [x] SurfvidApp/PlayerController.swift exists
- [x] SurfvidApp/ContentView.swift exists
- [x] SurfvidApp/Library/LibraryView.swift exists
- [x] SurfvidApp/Skim/SkimView.swift exists
- [x] SurfvidApp/Shared/Formatters.swift exists
- [x] Task 1 commit d40ac59 exists in git log
- [x] Task 2 commit 5234bd3 exists in git log
- [x] BUILD SUCCEEDED confirmed
