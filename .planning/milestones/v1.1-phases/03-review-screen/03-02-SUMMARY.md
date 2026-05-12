---
phase: 03
plan: 02
status: complete
completed: 2026-05-12
---

# Plan 03-02 Summary — ReviewView Clip List

## What Was Built

### Content layer structure
`ReviewView.swift` updated from 58 → 119 lines. The `Color.clear` placeholder in the ZStack content layer replaced with a conditional branch:
- `if appViewModel.clips.isEmpty → emptyState`
- `else → clipList`

Both branches padded with `.padding(.leading, 60).padding(.trailing, max(geometry.safeAreaInsets.trailing, 34))` to clear the Dynamic Island in landscape — a gap fix applied after initial verification revealed the List extended under the notch.

### Clip list (`clipList`)
`List { ForEach(appViewModel.clips) { clip in clipRow(clip) ... } }` with:
- `.listStyle(.plain)` + `.scrollContentBackground(.hidden)` — suppresses system List background
- `.listRowBackground(Color.clear)` per row — full dark theme (no visible cell fills)
- `.listRowSeparatorTint(Color.white.opacity(0.12))` per row
- `.padding(.top, 56)` — clears top chrome overlay height
- ForEach iterates by Identifiable UUID (no `id: \.self`; no `enumerated()`)

### Clip row (`clipRow`)
```
M:SS.t → M:SS.t   ← .body.monospacedDigit, .white
M:SS.t             ← .caption, Color.white.opacity(0.55)
```
`formatTimecode(clip.start)`, `formatTimecode(clip.end)`, `formatTimecode(clip.end - clip.start)` all called. `.contentShape(Rectangle())` for reliable hit testing. No tap gesture (D-07 read-only).

### Swipe-to-delete
`.swipeActions(edge: .trailing, allowsFullSwipe: true)` with `Button(role: .destructive)`. Deletion via `firstIndex(where: { $0.id == clip.id })` — safe for rapid back-to-back deletes (stale-index pitfall avoided). No DispatchQueue/Task wrap; removal is synchronous on MainActor.

### Empty state
VStack: thin `film` SF Symbol (48pt, .thin, white @ 30%) + "No clips marked" (.title2.semibold, white) + return prompt (.body, white @ 55%). Fills layer with `.frame(maxWidth: .infinity, maxHeight: .infinity)`.

## Bugs Fixed During Verification

**Dynamic Island overlap** — content layer lacked `.padding(.leading, 60)`. Fixed by applying the same landscape insets to the `clipList` and `emptyState` branches in the body.

**Scrub cursor jump to beginning** (Phase 2 regression diagnosed during this session) — `lastDragX` reset to 0 on drag end; first `onChanged` computed `dx = touch.x − 0`, seeking to position 0. Fixed in `SkimView.swift` by anchoring `lastDragX = value.location.x` on the first drag event and using `dx = 0`.

## Manual Verification
All 13 steps passed (approved 2026-05-12). REV-01, REV-02, REV-03 confirmed.
