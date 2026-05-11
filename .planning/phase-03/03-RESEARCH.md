# Phase 3: Review Screen — Research

**Researched:** 2026-05-11
**Domain:** SwiftUI List with swipe-to-delete, dark-theme List styling, screen enum extension, ZStack screen routing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Review screen uses dark theme, landscape locked — continues the video-editing mindset from Skim.
- **D-02:** Clip list is text-only, simple rows — no thumbnail images. Each row displays `[start → end] (duration)` timecode.
- **D-03:** Delete interaction is swipe-to-delete with immediate removal — standard iOS pattern. No confirmation dialog, no undo toast.
- **D-04:** Review is a committed checkpoint — once the user reaches Review, they cannot add clips directly. Back to Skim is the only path to mark more clips.
- **D-05:** Back button in Review goes to Skim (not Library). User returns to same video, same playhead position, all previously marked clips intact.
- **D-06:** When returning from Review to Skim, video resumes at the exact playhead position where the user tapped Done. PlayerController is kept alive; playback time is preserved automatically.
- **D-07:** Clip rows in the review list are read-only (not tappable). No tap-to-jump gesture.
- **D-08:** Screen enum is extended to include `.review` case. ContentView ZStack continues to swap screens via the enum.
- **D-09:** Orientation lock for `.review` matches Skim (`.landscape`). `AppDelegate.lockOrientation(.landscape)` called on `.review` case in ContentView.onChange.
- **D-10:** Done button in SkimView topChrome wires to `appViewModel.screen = .review`. Back button in ReviewView wires to `appViewModel.screen = .skim`.

### Claude's Discretion

- Exact clip row layout within the landscape frame (padding, alignment, safe-area insets — follow Phase 1 UI-SPEC spacing scale).
- Swipe-to-delete animation and delete button visual (red background is standard; Style per UI-SPEC dark theme color palette).
- ScrollView behavior if clip list exceeds landscape viewport height (e.g., sticky header with "Review" title, or inline scrolling).
- List container — `List` with `.swipeActions` modifier vs. custom VStack/ScrollView with manual swipe gesture detection. Either is acceptable; planner chooses based on Phase 1 patterns.

### Deferred Ideas (OUT OF SCOPE)

- Per-clip trim scrubbers in review — v2 feature.
- Clip preview on tap — v1 is display-only.
- Reorder clips — deferred to v2.
- Bulk delete — deferred to v2.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REV-01 | User can see all marked clips listed with start/end times and duration | SwiftUI `List` + `ForEach` over `appViewModel.clips`; `formatTimecode` already in Formatters.swift; duration computed inline as `clip.end - clip.start` |
| REV-02 | User can delete a clip before exporting | `.swipeActions(edge: .trailing)` on each ForEach row with `Button(role: .destructive)`; action calls `appViewModel.clips.remove(at:)` |
| REV-03 | User can return to skimming to add more clips from the same video | Back button in ReviewView top chrome sets `appViewModel.screen = .skim`; PlayerController survives the transition; playhead position preserved automatically |
</phase_requirements>

---

## Summary

Phase 3 is deliberately narrow: a single new SwiftUI view (`ReviewView`) wired into the existing ZStack routing system. The existing infrastructure — `AppViewModel.clips`, `PlayerController`, `AppDelegate.lockOrientation`, `formatTimecode`, and the `Screen` enum — already handles 90% of the requirements. The implementation is three targeted changes plus one new file.

**Change 1 (AppViewModel.swift):** Add `.review` case to the `Screen` enum. No new state variables needed; `clips` already persists across screen transitions.

**Change 2 (ContentView.swift):** Add `.review` branch to the ZStack switch and the `.onChange` orientation lock handler (locks to `.landscape`, same as `.skim`).

**Change 3 (SkimView.swift):** Wire the Done button stub at line 141 to `appViewModel.screen = .review`.

