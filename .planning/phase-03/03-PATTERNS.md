# Phase 3: Review Screen - Pattern Map

**Mapped:** 2026-05-11
**Files analyzed:** 5 (1 new + 4 edited)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `SurfvidApp/Review/ReviewView.swift` | view | request-response (read + mutate) | `SurfvidApp/Skim/SkimView.swift` | role-match (same dark-theme landscape view with top chrome) |
| `SurfvidApp/AppViewModel.swift` | store/state | event-driven | `SurfvidApp/AppViewModel.swift` (itself, existing pattern) | exact (adding one enum case) |
| `SurfvidApp/ContentView.swift` | router | request-response | `SurfvidApp/ContentView.swift` (itself, existing pattern) | exact (extending existing switch) |
| `SurfvidApp/Skim/SkimView.swift` | view | request-response | `SurfvidApp/Skim/SkimView.swift` (itself, existing pattern) | exact (one-line stub wire-up at line 141) |
| `project.yml` | config | — | `project.yml` (itself) | exact — no change needed; `sources: path: SurfvidApp` picks up new subdirectory automatically |

---

## Pattern Assignments

### `SurfvidApp/Review/ReviewView.swift` (view, request-response + list mutation)

**Primary analog:** `SurfvidApp/Skim/SkimView.swift`
**Secondary analog:** `SurfvidApp/Library/LibraryView.swift` (List + .plain style pattern)

---

**Imports pattern** — copy from `SkimView.swift` lines 1–3:
```swift
import SwiftUI
import AVFoundation
```
ReviewView does not use AVFoundation directly (PlayerController is not touched). Drop `AVFoundation`:
```swift
import SwiftUI
```

---

**EnvironmentObject injection pattern** — copy from `SkimView.swift` line 5:
```swift
@EnvironmentObject var appViewModel: AppViewModel
```
This is the only property ReviewView needs — all state (`clips`, `screen`) lives in AppViewModel.

---

**ZStack dark-theme scaffold pattern** — copy from `SkimView.swift` lines 24–110:
```swift
var body: some View {
    GeometryReader { geometry in
        ZStack(alignment: .top) {
            // Layer 1: Full-bleed black background
            Color.black.ignoresSafeArea()

            // Layer 2: content (List in ReviewView, PlayerView in SkimView)
            ...

            // Layer 3: Chrome overlays — VStack pinned top
            VStack(spacing: 0) {
                topChrome
                Spacer()
            }
            .padding(.leading, 60)
            .padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))
        }
    }
    .background(Color.black)
    .ignoresSafeArea()
}
```
Key landscape inset values from `SkimView.swift` line 103: `.padding(.leading, 60)` (Dynamic Island clearance) and `.padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))` (home indicator).

---

**Top chrome pattern** — copy from `SkimView.swift` lines 116–158:
```swift
private var topChrome: some View {
    HStack(alignment: .center) {
        // Back button — chevron.left + label, regular weight
        Button(action: { appViewModel.screen = .library }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .regular))
                Text("Library")
                    .font(.body)
            }
            .foregroundColor(.white)
        }
        .accessibilityLabel("Back to Library")

        Spacer()

        Text("Video")
            .font(.body.weight(.medium))
            .foregroundColor(Color.white.opacity(0.9))
            .lineLimit(1)

        Spacer()

        Button("Done") { ... }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white)
            .foregroundColor(Color.black)
            .clipShape(Capsule())
    }
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .background(
        LinearGradient(
            colors: [Color.black.opacity(0.45), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
```
For ReviewView, substitute:
- Back button target: `appViewModel.screen = .skim` (not `.library`)
- Back button label: `"Skim"` (not `"Library"`)
- `.accessibilityLabel`: `"Back to Skim"`
- Title: `"Review"`
- Replace Done pill with `Color.clear.frame(width: 60, height: 1)` to balance the HStack

---

