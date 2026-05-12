# Surfvid — Roadmap

## Milestone 1: v1.0

### Phase 1: App Shell & Video Browsing
**Goal:** User can grant Photos access, browse their camera roll, and tap a video to see it play — the full entry path to the app, end-to-end.
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** LIB-01, LIB-02, PERF-01
**Success Criteria:**
1. User opens the app and is prompted for Photos access; granting it reveals a scrollable grid of camera roll videos with thumbnails.
2. Videos are ordered most-recently-added first by default.
3. User taps a video and it begins playing immediately — the app does not hang, crash, or consume excessive memory even for a 15-20 GB hour-long file.
4. Scrolling the library grid remains smooth while thumbnails load asynchronously in the background.
**Plans:** 4 plans
Plans:
- [x] 01-01-PLAN.md — XcodeGen scaffold, core Swift type graph, project compiles (Wave 1)
- [x] 01-02-PLAN.md — Photos authorization flow, LibraryView, LibraryCell async thumbnails (Wave 2)
- [x] 01-03-PLAN.md — PlayerView AVPlayerLayer bridge, SkimView full chrome shell (Wave 3)
- [x] 01-04-PLAN.md — Integration wiring, orientation lock, device verification checkpoint (Wave 4)
**UI hint:** yes

### Phase 2: Skim Interactions
**Goal:** User can scrub through a video with a drag gesture, play/pause it, mark In and Out points with on-screen buttons, and see all marked clip ranges in the mini filmstrip — building a clip list in a single skim session.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** SKIM-01, SKIM-03, SKIM-04, SKIM-05, SKIM-06, SKIM-07, SKIM-08, PERF-02
**Success Criteria:**
1. User drags anywhere on the video surface and the playhead follows the finger accurately — the frame shown matches the time position, not a nearby keyframe.
2. User taps the In button then the Out button; the app registers a clip range for those two positions.
3. Current playhead position is displayed as a timecode (e.g. 0:12.3) that updates continuously during scrub.
4. A visual HUD flash confirms each In or Out registration immediately on tap.
5. User can repeat the In/Out process multiple times in one session; all marked clip ranges are shown in the mini filmstrip at the bottom of the skim view, with filmstrip thumbnails generated asynchronously so the skim UI is never blocked.
**Plans:** 3 plans
Plans:
- [x] 02-01-PLAN.md — AppViewModel Clip state machine + PlayerController seek throttle, CADisplayLink, time observer (Wave 1)
- [x] 02-02-PLAN.md — SkimView gesture wiring + TimelineBar Canvas, all controls live (Wave 2)
- [x] 02-03-PLAN.md — Device verification checkpoint (Wave 3)
**UI hint:** yes

### Phase 3: Review Screen
**Goal:** User can leave the skim screen, review all marked clips with their start/end times and durations, delete unwanted clips, and return to skimming to add more — without losing playback state.
**Mode:** mvp
**Depends on:** Phase 2
**Requirements:** REV-01, REV-02, REV-03
**Success Criteria:**
1. User navigates to the review screen and sees a list of all clips with start time, end time, and duration for each.
2. User deletes a clip from the review list; it disappears immediately.
3. User taps "back to skim" from the review screen; the skim view reopens with the same video at the same playhead position and all previously marked clips intact.
**Plans:** 2 plans
Plans:
- [ ] 03-01-PLAN.md — Screen enum .review case, ContentView routing + orientation lock, SkimView Done wire-up, ReviewView dark-theme shell (Wave 1)
- [ ] 03-02-PLAN.md — ReviewView clip list, swipe-to-delete, dark-theme List styling, empty state (Wave 2)
**UI hint:** yes

### Phase 4: Export
**Goal:** User can export every marked clip as a separate trimmed MP4 file to the Camera Roll, with per-clip progress feedback, a completion confirmation, and a share option — all without re-encoding.
**Mode:** mvp
**Depends on:** Phase 3
**Requirements:** EXP-01, EXP-02, EXP-03, EXP-04, PERF-03
**Success Criteria:**
1. User taps Export from the review screen; each clip is exported as a separate H.264 MP4 file that appears in the Camera Roll.
2. Per-clip export progress is shown (e.g. a progress bar or percentage per row) so the user can see which clips are done and which are in progress.
3. After all clips finish exporting, a confirmation message or screen is shown.
4. User can tap Share on a clip to open the iOS Share Sheet and send the file via AirDrop, Files, iCloud, or any share destination.
5. Exporting a 30-second clip from a 15 GB source file completes quickly using passthrough preset — no re-encode, export time is proportional to clip length only.
**Plans:** 2 plans
Plans:
**Wave 1**
- [x] 04-01-PLAN.md — ExportManager, AppViewModel export state + startExport, ContentView .done routing (Wave 1)
**Wave 2** *(blocked on Wave 1 completion)*
- [x] 04-02-PLAN.md — ReviewView Export button + progress + Share, DoneView, ActivityViewController; device checkpoint (Wave 2)

Cross-cutting constraints:
- `AVAssetExportPresetPassthrough` locked — no re-encode (both plans)
- Sequential export loop — one `AVAssetExportSession` at a time (both plans)
**UI hint:** yes

---

## Backlog

### Phase 999.1: Adjust skimming sensitivity to be able to define point more granularly (BACKLOG)

**Goal:** [Captured for future planning]
**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

---

## Requirement Coverage

| REQ-ID | Phase |
|--------|-------|
| LIB-01 | 1 |
| LIB-02 | 1 |
| PERF-01 | 1 |
| SKIM-01 | 2 |
| SKIM-03 | 2 |
| SKIM-04 | 2 |
| SKIM-05 | 2 |
| SKIM-06 | 2 |
| SKIM-07 | 2 |
| SKIM-08 | 2 |
| PERF-02 | 2 |
| REV-01 | 3 |
| REV-02 | 3 |
| REV-03 | 3 |
| EXP-01 | 4 |
| EXP-02 | 4 |
| EXP-03 | 4 |
| EXP-04 | 4 |
| PERF-03 | 4 |

**Total:** 19/19 requirements mapped. No orphans.
