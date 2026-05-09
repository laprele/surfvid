# Technology Stack: Surfvid

**Project:** Surfvid — native iOS video skimming and clip extraction
**Researched:** 2026-05-09
**Overall confidence:** HIGH (all Apple-framework choices; verified against official Apple documentation)

---

## Recommended Stack

### Core Frameworks (all first-party Apple — zero third-party dependencies)

| Technology | Version / Target | Purpose | Why |
|------------|-----------------|---------|-----|
| SwiftUI | iOS 16+ | All UI screens, gesture handling | Native declarative UI; DragGesture for scrub is first-class. iOS 16 is the sensible floor — covers ~95%+ of devices by 2025. |
| AVFoundation | iOS 16+ | Video playback, seeking, export | The only correct choice. AVPlayer + AVPlayerItem + AVAssetExportSession form the canonical pipeline. |
| AVKit | iOS 16+ | Video rendering surface | AVPlayerLayer (not AVPlayerViewController) — you need a custom player UI, so the pre-built controller is useless. |
| PhotosKit | iOS 14+ | Camera roll access, save-back | PHPhotoLibrary + PHAsset + PHImageManager for fetching; PHAssetChangeRequest for saving clips back. |
| MediaPlayer | iOS 16+ | Volume button detection (with caveats — see Pitfalls) | MPVolumeView + KVO on AVAudioSession.outputVolume is the only semi-supported path. |

---

## Layer-by-Layer Breakdown

### 1. UI Layer — SwiftUI

Use SwiftUI for everything. No UIKit views required for the UI itself.

- **DragGesture** drives the scrub interaction (`.onChanged` → seek, `.onEnded` → resume play).
- **GeometryReader** provides the scrub bar width to convert drag offset → CMTime.
- **@State / @ObservedObject** for playback state (current time, in/out points, clip list).
- SwiftUI's **VideoPlayer** wrapper (AVKit, iOS 14+) is too limited — it renders the player but doesn't expose the AVPlayer for KVO or custom seek. Use a **UIViewRepresentable wrapping AVPlayerLayer** instead.

**UIKit interop is needed in exactly one place:** the video rendering surface. Wrap `AVPlayerLayer` in a `UIViewRepresentable`. All other UI is pure SwiftUI.

### 2. Video Rendering — AVPlayerLayer via UIViewRepresentable

```swift
struct PlayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
```

This pattern is **minimal UIKit, maximum control** — you own AVPlayer entirely.

### 3. Playback & Scrubbing — AVFoundation

**Setup:**
```
PHAsset → PHImageManager.requestAVAsset() → AVURLAsset → AVPlayerItem → AVPlayer
```

**Seeking for scrub:**
- Use `seek(to:toleranceBefore:toleranceAfter:completionHandler:)` on `AVPlayer`.
- For live drag scrubbing: `toleranceBefore: CMTime(seconds: 0.1, ...)`, `toleranceAfter: CMTime(seconds: 0.1, ...)` — fast, visually accurate enough.
- For In/Out point setting (frame-accurate): `toleranceBefore: .zero, toleranceAfter: .zero` — slower but exact.
- Never stack seeks; cancel any in-flight seek before issuing a new one during a drag (use a debounce flag or check the completion handler).

**Playhead tracking during playback:**
```swift
player.addPeriodicTimeObserver(
    forInterval: CMTime(value: 1, timescale: 30), // ~33ms, matches 30fps
    queue: .main
) { [weak self] time in self?.currentTime = time }
```
A 30 Hz observer is smooth enough for a scrubber without hammering the main thread.

### 4. Thumbnail Strip — AVAssetImageGenerator

For the filmstrip / scrub background:
```swift
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: 80, height: 45) // thumbnail cell size
gen.generateCGImagesAsynchronously(forTimes: timestamps) { _, image, _, _, _ in ... }
```
- Generate N thumbnails (N = strip width ÷ cell width) asynchronously on first load.
- Cache as `[CMTime: UIImage]` — never regenerate.
- iOS 16+ has `images(for:)` async sequence — prefer that if targeting iOS 16+.

### 5. Export — AVAssetExportSession

For each marked clip (In → Out):
```swift
let session = AVAssetExportSession(asset: sourceAsset, presetName: AVAssetExportPresetPassthrough)!
session.timeRange = CMTimeRange(start: inPoint, end: outPoint)
session.outputFileType = .mp4
session.outputURL = tmpURL
await session.export()  // async/await available iOS 18+ via exportAsynchronously wrapper
```

**Preset choice:** `AVAssetExportPresetPassthrough` is the right default — it copies the video stream without re-encoding, making exports nearly instant (< 1 second for a 10-second clip). Use `AVAssetExportPresetHighestQuality` only if the source format is incompatible with passthrough (rare for HEVC/H.264 camera footage).

**After export:** save to Photos via:
```swift
try await PHPhotoLibrary.shared().performChanges {
    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmpURL)
}
```
Requires `NSPhotoLibraryAddOnlyUsageDescription` in Info.plist (add-only; no need for full read+write for this step).

### 6. Photos Library Access — PhotosKit

**Permission model (iOS 14+):**
- `.notDetermined` → `.authorized` (full) or `.limited` (user-selected subset)
- Request with `PHPhotoLibrary.requestAuthorization(for: .readWrite)`
- `.limited` is fine for this app — the user picks videos from the picker; if they granted limited access, they see only those videos, which is acceptable behavior.

**Fetching all videos:**
```swift
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
let results = PHAsset.fetchAssets(with: options)
```

