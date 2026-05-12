# Phase 4: Export - Research

**Researched:** 2026-05-12
**Domain:** AVFoundation export (AVAssetExportSession), PhotosKit write (PHPhotoLibrary), UIKit share sheet (UIActivityViewController), SwiftUI screen wiring
**Confidence:** HIGH (core export API patterns verified against Apple docs and community sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Export button in `topChrome` of ReviewView, right side of HStack. "Export All" — no per-clip export buttons.
- **D-02:** While exporting: lock clip list (disable swipe-to-delete and Export button). Boolean `isExporting` on AppViewModel. No mid-export mutation.
- **D-03:** User stays in ReviewView during export — no separate export screen.
- **D-04:** Per-clip progress shown as a thin progress bar per row, driven by `AVAssetExportSession.progress` polling.
- **D-05:** Sequential exports — one AVAssetExportSession at a time. Waiting clips show 0% progress.
- **D-06:** After all exports: navigate to `.done` case in `Screen` enum. Auto-navigate to `.library` after ~2.5s. Reset clip state.
- **D-07:** Done screen: large checkmark, "{N} clips exported", "Returning to library…" hint. Dark-theme.
- **D-08:** Share button per clip row appears only after that clip's export succeeded.
- **D-09:** Share action opens `UIActivityViewController` (wrapped for SwiftUI). Share payload is the exported file URL.
- **AVAssetExportPresetPassthrough** is locked (no re-encode) — CLAUDE.md and STATE.md.
- **Zero third-party dependencies** — Apple frameworks only.
- **iOS 16+ minimum target.**

### Claude's Discretion
- How to surface the Photos file URL after export (PHAsset request vs. capturing `AVAssetExportSession.outputURL`)
- Exact visual styling of per-row progress bar (height, color, overlay vs. underline)
- Whether `ExportManager` is a standalone class or methods on `AppViewModel`

### Deferred Ideas
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXP-01 | User can export each clip as a separate H.264 MP4 file to Camera Roll | AVAssetExportSession + PHPhotoLibrary.performChanges pattern; verified below |
| EXP-02 | Export progress is shown per clip | AVAssetExportSession.progress polled via Timer (Float 0.0–1.0); no KVO; verified below |
| EXP-03 | Confirmation is shown after all clips are exported | Done screen via .done Screen case + Task.sleep(for: .seconds(2.5)) auto-nav |
| EXP-04 | User can share clips via Share Sheet (AirDrop, iCloud, Files) | UIActivityViewController wrapped as UIViewControllerRepresentable; file URL from outputURL |
| PERF-03 | Passthrough export — no re-encode, export time proportional to clip length | AVAssetExportPresetPassthrough + timeRange on direct AVURLAsset; edit-list pitfall documented |
</phase_requirements>

---

## Summary

Phase 4 adds export capability on top of the three completed phases. The core export loop uses `AVAssetExportSession` initialised with `AVAssetExportPresetPassthrough` and a `CMTimeRange` derived from each `Clip`. Because the source videos are `AVURLAsset`s obtained via `PHImageManager.requestAVAsset`, exporting with passthrough is a file-copy plus an edit list insertion at the trim points — no transcoding occurs. The loop runs sequentially from a `Task` on the main actor; progress is polled every ~0.1s via a `Timer` while each session is running, and the polled `Float` value is written into a `@Published` property on `AppViewModel` so SwiftUI re-renders the progress bar.

Saving to the Camera Roll requires `PHPhotoLibrary.shared().performChanges { @Sendable in PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL) }`. The app's Info.plist already contains `NSPhotoLibraryAddOnlyUsageDescription`, so no plist change is needed. The authorization level to check/request is `.addOnly`; the app already holds `.readWrite` which is a superset, so no additional prompt will appear. After `performChanges` completes, the exported file URL (the `outputURL` set on the export session, written to the app's temp directory) is sufficient for the Share Sheet — there is no need to re-fetch via `PHAsset`.

The Done screen is a new `.done` case in the `Screen` enum, follows the existing ZStack-swap pattern in `ContentView`, and uses `Task { try? await Task.sleep(for: .seconds(2.5)); screen = .library }` for auto-navigation.

