---
phase: 01-app-shell-video-browsing
type: skeleton
created: 2026-05-09
---

# Walking Skeleton — Phase 1: App Shell & Video Browsing

> Records the foundational architectural decisions made in Phase 1. Subsequent phases build on
> this skeleton without renegotiating these choices.

---

## Phase Goal (User Story)

**As a** video creator with footage on my iPhone, **I want to** open Surfvid, grant Photos access
once, tap a video in my camera roll, and immediately see it paused on the first frame in a
landscape skim view, **so that** I can start marking In and Out points in the next phase without
having to set up or configure anything.

---

## Stack Decisions

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Swift 6.3.1 | Only option for iOS native |
| UI framework | SwiftUI (iOS 16+) | Project constraint — CLAUDE.md |
| Navigation | ZStack screen swap | NavigationStack push causes landscape glitch on Skim |
| UIKit exception | `UIViewRepresentable` for `AVPlayerLayer` only | SwiftUI has no native player surface |
| Video access | `PHImageManager.requestAVAsset` → `AVURLAsset` | Streams from Photos URL; never loads 15-20 GB into memory |
| Thumbnail access | `PHImageManager.requestImage` with `.opportunistic` | Async, cancellable by `PHImageRequestID` |
| Authorization | `PHPhotoLibrary.requestAuthorization(for: .readWrite)` | iOS 14+ API supporting `.limited` access |
| State management | Flat MVVM — single `AppViewModel` as `@StateObject` | No TCA, no nested VMs; personal tool does not need it |
| Third-party deps | Zero | CLAUDE.md hard constraint |
| Project scaffold | XcodeGen 2.45.4 (`project.yml`) | CLAUDE.md / D-01; `.xcodeproj` is gitignored |

---

## Architecture Decisions

### Screen Routing

`AppViewModel.screen: Screen` (enum `.library` | `.skim`) drives a `ZStack` switch in
`ContentView`. No `NavigationStack`. Transition: `.opacity`, 0.2s ease-out.

```
ContentView (ZStack)
  ├── LibraryView   (screen == .library)
  └── SkimView      (screen == .skim)
```

### AppViewModel — Single Root State

`AppViewModel` is the **only** `@StateObject` in the app. Created in `SurfvidApp.body`, injected
into all child views via `.environmentObject`. No child view models.

Published properties established in Phase 1:
- `screen: Screen` — current screen
- `authStatus: PHAuthorizationStatus` — Photos permission state
- `assets: [PHAsset]` — video assets, sorted creationDate descending

Methods established in Phase 1:
- `requestPhotosAccess() async` — wraps callback API in `withCheckedContinuation`
- `fetchVideos()` — runs `PHFetchRequest` with video predicate, snapshots to `[PHAsset]`
- `pickVideo(_ asset: PHAsset)` — calls `PlayerController.load`, then transitions to `.skim`

### PlayerController — Singleton Per App Session

`PlayerController` is a `let` constant on `AppViewModel`, created in `AppViewModel.init()`,
never recreated. `AVPlayer` lives inside `PlayerController` as a `let` constant.

Phase 1 API surface:
- `player: AVPlayer` — the stable player reference `PlayerView` binds to
- `load(asset: PHAsset) async` — resolves PHAsset → AVURLAsset → AVPlayerItem, pauses on first frame

### Orientation Lock Pattern

Two-part system (D-04, D-05):

1. `AppDelegate.swift` — `orientationLock: UIInterfaceOrientationMask` property +
   `application(_:supportedInterfaceOrientationsFor:)` delegate method. `lockOrientation(_:)` method
   updates the lock AND calls `requestGeometryUpdate` AND calls
   `setNeedsUpdateOfSupportedInterfaceOrientations()`.

2. `ContentView.swift` — `.onChange(of: appViewModel.screen)` triggers `AppDelegate.shared.lockOrientation`.

Library → portrait, Skim → `.landscape` (accepts Left and Right).

---

## Directory Layout

```
surfvid/                            ← repo root
├── project.yml                     ← XcodeGen spec (committed)
├── .gitignore                      ← includes *.xcodeproj/ and SurfvidApp/Info.plist
├── .planning/                      ← GSD planning artifacts
└── SurfvidApp/                     ← all Swift source (D-02)
    ├── SurfvidApp.swift            ← @main; @UIApplicationDelegateAdaptor; @StateObject AppViewModel
    ├── AppDelegate.swift           ← orientationLock; supportedInterfaceOrientationsFor; lockOrientation
    ├── AppViewModel.swift          ← Screen enum; @Published state; requestPhotosAccess; fetchVideos; pickVideo
    ├── PlayerController.swift      ← AVPlayer; load(asset:); Combine AnyCancellable set
    ├── ContentView.swift           ← ZStack switch on screen; .onChange orientation trigger
    ├── Library/
    │   ├── LibraryView.swift       ← authStatus switch; libraryList; permission states
    │   └── LibraryCell.swift       ← PHImageManager thumbnail; requestID cancel; metadata row
    ├── Skim/
    │   ├── SkimView.swift          ← full-bleed ZStack; topChrome; bottomChrome; GeometryReader insets
    │   └── PlayerView.swift        ← UIViewRepresentable; AVPlayerLayer; PlayerUIView
    └── Shared/
        └── Formatters.swift        ← formatDuration; relativeDate; formatTimecode stub
```

**Total Phase 1 files:** 10 Swift files. **Budget remaining for Phases 2-4:** 5 files.

---

## Info.plist Keys (generated by XcodeGen)

All Info.plist content lives in `project.yml` under `targets.Surfvid.info.properties`. Never
edit `SurfvidApp/Info.plist` directly — it is regenerated on every `xcodegen generate`.

Required keys declared in Phase 1:
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddOnlyUsageDescription`
- `UISupportedInterfaceOrientations` (Portrait + LandscapeLeft + LandscapeRight — all three required for `requestGeometryUpdate`)
- `UIApplicationSceneManifest`
- `ITSAppUsesNonExemptEncryption: false`

---

## Build & Run

```bash
# Generate Xcode project (run after any project.yml change)
xcodegen generate

# Build for simulator (compile check — no device needed)
xcodebuild build -scheme Surfvid -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'

# Run on device: open Surfvid.xcodeproj in Xcode, select device, press Run
```

---

## Constraints That Downstream Phases Inherit

| Constraint | Source | Impact |
|------------|--------|--------|
| Zero third-party dependencies | CLAUDE.md | No SPM packages, no CocoaPods; use only Apple frameworks |
| `PlayerController` is a `let` on `AppViewModel` — never recreated | D-10 | Phases 2+ may add methods to `PlayerController` but must not replace the instance |
| `AppViewModel` is the only `@StateObject` | CLAUDE.md Flat MVVM | Phase 2+ adds `@Published` properties and methods to `AppViewModel`; no new root view models |
| `PlayerView` must have stable SwiftUI identity | Pitfall 3 | Never apply `.id()` that changes per video; never wrap in `if` branches |
| `AVPlayer` streams from PHAsset URL | PERF-01 | Never load video data into `Data` or `NSData` in any phase |
| `~15 Swift files total` | CLAUDE.md | 10 used in Phase 1; Phases 2-4 share 5 remaining file budget |
| iOS 16+ deployment target | CLAUDE.md | All APIs must be available on iOS 16; check before using newer APIs |
