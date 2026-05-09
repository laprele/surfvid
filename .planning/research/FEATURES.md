# Feature Landscape

**Domain:** iOS video clip extraction / trimming app
**Project:** Surfvid
**Researched:** 2026-05-09
**Confidence:** HIGH (prototype validated; iOS platform conventions well-established)

---

## Reference Apps

| App | Category | Relevant Behavior |
|-----|----------|-------------------|
| Apple Photos | Built-in trimmer | Yellow handle trimmer on scrub bar; single clip per session; save as new clip |
| Apple Clips | Record + trim | Landscape skim, tap-to-hold clips, no multi-clip export |
| CapCut | Social/TikTok editor | Split tool to mark clips from long video; timeline with drag handles; export to Camera Roll |
| Splice (GoPro) | Action sports edit | Mark in/out on timeline; multi-clip assembly; export preset for action formats |
| LumaFusion | Pro editor | Jog/shuttle wheel; frame-accurate in/out; magnetic timeline; multi-track |

---

## Table Stakes

Features users expect without thinking. Missing = confusion or frustration.

| Feature | Why Expected | Complexity | Dependency |
|---------|--------------|------------|------------|
| Camera roll video picker | Every iOS video app starts here | Low | PhotosKit permission |
| Visible playhead with current timecode | Users need to know where they are | Low | AVFoundation seek |
| Drag-to-scrub the video | Standard iOS Photos gesture; not having it is jarring | Medium | AVFoundation `seekToTime` |
| Play / pause toggle | Essential for checking a moment before marking | Low | AVPlayer |
| Mark In point | Core trimming primitive | Low | State management |
| Mark Out point (creates a clip) | Core trimming primitive | Low | Depends on In point |
| Per-clip trim handles (drag to adjust In/Out after marking) | Apple Photos sets this expectation | Medium | Re-seek on drag |
| Delete a marked clip | Users make mistakes; delete is expected | Low | State management |
| Clip count / summary visible during skim | Users need to track progress on a long video | Low | None |
| Export to Camera Roll (Photos) | The canonical iOS save destination | Medium | AVAssetExportSession + PhotosKit |
| Progress indicator during export | Long videos take time; silence = assumed hang | Low | AVAssetExportSession progress |
| Confirmation after export | "Did it work?" — users need closure | Low | None |
| Landscape orientation for skim | Landscape maximises video surface; portrait feels wrong during playback | Low | UIInterfaceOrientation |
| "Pending In" visual feedback | User pressed Vol+ — they need to know it registered | Low | State + HUD overlay |

---

## Differentiators

Features that set Surfvid apart. Not expected by users, but meaningfully valuable.

| Feature | Value Proposition | Complexity | Dependency |
|---------|-------------------|------------|------------|
| Volume-button In/Out marking | Hands stay on the phone naturally; no need to reach a button on screen while watching | High | AVAudioSession + MPRemoteCommandCenter or IOKit workaround |
| Mark multiple clips from one skim session | No other simple trimmer does this in one pass; LumaFusion does it but with a complex timeline | Medium | Clip list state |
| Mini filmstrip with all marked clip ranges visible | Prevents accidental overlapping clips; shows progress at a glance | Medium | Clip list + timeline overlay |
| Tap-to-hide chrome during skim | Full-bleed video without distraction; feels cinematic | Low | Opacity toggle |
| Skim speed readout (0.x – N×) | Real-time velocity feedback tells the user how fast they're moving through footage | Low | Pointer velocity math |
| Return-to-skim from review | Non-destructive; user can add more clips without losing what they marked | Low | Navigation stack with state preservation |
| Per-clip label (auto-numbered, editable) | Surfing use case: "drop-in", "wipeout" — meaningful names speed up review | Medium | TextField + state |
| Scrub-by-dragging the whole video surface | Larger touch target than a thin scrubber bar; feels physically connected to the footage | Medium | Pointer events on full-bleed surface |

---

## Anti-Features

Deliberately excluded. Building these would bloat the focused workflow or invite scope creep.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Merged / concatenated export | Explicitly out of scope; adds AVMutableComposition complexity without matching the user's need | Export N individual clip files |
| Filters, color grading, LUTs | Turns a trimmer into an editor; CapCut already owns this space | Stay out of that category |
| Titles, text overlays, stickers | Social-content-creation feature set; wrong audience | Refer users to CapCut/Clips |
| Multi-track audio / voiceover | LumaFusion's territory; adds recording permissions + complexity | Not needed for personal clip extraction |
| Live camera capture | Footage already exists on the device; scope is camera roll only | Photos library picker is the entry point |
| Cloud sync / project files | Cross-device project state requires backend; overkill for personal use | Stateless: each session is independent |
| Timeline assembly / reordering clips before export | Forces users to think about order; individual files are more flexible downstream | Output numbered files; user can reorder in Photos or iMovie |
| Slow-motion / speed ramp | Specialty feature; adds AVFoundation complexity for edge cases | Apple Photos handles slo-mo natively |
| Social sharing deep-links (TikTok, Instagram, Reels) | Requires per-platform SDK; moves app into content-distribution territory | System Share Sheet covers this if needed |
| Subscription / paywall / analytics SDKs | v1 is personal use via Xcode sideload; these add entitlements and privacy complexity | Zero third-party dependencies for v1 |

