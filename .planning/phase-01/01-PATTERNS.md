# Phase 1: App Shell & Video Browsing — Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 10 Swift files + 1 YAML config
**Analogs found:** 0 / 10 (greenfield — no existing Swift codebase)

> This is a greenfield SwiftUI iOS app. There are no existing Swift source files to use as analogs.
> All patterns come directly from the verified code excerpts in RESEARCH.md (Patterns 1-7) and the
> Code Examples section. The JSX prototype in `Surfvid/` is used for visual/layout intent only.

---

## File Classification

| New File | Role | Data Flow | Pattern Source | Source Quality |
|----------|------|-----------|----------------|----------------|
| `project.yml` | config | — | RESEARCH.md Pattern 1 | exact (verified xcodegen spec) |
| `SurfvidApp/SurfvidApp.swift` | entry-point | request-response (app lifecycle) | RESEARCH.md Pattern 5 | exact |
| `SurfvidApp/AppDelegate.swift` | middleware | event-driven (orientation lock) | RESEARCH.md Pattern 5 | exact |
| `SurfvidApp/AppViewModel.swift` | view-model | CRUD + event-driven | RESEARCH.md Pattern 2 + Pattern 7 | exact |
| `SurfvidApp/PlayerController.swift` | controller | streaming (AVPlayer lifecycle) | RESEARCH.md Pattern 4 | exact |
| `SurfvidApp/ContentView.swift` | view | request-response (screen routing) | RESEARCH.md Pattern 7 | exact |
| `SurfvidApp/Library/LibraryView.swift` | view | request-response (permission states + list) | RESEARCH.md Pattern 2 + UI-SPEC | exact (pattern) + design contract |
| `SurfvidApp/Library/LibraryCell.swift` | view | request-response (async thumbnail) | RESEARCH.md Pattern 3 | exact |
| `SurfvidApp/Skim/SkimView.swift` | view | streaming (chrome overlay layout) | RESEARCH.md Pattern 6 + UI-SPEC | exact (pattern) + design contract |
| `SurfvidApp/Skim/PlayerView.swift` | view | streaming (AVPlayerLayer bridge) | RESEARCH.md Pattern 6 | exact |
| `SurfvidApp/Shared/Formatters.swift` | utility | transform (pure function) | RESEARCH.md Code Examples | exact |

---

## Pattern Assignments

### `project.yml` (config)

**Source:** RESEARCH.md — Pattern 1: XcodeGen project.yml for SwiftUI iOS 16 App

**Complete spec to copy as-is** (RESEARCH.md lines 193-232):

```yaml
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

**Gitignore note:** Add `*.xcodeproj/` to `.gitignore`. Commit `project.yml` only.
**Critical:** All three orientation values must be listed in `UISupportedInterfaceOrientations` or `requestGeometryUpdate` for landscape is silently ignored (Pitfall 1 / D-05).
**Info.plist:** Never edit `SurfvidApp/Info.plist` directly — it is regenerated on every `xcodegen generate` (Pitfall 6).

---

### `SurfvidApp/SurfvidApp.swift` (entry-point, app lifecycle)

**Source:** RESEARCH.md — Pattern 5: Orientation Lock, `@main` struct block (lines 433-445)

**Complete file pattern** (RESEARCH.md lines 433-445):

```swift
import SwiftUI

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
```

**Key points:**
- `@UIApplicationDelegateAdaptor` wires the AppDelegate for orientation support — mandatory, not optional.
- `AppViewModel` is created here as `@StateObject` — the single root owner.
- `ContentView` receives it via `.environmentObject` — all child views use `@EnvironmentObject var appViewModel: AppViewModel`.

---

### `SurfvidApp/AppDelegate.swift` (middleware, event-driven orientation lock)

**Source:** RESEARCH.md — Pattern 5: Orientation Lock, AppDelegate block (lines 409-431)

**Complete file pattern** (RESEARCH.md lines 409-431):

```swift
import UIKit

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
```

**Key points:**
- `static let shared` enables call-site access from `ContentView`'s `.onChange` handler without injecting via environment.
- `lockOrientation` must update `orientationLock` BEFORE calling `requestGeometryUpdate` — the system validates the request against this value (Pitfall 1).
- `setNeedsUpdateOfSupportedInterfaceOrientations()` on the root view controller is required; without it, physical device rotation reverts after the geometry update.

---

### `SurfvidApp/AppViewModel.swift` (view-model, CRUD + event-driven)

**Source:** RESEARCH.md — Pattern 7 (AppViewModel struct, lines 527-547) + Pattern 2 (Photos authorization + fetch, lines 252-278)

**Screen enum and AppViewModel skeleton** (RESEARCH.md lines 527-547):

```swift
import SwiftUI
import Photos
import Combine

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

