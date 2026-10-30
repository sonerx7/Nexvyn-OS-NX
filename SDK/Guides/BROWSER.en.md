# Nexvyn OS Browser: the "full HTML/JS like Chrome" goal

[Türkçe](BROWSER.tr.md) · **English**

This document explains how far a Chrome-level browser is possible on the Switch, the engines that were researched
(with sources), the path chosen for Nexvyn OS and the results of the `tests/web/` test pages.

## 1. Short answer

Running **all of current Chrome** (Blink + V8 JIT + GPU-accelerated drawing + the media stack) on the console, inside a
single `NexvynOS.nro` and under the GPL-3.0-or-later license, is not realistic with this hardware and these license
terms:

- Blink/Chromium is tens of millions of lines and depends deeply on POSIX/GL/audio/network layers; there is no version
  ported to devkitA64 + newlib + libnx.
- In homebrew apps most of the memory is available in title mode; in applet mode there is much less. A single tab of a
  modern site can want hundreds of MB.
- A JIT JS engine (V8) needs executable memory; this is only possible in special runtimes (see Brewser).

So Nexvyn OS takes a **hybrid** path:

1. **Full browser (WebKit)**: the console's own WebKit-based web applet (NetFront NX). While Nexvyn OS runs in title
   mode, sites that strain the engine open in this applet with one tap; closing it returns to Nexvyn OS.
2. **Our own engine**: an HTML/CSS/JS engine on QuickJS (`source/web/`). This work added CSS variables, real flexbox,
   CSS grid, SVG, `<canvas>` 2D, private tabs and link navigation with the gamepad.

## 2. Research

### 2.1 The Switch's built-in web applet (WebKit / NetFront NX)

