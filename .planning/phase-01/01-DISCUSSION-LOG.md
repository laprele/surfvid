# Phase 1: App Shell & Video Browsing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 1-App Shell & Video Browsing
**Areas discussed:** Project scaffold, Orientation lock, Photos data layer, Skim screen scope

---

## Project Scaffold

| Option | Description | Selected |
|--------|-------------|----------|
| XcodeGen | project.yml + xcodegen generate; .xcodeproj gitignored | ✓ |
| Xcode GUI | Manual File → New → App; .xcodeproj committed | |
| Both (with fallback) | XcodeGen primary, manual fallback noted | |

**User's choice:** XcodeGen (already installed)

| Option | Description | Selected |
|--------|-------------|----------|
| SurfvidApp/ at root | Separate top-level dir, distinct from Surfvid/ prototype | ✓ |
| iOS/ at root | Generic name | |
| Sources/ at root | Xcode project at root | |

**User's choice:** SurfvidApp/ at root

| Option | Description | Selected |
|--------|-------------|----------|
| com.laprell.surfvid — automatic signing | Simple, matches Apple ID team | ✓ |
| com.alexanderlaprell.surfvid | More unique reverse-DNS | |
| Set manually in Xcode | Leave as TODO | |

**User's choice:** com.laprell.surfvid, automatic signing

---

## Orientation Lock

| Option | Description | Selected |
|--------|-------------|----------|
| UIWindowScene.requestGeometryUpdate | iOS 16+ API; called on screen state change | ✓ |
| UIViewControllerRepresentable wrapper | Boilerplate but works to iOS 13 | |
| Info.plist restrict + AppDelegate override | Requires UIKit scene delegate bridge | |

**User's choice:** UIWindowScene.requestGeometryUpdate

| Option | Description | Selected |
|--------|-------------|----------|
| Portrait + Landscape Left + Landscape Right | All three for requestGeometryUpdate to work | ✓ |
| All four (incl. Upside Down) | Not needed | |
| You decide | Defer to planner | |

**User's choice:** Portrait + Landscape Left + Landscape Right

---

## Photos Data Layer

| Option | Description | Selected |
|--------|-------------|----------|
| Snapshot [PHAsset] on load, refresh on foreground | One-time snapshot + foreground refresh | |
| LibraryViewModel: PHPhotoLibraryChangeObserver | Live updates; more code | |
| Snapshot on load, no refresh | Load once per session; restart to see new videos | ✓ |

**User's choice:** Snapshot on load, no refresh

| Option | Description | Selected |
|--------|-------------|----------|
| AppViewModel | Central; same as screen state owner | ✓ |
| Separate LibraryViewModel @StateObject | Isolates fetch logic | |

**User's choice:** AppViewModel

---

## Skim Screen Scope in Phase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Full chrome foundation | AVPlayerLayer + top/bottom overlays; Phase 2 wires controls | ✓ |
| Minimal stub | AVPlayer + back button only | |
| You decide | Defer to planner per UI-SPEC | |

**User's choice:** Full chrome foundation

| Option | Description | Selected |
|--------|-------------|----------|
| Autoplay immediately | Matches success criterion 3; Phase 2 adds toggle | |
| Paused first frame | Player set up but not playing; play/pause wired in Phase 2 | ✓ |

**User's choice:** Paused first frame

**Notes:** User raised Phase 2 scrubbing behavior during this section. Captured as a specific: velocity-driven scrubbing identical to QuickTime Player on Mac trackpad — drag velocity = seek rate, finger position irrelevant. Deferred to Phase 2 SKIM-01 planning, logged in CONTEXT.md Specifics.

---

## Claude's Discretion

- File layout within SurfvidApp/ (flat vs. grouped)
- Exact project.yml structure beyond bundle ID + deployment target
- PHImageManager thumbnail implementation details (follow UI-SPEC §LIB-01)

## Deferred Ideas

- **QuickTime-style velocity-driven scrubbing** — Phase 2 (SKIM-01). User wants drag velocity to map to seek rate (fast swipe = fast seek; slow drag = frame-by-frame). Finger position irrelevant. Key input for Phase 2 researcher and planner.
- **Play/pause toggle** — Phase 2 (SKIM-04). Phase 1 leaves player paused.