**Photos authorization + fetch methods** (RESEARCH.md lines 252-278) — add to AppViewModel body:

```swift
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

**Key points:**
- `authStatus` is initialized from `PHPhotoLibrary.authorizationStatus(for: .readWrite)` on `init()` — not `.notDetermined` — so returning users skip the prompt immediately.
- `requestPhotosAccess()` is called from `LibraryView.onAppear` when `authStatus == .notDetermined`.
- `fetchVideos()` MUST include the media type predicate — omitting it returns photos alongside videos (Pitfall 4).
- `playerController` is a `let` constant — never recreated (D-10).
- All `@Published` mutations inside `requestPhotosAccess` are dispatched to `@MainActor`.

---

### `SurfvidApp/PlayerController.swift` (controller, streaming)

**Source:** RESEARCH.md — Pattern 4: AVPlayer Streaming from PHAsset (lines 360-395)

**Complete file pattern** (RESEARCH.md lines 360-395):

```swift
import AVFoundation
import Photos
import Combine

class PlayerController: ObservableObject {
    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()

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
                            self?.player.pause()  // D-09: pause on first frame, no autoplay
                        }
                    }
                self.cancellables.insert(cancellable)

                DispatchQueue.main.async {
                    self.player.replaceCurrentItem(with: item)
                    continuation.resume()
                }
            }
        }
    }
}
```

**Key points:**
- `player` is a `let` constant on `PlayerController` — never replaced, only its current item changes. This is the stable reference `PlayerView` holds (Pitfall guard / Pattern 6).
- Use `requestAVAsset` not `requestContentEditingInput` — the former returns an `AVURLAsset` that streams; the latter loads data into memory (PERF-01).
- Combine `AnyCancellable` stored in `Set<AnyCancellable>` for automatic KVO teardown — never use manual `addObserver`/`removeObserver` (Pitfall 4 / RESEARCH.md Anti-Patterns).
- `pause()` in the status sink satisfies D-09 (paused on first frame, no autoplay).
- `[weak self]` in both the `requestAVAsset` closure and the sink closure prevents retain cycles.

---

### `SurfvidApp/ContentView.swift` (view, screen routing)

**Source:** RESEARCH.md — Pattern 7: ZStack Screen Swap (lines 501-526)

**Complete file pattern** (RESEARCH.md lines 501-526):

```swift
import SwiftUI

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
```

**Key points:**
- ZStack swap replaces NavigationStack — NavigationStack's push animation assumes portrait-to-portrait; forced landscape on push causes visual glitches (RESEARCH.md Anti-Patterns).
- `.onChange(of: appViewModel.screen)` is the orientation lock integration point (D-04). This is where `AppDelegate.shared.lockOrientation` is called, not inside AppViewModel.
- `.animation(.easeOut(duration: 0.2), value:)` drives the 0.2s opacity transition (UI-SPEC — Library → Skim Transition).
- Do NOT wrap `LibraryView` or `SkimView` in `if` branches — use `switch` to preserve SwiftUI identity stability.

---

### `SurfvidApp/Library/LibraryView.swift` (view, permission states + list)

**Source:** RESEARCH.md — Pattern 2 (authorization status map, lines 283-291) + UI-SPEC (permission flow, list layout)

**Structure pattern — state-driven body:**

```swift
import SwiftUI
import Photos