**New file (ReviewView.swift):** A SwiftUI `List` that iterates `appViewModel.clips`, displays each clip as a text row in `[start → end] (duration)` format using `formatTimecode`, and exposes swipe-to-delete via `.swipeActions(edge: .trailing)`. Dark theme is achieved with `.scrollContentBackground(.hidden)` plus `Color.black.ignoresSafeArea()` behind the List (same pattern as SkimView), `.listRowBackground(Color.clear)` per row, and `.foregroundColor(.white)` for text. A top chrome area mirrors SkimView's gradient pattern with a "Back to Skim" button.

**Primary recommendation:** Use `List` + `.swipeActions(edge: .trailing)` + `Button(role: .destructive)`. This is the idiomatic SwiftUI pattern confirmed in CONTEXT.md. The `.scrollContentBackground(.hidden)` modifier (iOS 16+) is the correct mechanism for full dark-background List styling; it is available at the iOS 16.0 deployment target. [VERIFIED: developer.apple.com/documentation/swiftui/view/scrollcontentbackground]

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Clip list display (REV-01) | ReviewView (View) | AppViewModel (data source) | Pure read — renders `appViewModel.clips` as text rows |
| Swipe-to-delete (REV-02) | ReviewView (View action) | AppViewModel (mutation) | Gesture lives in the view; `clips.remove(at:)` is a simple array mutation on the ViewModel |
| Clip deletion persistence | AppViewModel (`@Published var clips`) | — | Already owns clips; removal is in-place array mutation, no separate persistence layer |
| Navigation back to Skim (REV-03) | ReviewView (Button action) | AppViewModel (screen enum) | Same pattern as all screen transitions in this app |
| Playback state preservation (D-06) | PlayerController (survives in AppViewModel) | — | PlayerController is a `let` constant in AppViewModel — it is never deallocated during screen swaps |
| Orientation lock | ContentView (onChange handler) | AppDelegate (lockOrientation) | Existing pattern; add `.review` case mirroring `.skim` |
| Dark theme | ReviewView + Color.black | — | `.scrollContentBackground(.hidden)` removes system List background; app applies its own Color.black backdrop |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 16+ (system) | `List`, `ForEach`, `.swipeActions`, `@EnvironmentObject` | Project constraint — SwiftUI only; all Phase 1–2 views use this |
| Foundation | iOS 16+ (system) | String formatting (timecode display) | `formatTimecode` already in Formatters.swift |

No new dependencies. Zero-dependency constraint from CLAUDE.md is preserved. [VERIFIED: CLAUDE.md]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `.scrollContentBackground(.hidden)` | iOS 16.0+ | Suppress default List white/gray system background | Required for dark-theme List; available at deployment target |
| SwiftUI `.listRowBackground(Color.clear)` | iOS 13+ | Make individual rows transparent (shows Color.black beneath) | Apply per row to achieve full dark theme |
| `Color(.systemRed)` | iOS 16+ (system) | Destructive action tint for swipe delete button | UI-SPEC Phase 1 declares this for destructive actions (Phase 3 is first use) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `List` + `.swipeActions` | Custom VStack/ScrollView + DragGesture for swipe | List is idiomatic, handles accessibility, cell reuse, and scroll bounce automatically. Custom swipe gesture is ~60 lines of geometry math for no benefit. CONTEXT.md prefers List. |
| `Button(role: .destructive)` | `.tint(Color(.systemRed))` on a regular Button | `role: .destructive` automatically applies the system red tint AND communicates intent to assistive technologies — prefer it. |

**Installation:** No new packages. All SwiftUI APIs are system-provided.

---

## Architecture Patterns

### System Architecture Diagram

```
[SkimView — Done button tap]
    ↓ appViewModel.screen = .review
ContentView ZStack
    ↓ switches to ReviewView
    ↓ ContentView.onChange triggers AppDelegate.lockOrientation(.landscape)

ReviewView
    ├── reads appViewModel.clips ([@Published [Clip]])
    ├── renders List { ForEach(clips) { clip → ClipRow } }
    │       └── .swipeActions(edge: .trailing) {
    │               Button(role: .destructive) { clips.remove(at: index) }
    │           }
    └── top chrome: Back button → appViewModel.screen = .skim

[ReviewView — Back button tap]
    ↓ appViewModel.screen = .skim
ContentView ZStack
    ↓ switches to SkimView
    ↓ ContentView.onChange triggers AppDelegate.lockOrientation(.landscape)
    ↓ PlayerController (unchanged) resumes at preserved currentTime
```

