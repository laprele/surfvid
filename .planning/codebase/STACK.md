# Technology Stack

**Analysis Date:** 2026-05-09

## Languages

**Primary:**
- JavaScript (JSX) — All application logic and UI components

**Secondary:**
- HTML5 — Single entry point (`Surfvid/Surfvid.html`)
- CSS — Inline styles only (no external stylesheet); global keyframe animations defined in `<style>` block in `Surfvid/Surfvid.html`

## Runtime

**Environment:**
- Browser (no server runtime) — the project is a static, single-page HTML file that runs entirely in the browser
- No Node.js, no build step, no package manager

**Package Manager:**
- None — dependencies are loaded via CDN `<script>` tags in `Surfvid/Surfvid.html`
- No `package.json`, no lockfile

## Frameworks

**Core UI:**
- React 18.3.1 — loaded from `https://unpkg.com/react@18.3.1/umd/react.development.js`
- ReactDOM 18.3.1 — loaded from `https://unpkg.com/react-dom@18.3.1/umd/react-dom.development.js`

**JSX Transpilation (runtime, in-browser):**
- Babel Standalone 7.29.0 — loaded from `https://unpkg.com/@babel/standalone@7.29.0/babel.min.js`
- All `.jsx` files are transpiled in the browser at load time using `<script type="text/babel">`
- No offline build/compile step

**Testing:**
- None — no test framework present

**Build/Dev:**
- None — no bundler (Webpack, Vite, esbuild, etc.)
- No dev server configuration
- Open `Surfvid/Surfvid.html` directly in a browser to run

## Key Dependencies

All dependencies are loaded via CDN with SRI integrity hashes:

| Package | Version | Source | Integrity hash |
|---------|---------|--------|----------------|
| react | 18.3.1 | unpkg | sha384-hD6... |
| react-dom | 18.3.1 | unpkg | sha384-u6ae... |
| @babel/standalone | 7.29.0 | unpkg | sha384-m08K... |

No other third-party libraries — all UI primitives (icons, layout, animation) are hand-rolled inline.

## Configuration

**Environment:**
- No environment variables — this is a fully static prototype with no server
- No `.env` file

**Build:**
- No build configuration files
- No `tsconfig.json`, `.eslintrc`, `.prettierrc`, `jest.config.*`, or `vite.config.*`

## Platform Requirements

**Development:**
- Any modern browser with ES2020+ support
- No install step — open `Surfvid/Surfvid.html` directly

**Production:**
- Static file hosting only (e.g., GitHub Pages, any CDN)
- No server-side requirements

---

*Stack analysis: 2026-05-09*
