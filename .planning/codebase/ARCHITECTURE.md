<!-- refreshed: 2026-05-09 -->
# Architecture

**Analysis Date:** 2026-05-09

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                  Surfvid/Surfvid.html                        │
│  (entry point — loads CDN scripts, .jsx files, mounts Root) │
└─────────────┬──────────────────────────────────────┬────────┘
              │                                      │
              ▼                                      ▼
┌─────────────────────────┐           ┌──────────────────────────┐
│  SVDevice               │           │  SVApp                   │
│  `surfvid-device.jsx`   │ children  │  `surfvid-app.jsx`       │
│  (iOS frame + buttons)  │◄──────────│  (screen router +        │
│                         │           │   top-level state)       │
└─────────────────────────┘           └──────────┬───────────────┘
                                                  │ renders one of:
              ┌───────────────┬──────────────────┬┴──────────────┐
              ▼               ▼                  ▼               ▼
  ┌─────────────────┐ ┌────────────────┐ ┌────────────┐ ┌──────────────┐
  │ SVLibraryPaper  │ │SVSkimPaper     │ │SVReview    │ │SVDoneToast   │
  │ surfvid-paper   │ │Landscape       │ │Paper       │ │(inline in    │
  │ -library.jsx    │ │surfvid-paper   │ │surfvid-    │ │surfvid-      │
  │                 │ │-skim-landscape │ │paper-      │ │app.jsx)      │
  └─────────────────┘ │.jsx            │ │review.jsx  │ └──────────────┘
                      └────────────────┘ └────────────┘

Shared utilities (loaded before all screens):
  surfvid-shared.jsx   — SVIcon, SVFilmTile, svFmt
  surfvid-data.jsx     — SVMockVideos, SVMockClips (constants)
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `Root` | Mounts SVDevice + SVApp; owns `landscape` bool | `Surfvid/Surfvid.html` (inline script) |
| `SVDevice` | Renders iPhone chassis, hardware buttons; dispatches `window.__svIn` / `window.__svOut` | `Surfvid/surfvid-device.jsx` |
| `SVApp` | Screen state machine (`library` → `skim` → `review` → `done`); owns video, playhead, clips | `Surfvid/surfvid-app.jsx` |
| `SVLibraryPaper` | Video list; calls `onPick(video)` to enter skim | `Surfvid/surfvid-paper-library.jsx` |
| `SVSkimPaperLandscape` | Full-bleed skim UI; drag-to-scrub; mark In/Out via volume buttons | `Surfvid/surfvid-paper-skim-landscape.jsx` |
| `SVHardwareBridgeLandscape` | Registers `window.__svIn` / `window.__svOut` for the current skim session | `Surfvid/surfvid-paper-skim-landscape.jsx` |
| `SVMiniFilmstrip` | Compact timeline bar with clip ranges and playhead | `Surfvid/surfvid-paper-skim-landscape.jsx` |
| `SVVolumeHUDLandscape` | Centered modal HUD that confirms In/Out marking | `Surfvid/surfvid-paper-skim-landscape.jsx` |
| `SVFlashBandLandscape` | Animated flash bar at top edge confirming button press | `Surfvid/surfvid-paper-skim-landscape.jsx` |
| `SVReviewPaper` | Clip list with per-clip trim scrubbers; export sheet | `Surfvid/surfvid-paper-review.jsx` |
| `SVClipRow` | Individual clip row with drag-to-trim handles | `Surfvid/surfvid-paper-review.jsx` |
| `SVExportSheet` | Bottom sheet for choosing export destination | `Surfvid/surfvid-paper-review.jsx` |
| `SVDoneToast` | Full-screen confirmation after export | `Surfvid/surfvid-app.jsx` |
| `SVIcon` | SVG icon factory (back, close, play, pause, trash, check, in, out, share, cloud, photos, hand) | `Surfvid/surfvid-shared.jsx` |
| `SVFilmTile` | Diagonal-stripe placeholder filmstrip tile | `Surfvid/surfvid-shared.jsx` |
| `svFmt` | Formats seconds to `0:12.3` or `1:23:45.6` | `Surfvid/surfvid-shared.jsx` |
| `SVMockVideos` | Static array of 7 mock video records | `Surfvid/surfvid-data.jsx` |
| `SVMockClips` | Static array of 4 pre-marked clips for `v1` | `Surfvid/surfvid-data.jsx` |