### Recommended Project Structure

```
SurfvidApp/
├── AppViewModel.swift        # + .review case in Screen enum
├── ContentView.swift         # + .review branch in ZStack + onChange
├── Skim/
│   └── SkimView.swift        # Done button stub wired to .review
└── Review/
    └── ReviewView.swift      # NEW: List + swipeActions + top chrome
```

New file count: +1 (`ReviewView.swift`). All existing files receive small, targeted edits. Total Swift file count goes from 11 to 12, well within the ~15-file target from CLAUDE.md.

### Pattern 1: SwiftUI List with .swipeActions (Idiomatic Delete)

**What:** `List { ForEach(binding) { ... }.swipeActions(edge: .trailing) { Button(role: .destructive) } }` is the current SwiftUI idiom for swipe-to-delete. The system handles animation, the red background, and full-swipe acceleration.

**When to use:** Any list that requires trailing-edge swipe delete with immediate removal.

```swift
// Source: developer.apple.com/documentation/swiftui/view/swipeactions
// [VERIFIED: Context7 /websites/developer_apple_swiftui]

List {
    ForEach(Array(appViewModel.clips.enumerated()), id: \.element.id) { index, clip in
        ClipRowView(clip: clip)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    appViewModel.clips.remove(at: index)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}
```

**Key API facts** [VERIFIED: Context7]:
- `edge:` defaults to `.trailing` — trailing swipe is standard for delete.
- `allowsFullSwipe: true` (default) — full right-to-left swipe fires the first action automatically. This is the correct behavior for D-03 (immediate removal).
- `Button(role: .destructive)` automatically applies `Color(.systemRed)` tint, no `.tint` modifier needed.
- Available iOS 15+. [VERIFIED: developer.apple.com/documentation/swiftui/view/swipeactions — iOS 15.0+]

**Important:** `.swipeActions` requires the row to be inside a `List`. It does NOT work on `ScrollView` + `LazyVStack` — swipe gesture conflicts. [ASSUMED based on SwiftUI documentation structure, but consistent with expected behavior]

### Pattern 2: Dark-Theme List (Black Background)

**What:** SwiftUI `List` renders with a system background color by default (white/grouped gray). To override this for the Skim dark theme, two modifiers are required: `.scrollContentBackground(.hidden)` on the `List` to suppress the system background, and `.listRowBackground(Color.clear)` on each row to make rows transparent. The `Color.black.ignoresSafeArea()` in the ZStack underneath provides the actual dark background.

**When to use:** Any SwiftUI `List` that needs a non-system (dark) background. Required for ReviewView's dark theme (D-01).

```swift
// Source: developer.apple.com/documentation/swiftui/view/scrollcontentbackground
// [VERIFIED: Context7 /websites/developer_apple_swiftui — iOS 16.0+]

ZStack {
    Color.black.ignoresSafeArea()  // dark backdrop

    List {
        ForEach(...) { item in
            Text(item.label)
                .foregroundColor(.white)
                .listRowBackground(Color.clear)          // row is transparent
                .listRowSeparatorTint(Color.white.opacity(0.12))  // subtle separator
        }
    }
    .scrollContentBackground(.hidden)  // suppress system List background
    .listStyle(.plain)                 // consistent with Phase 1 LibraryView (.plain)
}
```

**Critical detail:** `.scrollContentBackground(.hidden)` alone is not enough — without `.listRowBackground(Color.clear)`, each individual row still renders its own system-colored cell background on top of the black backdrop.

**Availability:** `.scrollContentBackground(_:)` is iOS 16.0+. [VERIFIED: Context7 — "iOS 16.0+"] The deployment target is iOS 16.0. No availability guard needed.

### Pattern 3: Screen Enum Extension and ContentView Routing

