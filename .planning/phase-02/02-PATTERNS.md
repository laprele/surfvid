# Phase 2: Skim Interactions — Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 5 files (3 modified + 2 new)
**Analogs found:** 5 / 5 (all files have direct codebase analogs or RESEARCH.md patterns)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `SurfvidApp/AppViewModel.swift` | view-model | CRUD (clip state machine) | Current file — extend in-place | exact |
| `SurfvidApp/PlayerController.swift` | controller | streaming + event-driven (seek throttle, time observer) | Current file — extend in-place | exact |
| `SurfvidApp/Skim/SkimView.swift` | view | event-driven (gesture + chrome toggle + HUD) | Current file — extend in-place | exact |
| `SurfvidApp/Skim/TimelineBar.swift` | view | transform (Canvas drawing from state) | `SurfvidApp/Library/LibraryCell.swift` (stateful view, derived display) | role-match |
| `SurfvidApp/Shared/Formatters.swift` | utility | transform (pure function) | Current file — `formatTimecode` stub already present | exact |

---

## Pattern Assignments

### `SurfvidApp/AppViewModel.swift` (view-model, CRUD)

**Analog:** Current file at `/Users/alexanderlaprell/repos/surfvid/SurfvidApp/AppViewModel.swift`

**Existing state declaration pattern** (lines 7–11) — copy this shape for new `@Published` properties:
```swift
class AppViewModel: ObservableObject {
    @Published var screen: Screen = .library
    @Published var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []
```

**What to ADD in Phase 2 — new state declarations** (insert after line 11, before `let playerController`):
```swift
    // Phase 2: clip marking state
    struct Clip: Identifiable {
        let id = UUID()
        let start: Double   // seconds into the video
        let end: Double     // seconds into the video
    }

    @Published var clips: [Clip] = []
    @Published var pendingIn: Double? = nil
```

**Existing method pattern** (lines 23–28) — new methods follow the same `func name()` top-level shape without extra visibility modifiers:
```swift
    func pickVideo(_ asset: PHAsset) {
        Task {
            await playerController.load(asset: asset)
            await MainActor.run { screen = .skim }
        }
    }
```

**What to ADD — clip state machine methods** (append after `fetchVideos()`, before closing brace):
```swift
    func markIn(at time: Double) {
        // D-08: Double-In resets pending to new position. No confirmation, no alert.
        pendingIn = time
    }

    func markOut(at time: Double) {
        if let inTime = pendingIn {
            // Normal path: both In and Out set
            let start = min(inTime, time)
            let end = max(inTime, time)
            guard end > start else { return }   // Pitfall 7: zero-duration guard
            clips.append(Clip(start: start, end: end))
            pendingIn = nil
        } else {
            // D-07: Out before In → auto-set In = max(0, currentTime - 15s)
            let autoIn = max(0, time - 15.0)
            clips.append(Clip(start: autoIn, end: time))
        }
    }

    func resetForNewVideo() {
        clips = []
        pendingIn = nil
    }
```

**Integration point:** `pickVideo(_:)` (line 23) — call `resetForNewVideo()` here so each video load starts with a clean clip list:
```swift
    func pickVideo(_ asset: PHAsset) {
        resetForNewVideo()      // ADD THIS LINE
        Task {
            await playerController.load(asset: asset)
            await MainActor.run { screen = .skim }
        }
    }
```

---

### `SurfvidApp/PlayerController.swift` (controller, streaming + event-driven)

**Analog:** Current file at `/Users/alexanderlaprell/repos/surfvid/SurfvidApp/PlayerController.swift`

**Existing imports and class skeleton** (lines 1–7) — Phase 2 adds `QuartzCore` import:
```swift
import AVFoundation
import Photos
import Combine
// ADD: import QuartzCore   ← for CADisplayLink
```

**Existing class-level pattern** (lines 5–7):
```swift
class PlayerController: ObservableObject {
    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
```

**Existing `[weak self]` + Combine pattern** (lines 18–33) — all new closure callbacks copy this capture list and guard pattern:
```swift
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: videoOptions
            ) { [weak self] avAsset, _, _ in
                guard let self, let avAsset = avAsset else {
                    continuation.resume()
                    return
                }
```

