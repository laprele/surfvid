# Surfvid — Retrospective

## Milestone: v1.1 — MVP

**Shipped:** 2026-05-12
**Phases:** 6 | **Plans:** 13 | **LOC:** 1,624 Swift | **Timeline:** 7 days

### What Was Built

- App shell with Photos authorization, camera roll grid, and async thumbnail generation
- Frame-accurate drag-to-scrub with In/Out marking, multi-clip mini filmstrip, and live timecode
- Review screen with clip list, swipe-to-delete, and playback state preservation
- Passthrough export (AVAssetExportPresetPassthrough) with per-clip progress, Camera Roll save, and Share Sheet
- Scrub sensitivity tuning (PX_PER_S 0.6 → 1.2) with zero-tolerance exact-frame seeks
- Pinch-to-zoom (up to 4×) with drag-to-pan routing, double-tap reset, and zoom indicator

### What Worked

- **objectWillChange forwarding** was the right pattern for PlayerController → AppViewModel reactivity. Established early and never needed revisiting.
- **Phase executor worktrees** isolated risky changes cleanly — merge commits are clean and phase boundaries are clear in git history.
- **Device testing** on real hardware caught real bugs that simulation missed (MainActor export mutation, Dynamic Island padding, Export All visibility with empty list). Human checkpoint at each phase was the right call for a UI-heavy app.
- **Zero-tolerance seeks** were a one-line fix that dramatically improved scrub precision. Captured as a backlog item and promoted quickly.
- **@GestureState + @State split** for in-flight vs committed gesture values was clean — the pattern generalized from Phase 2 (drag) to Phase 6 (pinch/pan) without modification.

### What Was Inefficient

- **REQUIREMENTS.md checkboxes never updated during development** — all were still `[ ]` at milestone close. The traceability table showed "Pending" for all requirements. PROJECT.md was kept up-to-date as the authoritative record instead, but the disconnect created extra noise at milestone close.
- **Phases 1–2 have no SUMMARY.md files** — these early phases were executed before the full artifact tracking pattern was established. Acceptable for a personal tool but worth enforcing from the start on future projects.
- **XcodeGen regeneration friction** — every new file addition in a worktree required manual `xcodegen generate` to update the `.xcodeproj` before building. This was a recurrent speed bump across multiple phases.

### Patterns Established

- `objectWillChange` forwarding: `appViewModel.playerController.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)` — the standard way to bridge `@EnvironmentObject` visibility across sub-objects
- Timer progress polling: `Timer(timeInterval: 0.1)` + `RunLoop.main.add(timer, forMode: .common)` — fires during scroll, safer than KVO for AVFoundation progress
- `@Sendable PHPhotoLibrary.performChanges` closure — required for Swift 6 concurrency compliance
- `await MainActor.run {}` wrapper after AVFoundation async continuations — AVFoundation resumes continuations off the main thread
- `@GestureState` for in-flight gesture values (auto-resets on cancel/end) + `@State` for committed values — clean gesture state model for complex multi-gesture views
- `ExclusiveGesture` / `.exclusively(before:)` for TapGesture(count:2) vs TapGesture(count:1) disambiguation

### Key Lessons

1. **Test on device early** — simulator doesn't replicate Dynamic Island layout, AVFoundation threading, or gesture feel. Every phase that had a device checkpoint caught at least one thing the simulator missed.
2. **Keep REQUIREMENTS.md in sync** — don't defer checkbox updates to milestone close. Update traceability table inline when a plan's summary confirms a requirement delivered.
3. **Promote backlog items quickly** — Skim Sensitivity (999.1 → Phase 5) went from backlog to shipped in one session. The friction of the backlog entry delayed it unnecessarily; if it's worth doing, insert it as a phase immediately.
4. **AVFoundation threading is non-obvious** — `exportAsynchronously` + `AVAssetExportSession` continuations resume on a background thread. Any @Published mutation after `await` needs explicit `MainActor.run`. Not documenting this upfront cost one device testing cycle.
5. **XcodeGen `.xcodeproj` in gitignore is the right call** — keeps history clean, but requires discipline: always run `xcodegen generate` in worktrees after adding new files before building.

### Cost Observations

- Model mix: primarily Sonnet (execution), Opus (planning and discussion)
- Sessions: ~6-8 focused sessions over 7 days
- Notable: Phase 6 (pinch-to-zoom, 200+ lines of gesture logic) executed in ~10 minutes with zero deviations from plan — the most efficient execution in the milestone

---

## Cross-Milestone Trends

| Metric | v1.1 |
|--------|------|
| Timeline | 7 days |
| Phases | 6 |
| Plans | 13 |
| LOC | 1,624 Swift |
| Device-caught bugs | 4 |
| Plan deviations (auto-fixed) | 5 |
| Requirements delivered | 19/19 |