**What:** The existing `Screen` enum in `AppViewModel.swift` needs a `.review` case. ContentView's ZStack switch and `.onChange` orientation handler need matching branches. This is an exact repeat of the pattern established for `.skim`.

**When to use:** Adding any new screen to the app.

```swift
// Source: existing code — AppViewModel.swift line 5, ContentView.swift lines 8–26
// [VERIFIED: read directly from codebase]

// AppViewModel.swift — line 5
enum Screen { case library, skim, review }   // ADD: review

// ContentView.swift — ZStack switch (add review branch)
switch appViewModel.screen {
case .library:
    LibraryView().transition(.opacity)
case .skim:
    SkimView().transition(.opacity)
case .review:
    ReviewView().transition(.opacity)          // NEW
}

// ContentView.swift — onChange orientation lock (add review case)
.onChange(of: appViewModel.screen) { newScreen in
    switch newScreen {
    case .library:
        AppDelegate.lockOrientation(.portrait)
    case .skim:
        AppDelegate.lockOrientation(.landscape)
    case .review:
        AppDelegate.lockOrientation(.landscape)  // NEW — D-09: same as .skim
    }
}
```

### Pattern 4: Clip Row Text Formatting

**What:** Each clip row displays the clip's start time, end time, and duration using `formatTimecode` from Formatters.swift. Duration is computed as `clip.end - clip.start` and formatted with `formatTimecode`. The row format from D-02 is: `[start → end] (duration)`.

**When to use:** Anywhere clip metadata is displayed.

```swift
// Source: Formatters.swift lines 23–35 + CONTEXT.md D-02
// [VERIFIED: read directly from codebase]

// Clip row content — all formatting via formatTimecode (top-level function)
HStack {
    Text("\(formatTimecode(clip.start)) → \(formatTimecode(clip.end))")
        .font(.body.monospacedDigit())
        .foregroundColor(.white)
    Spacer()
    Text("(\(formatTimecode(clip.end - clip.start)))")
        .font(.caption)
        .foregroundColor(Color.white.opacity(0.55))
}
.padding(.vertical, 8)    // UI-SPEC sm (8pt) vertical intra-row spacing
```

**Note on monospaced digits:** Using `.monospacedDigit()` on the timecode text prevents the row width from jittering as digits change. Consistent with Phase 1 UI-SPEC which uses `.title2.monospacedDigit()` for the skim timecode.

### Pattern 5: Top Chrome on ReviewView

**What:** ReviewView needs a top chrome area consistent with SkimView — same dark gradient, same back-button SF Symbol and styling, "Review" title centered, no Done button (replaced by nothing — user navigates back via Back button only).

**When to use:** ReviewView header.

