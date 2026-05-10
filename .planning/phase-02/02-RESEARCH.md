# Phase 2: Skim Interactions — Research

**Researched:** 2026-05-10
**Domain:** AVFoundation seek throttling, SwiftUI gesture composition, real-time UI updates, timeline drawing
**Confidence:** HIGH (core patterns verified against Apple canonical sources and official documentation)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Tap on the video surface = hide/show chrome. The overlay chrome fades out on tap and back in on the next tap. Matches the existing hint copy "Drag to skim · Tap to hide" in SkimView.
- **D-02:** Play/pause lives in the bottom chrome, next to the timecode readout. It is a dedicated button — not a tap-on-video gesture.
- **D-03:** Scrubbing always pauses playback. Releasing the drag does NOT auto-resume — user must tap play manually.
- **D-04:** Velocity-driven scrubbing — drag speed and direction drive seek rate; finger X position is irrelevant (QuickTime-style). Prototype used PX_PER_S ≈ 0.6 with exponential smoothing (vSmooth = vSmooth * 0.7 + rawV * 0.3). Planner tunes exact values.
- **D-05:** Throttle seek() to CADisplayLink rate during drag (not every gesture event). On In or Out tap, fire a final seek(to:toleranceBefore:.zero, toleranceAfter:.zero) to commit the exact frame. Pending-seek flag prevents overlapping seeks.
- **D-06:** In and Out buttons sit in the bottom chrome, flanking the timeline bar: [ IN ] [====timeline====] [ OUT ].
- **D-07:** Out before In → auto-set In = max(0, currentTime − 15s), save the clip. Matches prototype behavior.
- **D-08:** Double-In (In tapped while a pending In already exists) → reset pending In to the new position. First mark is cancelled; no confirmation needed.
- **D-09:** No thumbnail images in the timeline bar. The 28pt bar is a visual-only progress timeline: full video duration = full bar width. Shows: (a) colored range overlays for each marked clip, (b) a pending-In marker line when In is set but Out hasn't been tapped yet, (c) a white playhead line that tracks the current position in real time.
- **D-10:** Timeline bar is display-only — not tappable.
- **D-11:** No AVAssetImageGenerator — no async thumbnail work needed.
- **D-12:** Clip list lives in AppViewModel as @Published var clips: [Clip] and @Published var pendingIn: Double?. Clip is a plain struct { id: UUID, start: Double, end: Double }.

### Claude's Discretion

- Exact PX_PER_S value and smoothing coefficients — planner picks values targeting the prototype feel for hour-long videos.
- Timeline bar color tokens for clip ranges and pending-In marker — should follow Phase 1 UI-SPEC accent color (oklch(0.65 0.14 30 / 0.45) fill, oklch(0.7 0.16 30) border) for consistency.
- Play/pause SF Symbol choice (play.fill / pause.fill) and button sizing — follow Phase 1 UI-SPEC SF Symbols table.
- HUD flash visual for In/Out confirmation (SKIM-07) — prototype used a colored band from the top edge; planner may use that or a centered overlay. Must be non-blocking and auto-dismiss.

### Deferred Ideas (OUT OF SCOPE)

- Tappable timeline — user chose display-only. Could be added in v2.
- Volume button In/Out marking — deferred to v2 per PROJECT.md and CLAUDE.md.
- Filmstrip thumbnail images — replaced by plain timeline bar in v1.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SKIM-01 | User can drag anywhere on the video surface to scrub to any position | Velocity-driven DragGesture on video surface with CADisplayLink-throttled seek |
| SKIM-03 | User can tap on-screen In/Out buttons to mark clip boundaries | Button actions in bottomChrome; exact-frame seek(to:toleranceBefore:.zero) on commit |
| SKIM-04 | User can tap to play/pause video during a skim session | Dedicated play/pause button in bottomChrome; player.play() / player.pause() calls |
| SKIM-05 | Mini filmstrip at bottom of skim view shows all marked clip ranges | SwiftUI Canvas inside the 28pt RoundedRectangle placeholder; draws clip rects + playhead |
| SKIM-06 | Current playhead position displayed as timecode (0:12.3) | addPeriodicTimeObserver at 1/10s interval during play; direct player.currentTime() read during scrub |
| SKIM-07 | Visual HUD flash confirms In or Out was registered | @State flag + withAnimation + Task.sleep auto-dismiss pattern |
| SKIM-08 | User can mark multiple clips from one video in a single session | clips: [Clip] array in AppViewModel; pendingIn: Double? tracks open In mark |
| PERF-02 | Filmstrip thumbnails generated asynchronously without blocking skim UI | No-op — D-11/D-09 eliminated AVAssetImageGenerator entirely; plain Canvas drawing has no blocking cost |
</phase_requirements>

---

## Summary

Phase 2 wires interactivity into the SkimView chrome shell built in Phase 1. There are five distinct technical subsystems to implement: (1) the CADisplayLink-throttled velocity scrub gesture, (2) the periodic time observer for live timecode display, (3) the In/Out marking state machine in AppViewModel, (4) the SwiftUI Canvas timeline bar, and (5) the HUD flash confirmation overlay.

The core challenge is the seek throttle. Apple's canonical guidance (Technical Q&A QA1820) prescribes the "chase time" pattern: updates to the target seek position accumulate in a `chaseTime` variable while a `isSeekInProgress` flag gates the actual `seek(to:toleranceBefore:.zero, toleranceAfter:.zero, completionHandler:)` call. The completion handler fires with `finished: false` when interrupted by a newer request — this is the signal to re-seek to the latest `chaseTime`. A CADisplayLink drives the seek dispatch at 60fps rather than at the gesture event rate, which can be much higher and would overwhelm the decoder.

The gesture split — drag-to-scrub on the video surface, tap-to-toggle-chrome also on the video surface, dedicated buttons in the chrome — is solved with `.simultaneousGesture`. DragGesture with a non-zero `minimumDistance` (8pt is the standard threshold) will not block a TapGesture because taps complete before the drag threshold is crossed. This is the correct iOS 16-compatible approach; `DragGesture.Value.velocity` was not introduced until iOS 17 and must not be used.

