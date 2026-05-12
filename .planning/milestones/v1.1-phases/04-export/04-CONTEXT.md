# Phase 4: Export - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Add Export capability to ReviewView: let the user export all marked clips as separate passthrough MP4 files to Camera Roll, with per-clip progress feedback shown as a progress bar per row, a full-screen "Done" screen with clip count that auto-returns to library, and a per-clip Share Sheet button that appears only after that clip has been exported.

No new video editing or clip adjustment. No concurrent exports. No export of individual clips selected by the user — always exports all clips.

</domain>

<decisions>
## Implementation Decisions

### Export Trigger & Layout
- **D-01:** Export button lives in `topChrome` of ReviewView — right side of the HStack, mirroring the "Skim" back button on the left. "Export All" action, no per-clip export buttons.
- **D-02:** While exporting: lock the clip list — disable swipe-to-delete and the Export button. A boolean `isExporting` flag on AppViewModel is sufficient; no mid-export mutation allowed.
- **D-03:** No separate export screen navigation during export — the user stays in ReviewView watching per-row progress.

### Progress Display
- **D-04:** Per-clip progress shown as a thin progress bar overlaid on or below each clip row, driven by `AVAssetExportSession.progress` polling.
- **D-05:** Exports run sequentially — one `AVAssetExportSession` at a time. Clips waiting their turn show 0% progress. This avoids AVFoundation concurrency limits and simplifies state management.

### Completion UX
- **D-06:** After all clips finish exporting: navigate to a full-screen "Done" screen (new `.done` case in the `Screen` enum). After approximately 2.5 seconds, auto-navigate to `.library` and reset clip state.
- **D-07:** Done screen content: large checkmark icon, "{N} clips exported" count, small "Returning to library…" hint. Dark-theme consistent with the rest of the app.

### Share Sheet
- **D-08:** Share button per clip row appears only after that clip's export has succeeded. It is not visible before export.
- **D-09:** Share action opens `UIActivityViewController` (wrapped as a SwiftUI sheet via `UIViewControllerRepresentable` or `sheet(isPresented:)`). The share payload is the exported file URL retrieved from Photos via `PHAsset` after export completes.

### Claude's Discretion
- How exactly to surface the Photos file URL after export (PHAsset request vs. capturing `AVAssetExportSession.outputURL`) — planner picks the most reliable pattern.
- Exact visual styling of the per-row progress bar (height, color, overlay vs. underline) — follow the existing dark-theme palette.
- Whether `ExportManager` is a standalone class or methods on `AppViewModel` — planner decides based on complexity.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Export (EXP-01 to EXP-04, PERF-03) — locked requirements for this phase
- `.planning/ROADMAP.md` §Phase 4 — success criteria and phase goal

### Existing Implementation
- `SurfvidApp/AppViewModel.swift` — `Screen` enum (needs `.done` case), `Clip` struct, `clips: [Clip]`, `playerController`; export state and export functions go here or in a new ExportManager
- `SurfvidApp/Review/ReviewView.swift` — existing ReviewView with `topChrome`, `clipList`, and `clipRow`; Export button and progress bars are added here
- `SurfvidApp/PlayerController.swift` — owns `AVPlayer`; export needs the underlying `AVAsset` from the loaded PHAsset

### Apple Framework Constraints
- **AVAssetExportPresetPassthrough** is locked (no re-encode) — CLAUDE.md and STATE.md
- **PHPhotoLibrary write access** — currently the app only requests read; export needs `NSPhotoLibraryAddUsageDescription` in Info.plist and `PHPhotoLibrary.shared().performChanges` to save the exported file
- No third-party dependencies — Apple frameworks only (AVFoundation, PhotosKit)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SurfvidApp/Shared/Formatters.swift` — `formatTimecode` used in `clipRow`; export completion message can reuse it
- `SurfvidApp/Review/ReviewView.swift:clipRow` — existing row layout; progress bar and share button slot in here
- `SurfvidApp/Review/ReviewView.swift:topChrome` — existing HStack with `Color.clear` trailing spacer; replace it with the Export button

### Established Patterns
- **ZStack + GeometryReader scaffold** — ReviewView uses it; Done screen should follow the same pattern
- **`Screen` enum + ZStack swap in ContentView** — adding `.done` case follows exactly the same pattern as `.review`; orientation lock for `.done` same as `.review` (landscape)
- **`@EnvironmentObject var appViewModel`** — all screens use this; export state (`isExporting`, per-clip progress, per-clip exported URL) lives on AppViewModel
- **`objectWillChange` forwarding** — if ExportManager is a separate class, it needs the same forwarding pattern as PlayerController

### Integration Points
- `AppViewModel.clips: [Clip]` — export iterates this array; `Clip` struct may need `exportProgress: Double` and `exportedURL: URL?` fields added
- `PlayerController` — needs to expose the `AVAsset` (or `AVURLAsset`) from the loaded PHAsset so ExportManager can create `AVAssetExportSession`
- `ContentView` — `.done` case routing and orientation lock must be added

</code_context>

<specifics>
## Specific Ideas

- Done screen mirrors the prototype's `SVDoneToast` concept: full-screen overlay, checkmark, clip count, auto-return after ~2.5s
- Share Sheet: standard iOS `UIActivityViewController` — no custom share destinations needed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 4-Export*
*Context gathered: 2026-05-12*
