---
phase: 4
slug: export
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-12
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (no test target established yet) |
| **Config file** | Xcode scheme — no separate config file |
| **Quick run command** | `xcodebuild build -scheme Surfvid -destination 'generic/platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | same (no automated tests yet) |
| **Estimated runtime** | ~30 seconds (build only) |

> **Note:** Phases 1–3 used manual device verification. Phase 4 follows the same approach — no XCTest target exists. Nyquist sampling uses build-success + manual device checklist as verification signal.

---

## Sampling Rate

- **After every task commit:** Build must compile cleanly (zero errors)
- **After every plan wave:** Manual device test against checklist below
- **Before `/gsd-verify-work`:** Full manual checklist must be green
- **Max feedback latency:** Build ~30s; device test ~5 min per wave

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 4-01-01 | 01 | 1 | EXP-01, PERF-03 | clip.end > clip.start enforced | build | `xcodebuild build ...` | ✅ green |
| 4-01-02 | 01 | 1 | EXP-01, EXP-02 | isExporting guards mutation | build | `xcodebuild build ...` | ✅ green |
| 4-01-03 | 01 | 1 | EXP-02 | progress polled via Timer not KVO | build | `xcodebuild build ...` | ✅ green |
| 4-01-04 | 01 | 1 | EXP-03 | screen = .done after all clips | build | `xcodebuild build ...` | ✅ green |
| 4-02-01 | 02 | 2 | EXP-01 | MP4 appears in Camera Roll | manual | — | ✅ green |
| 4-02-02 | 02 | 2 | EXP-02 | progress bar updates during export | manual | — | ✅ green |
| 4-02-03 | 02 | 2 | EXP-03 | Done screen + auto-return 2.5s | manual | — | ✅ green |
| 4-02-04 | 02 | 2 | EXP-04 | Share sheet opens with file URL | manual | — | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No new test framework installation needed. Verification is build-success + manual device checklist.

*Existing infrastructure covers compilation verification. All functional requirements require real device.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| MP4 appears in Camera Roll | EXP-01 | PHPhotoLibrary write requires real device; simulator lacks Camera Roll write support | Export 1 clip; open Photos app; verify MP4 file present with correct duration |
| Per-clip progress bar updates | EXP-02 | UI animation requires real device | Export 2+ clips; watch each row; confirm progress bar animates 0%→100% per clip |
| Done screen + auto-return | EXP-03 | Timing requires device frame rate | Tap Export; watch Done screen appear; verify auto-return to Library after ~2.5s |
| Share sheet destinations | EXP-04 | UIActivityViewController requires real device (AirDrop, Files) | Tap Share on exported clip; verify AirDrop and Files appear |
| Passthrough speed | PERF-03 | Requires 15GB+ source file | Export 30s clip from hour-long video; verify completes in < 10s |
| Lock during export | D-02 | User interaction test | Start export; try swipe-to-delete; verify disabled |

---

## Validation Sign-Off

- [x] All tasks have build-pass verify or manual checklist entry
- [x] Sampling continuity: build check after each task commit
- [x] No watch-mode flags
- [x] Manual checklist completed on real device before verification
- [x] `nyquist_compliant: true` set in frontmatter when checklist passes

**Approval:** 2026-05-12
