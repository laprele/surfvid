---
phase: 01-app-shell-video-browsing
plan: "02"
subsystem: library-ui
tags:
  - photos-kit
  - library-view
  - async-thumbnail
  - permission-flow
dependency_graph:
  requires:
    - "01-01"
  provides:
    - LibraryView (full permission state switcher + library list)
    - LibraryCell (async thumbnail + metadata row + cancel-on-scroll)
  affects:
    - AppViewModel (consumes authStatus, assets, requestPhotosAccess, pickVideo)
    - Formatters (consumes formatDuration, relativeDate)
tech_stack:
  added: []
  patterns:
    - PHImageManager.requestImage with .opportunistic delivery (double-callback)
    - PHImageResultIsDegradedKey check for flicker prevention
    - PHImageManager.cancelImageRequest in onDisappear
    - SwiftUI List(.plain) with .listRowSeparator(.hidden)
    - UIApplication.openSettingsURLString deep-link for permission denied
key_files:
  created:
    - SurfvidApp/Library/LibraryCell.swift
  modified:
    - SurfvidApp/Library/LibraryView.swift
decisions:
  - "Used relativeDate(for:) as the primary video row title (PHAsset has no user-facing display name); Phase 2 can resolve actual filename via PHAssetResource if needed"
  - "Build verified via xcodebuild -target Surfvid -sdk iphoneos26.4 CODE_SIGNING_ALLOWED=NO (no simulator runtime installed on this machine; same approach as Wave 1)"
  - "swiftc -typecheck also passed for all 9 Swift files targeting arm64-apple-ios16.0"
metrics:
  duration: ~180s
  completed: "2026-05-09"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Phase 01 Plan 02: Library UI — Photos Permission Flow and Video List Summary

Wave 2 replaces the gray stub LibraryView with the full Photos authorization flow and a scrollable video list backed by LibraryCell with asynchronous thumbnail loading and scroll-cancel logic. LIB-01 and LIB-02 are satisfied.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement LibraryView — permission states, header, tab row, and list | 09c7bc9 | SurfvidApp/Library/LibraryView.swift |
| 2 | Implement LibraryCell — async thumbnail with requestID cancel and metadata row | a55216b | SurfvidApp/Library/LibraryCell.swift |

## Implementation Details

### LibraryView (SurfvidApp/Library/LibraryView.swift)

The body is a `switch appViewModel.authStatus` covering four cases:

- `.notDetermined` → `PermissionPromptView` + `onAppear { Task { await appViewModel.requestPhotosAccess() } }`
- `.denied, .restricted` → `PermissionDeniedView` with "Open Settings" CTA wired to `UIApplication.openSettingsURLString`
- `.authorized, .limited` → `libraryContent` VStack: `libraryHeader` → `titleBlock` → `tabRow` → `videoList` or `emptyState`
- `@unknown default` → `PermissionPromptView` (forward-compat guard)

The library list uses `List(appViewModel.assets, id: \.localIdentifier)` with `.listStyle(.plain)` and `.listRowSeparator(.hidden)`. Tab row shows Photos (active, orange 1.5pt underline) / iCloud / Files (inactive, secondaryLabel, v1 read-only). All copy strings match the UI-SPEC Copywriting Contract exactly.

### LibraryCell (SurfvidApp/Library/LibraryCell.swift)

Each row loads its thumbnail asynchronously:

- `PHImageRequestOptions.deliveryMode = .opportunistic` — fires handler twice (degraded first, full quality second)
- `PHImageResultIsDegradedKey` check: accepts degraded image as placeholder; replaces only with final full-quality
- `isSynchronous = false` — mandatory; synchronous requests in List freeze main thread 100-500ms per cell
- `isNetworkAccessAllowed = true` — permits iCloud fallback for assets not cached on-device
- Target size: `56 × 3 = 168` × `72 × 3 = 216` px (@3x retina)
- `cancelThumbnail()` in `.onDisappear` cancels in-flight requests by `requestID` to prevent zombie accumulation during fast scroll
- Placeholder: `Color(.secondarySystemFill)` — no spinner (UI-SPEC contract)
- Metadata: `"\(relativeDate(for:)) · \(formatDuration(_:))"` using functions from Formatters.swift

## PHAuthorizationStatus Edge Cases

- `.notDetermined` + `@unknown default` share the same prompt + onAppear trigger — safe for future iOS status additions
- `.limited` falls through to `.authorized` in the `case .authorized, .limited:` branch — shows whatever assets the user granted; no special UI required (UI-SPEC: "List renders with available assets; no special UI needed")
- `.restricted` (parental controls) shows same denied UI as `.denied` — correct behavior, both are unrecoverable without settings change

## Threat Model Compliance

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-02-01 | `mediaType = PHAssetMediaType.video.rawValue` predicate in AppViewModel.fetchVideos() — videos only | Applied in Wave 1 (AppViewModel.swift) |
| T-02-02 | `isSynchronous = false` + cancelImageRequest in onDisappear | Applied in LibraryCell |
| T-02-03 | `isNetworkAccessAllowed = true` for iCloud — user's own data, user-consented | Accepted |

## Build Results

- **swiftc type-check:** PASSED (all 9 Swift files, arm64-apple-ios16.0)
- **xcodebuild BUILD:** SUCCEEDED (`-target Surfvid -sdk iphoneos26.4 CODE_SIGNING_ALLOWED=NO`)
- **Note:** No iOS simulator runtime installed on this machine (Xcode 26.4.1, simulators require iOS 26 runtime). Build verified against iphoneos26.4 SDK — same approach as Wave 1.

## Success Criteria

- [x] LIB-01: User can browse camera roll videos with thumbnails — list shows rows with async-loaded thumbnails
- [x] LIB-02: Videos listed most-recently-added first — PHFetchRequest sorted by creationDate descending in AppViewModel
- [x] Permission flow: all four PHAuthorizationStatus states handled with correct UI and copy
- [x] xcodebuild BUILD SUCCEEDED

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None introduced. The LibraryCell primary label uses `relativeDate(for: asset.creationDate)` as the video title (Phase 2 can wire to actual PHAssetResource filename if desired — this was explicitly noted in the plan as a Phase 2 concern).

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes introduced in this plan.

## Self-Check: PASSED

- SurfvidApp/Library/LibraryView.swift: FOUND
- SurfvidApp/Library/LibraryCell.swift: FOUND
- Task 1 commit 09c7bc9: FOUND (git log)
- Task 2 commit a55216b: FOUND (git log)
- BUILD SUCCEEDED: CONFIRMED (xcodebuild output above)