**What to ADD — new @Published properties** (insert after line 7, before `func load`):
```swift
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    var duration: Double = 0   // set from AVPlayerItem after load; not @Published (no UI binds directly)
    var isScrubbing: Bool = false
```

**What to ADD — CADisplayLink proxy (retain-cycle-safe)** (insert as a private nested class before `func load`):
```swift
    // Nested proxy — CADisplayLink retains the proxy, not self. Prevents retain cycle.
    // Pattern source: RESEARCH.md Pattern 1 (Apple CADisplayLink docs)
    private class DisplayLinkTarget: NSObject {
        weak var owner: PlayerController?
        @objc func tick(link: CADisplayLink) {
            owner?.onDisplayLinkTick()
        }
    }
    private var displayLink: CADisplayLink?
```

**What to ADD — seek throttle state** (insert alongside DisplayLinkTarget block):
```swift
    private var chaseTime: CMTime = .zero
    private var isSeekInProgress = false
    private var timeObserverToken: Any?
```

**What to ADD — seek throttle methods** (append after `load(asset:)` closing brace):
```swift
    // Called from DragGesture.onChanged — accumulates target, does NOT seek directly
    func updateSeekTarget(_ time: Double) {
        chaseTime = CMTimeMakeWithSeconds(max(0, time), preferredTimescale: 600)
    }

    // Flush one seek per CADisplayLink tick (Pattern 2: Apple QA1820 chase-time)
    private func flushPendingSeek() {
        guard !isSeekInProgress,
              player.currentItem?.status == .readyToPlay else { return }
        let target = chaseTime
        isSeekInProgress = true
        player.seek(
            to: target,
            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
            toleranceAfter:  CMTime(seconds: 0.5, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self else { return }
            if finished {
                self.isSeekInProgress = false
                if CMTimeCompare(self.chaseTime, target) != 0 {
                    self.flushPendingSeek()   // chase if target moved during seek
                }
            }
            // !finished = interrupted by newer seek; new seek will complete and call this
        }
    }

    // Zero-tolerance seek — only for In/Out commit (D-05)
    func seekExact(to time: Double) {
        let target = CMTimeMakeWithSeconds(max(0, time), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
    }

    // Start CADisplayLink — call on drag begin
    func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkTarget()
        proxy.owner = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTarget.tick(link:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // Stop CADisplayLink — call on drag end
    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayLinkTick() {
        flushPendingSeek()
        // Update currentTime from player during scrub (overrides the periodic observer)
        currentTime = player.currentTime().seconds
    }

    // Periodic time observer for playback (not scrub)
    func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self, !self.isScrubbing else { return }  // Pitfall 2 guard
            self.currentTime = time.seconds
        }
    }

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    deinit {
        stopDisplayLink()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)   // Pitfall 6: mandatory teardown
        }
    }
```

**Integration point:** In `load(asset:)`, after `player.replaceCurrentItem(with: item)` (line 35), add:
```swift
                    self.duration = avAsset.duration.seconds
                    self.setupTimeObserver()
```

Also in the status sink (line 28), observe `isPlaying`:
```swift
                    let cancellable = item.publisher(for: \.status)
                        .filter { $0 != .unknown }
                        .first()
                        .sink { [weak self] status in
                            if status == .readyToPlay {
                                self?.player.pause()
                                self?.isPlaying = false
                            }
                        }
```

---

### `SurfvidApp/Skim/SkimView.swift` (view, event-driven)

**Analog:** Current file at `/Users/alexanderlaprell/repos/surfvid/SurfvidApp/Skim/SkimView.swift`

**Existing struct and @EnvironmentObject pattern** (lines 4–6) — all new `@State` goes here:
```swift
struct SkimView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    // ADD Phase 2 local state:
    @State private var chromeVisible: Bool = true
    @State private var isScrubbing: Bool = false
    @State private var lastDragX: CGFloat = 0
    @State private var hudFlash: HUDKind? = nil

    enum HUDKind { case inPoint, outPoint }
```