struct LibraryView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        switch appViewModel.authStatus {
        case .notDetermined:
            // Full-screen permission prompt — button calls appViewModel.requestPhotosAccess()
            PermissionPromptView()
        case .denied, .restricted:
            // Full-screen error + "Open Settings" deep-link
            PermissionDeniedView()
        case .authorized, .limited:
            // Library grid
            libraryList
        @unknown default:
            PermissionPromptView()
        }
    }

    private var libraryList: some View {
        // SwiftUI List with .listStyle(.plain) — UI-SPEC LIB-01
        List(appViewModel.assets, id: \.localIdentifier) { asset in
            LibraryCell(asset: asset)
                .onTapGesture { appViewModel.pickVideo(asset) }
                .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                .listRowSeparator(.hidden)  // custom hairline via cell
        }
        .listStyle(.plain)
    }
}
```

**Visual contract from UI-SPEC and prototype:**
- Screen background: `Color(.systemBackground)` (maps to `#FAFAF7` warm white in light mode).
- Header: "SURFVID" wordmark (caption, weight 500, uppercase, letterSpacing +1.2) + video count badge at top-right — `Color(.secondaryLabel)`.
- Title: "Pick a recording" — 38pt semibold SF Pro Display, letterSpacing -1.4pt.
- Subtitle: "Skim it with your finger. Mark In and Out to clip." — body, `Color(.secondaryLabel)`.
- Tab row: Photos / iCloud / Files — active tab: weight 600, `Color(.label)`, 1.5pt accent underline; inactive: weight 400, `Color(.secondaryLabel)`. Tab row has hairline bottom border `Color(.separator)`.
- Horizontal inset: 24pt (lg spacing token).
- `onAppear`: call `appViewModel.requestPhotosAccess()` if `authStatus == .notDetermined`.

**Permission denied view key elements (UI-SPEC Copywriting):**
- Heading: "Photos access required"
- Body: "Surfvid needs read access to your camera roll to show your videos."
- CTA: "Open Settings" — `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`

---

### `SurfvidApp/Library/LibraryCell.swift` (view, async thumbnail)

**Source:** RESEARCH.md — Pattern 3: PHImageManager Thumbnail Loading (lines 298-342)

**Complete file pattern** (RESEARCH.md lines 298-342):

```swift
import SwiftUI
import Photos

struct LibraryCell: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage? = nil
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail area — 56×72pt per UI-SPEC
            thumbnailView
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.localIdentifier)  // replace with video title when available
                    .font(.body)
                    .lineLimit(1)
                Text(metadataString)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .onAppear { loadThumbnail() }
        .onDisappear { cancelThumbnail() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            // UI-SPEC: Color(.secondarySystemFill) placeholder, no spinner
            Color(.secondarySystemFill)
        }
    }

    private var metadataString: String {
        // UI-SPEC Copywriting: "{relative date} · {M:SS}"
        let date = relativeDate(for: asset.creationDate ?? Date())
        let duration = formatDuration(asset.duration)
        return "\(date) · \(duration)"
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

**Key points:**
- Thumbnail size: 56×72pt at @3x = 168×216 pixels — matches UI-SPEC thumbnail spec and prototype dimensions.
- `isSynchronous = false` is mandatory — synchronous thumbnail requests in a List freeze the main thread 100-500ms per cell (RESEARCH.md Anti-Patterns / Pitfall 10).
- `.opportunistic` fires the handler twice — `PHImageResultIsDegradedKey` check prevents flicker and blank states (Pitfall 5).
- Metadata format from UI-SPEC: `"{relative date} · {M:SS}"` — calls `relativeDate()` and `formatDuration()` from `Formatters.swift`.
- Failed thumbnail state: show `Image(systemName: "film")` on `Color(.secondarySystemFill)` (UI-SPEC — Library Row Thumbnail states).

---

### `SurfvidApp/Skim/SkimView.swift` (view, chrome overlay layout)

**Source:** RESEARCH.md — Pattern 6 (AVPlayerLayer via UIViewRepresentable, structural container) + UI-SPEC (Skim Screen layout) + prototype `surfvid-paper-skim-landscape.jsx` (visual reference)

**ZStack chrome structure** (maps prototype lines 82-220 → SwiftUI):

```swift
import SwiftUI
import AVFoundation

struct SkimView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: full-bleed video — stable identity (Pitfall guard)
                Color.black.ignoresSafeArea()
                PlayerView(player: appViewModel.playerController.player)
                    .ignoresSafeArea()

                // Layer 2: top chrome overlay
                VStack {
                    topChrome
                    Spacer()
                    bottomChrome
                }
                // Skim insets: 60pt left (Dynamic Island), 34pt right (home indicator)
                // UI-SPEC: "use geometry.safeAreaInsets.trailing at runtime, not hard-code 34pt"
                .padding(.leading, 60)
                .padding(.trailing, geometry.safeAreaInsets.trailing > 0
                    ? geometry.safeAreaInsets.trailing : 34)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // Top chrome: ← Library   [Video Title]   [Done]
    // UI-SPEC: gradient rgba(0,0,0,0.45) → clear
    private var topChrome: some View {
        HStack {
            Button(action: { appViewModel.screen = .library }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Library")
                }
                .foregroundColor(.white)
                .font(.body)
            }
            .accessibilityLabel("Back to Library")

            Spacer()

            // Video title — truncated, center
            // Phase 1: placeholder text; Phase 2 wires to actual asset title
            Text("Video")
                .font(.body.weight(.medium))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Done pill
            Button("Done") { /* Phase 2 */ }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .foregroundColor(Color(.label))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.45), .clear],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // Bottom chrome: timecode / filmstrip placeholder / hint
    // UI-SPEC: gradient rgba(0,0,0,0.55) → clear
    private var bottomChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timecode row — Phase 2 wires to actual playhead
            HStack(alignment: .lastTextBaseline) {
                Text("0:00.0")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("/ 0:00")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                Text("0 marked")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
            }

            // Mini filmstrip placeholder (28pt height per prototype)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .frame(height: 28)

            // Hint label
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .foregroundColor(Color.white.opacity(0.7))
                Text("Drag to skim · Tap to hide")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
