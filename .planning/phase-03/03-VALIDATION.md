---
phase: 3
slug: review-screen
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-11
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | No test target yet — Wave 0 gap (see below) |
| **Quick run command** | `xcodebuild test -project Surfvid.xcodeproj -scheme Surfvid -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | Same (single test target) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build check only (`xcodebuild build ...`) — no test target exists yet
- **After every plan wave:** Manual device/simulator smoke test (enter Review, verify list, swipe-delete, return to Skim)
- **Before `/gsd-verify-work`:** All three ROADMAP.md success criteria verified on device
- **Max feedback latency:** 60 seconds (build check)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | REV-01, REV-02, REV-03 | — | N/A | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | REV-01 | — | N/A | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testClipRowFormatting` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 2 | REV-02 | — | N/A | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testClipDeletion` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 2 | REV-03 | — | N/A | unit | `xcodebuild test ... -only-testing SurfvidTests/AppViewModelTests/testClipsPersistedOnScreenTransition` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add `SurfvidTests` target to `project.yml` (if not yet created from Phase 2 gap)
- [ ] `SurfvidTests/AppViewModelTests.swift` — covers REV-02 (`clips.remove(at:)` after swipe) and REV-03 (clips array survives `.skim` → `.review` → `.skim` transitions)
- [ ] `SurfvidTests/FormattersTests.swift` — covers REV-01 (`formatTimecode` for duration display; edge case: sub-second clip)

**Note:** If the test target is not added in Wave 0, verification gate is manual-only (acceptable for this phase's logic simplicity).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ReviewView renders in landscape, dark theme | REV-01 | UI appearance not testable via XCTest | Open app on device, mark 2+ clips, tap Done, verify dark background and landscape lock |
| Swipe-to-delete renders red button | REV-02 | UI swipe gesture requires Simulator or device | Swipe left on a clip row, verify red Delete button appears |
| Back to Skim preserves playhead | REV-03 | AVPlayer state requires device | Note timecode before Done, tap Back, verify timecode matches within ±0.1s |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
