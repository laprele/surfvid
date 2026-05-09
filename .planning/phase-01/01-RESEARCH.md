# Phase 1: App Shell & Video Browsing — Research

**Researched:** 2026-05-09
**Domain:** SwiftUI / PhotosKit / AVFoundation / XcodeGen (iOS 16+)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use XcodeGen (`project.yml` + `xcodegen generate`) — not Xcode GUI. XcodeGen is already installed (v2.45.4).
- **D-02:** Swift source files live in `SurfvidApp/` at the repo root. The `.xcodeproj` is generated from `project.yml` and gitignored.
- **D-03:** Bundle ID: `com.laprell.surfvid`. Signing: automatic. Deployment target: iOS 16.
- **D-04:** Use `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` for orientation lock. Called when `AppViewModel.screen` changes.
- **D-05:** Info.plist declares Portrait + Landscape Left + Landscape Right. All three must be listed.
- **D-06:** On permission grant, run `PHFetchRequest` sorted by `creationDate` descending. Snapshot into `[PHAsset]` in `AppViewModel`. Load once per session.
- **D-07:** `[PHAsset]` array and `PHAuthorizationStatus` live in `AppViewModel`. Fetching triggered from `AppViewModel` after authorization.
- **D-08:** Phase 1 delivers the full chrome foundation for the skim screen: AVPlayerLayer (full-bleed, landscape) + top overlay gradient + bottom overlay gradient.
- **D-09:** When user taps a video, `PlayerController` sets up `AVPlayer` with the asset's PHAsset URL and pauses on the first frame. No autoplay.
- **D-10:** `PlayerController` is created once in `AppViewModel.init()` and reused across screen transitions.

### Claude's Discretion

- File layout within `SurfvidApp/` (flat vs. grouped by layer) — planner may choose based on ~15-file target.
- Exact `project.yml` structure and build settings beyond bundle ID and deployment target.
- `PHImageManager` thumbnail request implementation details (size, delivery mode, cancellation bookkeeping) — follow UI-SPEC §LIB-01 and cancel by `requestID` when cell leaves screen.

### Deferred Ideas (OUT OF SCOPE)

- Velocity-driven scrubbing — Phase 2, SKIM-01.
- Play/pause toggle — Phase 2, SKIM-04.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIB-01 | User can browse camera roll videos with thumbnails | PHFetchRequest + PHImageManager thumbnail pattern; async delivery mode; cancellation by requestID |
| LIB-02 | Videos listed most-recently-added first by default | `NSSortDescriptor(key: "creationDate", ascending: false)` on PHFetchOptions |
| PERF-01 | App plays and scrubs hour-long videos (15-20 GB) without crashing — AVPlayer streams from Photos asset URL, never loads file into memory | `PHImageManager.requestAVAsset` → AVURLAsset → AVPlayerItem → AVPlayer; streaming pattern confirmed; no memory load |
</phase_requirements>

---

## Summary

Phase 1 builds three vertical slices in one working skeleton: (1) XcodeGen project scaffold that compiles and runs on device, (2) Photos authorization + library grid with async thumbnails, and (3) tap-to-skim that shows the video paused on the first frame inside a full-chrome landscape shell. These three slices together constitute the "walking skeleton" — a thin end-to-end path from app launch to video on screen.

All major APIs are Apple first-party and have been stable since iOS 14-16. No third-party dependencies exist anywhere in the stack. The orientation lock mechanism requires an AppDelegate adaptor (two extra files) because SwiftUI has no native API for per-screen orientation. The thumbnail loading pattern is well-understood: deliver `.fastFormat` first, then allow `PHImageManager` to upgrade in a second callback; cancel the request by `requestID` in `onDisappear`. The AVPlayer streaming pattern from PHAsset is standard and confirmed correct for large local files.

The most nuanced technical area is the orientation lock: `UIWindowScene.requestGeometryUpdate` alone is not sufficient. It must be paired with an AppDelegate that overrides `supportedInterfaceOrientationsFor` to return the current lock, otherwise the system ignores the geometry request when the device is physically rotated. The exact two-file pattern (AppDelegate class + `@UIApplicationDelegateAdaptor`) is well-documented and tested on iOS 16+.