**Primary recommendation:** Keep `ExportManager` as a separate `ObservableObject` class (mirroring `PlayerController`) forwarded through `AppViewModel.objectWillChange`. Export state — `isExporting`, per-clip `exportProgress: Float`, per-clip `exportedURL: URL?` — is added to the `Clip` struct. The `AVAsset` needed for export is requested fresh per clip via `PHImageManager.requestAVAsset`; do not reuse the `AVPlayerItem` asset from `PlayerController` (separate concerns, no shared state risk).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Export session creation and progress polling | ExportManager (background Task + main-thread Timer) | AppViewModel (state owner) | AVAssetExportSession is an AVFoundation object; keeping it in a dedicated manager avoids bloating AppViewModel with AVFoundation lifecycle code |
| Per-clip progress state | AppViewModel.Clip struct (@Published) | — | All view state lives on AppViewModel per existing flat-MVVM architecture |
| Photos write (performChanges) | ExportManager | — | Async, throws, belongs next to export logic |
| Share Sheet presentation | ReviewView (SwiftUI sheet) | — | UIKit bridge is a view-layer concern |
| Screen transition to .done | AppViewModel (screen = .done) | — | Screen enum already owned here |
| Auto-return timer from Done screen | DoneView or AppViewModel | — | Task.sleep in view's onAppear is simplest; alternatively a method on AppViewModel |
| Orientation lock for .done | ContentView onChange(of: screen) | AppDelegate.lockOrientation | Same pattern as .review (landscape) |

---

## Standard Stack

### Core (all Apple frameworks — zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 16+ built-in | AVAssetExportSession, AVAssetExportPresetPassthrough, CMTimeRange | Only framework that provides native iOS video trimming/export |
| PhotosKit | iOS 16+ built-in | PHPhotoLibrary.performChanges, PHAssetChangeRequest.creationRequestForAssetFromVideo | Required to save exported file to Camera Roll |
| UIKit | iOS 16+ built-in | UIActivityViewController (Share Sheet) | No native SwiftUI equivalent; wrapped via UIViewControllerRepresentable |
| SwiftUI | iOS 16+ built-in | ReviewView updates, DoneView, progress binding | Existing app UI layer |

### No new package dependencies required.

---

## Architecture Patterns

### System Architecture Diagram

```
User taps "Export All"
        |
        v
AppViewModel.startExport()
  sets isExporting = true
  starts Task { for clip in clips { ... } }
        |
        v (per clip, sequentially)
ExportManager.exportClip(clip, asset: PHAsset)
  1. requestAVAsset(forVideo: phAsset) → AVURLAsset
  2. Create AVAssetExportSession(asset:, presetName: Passthrough)
  3. outputURL = temp dir / UUID.mp4
  4. outputFileType = .mp4
  5. timeRange = CMTimeRange(clip.start ... clip.end)
  6. Start Timer (0.1s) → poll exportSession.progress → update clip.exportProgress
  7. exportAsynchronously { ... } ← wrapped in withCheckedContinuation
  8. On completion: invalidate Timer
  9. PHPhotoLibrary.performChanges { creationRequestForAssetFromVideo(outputURL) }
 10. clip.exportedURL = outputURL  ← triggers Share button appearance
        |
        v (after all clips)
AppViewModel.screen = .done
        |
        v
DoneView (new Screen.done case)
  Task { try? await Task.sleep(for: .seconds(2.5)) }
  → AppViewModel.screen = .library
  → AppViewModel.resetForNewVideo()
```

### Recommended Project Structure

```
SurfvidApp/
├── AppViewModel.swift       # Add: .done Screen case, isExporting, exportedURL/progress on Clip
├── ContentView.swift        # Add: .done case in switch + landscape lock
├── Export/
│   ├── ExportManager.swift  # NEW: AVAssetExportSession lifecycle, PHPhotoLibrary write
│   └── DoneView.swift       # NEW: checkmark + count + auto-return
├── Review/
│   ├── ReviewView.swift     # Add: Export button in topChrome, progress bars, share buttons
│   └── ActivityViewController.swift  # NEW: UIViewControllerRepresentable wrapper
└── Info.plist               # NO CHANGE NEEDED (NSPhotoLibraryAddOnlyUsageDescription already present)
```

### Pattern 1: Sequential Export Loop with Progress Polling