```swift
// Source: SkimView.swift lines 116–158 (topChrome pattern)
// [VERIFIED: read directly from codebase]

// Top chrome — mirrors SkimView.topChrome structure
private var topChrome: some View {
    HStack(alignment: .center) {
        // Back to Skim — D-10, D-05
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

        // Spacer placeholder to balance the HStack (no Done button in ReviewView)
        Color.clear.frame(width: 60, height: 1)  // approximate Done pill width
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

**Insets:** ReviewView uses the same landscape insets as SkimView — `.padding(.leading, 60)` for Dynamic Island clearance and `.padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))` for the home indicator. Apply these to the top chrome's enclosing HStack or the outer VStack. [VERIFIED: UI-SPEC "Skim screen insets" section]

### Anti-Patterns to Avoid

- **Using `.onDelete` instead of `.swipeActions`:** `.onDelete` is the older ForEach modifier. It generates an "Edit" mode delete with red circles — not a swipe gesture. Use `.swipeActions` for iOS-standard swipe-to-delete. [VERIFIED: SwiftUI docs distinguish the two APIs]
- **Putting `List` inside a `ScrollView`:** `List` is already scrollable. Nesting it causes scroll conflict and is unsupported in SwiftUI.
- **Applying `.swipeActions` to the `List` instead of the row:** `.swipeActions` is a row-level modifier applied to the content inside `ForEach`, not to the `List` or `ForEach` itself.
- **Forgetting `.listRowBackground(Color.clear)`:** Without this, each row renders a white/gray system cell background over the black backdrop, breaking the dark theme even when `.scrollContentBackground(.hidden)` is applied to the List.
- **Using `@State var clips` in ReviewView:** Never copy `appViewModel.clips` into local `@State`. The list must bind directly to `appViewModel.clips` so deletions are reflected in AppViewModel and persist when navigating back to Skim. Use `ForEach(Array(appViewModel.clips.enumerated()), ...)` for index-based removal or pass a `Binding` to the clips array.
- **Disabling `.allowsFullSwipe`:** D-03 specifies immediate removal; full-swipe-to-delete is the correct affordance for "immediate, no undo". Leave `allowsFullSwipe: true` (the default).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swipe-to-delete gesture | Custom DragGesture on each row detecting rightward swipe, revealing a red button | `.swipeActions(edge: .trailing)` | System handles animation, accessibility, rubber-banding, full-swipe commit, and cancel-on-upward-swipe — all for free |
| Dark background for List | UIViewRepresentable wrapping UITableView with custom background | `.scrollContentBackground(.hidden)` + `.listRowBackground(Color.clear)` | Two-line solution; available at iOS 16 deployment target |
| Row deletion animation | Manual `withAnimation { clips.remove(at:) }` wrapping + offset transition | SwiftUI automatically animates the deletion when bound through `ForEach` with `id:` | ForEach removal animation is built into SwiftUI List |

**Key insight:** `List` + `.swipeActions` handles all delete-related complexity (animation, accessibility labels, full-swipe semantics) in approximately 10 lines. Custom gesture detection for this problem would require 60+ lines, a gesture state machine, and would break VoiceOver out of the box.

---

## Runtime State Inventory

> Skipped — this is not a rename/refactor/migration phase. New UI screen added on top of existing state.

---

## Common Pitfalls

### Pitfall 1: List Row Background Not Cleared (Dark Theme Breaks)
**What goes wrong:** Review screen shows white or gray cells against a black background — partial dark theme where the list background is suppressed but individual cells are still light.
**Why it happens:** `.scrollContentBackground(.hidden)` hides the scroll view's background, but each `List` row independently renders a `UITableViewCell`-style background. Without `.listRowBackground(Color.clear)`, rows stay opaque.
**How to avoid:** Apply `.listRowBackground(Color.clear)` to every row inside `ForEach`. Pair with `.scrollContentBackground(.hidden)` on the `List`.
**Warning signs:** List background is dark but each row has a lighter rectangle.

### Pitfall 2: Deletion Mutates Wrong Index After Animation
**What goes wrong:** User swipes to delete clip at index 2; clip at index 3 disappears instead (or a crash: "Index out of range").
**Why it happens:** Using captured `index` from `enumerated()` inside an async closure after the array has already been modified by a prior deletion.
**How to avoid:** Perform deletion synchronously inside the button action. Do not use `DispatchQueue.async` or `Task {}` for the removal. Since all state is on the main actor (`@Published` on `AppViewModel`), the removal and SwiftUI re-render are synchronous: `appViewModel.clips.remove(at: index)`.
**Warning signs:** Sporadic wrong-clip deletion or out-of-bounds crash after rapid successive swipes.

### Pitfall 3: Done Button Stub Not Wired (SkimView Line 141)
**What goes wrong:** Tapping Done on SkimView does nothing — navigation to ReviewView never happens.
**Why it happens:** SkimView line 141 contains `Button("Done") { /* Phase 3: trigger review screen */ }` — the comment confirms it is a stub. This file edit is Phase 3 task 1, not automatic.
**How to avoid:** Include the SkimView Done button wire-up (`appViewModel.screen = .review`) as an explicit task step. This is the primary integration point for REV-03 (return path) and REV-01 (entering review).
**Warning signs:** Running the app and tapping Done shows nothing; screen stays on Skim.

### Pitfall 4: Orientation Stays Landscape on Back Navigation to Skim
**What goes wrong:** User navigates back from Review to Skim; orientation is still landscape (correct), but if `.review` case is missing from ContentView's `.onChange` handler, the system will not re-confirm the landscape lock after a Review → Skim transition in an edge case.
**Why it happens:** ContentView's `.onChange` fires on every `screen` change. If the `.review` case is omitted, Swift's exhaustive switch would fail to compile — but if handled with a combined `case .skim, .review:` or missing altogether, the orientation lock may not fire correctly.
**How to avoid:** Add `.review` as its own explicit case in the switch, setting `.landscape` — identical to `.skim`. The `AppDelegate.lockOrientation` call is idempotent (safe to call even if already in landscape).
**Warning signs:** On Review → Skim, the app briefly allows portrait rotation before locking landscape again.

### Pitfall 5: Empty Clip List Edge Case
**What goes wrong:** User reaches Review with zero clips (possible if they tapped Done without marking anything, or deleted all clips). ReviewView shows an empty list with no visual guidance.
**Why it happens:** No empty-state handling in the list.
**How to avoid:** Add a conditional: if `appViewModel.clips.isEmpty`, show a centered message ("No clips marked yet") with a subtitle prompting the user to go back to Skim. This is a UX completeness requirement for a graceful empty state.
**Warning signs:** Blank black screen when no clips are present; user has no indication of what to do.

### Pitfall 6: `ForEach` Without Stable IDs Breaks Deletion Animation
**What goes wrong:** Deletion animation plays but the wrong row disappears visually before SwiftUI reconciles (flicker).
**Why it happens:** If `ForEach` is keyed on index (not ID), SwiftUI re-uses view identities incorrectly during animation.
**How to avoid:** Use `ForEach(appViewModel.clips)` — `Clip` already conforms to `Identifiable` (UUID-based `id` from Phase 2). Never use `ForEach(0..<clips.count, id: \.self)` for deletion-capable lists.
**Warning signs:** Visual glitch on delete where adjacent rows appear to jump.

---

## Code Examples

### Full ReviewView Skeleton

```swift
// Source: derived from CONTEXT.md decisions + SwiftUI docs
// Patterns: List dark theme [VERIFIED: Context7], swipeActions [VERIFIED: Context7],
//           topChrome [VERIFIED: SkimView.swift lines 116-158]