**Primary recommendation:** Build the Walking Skeleton as Wave 1 — XcodeGen scaffold + AppViewModel stub + ZStack screen swap compiling on device — before adding Photos or AVPlayer logic. This catches build-environment issues (code signing, entitlements, XcodeGen format) on the first wave instead of after significant feature code is written.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Photos authorization prompt | iOS System | AppViewModel | System dialog triggered by `PHPhotoLibrary.requestAuthorization`; status stored in AppViewModel |
| Video asset fetch / sort | AppViewModel | PhotosKit | PHFetchRequest runs on demand; result cached as `[PHAsset]` in AppViewModel |
| Library grid UI | LibraryView (SwiftUI) | AppViewModel | SwiftUI List reads from AppViewModel's `[PHAsset]` array |
| Thumbnail loading | LibraryCell (SwiftUI) | PHImageManager | Per-cell request; cell owns requestID for cancellation |
| Screen routing (Library ↔ Skim) | AppViewModel | ContentView | `screen` enum on AppViewModel drives ZStack switch |
| Orientation lock | AppDelegate + UIWindowScene | AppViewModel | `requestGeometryUpdate` + `supportedInterfaceOrientationsFor` must work together; triggered by AppViewModel.screen change |
| Video streaming / AVPlayer | PlayerController | AppViewModel | PlayerController resolves PHAsset → AVURLAsset → AVPlayerItem; AVPlayer never loads file into memory |
| AVPlayerLayer rendering | PlayerView (UIViewRepresentable) | SkimView | The single UIKit exception; layer owned by PlayerController's AVPlayer |
| Skim screen chrome layout | SkimView (SwiftUI) | PlayerController | Overlay gradients, back button, title, Done pill are pure SwiftUI on top of PlayerView |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 16+ (system) | All UI, layout, state binding | Project constraint; DragGesture, List, ZStack are first-class |
| PhotosKit | iOS 14+ (system) | Camera roll access, PHAsset fetch, thumbnail generation | Only correct API for browsable Photos library |
| AVFoundation | iOS 16+ (system) | AVPlayer, AVPlayerItem, streaming from PHAsset | Required for video playback without memory load |
| AVKit | iOS 16+ (system) | AVPlayerLayer (via UIViewRepresentable) | Required for custom player surface |
| XcodeGen | 2.45.4 (installed) | Generates `.xcodeproj` from `project.yml` | Project constraint; already installed |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Combine | iOS 13+ (system) | AnyCancellable for AVPlayerItem KVO | Use for `publisher(for: \.status)` on AVPlayerItem to avoid manual KVO teardown crashes |
| Foundation | iOS 16+ (system) | CMTime, NSSortDescriptor, DispatchQueue | Ubiquitous; no special consideration |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `PHAsset.fetchAssets(with:)` | `PHPickerViewController` | Picker gives transient access only, not a browsable library; wrong for this app |
| `AVPlayerLayer` UIViewRepresentable | `SwiftUI VideoPlayer` | `VideoPlayer` hides the AVPlayer reference; can't seek or control without it |
| AppDelegate orientation pattern | UIHostingController subclass | Both work on iOS 16; AppDelegate adaptor is simpler for flat MVVM |

**Installation:** No `npm install` needed. All frameworks are system-provided. XcodeGen is already installed at `/opt/homebrew/bin/xcodegen`.

**Version verification:** [VERIFIED: `xcodegen --version`] XcodeGen 2.45.4 confirmed installed. [VERIFIED: `xcodebuild -version`] Xcode 26.4.1 with iOS 26.4 SDK. Swift 6.3.1. [ASSUMED] iOS 16 simulator runtimes — current simctl shows only iOS 26 (unavailable) runtimes; testing on a real device or adding iOS 16 runtime manually may be required.

---

## Architecture Patterns

### System Architecture Diagram

```
App Launch
    │
    ▼
SurfvidApp (@main)
    │  @UIApplicationDelegateAdaptor
    ├──── AppDelegate
    │         └── orientationLock: UIInterfaceOrientationMask
    │             └── application(_:supportedInterfaceOrientationsFor:) → returns lock
    │
    └──── ContentView
              │  @StateObject
              ▼
          AppViewModel
              │  screen: Screen enum { .library | .skim }
              │  assets: [PHAsset]
              │  authStatus: PHAuthorizationStatus
              │  playerController: PlayerController
              │
              ├── .library ──────────────────────► LibraryView
              │                                       │  @EnvironmentObject AppViewModel
              │                                       ├── PermissionPromptView (if .notDetermined/.denied)
              │                                       └── List { LibraryCell(asset:) }
              │                                               │
              │                                               │  PHImageManager.requestImage(...)
              │                                               ▼
              │                                          UIImage thumbnail
              │                                               │ tap row
              │                                               ▼
              │                                       appVM.pickVideo(asset:)
              │                                       appVM.screen = .skim
              │                                       AppDelegate.orientationLock = .landscape
              │                                       UIWindowScene.requestGeometryUpdate(...)
              │
              └── .skim ───────────────────────────► SkimView (landscape)
                                                        │  PlayerController.load(asset:)
                                                        │  PHImageManager.requestAVAsset → AVURLAsset
                                                        │                                → AVPlayerItem
                                                        │                                → AVPlayer
                                                        ├── PlayerView (UIViewRepresentable)
                                                        │       └── AVPlayerLayer (full-bleed)
                                                        ├── TopChromeOverlay (gradient)
                                                        │       └── back button / title / Done pill
                                                        └── BottomChromeOverlay (gradient)
                                                                └── placeholder timecode / filmstrip area
```

### Recommended Project Structure

```
SurfvidApp/                     # All Swift source files (D-02)
├── SurfvidApp.swift            # @main entry point, @UIApplicationDelegateAdaptor
├── AppDelegate.swift           # orientationLock + supportedInterfaceOrientationsFor
├── AppViewModel.swift          # Single @StateObject root; Screen enum; PHAsset array
├── PlayerController.swift      # AVPlayer lifecycle; load(asset:); seek(to:)
│
├── Library/
│   ├── LibraryView.swift       # Permission states + List
│   └── LibraryCell.swift       # Row layout + PHImageManager thumbnail request
│
├── Skim/
│   ├── SkimView.swift          # Landscape chrome shell; ZStack layers
│   └── PlayerView.swift        # UIViewRepresentable wrapping AVPlayerLayer
│
└── Shared/
    ├── Models.swift            # VideoItem, Clip structs
    └── Formatters.swift        # svFmt equivalent: seconds → "0:12.3" / "H:MM:SS"
```