## Pattern Overview

**Overall:** Multi-screen single-page application with a centralized state machine

**Key Characteristics:**
- All screens are controlled components — they receive state and callbacks from `SVApp` only
- No global state library — all state is `React.useState` in `SVApp` (or local to a screen)
- No routing library — screen switching is a plain `if/else` tree in `SVApp`'s render
- No CSS modules or styled-components — all styles are inline `style` objects
- Global `window` object used as an inter-component event bus (hardware button bridge)

## Layers

**Shared Utilities:**
- Purpose: Icons, formatters, mock-video placeholders
- Location: `Surfvid/surfvid-shared.jsx`, `Surfvid/surfvid-data.jsx`
- Contains: Pure functions, SVG components, constant data
- Depends on: Nothing (loaded first)
- Used by: All screen components

**Device Shell:**
- Purpose: iPhone frame simulation; routes hardware-button clicks to registered handlers
- Location: `Surfvid/surfvid-device.jsx`
- Contains: `SVDevice` component, portrait/landscape button layout
- Depends on: `window.__svIn`, `window.__svOut` (set by the active screen)
- Used by: `Root` (wraps `SVApp`)

**Application Orchestrator:**
- Purpose: Top-level state, screen routing, clip CRUD
- Location: `Surfvid/surfvid-app.jsx`
- Contains: `SVApp`, `SVDoneToast`
- Depends on: All screen components, `SVMockClips`
- Used by: `Root`

**Screen Components:**
- Purpose: Render one UI screen; own local interaction state only
- Location: `Surfvid/surfvid-paper-library.jsx`, `Surfvid/surfvid-paper-skim-landscape.jsx`, `Surfvid/surfvid-paper-review.jsx`
- Contains: Full-screen layout, sub-components (rows, sheets, HUDs)
- Depends on: `SVIcon`, `SVFilmTile`, `svFmt` (globals), callbacks from `SVApp`
- Used by: `SVApp`

## Data Flow

### Primary User Flow

1. User opens `Surfvid/Surfvid.html` in browser
2. Babel transpiles `.jsx` files; `Root` mounts, renders `SVDevice` + `SVApp`
3. `SVApp` starts in `screen === 'library'`; renders `SVLibraryPaper` inside `SVDevice`
4. User taps a video → `onPick(video)` called → `SVApp` sets `video`, resets `playhead`/`clips`, sets `screen = 'skim'`
5. `SVApp` renders `SVSkimPaperLandscape`; `SVDevice` rotates to landscape
6. `SVHardwareBridgeLandscape` registers `window.__svIn`/`window.__svOut`
7. User drags the video surface → pointer events update `playhead` via `setPlayhead` callback
8. User presses Vol+ button in `SVDevice` → `window.__svIn()` called → `markIn()` sets `pendingIn`
9. User presses Vol- button → `window.__svOut()` called → `markOut()` calls `onAddClip(...)` back in `SVApp`
10. `SVApp` appends new clip to `clips` array
11. User taps "Done" → `screen = 'review'`; `SVApp` passes `clips` to `SVReviewPaper`
12. User trims clips by dragging handles in `SVClipRow`; calls `onUpdateClip(id, patch)` back to `SVApp`
13. User taps "Export" → `SVExportSheet` shown; user picks destination; calls `onExport(dest)`
14. `SVApp.onExport` sets `screen = 'done'`; after 2400ms auto-resets to `'library'`

### State Ownership

```
SVApp (top-level state owner)
  ├── screen: 'library' | 'skim' | 'review' | 'done'
  ├── video: null | { id, title, dur, hue, tone }
  ├── playhead: number (seconds)
  ├── clips: [{ id, videoId, start, end, label }]
  └── exportedTo: null | 'photos' | 'icloud' | 'files' | 'share'

SVSkimPaperLandscape (local state)
  ├── skimming: bool
  ├── velocity: number
  ├── hud: null | 'in' | 'out'
  ├── pendingIn: null | number
  ├── flash: null | { side, t }
  └── chromeHidden: bool

SVReviewPaper (local state)
  ├── activeId: clip id
  ├── exportOpen: bool
  └── destination: string
```

