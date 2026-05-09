# Codebase Structure

**Analysis Date:** 2026-05-09

## Directory Layout

```
surfvid/                        # Repository root
├── Surfvid/                    # All application source files
│   ├── Surfvid.html            # Entry point — open this in a browser to run the app
│   ├── surfvid-shared.jsx      # Shared icons, helpers, placeholder components
│   ├── surfvid-data.jsx        # Mock video + clip data (constants only)
│   ├── surfvid-device.jsx      # iPhone chassis component (portrait/landscape)
│   ├── surfvid-paper-library.jsx        # Library screen — pick a video
│   ├── surfvid-paper-skim-landscape.jsx # Skim screen — scrub + mark In/Out
│   ├── surfvid-paper-review.jsx         # Review screen — trim clips + export
│   ├── 01-debug-skim.png       # Design reference screenshot
│   └── 02-debug-skim.png       # Design reference screenshot
├── .claude/
│   └── settings.local.json     # Claude Code permission overrides (local only)
├── .planning/
│   └── codebase/               # GSD codebase map documents (this directory)
├── .git/                       # Git repository metadata
└── README.md                   # Minimal repo description (1 line)
```

## Directory Purposes

**`Surfvid/` — all application code:**
- Purpose: Contains every file needed to run the prototype
- Contains: One HTML entry point, seven `.jsx` component/data files, two debug screenshots
- Key files: `Surfvid.html` (entry), `surfvid-app.jsx` (orchestrator), `surfvid-shared.jsx` (utilities)
- No subdirectories — flat structure

**`.claude/` — tooling config:**
- Purpose: Claude Code local settings
- Contains: `settings.local.json` — permission allow-list for Claude bash commands
- Generated: No — manually maintained
- Committed: Yes (present in initial commit)

**`.planning/codebase/` — architecture documentation:**
- Purpose: GSD codebase map for AI-assisted planning
- Contains: STACK.md, INTEGRATIONS.md, ARCHITECTURE.md, STRUCTURE.md (this file)
- Generated: Yes (by GSD mapper agent)
- Committed: Likely yes (part of planning workflow)

## Key File Locations

**Entry Points:**
- `Surfvid/Surfvid.html`: The sole entry point. Open in any modern browser. Loads CDN scripts, then all `.jsx` files in dependency order, then mounts `Root`.

**Application Orchestrator:**
- `Surfvid/surfvid-app.jsx`: `SVApp` — top-level screen state machine. `SVDoneToast` — post-export confirmation screen.

**Screen Components:**
- `Surfvid/surfvid-paper-library.jsx`: `SVLibraryPaper` — video selection screen
- `Surfvid/surfvid-paper-skim-landscape.jsx`: `SVSkimPaperLandscape` — the main skimming UI (landscape), plus `SVMiniFilmstrip`, `SVVolumeHUDLandscape`, `SVFlashBandLandscape`, `SVHardwareBridgeLandscape`
- `Surfvid/surfvid-paper-review.jsx`: `SVReviewPaper` — clip review + export; contains `SVClipRow`, `SVExportSheet`

**Device Shell:**
- `Surfvid/surfvid-device.jsx`: `SVDevice` — iPhone frame with interactive hardware buttons

**Shared Utilities:**
- `Surfvid/surfvid-shared.jsx`: `SVIcon` (icon factory), `SVFilmTile` (filmstrip placeholder), `svFmt` (time formatter)
- `Surfvid/surfvid-data.jsx`: `SVMockVideos` (7 video records), `SVMockClips` (4 pre-marked clips)

**Configuration:**
- `Surfvid/Surfvid.html` — all CDN URLs and SRI hashes are defined here; no separate config file
- `.claude/settings.local.json` — Claude Code permissions

**Design References:**
- `Surfvid/01-debug-skim.png` — screenshot reference for the skim screen layout
- `Surfvid/02-debug-skim.png` — screenshot reference for the skim screen layout

## Naming Conventions

**Files:**
- All application files: `surfvid-<purpose>.jsx` (kebab-case, `surfvid-` prefix)
- Screen components: `surfvid-paper-<screen-name>.jsx`
- The HTML entry point: `Surfvid.html` (PascalCase, matching the project name)

**React Components:**
- PascalCase with `SV` prefix: `SVApp`, `SVDevice`, `SVLibraryPaper`, `SVSkimPaperLandscape`, `SVReviewPaper`, `SVClipRow`, `SVExportSheet`, `SVDoneToast`, `SVIcon`, `SVFilmTile`, `SVMiniFilmstrip`, `SVVolumeHUDLandscape`, `SVFlashBandLandscape`, `SVHardwareBridgeLandscape`

**Utility Functions:**
- camelCase with `sv` prefix: `svFmt`

**Mock Data Constants:**
- `SVMock` prefix + PascalCase noun: `SVMockVideos`, `SVMockClips`

**Global Window Bridge Variables:**
- Double underscore + camelCase: `window.__svIn`, `window.__svOut`

## Where to Add New Code

**New Screen:**
- Create `Surfvid/surfvid-paper-<screenname>.jsx`
- Export the root component via `Object.assign(window, { SVNewScreen })`
- Add `<script type="text/babel" src="surfvid-paper-<screenname>.jsx"></script>` to `Surfvid/Surfvid.html` before `surfvid-app.jsx`
- Add a new `screen` value and render branch in `SVApp` in `Surfvid/surfvid-app.jsx`

**New Shared Icon:**
- Add a new key to the `SVIcon` object in `Surfvid/surfvid-shared.jsx`

**New Shared UI Primitive:**
- Add as a named function in `Surfvid/surfvid-shared.jsx` and include it in the `Object.assign(window, {...})` call at the bottom

**New Mock Data:**
- Add to `Surfvid/surfvid-data.jsx` and include in the `Object.assign(window, {...})` call

**New Sub-component within a screen:**
- Define it in the same `.jsx` file as its parent screen (e.g., sub-components of Review live in `surfvid-paper-review.jsx`)
- Only export to window if other files need it

## Special Directories

**`Surfvid/` (flat — no subdirectories):**
- Purpose: Entire application lives here
- Generated: No
- Committed: Yes

**`.planning/` (planning docs):**
- Purpose: AI-assisted planning artifacts
- Generated: Yes (GSD tools)
- Committed: Per project convention

---

*Structure analysis: 2026-05-09*
