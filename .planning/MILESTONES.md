# Surfvid — Milestones

## v1.1 — MVP (2026-05-12)

**Phases:** 1–6 · **Plans:** 13 · **LOC:** 1,624 Swift (15 files) · **Timeline:** 7 days (2026-05-05 → 2026-05-12)

**Delivered:** Full end-to-end on-device video skimming app — browse camera roll, scrub to frame, mark clips, review, export passthrough MP4s to Camera Roll with Share Sheet.

**Key accomplishments:**
1. App shell with Photos auth, camera roll grid, and async thumbnails
2. Frame-accurate drag-to-scrub with In/Out marking and multi-clip mini filmstrip
3. Review screen with clip list, swipe-to-delete, and playback state preservation across navigation
4. Passthrough export (no re-encode) with per-clip progress bars, Camera Roll save, and Share Sheet
5. Scrub sensitivity tuned (PX_PER_S 0.6 → 1.2) with zero-tolerance exact-frame seeks
6. Pinch-to-zoom (up to 4×) with drag-to-pan routing, double-tap reset, and zoom indicator

**Archive:** [v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md) · [v1.1-REQUIREMENTS.md](milestones/v1.1-REQUIREMENTS.md)