**Existing ZStack layer order** (lines 8–33) — MUST NOT change (Pitfall 3: AVPlayerLayer identity):
```swift
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                PlayerView(player: appViewModel.playerController.player)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                    bottomChrome
                }
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
            }
        }
```

**What to ADD — gesture layer** (new Layer 3 in the ZStack, between PlayerView and the VStack chrome):
```swift
                // Layer 3: Gesture capture surface (between video and chrome)
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .gesture(scrubGesture)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    chromeVisible.toggle()
                                }
                            }
                    )
```

**What to ADD — chrome opacity wrapper** on the VStack chrome (wrap the existing VStack):
```swift
                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                    bottomChrome
                }
                .padding(.leading, 60)
                .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
                .opacity(chromeVisible ? 1 : 0)       // D-01
                .animation(.easeOut(duration: 0.2), value: chromeVisible)
```

**What to ADD — HUD flash overlay** (as a new layer above the VStack chrome, inside ZStack):
```swift
                // Layer 5: HUD flash overlay
                hudFlashOverlay
```

**Existing Button pattern** in `topChrome` (lines 42–50) — In/Out buttons copy this shape exactly:
```swift
            Button(action: { appViewModel.screen = .library }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .regular))
                    Text("Library")
                        .font(.body)
                }
                .foregroundColor(.white)
            }
```

**Existing `bottomChrome` computed property** (lines 87–134) — Phase 2 replaces/extends three elements inside it:

1. Replace `Text("0:00.0")` (line 93) with:
```swift
                Text(formatTimecode(appViewModel.playerController.currentTime))
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
```

2. Replace the `RoundedRectangle` placeholder (lines 106–112) with:
```swift
                // D-09: Plain Canvas timeline bar — no thumbnail images
                HStack(spacing: 8) {
                    Button("IN") {
                        let t = appViewModel.playerController.currentTime
                        appViewModel.playerController.seekExact(to: t)   // D-05
                        appViewModel.markIn(at: t)
                        showHUD(.inPoint)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 36)

                    TimelineBar(
                        duration: appViewModel.playerController.duration,
                        currentTime: appViewModel.playerController.currentTime,
                        clips: appViewModel.clips,
                        pendingIn: appViewModel.pendingIn
                    )

                    Button("OUT") {
                        let t = appViewModel.playerController.currentTime
                        appViewModel.playerController.seekExact(to: t)   // D-05
                        appViewModel.markOut(at: t)
                        showHUD(.outPoint)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 36)
                }
```

3. Replace `Text("0 marked")` (line 100) with:
```swift
                Text("\(appViewModel.clips.count) marked")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
```

**What to ADD — pending-In pill** (new ZStack layer between gesture surface and VStack chrome):
```swift
                // Layer 4: Pending-IN pill (below topChrome, above video)
                if let inTime = appViewModel.pendingIn, chromeVisible {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.80, green: 0.38, blue: 0.18))
                            .frame(width: 6, height: 6)
                        Text("MARKING · IN @ \(formatTimecode(inTime))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(red: 0.72, green: 0.32, blue: 0.14))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 56)
                    .transition(.opacity)
                }
```

**What to ADD — play/pause button** (insert in bottomChrome HStack with timecode, alongside `Spacer()`):
```swift
                // Play/pause button — D-02: dedicated button, not tap-on-video
                Button(action: { appViewModel.playerController.togglePlayPause() }) {
                    Image(systemName: appViewModel.playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
```