**List + dark theme pattern** — copy structural approach from `LibraryView.swift` lines 113–120, then apply dark-theme modifiers:
```swift
// LibraryView uses:
List(appViewModel.assets, id: \.localIdentifier) { asset in
    LibraryCell(asset: asset)
        .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
        .listRowSeparator(.hidden)
}
.listStyle(.plain)
```
For ReviewView, extend this with dark-theme modifiers (no analog in existing code — use RESEARCH.md pattern):
```swift
List {
    ForEach(appViewModel.clips) { clip in
        clipRow(clip)
            .listRowBackground(Color.clear)            // required — clears system cell bg
            .listRowSeparatorTint(Color.white.opacity(0.12))
    }
}
.scrollContentBackground(.hidden)   // iOS 16+ — suppresses List's system background
.listStyle(.plain)
.padding(.top, 56)                  // clear top chrome height
```
**Critical:** Both `.scrollContentBackground(.hidden)` AND `.listRowBackground(Color.clear)` are required for full dark theme. Either alone is insufficient (see RESEARCH.md Pitfall 1).

---

**Clip row pattern** — built from `formatTimecode` in `SurfvidApp/Shared/Formatters.swift` lines 23–35:
```swift
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
Row layout following SkimView timecode pattern (line 169, `.title2.monospacedDigit()`):
```swift
private func clipRow(_ clip: AppViewModel.Clip) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(formatTimecode(clip.start)) → \(formatTimecode(clip.end))")
                .font(.body.monospacedDigit())      // .monospacedDigit() prevents jitter
                .foregroundColor(.white)
            Text(formatTimecode(clip.end - clip.start))
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.55))
        }
        Spacer()
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
            if let index = appViewModel.clips.firstIndex(where: { $0.id == clip.id }) {
                appViewModel.clips.remove(at: index)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
```
**Note on deletion pattern:** Use `firstIndex(where: { $0.id == clip.id })` rather than captured `index` from `enumerated()`. This avoids the index-staleness pitfall (RESEARCH.md Pitfall 2) and is safe because `Clip.id` is a UUID (Identifiable — established in AppViewModel lines 13–17).

---

**Empty state pattern** — copy from `LibraryView.swift` lines 124–140:
```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Spacer()
        Image(systemName: "film")
            .font(.system(size: 48, weight: .thin))
            .foregroundColor(Color(.tertiaryLabel))
        Text("No videos found")
            ...
        Spacer()
    }
}
```
For ReviewView, adapt to dark theme — replace `Color(.tertiaryLabel)` with `Color.white.opacity(0.3)`, text `foregroundColor(.white)` / `Color.white.opacity(0.55)`. Trigger: `if appViewModel.clips.isEmpty { emptyState } else { List {...} }`.

---

### `SurfvidApp/AppViewModel.swift` (store/state, event-driven — enum extension)

**Analog:** `SurfvidApp/AppViewModel.swift` lines 5, 8 — existing Screen enum and screen property.

**Existing pattern** (`AppViewModel.swift` line 5):
```swift
enum Screen { case library, skim }
```

**Change:** Add `.review` case:
```swift
enum Screen { case library, skim, review }
```

No other changes to AppViewModel. The `clips: [Clip]` array (line 19) and `Clip` struct (lines 13–17) already carry all state ReviewView needs. No new `@Published` properties.

---

### `SurfvidApp/ContentView.swift` (router, request-response — ZStack extension)

**Analog:** `SurfvidApp/ContentView.swift` lines 7–25 — existing ZStack switch and onChange handler.

**Existing ZStack switch** (`ContentView.swift` lines 8–15):
```swift
switch appViewModel.screen {
case .library:
    LibraryView()
        .transition(.opacity)
case .skim:
    SkimView()
        .transition(.opacity)
}
```

**Existing onChange handler** (`ContentView.swift` lines 18–25):
```swift
.onChange(of: appViewModel.screen) { newScreen in
    switch newScreen {
    case .library:
        AppDelegate.lockOrientation(.portrait)
    case .skim:
        AppDelegate.lockOrientation(.landscape)
    }
}
```

**Changes:** Add `.review` case to both switches — copy the `.skim` pattern exactly:
```swift
// ZStack switch — add after .skim case:
case .review:
    ReviewView()
        .transition(.opacity)

// onChange switch — add after .skim case:
case .review:
    AppDelegate.lockOrientation(.landscape)   // D-09: same as .skim
