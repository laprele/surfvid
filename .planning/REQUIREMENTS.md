# Requirements — Surfvid

## v1 Requirements

### Library

- [ ] **LIB-01**: User can browse camera roll videos with thumbnails
- [ ] **LIB-02**: Videos listed most-recently-added first by default

### Skimming

- [ ] **SKIM-01**: User can drag anywhere on the video surface to scrub to any position
- [ ] **SKIM-03**: User can tap on-screen In/Out buttons to mark clip boundaries
- [ ] **SKIM-04**: User can tap to play/pause video during a skim session
- [ ] **SKIM-05**: Mini filmstrip at bottom of skim view shows all marked clip ranges
- [ ] **SKIM-06**: Current playhead position displayed as timecode (0:12.3)
- [ ] **SKIM-07**: Visual HUD flash confirms In or Out was registered
- [ ] **SKIM-08**: User can mark multiple clips from one video in a single session

### Review

- [ ] **REV-01**: User can see all marked clips listed with start/end times and duration
- [ ] **REV-02**: User can delete a clip before exporting
- [ ] **REV-03**: User can return to skimming to add more clips from the same video

### Export

- [ ] **EXP-01**: User can export each clip as a separate H.264 MP4 file to Camera Roll
- [ ] **EXP-02**: Export progress is shown per clip
- [ ] **EXP-03**: Confirmation is shown after all clips are exported
- [ ] **EXP-04**: User can share clips via Share Sheet (AirDrop, iCloud, Files)

### Performance

- [ ] **PERF-01**: App plays and scrubs hour-long videos (15-20 GB) without crashing or significant lag — AVPlayer streams from Photos asset URL, never loads file into memory
- [ ] **PERF-02**: Filmstrip thumbnails for hour-long videos generated asynchronously without blocking the skim UI
- [ ] **PERF-03**: Clip export from large source files completes using passthrough preset (no re-encode; export time proportional to clip length only)

---

## v2 Requirements

- Volume button In/Out marking (Vol+ = In, Vol- = Out) — requires real-device spike; sandboxed gray-area workaround via AVAudioSession KVO
- Per-clip trim scrubbers in review — drag handles to fine-tune each clip's In/Out after marking
- Library search and filter by date or duration

---

## Out of Scope

- Merged/concatenated export — user wants separate files per clip, not a joined video
- Live camera capture — camera roll only; workflow starts after footage exists
- React Native / cross-platform — native SwiftUI only
- Social sharing SDKs (Instagram, TikTok, etc.) — Share Sheet covers all destinations

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| LIB-01 | — | Unassigned |
| LIB-02 | — | Unassigned |
| SKIM-01 | — | Unassigned |
| SKIM-03 | — | Unassigned |
| SKIM-04 | — | Unassigned |
| SKIM-05 | — | Unassigned |
| SKIM-06 | — | Unassigned |
| SKIM-07 | — | Unassigned |
| SKIM-08 | — | Unassigned |
| REV-01 | — | Unassigned |
| REV-02 | — | Unassigned |
| REV-03 | — | Unassigned |
| EXP-01 | — | Unassigned |
| EXP-02 | — | Unassigned |
| EXP-03 | — | Unassigned |
| EXP-04 | — | Unassigned |
| PERF-01 | — | Unassigned |
| PERF-02 | — | Unassigned |
| PERF-03 | — | Unassigned |
