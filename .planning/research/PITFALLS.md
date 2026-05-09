# iOS Video App Pitfalls

**Domain:** Native SwiftUI + AVFoundation video editing app
**Researched:** 2026-05-09
**Confidence:** HIGH for AVFoundation/Photos APIs (well-established, stable); MEDIUM for volume-button approach (Apple policy edges)

---

## Critical Pitfalls

### Pitfall 1: Volume Button Capture Is Sandboxed — the Core Feature May Not Work As Designed

**What goes wrong:** The hardware volume buttons on iOS are system-owned. Apps cannot intercept them as arbitrary input events. The prototype validated "volume button = mark In/Out" as a concept, but the real iOS restriction is that pressing volume buttons changes system volume — you cannot silently consume the event without a side effect.

**Why it happens:** iOS media sandbox. Only the system media HUD and `MPVolumeView` have direct access to volume button events. Apps receive a `AVAudioSession` route change notification or can observe `outputVolume` on `AVAudioSession.sharedInstance()`, but this has two problems: the volume actually changes (audible click, system HUD flashes), and if the volume is already at 0 or 100, the button press produces no `outputVolume` change at all.

**Consequences:** The primary marking interaction may not work reliably. At min/max volume, button presses are silent and undetectable. Users will see the system volume HUD every time they mark a point, breaking immersion.

**Prevention:**
- In Phase 1 (playback foundation), spike this immediately on a real device — do not defer to Phase 3.
- Use KVO on `AVAudioSession.sharedInstance().outputVolume`, set initial volume to 0.5 at session start to preserve headroom in both directions, and suppress the HUD by embedding a hidden `MPVolumeView` in the view hierarchy.
- Accept that this is a "good enough for personal use" hack, not a robust solution.
- Have a fallback interaction (e.g., on-screen tap) ready from the start.

**Detection:** Build the spike as the very first device test. If the HUD suppression trick stops working in a future iOS update, the app silently degrades to showing the volume HUD on every mark.

**Phase:** Must be validated in Phase 1 (Core Playback), not deferred.

---

### Pitfall 2: AVPlayer seek() Without Zero Tolerance Gives Inaccurate Scrub Position

**What goes wrong:** The default `AVPlayer.seek(to:)` uses `AVAsyncKeyValueLoading`-style tolerance: it snaps to the nearest I-frame (keyframe), which can be 1–2 seconds away from the requested time. For a scrubbing UI where the user drags to a precise frame, this makes the playhead feel laggy and imprecise.

**Why it happens:** By default, Apple uses `toleranceBefore: .positiveInfinity` and `toleranceAfter: .positiveInfinity` for performance. Decoding to an exact frame requires seeking to the prior keyframe and decoding forward, which is slower.

**Consequences:** In/Out points land on wrong frames. Export cuts to the wrong moment. The scrub thumb position visually disagrees with actual video frame shown.

**Prevention:** Always use the four-argument form for scrubbing:
```swift
player.seek(to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero)
```
Accept that this is slower. For coarse scrubbing (finger still moving), throttle seeks. For final In/Out point commitment, always use zero tolerance.

**Detection:** Test with a video that has long GOP intervals (HEVC from iPhone typically has 1–2 second keyframe intervals). The error will be obvious.

**Phase:** Phase 1 (Core Playback).

---

### Pitfall 3: Overlapping seek() Calls Corrupt Player State

**What goes wrong:** Calling `seek(to:)` while a previous seek is still in flight causes undefined ordering. The player may end up at neither the old nor the new time, and `isSeekInProgress`-style flags get out of sync.

**Why it happens:** `seek(to:completionHandler:)` is asynchronous. Rapid scrub drag generates many calls per second. Each call cancels the previous, but completion handlers still fire — sometimes out of order.

**Consequences:** Playhead jumps erratically. Completion handlers fire with `finished: false` and are incorrectly treated as successes. In/Out times recorded during rapid scrub are wrong.

**Prevention:** Track a pending seek flag. When a new seek arrives while one is in flight, store only the most recent target and issue a new seek only after the current one completes:
```swift
var pendingSeekTime: CMTime?
var isSeeking = false

func scrubTo(_ time: CMTime) {
    if isSeeking {
        pendingSeekTime = time
        return
    }
    isSeeking = true
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
        guard let self else { return }
        self.isSeeking = false
        if let next = self.pendingSeekTime {
            self.pendingSeekTime = nil
            self.scrubTo(next)
        }
    }
}
```