```

**Key points:**
- `PlayerView` must have stable SwiftUI identity — do NOT wrap it in `if` branches or apply `.id(asset.localIdentifier)` (Pitfall guard / Pitfall 3). Use `ZStack` with `PlayerView` always present.
- Safe-area insets: use `GeometryReader` to read `safeAreaInsets.trailing` at runtime rather than hard-coding 34pt (UI-SPEC Spacing table note on 34pt).
- Left inset 60pt hard-coded is acceptable (Dynamic Island clearance — hardware constant per prototype `INSET_LEFT = 60`).
- All colors use the dark-theme tokens from UI-SPEC: `Color.black.opacity(0.45)` top gradient, `Color.black.opacity(0.55)` bottom gradient, `Color.white` primary text, `Color.white.opacity(0.55)` secondary text.
- `appViewModel.screen = .library` on back button — the `.onChange` in `ContentView` then fires `AppDelegate.shared.lockOrientation(.portrait)`.

---

### `SurfvidApp/Skim/PlayerView.swift` (view, AVPlayerLayer UIKit bridge)

**Source:** RESEARCH.md — Pattern 6: AVPlayerLayer via UIViewRepresentable (lines 466-489)

**Complete file pattern** (RESEARCH.md lines 466-489):

```swift
import SwiftUI
import AVFoundation

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

**Key points:**
- `videoGravity = .resizeAspectFill` fills the view; video is cropped to fill the frame (full-bleed per UI-SPEC Skim Screen layout).
- `updateUIView` only reassigns `player` — never creates a new `AVPlayerLayer`. Creating a second layer in `updateUIView` causes the black screen bug (Pitfall 3).
- Add `print("makeUIView called")` during development — should fire exactly once per app launch to confirm stable identity.
- This is the ONLY UIKit usage in the entire app (CLAUDE.md constraint: "no UIKit except a single `UIViewRepresentable` for `AVPlayerLayer`").

---

### `SurfvidApp/Shared/Formatters.swift` (utility, pure transform functions)

**Source:** RESEARCH.md — Code Examples: Time Formatter + Relative Date Formatting (lines 654-682)

**Complete file pattern** (RESEARCH.md lines 654-682):

```swift
import Foundation

// Duration formatter — no milliseconds for Library display
// UI-SPEC Copywriting: M:SS for under 1 hour; H:MM:SS for 1 hour or more
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

// Relative date formatter — UI-SPEC Copywriting: "Yesterday · 30:42" format
func relativeDate(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .spellOut  // "yesterday", "2 days ago"
    return formatter.localizedString(for: date, relativeTo: Date())
}
```

**Phase 2 extension (declare now, implement in Phase 2):**

```swift
// Skim timecode — M:SS.f (tenths of second) for skim screen playhead
// Prototype: svFmt(seconds) → "0:12.3" or "H:MM:SS.f"
// Implement in Phase 2 when playhead timecode is wired
func formatTimecode(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    let tenths = Int((seconds - Double(totalSeconds)) * 10)

    if hours > 0 {
        return String(format: "%d:%02d:%02d.%d", hours, minutes, secs, tenths)
    } else {
        return String(format: "%d:%02d.%d", minutes, secs, tenths)
    }
}
```

**Key points:**
- These are plain top-level functions, not methods on a struct — they are imported directly wherever needed with no namespace.
- `RelativeDateTimeFormatter` with `.spellOut` produces "yesterday", "2 days ago", "3 weeks ago" — matching the prototype's `v.when` field and UI-SPEC copywriting contract.
- The Phase 2 `formatTimecode` variant adds `.f` (tenths) for the skim screen playhead; declare the stub now so Phase 2 only needs to fill the body.

