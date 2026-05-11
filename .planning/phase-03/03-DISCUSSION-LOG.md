# Phase 3 Discussion Log

**Date:** 2026-05-11  
**Facilitator:** Claude  
**Phase:** 3 — Review Screen

---

## Gray Areas Discussed

### 1. Review List Layout

**Options Presented:**
- A: Simple rows (timecode only) — text-based, fast
- B: Card-style with thumbnail — visual context

**Decision:** Simple rows (timecode only)  
**Rationale:** Matches the stripped-down design philosophy from Phase 2; fast rendering aligns with performance priorities.

**Follow-up:** Theme and orientation?
- A: Light theme, portrait (like Library)
- B: Dark theme, landscape (continuing Skim video-editing mindset)

**Decision:** Dark theme, landscape  
**Rationale:** Keeps user in video-editing mental model; allows quick returns to Skim without leaving landscape mode.

---

### 2. Delete Interaction

**Options Presented:**
- A: Swipe-to-delete (immediate removal)
- B: Edit mode with delete buttons

**Decision:** Swipe-to-delete with immediate removal  
**Rationale:** Fast, standard iOS pattern; aligns with confident, decisive UI.

**Follow-up:** Undo capability?
- A: Immediate removal only (user re-marks in Skim if regretted)
- B: Toast with Undo button (recovery without re-skimming)

**Decision:** Immediate removal only  
**Rationale:** Simplifies UI; user can always return to Skim and re-mark if needed. Reduces undo complexity.

---

### 3. Navigation & Flow

**Question 1:** Can users add more clips after reaching Review?
- A: Go back to Skim, mark more, return to Review (flexible loop)
- B: Review-only checkpoint — no adding from Review

**Decision:** Review-only checkpoint  
**Rationale:** Simpler mental model; clear progression through the workflow. Users can return to Skim but must make a conscious choice.

**Question 2:** What does the back button do?
- A: Back to Skim (same video, same playhead, clips intact)
- B: To Library (start fresh)

**Decision:** Back to Skim  
**Rationale:** Preserves editing context; user can mark additional clips and review them without losing the original session state.

---

### 4. Playback State Preservation

**Question 1:** How should playback position be handled?
- A: Resume at same position (where user tapped Done)
- B: Start from first clip (deliberate review-then-continue pattern)

**Decision:** Resume at same position  
**Rationale:** Preserves mental model of video timeline; user can re-enter the skim session seamlessly.

**Question 2:** Should tapping a clip row jump to that position?
- A: Yes — tappable clips for faster preview
- B: No — rows display-only

**Decision:** Rows are display-only  
**Rationale:** Simpler interaction model; scrubbing happens in Skim via manual drag, not from Review.

---

## Key Decisions Summary

| Area | Decision |
|------|----------|
| Theme & Orientation | Dark landscape (continuing Skim context) |
| Clip Display | Text-only rows with timecode |
| Delete Gesture | Swipe-to-delete, immediate removal, no undo |
| Navigation | Back button goes to Skim; Review is a checkpoint |
| Playback State | Resume at same position; rows are non-interactive |

---

## Deferred Ideas Captured

- Per-clip trim scrubbers in review (v2)
- Clip preview on tap (v2)
- Reorder clips (v2)
- Bulk delete (v2)

---

*Generated during Phase 3 discussion on 2026-05-11*