The canonical iOS 16-compatible pattern. Uses `exportAsynchronously` wrapped with `withCheckedContinuation` for async/await integration, and a separate `Timer` to poll `AVAssetExportSession.progress`.

**Why not `export(to:as:)` (iOS 16+ async method)?**
The newer `export(to:as:isolation:)` method is iOS 18+ only. The `export()` method (no arguments) was added in iOS 16 but provides no built-in progress stream — it simply suspends until completion. `states(updateInterval:)` is also iOS 18+. For iOS 16 targets, the Timer-polling approach is the correct and only option. [CITED: developer.apple.com/documentation/avfoundation/avassetexportsession/state]

```swift
// Source: Apple Developer Documentation + community pattern (VERIFIED: multiple sources)
// ExportManager.swift

func exportClip(_ clip: AppViewModel.Clip, from phAsset: PHAsset) async throws -> URL {
    // Step 1: Get AVAsset from PHAsset
    let avAsset = try await requestAVAsset(for: phAsset)

    // Step 2: Build output URL (temp directory; unique per clip)
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")

    // Step 3: Delete any pre-existing file at that path (export fails otherwise)
    try? FileManager.default.removeItem(at: outputURL)

    // Step 4: Create export session
    guard let session = AVAssetExportSession(
        asset: avAsset,
        presetName: AVAssetExportPresetPassthrough
    ) else {
        throw ExportError.sessionCreationFailed
    }
    session.outputURL = outputURL
    session.outputFileType = .mp4
    session.timeRange = CMTimeRange(
        start: CMTimeMakeWithSeconds(clip.start, preferredTimescale: 600),
        end:   CMTimeMakeWithSeconds(clip.end,   preferredTimescale: 600)
    )

    // Step 5: Poll progress on main thread while export runs
    let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        // AVAssetExportSession.progress is a Float (0.0–1.0); NOT KVO observable
        // Must poll; do NOT use KVO or Combine publisher on this property
        Task { @MainActor in
            self?.onProgress(Float(session.progress), for: clip.id)
        }
    }
    RunLoop.main.add(progressTimer, forMode: .common)  // fires during scrolling too

    // Step 6: Await completion (wrap callback in async)
    try await withCheckedThrowingContinuation { continuation in
        session.exportAsynchronously {
            progressTimer.invalidate()
            switch session.status {
            case .completed:
                continuation.resume()
            case .failed:
                continuation.resume(throwing: session.error ?? ExportError.unknown)
            case .cancelled:
                continuation.resume(throwing: ExportError.cancelled)
            default:
                continuation.resume(throwing: ExportError.unknown)
            }
        }
    }

    return outputURL
}
```

### Pattern 2: PHImageManager.requestAVAsset (async wrapper)

```swift
// Source: matches PlayerController.load(asset:) pattern already in codebase [VERIFIED: codebase]
private func requestAVAsset(for phAsset: PHAsset) async throws -> AVAsset {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat  // export needs highest quality, not .automatic

    return try await withCheckedThrowingContinuation { continuation in
        PHImageManager.default().requestAVAsset(
            forVideo: phAsset,
            options: options
        ) { avAsset, _, info in
            if let asset = avAsset {
                continuation.resume(returning: asset)
            } else {
                let error = info?[PHImageErrorKey] as? Error
                continuation.resume(throwing: error ?? ExportError.assetUnavailable)
            }
        }
    }
}
```

**Note on delivery mode:** PlayerController uses `.automatic` because it wants fast playback startup. ExportManager should use `.highQualityFormat` to ensure passthrough gets the original bitstream, not a degraded iCloud proxy. [ASSUMED — reasonable inference from API semantics; confirm if export produces unexpectedly small files]

### Pattern 3: PHPhotoLibrary.performChanges (save to Camera Roll)

```swift
// Source: Apple Developer Forums thread/763665 (@Sendable fix for Swift 6 concurrency) [CITED]
func saveToPhotoLibrary(fileURL: URL) async throws {
    // Authorization: app already holds .readWrite (superset of .addOnly).
    // Check current status first; only request if needed.
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    guard status == .authorized || status == .limited else {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard newStatus == .authorized || newStatus == .limited else {
            throw ExportError.photosAccessDenied
        }
    }

    try await PHPhotoLibrary.shared().performChanges { @Sendable in
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
    }
}
```