```
Both switches are exhaustive enums — Swift will emit a compile error if `.review` is added to the enum but missing from a switch, providing a natural build-time check.

---

### `SurfvidApp/Skim/SkimView.swift` (view — one-line stub wire-up)

**Analog:** `SurfvidApp/Skim/SkimView.swift` line 119 — existing back-button pattern:
```swift
Button(action: { appViewModel.screen = .library }) {
```

**Existing stub** (`SkimView.swift` line 141):
```swift
Button("Done") { /* Phase 3: trigger review screen */ }
```

**Change:** Replace stub body with navigation assignment:
```swift
Button("Done") { appViewModel.screen = .review }
```
Optionally add `.disabled(appViewModel.clips.isEmpty)` to guard empty navigation (RESEARCH.md Open Question 2 recommendation):
```swift
Button("Done") { appViewModel.screen = .review }
    .disabled(appViewModel.clips.isEmpty)
```

---

### `project.yml` (config — no change needed)

**Analog:** `project.yml` lines 18–19:
```yaml
sources:
  - path: SurfvidApp
```
XcodeGen scans the `SurfvidApp/` directory tree recursively. Creating `SurfvidApp/Review/ReviewView.swift` in a new subdirectory is automatically picked up — no entry needed. **No edit required.**

---

## Shared Patterns

### Screen Navigation (all views)
**Source:** `SurfvidApp/AppViewModel.swift` line 8; `SurfvidApp/ContentView.swift` lines 8–25
**Apply to:** ReviewView (back button), SkimView (Done button wire-up)
```swift
// All screen transitions follow this one-liner pattern:
appViewModel.screen = .<targetCase>
```
No animation is applied at the call site — the `.animation(.easeOut(duration: 0.2), value: appViewModel.screen)` in ContentView line 17 handles all transitions globally.

### Orientation Lock
**Source:** `SurfvidApp/ContentView.swift` lines 18–25; `SurfvidApp/AppDelegate.swift`
**Apply to:** ContentView `.onChange` handler (add `.review` case)
```swift
.onChange(of: appViewModel.screen) { newScreen in
    switch newScreen {
    case .library: AppDelegate.lockOrientation(.portrait)
    case .skim:    AppDelegate.lockOrientation(.landscape)
    case .review:  AppDelegate.lockOrientation(.landscape)  // NEW
    }
}
```

### Dark Theme Color Palette
**Source:** `SurfvidApp/Skim/SkimView.swift` — used throughout
**Apply to:** ReviewView background, text, separators
```swift
// Background
Color.black.ignoresSafeArea()

// Primary text
.foregroundColor(.white)

// Secondary text / icons
.foregroundColor(Color.white.opacity(0.55))

// Separator tint
Color.white.opacity(0.12)

// Top chrome gradient
LinearGradient(
    colors: [Color.black.opacity(0.45), .clear],
    startPoint: .top,
    endPoint: .bottom
)
```

### EnvironmentObject Access
**Source:** `SurfvidApp/Skim/SkimView.swift` line 5; `SurfvidApp/Library/LibraryView.swift` line 5
**Apply to:** ReviewView
```swift
@EnvironmentObject var appViewModel: AppViewModel
```
No other property wrappers needed. ReviewView is purely read + simple mutation (`clips.remove`).

### formatTimecode Utility
**Source:** `SurfvidApp/Shared/Formatters.swift` lines 23–35
**Apply to:** ReviewView clip rows (start, end, and duration display)
```swift
// Top-level function — no import needed, available in all Swift files in the target
formatTimecode(clip.start)   // start time
formatTimecode(clip.end)     // end time
formatTimecode(clip.end - clip.start)  // duration
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `List` with dark theme + `.swipeActions` | view sub-pattern | CRUD | No existing list in the codebase uses `.swipeActions` or `.scrollContentBackground(.hidden)` — LibraryView's List is light-theme and tap-only. Use RESEARCH.md Pattern 1 + Pattern 2 code examples directly. |

---

## Metadata

**Analog search scope:** `SurfvidApp/` (all 11 Swift files)
**Files scanned:** 11
**Pattern extraction date:** 2026-05-11
**Key constraint:** iOS 16.0 deployment target — `.scrollContentBackground(.hidden)` is available (iOS 16.0+); `.swipeActions` is available (iOS 15.0+). No availability guards needed.