import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Layer 1: Full-bleed black background (D-01 dark theme)
                Color.black.ignoresSafeArea()

                // Layer 2: Clip list
                List {
                    ForEach(appViewModel.clips) { clip in
                        clipRow(clip)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.12))
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .padding(.top, 56)  // clear top chrome height

                // Layer 3: Top chrome overlay
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
        .contentShape(Rectangle())  // tappable area for swipe target
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

            // Balance HStack — no Done button in ReviewView
            Color.clear.frame(width: 60, height: 1)
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
}
```

### Screen Enum Extension (AppViewModel.swift line 5)

```swift
// Source: existing AppViewModel.swift line 5 + CONTEXT.md D-08
// [VERIFIED: read directly from codebase]

// BEFORE:
enum Screen { case library, skim }

// AFTER:
enum Screen { case library, skim, review }
```

### ContentView ZStack + Orientation (ContentView.swift)

```swift
// Source: existing ContentView.swift + CONTEXT.md D-08, D-09
// [VERIFIED: read directly from codebase]

// ZStack switch — add .review case
switch appViewModel.screen {
case .library:
    LibraryView().transition(.opacity)
case .skim:
    SkimView().transition(.opacity)
case .review:
    ReviewView().transition(.opacity)    // NEW
}

// onChange orientation lock — add .review case
case .review:
    AppDelegate.lockOrientation(.landscape)  // NEW — D-09
```

### SkimView Done Button Wire-Up (SkimView.swift line 141)

```swift
// Source: SkimView.swift line 141 — existing stub
// [VERIFIED: read directly from codebase]

// BEFORE (stub):
Button("Done") { /* Phase 3: trigger review screen */ }

