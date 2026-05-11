# Phase 3: Review Screen - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning

<domain>
## Phase Boundary

User exits the skim session and enters a dedicated Review screen to view all marked clips with their timecode metadata, delete unwanted clips with a swipe gesture, and navigate back to continue skimming the same video without losing playback state or the clip list. Review is a committed checkpoint — clips cannot be added from Review; users must return to Skim to mark more.

No per-clip trim scrubbers in v1 (deferred to v2). No export or progress UI (Phase 4). Scope is the review list, deletion, and navigation only.

</domain>

<decisions>
## Implementation Decisions

### Review Screen Presentation
- **D-01:** Review screen uses **dark theme, landscape locked** — continues the video-editing mindset from Skim. Not a management screen like Library; user is still in the context of reviewing clips they just marked.
- **D-02:** Clip list is **text-only, simple rows** — no thumbnail images. Each row displays `[start → end] (duration)` timecode. Fast to render, aligns with the stripped-down design philosophy from Phase 2.

### Clip Deletion
- **D-03:** Delete interaction is **swipe-to-delete with immediate removal** — standard iOS pattern. No confirmation dialog, no undo toast. If regretted, user returns to Skim and re-marks the clip.

### Navigation Flow
- **D-04:** **Review is a committed checkpoint** — once the user reaches Review, they cannot add clips directly. If they want to mark additional clips, they must tap "Back to Skim", mark the new clips in the video, then tap Done again to return to Review. The new clips are appended to the list.
- **D-05:** Back button in Review **goes to Skim** (not Library). User returns to the same video, same playhead position, all previously marked clips intact. This preserves editing context for the current video session.

### Playback State Preservation
- **D-06:** When returning from Review to Skim, **video resumes at the exact playhead position** where the user tapped Done. PlayerController is kept alive across the transition (Phase 1 decision); playback time is preserved automatically.
- **D-07:** Clip rows in the review list are **read-only (not tappable)**. No tap-to-jump gesture. User navigates back to Skim and scrubs manually to preview or verify a clip.

### Screen Transition Mechanics
- **D-08:** **Screen enum is extended** to include `.review` case (in addition to `.library` and `.skim`). ContentView ZStack continues to swap screens via the enum.
- **D-09:** Orientation lock changes on Review entry: `AppDelegate.lockOrientation(.landscape)` (same as Skim). Review is not part of the portrait-landscape-portrait cycle; user must explicitly navigate back to Library to return to portrait.
- **D-10:** Done button in SkimView topChrome wires to `appViewModel.screen = .review`. Back button in ReviewView wires to `appViewModel.screen = .skim`.

### Claude's Discretion
- Exact clip row layout within the landscape frame (padding, alignment, safe-area insets — follow Phase 1 UI-SPEC spacing scale).
- Swipe-to-delete animation and delete button visual (red background is standard; Style per UI-SPEC dark theme color palette).
- ScrollView behavior if clip list exceeds landscape viewport height (e.g., sticky header with "Review" title, or inline scrolling).
- List container — `List` with `.swipeActions` modifier vs. custom VStack/ScrollView with manual swipe gesture detection. Either is acceptable; planner chooses based on Phase 1 patterns.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Requirements
- `.planning/ROADMAP.md` — Phase 3 entry: goal, success criteria, requirements REV-01, REV-02, REV-03
- `.planning/REQUIREMENTS.md` — Full requirement definitions for REV-01, REV-02, REV-03

### Design Contract (Locked)
- `.planning/phase-01/01-UI-SPEC.md` — Phase 1 design contract. Defines dark theme color tokens for landscape (used in Skim, now extended to Review), typography, spacing scale, SF Symbols, and padding rules. **Review screen uses the Skim dark theme section as the authoritative source.**

### Existing Implementation
- `SurfvidApp/AppViewModel.swift` — Owns `screen: Screen` enum (will add `.review` case), `clips: [Clip]`, `pendingIn: Double?`. Phase 3 adds no new state variables — clips list persists across screen transitions.
- `SurfvidApp/Skim/SkimView.swift` — Top chrome Done button (line 141) currently stubs "Phase 3: trigger review screen". Phase 3 wires this to `appViewModel.screen = .review`.
- `SurfvidApp/PlayerController.swift` — Persists across Review transition (Phase 1 decision D-10). No changes needed in Phase 3; playback time is preserved automatically.
- `SurfvidApp/ContentView.swift` — ZStack screen routing adds `.review` case. Orientation lock in `.onChange` handler adds `.review` → `.landscape`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Dark theme color tokens from Phase 1 UI-SPEC (Section "Skim screen dark theme") — apply same palette to Review background, text, and swipe-delete button.
- `formatTimecode(_:)` in `Formatters.swift` — wire to each clip row to display start/end times consistently.
- `AppDelegate.lockOrientation(_:)` pattern — already used in ContentView.onChange for Skim; reuse for Review in the `.review` case.

### Established Patterns
- **Flat MVVM:** Review state (clips list) is already in AppViewModel; no new ViewModel needed.
- **ZStack screen swap:** Review is another case in the Screen enum, consistent with Library and Skim.
- **@EnvironmentObject injection:** ReviewView receives `appViewModel` via `@EnvironmentObject`, same pattern as LibraryView and SkimView.
- **Orientation lock:** `.onChange(of: appViewModel.screen)` in ContentView already handles Library ↔ Skim transitions; Phase 3 adds the `.review` case which locks to landscape like Skim.

### Integration Points
- `SkimView` Done button (topChrome) → `appViewModel.screen = .review`
- `ReviewView` Back button → `appViewModel.screen = .skim`
- `ContentView.onChange` → add orientation lock rule for `.review` case
- Screen enum in `AppViewModel` → add `.review` case

</code_context>

<specifics>
## Specific Ideas

- **Swipe-to-delete pattern:** Swift's `List` with `.swipeActions(edge: .trailing) { ... }` modifier is the idiomatic way to implement this in SwiftUI. Planner should prefer this over custom gesture detection for consistency with iOS standard patterns.
- **Dark theme consistency:** Review background should match the full-bleed black + ultra-thin material overlays from Skim screen (UI-SPEC "Skim screen dark theme" section). Do not switch to the Library light theme.

</specifics>

<deferred>
## Deferred Ideas

- **Per-clip trim scrubbers in review** — v2 feature. User could fine-tune each clip's In/Out boundaries after marking, without returning to Skim. Deferred pending v1 validation of the basic review flow.
- **Clip preview on tap** — User could tap a clip row to scrub to that position and preview it in a modal or transition. Deferred; v1 is display-only for simplicity.
- **Reorder clips** — User could drag clips to reorder them before export. Deferred to v2.
- **Bulk delete** — Select multiple clips and delete together. Deferred to v2.

</deferred>

---

*Phase: 3-Review Screen*
*Context gathered: 2026-05-11*