**Important:** The `@Sendable` attribute on the closure is required to silence Swift 6 strict concurrency warnings. The closure must only capture sendable types (URLs are Sendable). [CITED: developer.apple.com/forums/thread/763665]

### Pattern 4: UIActivityViewController for SwiftUI

```swift
// Source: hoyelam.com/share-sheet-uiactivityviewcontroller-within-swiftui [CITED]
// ActivityViewController.swift

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]   // pass [exportedURL] — a file URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Usage in ReviewView:
// .sheet(isPresented: $showingShareSheet) {
//     ActivityViewController(activityItems: [clip.exportedURL!])
// }
```

**Share payload:** Use the `outputURL` captured from the export session directly — this is a file URL in the app's temp directory. **Do not** re-request via PHAsset after saving to Camera Roll; the temp file URL is what share sheet destinations expect for immediate file transfer. [VERIFIED: consistent with standard iOS share sheet usage]

### Pattern 5: Auto-Navigation from Done Screen

```swift
// DoneView.swift — onAppear triggers auto-return after 2.5s
struct DoneView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        // ... checkmark + count UI ...
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                await MainActor.run {
                    appViewModel.resetForNewVideo()
                    appViewModel.screen = .library
                }
            }
        }
    }
}
```

### Pattern 6: ExportManager objectWillChange Forwarding

```swift
// AppViewModel.swift — mirrors the PlayerController pattern already in place
let exportManager: ExportManager

init() {
    // existing init...
    exportManager.objectWillChange
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)
}
```

### Pattern 7: Clip Struct Additions

```swift
// AppViewModel.swift — add export state fields to Clip
struct Clip: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
    // Phase 4 additions:
    var exportProgress: Float = 0.0     // 0.0–1.0, polled from AVAssetExportSession.progress
    var exportedURL: URL? = nil         // set after successful export; presence drives Share button
}
```

### Anti-Patterns to Avoid

- **KVO on `AVAssetExportSession.progress`:** The property is explicitly NOT KVO-observable. Any attempt to use `observe(_:options:changeHandler:)` or Combine `.publisher(for: \.progress)` will silently never fire. Always poll via Timer. [VERIFIED: Apple docs, community sources]
- **Reusing AVPlayerItem's asset for export:** The `AVPlayerItem` in `PlayerController` holds the asset currently loaded into the player. Creating an `AVAssetExportSession` from that same asset while the player is mid-use creates undefined state. Request a fresh `AVAsset` per export. [ASSUMED — conservative interpretation of AVFoundation thread-safety docs]
- **Mutating `clips` array during export:** `D-02` is correct — mutation during export risks index-out-of-bounds crashes in the sequential loop. The `isExporting` flag guards this.
- **Not deleting outputURL before export:** `AVAssetExportSession` returns `.failed` if a file already exists at `outputURL`. Always `try? FileManager.default.removeItem(at: outputURL)` before starting.
- **Using `AVFileType.mov` for outputFileType with Passthrough:** When the source is an H.264 MP4 (standard iPhone camera roll video), use `.mp4`. MOV is acceptable but MP4 is the universal container. Note: passthrough may insert an edit list at trim points — this is expected behavior for I-frame alignment and plays correctly on all Apple devices. [VERIFIED: multiple Apple Developer Forum discussions]
- **Running Timer on default RunLoop mode:** Use `.common` mode so the timer fires while the List is scrolling. `RunLoop.main.add(progressTimer, forMode: .common)` is required when using `Timer.scheduledTimer`. [ASSUMED — well-known iOS pattern]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video trimming without re-encode | Custom AVAssetWriter pipeline | `AVAssetExportSession(presetName: AVAssetExportPresetPassthrough)` + `timeRange` | Passthrough handles I-frame alignment and edit list insertion automatically |
| Save to Camera Roll | NSData write + UISaveVideoAtPathToSavedPhotosAlbum | `PHPhotoLibrary.performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo }` | Only PhotoKit API that creates a proper Photos asset with metadata |
| Share Sheet | Custom share UI | `UIActivityViewController` via `UIViewControllerRepresentable` | System sheet includes AirDrop, Files, Messages, iCloud Drive automatically |
| Progress observation | Combine publisher / KVO on exportSession | `Timer` polling `session.progress` every 0.1s | `progress` is not KVO-observable; Timer is the canonical approach |

