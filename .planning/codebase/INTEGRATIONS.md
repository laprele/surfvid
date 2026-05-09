# External Integrations

**Analysis Date:** 2026-05-09

## APIs & External Services

**None** — this is a self-contained interactive prototype. It makes no API calls, sends no network requests beyond the initial CDN script loads, and stores no data persistently.

**CDN Dependencies (load-time only):**
- `https://unpkg.com/react@18.3.1/umd/react.development.js`
- `https://unpkg.com/react-dom@18.3.1/umd/react-dom.development.js`
- `https://unpkg.com/@babel/standalone@7.29.0/babel.min.js`

These are script tags in `Surfvid/Surfvid.html` — not runtime API integrations.

## Data Storage

**Databases:** None

**File Storage:** None

**Caching:** None — all state is ephemeral, held in React component state. Refreshing the page resets everything.

**Mock data only:** Video and clip data is hardcoded in `Surfvid/surfvid-data.jsx` as JavaScript constants (`SVMockVideos`, `SVMockClips`).

## Authentication & Identity

**Auth Provider:** None — no authentication layer exists

## Monitoring & Observability

**Error Tracking:** None

**Logs:** None — no logging framework. Browser `console` may be used ad-hoc during development.

## CI/CD & Deployment

**Hosting:** Not configured — the project is a local file prototype

**CI Pipeline:** None — no GitHub Actions, no CI config files

## Environment Configuration

**Required env vars:** None

**Secrets:** None

## Webhooks & Callbacks

**Incoming:** None

**Outgoing:** None

## Browser APIs Used

The prototype uses the following browser-native APIs (no external SDK required):

| API | Where used | Purpose |
|-----|-----------|---------|
| `window.__svIn` / `window.__svOut` | `Surfvid/surfvid-device.jsx`, `Surfvid/surfvid-paper-skim-landscape.jsx` | Cross-component hardware button bridge |
| Pointer Events API (`pointerdown`, `pointermove`, `pointerup`, `pointercancel`) | `Surfvid/surfvid-paper-skim-landscape.jsx`, `Surfvid/surfvid-paper-review.jsx` | Drag-to-skim and trim handle interactions |
| `element.setPointerCapture()` / `releasePointerCapture()` | `Surfvid/surfvid-paper-skim-landscape.jsx` | Keeps drag tracking outside element bounds |
| `performance.now()` | `Surfvid/surfvid-paper-skim-landscape.jsx` | Velocity calculation for skim speed readout |
| `Date.now()` | `Surfvid/surfvid-app.jsx`, `Surfvid/surfvid-paper-skim-landscape.jsx` | Clip ID generation and flash animation keying |
| `setTimeout` | `Surfvid/surfvid-app.jsx`, `Surfvid/surfvid-paper-skim-landscape.jsx` | Auto-dismiss toasts and HUD overlays |
| `Object.assign(window, {...})` | All `.jsx` files | Global symbol registration so sequentially loaded scripts share components |

---

*Integration audit: 2026-05-09*