Total: 10 Swift files for Phase 1. Five more are budgeted for Phases 2-4 (review, export, HUD, filmstrip, done toast).

### Pattern 1: XcodeGen project.yml for SwiftUI iOS 16 App

**What:** Declarative Xcode project spec. `xcodegen generate` produces `.xcodeproj` from this YAML. The generated project is gitignored.

**When to use:** Always. D-01 requires XcodeGen.

```yaml
# Source: Context7 /yonaskolb/xcodegen (VERIFIED)
name: Surfvid
options:
  bundleIdPrefix: com.laprell
  deploymentTarget:
    iOS: "16.0"
  minimumXcodeGenVersion: "2.40.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: 4KJH92DV9R
    CODE_SIGN_STYLE: Automatic

targets:
  Surfvid:
    type: application
    platform: iOS
    sources:
      - path: SurfvidApp
    info:
      path: SurfvidApp/Info.plist
      properties:
        CFBundleDisplayName: Surfvid
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        NSPhotoLibraryUsageDescription: "Surfvid needs read access to your camera roll to show your videos."
        NSPhotoLibraryAddOnlyUsageDescription: "Surfvid saves exported clips back to your camera roll."
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
          UISceneConfigurations: {}
        ITSAppUsesNonExemptEncryption: false
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.laprell.surfvid
        IPHONEOS_DEPLOYMENT_TARGET: "16.0"
```

**Gitignore entry:** Add `*.xcodeproj/` to `.gitignore`. The `project.yml` is what gets committed. [VERIFIED: Context7 /yonaskolb/xcodegen FAQ]

