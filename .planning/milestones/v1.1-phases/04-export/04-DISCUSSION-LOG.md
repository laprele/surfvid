# Phase 4: Export - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 4-Export
**Areas discussed:** Export trigger & layout, Progress display, Completion UX, Share Sheet timing

---

## Export Trigger & Layout

| Option | Description | Selected |
|--------|-------------|----------|
| "Export" in top chrome | Right-side of topChrome HStack, exports all clips at once | ✓ |
| Bottom action bar | Fixed bar pinned below the clip list | |
| Per-clip export buttons | Each row has its own Export button | |

**User's choice:** "Export" in top chrome

**Lock behavior during export:**

| Option | Description | Selected |
|--------|-------------|----------|
| Lock it — disable swipe-to-delete and Export button | `isExporting = true` disables all edit actions | ✓ |
| Allow deletion mid-export | Cancel in-flight AVAssetExportSession on clip delete | |
| Navigate away to a dedicated export screen | New ExportProgressView screen | |

**User's choice:** Lock the list — disable all edits while exporting

**Notes:** None

---

## Progress Display

| Option | Description | Selected |
|--------|-------------|----------|
| Progress bar per row | Thin bar overlaid on/below clip row, driven by AVAssetExportSession.progress | ✓ |
| Percentage text per row | Replace clip duration text with "Exporting… 47%" during export | |
| Full-screen export overlay | Modal overlay covers ReviewView showing all clips' progress | |

**User's choice:** Progress bar per row

**Concurrency:**

| Option | Description | Selected |
|--------|-------------|----------|
| Sequentially — one at a time | Simpler, avoids AVFoundation limits; waiting clips show 0% | ✓ |
| Concurrently — all at once | Faster total time but AVFoundation may serialize anyway | |

**User's choice:** Sequential

**Notes:** None

---

## Completion UX

| Option | Description | Selected |
|--------|-------------|----------|
| Full "Done" screen, then auto-return to library | Full-screen confirmation, ~2.5s delay, then navigate to .library | ✓ |
| Toast overlay on ReviewView | Temporary banner/sheet over ReviewView, user stays after | |
| iOS system alert | UIKit-style alert with OK button | |

**User's choice:** Full Done screen with auto-return

**Done screen content:**

| Option | Description | Selected |
|--------|-------------|----------|
| Checkmark + clip count + auto-return countdown | Large checkmark, "3 clips exported", "Returning to library…" hint | ✓ |
| Checkmark + simple message | Just checkmark and "Export complete" | |
| Let Claude decide | Claude picks layout at plan time | |

**User's choice:** Checkmark + clip count + auto-return countdown

**Notes:** Mirrors the prototype's SVDoneToast concept

---

## Share Sheet Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Only after that clip has been exported | Share button appears per row only after export succeeds; shares exported file URL | ✓ |
| Always visible — shares the source video range | Two different share payloads depending on export state | |
| On the Done screen only | Share only available after all clips export; no per-clip share | |

**User's choice:** Only after that clip has been exported

**Share payload:**

| Option | Description | Selected |
|--------|-------------|----------|
| Share the exported file URL from Photos | Use PHAsset to get URL of new clip in Camera Roll; pass to UIActivityViewController | ✓ |
| Share a temporary file URL | Write clip to temp directory; share that URL | |
| Let Claude decide | Claude picks approach at plan time | |

**User's choice:** Share the exported file URL from Photos (via PHAsset after export)

**Notes:** None

---

## Claude's Discretion

- How to surface the Photos file URL after export (PHAsset request vs. `AVAssetExportSession.outputURL`)
- Exact visual styling of per-row progress bar (height, color, overlay vs. underline)
- Whether `ExportManager` is a standalone class or methods on `AppViewModel`

## Deferred Ideas

None — discussion stayed within phase scope.