---

## Common Pitfalls

### Pitfall 1: `AVAssetExportSession.progress` is NOT KVO-Observable
**What goes wrong:** Developer tries `session.publisher(for: \.progress)` or adds KVO observer — never fires, progress stays at 0.0.
**Why it happens:** Apple explicitly does not make this property KVO-observable; it is a plain Float that updates on an internal serial queue.
**How to avoid:** Always use a `Timer` (or while-loop on background thread) to poll `.progress` every 100ms.
**Warning signs:** Progress bar stays at 0% throughout export then jumps to 100% when done.

### Pitfall 2: Output File Already Exists
**What goes wrong:** `exportAsynchronously` completes with status `.failed` and an error like "The operation could not be completed because the output file already exists."
**Why it happens:** Previous export wrote to the same path; temp directory is not auto-cleared between sessions.
**How to avoid:** `try? FileManager.default.removeItem(at: outputURL)` immediately before `session.exportAsynchronously`.
**Warning signs:** First clip exports fine, subsequent clips fail.

### Pitfall 3: Timer Not Added to `.common` RunLoop Mode
**What goes wrong:** Progress bar freezes while user scrolls the clip list.
**Why it happens:** Default `Timer.scheduledTimer` runs in `.default` mode; List scroll events switch the run loop to `.tracking` mode.
**How to avoid:** Use `let t = Timer(timeInterval:repeats:block:)` then `RunLoop.main.add(t, forMode: .common)`.

### Pitfall 4: AVAssetExportSession Stuck in `.waiting` State
**What goes wrong:** Export never starts, progress stays 0, completion handler never called.
**Why it happens:** Known iOS bug (FB9155832, FB9188280) — can occur after the app is killed mid-export multiple times. Also happens if the device is running out of storage.
**How to avoid:** Check `UIDevice.current.systemFreeSize` (via FileManager) before export. Add a timeout guard (e.g., if progress stays 0 for >10s with status `.exporting`, cancel and report error). [CITED: developer.apple.com/forums/thread/649671]
**Warning signs:** Status is `.exporting` but progress stays 0.0 indefinitely.

### Pitfall 5: PHPhotoLibrary.performChanges Swift 6 Data Race Warning
**What goes wrong:** `Sending main actor-isolated value of type 'URL' to nonisolated context risks causing data races` compiler warning / error.
**Why it happens:** Swift 6 strict concurrency — the `performChanges` closure runs on a nonisolated background thread.
**How to avoid:** Mark the closure `@Sendable`. URLs are Sendable; do not capture non-Sendable types.
**Warning signs:** Build fails or produces warnings with strict concurrency mode enabled.

### Pitfall 6: cancelExport() from Main Thread on iOS 16.1
**What goes wrong:** UI freezes when user tries to cancel export (if cancel is implemented).
**Why it happens:** iOS 16.1-specific bug where `cancelExport()` called from main thread causes synchronous completion.
**How to avoid:** If implementing cancellation, call `DispatchQueue.global().async { session.cancelExport() }`. [CITED: medium.com/@mi9nxi/avassetexportsession-cancelexport]

### Pitfall 7: Wrong PHAccessLevel Check for Save
**What goes wrong:** Calling `PHPhotoLibrary.requestAuthorization(for: .readWrite)` again when app already has `.readWrite` — shows unnecessary system prompt on first export.
**Why it happens:** Checking the wrong access level; app already has `.readWrite` which covers add operations.
**How to avoid:** Check `PHPhotoLibrary.authorizationStatus(for: .addOnly)`. Since `.readWrite` is a superset, it will return `.authorized` even though the original request was `.readWrite`. No additional prompt is shown.

### Pitfall 8: Passthrough + .mp4 + Non-Keyframe Trim Points
**What goes wrong:** Exported clip plays with a brief black/garbage frame at the start on non-Apple players.
**Why it happens:** H.264 can only cut cleanly on I-frames; if `clip.start` falls between I-frames, AVFoundation inserts an edit list in the MP4 container to mask the gap. Most Apple players honour edit lists; some third-party players ignore them.
**Impact for this app:** Clips will play correctly on iOS/macOS. No action needed for v1. [VERIFIED: multiple Apple Developer Forum discussions]

