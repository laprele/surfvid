# Phase 4: Export - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 6 (3 new, 3 modified)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `SurfvidApp/Export/ExportManager.swift` | service | file-I/O + event-driven | `SurfvidApp/PlayerController.swift` | role-match (ObservableObject manager with async ops + callbacks) |
| `SurfvidApp/Export/DoneView.swift` | component | request-response | `SurfvidApp/Review/ReviewView.swift` | role-match (full-screen dark SwiftUI view, ZStack scaffold) |
| `SurfvidApp/Review/ActivityViewController.swift` | utility | request-response | `SurfvidApp/Skim/PlayerView.swift` | role-match (UIViewRepresentable/UIViewControllerRepresentable bridge) |
| `SurfvidApp/AppViewModel.swift` | store | CRUD + event-driven | self (existing file to modify) | exact |
| `SurfvidApp/ContentView.swift` | controller | request-response | self (existing file to modify) | exact |
| `SurfvidApp/Review/ReviewView.swift` | component | CRUD | self (existing file to modify) | exact |

---

## Pattern Assignments

### `SurfvidApp/Export/ExportManager.swift` (service, file-I/O + event-driven)

**Analog:** `SurfvidApp/PlayerController.swift`

**Imports pattern** (PlayerController.swift lines 1-4):
```swift
import AVFoundation
import Photos
import Combine
import QuartzCore
```
ExportManager needs `AVFoundation`, `Photos`, `Combine` (for `ObservableObject`). Drop `QuartzCore`.

**Class declaration pattern** (PlayerController.swift lines 6-8):
```swift
class PlayerController: ObservableObject {
    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
```
ExportManager mirrors this: `class ExportManager: ObservableObject` with no stored `AVPlayer` equivalent, but same `private var cancellables` field if needed.

**objectWillChange forwarding setup** — this is the critical pattern. ExportManager is NOT wired into the `init()` pattern below directly; it is AppViewModel that holds it and sinks its `objectWillChange`. See AppViewModel section for the sink. ExportManager itself needs no extra setup — it only needs to be `ObservableObject` and use `@Published` for any properties that need to propagate.

**Async callback pattern with withCheckedContinuation** (PlayerController.swift lines 38-66):
```swift
func load(asset: PHAsset) async {
    let videoOptions = PHVideoRequestOptions()
    videoOptions.isNetworkAccessAllowed = true
    videoOptions.deliveryMode = .automatic

    return await withCheckedContinuation { continuation in
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: videoOptions
        ) { [weak self] avAsset, _, _ in
            guard let self, let avAsset = avAsset else {
                continuation.resume()
                return
            }
            // ...
            DispatchQueue.main.async {
                // ...
                continuation.resume()
            }
        }
    }
}
```
ExportManager's `requestAVAsset` follows this exact shape: `PHVideoRequestOptions`, `PHImageManager.default().requestAVAsset(forVideo:options:)`, wrapped in `withCheckedThrowingContinuation`. Difference: use `deliveryMode = .highQualityFormat` (not `.automatic`) and resume with the asset or throw.

**Timer + RunLoop.main .common pattern** (PlayerController.swift lines 112-116 for CADisplayLink analog):
```swift
let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTarget.tick(link:)))
link.add(to: .main, forMode: .common)
```
The `.common` RunLoop mode on `.main` is the established project pattern for time-based callbacks that must fire during scrolling. ExportManager's progress timer uses the same mode:
```swift
let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
    self?.onProgress?(clip.id, session.progress)
}
RunLoop.main.add(timer, forMode: .common)
```

**MainActor dispatch for state updates** (PlayerController.swift lines 61-65):
```swift
DispatchQueue.main.async {
    self.player.replaceCurrentItem(with: item)
    self.duration = avAsset.duration.seconds
    self.setupTimeObserver()
    continuation.resume()
}
```
Export progress callbacks that mutate AppViewModel state must land on the main actor. Use `Task { @MainActor in ... }` inside the timer block (matching the RESEARCH.md Pattern 1 excerpt).

**deinit cleanup pattern** (PlayerController.swift lines 162-167):
```swift
deinit {
    stopDisplayLink()
    if let token = timeObserverToken {
        player.removeTimeObserver(token)
    }
}
```
ExportManager needs no explicit deinit for its Timer because the timer is invalidated inside the `exportAsynchronously` completion handler. However, if export is cancelled mid-flight, invalidate in a `cancelExport()` path.

---

### `SurfvidApp/Export/DoneView.swift` (component, request-response)

**Analog:** `SurfvidApp/Review/ReviewView.swift`

**Imports and EnvironmentObject pattern** (ReviewView.swift lines 1-3):
```swift
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var appViewModel: AppViewModel
```
DoneView follows the identical declaration: `import SwiftUI`, `struct DoneView: View`, `@EnvironmentObject var appViewModel: AppViewModel`. No additional imports needed.