- The Switch has no normal browser open to the user; web content is shown with browser applets. The engine is the
  WebKit-based **NetFront NX**. The WebKit version in the User-Agent depends on the system version: `AppleWebKit/601.6`
  on 1.0.0-6.1.0, `606.4` on 10.0.0, `613.0` on 20.1.0 and later (and on Switch 2).
  ([Switchbrew: Internet Browser](https://switchbrew.org/wiki/Internet_Browser))
- WebKit 613 roughly matches the Safari 15.4 era: ES2021 JavaScript, flexbox/grid, CSS variables, `<video>` (in
  whitelisted applets), Web Audio and similar features are there. The state of WebGL and JIT is not documented on
  Switchbrew.
- The general-purpose applet is `WebApplet` (010000000000100A). The whitelist only limits page navigation; `<video>` and
  JS network requests are not affected. Applets do not mount the SD card. The applet heap is 0x15600000 bytes
  (~342 MB). ([Switchbrew: Internet Browser](https://switchbrew.org/wiki/Internet_Browser))
- The libnx API: `webPageCreate`, `webConfigSetWhitelist`, `webConfigSetPointer`, `webConfigSetTouchEnabledOnContents`,
  `webConfigSetPageCache`, `webConfigSetWebAudio`, `webConfigShow`, and on return `webReplyGetLastUrl` /
  `webReplyGetExitReason`. ([libnx web.h](https://switchbrew.github.io/libnx/web_8h.html), devkitPro
  `libnx/include/switch/applets/web.h`)
- Limits: the applet can only be opened from a program running as an application (title); homebrew opened from the
  Album (applet mode) and emulators (Ryujinx does not implement the web applet) cannot do this. Tools such as BrowseNX
  open the same applet through hbmenu and note that the NRO version has no HTML5 video support.
  ([GameBrew: BrowseNX](https://gamebrew.org/wiki/BrowseNX_Switch))
- While the applet is open, Nexvyn OS waits (the call is blocking); cookies/sessions are not shared with the applet.

### 2.2 Homebrew engines and libraries

| Project | What | License | Status for Nexvyn OS |
|---|---|---|---|
| **NetSurf for NX** (etonedemid, 0.2.0) | Switch port of NetSurf; JS with QuickJS, flexbox, grid, `calc()`, CSS variables; no sticky and no WebGL | NetSurf: **GPL-2.0**; its libraries (LibCSS, Hubbub, libdom) **MIT** | Usable as a separate .nro. Because the NetSurf core is GPLv2, embedding it in GPL-3.0-or-later code needs an "or later" clause; it was not embedded without confirming that. The MIT-licensed LibCSS/libdom/Hubbub are license-compatible. |
| **Brewser** (natureglass) | V8 + JIT, Skia, WebGL1/2 through Mesa; Web MIDI/USB/Serial; ~70-75% of web features according to its developer | **MPL-2.0** | A separate runtime that needs Atmosphère. V8+Skia+Mesa are too large to embed in a single NRO; although MPL-2.0 is compatible with GPLv3, the integration is outside this project's scope. |
| **nx.js** (TooTallNate) | A JS runtime for the Switch with QuickJS + cairo; Canvas 2D, fetch, URL, crypto | **MIT** | Not a browser but an app runtime. The Canvas/fetch ideas served as an example; no code was copied. |
| **litehtml** | An HTML/CSS layout engine; leaves drawing to the app; according to its own README it is not recommended as a full browser engine | **BSD-3-Clause**, HTML parser gumbo **Apache-2.0** | License-compatible. But it has no JS/DOM; our existing QuickJS DOM bindings depend on our own `Node` structure. Switching would be a large rewrite with limited gain. |
| **lexbor** | An HTML5 parser, CSS parser/selector engine in C, no dependencies | **Apache-2.0** | License-compatible (Apache-2.0 is compatible with GPLv3). Our parser is already lenient and keeps raw SVG text; the best candidate for replacing the CSS parser later. |

Sources: [GameBrew: NetSurf for NX](https://www.gamebrew.org/wiki/NetSurf_for_NX_Switch),
[netsurf-switch](https://github.com/etonedemid/netsurf-switch),
[NetSurf license page (mirror)](https://plan9.io/sources/contrib/yk/9front/sys/lib/netsurf/licence.html),
[Debian netsurf copyright](https://sources.debian.org/src/netsurf/3.11-3/debian/copyright),
[GameBrew: Brewser](https://www.gamebrew.org/wiki/Brewser_Switch),
[GBAtemp: Brewser announcement](https://gbatemp.net/posts/10903033/),
[nx.js](https://github.com/TooTallNate/nx.js), [GameBrew: nx.js](https://www.gamebrew.org/wiki/Nx.js_Switch),
[litehtml](https://github.com/litehtml/litehtml), [lexbor](https://github.com/lexbor/lexbor),
[FSF license compatibility list](https://www.gnu.org/licenses/license-list.html).

### 2.3 Evaluation

- **Compatibility ceiling**: for modern sites (Gmail, YouTube, X, Discord, React/Next apps) to really work, a full
  engine is required. On the Switch, the best and cheapest source of that is the system's own WebKit.
- **Our own engine**: fast for news sites, Wikipedia, documents, forums, simple apps and local HTML, and integrated with
  Nexvyn OS (password vault, reader mode, downloads, tabs). The gaps with the most benefit were closed: CSS variables
  (almost every modern site sets its colors with them), real flexbox and grid (menus, card grids), inline SVG (icons),
  canvas 2D (charts, simple games).
- **Replacing the parser/layout with lexbor or litehtml**: possible license-wise; but the DOM/JS bindings, the thread
  snapshots and the font measurement cache depend on our own data structures. Replacing them in this work would have
  brought less gain and more risk than the features added in the same time.

## 3. What was done

### 3.1 Hybrid browsing: "Full browser (WebKit)"

- **Compatibility detector** (`Page::compatibility()`): it scores many scripts on a page with almost no text (an app
  built only with JS), `<video>/<audio>`, WebGL/WebGPU, `<canvas>`, "enable JavaScript" warnings, React/Next/Angular/
  Nuxt/Gatsby/Svelte markers, repeated script errors and JS being turned off for the site. With a score of 3 or more, a
  suggestion bar with the reason appears at the top of the page.
- The bar has **Full Browser (WebKit)** and **Always Open This Way** buttons. Per-site preference: every time you go to
  that site, the tab shows an "Opened in the full browser" page and the applet opens; there are "Open here this time"
  and "stop opening this site in the full browser" options.
- The applet starts with the pointer, touch, page cache and Web Audio on. When it closes, the address the applet showed
  last (`webReplyGetLastUrl`) is written to history; if you went to a different page, an "open that page here"
  notification appears.
- **When it is unavailable** (applet mode / emulator), "Why is WebKit not available?" appears instead of the button and
  explains the reason.
- Settings > General: "Suggest the full browser", "Always open <site> in the full browser".
- Share menu and right-click menu: "Open in Full Browser (WebKit)", "Always Open This Site in the Full Browser".

### 3.2 Engine (source/web)

- **CSS variables**: `--name: value` definitions are layered per element (elements that do not change share their
  parent's layer, so Tailwind's universal resets stay cheap); declarations that use `var()` are re-parsed in the
  cascade once the variables are known. Nested `var()`, fallback values and cycle protection are there.
- **prefers-color-scheme**: tied to the "Ask sites for a dark theme" setting (CSS and `matchMedia`).
- **Flexbox (row)**: `flex-grow/shrink/basis`, the `flex` shorthand, `flex-wrap`, `row-reverse`, `gap`,
  `justify-content` (start/end/center/space-between/around/evenly), `margin: auto`, `align-items` and `align-self`
  (stretch/start/end/center), vertical centering in a fixed-height container, text nodes as anonymous items.
  Column flexbox: `gap` and `align-items: center/end`.
- **CSS grid**: `grid-template-columns` (px/%/em, `fr`, `auto`, `minmax()`, `repeat(n, …)`,
  `repeat(auto-fill|auto-fit, …)`), `gap`, `grid-column` (`span n`, `a / b`, `1 / -1`), automatic placement row by row.
- **SVG**: `<img src=*.svg>` and `data:image/svg+xml` are drawn sharply with SDL_image's nanosvg at up to 4 times the
  CSS size; inline `<svg>` is no longer hidden but drawn as an image (`currentColor`, default fill = text color,
  `<use href="#id">` icon sprites are resolved from other inline SVGs too).
- **WebP**: since SDL_image 2.0.4 is built with libwebp, still WebP is already decoded (no animated WebP).
- **Canvas 2D**: paths, curves, arcs, `roundRect`, `Path2D`, transforms, `save/restore`, nonzero/evenodd fill, strokes
  (joins and caps approximated with discs), `fillRect/strokeRect/clearRect`, `globalAlpha`, `destination-out`,
  `fillText/measureText` (with the system font, as a layer on top of the bitmap), `getImageData`, `putImageData`,
  `drawImage` from another canvas, `isPointInPath`. The anti-aliased rasterizer is in C++.
- **Private cookie jar and storage**: separate cookies and Web Storage for private tabs that are not written to disk.
- `CSS.supports()` reports the properties the engine really lays out.

### 3.3 The Browser app

- **Private tab** (Ctrl+Shift+N, link menu): no history, session or closed-tab records are kept; separate cookies and
  storage; deleted when the last private tab closes. A purple mark in the tab strip and the address bar.
- **Link navigation with the gamepad**: the D-pad moves a focus ring to the nearest link and the pointer moves onto
  the link (opened with A); if there is no link nearby, the page scrolls. Keyboard arrows scroll as before.
- **Ctrl+W**: because the shell turns Ctrl+W into a window close request, the browser refuses the request when there
  is more than one tab and closes the active tab; with a single tab the window closes (like other browsers). The menu
  label is correct.
- Bug fix: deleting a bookmark / reading list item from the generated pages always deleted the first item.
- Already there (unchanged): tab previews, address bar suggestions, the bookmarks bar and manager, history search, the
  download manager, find in page, zoom, reader mode, per-site JS and desktop identity, error pages, the password vault.

### 3.4 Startup and responsiveness

The owner reported that opening the Browser hung and showed "Loading" for a long time. Causes found in the code (the
console could not be used during the work, so the times below are estimates for the Cortex-A57 and the SD card; the
log now has a `browser` timeline to measure them on the console):

| Cause | Before | After |
|---|---|---|
| `onStart` ran while the whole shell waited: history, bookmarks, reading list, session and the cookie jar were parsed on the main thread; the cookie loader checked duplicates pairwise (3000 cookies: ~4.5 million comparisons) | ~150-400 ms with a used profile, before the window appeared | only `prefs.json` (~5-10 ms); the rest is parsed on web workers in parallel and the first tab opens when the data and cookies are in (a spinner meanwhile); duplicates through a hash set |
| The password store derived its key at startup (PBKDF2-HMAC-SHA256, 2 x 20000 rounds) | ~30-80 ms on the main thread | on a worker |
| The JavaScript prelude (148 KB) was compiled on the main thread by the first page with scripts; every external script was parsed on the main thread (not interruptible) | ~100-250 ms for the prelude, ~0.3-1 s freeze per large bundle | prelude compiled on a worker at startup; scripts of 8 KB and more are compiled on a worker with its own QuickJS runtime, the page only loads the bytecode; 12 MB bytecode cache for bundles used again |
| Layout asked for the metrics of the whole ASCII range for every font size (~97 glyphs to rasterize per size) and measured 4 ms per frame; after 1.5 s without input the shell drops to 20 frames a second, so the exact relayout waited for seconds | ~700-900 glyphs on the start page, ~3-6 s until the exact layout | only the characters the text uses (40-60 % fewer), 7 ms per frame, and the window keeps the full frame rate while a page works |
| First paint waited up to 4 s for parser scripts; images could take all three shared network connections ahead of style sheets and scripts | up to 4 s of "Loading" | at most 2 s; images take one connection until style sheets and parser scripts are in |
| Every visited page rewrote `history.json` (up to 1500 entries) on the main thread; DOM snapshots of script pages copied script sources for every relayout | 30-80 ms hitch per page; large copies | batched, written on a worker; script / style text is not copied and relayouts are spaced by the copy's cost |

Session restore already loaded only the active tab (the others load when shown). No network or DNS call runs on the
main thread (`net` uses its worker threads).

### 3.5 Effects and motion

- **2D transforms** (`translate`, `scale`, `rotate`, `skew`, `matrix`, their X / Y / 3d forms, `transform-origin`,
  `calc()` with % and px): elements with effects become *paint groups*. A translation is drawn as an offset; a
  rotation, scale or skew draws the group once into a texture (sharp up to 2x) and then as a transformed quad.
  Clicks and form widgets follow the transform; transformed content is culled by its transformed bounds. `rotateX/Y`
  without perspective flatten into a scale.
- **Transitions**: `transition` and its longhands (property, duration, timing: `ease*`, `linear`, `cubic-bezier`,
  `steps`, delay) for `opacity`, `transform`, `color`, `background-color`, `border-color`, `width`, `height`,
  `top/left/right/bottom`. They start when a computed value changes after a restyle (class or style change from a
  script); `transitionrun/start/end` reach scripts.
- **Animations**: `@keyframes` and every `animation-*` property (name, duration, timing per keyframe segment, delay,
  iteration count, direction, fill mode, play state); `animationstart/iteration/end` events. Only width / height lay
  the page out again; the rest is applied while painting. Frames are requested only while something animates.
- **prefers-reduced-motion** follows Settings > Appearance > Reduce Motion (CSS and `matchMedia`).
- **Paint**: real `opacity` (whole group), `box-shadow` (soft outer shadows, inset shown as a rim), `linear-gradient`,
  `radial-gradient` and repeating gradients (also inside `background`), `overflow: hidden` clipping (rectangular),
  `position: relative` offsets, `position: sticky` (top), `z-index` and stacking order.
- **Layout**: `grid-template-rows`, `grid-template-areas`, `grid-area`, `grid-row` (spans), explicit line placement,
  flex `order`, `align-content` / `place-content` for wrapped lines, `inset/right/bottom`; `@supports` conditions are
  evaluated (`not`, `and`, `or`, `selector()`).
- **JS**: `Element.animate()` on the engine's animator (`finished`, `cancel`, `pause`, `play`, `reverse`, `finish`,
  `onfinish`), `requestAnimationFrame` at 60 Hz, `getComputedStyle` for `transform` (the animated matrix too),
  `opacity`, `z-index`, `transition-*`, `animation-*`, a real `IntersectionObserver` (thresholds, `rootMargin`,
  checked after each layout, on scroll and resize).

## 4. Test pages and results

The pages under `tests/web/` (on the computer `python -m http.server 8000`, from the console
`http://<ip>:8000/`):

| Page | Contents |
|---|---|
| `js_dom.html` | 34 automatic tests, a PASS/FAIL table |
| `css.html` | CSS features with green/red boxes |
| `layout.html` | 16 flexbox/grid layouts, with the expected look described |
| `canvas.html` | Drawings, 7 pixel tests, a `requestAnimationFrame` animation |
| `svg.html` | Inline SVG, `currentColor`, `<use>`, gradients, data-URI SVG, WebP |
| `effects.html` | 15 automatic tests (transform / animation values, events, `Element.animate`, `IntersectionObserver`, 60 Hz frames) and visual sections |
| `layout2.html` | Grid areas and rows, spans, `order`, `align-content`, `calc` / `clamp` / `min`, `place-content` |
| `heavy.html` | A synthetic heavy page (2000 cards, `?n=` for more) with its build and first-frame times in the title |

**Important note:** neither the console nor the emulator could be used during this work (the emulator was with the
coordinator). The "Expected" column below is based on reviewing the code and running the canvas context in Node.js
with mock native functions. When `js_dom.html` is opened on the console, the title shows "JS x/34"; the real results
should be entered in this table.

| Area | Test | Expected |
|---|---|---|
| DOM | querySelector(All), matches/closest, classList, dataset, create/append/insertBefore/remove, innerHTML/outerHTML | PASS |
| Events | capture → target → bubbling order, stopPropagation/preventDefault, CustomEvent | PASS |
| Timers | setTimeout, setInterval/clearInterval, requestAnimationFrame, microtask order, async/await | PASS |
| Storage | localStorage, sessionStorage (memory only in a private tab) | PASS |
| Navigation | history.pushState/replaceState, URL/URLSearchParams | PASS |
| Network | fetch (same-origin JSON), XMLHttpRequest, AbortController | PASS (over http; SKIPPED with sdmc:) |
| Other | TextEncoder/Decoder, MutationObserver, FormData, matchMedia, CSS.supports, structuredClone, crypto | PASS |
| JS language | ES2020/ES2022 (QuickJS-ng) | PASS |
| Canvas | getContext('2d') + getImageData | PASS |
| WebGL | getContext('webgl') | FAIL (expected: not there → the full browser is suggested) |
| CSS | var() (5 boxes), @media, prefers-color-scheme, calc/clamp, hsl/rgb, :nth-child, :is/:not, [attr^=], !important, @supports | Green |
| Layout | flexbox 1-11, grid 12-15, flex with variables 16 | As described |
| SVG | inline, currentColor, `<use>` sprite, linearGradient, data-URI SVG, WebP | Visible |
| Effects | `effects.html` 1-15: computed transform / opacity / z-index / animation-name / transition-duration, animated value changes, rAF ~60 Hz, transitionend, animationstart / iteration / end, `Element.animate` finished and cancel, IntersectionObserver, CSS.supports, matchMedia reduced motion | PASS (expected; the rAF test depends on the frame rate the page gets) |
| Layout 2 | `layout2.html` 1-6 | As described |

### Not supported (on purpose)

- `position: absolute/fixed` are still laid out in the normal flow (only their offsets animate); no 3D (perspective,
  `rotateX/Y` are flattened), no rounded clipping of content other than images, `filter` / `backdrop-filter`,
  `clip-path` shapes, `:hover` styles, the `transitionend` of a property whose element leaves the layout.
- A transition starts after the restyle is laid out (one layout later than in desktop browsers); transitions to
  `auto` sizes and from / to a transparent background without a box jump. Element.animate has no `currentTime`
  seeking, `playbackRate` or composite modes.
- `grid-auto-flow: dense`, `fr` rows, `subgrid`, `masonry`.
- Canvas: `clip()`, gradients (painted with the average color), patterns, shadows, `drawImage` from an `<img>`,
  `toDataURL`.
- `<text>` inside SVG, painting with CSS classes, filters.
- Web fonts (`@font-face`), `<video>/<audio>`, WebGL, Service Worker, WebSocket, WebAssembly. The full browser
  (WebKit) is suggested for sites that need these.