---

## Code Examples

### Complete ExportManager skeleton

```swift
// Source: synthesised from verified patterns above
import AVFoundation
import Photos
import Combine

enum ExportError: Error {
    case sessionCreationFailed
    case assetUnavailable
    case photosAccessDenied
    case cancelled
    case unknown
}

class ExportManager: ObservableObject {
    // Called from AppViewModel to update per-clip state on @Published clips array
    var onProgress: ((UUID, Float) -> Void)?
    var onClipComplete: ((UUID, URL) -> Void)?
    var onClipFailed: ((UUID, Error) -> Void)?

    func exportClip(_ clip: AppViewModel.Clip, phAsset: PHAsset) async throws -> URL {
        let avAsset = try await requestAVAsset(for: phAsset)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try? FileManager.default.removeItem(at: outputURL)  // Pitfall 2 guard

        guard let session = AVAssetExportSession(
            asset: avAsset,
            presetName: AVAssetExportPresetPassthrough
        ) else { throw ExportError.sessionCreationFailed }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.timeRange = CMTimeRange(
            start: CMTimeMakeWithSeconds(clip.start, preferredTimescale: 600),
            end:   CMTimeMakeWithSeconds(clip.end,   preferredTimescale: 600)
        )

        // Timer polling — Pitfall 1 + Pitfall 3
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.onProgress?(clip.id, session.progress)
        }
        RunLoop.main.add(timer, forMode: .common)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                timer.invalidate()
                switch session.status {
                case .completed: continuation.resume()
                case .failed:    continuation.resume(throwing: session.error ?? ExportError.unknown)
                case .cancelled: continuation.resume(throwing: ExportError.cancelled)
                default:         continuation.resume(throwing: ExportError.unknown)
                }
            }
        }

        return outputURL
    }

    private func requestAVAsset(for phAsset: PHAsset) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, info in
                if let asset { continuation.resume(returning: asset) }
                else { continuation.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? ExportError.assetUnavailable) }
            }
        }
    }

    func saveToPhotoLibrary(fileURL: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }
    }
}
```

### Export loop in AppViewModel

```swift
// AppViewModel.swift additions
@Published var isExporting = false

func startExport(assets: [PHAsset]) {  // caller maps clips -> phAssets
    guard !clips.isEmpty, !isExporting else { return }
    isExporting = true

    // Wire callbacks
    exportManager.onProgress = { [weak self] id, progress in
        guard let self else { return }
        if let i = clips.firstIndex(where: { $0.id == id }) {
            clips[i].exportProgress = progress
        }
    }

    Task {
        for (i, clip) in clips.enumerated() {
            let phAsset = assets[i]  // assumes 1:1 mapping (single video session)
            do {
                let url = try await exportManager.exportClip(clip, phAsset: phAsset)
                try await exportManager.saveToPhotoLibrary(fileURL: url)
                clips[i].exportedURL = url
                clips[i].exportProgress = 1.0
            } catch {
                // Mark clip as failed — show error indicator (design TBD)
                clips[i].exportProgress = 0.0
            }
        }
        isExporting = false
        screen = .done
    }
}
```

### ActivityViewController for Share Sheet