---

## Scrubbing / Marking UX Patterns on iOS

### Pattern 1: Drag-on-full-surface (Surfvid's model — validated in prototype)
- Touch anywhere on the video frame, drag left/right to move playhead
- Larger target than a scrub bar; lower precision per pixel requires velocity scaling
- Velocity readout helpful (0.x for slow, N× for fast)
- Used by: Surfvid prototype; conceptually similar to Apple's "scrub speed" zones

### Pattern 2: Thumb scrubber bar (Apple Photos / most apps)
- Thin bar at the bottom or top; drag thumb
- Precise but small touch target; thumb occludes the timecode
- Good for short clips; fiddly on 30+ minute videos

### Pattern 3: Jog / shuttle wheel (LumaFusion)
- Circular dial at bottom of screen; rotate for frame-by-frame
- High precision; familiar to professional editors
- High implementation complexity; wrong for a fast-skim use case

### Pattern 4: Frame-stepping buttons (+1 / -1 frame)
- Buttons to nudge one frame at a time
- Useful for exact In/Out on action content
- Medium complexity; pairs well with a coarse scrubber
- Recommended for review screen trim handles (future phase)

### Pattern 5: Filmstrip / thumbnails strip
- Row of frame thumbnails below timeline
- Users can tap a thumbnail to jump
- High complexity (AVAssetImageGenerator, async thumbnail loading)
- CapCut and LumaFusion both use it; overkill for v1

---

## Export Formats and Destinations (iOS Reality)

### Formats users actually use
| Format | When | Notes |
|--------|------|-------|
| MP4 (H.264) | Default / universal | PHAsset to Camera Roll; AirDrop; Messages — always works |
| MP4 (H.265 / HEVC) | Space-saving, newer iPhones | Smaller files but limited compatibility with older software |
| MOV (ProRes) | Professional / LumaFusion output | Huge files; overkill for social or personal clips |

**Recommendation:** H.264 MP4 at source resolution. No format picker for v1 — reduces decisions, always compatible.

### Destinations users actually use
| Destination | Mechanism | Priority |
|-------------|-----------|----------|
| Camera Roll (Photos library) | `PHPhotoLibrary.shared().performChanges` | Primary — expected by all iOS users |
| Files app (On My iPhone) | `FileManager` copy to app's Documents folder | Secondary — useful for surfvid's power users |
| Share Sheet | `UIActivityViewController` | Tertiary — covers AirDrop, Messages, iCloud Drive indirectly |
| iCloud Drive | Share Sheet delegates to Files | Covered via Share Sheet |

**Recommendation:** Implement Camera Roll first. Share Sheet second (one `UIActivityViewController` covers AirDrop, iCloud Drive, Messages). Files app is low-priority.

---

## Feature Dependencies

```
PhotosKit permission
  └── Camera roll picker
        └── AVPlayer + AVAsset load
              ├── Drag-to-scrub (seekToTime)
              │     └── Skim velocity readout
              ├── Volume-button bridge
              │     ├── Mark In (state)
              │     └── Mark Out (creates clip) ← depends on Mark In state
              │           └── Clip list
              │                 ├── Mini filmstrip overlay
              │                 ├── "N marked" counter
              │                 └── Review screen
              │                       ├── Per-clip trim handles (re-seek)
              │                       ├── Per-clip label editing
              │                       ├── Delete clip
              │                       └── Export trigger
              │                             └── AVAssetExportSession
              │                                   ├── Export progress HUD
              │                                   └── PHPhotoLibrary save
              │                                         └── Confirmation toast
              └── Play / pause toggle
```

---

## MVP Recommendation

Build in this order to be useful as fast as possible:

1. Camera roll picker + AVPlayer playback (nothing works without this)
2. Drag-to-scrub with timecode readout
3. Volume-button In/Out marking + clip list state
4. Mini filmstrip overlay showing marked ranges
5. Review screen with per-clip trim handles + delete
6. AVAssetExportSession export to Camera Roll + toast

Defer to a later phase:
- Per-clip label editing (auto-numbering is sufficient for v1)
- Share Sheet / Files export destinations (Camera Roll covers the primary need)
- Frame-stepping buttons on review trim handles (drag handles are good enough)
- Tap-to-hide chrome (nice-to-have; implement after core loop works)

---

## Sources

- Surfvid prototype (`Surfvid/Surfvid.html` and component JSX files) — HIGH confidence, first-party validated UX
- Apple Photos app trimming behavior — HIGH confidence, directly observable
- AVFoundation documentation (developer.apple.com/documentation/avfoundation) — HIGH confidence
- LumaFusion, CapCut, Splice feature sets — MEDIUM confidence (training data, app store descriptions; not verified via live web access this session)