---

## Shared Patterns

### EnvironmentObject Access
**Apply to:** All view files (`LibraryView`, `LibraryCell` indirectly via parent, `SkimView`, `ContentView`)

```swift
@EnvironmentObject var appViewModel: AppViewModel
```

- Set once at the root in `SurfvidApp.body` via `.environmentObject(appViewModel)`.
- All child views declare `@EnvironmentObject var appViewModel: AppViewModel` — no explicit passing needed.
- `LibraryCell` receives `PHAsset` as a `let` prop from `LibraryView`'s `List` — it does NOT need `@EnvironmentObject` unless it needs to call `pickVideo`.

### MainActor Dispatch for @Published Mutations
**Apply to:** `AppViewModel.requestPhotosAccess()`, `PlayerController.load(asset:)`, any callback-based API result handler

```swift
await MainActor.run {
    self.somePublishedProperty = value
}
```

- All `@Published` property mutations must happen on the main thread.
- `PHPhotoLibrary.requestAuthorization` completion fires on a background thread — always dispatch to `@MainActor`.
- `PHImageManager.requestImage` with `isSynchronous = false` fires on main by default, but explicit `@MainActor` dispatch is defensive and harmless.

### Combine AnyCancellable Storage
**Apply to:** `PlayerController`

```swift
private var cancellables = Set<AnyCancellable>()
```

- All `sink` subscriptions are stored in `cancellables` for automatic deallocation.
- Never use manual `addObserver`/`removeObserver` on `AVPlayerItem` (RESEARCH.md Anti-Patterns).

### weak self in Closures
**Apply to:** All escaping closures capturing `self` — `PlayerController.load`, `LibraryCell.loadThumbnail`

```swift
{ [weak self] ... in
    guard let self else { return }
    ...
}
```

- Required to prevent retain cycles in `PHImageManager` callbacks and Combine sinks.

---

## No Analog Found

All 10 files have exact pattern matches from RESEARCH.md verified code excerpts. There are no files requiring invention from scratch.

| File | Why No Analog Needed |
|------|---------------------|
| n/a | All patterns provided as verified code in RESEARCH.md Patterns 1-7 and Code Examples |

---

## Visual Layout Reference (JSX Prototype → SwiftUI Mapping)

The JSX prototype is a visual contract only. Key measurements extracted for the SwiftUI implementation:

| Prototype Value | SwiftUI Equivalent | File |
|----------------|-------------------|------|
| `paddingTop: 60` | `.safeAreaInset(edge: .top)` or `Spacer` respecting safe area | `LibraryView` |
| `padding: '14px 24px 6px'` | `.padding(.horizontal, 24).padding(.vertical, 14)` | `LibraryView` header |
| `fontSize: 38, letterSpacing: -1.4` | `.font(.custom("SF Pro Display", size: 38)).tracking(-1.4)` | `LibraryView` title |
| `width: 56, height: 72` (thumbnail) | `.frame(width: 56, height: 72)` | `LibraryCell` |
| `padding: '14px 0'` (row) | `.listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))` | `LibraryView` list |
| `INSET_LEFT = 60` | `.padding(.leading, 60)` | `SkimView` chrome |
| `INSET_RIGHT = 34` | `geometry.safeAreaInsets.trailing` (runtime) | `SkimView` chrome |
| `rgba(0,0,0,0.45)` top gradient | `Color.black.opacity(0.45)` → `.clear` | `SkimView` topChrome |
| `rgba(0,0,0,0.55)` bottom gradient | `.clear` → `Color.black.opacity(0.55)` | `SkimView` bottomChrome |
| `height: 28` (filmstrip) | `.frame(height: 28)` | `SkimView` bottomChrome |
| `background: 'rgba(255,255,255,0.92)'` (Done pill) | `Color.white` background | `SkimView` Done button |

---

## Metadata

**Analog search scope:** Greenfield — no existing Swift source files. Patterns sourced exclusively from RESEARCH.md (verified code excerpts from Apple documentation, XcodeGen docs, and confirmed community patterns).
**Files scanned:** 2 JSX prototype files (visual reference only), 4 planning docs (RESEARCH.md, CONTEXT.md, UI-SPEC.md, CLAUDE.md)
**Pattern extraction date:** 2026-05-09