```swift
// ActivityViewController.swift
import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

---

## Info.plist Status

**No changes required.**

The app's Info.plist already contains:
```xml
<key>NSPhotoLibraryAddOnlyUsageDescription</key>
<string>Surfvid saves exported clips back to your camera roll.</string>
```

[VERIFIED: read from SurfvidApp/Info.plist directly]

The `NSPhotoLibraryAddUsageDescription` key (older, deprecated) is **not** needed on iOS 16+; `NSPhotoLibraryAddOnlyUsageDescription` is the correct key for write-only access.

---

## State of the Art

| Old Approach | Current Approach | iOS Version | Impact |
|--------------|------------------|-------------|--------|
| `exportAsynchronously(completionHandler:)` | Still the right choice for iOS 16 | iOS 4+ | `export(to:as:)` async method available but iOS 18+ only |
| `states(updateInterval:)` AsyncSequence for progress | iOS 18+ only | iOS 18 | Not applicable; use Timer polling for iOS 16 target |
| `PHPhotoLibrary.requestAuthorization(_:)` (no access level) | `requestAuthorization(for: .addOnly)` | iOS 14+ | Correct for write-only use |
| `status` + `progress` properties | `State` enum with `exporting(progress:)` case | iOS 18 | Not applicable for iOS 16 |

**Deprecated/outdated:**
- `exportAsynchronously(completionHandler:)`: Apple deprecated this in iOS 18 in favour of `export(to:as:isolation:)`. However, since this app targets iOS 16, it remains the correct approach — the deprecation warning (if seen) can be noted but not acted on until minimum target is raised to iOS 18.
- `UISaveVideoAtPathToSavedPhotosAlbum`: Old C-level API; do not use. PHPhotoLibrary is the correct replacement.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.highQualityFormat` delivery mode should be used for export (vs `.automatic` used in PlayerController) | Pattern 2 | Passthrough export might silently degrade quality by using iCloud proxy; verify by checking exported file size |
| A2 | Reusing PlayerController's AVAsset for export creates undefined state risk | Architecture / Anti-Patterns | If wrong, a simpler approach (reuse the loaded asset) is possible — but cost of separate requestAVAsset is low (fast, cached) |
| A3 | Timer on `.common` run loop mode is needed to fire during List scroll | Pitfall 3 | If wrong, progress works fine on `.default` — no harm in using `.common` regardless |
| A4 | `PHPhotoLibrary.authorizationStatus(for: .addOnly)` returns `.authorized` when app holds `.readWrite` | Pattern 3 | If wrong, a second system permission prompt appears on first export — testable immediately |

---

## Open Questions

1. **PHAsset reference in the export loop**
   - What we know: `AppViewModel.clips` contains `Clip` structs (start/end seconds). The export loop needs the `PHAsset` to call `requestAVAsset`.
   - What's unclear: The current design only stores one `selectedAsset` implicitly (the last video loaded via `pickVideo`). The planner needs to decide where to store the `PHAsset` reference so `startExport` can retrieve it.
   - Recommendation: Add `@Published var currentAsset: PHAsset?` to AppViewModel, set in `pickVideo`. Export uses this single asset for all clips (a single skim session always has one video source).

2. **Error UX for failed individual clips**
   - What we know: Export can fail per-clip (storage full, iCloud download error).
   - What's unclear: Context.md does not specify error display. The loop silently skips failed clips.
   - Recommendation: Mark failed clips with a red indicator (e.g., `exportProgress = -1.0` as a sentinel, or a separate `exportFailed: Bool`). Navigate to `.done` only if at least one clip succeeded; show inline error row if any failed.

3. **Temp file cleanup**
   - What we know: Exported files are written to `FileManager.default.temporaryDirectory`.
   - What's unclear: When should temp files be deleted? On `.library` navigation? On app terminate?
   - Recommendation: Delete temp files when `resetForNewVideo()` is called (transition to library clears all state). This keeps Share Sheet working until the user exits.

---

## Environment Availability

Step 2.6: SKIPPED — no external CLI tools or services required. All APIs are iOS system frameworks available on any iOS 16+ device. Xcode build toolchain is already in use for Phases 1-3.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | Xcode scheme — no separate config file needed |
| Quick run | Run unit test target in Xcode (Cmd+U) |
| Full suite | Cmd+U (all targets) |

**Note:** This app has no automated test target established in Phases 1-3. The verification approach for prior phases was manual device testing. Phase 4 should follow the same manual verification pattern given the zero-third-party-dependency constraint and the nature of the feature (hardware camera roll access, real video files).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| EXP-01 | Clip exported as MP4 to Camera Roll | Manual device | — | Requires real PHAsset; no simulator support for Camera Roll write |
| EXP-02 | Progress bar updates per-clip during export | Manual device | — | UI observation; can be unit-tested with a mock ExportManager |
| EXP-03 | Done screen appears; auto-returns after 2.5s | Manual device | — | Timing-dependent |
| EXP-04 | Share sheet opens with AirDrop/Files/iCloud | Manual device | — | Requires real device; Share Sheet does not appear in simulator |
| PERF-03 | 30s clip from 15GB file exports quickly (passthrough) | Manual device | — | Subjective; estimate <5s per 30s clip |