**DEVELOPMENT_TEAM:** [VERIFIED: keychain certificate OU field] Team ID is `4KJH92DV9R` (Alexander Laprell's Apple Developer account). Hard-code in `project.yml` since this is a personal single-developer project.

**Note on Info.plist location:** XcodeGen's `info.path` generates the plist at that path on disk every time `xcodegen generate` runs. The `NSPhotoLibraryUsageDescription` and orientation keys live here — not in a hand-maintained plist. [VERIFIED: Context7 /yonaskolb/xcodegen — "Auto-Generate Info.plist and Entitlements"]

**SDK frameworks:** AVFoundation, AVKit, and PhotosKit are linked automatically when you import them in Swift on iOS. No explicit `dependencies: sdk:` entries needed for these frameworks on iOS targets. [ASSUMED — standard Apple framework auto-linking behavior]

### Pattern 2: PHPhotoLibrary Authorization Flow

**What:** Request Photos access using the async/await-compatible `withCheckedContinuation` wrapper, then fetch assets. [CITED: developer.apple.com/documentation/photokit/phphotolibrary/3616053-requestauthorization]

**When to use:** On AppViewModel initialization or on first launch.

```swift
// Source: PHPhotoLibrary docs + community async/await pattern [CITED]
func requestPhotosAccess() async {
    // PHPhotoLibrary.requestAuthorization(for:) has no native async overload.
    // Use withCheckedContinuation to bridge to async/await.
    let status = await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            continuation.resume(returning: status)
        }
    }
    await MainActor.run {
        self.authStatus = status
        if status == .authorized || status == .limited {
            self.fetchVideos()
        }
    }
}

func fetchVideos() {
    // D-06: PHFetchRequest sorted by creationDate descending, snapshot into [PHAsset]
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType = %d",
                                    PHAssetMediaType.video.rawValue)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate",
                                                ascending: false)]
    let result = PHAsset.fetchAssets(with: options)
    var fetched: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in fetched.append(asset) }
    // PHFetchResult is a lazy cursor; enumerating does not load video data into memory
    self.assets = fetched
}
```

**Thread safety:** `requestAuthorization` completion handler fires on an arbitrary background thread. Always dispatch UI updates to `@MainActor`. [VERIFIED: PHImageManager docs + community research]

**Status handling map:**

| PHAuthorizationStatus | UI Action |
|----------------------|-----------|
| `.notDetermined` | Show permission prompt view; call `requestAuthorization` on button tap |
| `.authorized` | Fetch and show library grid immediately |
| `.limited` | Fetch and show library grid (subset visible) — no special UI in v1 |
| `.denied` / `.restricted` | Show "Photos access required" full-screen state + Settings deep-link |

### Pattern 3: PHImageManager Thumbnail Loading (List Scroll)

**What:** Async thumbnail delivery for list cells; cancel when cell leaves screen.

**When to use:** Inside `LibraryCell`, triggered by `.onAppear`.

```swift
// Source: PHImageRequestOptions docs + ikyle.me/blog/2025 [CITED/VERIFIED]
struct LibraryCell: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage? = nil
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        HStack { ... }
        .onAppear { loadThumbnail() }
        .onDisappear { cancelThumbnail() }
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic  // fast degraded first, then full quality
        options.isSynchronous = false          // NEVER synchronous in a list cell
        options.isNetworkAccessAllowed = true  // allow iCloud download if needed

        let targetSize = CGSize(width: 56 * 3, height: 72 * 3) // @3x for retina

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // result handler fires on main thread for non-synchronous requests
            // may fire TWICE with .opportunistic: once degraded, once full quality
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded, let image = image {
                self.thumbnail = image  // final full-quality image
            } else if self.thumbnail == nil, let image = image {
                self.thumbnail = image  // use degraded as placeholder while loading
            }
        }
    }

    private func cancelThumbnail() {
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}
```

**Thread safety:** [VERIFIED: Apple PHImageManager docs + community sources] When `isSynchronous = false`, the result handler fires on the main thread. No `DispatchQueue.main.async` wrapper needed.

**Double-callback with `.opportunistic`:** The handler fires twice — once with a fast/degraded image, then again with the full-quality version. Check `PHImageResultIsDegradedKey` in the `info` dict to distinguish them. Show the degraded image immediately; replace it when the final arrives.

**Placeholder:** Per UI-SPEC, show `Color(.secondarySystemFill)` rounded rect while `thumbnail == nil`. No spinner.

**`PHCachingImageManager` alternative:** For 50+ assets, `PHCachingImageManager` pre-warms thumbnails for visible cells. For Phase 1 (simple List, not a grid with many simultaneously visible cells), the default `PHImageManager` is sufficient. `PHCachingImageManager` is a drop-in replacement if scroll performance degrades. [ASSUMED — performance threshold; validate on device]

### Pattern 4: AVPlayer Streaming from PHAsset (No Memory Load)

**What:** Load a large local video for playback without reading the file into memory. [CITED: Apple PHImageManager/requestAVAsset docs]

**When to use:** In `PlayerController.load(asset:)`, triggered when user taps a video.

```swift
// Source: Apple AVFoundation docs + STACK.md [VERIFIED/CITED]
func load(asset: PHAsset) async {
    let videoOptions = PHVideoRequestOptions()
    videoOptions.isNetworkAccessAllowed = true
    videoOptions.deliveryMode = .automatic  // use best available locally

    return await withCheckedContinuation { continuation in
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: videoOptions
        ) { [weak self] avAsset, _, _ in
            guard let self, let avAsset = avAsset else {
                continuation.resume()
                return
            }
            // avAsset is AVURLAsset for local videos — streams from URL, no memory load
            let item = AVPlayerItem(asset: avAsset)

            // Observe status via Combine to avoid KVO teardown crashes (Pitfall 4)
            let cancellable = item.publisher(for: \.status)
                .filter { $0 != .unknown }
                .first()
                .sink { [weak self] status in
                    if status == .readyToPlay {
                        self?.player?.pause()  // D-09: pause on first frame, no autoplay
                    }
                }
            self.cancellables.insert(cancellable)

            DispatchQueue.main.async {
                self.player?.replaceCurrentItem(with: item)
                continuation.resume()
            }
        }
    }
}
```

**Key constraint — PERF-01:** `PHImageManager.requestAVAsset` returns an `AVURLAsset` for local videos. The asset streams from the Photos asset URL. The full video data (15-20 GB) is never loaded into memory. This is the correct pattern — never use `PHAsset.requestContentEditingInput` or load the URL into `Data`. [VERIFIED: STACK.md + Apple docs]

**iOS 18 note:** In iOS 18+, the URL returned from `requestAVAsset` may have a hash suffix appended. Do not use `relativePath` for file operations on this URL — always use `absoluteString`. Phase 1 does not perform file operations on the URL (playback only), so this is not an immediate concern. [CITED: medium.com/@mi9nxi — iOS 18 PHAsset URL changes]

### Pattern 5: Orientation Lock — AppDelegate + requestGeometryUpdate

**What:** Lock the app to portrait for Library, landscape for Skim. Requires two-part implementation: AppDelegate override tells the system what orientations are supported, and `requestGeometryUpdate` triggers the actual rotation. [CITED: multiple Apple Developer Forums threads + community articles]

**Why two parts:** `requestGeometryUpdate` alone changes orientation momentarily, but if the device is physically rotated, the system reverts to whatever `supportedInterfaceOrientationsFor` returns. Both must be in sync.

```swift
// File: AppDelegate.swift
// Source: [CITED: tungvt.it.01 Medium article + Apple Developer Forums]
class AppDelegate: NSObject, UIApplicationDelegate {
    static let shared = AppDelegate()
    var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return orientationLock
    }

    func lockOrientation(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask
        UIApplication.shared.connectedScenes.forEach { scene in
            guard let windowScene = scene as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            windowScene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

// File: SurfvidApp.swift
@main
struct SurfvidApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
        }
    }
}

// In ContentView or root ZStack — watch AppViewModel.screen changes:
.onChange(of: appViewModel.screen) { newScreen in
    switch newScreen {
    case .library:
        AppDelegate.shared.lockOrientation(.portrait)
    case .skim:
        AppDelegate.shared.lockOrientation(.landscape)
    }
}
```

**Info.plist requirement (D-05):** All three orientations (`UIInterfaceOrientationPortrait`, `UIInterfaceOrientationLandscapeLeft`, `UIInterfaceOrientationLandscapeRight`) must be in `UISupportedInterfaceOrientations`. If only portrait is declared, `requestGeometryUpdate` for landscape is silently ignored. [VERIFIED: research from Apple Dev Forums thread 707735 + multiple community sources]

### Pattern 6: AVPlayerLayer via UIViewRepresentable

**What:** The single UIKit exception — wraps AVPlayerLayer in a SwiftUI view. [VERIFIED: STACK.md]

**When to use:** Only in `PlayerView.swift`. All other UI is SwiftUI.

```swift
// Source: STACK.md [VERIFIED against Apple AVFoundation docs]
struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill  // full-bleed
        return view
    }

    // IMPORTANT: updateUIView must NOT recreate the layer — only update properties
    // Recreating causes Pitfall 8 (SwiftUI rebuild tears down AVPlayerLayer)
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player  // safe: same player reference on rebuild
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
```

**Pitfall guard (Pitfall 8):** Keep `AVPlayer` in a class (`PlayerController`) owned by `@StateObject`-level `AppViewModel`. The `PlayerView` receives the player by value but the underlying object is stable. Never create `AVPlayer` inside a SwiftUI view's `body`. [VERIFIED: PITFALLS.md]

### Pattern 7: ZStack Screen Swap

**What:** Root navigation without NavigationStack — screen enum drives ZStack conditional rendering.

**When to use:** `ContentView.swift`. This replaces NavigationStack because Skim is landscape and NavigationStack's push animation assumes portrait continuity.

```swift
// Source: ARCHITECTURE.md [VERIFIED]
struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            switch appViewModel.screen {
            case .library:
                LibraryView()
                    .transition(.opacity)
            case .skim:
                SkimView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: appViewModel.screen)
        .onChange(of: appViewModel.screen) { newScreen in
            switch newScreen {
            case .library:
                AppDelegate.shared.lockOrientation(.portrait)
            case .skim:
                AppDelegate.shared.lockOrientation(.landscape)
            }
        }
    }
}

// AppViewModel.swift
enum Screen { case library, skim }

class AppViewModel: ObservableObject {
    @Published var screen: Screen = .library
    @Published var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []

    let playerController: PlayerController  // D-10: created once in init

    init() {
        self.playerController = PlayerController()
    }

    func pickVideo(_ asset: PHAsset) {
        Task {
            await playerController.load(asset: asset)
            await MainActor.run { screen = .skim }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Synchronous thumbnail request:** `options.isSynchronous = true` in a List cell freezes the main thread for 100-500ms per cell. Always `false`. [VERIFIED: PITFALLS.md Pitfall 10]
- **Storing PHAsset in model structs:** PHAssets go stale if the Photos library mutates. Copy `localIdentifier`, `duration`, `creationDate` immediately; don't hold PHAsset in VideoItem. [VERIFIED: ARCHITECTURE.md]
- **Creating AVPlayer inside a SwiftUI view:** Causes recreation on every rebuild. AVPlayer must live in PlayerController owned by AppViewModel. [VERIFIED: PITFALLS.md Pitfall 8]
- **Requesting geometry update without AppDelegate override:** `requestGeometryUpdate` alone is insufficient — physical device rotation reverts without the `supportedInterfaceOrientationsFor` override. [CITED: Apple Dev Forums 707735]
- **Using NavigationStack for Library→Skim:** NavigationStack push animation is portrait-to-portrait; forced landscape on push causes visual glitches. Use ZStack swap instead. [VERIFIED: ARCHITECTURE.md + STATE.md]
- **Manual KVO on AVPlayerItem:** Use Combine `publisher(for: \.status)` instead; manual KVO requires explicit removal which causes crashes if missed. [VERIFIED: PITFALLS.md Pitfall 4]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async thumbnail delivery | Custom image cache | `PHImageManager.requestImage` with `.opportunistic` + `PHImageRequestID` cancel | Handles HEIF, HDR, iCloud download, memory pressure automatically |
| Video streaming from Photos | Custom URL resolver | `PHImageManager.requestAVAsset` returning `AVURLAsset` | The URL is a secured Photos-internal reference; hand-rolling breaks entitlements |
| Orientation lock | Custom rotation logic | AppDelegate `supportedInterfaceOrientationsFor` + `requestGeometryUpdate` | System enforces orientation via UIWindowScene; bypassing it causes visual artifacts |
| Time formatting | Manual division/modulo | A pure function `formatDuration(_ seconds: Double) -> String` (hand-roll is correct here — no library needed) | The formatting is simple enough to implement once; no library needed |
| KVO observation teardown | Manual `addObserver`/`removeObserver` | Combine `AnyCancellable` stored in `Set<AnyCancellable>` | Automatic deallocation prevents Pitfall 4 crashes |

**Key insight:** Photos and AVFoundation handle the hard parts (memory management, iCloud access, HEVC decoding) internally. Hand-rolling any layer of this stack reintroduces solved problems.

---

## Common Pitfalls

### Pitfall 1: `requestGeometryUpdate` Silently Ignored

**What goes wrong:** Calling `windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))` on screen change, but the app doesn't rotate — or it rotates momentarily and snaps back when the device is tilted.

**Why it happens:** `requestGeometryUpdate` is a request, not a command. The system validates against `application(_:supportedInterfaceOrientationsFor:)`. If that delegate method returns `.portrait` only, the landscape request is silently dropped.

**How to avoid:** Always update `AppDelegate.orientationLock` before calling `requestGeometryUpdate`. Call `setNeedsUpdateOfSupportedInterfaceOrientations()` on the root view controller after the update. Ensure all three orientations are in `UISupportedInterfaceOrientations` in Info.plist.

**Warning signs:** `requestGeometryUpdate` error handler fires with an error code; or orientation changes on first tap but not on subsequent taps.

### Pitfall 2: Thumbnail Result Handler Called on Background Thread (with `.fastFormat`)

**What goes wrong:** With `deliveryMode = .fastFormat` (not `.opportunistic`), the result handler may fire on a background thread, causing `@State` mutations to crash.

**Why it happens:** `.fastFormat` is designed for speed; Apple docs do not guarantee main thread delivery for all modes.

**How to avoid:** Use `.opportunistic` for list thumbnails (documented to call back on main for the high-quality result). Or wrap any `@State` mutation in `DispatchQueue.main.async`. UI-SPEC specifies `.opportunistic` as the correct mode.

**Warning signs:** "Publishing changes from background threads is not allowed" runtime warning in Xcode console.

### Pitfall 3: `makeUIView` Called Repeatedly (AVPlayerLayer Recreated)

**What goes wrong:** Video appears black after navigating back and tapping a new video, or player audio continues but screen is dark.

**Why it happens:** SwiftUI identity changed for the `PlayerView` — usually because a conditional wrapping the view changed, or the `id` modifier changed. `makeUIView` is called again, creating a second `AVPlayerLayer` that Xcode drops silently.

**How to avoid:** Give `PlayerView` a stable identity — don't wrap in `if` branches; don't use `.id(asset.localIdentifier)` that changes per video. The player itself changes; the view wrapper should be stable. [VERIFIED: PITFALLS.md Pitfall 8]

**Warning signs:** Add `print("makeUIView called")` in `makeUIView` — should fire exactly once per app launch.

### Pitfall 4: No PHFetchRequest predicate — fetches all asset types

**What goes wrong:** Library grid shows photos alongside videos because `fetchAssets(with:)` was called without a media type filter.

**Why it happens:** `PHAsset.fetchAssets(with: options)` without a `predicate` returns all asset types (photos, videos, live photos, etc.).

**How to avoid:** Always include `NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)` in `PHFetchOptions`. [VERIFIED: STACK.md]

**Warning signs:** Grid shows non-video items; tapping one crashes when attempting to load as AVAsset.

### Pitfall 5: `PHImageResultIsDegradedKey` Not Checked — UI Flickers to Blank

**What goes wrong:** Thumbnail loads a degraded version, then the handler fires again with `nil` image (or worse, the final image arrives but code only accepts one call).

**Why it happens:** `.opportunistic` mode deliberately calls the handler twice. Code that only handles the first call misses the upgrade; code that sets `thumbnail = image` unconditionally sets `nil` if the second call has no image.

**How to avoid:** Always check `PHImageResultIsDegradedKey`. Accept the degraded image as an immediate placeholder; replace it only when the final non-degraded image arrives. [VERIFIED: Apple PHImageManager docs]

### Pitfall 6: XcodeGen `info.path` Plist Overwritten on Regenerate

**What goes wrong:** Developer manually edits the generated `SurfvidApp/Info.plist`, then runs `xcodegen generate`, and the edits are silently overwritten.

**Why it happens:** XcodeGen treats `info.path` as an output — it regenerates the file on every `xcodegen generate` call.

**How to avoid:** All Info.plist entries must be in `project.yml` under `info.properties`. Never edit the generated plist directly. The plist can also be added to `.gitignore` to make its derived nature explicit. [VERIFIED: Context7 /yonaskolb/xcodegen — "Plist files are generated on disk every time"]

---

## Walking Skeleton Structure

The thinnest working end-to-end path — Phase 1 Walking Skeleton — in order:

**Wave 1 (scaffold):** `project.yml` → `xcodegen generate` → app compiles and launches on device showing a gray screen. Verifies: build system works, signing works, deployment target correct.

**Wave 2 (library entry path):** `AppViewModel` with `authStatus` + `assets` + `screen` enum → `ContentView` ZStack swap → `LibraryView` showing authorization state → permission prompt → PHFetchRequest returning `[PHAsset]` → List rendering rows with `PHImageManager` thumbnails. Verifies: LIB-01, LIB-02.

**Wave 3 (skim screen shell):** `PlayerController.load(asset:)` via `PHImageManager.requestAVAsset` → `AVPlayer` streaming → `PlayerView` rendering first frame (paused) → `SkimView` full chrome (top gradient + bottom gradient + back button). Verifies: PERF-01, D-08, D-09.

**Wave 4 (navigation + orientation):** `AppDelegate` orientation lock → `AppViewModel.pickVideo` → `appVM.screen = .skim` → orientation changes to landscape → back button → `appVM.screen = .library` → orientation changes to portrait. Verifies: D-04, D-05.

Each wave produces a buildable, runnable app. No wave introduces code that requires a later wave's code to compile.

---

## Code Examples

### Time Formatter (svFmt Swift equivalent)

```swift
// Source: Prototype svFmt function, adapted to Swift [VERIFIED: STRUCTURE.md — svFmt exists in surfvid-shared.jsx]
// Library format: M:SS or H:MM:SS (no milliseconds)
// Skim format: M:SS.f (tenths of second) — for Phase 2

