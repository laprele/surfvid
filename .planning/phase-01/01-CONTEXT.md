# Phase 1: App Shell & Video Browsing - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a working iOS app that: (1) requests Photos access and shows a scrollable list of camera roll videos with async thumbnails, (2) lets the user tap a video to enter a skim screen showing the video paused on the first frame with full chrome layout, and (3) lets the user return to the library. No scrubbing, no In/Out marking, no export — those are Phase 2+. Phase 1 is the complete entry path: Library → Skim shell → back to Library.

</domain>

<decisions>
## Implementation Decisions

### Project Scaffold
- **D-01:** Use XcodeGen (`project.yml` + `xcodegen generate`) — not Xcode GUI. Anti-pattern rules (#28) require this for iOS. XcodeGen is already installed.
- **D-02:** Swift source files live in `SurfvidApp/` at the repo root (separate from `Surfvid/` prototype). The `.xcodeproj` is generated from `project.yml` and should be gitignored.
- **D-03:** Bundle ID: `com.laprell.surfvid`. Signing: automatic (Xcode manages team from Apple ID). Deployment target: iOS 16.

### Orientation Lock
- **D-04:** Use `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` — the iOS 16+ imperative API. Called when `AppViewModel.screen` changes (Library → portrait, Skim → landscape).
- **D-05:** Info.plist (via `project.yml`) declares: Portrait + Landscape Left + Landscape Right. All three must be listed or `requestGeometryUpdate` will be silently ignored.

### Photos Data Layer
- **D-06:** On permission grant, run a `PHFetchRequest` sorted by `creationDate` descending and snapshot the result into `[PHAsset]` in `AppViewModel`. No `PHPhotoLibraryChangeObserver`, no foreground refresh — load once per session. This is sufficient for a personal tool.
- **D-07:** The `[PHAsset]` array and `PHAuthorizationStatus` live in `AppViewModel` (not a separate LibraryViewModel). Fetching is triggered from `AppViewModel` after authorization is granted.

### Skim Screen Scope in Phase 1
- **D-08:** Phase 1 delivers the **full chrome foundation** for the skim screen: AVPlayerLayer (full-bleed, landscape) + top overlay gradient (back-to-Library button, video title, Done pill) + bottom overlay gradient. The visual shell is complete so Phase 2 only needs to wire gestures and controls into the existing layout.
- **D-09:** When the user taps a video, `PlayerController` sets up `AVPlayer` with the asset's `PHAsset` URL and **pauses on the first frame** (does not autoplay). Play/pause is wired in Phase 2.
- **D-10:** `PlayerController` is created once in `AppViewModel` at init and reused across screen transitions (not created per-tap).

### Claude's Discretion
- File layout within `SurfvidApp/` (flat vs. grouped by layer) — planner may choose based on ~15-file target from PROJECT.md.
- Exact `project.yml` structure and build settings beyond bundle ID and deployment target.
- `PHImageManager` thumbnail request implementation details (size, delivery mode, cancellation bookkeeping) — follow UI-SPEC §LIB-01 and cancel by `requestID` when cell leaves screen.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Requirements
- `.planning/ROADMAP.md` — Phase 1 entry: goal, success criteria, requirements LIB-01, LIB-02, PERF-01
- `.planning/REQUIREMENTS.md` — Full requirement definitions for LIB-01, LIB-02, PERF-01

### Design Contract (Locked)
- `.planning/phase-01/01-UI-SPEC.md` — Approved design contract (2026-05-09). Defines: list layout, thumbnail behavior, permission flow UI, Library→Skim transition, color tokens, typography, spacing, copy, SF Symbols, and the skim screen chrome foundation layer. **This is the authoritative source for all visual and interaction decisions in Phase 1. Do not re-derive from the prototype.**

### Prototype Reference
- `Surfvid/surfvid-paper-library.jsx` — Library screen prototype (layout reference; not to be re-implemented, use UI-SPEC instead)
- `Surfvid/surfvid-paper-skim-landscape.jsx` — Skim screen prototype (layout reference for chrome positioning)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No existing Swift code — greenfield iOS app. Everything is new.

### Established Patterns (from prototype, map to Swift equivalents)
- **Screen state machine:** `SVApp` owns a `screen` enum (`'library' | 'skim' | ...`) and drives a conditional render. Maps directly to `AppViewModel.screen: Screen` enum driving a `ZStack` swap in SwiftUI.
- **Controlled screens:** Prototype screens receive all data and callbacks as props. Maps to SwiftUI screens receiving `AppViewModel` via `@EnvironmentObject`.
- **Time formatter (`svFmt`):** Formats seconds to `0:12.3` / `H:MM:SS.f`. Needs a Swift equivalent function — implement as a plain function in a utilities file.

### Integration Points
- `AppViewModel` is the single @StateObject root — all screens receive it via `@EnvironmentObject`. New code in Phase 1 plugs into it here.
- `PlayerController` is created in `AppViewModel.init()` and injected into the skim screen.
- Orientation lock fires on `AppViewModel.screen` change — the `.onChange` observer on the root ZStack view is the integration point.

</code_context>

<specifics>
## Specific Ideas

- **QuickTime-style scrubbing (Phase 2 spec, captured here):** The user explicitly wants velocity-driven scrubbing — identical to QuickTime Player on Mac with trackpad. Drag velocity maps to seek rate (positive or negative). Slow drag = near frame-by-frame; fast flick = large seek. Finger position on screen is irrelevant — only speed and direction matter. This is NOT position-mapped scrubbing. Phase 2 researcher must investigate AVFoundation seek throttling + velocity mapping for this exact model.

</specifics>

<deferred>
## Deferred Ideas

- **Velocity-driven scrubbing** — Phase 2, SKIM-01. QuickTime-style (see Specifics above). Not in Phase 1 scope.
- **Play/pause toggle** — Phase 2, SKIM-04. Phase 1 leaves player paused; Phase 2 wires the tap-to-play control.

</deferred>

---

*Phase: 1-App Shell & Video Browsing*
*Context gathered: 2026-05-09*