**Full-screen dark scaffold** (ReviewView.swift lines 7-31):
```swift
var body: some View {
    GeometryReader { geometry in
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            // ... content layers ...
        }
    }
    .background(Color.black)
    .ignoresSafeArea()
}
```
DoneView uses the same outer wrapper: `GeometryReader` wrapping a `ZStack` on `Color.black.ignoresSafeArea()`, with `.background(Color.black).ignoresSafeArea()` on the outer view.

**Safe-area-aware padding** (ReviewView.swift lines 14-18):
```swift
.padding(.leading, 60)
.padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
```
DoneView content should use the same padding values (60pt leading for Dynamic Island clearance, `max(geometry.safeAreaInsets.trailing, 34)` trailing for home indicator).

**Auto-navigation with Task.sleep** — the codebase already uses timed auto-dismiss in SkimView (SkimView.swift lines 311-316):
```swift
private func showHUD(_ kind: HUDKind) {
    withAnimation(.easeIn(duration: 0.12)) { hudFlash = kind }
    Task {
        try? await Task.sleep(nanoseconds: 700_000_000)
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) { hudFlash = nil }
        }
    }
}
```
DoneView's `onAppear` timer uses the same `Task { try? await Task.sleep(...); await MainActor.run { ... } }` pattern. For 2.5 seconds use `Task.sleep(nanoseconds: 2_500_000_000)` (iOS 16 compatible — `Task.sleep(for: .seconds(2.5))` requires iOS 16.0+ via the `Duration` API, but `nanoseconds:` is always available).

**AppViewModel state mutation** (ReviewView.swift line 92):
```swift
Button(action: { appViewModel.screen = .skim }) {
```
DoneView's auto-nav writes directly: `appViewModel.screen = .library` then `appViewModel.resetForNewVideo()`.

**Large icon + text empty-state layout** (ReviewView.swift lines 71-88):
```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Spacer()
        Image(systemName: "film")
            .font(.system(size: 48, weight: .thin))
            .foregroundColor(Color.white.opacity(0.3))
        Text("No clips marked")
            .font(.title2.weight(.semibold))
            .foregroundColor(.white)
        Text("Tap Skim to return and mark clips from this video.")
            .font(.body)
            .foregroundColor(Color.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```
DoneView's centered content follows the same pattern: `VStack(spacing: 16)` with `Spacer()` above and below, large icon at `.system(size: 48+, weight: .thin)` (use "checkmark.circle" or "checkmark" at larger size), title at `.title2.weight(.semibold)`, subtitle at `.body` with `.opacity(0.55)`. For the checkmark use a larger size — see Research.md which references the prototype's large checkmark.

---

### `SurfvidApp/Review/ActivityViewController.swift` (utility, request-response)

**Analog:** `SurfvidApp/Skim/PlayerView.swift`

Read PlayerView.swift to confirm the UIViewRepresentable pattern in use:
```swift
// (PlayerView.swift — UIViewRepresentable wrapping AVPlayerLayer)
import SwiftUI
import AVFoundation

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
    // ...
}
```
ActivityViewController follows the same UIViewControllerRepresentable shape: `import SwiftUI` + `import UIKit`, struct with `let activityItems: [Any]`, `makeUIViewController` returning a configured `UIActivityViewController`, empty `updateUIViewController`. This is the only UIKit bridge in the project — follow `PlayerView`'s minimal/stateless wrapper convention.

**Imports** (matching PlayerView's style):
```swift
import SwiftUI
import UIKit
```
No `AVFoundation` needed. No `Combine`, no `Photos`.

**Struct declaration** (same shape as PlayerView):
```swift
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

---

### `SurfvidApp/AppViewModel.swift` (store, CRUD + event-driven) — MODIFY

**Existing file:** `SurfvidApp/AppViewModel.swift` — read in full above.

**Screen enum addition** (AppViewModel.swift line 5):
```swift
enum Screen { case library, skim, review }
```
Add `.done` case: `enum Screen { case library, skim, review, done }`

**Clip struct addition** (AppViewModel.swift lines 13-17):
```swift
struct Clip: Identifiable {
    let id = UUID()
    let start: Double   // seconds
    let end: Double     // seconds
}
```
Add two mutable fields:
```swift
struct Clip: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
    // Phase 4:
    var exportProgress: Float = 0.0   // 0.0–1.0 polled from AVAssetExportSession.progress
    var exportedURL: URL? = nil       // set after successful export; nil = not yet exported
}
```

**@Published state additions** (insert after line 20, matching existing @Published field style):
```swift
@Published var clips: [Clip] = []
@Published var pendingIn: Double? = nil
// Phase 4:
@Published var isExporting: Bool = false
@Published var currentAsset: PHAsset? = nil   // set in pickVideo; used by startExport
```

**ExportManager property + objectWillChange forwarding** — mirrors the PlayerController pattern (AppViewModel.swift lines 22-30):
```swift
let playerController: PlayerController  // D-10: created once in init
private var cancellables = Set<AnyCancellable>()

