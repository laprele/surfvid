---
phase: 1
slug: app-shell-video-browsing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xcodebuild (build-only; no XCTest target in Phase 1) |
| **Config file** | `project.yml` (XcodeGen spec) |
| **Quick run command** | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -20` |
| **Full suite command** | Manual device testing per checklist below |
| **Estimated runtime** | ~30s (clean build); manual checklist ~10 min |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 | tail -20`
- **After every plan wave:** Deploy to device + run manual checklist for that wave
- **Before `/gsd-verify-work`:** Full manual device checklist must pass
- **Max feedback latency:** 30 seconds (build check per task)

---

## Per-Task Verification Map

| Task ID | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| Scaffold: project.yml + xcodegen | 1 | — | — | N/A | build | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` | ⬜ pending |
| AppViewModel + Screen enum | 1 | — | — | N/A | build | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` | ⬜ pending |
| ContentView ZStack swap | 1 | — | — | N/A | build | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` | ⬜ pending |
| LibraryView + permission states | 2 | LIB-01 | — | NSPhotoLibraryUsageDescription present in Info.plist | build + manual | `xcodebuild build ...` then device permission flow | ⬜ pending |
| LibraryCell + PHImageManager thumbnails | 2 | LIB-01 | — | N/A | build + manual | `xcodebuild build ...` then device scroll test | ⬜ pending |
| PHFetchRequest sorted by creationDate desc | 2 | LIB-02 | — | N/A | build + manual | `xcodebuild build ...` then verify order vs Photos app | ⬜ pending |
| PlayerController.load(asset:) + AVPlayer streaming | 3 | PERF-01 | — | AVPlayer streams from URL; no file loaded into memory | build + manual | `xcodebuild build ...` then Instruments Allocations on device | ⬜ pending |
| PlayerView (UIViewRepresentable) | 3 | PERF-01 | — | N/A | build | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` | ⬜ pending |
| SkimView chrome layout | 3 | — | — | N/A | build | `xcodebuild build -scheme Surfvid -sdk iphonesimulator 2>&1 \| tail -5` | ⬜ pending |
| AppDelegate orientation lock | 4 | — | — | N/A | build + manual | `xcodebuild build ...` then device orientation test | ⬜ pending |
| pickVideo flow (Library → Skim) | 4 | LIB-01, PERF-01 | — | N/A | manual | Device: tap video → skim appears | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*No XCTest target in Phase 1. All automated feedback is via xcodebuild.*

- [ ] `SurfvidApp/` directory created — required for xcodebuild to find sources
- [ ] `project.yml` created — required before `xcodegen generate`
- [ ] `.xcodeproj` generated — required before any `xcodebuild` commands
- [ ] `.gitignore` includes `*.xcodeproj/` and `SurfvidApp/Info.plist`

*Existing infrastructure: none (greenfield). Wave 1 establishes the build system.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Permission prompt shown on fresh install | LIB-01 | Requires iOS system dialog; no automation API | Delete app, reinstall, launch — system dialog must appear |
| Permission denied → Settings deep-link | LIB-01 | Requires device Settings app | Deny permission → tap "Open Settings" → Settings app opens to Surfvid |
| Library grid shows thumbnails in correct order | LIB-01, LIB-02 | Requires real Photos library | First row must match most recent video in Photos app |
| Thumbnails load asynchronously without scroll jank | LIB-01 | Requires real device frame rate | Scroll 20+ rows rapidly; Xcode FPS counter stays ≥55fps |
| Large video (>1 GB) plays on first frame, no crash | PERF-01 | Requires real large file on device | Tap a large video; skim screen appears within 3s; no crash |
| Memory does not spike during large video playback | PERF-01 | Requires Instruments | Run Allocations instrument during playback; no multi-GB spike |
| Orientation locks portrait in Library | D-04/D-05 | Requires physical device rotation | Rotate device in Library — screen stays portrait |
| Orientation locks landscape in Skim | D-04/D-05 | Requires physical device rotation | Enter Skim screen — screen rotates to landscape; stays locked |
| Back to Library restores portrait | D-04/D-05 | Requires physical device rotation | Back button from Skim → Library — screen returns to portrait |

---

## Manual Device Testing Checklist (Phase 1 gate)

**Success Criterion 1 — Photos permission + library grid:**
- [ ] Fresh install: app shows permission prompt
- [ ] Deny permission: app shows "Photos access required" + "Open Settings" button
- [ ] Grant permission: library grid shows video thumbnails in most-recent-first order
- [ ] Thumbnails use `Color(.secondarySystemFill)` placeholder before loading
- [ ] Scrolling 20+ rows is smooth (no jank, no stutter)

**Success Criterion 2 — Most recently added first:**
- [ ] First row matches most recent video in the iOS Photos app

**Success Criterion 3 — Large video playback:**
- [ ] Tap a video > 1 GB: skim screen appears within 3 seconds showing first frame paused
- [ ] App does not crash or become unresponsive
- [ ] Memory in Xcode Debug Navigator does not spike to multi-GB levels

**Success Criterion 4 — Smooth thumbnail scroll:**
- [ ] No dropped frames while scrolling (verify with Xcode FPS counter)
- [ ] No "Publishing changes from background threads" warnings in console

**Orientation gate:**
- [ ] Library screen is portrait-locked (device rotation has no effect)
- [ ] Skim screen is landscape-locked (device rotation has no effect)
- [ ] Back to library: portrait lock restores

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify (build check) or manual checklist entry
- [ ] Sampling continuity: every task commit triggers a build check
- [ ] Wave 0: `project.yml` + `xcodegen generate` in Wave 1 Task 1 (no prior gap)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build check)
- [ ] `nyquist_compliant: true` set in frontmatter after executor confirms checklist

**Approval:** pending