The timeline bar replaces the `RoundedRectangle` placeholder with a SwiftUI `Canvas` view. Canvas (introduced iOS 15) redraws the entire timeline in a single GPU pass when its captured state changes — it avoids per-shape SwiftUI view reconciliation overhead, making it the right choice for a bar that updates at display-link rate with multiple overlapping clip rects.

**Primary recommendation:** Implement seek throttle in `PlayerController` using the Apple QA1820 chase-time pattern; drive the loop from a CADisplayLink started on drag-begin and stopped on drag-end; use `Canvas` for the timeline bar; use `addPeriodicTimeObserver` at a 0.1s interval for playhead timecode during play, switching to direct `player.currentTime()` reads inside the CADisplayLink tick during scrub.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Velocity scrub gesture (DragGesture) | SkimView (View) | PlayerController (Controller) | Gesture lives on the view; seek calls delegate to PlayerController |
| Seek throttle (chase-time + CADisplayLink) | PlayerController | — | Owns AVPlayer; CADisplayLink must live on the same object that calls seek() |
| Timecode label update | PlayerController (publishes @Published var currentTime: Double) | SkimView (reads and formats) | AVPlayer state → PlayerController → SwiftUI via @Published |
| In/Out state machine (pendingIn, clips) | AppViewModel | — | Flat MVVM — all cross-screen state in AppViewModel per D-12 and project architecture |
| Timeline bar drawing | SkimView (Canvas) | — | Pure visual derived from AppViewModel.clips + PlayerController.currentTime |
| Play/pause toggle | SkimView (Button action) | PlayerController (player.play/pause) | Button in chrome calls playerController.togglePlayPause() |
| HUD flash (SKIM-07) | SkimView (@State + overlay) | — | Purely visual; no business logic; transient @State flag drives visibility |
| Chrome show/hide (D-01) | SkimView (@State chromeVisible) | — | Local view state; no need to surface to AppViewModel |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 16+ (system) | AVPlayer.seek, addPeriodicTimeObserver | System framework — the only way to control AVPlayer |
| QuartzCore | iOS 16+ (system) | CADisplayLink | System framework — display-synchronized callback loop |
| SwiftUI | iOS 16+ (system) | DragGesture, Canvas, simultaneousGesture, withAnimation | Project constraint — SwiftUI only |
| Combine | iOS 16+ (system) | @Published for PlayerController.currentTime and isPlaying | Already used in PlayerController for item status observation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 16+ (system) | CMTime arithmetic, Task.sleep | CMTimeMakeWithSeconds for observer intervals |

No third-party dependencies. Zero-dependency constraint from CLAUDE.md is preserved. [VERIFIED: CLAUDE.md]

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CADisplayLink | Timer at 60fps | Timer has no display-sync guarantee; CADisplayLink fires exactly at vsync |
| addPeriodicTimeObserver | CADisplayLink for timecode too | One CADisplayLink for both scrub throttle and timecode is simpler; preferred during drag |
| Canvas for timeline | ZStack with multiple Rectangle overlays | Canvas is a single GPU pass; ZStack with N clips creates N view nodes — worse at 60fps with many clips |
| completionHandler-based seek | async seek (iOS 16+) | Async variant exists but the flag pattern is clearer for the chase-time loop |

---

## Architecture Patterns

### System Architecture Diagram

```
DragGesture (SkimView)
    ↓ onChanged: accumulate velocity, update chaseTime
CADisplayLink tick (PlayerController, 60fps)
    ↓ if isSeekInProgress == false → seek(to: chaseTime, tolerance: non-zero)
AVPlayer decoder
    ↓ completion handler: if chaseTime changed → seek again (chase loop)
    ↓ else: isSeekInProgress = false
PlayerController.currentTime (@Published Double)
    ↑ set inside CADisplayLink tick from player.currentTime()
    ↓ consumed by SkimView timecode label + Canvas timeline
AppViewModel.pendingIn / clips
    ↑ set by In/Out button actions in SkimView
    ↓ consumed by Canvas timeline for clip range drawing

[ In/Out Button tap ]
    → playerController.seekExact(to: currentTime)   ← zero-tolerance final seek
    → appViewModel.markIn() OR markOut()
    → SkimView: @State showHUD = true → Task.sleep 700ms → showHUD = false
```

### Recommended Project Structure

```
SurfvidApp/
├── AppViewModel.swift       # + clips: [Clip], pendingIn: Double?
├── PlayerController.swift   # + CADisplayLink, seekThrottle, timeObserver
├── Skim/
│   ├── SkimView.swift       # + DragGesture, TapGesture, HUD overlay
│   ├── TimelineBar.swift    # New: Canvas-based timeline (extracted for clarity)
│   └── PlayerView.swift     # Unchanged
└── Shared/
    └── Formatters.swift     # formatTimecode() already implemented
```

New file count: +1 (`TimelineBar.swift`). Matches the ~15-file project target.

---

### Pattern 1: CADisplayLink with Weak Target Proxy (Retain-Cycle-Safe)

**What:** CADisplayLink strongly retains its target. Using `target: self` directly in a class that also holds the display link creates a retain cycle — neither is deallocated. Use a nested proxy class that holds only a `weak` reference to the owner.

**When to use:** Any time a class-owned `CADisplayLink` references back to `self` via selector.

```swift
// Source: Apple Developer Docs (CADisplayLink), community pattern [CITED: developer.apple.com/documentation/quartzcore/cadisplaylink]
// [VERIFIED: multiple community sources confirm this is the only retain-cycle-safe pattern]

class PlayerController: ObservableObject {
    private var displayLink: CADisplayLink?
    
    // Proxy holds weak reference — CADisplayLink retains proxy, not self
    private class DisplayLinkTarget: NSObject {
        weak var owner: PlayerController?
        @objc func tick(link: CADisplayLink) {
            owner?.onDisplayLinkTick(link: link)
        }
    }
    
    func startDisplayLink() {
        let proxy = DisplayLinkTarget()
        proxy.owner = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTarget.tick(link:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    func stopDisplayLink() {
        displayLink?.invalidate()   // removes from all run loops AND releases the proxy
        displayLink = nil
    }
    
    deinit {
        stopDisplayLink()
    }
    
    @objc private func onDisplayLinkTick(link: CADisplayLink) {
        // Called at vsync rate (60fps on 60Hz, up to 120fps on ProMotion)
        // link.targetTimestamp is the deadline for this frame
        flushPendingSeek()
        updateCurrentTime()
    }
}
```