init() {
    self.playerController = PlayerController()
    // Forward PlayerController @Published changes so SkimView re-renders
    playerController.objectWillChange
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)
    // ...
}
```
Add ExportManager after PlayerController, forwarding the same way:
```swift
let playerController: PlayerController
let exportManager: ExportManager          // Phase 4
private var cancellables = Set<AnyCancellable>()

init() {
    self.playerController = PlayerController()
    self.exportManager = ExportManager()  // Phase 4
    playerController.objectWillChange
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)
    exportManager.objectWillChange        // Phase 4
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)
    // ...
}
```

**pickVideo modification** (AppViewModel.swift lines 38-44):
```swift
func pickVideo(_ asset: PHAsset) {
    resetForNewVideo()
    Task {
        await playerController.load(asset: asset)
        await MainActor.run { screen = .skim }
    }
}
```
Add `currentAsset = asset` before the Task:
```swift
func pickVideo(_ asset: PHAsset) {
    resetForNewVideo()
    currentAsset = asset               // Phase 4: retain for export
    Task {
        await playerController.load(asset: asset)
        await MainActor.run { screen = .skim }
    }
}
```

**startExport method** — new method following the same Task-on-MainActor pattern as the existing async methods. The existing Task pattern (AppViewModel.swift lines 40-43):
```swift
Task {
    await playerController.load(asset: asset)
    await MainActor.run { screen = .skim }
}
```
startExport follows the same shape: a Task with sequential await calls and MainActor.run for state writes.

**resetForNewVideo extension** (AppViewModel.swift lines 91-94):
```swift
func resetForNewVideo() {
    clips = []
    pendingIn = nil
}
```
Add `isExporting = false` and `currentAsset = nil`:
```swift
func resetForNewVideo() {
    clips = []
    pendingIn = nil
    isExporting = false     // Phase 4
    currentAsset = nil      // Phase 4
}
```

---

### `SurfvidApp/ContentView.swift` (controller, request-response) — MODIFY

**Existing file:** `SurfvidApp/ContentView.swift` — read in full above.

**Switch case addition** (ContentView.swift lines 8-18):
```swift
switch appViewModel.screen {
case .library:
    LibraryView()
        .transition(.opacity)
case .skim:
    SkimView()
        .transition(.opacity)
case .review:
    ReviewView()
        .transition(.opacity)
}
```
Add `.done` case following the identical pattern:
```swift
case .done:
    DoneView()
        .transition(.opacity)
```

**Orientation lock addition** (ContentView.swift lines 21-30):
```swift
.onChange(of: appViewModel.screen) { newScreen in
    switch newScreen {
    case .library:
        AppDelegate.lockOrientation(.portrait)
    case .skim:
        AppDelegate.lockOrientation(.landscape)
    case .review:
        AppDelegate.lockOrientation(.landscape)
    }
}
```
Add `.done` case — same lock as `.review` (stays landscape, matching D-06 which says Done screen auto-returns to library after 2.5s from the same landscape context):
```swift
case .done:
    AppDelegate.lockOrientation(.landscape)
```

---

### `SurfvidApp/Review/ReviewView.swift` (component, CRUD) — MODIFY

**Existing file:** `SurfvidApp/Review/ReviewView.swift` — read in full above.

**topChrome Export button** (ReviewView.swift lines 90-122):
```swift
private var topChrome: some View {
    HStack(alignment: .center) {
        Button(action: { appViewModel.screen = .skim }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .regular))
                Text("Skim")
                    .font(.body)
            }
            .foregroundColor(.white)
        }
        .accessibilityLabel("Back to Skim")

        Spacer()

        Text("Review")
            .font(.body.weight(.medium))
            .foregroundColor(Color.white.opacity(0.9))

        Spacer()

        Color.clear.frame(width: 60, height: 1)  // ← replace this with Export button
    }
    // ...
}
```
Replace `Color.clear.frame(width: 60, height: 1)` with an Export button styled like the "Done" pill in SkimView's topChrome (SkimView.swift lines 141-148):
```swift
Button("Done") { appViewModel.screen = .review }
    .font(.caption.weight(.semibold))
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.white)
    .foregroundColor(Color.black)
    .clipShape(Capsule())
    .disabled(appViewModel.clips.isEmpty)