### Wave 0 Gaps
- No XCTest target exists yet. If unit tests are desired (e.g., testing ExportError handling or progress callback logic), a test target must be added to the Xcode project.
- Manual verification checklist (replaces automated tests for this phase):
  - [ ] Export one clip → verify MP4 appears in Camera Roll
  - [ ] Export multiple clips → verify separate files, correct trim points
  - [ ] Progress bar updates during export (not stuck at 0% or 100%)
  - [ ] Done screen appears with correct clip count
  - [ ] Auto-return to library after 2.5s
  - [ ] Share button absent before export, appears after
  - [ ] Share Sheet opens with correct file URL
  - [ ] Swipe-to-delete disabled during export
  - [ ] Export button disabled during export

---

## Security Domain

Phase 4 has no novel authentication, session management, or cryptographic requirements. The existing Photos authorization model covers the write permission. No user credentials, network calls, or sensitive data processing is involved.

Applicable ASVS considerations:
- **V5 Input Validation:** `clip.start` and `clip.end` are Double values computed by the app (not user text input). Guard `clip.end > clip.start` (already enforced in `markOut`), and clamp to `[0, asset.duration.seconds]` in the export session setup.
- **File path safety:** `outputURL` is constructed from a UUID — no user-controlled string is used in the path. No path traversal risk.

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: SurfvidApp/Info.plist] — NSPhotoLibraryAddOnlyUsageDescription already present
- [VERIFIED: SurfvidApp/AppViewModel.swift, PlayerController.swift, ContentView.swift, AppDelegate.swift, ReviewView.swift] — codebase patterns confirmed via direct file read
- [CITED: developer.apple.com/documentation/avfoundation/avassetexportsession] — AVAssetExportSession class reference
- [CITED: developer.apple.com/documentation/avfoundation/avassetexportsession/state] — State enum, iOS 18 availability
- [CITED: developer.apple.com/documentation/avfoundation/avassetexportsession/progress] — progress property (NOT KVO-observable)
- [CITED: developer.apple.com/documentation/avfoundation/avassetexportsession/export(to:as:isolation:)] — iOS 18+ only
- [CITED: developer.apple.com/forums/thread/763665] — @Sendable closure pattern for PHPhotoLibrary.performChanges Swift 6

### Secondary (MEDIUM confidence)
- [CITED: hoyelam.com/share-sheet-uiactivityviewcontroller-within-swiftui] — UIViewControllerRepresentable pattern for UIActivityViewController
- [CITED: developer.apple.com/forums/thread/649671] — AVAssetExportSession stuck-in-waiting bug (FB9155832)
- [CITED: medium.com/@mi9nxi/ios-18-phasset-url-from-requestavasset] — AVURLAsset URL behaviour on iOS 18
- [CITED: medium.com/@mi9nxi/avassetexportsession-cancelexport] — cancelExport() main-thread freeze on iOS 16.1
- [CITED: bacancytechnology.com/blog/avfoundation-framework-to-trim-the-video] — Timer polling pattern for progress, 0.1s interval

### Tertiary (LOW confidence — training knowledge, not verified this session)
- [ASSUMED] — `.highQualityFormat` vs `.automatic` delivery mode preference for export
- [ASSUMED] — RunLoop.main `.common` mode requirement for Timer during scroll

---

## Metadata

**Confidence breakdown:**
- Core export API (AVAssetExportSession passthrough + timeRange): HIGH — confirmed via Apple docs and multiple forum sources
- PHPhotoLibrary write pattern: HIGH — confirmed from Apple forums (@Sendable fix)
- Info.plist status: HIGH — verified by direct file read
- UIActivityViewController SwiftUI wrapper: HIGH — standard community pattern
- Progress polling (Timer, not KVO): HIGH — confirmed from Apple docs and community
- iOS version constraints (export() iOS 18+ only): HIGH — confirmed from Apple docs
- Delivery mode recommendation: LOW — assumed, should be verified on device

**Research date:** 2026-05-12
**Valid until:** 2026-11-12 (AVFoundation APIs are stable; iOS 18 export APIs exist but iOS 16 target makes them irrelevant until minimum target is raised)