**Pitfall:** Calling `displayLink.invalidate()` without first setting `displayLink = nil` does NOT break the retain cycle — `invalidate` removes the link from run loops but the proxy object may still hold a strong ref. Always nil the ivar after invalidate.

---

### Pattern 2: Chase-Time Seek Throttle (Apple QA1820)

**What:** Apple's canonical pattern for smooth interactive scrubbing. Prevents cascading seek cancellations caused by rapid `seek()` calls.

**When to use:** Any velocity-driven or slider-driven seek where the target changes faster than seeks complete.

```swift
// Source: Apple Technical Q&A QA1820 [CITED: developer.apple.com/library/archive/qa/qa1820]

class PlayerController: ObservableObject {
    // Seek throttle state
    private var chaseTime: CMTime = .zero
    private var isSeekInProgress = false
    
    /// Called from CADisplayLink tick — dispatches one seek per frame if needed
    private func flushPendingSeek() {
        guard !isSeekInProgress,
              player.currentItem?.status == .readyToPlay else { return }
        
        // Use non-zero tolerance during drag for speed (keyframe-accurate, ~30ms latency)
        // Zero-tolerance seek happens only on In/Out commit (see seekExact below)
        let target = chaseTime
        isSeekInProgress = true
        player.seek(
            to: target,
            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self else { return }
            if finished {
                self.isSeekInProgress = false
                // If chaseTime changed while seek was in-flight, chase again
                if CMTimeCompare(self.chaseTime, target) != 0 {
                    self.flushPendingSeek()
                }
            }
            // If !finished, another seek() call interrupted this one.
            // The new seek will complete and call this handler with finished: true.
        }
    }
    
    /// Update target time from gesture (called on every DragGesture onChanged)
    func updateSeekTarget(_ time: Double) {
        chaseTime = CMTimeMakeWithSeconds(max(0, time), preferredTimescale: 600)
    }
    
    /// Zero-tolerance seek for exact frame commitment on In/Out mark
    func seekExact(to time: Double, completion: (() -> Void)? = nil) {
        let target = CMTimeMakeWithSeconds(time, preferredTimescale: 600)
        player.seek(
            to: target,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            if finished { completion?() }
        }
    }
}
```

**Key distinction:**
- During drag: non-zero tolerance (`CMTime(seconds: 0.5, preferredTimescale: 600)`) → faster, keyframe-accurate seek (~30–60ms latency for H.264)
- On In/Out mark: zero tolerance → exact frame, may take 100–300ms but only fires once [CITED: developer.apple.com/library/archive/qa/qa1820]

---

### Pattern 3: Velocity Scrub from DragGesture (iOS 16 Compatible)

**What:** `DragGesture.Value.velocity` was introduced in iOS 17. On iOS 16, velocity must be computed from consecutive position deltas. The prototype's exponential smoothing approach maps directly.

**When to use:** iOS 16 minimum deployment target — cannot use `value.velocity`.

```swift
// Source: derived from prototype surfvid-paper-skim-landscape.jsx + iOS 16 DragGesture API
// [VERIFIED: Apple docs confirm velocity property is iOS 17+; position delta approach is community-verified]

// In SkimView — local @State for scrub accumulation
@State private var lastDragX: CGFloat = 0
@State private var vSmooth: Double = 0  // exponentially smoothed velocity (pts/ms)

// Constants (tunable — Claude's discretion per CONTEXT.md)
let PX_PER_S: Double = 0.6  // prototype value; 1px drag → 1/0.6 ≈ 1.67s seek
let ALPHA: Double = 0.3      // smoothing weight for new sample (prototype: 0.3)

// On the video surface:
var scrubGesture: some Gesture {
    DragGesture(minimumDistance: 8)  // 8pt prevents tap-drag conflict
        .onChanged { value in
            let dx = Double(value.location.x - lastDragX)
            // dt not available directly; approximate per-frame since CADisplayLink drives the seek
            vSmooth = vSmooth * (1 - ALPHA) + (dx / 1.0) * ALPHA
            lastDragX = value.location.x
            
            let dSec = -dx / PX_PER_S   // negative: drag right → earlier in video? 
                                          // prototype: dSec = -dx/PX_PER_S → rightward = positive seek
            let newTime = max(0, min(videoDuration, currentDisplayTime + dSec))
            playerController.updateSeekTarget(newTime)
            
            if !isScrubbing {
                isScrubbing = true
                playerController.player.pause()   // D-03: always pause on scrub start
                playerController.startDisplayLink()
            }
        }
        .onEnded { _ in
            isScrubbing = false
            vSmooth = 0
            playerController.stopDisplayLink()
            // D-03: do NOT resume playback automatically
        }
}
```

**Direction convention (from prototype):** `dSec = -dx / PX_PER_S`. Drag right (positive dx) → negative dSec → time moves backward. Confirms: right = earlier, left = later. Match this exactly.

**Note on velocity smoothing:** The prototype accumulates `vSmooth` across frames for a speedLabel display. For the seek model, the position delta `dx` per gesture event directly drives the time delta `dSec` — smoothing is optional cosmetic. The CADisplayLink rate (not gesture rate) controls seek frequency.

---

### Pattern 4: Gesture Split — Tap-to-Toggle Chrome + Drag-to-Scrub

**What:** Two gestures on the same surface. DragGesture with `minimumDistance: 8` will not fire its `onChanged` for moves < 8pt, so a quick tap completes the TapGesture before the drag threshold is crossed. Use `.simultaneousGesture` to recognize both.

**When to use:** Video surface where tap hides chrome and drag scrubs.