**Detection:** Add logging to completion handlers; if `finished: false` appears during normal drag, the pattern is broken.

**Phase:** Phase 1 (Core Playback).

---

### Pitfall 4: AVPlayerItem KVO Observation Without Proper Teardown Causes Crashes

**What goes wrong:** Adding KVO observers on `AVPlayerItem` (status, `loadedTimeRanges`, `playbackBufferEmpty`) without removing them before the item is deallocated causes `NSInternalInconsistencyException` crashes that are hard to reproduce.

**Why it happens:** `AVPlayerItem` does not use Swift's `Observation` or Combine natively for all properties. KVO observers must be explicitly removed. In SwiftUI, the view model or coordinator that holds the observer may outlive or be recreated independently of the item.

**Consequences:** Sporadic "was deallocated while key value observers were still registered" crashes, typically on navigation back or when the app is backgrounded.

**Prevention:** Use `addObserver(_:forKeyPath:options:context:)` only inside a dedicated `Coordinator`/`ViewModel` that owns the item lifetime. Prefer Combine's `.publisher(for: \.status)` on `AVPlayerItem` which automatically unsubscribes when the `AnyCancellable` is deallocated. Store all `AnyCancellable` in a `Set<AnyCancellable>` on the owning object.

**Detection:** Run the app under the Zombie Objects instrument. Any "message sent to deallocated instance" from AVFoundation classes signals this problem.

**Phase:** Phase 1 (Core Playback).

---

## Moderate Pitfalls

### Pitfall 5: PHPhotoLibrary Authorization — Limited Access Mode (iOS 14+)

**What goes wrong:** On iOS 14+, users can grant "Limited" access — the app sees only a subset of the library, not the full camera roll. Apps that assume full access will silently miss videos. Worse, the limited-access picker (PHPickerViewController) bypasses authorization entirely — but it also returns `PHAsset` identifiers only after explicit user selection, not a browsable library.

**Prevention:** Always check `PHAuthorizationStatus.limited` as a distinct case. Prompt users to update their selection via `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)` when limited. For a personal tool, document that full access is required for the library-browsing screen to work correctly.

**Detection:** Test with an account that has Limited access configured in Settings.

**Phase:** Phase 1 (Library access).

---

### Pitfall 6: AVAssetExportSession Fails Silently Without Error Inspection

**What goes wrong:** `AVAssetExportSession.export(to:as:)` (async/await form, iOS 18+) or the completion-handler form returns a session with `.failed` status and a non-nil `error`, but callers that only check the completion block's implied success silently produce no output file.

**Prevention:** Always inspect `exportSession.status == .failed` and log `exportSession.error`. The most common error is `AVErrorMediaServicesWereReset` (background kill) and `AVErrorExportFailed` (unsupported combination of preset + asset codec). Use `AVAssetExportPresetPassthrough` when no re-encode is needed; it is the fastest and most reliable preset for simple trim exports.

**Detection:** Export to a known path and verify the file exists and has non-zero size after export.

**Phase:** Phase 2 (Export).

---

### Pitfall 7: Background Export Killed Without UIBackgroundTask

**What goes wrong:** If the user backgrounds the app during a long export, iOS may suspend or terminate the process. `AVAssetExportSession` does not survive process suspension.

**Prevention:** Wrap export in a `UIApplication.shared.beginBackgroundTask(withName:expirationHandler:)` block. In the expiration handler, cancel the export session and show a notification or badge. For a personal sideloaded tool without background-processing entitlements, set user expectations: keep the app in foreground during export.

**Detection:** Start a 2-minute export, immediately background the app, return after 30 seconds. If the file is incomplete or missing, background handling is broken.

**Phase:** Phase 2 (Export).

---

### Pitfall 8: SwiftUI Rebuilds Recreate UIViewRepresentable and Tear Down AVPlayerLayer

**What goes wrong:** When a parent SwiftUI view rebuilds (e.g., due to a `@State` change), `makeUIView` may be called again, creating a new `AVPlayerLayer`. The old layer is removed from the view hierarchy, taking the player output with it. The player continues playing but nothing is visible.