// AFTER:
Button("Done") { appViewModel.screen = .review }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.onDelete(perform:)` on ForEach | `.swipeActions(edge:allowsFullSwipe:content:)` | iOS 15 | swipeActions gives full control over button label, tint, and full-swipe behavior; onDelete is limited to a default "Delete" label |
| Manual `UITableView.backgroundColor = .black` in UIViewRepresentable | `.scrollContentBackground(.hidden)` | iOS 16 | Pure SwiftUI — no UIKit needed |
| `List` row backgrounds via `UIAppearance` hacks | `.listRowBackground(Color.clear)` | iOS 14 | Declarative per-row background override |

**Deprecated/outdated for this phase:**
- `onDelete(perform:)`: Still works but is limited. Produces an Edit-mode delete behavior (red circles), not a swipe gesture. Not appropriate here.
- Manual UITableViewCell background clearing via `UIAppearance`: Not needed given `.listRowBackground` and `.scrollContentBackground`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.swipeActions` requires the row to be inside a `List` — does not work in `ScrollView` + `LazyVStack` | Pattern 1, Anti-Patterns | Low risk: CONTEXT.md already prefers `List`; investigation is not needed unless ScrollView approach is chosen |
| A2 | Empty-state handling (Pitfall 5) is needed for the case where user reaches Review with no clips | Pitfall 5 | If empty state is not handled, the app shows a blank black screen — not a crash but a poor UX. Low risk of being wrong; defensive pattern is cheap to add |

**Both claims have low consequence if incorrect. No user confirmation needed before planning.**

---

## Open Questions

1. **Clip count badge in SkimView top chrome**
   - What we know: SkimView currently shows "N marked" in the bottom chrome (line 181). There is no Done button badge.
   - What's unclear: Should the Done button show a clip count badge (e.g., "Done (3)")? CONTEXT.md does not address this; it is Claude's discretion.
   - Recommendation: Keep the Done button as a plain pill ("Done") — it matches Phase 1 UI-SPEC and the existing stub. Clip count is already visible in the bottom chrome as "N marked". No change needed.

2. **Empty clip list when navigating to Review**
   - What we know: A user could tap Done with zero clips marked (or delete all clips in Review).
   - What's unclear: Should Done be disabled when `clips.isEmpty`? Or should ReviewView handle the empty state gracefully?
   - Recommendation: Disable Done when `clips.isEmpty` (`.disabled(appViewModel.clips.isEmpty)` modifier on the button) AND show an empty state in ReviewView. Belt-and-suspenders — disabling is the simpler guard, empty state is the defensive fallback.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build | ✓ | 26.4.1 (Swift 6.3.1) | — |
| iOS 16+ simulator or device | ReviewView test | ✓ (verified Phase 1 + 2) | iOS 18+ | — |
| SwiftUI `.scrollContentBackground(.hidden)` | Dark-theme List | ✓ (iOS 16.0+ — matches deployment target) | iOS 16.0+ | — |
| SwiftUI `.swipeActions` | REV-02 delete | ✓ (iOS 15.0+ — below deployment target) | iOS 15.0+ | — |