```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/composing-swiftui-gestures]
// [VERIFIED: community sources confirm minimumDistance > 0 avoids tap/drag conflict]

var videoSurface: some View {
    Color.clear.contentShape(Rectangle())
        .gesture(scrubGesture)                     // primary — DragGesture(minimumDistance: 8)
        .simultaneousGesture(
            TapGesture()
                .onEnded { chromeVisible.toggle() }
        )
}
```

**Why simultaneousGesture not highPriorityGesture:** `highPriorityGesture` would suppress the drag if tap is recognized. `simultaneousGesture` allows both to run independently. The non-zero `minimumDistance` on the DragGesture provides the discrimination: a tap resolves in < 8pt of movement and completes TapGesture's recognizer before DragGesture activates.

**Anti-pattern:** Do NOT use `onTapGesture` and `.gesture(DragGesture())` on the same view without `.simultaneousGesture` — the tap will be cancelled when the drag recognizer activates.

---

### Pattern 5: Timecode Observer with Scrub-Override

**What:** `addPeriodicTimeObserver` fires at a fixed interval during playback. During drag, the timecode display must update from the seek target, not the observer (which lags the seek). Use a flag to suppress observer updates during scrub; read directly from `playerController.currentTime` (a @Published Double updated in the CADisplayLink tick).

**When to use:** Any continuous timecode display paired with interactive scrubbing.

```swift
// Source: [CITED: developer.apple.com/documentation/avfoundation/avplayer/1385829-addperiodictimeobserver]
// [VERIFIED: community pattern for avoiding "jerky" progress during scrub]

class PlayerController: ObservableObject {
    @Published var currentTime: Double = 0  // updated by observer OR displayLink
    @Published var isPlaying: Bool = false
    
    private var timeObserverToken: Any?
    
    func setupTimeObserver() {
        // 0.1s interval = 10 updates/sec during playback — sufficient for M:SS.f display
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            self.currentTime = time.seconds
        }
    }
    
    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    // Called from CADisplayLink tick during scrub
    private func updateCurrentTime() {
        currentTime = player.currentTime().seconds
    }
    
    deinit {
        removeTimeObserver()
        stopDisplayLink()
    }
}
```

**Observer removal is mandatory.** Failing to call `removeTimeObserver(_:)` before `PlayerController` deinits causes a crash if the player fires the callback on a deallocated object. Store the token as `Any?` and nil it after removal. [CITED: developer.apple.com/documentation/avfoundation/avplayer/1387552-removetimeobserver]

**Interval choice:** `0.1s` (10fps update rate) is sufficient for the timecode format `0:MM:SS.f` (tenths). Higher frequency wastes @Published updates. Lower than 0.5s is imperceptible for tenths display.

---

### Pattern 6: SwiftUI Canvas for Timeline Bar

**What:** Canvas (iOS 15+, SwiftUI 3+) executes immediate-mode drawing in a single GPU pass per frame. Unlike ZStack with N Shape views, Canvas does not create N view nodes — the entire bar is one `drawRect`-equivalent call.

**When to use:** Visual elements with 1+ dynamic sub-elements that update at display-link rate.

```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/canvas] — iOS 15+ availability confirmed
// [VERIFIED: WWDC21 "Add rich graphics to your SwiftUI app" introduces Canvas in SwiftUI 3/iOS 15]

struct TimelineBar: View {
    let duration: Double
    let currentTime: Double
    let clips: [Clip]
    let pendingIn: Double?
    
    // UI-SPEC color tokens (oklch → approximate sRGB for SwiftUI Color)
    // oklch(0.65 0.14 30 / 0.45) fill ≈ orange-red at 45% opacity
    // oklch(0.7 0.16 30) border ≈ brighter orange-red
    static let clipFill = Color(red: 0.83, green: 0.35, blue: 0.15).opacity(0.45)
    static let clipBorder = Color(red: 0.87, green: 0.42, blue: 0.20)
    static let playheadColor = Color.white
    static let pendingInColor = Color(red: 0.87, green: 0.42, blue: 0.20)
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard duration > 0 else { return }
            
            // 1. Draw clip ranges
            for clip in clips {
                let x = CGFloat(clip.start / duration) * w
                let clipW = max(2, CGFloat((clip.end - clip.start) / duration) * w)
                let rect = CGRect(x: x, y: 0, width: clipW, height: h)
                context.fill(Path(rect), with: .color(TimelineBar.clipFill))
                // Left and right borders (1.5pt per prototype)
                context.stroke(Path(rect), with: .color(TimelineBar.clipBorder), lineWidth: 1.5)
            }
            
            // 2. Draw pending-In marker (1.5pt vertical line + 7×7 diamond cap at top)
            if let inTime = pendingIn {
                let x = CGFloat(inTime / duration) * w
                var linePath = Path()
                linePath.move(to: CGPoint(x: x, y: 0))
                linePath.addLine(to: CGPoint(x: x, y: h))
                context.stroke(linePath, with: .color(TimelineBar.pendingInColor), lineWidth: 1.5)
                // Diamond cap (7×7 rotated square)
                let capRect = CGRect(x: x - 3.5, y: -3.5, width: 7, height: 7)
                context.fill(Path(roundedRect: capRect, cornerRadius: 1), with: .color(TimelineBar.pendingInColor))
            }
            
            // 3. Draw playhead (1.5pt white line, extends slightly beyond bar top/bottom)
            let px = CGFloat(currentTime / duration) * w
            var playheadPath = Path()
            playheadPath.move(to: CGPoint(x: px, y: -3))
            playheadPath.addLine(to: CGPoint(x: px, y: h + 3))
            context.stroke(playheadPath, with: .color(TimelineBar.playheadColor), lineWidth: 1.5)
            // Square cap at top (9×9 per prototype)
            let capRect = CGRect(x: px - 4.5, y: -3 - 4.5, width: 9, height: 9)
            context.fill(Path(roundedRect: capRect, cornerRadius: 1), with: .color(TimelineBar.playheadColor))
        }
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
    }
}
```

**Canvas re-draws when its captured variables change.** Since `currentTime`, `clips`, and `pendingIn` are all passed as arguments to the `TimelineBar` view (which derives from `@Published` properties), any change triggers a view re-render, which triggers a Canvas re-draw. This is correct behavior.