**What to ADD — scrubGesture computed property** (add as a private computed property on SkimView):
```swift
    // D-04: Velocity-driven scrub — direction and speed from position delta, not finger position.
    // D-03: Drag always pauses. D-05: CADisplayLink throttles seek, not every event.
    // iOS 16 compatible: no DragGesture.Value.velocity (iOS 17+ only).
    private let PX_PER_S: Double = 0.6   // prototype value; tune on device with real H.264 footage

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 8)   // 8pt avoids tap/drag conflict (Pitfall 3 / Pattern 4)
            .onChanged { [self] value in
                let dx = Double(value.location.x - lastDragX)
                lastDragX = value.location.x

                if !isScrubbing {
                    isScrubbing = true
                    appViewModel.playerController.isScrubbing = true
                    appViewModel.playerController.player.pause()   // D-03
                    appViewModel.playerController.isPlaying = false
                    appViewModel.playerController.startDisplayLink()
                }

                // dSec = -dx / PX_PER_S: right drag → negative dSec → earlier in video
                // Matches prototype: const dSec = -dx / PX_PER_S (prototype line 34)
                let dSec = -dx / PX_PER_S
                let currentTime = appViewModel.playerController.currentTime
                let duration = appViewModel.playerController.duration
                let newTime = max(0, min(duration, currentTime + dSec))
                appViewModel.playerController.updateSeekTarget(newTime)
            }
            .onEnded { _ in
                isScrubbing = false
                appViewModel.playerController.isScrubbing = false
                lastDragX = 0
                appViewModel.playerController.stopDisplayLink()
                // D-03: do NOT auto-resume playback
            }
    }
```

**What to ADD — HUD flash helpers** (add as private methods on SkimView):
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

    // Flash band from top edge — matches prototype SVFlashBandLandscape
    // In = left side, accent orange. Out = right side, white.
    @ViewBuilder
    private var hudFlashOverlay: some View {
        if let kind = hudFlash {
            let color: Color = kind == .inPoint
                ? Color(red: 0.87, green: 0.42, blue: 0.20)   // UI-SPEC accent oklch(0.7 0.16 30)
                : Color.white
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 80, height: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: kind == .inPoint ? .topLeading : .topTrailing)
                .padding(.top, 0)
                .padding(.horizontal, kind == .inPoint
                    ? CGFloat(0.36 * UIScreen.main.bounds.width)
                    : CGFloat(0.52 * UIScreen.main.bounds.width))
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }
```

---

### `SurfvidApp/Skim/TimelineBar.swift` (view, transform — NEW FILE)

**Analog for structure:** `SurfvidApp/Library/LibraryCell.swift` — a stateless struct View that takes `let` props and displays derived UI. No `@EnvironmentObject`; no `@State`. All inputs passed as plain `let` constants.

**LibraryCell struct pattern** (lines 1–7 of LibraryCell.swift) — copy this shape:
```swift
import SwiftUI
import Photos

struct LibraryCell: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage? = nil
```

**TimelineBar follows the same pattern — props only, no side effects:**
```swift
import SwiftUI

struct TimelineBar: View {
    let duration: Double
    let currentTime: Double
    let clips: [AppViewModel.Clip]
    let pendingIn: Double?
```

**Core Canvas pattern** (from RESEARCH.md Pattern 6, verified against Apple docs):
```swift
    // UI-SPEC accent: oklch(0.65 0.14 30 / 0.45) fill → approx sRGB(0.83, 0.35, 0.15) @ 45%
    // UI-SPEC accent: oklch(0.7 0.16 30) border → approx sRGB(0.87, 0.42, 0.20)
    // Prototype: SVMiniFilmstrip (lines 246-280 of prototype JSX)

    private static let clipFill = Color(red: 0.83, green: 0.35, blue: 0.15).opacity(0.45)
    private static let clipBorder = Color(red: 0.87, green: 0.42, blue: 0.20)
    private static let pendingInColor = Color(red: 0.87, green: 0.42, blue: 0.20)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard duration > 0 else { return }

            // 1. Clip ranges — prototype JSX lines 246-254
            for clip in clips {
                let x = CGFloat(clip.start / duration) * w
                let clipW = max(2, CGFloat((clip.end - clip.start) / duration) * w)
                let rect = CGRect(x: x, y: 0, width: clipW, height: h)
                context.fill(Path(rect), with: .color(Self.clipFill))
                context.stroke(Path(rect), with: .color(Self.clipBorder), lineWidth: 1.5)
            }