## Key Abstractions

**Hardware Button Bridge:**
- Purpose: Decouple `SVDevice` (the shell) from the active screen's In/Out logic
- Pattern: `window.__svIn` and `window.__svOut` are set by `SVHardwareBridgeLandscape` on mount and deleted on unmount. `SVDevice` calls them blindly.
- Files: `Surfvid/surfvid-device.jsx` (caller), `Surfvid/surfvid-paper-skim-landscape.jsx` (setter)

**Controlled Screen Components:**
- Purpose: All screens are "dumb" — they receive all data and mutation callbacks as props
- Pattern: `SVApp` owns all cross-screen state; screens call `onAddClip`, `onUpdateClip`, `onDeleteClip`, `onExport`, `onBack`, `onDone`, `onPick`

## Entry Points

**HTML Entry:**
- Location: `Surfvid/Surfvid.html`
- Triggers: Browser open
- Responsibilities: Loads CDN scripts, loads all `.jsx` files in dependency order, mounts `Root` via `ReactDOM.createRoot`

**Script Load Order (dependency order):**
1. `surfvid-shared.jsx` — utilities, no dependencies
2. `surfvid-data.jsx` — mock data, no dependencies
3. `surfvid-device.jsx` — device frame, no component deps
4. `surfvid-paper-library.jsx` — depends on `SVFilmTile`, `svFmt`, `SVMockVideos`
5. `surfvid-paper-skim-landscape.jsx` — depends on `SVIcon`, `svFmt`
6. `surfvid-paper-review.jsx` — depends on `SVIcon`, `svFmt`
7. `surfvid-app.jsx` — depends on all screens, `SVMockClips`
8. Inline `Root` script in `Surfvid.html` — depends on `SVDevice`, `SVApp`

## Architectural Constraints

- **Threading:** Single-threaded browser event loop. No Web Workers.
- **Global state:** `window.__svIn`, `window.__svOut` (mutable, set by active skim screen), `SVIcon`, `SVFilmTile`, `svFmt`, `SVMockVideos`, `SVMockClips`, all component functions (all exposed via `Object.assign(window, {...})`)
- **Circular imports:** Not applicable — no module system; all files share a single global scope
- **No module system:** There is no `import`/`export`. All symbols are globals on `window`. Load order in `Surfvid.html` is the only dependency management.
- **In-browser transpilation:** Babel Standalone runs at page load. Cold-start is slower than a pre-compiled bundle but acceptable for a prototype.

## Anti-Patterns

### Global Namespace Pollution

**What happens:** Every component and utility is exported via `Object.assign(window, {...})` at the end of each `.jsx` file. All names (`SVApp`, `SVDevice`, `svFmt`, etc.) live on `window`.

**Why it's wrong:** Name collisions are silent. No tree-shaking. No IDE import completions.

**Do this instead:** Introduce a module bundler (Vite, esbuild) and use ES module `import`/`export`. Each file would `import { SVIcon, svFmt } from './surfvid-shared.jsx'`.

### Hardware Event Bus via `window`

**What happens:** `SVDevice` calls `window.__svIn()` / `window.__svOut()`. `SVHardwareBridgeLandscape` writes to those keys.

**Why it's wrong:** Implicit coupling. If two screens accidentally register handlers simultaneously, only the last one wins silently.

**Do this instead:** Pass `onIn`/`onOut` callback props from `SVApp` down through `SVDevice` (as a render prop or context), eliminating the `window` intermediary.

## Error Handling

**Strategy:** None — this is a prototype. No try/catch blocks, no error boundaries, no fallback UI.

**Patterns:**
- `try { el.releasePointerCapture(e.pointerId); } catch {}` — silently swallows pointer-capture errors in `Surfvid/surfvid-paper-skim-landscape.jsx`
- All other operations assume success

## Cross-Cutting Concerns

**Logging:** None
**Validation:** None — clip start/end are clamped numerically (`Math.min`/`Math.max`) but not validated as types
**Authentication:** None

---

*Architecture analysis: 2026-05-09*