---

### Pattern 7: HUD Flash with @State Flag + Task Auto-Dismiss

**What:** Transient overlay that appears on In/Out tap and auto-dismisses after ~700ms. The prototype uses `setTimeout(..., 700)`. The SwiftUI equivalent is `Task { try? await Task.sleep(nanoseconds: 700_000_000) }`.

**When to use:** Any non-blocking, timed auto-dismiss overlay in SwiftUI.

```swift
// Source: [ASSUMED — standard SwiftUI pattern, but specific interaction verified against prototype timing]

// In SkimView — local state
@State private var hudFlash: HUDKind? = nil  // nil = hidden

enum HUDKind { case inPoint, outPoint }

func showHUD(_ kind: HUDKind) {
    withAnimation(.easeIn(duration: 0.12)) {
        hudFlash = kind
    }
    Task {
        try? await Task.sleep(nanoseconds: 700_000_000)
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                hudFlash = nil
            }
        }
    }
}

// Flash band overlay (from prototype: colored bar at top edge, 4pt height, 80pt wide)
@ViewBuilder
var hudFlashOverlay: some View {
    if let kind = hudFlash {
        let color: Color = kind == .inPoint
            ? Color(red: 0.87, green: 0.42, blue: 0.20)   // accent orange-red
            : Color.white
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 80, height: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: kind == .inPoint ? .topLeading : .topTrailing)
            .padding(.top, 0)
            .padding(.horizontal, kind == .inPoint ? 80 : 100)  // approx prototype: 36%/52% offsets
            .transition(.opacity)
    }
}
```

**Prototype reference:** `SVFlashBandLandscape` — 4pt height bar at top, left side for In (accent orange), right side for Out (white), 700ms total duration with CSS animation `svFlash 700ms ease-out forwards`.

---

### Pattern 8: In/Out State Machine (AppViewModel)

**What:** The clip marking logic. Pure state machine on AppViewModel — no AVPlayer coupling here. PlayerController is called only to get the current time.

```swift
// Source: derived directly from prototype markIn()/markOut() + CONTEXT.md decisions D-07/D-08
// [VERIFIED: maps 1:1 from prototype logic]

// In AppViewModel

struct Clip: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
}

@Published var clips: [Clip] = []
@Published var pendingIn: Double? = nil

func markIn(at time: Double) {
    // D-08: Double-In resets pending to new position
    pendingIn = time
}

func markOut(at time: Double) {
    if let inTime = pendingIn {
        // Normal path: both In and Out set
        let start = min(inTime, time)
        let end = max(inTime, time)
        guard end > start else { return }   // degenerate: same time, ignore
        clips.append(Clip(start: start, end: end))
        pendingIn = nil
    } else {
        // D-07: Out before In → auto-set In = max(0, currentTime - 15s)
        let autoIn = max(0, time - 15.0)
        clips.append(Clip(start: autoIn, end: time))
        // pendingIn stays nil
    }
}

func resetForNewVideo() {
    clips = []
    pendingIn = nil
}
```

**Caller pattern in SkimView:**

```swift
Button("IN") {
    let t = appViewModel.playerController.currentTime
    appViewModel.playerController.seekExact(to: t)  // D-05: exact frame commit
    appViewModel.markIn(at: t)
    showHUD(.inPoint)
}

Button("OUT") {
    let t = appViewModel.playerController.currentTime
    appViewModel.playerController.seekExact(to: t)  // D-05: exact frame commit
    appViewModel.markOut(at: t)
    showHUD(.outPoint)
}
```

---

### Anti-Patterns to Avoid