            // 2. Pending-In marker — prototype JSX lines 256-266
            if let inTime = pendingIn {
                let x = CGFloat(inTime / duration) * w
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: h))
                context.stroke(line, with: .color(Self.pendingInColor), lineWidth: 1.5)
                // 7×7 diamond cap at top — prototype: top: -2, left: -3, width: 7, height: 7
                let cap = CGRect(x: x - 3.5, y: -3.5, width: 7, height: 7)
                context.fill(Path(roundedRect: cap, cornerRadius: 1), with: .color(Self.pendingInColor))
            }

            // 3. Playhead — prototype JSX lines 268-280
            let px = CGFloat(currentTime / duration) * w
            var playhead = Path()
            playhead.move(to: CGPoint(x: px, y: -3))
            playhead.addLine(to: CGPoint(x: px, y: h + 3))
            context.stroke(playhead, with: .color(.white), lineWidth: 1.5)
            // 9×9 square cap — prototype: top: -3, left: -4, width: 9, height: 9
            let cap = CGRect(x: px - 4.5, y: -3 - 4.5, width: 9, height: 9)
            context.fill(Path(roundedRect: cap, cornerRadius: 1), with: .color(.white))
        }
        // Background track — exact placeholder from SkimView lines 106-112 (keep frame + border)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
        .frame(height: 28)   // matches prototype height: 28 and SkimView placeholder frame
    }
}
```

**Canvas re-draw rule:** Canvas re-draws whenever its SwiftUI view identity updates. Since `TimelineBar` is called with `let` props derived from `@Published` values in `PlayerController` and `AppViewModel`, any `@Published` change propagates through `SkimView` → `TimelineBar` → Canvas redraw automatically. No manual observation needed.

---

### `SurfvidApp/Shared/Formatters.swift` (utility, pure transform — ALREADY IMPLEMENTED)

**Analog:** Current file at `/Users/alexanderlaprell/repos/surfvid/SurfvidApp/Shared/Formatters.swift`

`formatTimecode(_:)` is fully implemented at lines 23–35. No changes needed to the file itself.

**Wire pattern in SkimView** — replace the static string `Text("0:00.0")` (SkimView line 93) with:
```swift
Text(formatTimecode(appViewModel.playerController.currentTime))
```

`formatTimecode` is a top-level function, not a method — call it directly with no namespace, same as `formatDuration` is called in `LibraryCell`.

---

## Shared Patterns

### @EnvironmentObject Access
**Source:** `SurfvidApp/Skim/SkimView.swift` lines 5–6
**Apply to:** `SkimView` (all new controls read from `appViewModel`)

```swift
@EnvironmentObject var appViewModel: AppViewModel
```

Pattern already established in SkimView. New controls and gesture handlers access `appViewModel.playerController` and `appViewModel.clips` / `appViewModel.pendingIn` via this existing property — no additional wiring needed.

---

### [weak self] in Closures
**Source:** `SurfvidApp/PlayerController.swift` lines 18–19
**Apply to:** All new escaping closures in `PlayerController` (seek completion handlers, Combine sinks)

```swift
{ [weak self] avAsset, _, _ in
    guard let self, let avAsset = avAsset else {
```

All seek completion handlers and CADisplayLink callbacks in `PlayerController` must use `[weak self]` + `guard let self` — same pattern as the existing `requestAVAsset` callback.

---

### @MainActor Dispatch for @Published Mutations
**Source:** `SurfvidApp/AppViewModel.swift` lines 36–41
**Apply to:** All `PlayerController` callback closures that write `@Published` properties

```swift
        await MainActor.run {
            self.authStatus = status
            if status == .authorized || status == .limited {
                self.fetchVideos()
            }
        }
```

`PlayerController.currentTime` and `isPlaying` are `@Published` and must only be written on the main thread. The periodic time observer is already configured with `queue: .main`. The CADisplayLink `onDisplayLinkTick` fires on `.main` run loop — safe. The seek completion handler fires on main by default for `AVPlayer` — safe. The `load(asset:)` callback must dispatch to main before setting duration.

---

### Combine AnyCancellable Storage
**Source:** `SurfvidApp/PlayerController.swift` line 7
**Apply to:** Any new Combine subscriptions in `PlayerController`

```swift
    private var cancellables = Set<AnyCancellable>()
```

Already present. New `@Published` subscriptions (e.g., observing `isPlaying` from `player.timeControlStatus`) store their `AnyCancellable` tokens here.

---

### Private Computed Property for Sub-Views
**Source:** `SurfvidApp/Skim/SkimView.swift` lines 38, 87
**Apply to:** `scrubGesture`, `hudFlashOverlay`, `pendingInPill` additions in `SkimView`

```swift
    private var topChrome: some View { ... }
    private var bottomChrome: some View { ... }
```

New additions (`scrubGesture`, `hudFlashOverlay`) follow the same `private var name: some Gesture/View` computed property shape. The `hudFlashOverlay` uses `@ViewBuilder` because it has conditional content.

---

## No Analog Found

All files have direct codebase analogs or fully-specified patterns in RESEARCH.md. There are no files requiring invention from scratch.

| File | Why No New Analog Needed |
|------|--------------------------|
| `TimelineBar.swift` | Canvas drawing fully specified in RESEARCH.md Pattern 6 + prototype JSX `SVMiniFilmstrip` lines 228–281 |
| `PlayerController` seek throttle | Chase-time pattern fully specified in RESEARCH.md Pattern 2 (Apple QA1820) |
| `PlayerController` CADisplayLink | Proxy pattern fully specified in RESEARCH.md Pattern 1 |
| HUD flash overlay | Pattern fully specified in RESEARCH.md Pattern 7 + prototype `SVFlashBandLandscape` lines 307–318 |
| In/Out state machine | Logic fully specified in RESEARCH.md Pattern 8 + prototype `markIn`/`markOut` lines 55–72 |

---

## Prototype-to-Swift Quick Reference

| Prototype (JSX) | Swift Equivalent | File |
|-----------------|-----------------|------|
| `const PX_PER_S = 0.6` (line 15) | `private let PX_PER_S: Double = 0.6` | `SkimView` |
| `vSmooth = vSmooth * 0.7 + (dx/dt) * 0.3` (line 32) | Position delta `dx` drives `dSec` directly; CADisplayLink controls rate | `SkimView` |
| `const dSec = -dx / PX_PER_S` (line 34) | `let dSec = -dx / PX_PER_S` — right = earlier | `SkimView` |
| `setPendingIn(playhead)` / `setPendingIn(null)` (lines 56, 68) | `appViewModel.pendingIn = time` / `= nil` via `markIn`/`markOut` | `AppViewModel` |
| `onAddClip({ start, end })` (lines 63, 67) | `appViewModel.clips.append(Clip(start:end:))` | `AppViewModel` |
| `setTimeout(() => setHud(null), 700)` (lines 58, 71) | `Task { try? await Task.sleep(nanoseconds: 700_000_000) }` | `SkimView` |
| `SVMiniFilmstrip` clip rect drawing (lines 246–254) | `Canvas` clip rect loop | `TimelineBar` |
| `SVMiniFilmstrip` pending-In line (lines 256–266) | `Canvas` pending-In line + diamond cap | `TimelineBar` |
| `SVMiniFilmstrip` playhead line (lines 268–280) | `Canvas` playhead line + square cap | `TimelineBar` |
| `SVFlashBandLandscape` left 36%, width 80 (line 313) | `.padding(.horizontal, 0.36 * screenWidth)` | `SkimView` |
| `chromeHidden` toggle on click (line 92) | `chromeVisible.toggle()` via `TapGesture().onEnded` | `SkimView` |
| `opacity: chromeHidden ? 0 : 1, transition: 200ms` (lines 117, 164) | `.opacity(chromeVisible ? 1 : 0).animation(.easeOut(duration: 0.2))` | `SkimView` |

---

## Metadata

**Analog search scope:** `/Users/alexanderlaprell/repos/surfvid/SurfvidApp/` — all 10 Swift files read
**Prototype read:** `/Users/alexanderlaprell/repos/surfvid/Surfvid/surfvid-paper-skim-landscape.jsx` — full file
**Pattern extraction date:** 2026-05-10
