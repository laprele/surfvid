# Architecture Patterns: Surfvid iOS

**Domain:** Native SwiftUI video clip-marking app
**Researched:** 2026-05-09
**Confidence:** HIGH (prototype source read directly; AVFoundation patterns from official docs knowledge)

---

## Recommended Architecture: Flat MVVM + Single ObservableObject Root

For a personal tool of this scope — four screens, no network, no auth, no modularization needed — the right call is a single `AppViewModel` class owned at the root, passed down as an `@EnvironmentObject`. No TCA, no Composable Architecture, no coordinator pattern. Those exist to solve team-scale problems this app does not have.

SwiftUI's `NavigationStack` with a value-based path is the correct routing primitive for iOS 16+. The screen enum lives on `AppViewModel`, not inside any view.

---

## Top-Level Component Map

```
SurfvidApp  (entry point, @main)
└── ContentView
    └── AppViewModel  (@StateObject, injected as @EnvironmentObject)
        ├── Screen enum  { library | skim | review | done }
        ├── selectedVideo: VideoItem?
        ├── clips: [Clip]
        ├── pendingIn: Double?          ← ephemeral skim state
        └── PlayerController            ← owns AVPlayer lifecycle
            └── AVPlayer
                └── AVPlayerItem  (built from PHAsset URL)
```

### Screen routing

```
ContentView switches on appVM.screen:
  .library  → LibraryView
  .skim     → SkimView
  .review   → ReviewView
  .done     → DoneToast (auto-pops after 2.4s)
```