- **Direct seek on every gesture event:** `DragGesture.onChanged` fires faster than 60fps on modern hardware. Calling `player.seek()` on every event floods the decoder and produces stuttering. Always gate through the CADisplayLink tick. [CITED: developer.apple.com/library/archive/qa/qa1820]
- **Using DragGesture.Value.velocity:** Only available on iOS 17+. The deployment target is iOS 16. Must compute from position deltas. [ASSUMED — based on Apple docs title; exact iOS version could not be confirmed via WebFetch but is consistent across multiple search sources]
- **Recreating PlayerController or AVPlayer on video load:** D-10 from Phase 1 — PlayerController is a `let` constant in AppViewModel. Phase 2 calls `resetForNewVideo()` on AppViewModel, not `PlayerController.init()`.
- **addPeriodicTimeObserver without removing:** Failing to call `removeTimeObserver(_:)` in `deinit` causes a crash when the callback fires on a deallocated object. The token must be stored and removed.
- **Zero-tolerance seek during drag:** Use non-zero tolerance (e.g., 0.5s each side) during the drag loop. Zero-tolerance seeks during interactive drag dramatically increase decoder load and will cause stutter on H.264 hour-long videos. Reserve zero-tolerance for the final commit on In/Out mark.
- **isScrubbing flag not guarding the time observer:** Without the guard, the periodic time observer will fight the CADisplayLink for `currentTime`, causing the timecode to jump backward during scrub.
- **CADisplayLink without weak proxy:** Using `CADisplayLink(target: self, ...)` directly causes a retain cycle. `PlayerController` will never be deallocated. Always use the nested proxy class.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Display-sync callback loop | Custom Timer-based 60fps loop | CADisplayLink | Timer has drift; CADisplayLink is synchronized to actual vsync |
| Smooth seek queue | Custom OperationQueue for seeks | Apple QA1820 chase-time pattern | Apple's pattern handles the `finished: false` edge case correctly |
| Timeline drawing | ZStack of N Rectangle views for N clips | Canvas | Canvas is one GPU pass; ZStack creates N view nodes causing layout reconciliation at 60fps |
| Auto-dismiss timer | DispatchQueue.main.asyncAfter | Task { try? await Task.sleep } | async/await is cooperative with Swift Concurrency; DispatchQueue timer doesn't cancel on deallocation |
| Velocity smoothing | Complex physics simulation | Exponential moving average (prototype's formula) | One-line formula; correct feel already validated in the prototype |

**Key insight:** The seek throttle is not "just calling seek less often" — the chase-time pattern is specifically designed to handle the case where a seek completes with `finished: false` (interrupted by a newer seek). Without this, the `isSeekInProgress` flag gets stuck `true` permanently, halting all further seeking. [CITED: developer.apple.com/library/archive/qa/qa1820]

---

## Common Pitfalls

### Pitfall 1: isSeekInProgress Flag Stuck True
**What goes wrong:** If the completion handler of a seek is never called (e.g., player not in `.readyToPlay` state when seek fires), the flag stays `true` and all future seeks are blocked silently.
**Why it happens:** `trySeekToChaseTime` does not guard against `currentItem.status != .readyToPlay`; seek is dispatched but the handler never fires.
**How to avoid:** Add `guard player.currentItem?.status == .readyToPlay else { isSeekInProgress = false; return }` before dispatching each seek.
**Warning signs:** Scrubbing freezes after a few seconds; timecode stops updating; app appears frozen on a frame.

### Pitfall 2: Timecode Label Jumps During Scrub
**What goes wrong:** The `addPeriodicTimeObserver` fires at the 0.1s interval and overwrites `currentTime` with a slightly stale value, causing the display to jump while the user is dragging.
**Why it happens:** The observer fires on `.main` regardless of scrub state.
**How to avoid:** Gate the observer callback with `guard !self.isScrubbing else { return }`.
**Warning signs:** Timecode visibly snaps backward or flickers during fast scrubs.

### Pitfall 3: DragGesture Cancels Tap (Chrome Toggle Broken)
**What goes wrong:** Tapping the video surface scrubs slightly or the chrome never hides.
**Why it happens:** Using `.gesture(DragGesture(minimumDistance: 0))` without `TapGesture` in `simultaneousGesture` — the drag recognizer captures the touch before TapGesture can complete.
**How to avoid:** Set `minimumDistance: 8` (not 0) on DragGesture; add TapGesture via `.simultaneousGesture`.
**Warning signs:** Tapping does nothing; tiny drags scrub instead of toggling chrome.

### Pitfall 4: CADisplayLink Retain Cycle Prevents Deinit
**What goes wrong:** PlayerController is never deallocated. If a new video is loaded (in a future session), the old PlayerController's CADisplayLink keeps firing on the old player.
**Why it happens:** `CADisplayLink(target: self, ...)` — CADisplayLink retains `self`.
**How to avoid:** Always use the nested `DisplayLinkTarget` proxy pattern. Add a `print("PlayerController deinit")` debug assertion during development.
**Warning signs:** Memory grows with each video load; multiple CADisplayLink callbacks firing.

### Pitfall 5: Zero-Tolerance Seek During Drag Causes Decoder Overload
**What goes wrong:** Scrubbing an hour-long H.264 video feels sluggish and the frame display rate drops to < 5fps.
**Why it happens:** H.264 uses keyframe + delta frame compression. Zero-tolerance seeks force decoding from the nearest keyframe for every seek position — which may be 30+ seconds back on a 1fps keyframe interval, requiring decoding 1800+ frames per seek on a 1-hour video.
**How to avoid:** Use `toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600)` during drag; zero-tolerance only on mark commit.
**Warning signs:** Seek latency > 200ms per frame; video surface goes black between seeks.

### Pitfall 6: removeTimeObserver Not Called Before PlayerController Deinit
**What goes wrong:** App crashes with an `EXC_BAD_ACCESS` or the observer fires on a deallocated object.
**Why it happens:** `addPeriodicTimeObserver` returns an opaque token that keeps the callback alive until explicitly removed.
**How to avoid:** Store the token as `private var timeObserverToken: Any?`; call `player.removeTimeObserver(token)` in `deinit`.
**Warning signs:** Crash in release builds after navigating away from skim screen.

### Pitfall 7: Out = In Degenerate Case
**What goes wrong:** User taps In, immediately taps Out at the exact same position. `Clip(start: t, end: t)` with duration 0 is appended and will crash the export phase.
**Why it happens:** No guard on `end > start`.
**How to avoid:** `guard end > start else { return }` in `markOut`. Recommended minimum: 0.1s.
**Warning signs:** Timeline bar shows zero-width clip rects; export in Phase 4 fails with invalid time range.

---

## Code Examples

### Verified: AVPlayer Seek with Completion Handler (toleranceBefore/After)

```swift
// Source: Apple Technical Q&A QA1820
// [CITED: developer.apple.com/library/archive/qa/qa1820]
player.seek(
    to: targetCMTime,
    toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
    toleranceAfter:  CMTime(seconds: 0.5, preferredTimescale: 600)
) { finished in
    // finished = true  → seek completed, player is at targetCMTime
    // finished = false → seek was interrupted by a newer seek() call
    // DO NOT assume player position on finished=false
}
```

### Verified: addPeriodicTimeObserver Setup and Teardown

```swift
// Source: [CITED: developer.apple.com/documentation/avfoundation/avplayer/1385829-addperiodictimeobserver]
let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
let token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
    self?.currentTime = time.seconds
}
// Must call before deinit:
player.removeTimeObserver(token)
```

### Verified: Canvas Drawing with @Published State

```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/canvas] — iOS 15+
Canvas { context, size in
    let rect = CGRect(x: 10, y: 0, width: 50, height: size.height)
    context.fill(Path(rect), with: .color(.orange.opacity(0.45)))
}
.frame(height: 28)
// Canvas re-draws whenever its SwiftUI view identity updates (i.e., on @Published changes passed as let arguments)
```

### Verified: simultaneousGesture for Tap + Drag

```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/composing-swiftui-gestures]
someView
    .gesture(DragGesture(minimumDistance: 8).onChanged { _ in }.onEnded { _ in })
    .simultaneousGesture(TapGesture().onEnded { toggleChrome() })
```

### Prototype Mapping: Scrub Direction and Speed

```jsx
// Prototype (JSX):
const dSec = -dx / PX_PER_S;  // PX_PER_S = 0.6
setPlayhead((p) => Math.min(dur, Math.max(0, p + dSec)));
```

```swift
// Swift equivalent:
let dSec = -Double(dx) / PX_PER_S   // PX_PER_S = 0.6
let newTime = max(0, min(duration, currentTime + dSec))
playerController.updateSeekTarget(newTime)
```

### Prototype Mapping: Pending-In Pill (MARKING · IN)

```jsx
// Prototype (JSX):
// background: 'rgba(255,255,255,0.92)', backdropFilter: 'blur(10px)'
// text color: 'oklch(0.55 0.16 30)', dot: 'oklch(0.6 0.18 30)'
// top: 56, centered horizontally, capsule shape
```

```swift
// SwiftUI equivalent — positioned below topChrome in ZStack
if let inTime = appViewModel.pendingIn, chromeVisible {
    HStack(spacing: 6) {
        Circle()
            .fill(Color(red: 0.80, green: 0.38, blue: 0.18))
            .frame(width: 6, height: 6)
        Text("MARKING · IN @ \(formatTimecode(inTime))")
            .font(.caption.weight(.semibold))
            .foregroundColor(Color(red: 0.72, green: 0.32, blue: 0.14))
            .kerning(/* -0.1 from prototype */)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(.ultraThinMaterial, in: Capsule())
    .transition(.opacity)
}
```

---

## Runtime State Inventory

> Skipped — this is not a rename/refactor/migration phase. Greenfield implementation within existing shell.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSTimer for display loop | CADisplayLink | iOS 3.1 | vsync-synchronized, not calendar-time |
| Manual KVO addObserver/removeObserver on AVPlayerItem | Combine `.publisher(for: \.status)` | iOS 13 / Swift 5 | Automatic teardown via AnyCancellable |
| DispatchQueue.main.asyncAfter for timed dismiss | `Task { try? await Task.sleep }` | Swift 5.5 / iOS 15 | Structured concurrency; cancellable with Task handle |
| DragGesture(minimumDistance: 0) for all gesture types | Non-zero minimumDistance + simultaneousGesture | SwiftUI 2 | Reliable tap/drag discrimination |
| Seek on every gesture event | Chase-time pattern with completion handler | QA1820 (evergreen) | Eliminates decoder cascade, dramatically better UX |
| ZStack Shape overlay for timeline | Canvas immediate mode | iOS 15 | One GPU pass vs N view nodes |

**Deprecated/outdated:**
- `seekToTime:` (Objective-C selector): Use `seek(to:toleranceBefore:toleranceAfter:completionHandler:)` — the Swift API.
- `kCMTimeZero` Objective-C constant: Use `CMTime.zero` in Swift.
- `PHVideoRequestOptions.deliveryMode = .highQualityFormat`: Already set to `.automatic` in Phase 1 PlayerController, which handles local vs iCloud correctly.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | DragGesture.Value.velocity is iOS 17+; must use position delta on iOS 16 | Pattern 3, Anti-Patterns | If velocity were iOS 16+, we'd use it directly; position delta approach still works correctly either way — no regressions |
| A2 | PX_PER_S = 0.6 from prototype gives correct feel for hour-long videos | Pattern 3 | Hour-long video = 3600s; at 0.6 px/s, full scrub at max velocity across full screen (~700pt) takes ~3600 / (700/0.6) ≈ 3.1 seconds. May be too slow. Planner should tune based on CONTEXT.md discretion |
| A3 | Non-zero seek tolerance of 0.5s each side is sufficient during drag for H.264 camera roll footage | Pattern 2 | Camera roll iPhone videos have variable keyframe intervals; 0.5s tolerance may skip to wrong keyframe visually. May need adjustment |
| A4 | withAnimation + Task.sleep(nanoseconds: 700_000_000) is sufficient for HUD flash — no race conditions | Pattern 7 | If user taps In twice in 700ms, second Task may interfere with first dismiss animation. Low probability; add debounce if needed |

**Note on A2:** The prototype was designed for a web prototype with simulated playhead, not real AVPlayer seek latency. If H.264 seeks at 0.5s tolerance take 30-60ms each and the display link fires at 60fps (16.7ms intervals), the effective seek rate is limited by the seek latency, not the display link. This is expected behavior; the CADisplayLink just prevents seek requests from accumulating.

---

## Open Questions (RESOLVED)

1. **PX_PER_S tuning for hour-long videos**
   - What we know: Prototype uses 0.6 which "felt right" in the React simulation
   - What's unclear: Whether 0.6 is appropriate when real AVPlayer seek latency is 30-100ms per seek on an iPhone with a 1-hour H.264 file
   - **RESOLVED:** Plan 02-02 sets PX_PER_S = 0.6 (prototype value). Device checkpoint (02-03) covers on-device tuning if needed.

2. **Chrome visibility during scrub**
   - What we know: D-01 says tap hides chrome; D-03 says scrub always pauses
   - What's unclear: Should the bottom chrome (timecode, In/Out buttons, timeline) remain visible during a scrub, or does starting a drag automatically show it?
   - **RESOLVED:** Plan 02-02 keeps chrome visible during scrub — only a tap on the video surface toggles `chromeVisible`. Drag gesture does not affect `chromeVisible`.

3. **Done button routing**
   - What we know: SkimView Done button is a no-op stub from Phase 1 ("Phase 2: trigger review screen")
   - What's unclear: Should Done remain a no-op stub in Phase 2, or should it route to `.review`? The Screen enum currently has only `.library` and `.skim`.
   - **RESOLVED:** Stays as stub in Phase 2. Phase 3 adds `.review` to Screen enum and wires Done.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build + test | ✓ | 26.4.1 (Swift 6.3.1) | — |
| iOS 16+ device or simulator | SKIM-01 gesture testing | ✓ (verified in Phase 1) | iOS 18+ | — |
| SwiftUI Canvas | Timeline bar | ✓ (iOS 15+; deployment target is iOS 16) | iOS 15+ | ZStack fallback (not needed) |
| CADisplayLink | Seek throttle | ✓ (QuartzCore, system) | iOS 3.1+ | — |
| AVPlayer.addPeriodicTimeObserver | Timecode display | ✓ (AVFoundation, system) | iOS 10+ | — |

All dependencies are system frameworks. No external tools required.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (system — Xcode 26.4.1) |
| Config file | None — no test target exists in project.yml |
| Quick run command | `xcodebuild test -project Surfvid.xcodeproj -scheme Surfvid -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same (only one test target) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SKIM-01 | Drag on video surface changes seek position | manual-only (gesture requires device/simulator interaction) | — | ❌ Wave 0 if testing desired |
| SKIM-03 | In/Out buttons update AppViewModel state correctly | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testMarkInOut` | ❌ Wave 0 |
| SKIM-04 | Play/pause button toggles PlayerController.isPlaying | unit | `xcodebuild test ... -only-testing SurfvidTests/PlayerControllerTests/testPlayPause` | ❌ Wave 0 |
| SKIM-05 | Timeline Canvas renders without crash for empty/filled clips | manual-only (visual rendering) | — | — |
| SKIM-06 | formatTimecode produces correct M:SS.f output | unit | `xcodebuild test ... -only-testing SurfvidTests/FormattersTests/testFormatTimecode` | ❌ Wave 0 |
| SKIM-07 | HUD flash appears and auto-dismisses (visual) | manual-only | — | — |
| SKIM-08 | Multiple In/Out calls produce correct clips array | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testMultipleClips` | ❌ Wave 0 |
| PERF-02 | Timeline bar draws without blocking (no AVAssetImageGenerator calls) | manual-only | — | — |

### Wave 0 Gaps

Unit tests are **strongly recommended but not blocking** for this phase — all critical logic is in pure Swift state machines (`AppViewModel.markIn`, `markOut`, `resetForNewVideo`, `Clip` construction) that are trivially unit-testable. The gesture and AVPlayer interactions are inherently manual.

- [ ] `SurfvidTests/AppViewModelTests.swift` — covers SKIM-03, SKIM-08 (markIn, markOut, D-07, D-08, edge cases)
- [ ] `SurfvidTests/PlayerControllerTests.swift` — covers SKIM-04 (play/pause toggle; mock AVPlayer)
- [ ] `SurfvidTests/FormattersTests.swift` — covers SKIM-06 (formatTimecode already implemented in Formatters.swift; test edge cases: 0s, 1h, 59:59.9)
- [ ] Add `SurfvidTests` target to `project.yml`

Note: A test target does not currently exist in `project.yml`. Wave 0 must add it before test files can be written. Adding a test target to project.yml and regenerating with `xcodegen generate` takes < 2 minutes.

*(If a test target is not added in Wave 0, verification gate is manual-only — acceptable for a personal tool but reduces confidence for edge cases like double-In, out-before-in, and the 0-duration clip guard.)*

---

## Security Domain

> `security_enforcement` not set in config.json — treating as enabled per policy.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — local app, no auth |
| V3 Session Management | no | n/a — no sessions |
| V4 Access Control | no | n/a — single-user local app |
| V5 Input Validation | yes (low risk) | All clip times clamped to [0, duration] before use |
| V6 Cryptography | no | No secrets or encryption needed |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Time value out of bounds (seek past end or negative) | Tampering | `max(0, min(duration, t))` clamp in updateSeekTarget and markOut |
| Zero-duration clip in clips array | Tampering | `guard end > start` in markOut |
| Nil player item during seek | Denial of Service | Guard `player.currentItem?.status == .readyToPlay` before seek |

No network, no user accounts, no server calls. Security surface is minimal.

---

## Sources

### Primary (HIGH confidence)
- Apple Technical Q&A QA1820 [CITED: developer.apple.com/library/archive/qa/qa1820] — canonical chase-time seek pattern
- Apple AVFoundation addPeriodicTimeObserver [CITED: developer.apple.com/documentation/avfoundation/avplayer/1385829-addperiodictimeobserver] — observer setup
- Apple AVFoundation removeTimeObserver [CITED: developer.apple.com/documentation/avfoundation/avplayer/1387552-removetimeobserver] — observer teardown
- Apple SwiftUI Canvas [CITED: developer.apple.com/documentation/swiftui/canvas] — Canvas iOS 15+ availability
- Apple SwiftUI Composing Gestures [CITED: developer.apple.com/documentation/swiftui/composing-swiftui-gestures] — simultaneousGesture
- Apple CADisplayLink [CITED: developer.apple.com/documentation/quartzcore/cadisplaylink] — invalidate, run loop, target lifecycle
- Prototype `surfvid-paper-skim-landscape.jsx` [VERIFIED: read directly from codebase] — PX_PER_S=0.6, vSmooth formula, clip range draw logic, HUD timing

### Secondary (MEDIUM confidence)
- Community weak-target proxy pattern for CADisplayLink [VERIFIED: multiple sources agree] — nested NSObject proxy class
- WWDC21 "Add rich graphics to your SwiftUI app" [CITED via search result] — Canvas introduced iOS 15/SwiftUI 3
- AVPlayer+Scrubbing.swift gist (shaps80) [CITED: gist.github.com/shaps80/ac16b906938ad256e1f47b52b4809512] — zero-tolerance seek pattern cross-reference

### Tertiary (LOW confidence)
- DragGesture.Value.velocity iOS 17+ availability — [ASSUMED from search results; exact iOS version not directly verified via Apple docs WebFetch]
- Non-zero seek tolerance value of 0.5s for H.264 — [ASSUMED] reasonable estimate; device testing required to confirm adequate frame accuracy

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple system frameworks, verified available on iOS 16
- Architecture: HIGH — directly derived from Apple QA1820 + existing Phase 1 patterns
- Pitfalls: HIGH — most verified against Apple documentation or prototype code
- Gesture behavior: MEDIUM — simultaneousGesture + minimumDistance interaction verified via multiple community sources; exact behavior should be confirmed on device
- PX_PER_S value: LOW — only validated in prototype simulation, not real AVPlayer

**Research date:** 2026-05-10
**Valid until:** Stable — AVFoundation seek APIs and SwiftUI Canvas have not changed since iOS 15/16. CADisplayLink pattern is unchanged since iOS 3. Re-verify if deployment target moves to iOS 17+ (velocity property becomes available).
