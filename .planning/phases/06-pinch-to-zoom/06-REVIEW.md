---
phase: 06-pinch-to-zoom
reviewed: 2026-05-12T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - SurfvidApp/Skim/SkimView.swift
findings:
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-05-12
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Phase 6 adds pinch-to-zoom, drag-to-pan, double-tap reset, a zoom indicator overlay, and `onChange` reset on video change to `SkimView.swift`. The gesture routing logic for the scrub/pan split is sound in the normal case. Three critical issues were found: live `effectiveZoom` is unclamped during a pinch (visual overshoot below 1.0), `clampPan()` uses the deprecated and size-incorrect `UIScreen.main.bounds` instead of the view's own geometry, and a state-corruption scenario occurs when `zoom` is reset by a simultaneous gesture mid-drag. Four warnings cover pan not being clamped during live drag, `isScrubbing` state becoming orphaned on the zoom-changes-mid-drag path, incorrect gesture-tree commit behavior when pan and scrub both fire in `onEnded`, and the `onChange` deprecation on iOS 17+.

---

## Critical Issues

### CR-01: Live `effectiveZoom` is unclamped — video can visually shrink below 1.0 during a pinch

**File:** `SurfvidApp/Skim/SkimView.swift:25`

**Issue:** `effectiveZoom = zoom * pinchDelta`. The clamping to `[1, 4]` only happens in `pinchGesture.onEnded` after the gesture completes. During a live pinch, `pinchDelta` is the raw `MagnificationGesture` value, which freely passes values below 1.0. When `zoom = 1.0` and the user pinches in (scale < 1), `effectiveZoom` drops below 1.0, visibly shrinking the video to smaller than its natural frame — which is the opposite of the intended zoom behavior and appears broken. On release the value snaps back to 1.0, but the intermediate frames are wrong.

**Fix:** Clamp `effectiveZoom` at the computed property level:

```swift
private var effectiveZoom: CGFloat { max(1.0, min(4.0, zoom * pinchDelta)) }
```

---

### CR-02: `clampPan()` uses `UIScreen.main.bounds` instead of the view's geometry

**File:** `SurfvidApp/Skim/SkimView.swift:427–433`

**Issue:** `UIScreen.main` is deprecated as of iOS 16.0 and will produce compiler warnings on any deployment target that includes iOS 16. More critically, `UIScreen.main.bounds` returns the full screen dimensions, which are only equal to the view's actual bounds when the app runs full-screen on iPhone in portrait. Any rotation, split-view on iPad (even though this app is currently iPhone-only, the API contract is wrong), or future safe-area changes will cause `maxX` / `maxY` to be computed from the wrong rectangle. The correct size is already available from the `GeometryReader` in `body`.

`clampPan()` is a private method with no access to `geometry`, so it cannot receive the correct value. Two approaches exist:

**Fix option A (minimal) — store geometry size in a `@State` and update it:**

```swift
@State private var viewSize: CGSize = UIScreen.main.bounds.size  // fallback initial

// In body, inside GeometryReader:
.onAppear { viewSize = geometry.size }
.onChange(of: geometry.size) { viewSize = $1 }  // iOS 17+
// or .onChange(of: geometry.size) { _ in viewSize = geometry.size }  // iOS 16

private func clampPan() {
    let w = viewSize.width
    let h = viewSize.height
    let maxX = w * (zoom - 1) / 2
    let maxY = h * (zoom - 1) / 2
    committedPan.width  = min(maxX, max(-maxX, committedPan.width))
    committedPan.height = min(maxY, max(-maxY, committedPan.height))
}
```

**Fix option B (cleaner) — pass size into clampPan:**

```swift
private func clampPan(in size: CGSize) {
    let maxX = size.width  * (zoom - 1) / 2
    let maxY = size.height * (zoom - 1) / 2
    committedPan.width  = min(maxX, max(-maxX, committedPan.width))
    committedPan.height = min(maxY, max(-maxY, committedPan.height))
}
```

All three call sites (`pinchGesture.onEnded`, `scrubOrPanGesture.onEnded`) must pass the geometry size.

---

### CR-03: State corruption when `zoom` is reset to 1 mid-drag by a concurrent gesture

**File:** `SurfvidApp/Skim/SkimView.swift:296–344`

**Issue:** `scrubOrPanGesture.onChanged` and `.updating($livePanDelta)` both branch on `zoom > 1` as a live condition. If a two-finger pinch gesture completes (setting `zoom = 1.0`) while a drag is still in progress, the drag's `onChanged` transitions mid-gesture from the pan path (`zoom > 1` → skip) to the scrub path (`zoom <= 1` → run). At this exact moment:

1. `isScrubbing = false`, `lastDragX = 0` → `dx = 0` on the first event (correct anchoring).
2. `appViewModel.playerController.startDisplayLink()` is called from within an `onChanged` callback, which runs on the main thread during an ongoing gesture — fine by itself.
3. `onEnded` then runs. `isScrubbing = true`, so scrub cleanup runs (correct). But `zoom` may now equal 1 (or have been reset), so the pan commit branch (`if zoom > 1`) is skipped.

The larger problem is the reverse: a drag starts when `zoom > 1` (pan mode). The `livePanDelta` accumulates. If a double-tap fires simultaneously (`.simultaneousGesture`), `resetZoom()` sets `zoom = 1`. The drag's `onEnded` then executes `if zoom > 1` — which is now false — so `committedPan` is NOT updated and `clampPan()` is NOT called. However `livePanDelta` was accumulating a large translation that now won't be committed. `@GestureState` then resets `livePanDelta` to `.zero`, and the pan silently disappears. This gives the appearance that the pan was ignored. More dangerously, if `zoom` is 1 but `committedPan` is non-zero (because it was set before the double-tap but after a previous pan), the video stays offset with no visible zoom, which looks like a display glitch.

**Fix:** Capture the routing mode at gesture-start using a `@State` flag rather than checking `zoom` live:

```swift
@State private var dragIsInPanMode: Bool = false

// In .onChanged:
if !isScrubbing && !dragIsInPanMode {
    // First event: lock in mode based on current zoom
    if zoom > 1 {
        dragIsInPanMode = true
    } else {
        isScrubbing = true
        // ... existing scrub start-up
    }
}
if dragIsInPanMode { return }   // pan handled by .updating
// ... scrub logic

// In .onEnded:
if dragIsInPanMode {
    committedPan.width  += value.translation.width
    committedPan.height += value.translation.height
    clampPan()
    dragIsInPanMode = false
}
```

---

## Warnings

### WR-01: `livePanDelta` is not clamped — user can drag beyond visible bounds during active pan

**File:** `SurfvidApp/Skim/SkimView.swift:40–41`

**Issue:** The video's visual offset is `committedPan + livePanDelta`. `clampPan()` clamps only `committedPan`. During a live drag, `livePanDelta` can freely push the video beyond the maximum pan extent (the edge of the visible frame). The video snaps back within bounds when the finger lifts (`clampPan()` runs in `onEnded`), but the mid-gesture visual is wrong: the user can partially drag the video entirely off-screen.

**Fix:** Clamp the computed display offset rather than (or in addition to) the stored values. One approach is to expose a `clampedDisplayOffset` computed property used only by the `.offset()` modifier:

```swift
private func clampedOffset(in size: CGSize) -> CGSize {
    let raw = CGSize(width:  committedPan.width  + livePanDelta.width,
                     height: committedPan.height + livePanDelta.height)
    let maxX = size.width  * (effectiveZoom - 1) / 2
    let maxY = size.height * (effectiveZoom - 1) / 2
    return CGSize(width:  min(maxX, max(-maxX, raw.width)),
                  height: min(maxY, max(-maxY, raw.height)))
}

// In body, replace .offset(...) with:
.offset(clampedOffset(in: geometry.size))
```

---

### WR-02: `isScrubbing` and DisplayLink left running when gesture transitions from scrub to pan mode

**File:** `SurfvidApp/Skim/SkimView.swift:302–344`

**Issue:** If `zoom` becomes > 1 while a drag is in progress (unlikely but possible if another finger triggers a simultaneous pinch that commits before `onEnded`), the `onChanged` guard `zoom <= 1` starts returning early while `isScrubbing = true` and `displayLink` is running. The `onEnded` guard `if isScrubbing` would still fire and clean up in most scenarios, but if the system cancels the gesture (e.g., incoming call), the gesture sends a `.cancelled` state which SwiftUI routes only to `.updating` — NOT to `.onEnded`. The DisplayLink will be left running indefinitely and `playerController.isScrubbing` will remain `true`, freezing the time observer (which guards on `isScrubbing`). Result: timecode display stops updating after the call is dismissed until the next scrub gesture.

**Fix:** Add a `deinit`-safe or `onDisappear` cleanup path in `SkimView`, or ensure `appViewModel.playerController.stopDisplayLink()` and `isScrubbing = false` are called from a `.onDisappear` modifier on the view:

```swift
.onDisappear {
    if isScrubbing {
        isScrubbing = false
        appViewModel.playerController.isScrubbing = false
        appViewModel.playerController.stopDisplayLink()
    }
}
```

---

### WR-03: `onEnded` can commit pan offset even when the drag was used for scrubbing

**File:** `SurfvidApp/Skim/SkimView.swift:337–342`

**Issue:** In `scrubOrPanGesture.onEnded`, both the scrub cleanup branch (`if isScrubbing`) and the pan commit branch (`if zoom > 1`) are evaluated independently with no mutual exclusion. If `zoom` is set to > 1 between the time a scrub drag started and when it ends (again, via a simultaneous pinch completing during an active drag), `onEnded` will:
1. Clean up the scrub state correctly.
2. **Also** commit `value.translation.width/height` as a pan offset — which is the entire scrub delta (which can be hundreds of pixels wide) applied as a positional pan. This will teleport the video to an unexpected location.

**Fix:** Make the two branches mutually exclusive:

```swift
.onEnded { value in
    if isScrubbing {
        isScrubbing = false
        appViewModel.playerController.isScrubbing = false
        lastDragX = 0
        appViewModel.playerController.stopDisplayLink()
    } else if zoom > 1 {
        committedPan.width  += value.translation.width
        committedPan.height += value.translation.height
        clampPan()
    }
}
```

---

### WR-04: `.onChange(of:)` uses deprecated iOS 16 single-closure form

**File:** `SurfvidApp/Skim/SkimView.swift:135`

**Issue:** The form `.onChange(of: appViewModel.currentAsset) { _ in resetZoom() }` is the iOS 14/16 single-closure form, which was deprecated in iOS 17. The project targets iOS 16+, so this will compile without error but produces a deprecation warning in Xcode on any iOS 17+ SDK build. In practice this is harmless but will accumulate with other warnings over time.

**Fix:** Use the two-parameter form, which compiles cleanly on both iOS 16 and iOS 17+:

```swift
.onChange(of: appViewModel.currentAsset) { _, _ in resetZoom() }
```

Note: the two-parameter form `{ oldValue, newValue in }` is available from iOS 17; the `{ _, _ in }` syntax will require an availability check or adoption of the backward-compatible overload. Cleanest for iOS 16 compatibility:

```swift
// iOS 16-safe, no deprecation warning on 17+:
.onChange(of: appViewModel.currentAsset) { [self] _ in
    resetZoom()
}
// or keep the suppression pragma until minimum deployment moves to iOS 17
```

---

## Info

### IN-01: `%.2g` format specifier produces inconsistent decimal display for zoom label

**File:** `SurfvidApp/Skim/SkimView.swift:63`

**Issue:** `String(format: "%.2g×", effectiveZoom)` uses the `%g` format which suppresses trailing zeros and switches to scientific notation for large/small values. At `1.5` it displays "1.5×", at `2.0` it displays "2×" (not "2.0×"), at `3.14` it displays "3.1×". While this matches the intent of showing significant digits, the inconsistent number of decimal places (0 vs 1) can look visually unstable as the label width changes during a live pinch, potentially causing layout jitter in the overlay. A fixed format like `%.1f×` gives uniform width.

**Fix:**

```swift
Text(String(format: "%.1f×", effectiveZoom))
```

---

### IN-02: Zoom indicator `.transition(.opacity)` has no matching animation context

**File:** `SurfvidApp/Skim/SkimView.swift:73`

**Issue:** The zoom indicator uses `.transition(.opacity)` but the conditional `if effectiveZoom > 1.01 { ... }` is inside a `ZStack` with no explicit `withAnimation` controlling its insertion/removal. SwiftUI will animate the transition only if the surrounding context has an active animation. When `effectiveZoom` crosses 1.01 during a live pinch (driven by `@GestureState`), there is no animation context, so the indicator appears/disappears instantly despite the `.transition(.opacity)`. This is a cosmetic issue.

**Fix:** Wrap the condition in an explicit animation, or add `.animation(.easeOut(duration: 0.15), value: effectiveZoom > 1.01)` to the indicator view:

```swift
Text(String(format: "%.1f×", effectiveZoom))
    // ... existing modifiers
    .animation(.easeOut(duration: 0.15), value: effectiveZoom > 1.01)
    .transition(.opacity)
```

---

_Reviewed: 2026-05-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