Do not use `NavigationStack` push/pop for Library→Skim because Skim is landscape and the transition model differs. A simple ZStack swap (matching the prototype's `setScreen`) is cleaner and avoids NavigationStack's implicit orientation handling.

---

## Data Models

```swift
// Mirrors SVMockVideos / PHAsset
struct VideoItem: Identifiable {
    let id: String           // PHAsset.localIdentifier
    let title: String        // asset.localizedTitle or filename
    let duration: Double     // CMTime → seconds
    let creationDate: Date
    // No thumbnail stored here — generated on demand in LibraryCell
}

// Mirrors SVMockClips
struct Clip: Identifiable {
    let id: UUID
    let videoId: String
    var start: Double        // seconds (CMTime-convertible)
    var end: Double
    var label: String
}
```

`PHAsset` is never stored beyond the moment you resolve an `AVPlayerItem` from it. Keep the model layer free of Photos types — it simplifies testing and isolates the Photos permission boundary.

---

## PlayerController: AVPlayer Lifecycle

`PlayerController` is a class (not a struct) owned by `AppViewModel`. It persists across screen transitions. The player is created once per video pick and torn down on return to Library.

```swift
final class PlayerController: ObservableObject {
    private(set) var player: AVPlayer?
    private var timeObserver: Any?

    @Published var currentTime: Double = 0     // updated by periodic observer
    @Published var duration: Double = 0

    func load(asset: PHAsset) async { ... }    // resolves AVAsset, creates item
    func seek(to seconds: Double) async { ... }
    func pause() { player?.pause() }
    func teardown() { ... }                    // called on back-to-library
}
```

**Why keep it alive across Skim→Review:** The Review screen needs the same player to scrub individual clip trim handles. Recreating AVPlayer for each clip would cause a perceptible stutter and re-load delay on long videos.

**Seeking:** Use `seek(to:toleranceBefore:toleranceAfter:)` with `.zero`/`.zero` for trim scrubbers (frame-accurate) and `CMTime(seconds: t, preferredTimescale: 600)` with small non-zero tolerances for skim dragging (faster, good enough). Zero-tolerance seeks on a scrub drag block the main thread — issue them on a background serial `DispatchQueue` or via `async/await`.

---

## Threading Model

| Operation | Thread | Reason |
|-----------|--------|--------|
| PHAsset → AVAsset resolution | Background (async) | `PHImageManager` callback is on a background thread |
| `AVAsset.load(.duration)` | Background (async/await) | New AVFoundation async API; must not block main |
| Periodic time observation | Called on main by AVPlayer | Safe to assign `@Published` directly |
| `AVAssetExportSession` export | Background | Always async; do not poll on main |
| Updating `clips` array | Main | `@Published` mutations must be on main |
| Seek during scrub drag | Background serial queue | Prevents UI frame drops |

The `async/await` AVFoundation API (`asset.load(.duration)`, `asset.load(.tracks)`) is available iOS 15+ and is the correct pattern — it replaces the old `loadValuesAsynchronously` callback style.

---

## State Flow: In/Out Marking

```
User presses Vol+
  → HardwareVolumeObserver fires onIn callback
  → SkimView calls appVM.markIn()
  → appVM.pendingIn = playerController.currentTime
  → SkimView re-renders: shows MARKING · IN pill

User presses Vol−
  → HardwareVolumeObserver fires onOut callback
  → SkimView calls appVM.markOut()
  → if pendingIn != nil:
        appVM.clips.append(Clip(start: pendingIn, end: currentTime))
        appVM.pendingIn = nil
     else:
        appVM.clips.append(Clip(start: max(0, currentTime-15), end: currentTime))
  → SkimView re-renders: filmstrip shows new clip range
```

`pendingIn` lives on `AppViewModel`, not inside `SkimView`. This matches the prototype where it was `SkimView`-local, but for iOS the volume-button bridge fires via a system-level observer that is wired at the app level — making app-level state cleaner.

---

## Volume Button Bridge

iOS has no public API to intercept volume button presses silently. The standard workaround: embed an `AVAudioSession` and observe `outputVolume` on `AVAudioSession.sharedInstance()` via KVO. Reset the volume to 0.5 immediately after each press to keep the system HUD from showing (this requires `MPVolumeView` with `setShowsVolumeSlider(false)` to suppress the system overlay on the skim screen).

```swift
final class HardwareVolumeObserver: NSObject {
    var onIn: (() -> Void)?
    var onOut: (() -> Void)?
    private var lastVolume: Float = 0.5

    // KVO on AVAudioSession.sharedInstance().outputVolume
    // volume > lastVolume → Vol+ → onIn
    // volume < lastVolume → Vol- → onOut
    // then reset AVAudioSession volume to 0.5
}
```

This is an established pattern with known limitations: it does not work when the device is on silent mode or when another audio session is active. The prototype notes this; it is acceptable for a personal tool.

---

## Screen-by-Screen Component Boundaries

### LibraryView
- Reads: Photos library via `PHFetchResult` (no `appVM` state needed beyond triggering navigation)
- Writes: `appVM.pickVideo(asset:)` → sets `selectedVideo`, transitions to `.skim`
- `LibraryCell`: renders thumbnail via `PHImageManager.requestImage` (async)

### SkimView (landscape, full-bleed)
- Reads: `appVM.selectedVideo`, `appVM.clips`, `appVM.pendingIn`, `playerController.currentTime`
- Writes: drag gesture → `playerController.seek(to:)`, Vol+/- → `appVM.markIn/Out()`
- Contains: `VideoPlayerLayer` (UIViewRepresentable wrapping `AVPlayerLayer`), `MiniFilmstrip`, `VolumeHUD`
- `HardwareVolumeObserver` is attached here (active only while SkimView is shown)

### ReviewView
- Reads: `appVM.clips`, `appVM.selectedVideo`, `playerController`
- Writes: `appVM.updateClip(id:patch:)`, `appVM.deleteClip(id:)`, `appVM.export()`
- Each clip row has its own trim scrubber that calls `playerController.seek(to:)` on drag

### ExportManager (separate class, not a view)
- Receives: `[Clip]`, source `AVAsset`
- Produces: one `AVAssetExportSession` per clip, writes to Photos via `PHPhotoLibrary`
- Reports progress via `@Published var exportProgress: [UUID: Float]`

---

## Build Order (dependency graph)

```
1. Data models (VideoItem, Clip)          — no dependencies
2. AppViewModel (screen enum, state)      — depends on models
3. PlayerController                       — depends on models
4. LibraryView + PHAsset fetch            — depends on AppViewModel
5. VideoPlayerLayer (UIViewRepresentable) — depends on PlayerController
6. SkimView                               — depends on 2, 3, 5
7. HardwareVolumeObserver                 — depends on 2 (wires into SkimView)
8. ReviewView + clip scrubbers            — depends on 2, 3
9. ExportManager                          — depends on models, AVFoundation
10. DoneToast                             — depends on 2 (reads clip count)
```

---

## What NOT to Do

- **Do not use TCA** for v1. The app has one screen that is genuinely complex (Skim); the rest is trivial. TCA's overhead buys nothing here.
- **Do not use `NavigationStack` push for Skim.** The forced landscape orientation and full-bleed video make it a modal replacement, not a drill-down.
- **Do not store `PHAsset` in your model structs.** PHAssets become invalid after the Photos library mutates. Copy only what you need (identifier, duration, title) immediately on pick.
- **Do not seek on every `onChange` of a drag gesture value** without debouncing. SwiftUI gesture callbacks fire at display refresh rate — queue seeks to a serial background queue and drop pending seeks when a new one arrives.
- **Do not run `AVAssetExportSession` on main thread.** It is async by nature, but do not await it from a `@MainActor` context without a wrapping `Task.detached`.

---

## Project Size

Single Xcode target, single module. No Swift packages, no SPM dependencies for v1. Group by feature folder (`Library/`, `Skim/`, `Review/`, `Export/`, `Models/`, `Shared/`). ~15 Swift files total. Personal tool — modularization adds friction with zero benefit at this scale.