**Why it happens:** SwiftUI's diffing does not always recognize that a `UIViewRepresentable` wrapping an `AVPlayerLayer` is the same view. If the wrapping view's identity changes (e.g., it's inside a conditional or its `id` modifier changes), SwiftUI tears it down and recreates it.

**Prevention:** Keep the `AVPlayer` instance in an `@StateObject` ViewModel so it survives view rebuilds. In `updateUIView`, do not create a new `AVPlayerLayer` — only update properties. Use a stable `id` for the video player view.

**Detection:** Add a `print("makeUIView called")` log; if it fires more than once per video session, the player is being recreated.

**Phase:** Phase 1 (Core Playback).

---

### Pitfall 9: AVPlayer Memory Leaks from Retained Player Items

**What goes wrong:** `AVPlayerItem` holds a strong reference to its underlying `AVAsset`, which loads video data into memory. If old player items are not replaced (using `player.replaceCurrentItem(with: nil)`) when navigating away from a video, each visited video accumulates memory.

**Prevention:** Call `player.replaceCurrentItem(with: nil)` in the view's `onDisappear` or `deinit`. Remove all periodic time observers (they hold a strong reference to the player) with `player.removeTimeObserver(_:)`.

**Detection:** Use the Allocations instrument. After visiting 5 videos, memory should not grow proportionally. If `AVAssetResourceLoader` or `AVURLAsset` instances accumulate, items are leaking.

**Phase:** Phase 1 (Core Playback), validated in Phase 3 (multi-clip).

---

### Pitfall 10: Thumbnail Generation Blocks the Main Thread

**What goes wrong:** `AVAssetImageGenerator.copyCGImage(at:actualTime:)` is synchronous and can block for 100–500ms on large HEVC files. Called from a `LazyVGrid` cell for a library of 50 videos, this freezes the scroll.

**Prevention:** Always use `generateCGImagesAsynchronously(forTimes:completionHandler:)`. Cache generated thumbnails keyed by asset local identifier + timestamp. Cancel pending image generation when cells scroll off screen.

**Detection:** Enable the Main Thread Checker in the Xcode scheme. Any synchronous AVFoundation call from the main thread will be flagged.

**Phase:** Phase 1 (Library screen).

---

## Minor Pitfalls

### Pitfall 11: Hardcoded Export Paths to Documents Directory

**What goes wrong:** Exporting to a hardcoded `FileManager.default.urls(for: .documentDirectory)` path works on first run but leaves orphaned files on repeat exports (same filename collision) and wastes storage.

**Prevention:** Use a UUID-named temp file in `FileManager.default.temporaryDirectory`, save to Photos via `PHPhotoLibrary`, then delete the temp file immediately after. Never accumulate files in the Documents directory.

**Phase:** Phase 2 (Export).

---

### Pitfall 12: No Error Handling for AVPlayerItem Status .failed

**What goes wrong:** If the Photos asset is a Live Photo, a slow-motion video, or an unsupported format, `AVPlayerItem.status` transitions to `.failed`. Apps that only handle `.readyToPlay` leave the UI in a loading spinner forever.

**Prevention:** In the KVO/Combine observer for `AVPlayerItem.status`, handle `.failed` explicitly: log `playerItem.error`, show an error state in the UI, and allow the user to dismiss.

**Phase:** Phase 1 (Core Playback).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Core Playback (Phase 1) | Volume button detection fails at min/max volume | Spike on device on day one; set initial volume to 0.5 |
| Core Playback (Phase 1) | seek() inaccuracy ruins In/Out precision | Always use toleranceBefore/After: .zero for committed marks |
| Core Playback (Phase 1) | SwiftUI rebuild tears down AVPlayerLayer | Keep AVPlayer in @StateObject, stable id on player view |
| Library screen (Phase 1) | Thumbnail generation freezes scroll | Async image generation, cancel on scroll |
| Multi-clip session (Phase 2) | Player item leak across clips | replaceCurrentItem(with: nil) on exit |
| Export (Phase 2) | Export fails silently | Always inspect exportSession.status and .error |
| Export (Phase 2) | Background kill during long export | UIBackgroundTask wrapper + user expectation setting |
| Photos permissions (Phase 1) | Limited access silently hides videos | Handle .limited case; prompt for full access |

---

## Sources

- Apple Developer Documentation: AVPlayer, AVPlayerItem, AVAssetExportSession, PHPhotoLibrary (knowledge cutoff August 2025; HIGH confidence for all AVFoundation APIs which have been stable since iOS 14)
- MPVolumeView / outputVolume KVO pattern: well-known community workaround; MEDIUM confidence on HUD suppression behavior in iOS 18+ (verify on target OS version)
- UIBackgroundTask + AVAssetExportSession: documented Apple pattern; HIGH confidence