```
Export pill follows the same capsule styling with a disabled state wired to `appViewModel.isExporting || appViewModel.clips.isEmpty`.

**clipList swipe-to-delete disable during export** (ReviewView.swift lines 39-47):
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) {
        if let index = appViewModel.clips.firstIndex(where: { $0.id == clip.id }) {
            appViewModel.clips.remove(at: index)
        }
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```
Wrap the entire `.swipeActions` modifier with a conditional: only apply when `!appViewModel.isExporting`. Pattern: use the modifier conditionally in a `@ViewBuilder` or guard the `swipeActions` content. The simplest approach follows the `.disabled()` pattern already used on buttons — apply `.swipeActions` only when not exporting by returning an empty `swipeActions` block when `isExporting` is true.

**clipRow progress bar** — inserted inside `clipRow(_:)` (ReviewView.swift lines 55-69):
```swift
private func clipRow(_ clip: AppViewModel.Clip) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(formatTimecode(clip.start)) → \(formatTimecode(clip.end))")
                .font(.body.monospacedDigit())
                .foregroundColor(.white)
            Text(formatTimecode(clip.end - clip.start))
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.55))
        }
        Spacer()
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
}
```
Modify the `VStack` to add a progress bar below the timecode text when `appViewModel.isExporting || clip.exportProgress > 0`. The share button goes in the `Spacer()` area on the right. Color for progress bar: `Color.white.opacity(0.7)` or the orange accent `Color(red: 0.87, green: 0.42, blue: 0.20)` already used in SkimView (SkimView.swift line 340) — planner chooses.

---

## Shared Patterns

### ObservableObject Manager with objectWillChange Forwarding
**Source:** `SurfvidApp/PlayerController.swift` lines 6-8 + `SurfvidApp/AppViewModel.swift` lines 22-30
**Apply to:** `ExportManager.swift` (as the new manager) + `AppViewModel.swift` (sink from ExportManager)
```swift
// In AppViewModel.init():
exportManager.objectWillChange
    .sink { [weak self] _ in self?.objectWillChange.send() }
    .store(in: &cancellables)
```

### EnvironmentObject Access in Views
**Source:** All view files (ReviewView.swift line 3, SkimView.swift line 5, LibraryView.swift line 5)
**Apply to:** `DoneView.swift`
```swift
@EnvironmentObject var appViewModel: AppViewModel
```

### Dark-Theme Full-Screen Scaffold
**Source:** `SurfvidApp/Review/ReviewView.swift` lines 7-31
**Apply to:** `DoneView.swift`
```swift
GeometryReader { geometry in
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()
        // content
    }
}
.background(Color.black)
.ignoresSafeArea()
```

### Safe-Area-Aware Padding (Dynamic Island + Home Indicator)
**Source:** `SurfvidApp/Review/ReviewView.swift` lines 14-18 + SkimView.swift lines 102-103
**Apply to:** `DoneView.swift` content layer
```swift
.padding(.leading, 60)
.padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
```

### Task-Based Timed Auto-Dismiss
**Source:** `SurfvidApp/Skim/SkimView.swift` lines 310-317
**Apply to:** `DoneView.swift` onAppear
```swift
Task {
    try? await Task.sleep(nanoseconds: 2_500_000_000)
    await MainActor.run {
        appViewModel.resetForNewVideo()
        appViewModel.screen = .library
    }
}
```

### UIKit Bridge (UIViewControllerRepresentable / UIViewRepresentable)
**Source:** `SurfvidApp/Skim/PlayerView.swift` (UIViewRepresentable)
**Apply to:** `SurfvidApp/Review/ActivityViewController.swift` (UIViewControllerRepresentable)
Same pattern: minimal struct, `let` property for the UIKit object, `makeUIViewController` creates and configures, `updateUIViewController` is empty.

### Accent Color
**Source:** `SurfvidApp/Skim/SkimView.swift` line 340
**Apply to:** Progress bar in `ReviewView.clipRow`, any export-state accents
```swift
Color(red: 0.87, green: 0.42, blue: 0.20)  // UI-SPEC orange accent
```

### withCheckedContinuation Async Wrapper
**Source:** `SurfvidApp/AppViewModel.swift` lines 47-57 + `SurfvidApp/PlayerController.swift` lines 38-66
**Apply to:** `ExportManager.requestAVAsset` and `ExportManager.exportClip`
```swift
return try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, info in
        if let asset = asset {
            continuation.resume(returning: asset)
        } else {
            let error = info?[PHImageErrorKey] as? Error
            continuation.resume(throwing: error ?? ExportError.assetUnavailable)
        }
    }
}
```

---

## No Analog Found

No files in this phase are without an analog. All patterns are covered by existing codebase files.

---

## Metadata

**Analog search scope:** `SurfvidApp/` (all Swift files — 12 files total)
**Files scanned:** 12
**Pattern extraction date:** 2026-05-12