**Loading for playback:**
```swift
PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
    // avAsset is AVURLAsset for local videos
}
```

**Info.plist keys required:**
- `NSPhotoLibraryUsageDescription` — for reading the library
- `NSPhotoLibraryAddOnlyUsageDescription` — for saving exported clips back

---

## Volume Button Capture — The Hard Problem

**This is the most constrained technical requirement in the project.**

### What is possible (MEDIUM confidence)

The only semi-supported approach on a **sideloaded, sandboxed iOS app** is KVO on `AVAudioSession.outputVolume`:

```swift
AVAudioSession.sharedInstance().addObserver(self,
    forKeyPath: "outputVolume", options: .new, context: nil)
```

When the hardware volume buttons are pressed, `outputVolume` changes and the KVO fires. You can detect "volume went up" vs "volume went down" and map those to In/Out.

**Setup required:**
1. Set `AVAudioSession.sharedInstance().setCategory(.playback)` — buttons must be actively controlling audio volume, not silent-switch behavior.
2. Keep `MPVolumeView` somewhere off-screen in the view hierarchy to suppress the system volume HUD (otherwise a translucent overlay appears every time the button fires).

### Limitations (HIGH confidence)

- This is a **gray area** — Apple does not document it as a supported input API.
- Volume clamps at 0.0 and 1.0; buttons pressed at those extremes do not generate KVO events. Mitigation: reset volume to 0.5 after each press (requires `MPVolumeView` slider manipulation, which is itself fragile).
- **App Store review risk:** Apps that misuse volume buttons as hidden input sometimes get flagged. For a personal sideloaded app (as Surfvid is), this is not a concern. For future App Store submission, this approach may require a fallback (e.g., on-screen buttons).
- There is **no official public API** for this. Private frameworks (`MediaRemote.framework`) can capture button events cleanly but are off-limits for any distributed app.

**Recommendation:** Use the KVO/MPVolumeView approach for the sideloaded v1. Build the In/Out marking UI to also work with on-screen tap targets as a fallback. Flag for review if an App Store submission is ever attempted.

---

## Deployment Target

| Target | Recommendation | Rationale |
|--------|---------------|-----------|
| **iOS 16** | Recommended minimum | Covers ~95%+ of active devices. Unlocks full SwiftUI navigation stack, Swift concurrency (`async/await`) throughout, and `AVAssetImageGenerator.images(for:)` async sequence. |
| iOS 17 | Optional upgrade | Adds SwiftData, improved animations — neither is needed for this app. No meaningful gain. |
| iOS 18 | Too aggressive | Reduces addressable device pool; no required APIs are iOS 18-only for this app. |

**Xcode version:** Xcode 16+ is required by Apple for App Store submissions (as of April 2025). Use Xcode 16 for development.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI framework | SwiftUI | UIKit | Project explicitly requires SwiftUI; SwiftUI DragGesture is sufficient |
| Video renderer | AVPlayerLayer (UIViewRepresentable) | AVPlayerViewController | AVPlayerViewController cannot be skinned for custom scrub UI |
| Video renderer | AVPlayerLayer (UIViewRepresentable) | SwiftUI VideoPlayer | VideoPlayer hides AVPlayer reference; no custom seek control |
| Library picker | PHPhotoLibrary direct | PHPickerViewController | Picker modal gives transient file access only, not PHAsset/AVAsset reference needed for scrubbing |
| Export format | .mp4 (H.264/HEVC passthrough) | .mov | .mp4 is universally compatible; camera footage is already H.264/HEVC so passthrough works |
| Third-party libs | None | Various | Project constraint explicitly forbids third-party dependencies for v1 |

---

## Key APIs Quick Reference

| API | Class | Purpose | iOS Floor |
|-----|-------|---------|-----------|
| `seek(to:toleranceBefore:toleranceAfter:)` | AVPlayer | Scrub seek | iOS 4 |
| `addPeriodicTimeObserver(forInterval:queue:using:)` | AVPlayer | Playhead tracking | iOS 4 |
| `requestAVAsset(forVideo:options:)` | PHImageManager | Load PHAsset as AVAsset | iOS 8 |
| `fetchAssets(with:)` | PHAsset | Query camera roll | iOS 8 |
| `creationRequestForAssetFromVideo(atFileURL:)` | PHAssetChangeRequest | Save clip to Photos | iOS 8 |
| `generateCGImagesAsynchronously(forTimes:completionHandler:)` | AVAssetImageGenerator | Filmstrip thumbnails | iOS 4 |
| `images(for:)` async sequence | AVAssetImageGenerator | Modern filmstrip | iOS 16 |
| `outputVolume` KVO | AVAudioSession | Volume button detection | iOS 6 (gray area) |

---

## Sources

- Apple Developer Documentation: AVFoundation (avfoundation), AVKit (avkit), PhotosKit (photokit), SwiftUI (swiftui)
- Apple Upcoming Requirements: https://developer.apple.com/news/upcoming-requirements/ (Xcode 16 / iOS 18 SDK required for App Store as of April 2025)
- PHAuthorizationStatus: https://developer.apple.com/documentation/photokit/phauthorizationstatus
- PHAssetChangeRequest: https://developer.apple.com/documentation/photokit/phassetchangerequest
- AVAssetExportSession: https://developer.apple.com/documentation/avfoundation/avassetexportsession
- addPeriodicTimeObserver: https://developer.apple.com/documentation/avfoundation/avplayer/addperiodictimeobserver
- MPVolumeView volume-button KVO: MEDIUM confidence (community-verified approach; not officially documented by Apple as supported input API)