All dependencies are system frameworks. No new tools or packages.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (system — Xcode 26.4.1) |
| Config file | No test target in project.yml (Wave 0 gap from Phase 2 — still unresolved) |
| Quick run command | `xcodebuild test -project /Users/alexanderlaprell/repos/surfvid/Surfvid.xcodeproj -scheme Surfvid -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same (only one test target) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REV-01 | All clips display with correct start/end/duration formatting | unit | `xcodebuild test ... -only-testing SurfvidTests/ReviewViewModelTests/testClipRowFormatting` | ❌ Wave 0 |
| REV-02 | Deleting a clip removes it from appViewModel.clips | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testClipDeletion` | ❌ Wave 0 |
| REV-03 | Setting screen = .skim with non-empty clips preserves clips array | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testClipsPersistedOnScreenTransition` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Build check only (no test target exists yet)
- **Per wave merge:** Manual device/simulator smoke test: enter Review, verify list, swipe-delete, return to Skim
- **Phase gate:** All three success criteria from ROADMAP.md verified on device before `/gsd-verify-work`

### Wave 0 Gaps

The test target was identified as a gap in Phase 2 research but was not created. Phase 3 has pure-Swift logic in AppViewModel (clip deletion, screen transition) that is trivially unit-testable. Planner should decide whether to create the test target in Wave 0 of this phase.

- [ ] `SurfvidTests/AppViewModelTests.swift` — covers REV-02 (`clips.remove(at:)` after swipe) and REV-03 (clips array survives `.skim` → `.review` → `.skim` transitions)
- [ ] `SurfvidTests/FormattersTests.swift` — covers REV-01 (`formatTimecode` for duration display; edge case: sub-second clip)
- [ ] Add `SurfvidTests` target to `project.yml` if not yet done

If the test target is still not added in Wave 0 of Phase 3, verification gate is manual-only (acceptable given the simplicity of this phase's logic).

---

## Security Domain

> `security_enforcement` not set in config.json — treating as enabled per policy.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — local app, no auth |
| V3 Session Management | no | n/a — no sessions |
| V4 Access Control | no | n/a — single-user local app |
| V5 Input Validation | yes (low risk) | Clip start/end times already clamped in Phase 2 via `max(0, min(duration, t))`; no new user-entered data in Phase 3 |
| V6 Cryptography | no | No secrets or encryption needed |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Index-out-of-bounds on concurrent deletion | Tampering | Deletion is synchronous on MainActor; SwiftUI `List` serializes user gestures; no concurrent deletion possible in single-user local app |
| Negative duration clip displayed (end < start) | Tampering | Phase 2 `markOut` has `guard end > start` — zero/negative-duration clips cannot exist in the array |

No network, no user accounts, no server calls. Security surface for Phase 3 is minimal.

---

## Sources

### Primary (HIGH confidence)
- `/websites/developer_apple_swiftui` via Context7 — `.swipeActions(edge:allowsFullSwipe:content:)` API, `Button(role: .destructive)`, `.scrollContentBackground(.hidden)`, `.listRowBackground` [VERIFIED]
- `SurfvidApp/AppViewModel.swift` — Screen enum, clips array, Clip struct [VERIFIED: read from codebase]
- `SurfvidApp/ContentView.swift` — ZStack routing, onChange orientation lock pattern [VERIFIED: read from codebase]
- `SurfvidApp/Skim/SkimView.swift` — Done button stub (line 141), topChrome pattern [VERIFIED: read from codebase]
- `SurfvidApp/Shared/Formatters.swift` — formatTimecode implementation [VERIFIED: read from codebase]
- `.planning/phase-01/01-UI-SPEC.md` — Dark theme color tokens, spacing scale, SF Symbols, landscape insets [VERIFIED: read from file]
- `CLAUDE.md` — Zero-dependency constraint, iOS 16+ SwiftUI-only constraint [VERIFIED: read from file]

### Secondary (MEDIUM confidence)
- `.planning/phase-02/02-RESEARCH.md` — Established patterns from Phase 2 that ReviewView inherits [VERIFIED: read from file]
- Apple SwiftUI documentation (via Context7) — `.listStyle(.plain)`, `.listRowSeparatorTint`, ForEach with Identifiable [VERIFIED]

### Tertiary (LOW confidence)
- `.swipeActions` not working inside `ScrollView` + `LazyVStack` — inferred from SwiftUI documentation structure; not explicitly tested [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple system frameworks, verified at iOS 16.0 deployment target
- Architecture: HIGH — directly derived from existing Phase 1/2 patterns with minimal extension
- Pitfalls: HIGH — most verified by reading existing codebase and confirmed SwiftUI dark-theme List patterns
- `.swipeActions` behavior: HIGH — API verified via Context7 against Apple documentation
- Empty-state recommendation: MEDIUM — reasonable defensive design, not explicitly required by CONTEXT.md

**Research date:** 2026-05-11
**Valid until:** Stable — SwiftUI List APIs and `.scrollContentBackground` have not changed since iOS 16. Re-verify only if deployment target moves below iOS 16 (which contradicts CLAUDE.md).