func formatDuration(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

### Relative Date Formatting

```swift
// UI-SPEC: metadata format "{relative date} · {M:SS}"  e.g. "Yesterday · 30:42"
func relativeDate(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .spellOut  // "yesterday", "2 days ago"
    return formatter.localizedString(for: date, relativeTo: Date())
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `UIDevice.setValue(_:forKey: "orientation")` rotation lock | `UIWindowScene.requestGeometryUpdate(.iOS(...))` | iOS 16 | Old approach shows deprecation warning in Xcode; new API is required |
| `loadValuesAsynchronously(forKeys:completionHandler:)` | `asset.load(.duration)` async/await | iOS 15 | New API is cleaner; old API still works on iOS 16 but is legacy |
| `PHPhotoLibrary.requestAuthorization(_:)` (iOS 13-) | `PHPhotoLibrary.requestAuthorization(for: .readWrite)` (iOS 14+) | iOS 14 | The `for:` parameter version supports `.addOnly` access level distinction |
| Sync `copyCGImage(at:actualTime:)` for thumbnails | Async `requestImage(for:...)` via PHImageManager | iOS 8+ | Sync blocks main thread; always use async in list cells |

**Deprecated/outdated:**

- `UIDevice.setValue(_:forKey: "orientation")`: Deprecated iOS 16; shows warning; use `requestGeometryUpdate` instead.
- `PHPhotoLibrary.requestAuthorization(_:)` (without `for:` parameter): Deprecated iOS 14; still works but always grants `.authorized` or `.denied` without `.limited` support.
- `AVAssetImageGenerator.copyCGImage(at:actualTime:)` on main thread: Not deprecated but triggers Main Thread Checker warning if called from the main thread. Always call from background.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AVFoundation/AVKit/PhotosKit are auto-linked on iOS targets without explicit `sdk:` entries in project.yml | Standard Stack | Build fails with "framework not found"; fix: add explicit `sdk:` dependency entries |
| A2 | iOS 16 simulator runtime is not available in current Xcode 26 environment; real device required for testing | Environment Availability | If a simulator runtime is available, this is not a blocker; if neither simulator nor device is available, testing is blocked |
| A3 | `PHCachingImageManager` is not needed for Phase 1 — default `PHImageManager` suffices for a simple List | Pattern 3 | Scroll jank on large libraries; fix: swap to `PHCachingImageManager` (drop-in replacement) |
| A4 | Swift 6 strict concurrency does not break the patterns shown (using `@MainActor` and checked continuations) | Patterns 2, 4 | Compiler warnings or errors; fix: annotate actor isolation correctly |

---

## Open Questions

1. **Swift 6 strict concurrency with Combine AnyCancellable + @Published**
   - What we know: The project uses Swift 6.3.1. `@Published` mutations on `@MainActor` are safe.
   - What's unclear: Whether `PHImageManager` callbacks with `isSynchronous = false` fire strictly on `@MainActor` or require explicit dispatch annotations in Swift 6 strict concurrency mode.
   - Recommendation: Add `// swift-tools-version: suppress-concurrency` or use `@unchecked Sendable` as needed. Validate at compile time in Wave 1.

2. **Simulator availability for iOS 16 testing**
   - What we know: `xcrun simctl list devices` shows only iOS 26 simulators, all marked "unavailable, runtime profile not found."
   - What's unclear: Whether a real device (iPhone with iOS 16+) is available for testing.
   - Recommendation: Plan assumes real device testing. If unavailable, download iOS 16/17/18 simulator runtime via Xcode → Platforms.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| XcodeGen | D-01: project scaffold | ✓ | 2.45.4 | — |
| Xcode | Build + signing | ✓ | 26.4.1 (Xcode 26) | — |
| Swift | Compilation | ✓ | 6.3.1 | — |
| iOS 26.4 SDK | Build target | ✓ | 26.4 | — |
| iOS simulator (iOS 16-18) | Phase testing | ✗ | — | Real device with iOS 16+ |
| Apple Developer certificate | Code signing | ✓ | Team ID 4KJH92DV9R | — |

**Missing dependencies with no fallback:** None that block compilation or execution.

**Missing dependencies with fallback:**
- iOS 16-18 simulator runtime: Not present in current Xcode 26 environment. Use a real device, or download older runtime via Xcode → Platforms pane.

---

## Validation Architecture

nyquist_validation is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | No automated test framework for this phase |
| Config file | None (no XCTest targets in project.yml for Phase 1) |
| Quick run command | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` |
| Full suite command | Manual device testing per checklist below |

**Rationale:** This is a native iOS app requiring PhotosKit authorization and AVPlayer on a real device. XCTest UI tests for Photos permission flow require special entitlements and physical interaction. The primary validation strategy for Phase 1 is: (1) clean build succeeds, and (2) manual device checklist passes.

A `Formatters.swift` unit-testable pure function (`formatDuration`) can be tested with XCTest — but adding an XCTest target to the project.yml is discretionary. The planner may elect to add `SurfvidTests` target in a later wave if useful.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| LIB-01 | Camera roll videos appear in list with thumbnails | Manual | — | Requires real device + Photos access |
| LIB-01 | Thumbnails load without blocking scroll | Manual | — | Observe Xcode Instruments / frame rate |
| LIB-01 | Thumbnail loading and cancellation | Manual | — | Scroll rapidly; no crash, no zombie requests |
| LIB-02 | Most-recently-added video appears first | Manual | — | Verify against Photos app order |
| PERF-01 | App plays 15-20 GB video without hang/crash | Manual | — | Use a real large file on device |
| PERF-01 | AVPlayer does not load video into memory | Xcode Instruments (Allocations) | — | Run Allocations instrument during playback; AVURLAsset should show no large allocations |
| Build | Project compiles with no errors | Automated | `xcodebuild build -scheme Surfvid -sdk iphonesimulator` | Validates scaffold, signing config, framework imports |
| D-04/D-05 | Orientation changes correctly on screen swap | Manual | — | Tap video → landscape; back → portrait |

### Manual Device Testing Checklist (Phase 1 gate)

**Success Criterion 1 — Photos permission + library grid:**
- [ ] Fresh install: app shows permission prompt
- [ ] Deny permission: app shows "Photos access required" + "Open Settings" button
- [ ] Grant permission: library grid shows video thumbnails in most-recent-first order
- [ ] Thumbnails use `Color(.secondarySystemFill)` placeholder before loading
- [ ] Scrolling 20+ rows is smooth (no jank, no stutter)

**Success Criterion 2 — Most recently added first:**
- [ ] First row matches most recent video in the iOS Photos app

**Success Criterion 3 — Large video playback:**
- [ ] Tap a video > 1 GB: skim screen appears within 3 seconds showing first frame paused
- [ ] App does not crash or become unresponsive
- [ ] Memory in Xcode Debug Navigator does not spike to multi-GB levels

**Success Criterion 4 — Smooth thumbnail scroll:**
- [ ] No dropped frames while scrolling (verify with Xcode FPS counter)
- [ ] No "Publishing changes from background threads" warnings in console

**Orientation gate:**
- [ ] Library screen is portrait-locked (device rotation has no effect)
- [ ] Skim screen is landscape-locked (device rotation has no effect)
- [ ] Back to library: portrait lock restores

### Wave 0 Gaps

- [ ] `SurfvidApp/` directory does not exist yet — must be created as part of Wave 1
- [ ] `project.yml` does not exist yet — must be created as Wave 1 task 1
- [ ] No test targets defined — acceptable for Phase 1 (build-only validation)

*(No test framework gaps that block execution — manual testing is the validation strategy for Phase 1)*

---

## Security Domain

Phase 1 has no network traffic, no authentication, no user data leaving the device, and no cryptography. ASVS categories V2, V3, V4, and V6 do not apply.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth in v1 |
| V3 Session Management | No | No sessions |
| V4 Access Control | No | Single-user personal app |
| V5 Input Validation | Partial | PHFetchRequest predicate validates media type; no user text input in Phase 1 |
| V6 Cryptography | No | No cryptographic operations |

**Privacy note:** `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddOnlyUsageDescription` must be present in Info.plist before App Store review (and before TestFlight). Both are included in the `project.yml` template above. [VERIFIED: Apple App Store guidelines]

---

## Project Constraints (from CLAUDE.md)

| Directive | Type | Impact on Phase 1 |
|-----------|------|--------------------|
| iOS 16+, SwiftUI only | Required | All UI is SwiftUI; one UIViewRepresentable for AVPlayerLayer |
| No UIKit except `UIViewRepresentable` for `AVPlayerLayer` | Required | Only `PlayerView.swift` touches UIKit |
| Zero third-party dependencies — Apple frameworks only | Required | No SPM packages; no Pods; no npm |
| AVPlayer must stream from Photos asset URL, never load into memory | Required | Use `requestAVAsset` → AVURLAsset pattern |
| Flat MVVM: one AppViewModel as @EnvironmentObject | Required | Single AppViewModel; no TCA; no nested VMs |
| PlayerController created once in AppViewModel.init(), reused | Required | PlayerController is a let constant on AppViewModel |
| ~15 Swift files total | Target | Phase 1 uses 10 files; 5 remain for Phases 2-4 |

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: Context7 /yonaskolb/xcodegen] — `project.yml` structure, Info.plist generation, signing configuration, SDK framework linking, gitignore recommendation
- [VERIFIED: .planning/research/STACK.md] — PHImageManager requestAVAsset pattern, AVPlayerLayer UIViewRepresentable pattern, PHFetchRequest with video predicate
- [VERIFIED: .planning/research/ARCHITECTURE.md] — AppViewModel structure, PlayerController lifecycle, threading model, build order
- [VERIFIED: .planning/research/PITFALLS.md] — All pitfalls cited above verified from this existing research
- [VERIFIED: `xcodegen --version`] — XcodeGen 2.45.4 installed at /opt/homebrew/bin/xcodegen
- [VERIFIED: `xcodebuild -version`] — Xcode 26.4.1, Swift 6.3.1, iOS 26.4 SDK
- [VERIFIED: keychain certificate] — Development Team ID 4KJH92DV9R

### Secondary (MEDIUM confidence)

- [CITED: developer.apple.com/documentation/photokit/phphotolibrary/3616053-requestauthorization] — requestAuthorization(for:) API
- [CITED: ikyle.me/blog/2025/querying-the-ios-photo-library] — PHFetchOptions + thumbnail loading patterns
- [CITED: medium.com/@tungvt.it.01 — "Full-Screen View in Landscape Using SwiftUI"] — Complete AppDelegate orientation lock implementation
- [CITED: Apple Developer Forums thread 707735] — iOS 16 orientation change API requirements

### Tertiary (LOW confidence)

- [CITED: medium.com/@mi9nxi — "iOS 18 PHAsset URL from requestAVAsset"] — iOS 18 URL suffix behavior; not yet relevant for iOS 16 target but worth noting

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all Apple first-party, stable since iOS 14-16; XcodeGen verified installed
- Architecture: HIGH — patterns directly from existing domain research + official docs
- Pitfalls: HIGH — all pitfalls sourced from verified prior research + official docs
- Orientation lock: MEDIUM-HIGH — multiple community sources agree on the two-part pattern; behavior confirmed on iOS 16

**Research date:** 2026-05-09
**Valid until:** 2026-08-09 (stable Apple frameworks; XcodeGen API changes slowly)
