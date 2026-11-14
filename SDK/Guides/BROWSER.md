# Nexvyn OS Browser: the "full HTML/JS like Chrome" goal

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

Since 1.2.4 Nexvyn OS has one browser: its own engine (the console's system web applet is no longer used).

- **Our own engine**: an HTML/CSS/JS engine on QuickJS (`source/web/`). This work added CSS variables, real flexbox,
  CSS grid, SVG, `<canvas>` 2D, private tabs and link navigation with the gamepad.
- Sign-in pages for apps (`net.oauth`) open in a tab of this browser; the tab closes when the page reaches the app's
  redirect address.

## Loading indicator and lightweight developer console

A thin bottom-edge bar shows navigation progress. An unknown transfer length uses a moving marker;
the first visible content and the remaining page resources are separate stages.

Open the console with **F12**, **Ctrl+Shift+J**, or **View > Developer console**. It shows the last 200
JavaScript messages, errors/warnings, failed CSS/HTTP requests and loading timings, with an errors
filter, clear and clipboard copy. Enter `document.title` or `typeof ReadableStream` in the bottom
field to evaluate it in the page's JavaScript environment. Commands have time and length limits.
The optional panel is a small diagnostic console, not full Chrome DevTools.

In the source checkout, `tests/run_browser.ps1` checks engine/loading policies and `tests/run_net.ps1`
tests the real network code against a loopback HTTP server. These do not verify live sites or console hardware.

## 2. Research

### 2.1 The Switch's built-in web applet (history)

Until 1.2.3 Nexvyn OS could hand a page to the console's web applet (WebKit-based NetFront NX). It was removed in
1.2.4: the user wants one browser, and the applet needed title mode, stopped consoles on untested system versions
and shared no cookies with the OS. The research notes are not kept here.

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
  engine is required. Nexvyn OS builds that engine step by step itself.
- **Our own engine**: fast for news sites, Wikipedia, documents, forums, simple apps and local HTML, and integrated with
  Nexvyn OS (password vault, reader mode, downloads, tabs). The gaps with the most benefit were closed: CSS variables
  (almost every modern site sets its colors with them), real flexbox and grid (menus, card grids), inline SVG (icons),
  canvas 2D (charts, simple games).
- **Replacing the parser/layout with lexbor or litehtml**: possible license-wise; but the DOM/JS bindings, the thread
  snapshots and the font measurement cache depend on our own data structures. Replacing them in this work would have
  brought less gain and more risk than the features added in the same time.

## 3. What was done

### 3.1 Compatibility hints

- **Compatibility detector** (`Page::compatibility()`): it scores many scripts on a page with almost no text (an app
  built only with JS), `<video>/<audio>`, WebGL/WebGPU, `<canvas>`, "enable JavaScript" warnings, React/Next/Angular/
  Nuxt/Gatsby/Svelte markers, repeated script errors and JS being turned off for the site. The score is kept for
  diagnostics.
- For a few heavy sites the top bar offers the lighter version of the site (`Lite Version`) or Tube for YouTube videos.
- Bookmarks bar: off on a new install; users who already had the browser keep it on (Browser > View).

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
- **Canvas 2D**: paths, curves, arcs, `ellipse`, `roundRect` (radii arrays and points), `Path2D`, transforms, `save/restore`,
  nonzero/evenodd fill, real strokes (`lineJoin` miter / round / bevel, `miterLimit`, `lineCap`, `setLineDash` with
  `lineDashOffset`), `fillRect/strokeRect/clearRect`, `globalAlpha`, `getImageData` / `putImageData` (dirty rects) / `ImageData`,
  `isPointInPath` (both fill rules) and `isPointInStroke`. Linear, radial and conic gradients, patterns (canvas or `<img>`),
  `clip()` with the `save/restore` stack, all 26 composite operations (Porter-Duff and blend modes), real `shadowBlur`
  (gaussian approximation, bounded cost), the `filter` property (`blur`, `brightness`, `contrast`, `grayscale`, `sepia`,
  `saturate`, `invert`, `opacity`, `hue-rotate`, `drop-shadow`), `imageSmoothingEnabled` / `imageSmoothingQuality`.
  Text (`fillText`, `strokeText` outline, `textAlign`, `textBaseline`, `direction`, `maxWidth`, `measureText` with the real
  ink box) is rasterized with the system font into the bitmap, so `getImageData`, `drawImage` and `toDataURL` see it.
  `drawImage` / `createPattern` / `createImageBitmap` take `<img>` (also `new Image()` with `onload`, data, http and blob URLs),
  canvases, `ImageBitmap` and `Blob`; cross-origin pictures are not tainted, so apps keep working. `toDataURL` / `toBlob` /
  `OffscreenCanvas.convertToBlob` write PNG or JPEG (quality parameter); other types give PNG. `getContext('2d', {alpha:false})`
  makes an opaque bitmap. Setting `width` / `height` (even to the same value) clears the canvas and resets the context. The
  rasterizer, stroker, blur, filters and the PNG / JPEG encoders are C++ (`web_canvas.cpp`) with host unit tests.
  Limits: video frames cannot be drawn, text uses the sans fonts (bold or regular), a canvas is at most 4096 px a side and
  16 MB (and smaller when the OS is short of memory), `isPointInStroke` treats joins and caps as round.
- **ES modules** (1.3.0): `<script type="module">` (deferred, in document order), static `import` / `export`, dynamic
  `import()` (also from classic scripts), `import.meta.url`, top-level `await`, `nomodule`, `<script type="importmap">`
  (`imports`, `scopes`) and JSON modules. QuickJS resolves imports synchronously, so a module's whole graph is
  downloaded and cached first (relative, absolute and `data:` URLs, 48 MB / 2000 modules at most); a missing module or an
  unmapped bare name rejects the promise and the page keeps running.
- **Web Workers** (1.3.0): `new Worker(url, {type, name})` with `http(s):`, local, `blob:` and `data:` scripts and module
  workers. Each worker is a thread (below the main thread) with its own QuickJS runtime and its own lock: nothing it
  waits on is held by the main thread. `postMessage` is a structured clone (objects, arrays, Map, Set, Date, RegExp,
  typed arrays, BigInt, cycles) with transferable `ArrayBuffer`s; `onmessage` / `onerror`, `terminate()`, `close()`,
  `importScripts`, `fetch` (done by the page: cookies, `blob:` and `data:` work), timers, `performance.now`,
  `TextEncoder` / `TextDecoder`, `URL`, `crypto.getRandomValues`, `atob` / `btoa` inside. Limits: 4 workers at a time
  (a fifth `new Worker` throws `QuotaExceededError`), 24 MB of script memory each, a callback that runs 4 s ends the
  worker with an error event (the page never waits for it), workers end with their page. Not there: `SharedWorker`,
  `SharedArrayBuffer`, `import()` and IndexedDB inside a worker, posting `Error` objects or functions.
- **IndexedDB** (1.3.0): `indexedDB.open` / `deleteDatabase` / `databases` / `cmp`, versions with `upgradeneeded`,
  object stores (key paths, key generators), indexes (unique, `multiEntry`, compound key paths), transactions
  (`readonly`, `readwrite`, abort rolls back), `get` / `getKey` / `getAll` / `getAllKeys` / `count` / `put` / `add` /
  `delete` / `clear`, cursors in all four directions (`continue`, `advance`, `continuePrimaryKey`, `update`,
  `delete`), `IDBKeyRange`. Values are structured clones. Each origin has its own files in the Browser's storage folder
  (private tabs keep theirs in memory); opening reads the file on a background thread and changes are written back
  there a moment after the last commit, never on the main thread. At most 32 MB per database; "clear browsing data"
  deletes them. Transactions of a page run one after another.
- **WebAudio** (`AudioContext`, `webkitAudioContext`, `OfflineAudioContext`): `GainNode`, `OscillatorNode` (sine, square,
  sawtooth, triangle), `AudioBufferSourceNode` (loop, playback rate, start offset, `onended`), `AudioBuffer`,
  `decodeAudioData` (wav, ogg, mp3, flac, decoded on a worker), `BiquadFilterNode` (lowpass, highpass, bandpass, shelves,
  peaking, notch, allpass), `DelayNode`, `StereoPannerNode`, `AnalyserNode`, `DynamicsCompressorNode`, and `AudioParam`
  automation (`setValueAtTime`, linear and exponential ramps, `setTargetAtTime`, `setValueCurveAtTime`, cancel). The graph
  renders on one low-priority thread per context into a ring buffer that the OS mixer reads; the page's thread only
  posts commands (no shared locks). Limits: 4 contexts, 4096 nodes and 96 voices per page. Not supported: spatial
  `PannerNode` (a pass-through stand-in), `ScriptProcessorNode`, `AudioWorklet`, `MediaStream` nodes; `<audio>` elements
  keep their own output (`createMediaElementSource` returns a silent stand-in). Autoplay rules are a no-op: a context
  starts running and `resume()` always works.
- **WebGL 2** (`getContext('webgl2')`, `WebGL2RenderingContext`): vertex array objects, instancing (`drawArraysInstanced`, `drawElementsInstanced`, `vertexAttribDivisor`, `drawRangeElements`), integer attributes, uniform buffer objects (`getUniformBlockIndex`, `uniformBlockBinding`, `bindBufferBase/Range`, block queries), `copyBufferSubData` / `getBufferSubData`, 3D and 2D-array textures (`texImage3D`, `texStorage2D/3D`), sampler objects, multiple render targets (`drawBuffers`, `framebufferTextureLayer`, `blitFramebuffer`, `readBuffer`, `invalidateFramebuffer`), float and integer color formats (`EXT_color_buffer_float`), occlusion queries, sync objects (emulated: `clientWaitSync` waits with `glFinish`) and transform feedback. GLSL ES 3.00 and 1.00 shaders go to the OpenGL ES 3 driver as written (`web_glsl3.cpp` can also translate them to GLSL 430 for a desktop-only host); compile errors come back in `getShaderInfoLog`. Extensions follow what the host offers (`EXT_color_buffer_float`, `OES_texture_float_linear`, `EXT_texture_filter_anisotropic`, `WEBGL_compressed_texture_s3tc`). Limits: a context may hold 256 MB of buffers and 3D / array textures; a query or transform feedback must start and end inside one script task (a frame callback); WebGL 1 contexts do not see any of this. Known gaps (not passing on the emulator test host; the context never crashes, calls just return wrong pixels): rendering to a single layer of a 2D-array texture (`framebufferTextureLayer` + clear), sampling 3D textures (`sampler3D`), and `drawArraysInstanced` with a changed vertex array object or instance count; `ANY_SAMPLES_PASSED_CONSERVATIVE` may report samples that did not pass (allowed by the spec). `MAX_TEXTURE_MAX_ANISOTROPY_EXT` reports the host limit (at most 16). These features stay unverified until tried on a real console.
- **Gamepad API**: `navigator.getGamepads()`, `gamepadconnected`, standard mapping (17 buttons, 4 axes; the standard
  layout is by position, so the Switch B button is button 0), dead zone 0.1, `vibrationActuator.playEffect` (the
  console's rumble, strongest of the two magnitudes). The pad appears after the first input, as in other browsers.
  While a page polls the controller it owns the pad (the pad stops moving the pointer); touch still works. Nothing is
  reported while the page is in a background tab or an unfocused window.
- **Fullscreen API**: `element.requestFullscreen()`, `document.exitFullscreen()`, `fullscreenElement`,
  `fullscreenEnabled`, `fullscreenchange` (and the `webkit` names). The window goes fullscreen, the toolbar and tabs hide,
  and the element covers the page. Esc leaves; with a controller, hold B for a moment while the page polls the pad.
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

### 3.6 1.0.2: real-world compatibility

Prioritized by how often real sites depend on it.

| Area | Before (1.0.0) | Now (1.0.2) |
|---|---|---|
| `position: absolute` | laid out in the normal flow | out of the flow, against the nearest positioned or transformed ancestor's padding box: `top/right/bottom/left` (px, %, `calc`), `inset`, stretching between left and right, centering with auto margins, `translate(-50%,-50%)`, static position when offsets are `auto`, nested containing blocks, `%` heights |
| `position: fixed` | in the flow | against the view: stays in place while the page scrolls (headers, cookie bars, toasts, modals); a transformed ancestor holds it as in CSS |
| Stacking | z-index of in-flow groups | positioned boxes paint above the flow in tree order / by z-index; `elementFromPoint` and clicks go to the topmost layer (overlays get the click, not the content below) |
| `calc()` | two terms, `100% - 20px` read as `100%` | full expression: `+ - * /`, parentheses, nested `calc()`, percentage plus length kept exactly (`calc(100% - 2rem - 10px)`), `min()/max()/clamp()` in the cascade, `env()` fallback |
| Units | `vw/vh/vmin/vmax/rem/em` | the same, now also inside `calc` everywhere |
| `:hover` `:focus` `:focus-within` `:focus-visible` `:active` `:target` | never matched | matched (pointer, form focus, controller link focus as `:focus-visible`); a change restyles the page only when some selector puts that pseudo-class on the element whose state changed; `:has()` (descendants / children), `:placeholder-shown` |
| `overflow: auto / scroll` | drawn as `hidden` at best | a scrolling box: drag, wheel and right stick scroll it before the page; per axis (`overflow-x`, `overflow-y`); its content no longer makes the page longer |
| `text-overflow: ellipsis`, `line-clamp` | wrapped text | one line cut with "…"; `-webkit-line-clamp` / `line-clamp` limit the lines and end the last one with "…" |
| `object-fit`, `object-position` | stretched | `fill / contain / cover / none / scale-down` with position (also with rounded corners) |
| `filter` | none | `brightness / contrast / grayscale / sepia / invert / saturate / opacity` on everything drawn (pictures: brightness only); `blur()` and `drop-shadow()` are not drawn |
| `backdrop-filter` | none | the blur is not drawn; a see-through background behind it is made almost opaque so the text stays readable |
| `width / height: fit-content` (max-/min-content) | `auto` | shrink-to-fit |
| `<video>` / `<audio>` | hidden | inline playback with the system media player (FFmpeg: mp4/webm/mkv, mp3/aac/ogg, progressive http(s) and HLS): poster, play button, controls bar (play/pause, time, seek, mute, "Open in Video Player"); one plays at a time, nothing is made before the first play, a hidden tab frees its decoder. `HTMLMediaElement`: `play()/pause()/load()/canPlayType()`, `currentTime`, `duration`, `paused`, `ended`, `volume`, `muted`, `loop`, `playbackRate`, `videoWidth/Height`, `readyState`, `error` and the events `loadstart`, `loadedmetadata`, `canplay`, `play`, `playing`, `pause`, `timeupdate`, `ended`, `error`, `volumechange`. `seeking`, `buffered`, `seekable`, `networkState` and the `seeking`/`seeked`/`waiting` events are real state. MediaSource / SourceBuffer (`blob:` streams, as on YouTube) work for H.264 + AAC fragmented MP4 and WebM (see "Video" below) |
| `<picture>` / `srcset` | first `<source>` with a srcset, ~600 px candidate | the first `<source>` whose `type` is decoded here and whose `media` holds; `srcset` by `sizes` and the width the picture gets (capped at 1280 px for memory) |
| `<dialog>` | `open` attribute only | `show()`, `showModal()` (centered over a dimmed page, focus to `[autofocus]`), `close(value)`, `returnValue`, `requestClose()`, `cancel` / `close` events, Escape, `<form method=dialog>` |
| Forms | text, password, checkbox, radio, select, buttons | plus `range` (slider), `color` (color well), `number` (narrow field), date / time types (field with the format to type), `<progress>`, `<meter>` (low / high / optimum colors) |
| `ResizeObserver` | one callback | checked after every layout; an entry whenever the size changes |
| `matchMedia` | `matches` only | `change` events (`addEventListener`, `addListener`, `onchange`) on resize / zoom |
| `structuredClone` | JSON copy | the clone algorithm: cycles, `Map`, `Set`, `Date`, `RegExp`, typed arrays, errors; functions and nodes throw `DataCloneError` |
| `getBoundingClientRect` | union of the content | a block's own border box, with relative offsets / translations; fixed boxes stay in the view |

Already there and checked by the tests: `fetch` with `Response.json/text/blob/arrayBuffer/formData/clone`,
`URL` / `URLSearchParams`, `localStorage` / `sessionStorage`, Promise / async order, `MutationObserver`,
`requestIdleCallback`, `history.pushState` / `popstate`, `CustomEvent`, `dataset`, `classList`, `closest` / `matches`,
`TextEncoder` / `TextDecoder`, `crypto.getRandomValues` / `randomUUID`, `<details>`, `<template>.content`, inline
`<svg>` and `<img src=*.svg>`, canvas 2D.

### 3.7 Memory, size and "a separate app?"

**Bytecode cache on the SD card.** Big scripts (8 KB and more) are also kept as compiled bytecode in `jscache/` (48 MB, oldest removed first), so a revisit or a restart skips the parse. Setting `web.jsBytecodeCache` (default on); private tabs never use it. A damaged or outdated entry is ignored and recompiled.

**Nothing of the engine runs without a Browser window.** The engine keeps a few things between pages: two worker
threads (1 MB stacks each), a QuickJS compile runtime per worker, the compiled prelude, a bytecode cache (up to
12 MB), the cookie jars, Web Storage and a font metrics cache. Before 1.0.2 these stayed in memory after the Browser
closed. Now `web::releaseEngine()` runs when the window closes (`~BrowserApp`): it saves cookies and Web Storage,
frees all of them, and the workers finish their queued jobs, free their QuickJS runtimes and exit
(`web::stopWorkers()`; the next job starts them again). Pages, layouts, images, canvases and media players go with
their tabs. The log shows it: `engine released: heap A -> B MB`, `workers stopped (2)` and, 3 s later,
`3 s after the Browser closed: heap X MB in use`; `page ready: ... (heap, MB above the Browser's start, JS KB)` for
each page.

| Measurement | Value |
|---|---|
| Engine + Browser code (`web_*.o`, `app_browser.o`, text) | 1.14 MB before, 1.23 MB now (+85 KB) of a 44 MB NRO text; the prelude is 163 KB in romfs |
| PC test setup, empty Browser window + error page | about 5.5 MB of heap above the moment it opened |
| Idle, no Browser window | 0 threads, 0 QuickJS runtimes, caches freed (measured: see the log lines above; the console numbers belong in this table) |

**A separate app from the App Market?** Native modules (`.nxvmod`) are switched off in 1.0.x: stickies, fontbook and
network crashed in `mutexLock` on a lock that lives in module memory (the writable segment is mapped through
`svcControlCodeMemory`, and kernel locking on that memory fails). The Browser would hit exactly that: `web_jobs.cpp`,
`web_layout.cpp` and `app_browser.cpp` keep `static Mutex` / `CondVar` objects, and `web_js.cpp` uses a
`thread_local` compile runtime, which the loader refuses (`PT_TLS`). Making it a module would need (1) the loader to
map the writable segment as ordinary memory (or the module's locks moved to the heap), (2) TLS support or no
`thread_local`, (3) the module tests re-enabled on the PC test setup and on a console. The gain would be about 1.4 MB (code +
prelude) of a 66 MB NRO, and none in RAM, since the code pages of a built-in app cost nothing while it is closed and
the engine now frees its heap. Recommendation: keep the Browser built in (it is also what other apps open links
with); if the owner wants it removable from the lists, the existing optional-app mechanism (`"optional": true`, App
Market "Get", Settings > Apps) can hide it without moving code, but that only changes the lists, not the NRO size.

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
| `compat.html` | 64 automatic checks in four groups (positioning and units, CSS, HTML5 elements, JS APIs) with a PASS/FAIL table; the title shows "Compat x/y" and every result goes to the log (`webjs` lines) |
| `html5.html` | Visual: fixed translucent header with a `:hover` menu, absolute badges and centering, card grid with `object-fit`, ellipsis, line-clamp and filters, horizontal and vertical scrolling boxes, video / audio controls, form controls, `<details>`, modal `<dialog>` |

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
| WebGL | getContext('webgl') | FAIL (expected: not there) |
| CSS | var() (5 boxes), @media, prefers-color-scheme, calc/clamp, hsl/rgb, :nth-child, :is/:not, [attr^=], !important, @supports | Green |
| Layout | flexbox 1-11, grid 12-15, flex with variables 16 | As described |
| SVG | inline, currentColor, `<use>` sprite, linearGradient, data-URI SVG, WebP | Visible |
| Effects | `effects.html` 1-15: computed transform / opacity / z-index / animation-name / transition-duration, animated value changes, rAF ~60 Hz, transitionend, animationstart / iteration / end, `Element.animate` finished and cancel, IntersectionObserver, CSS.supports, matchMedia reduced motion | PASS (expected; the rAF test depends on the frame rate the page gets) |
| Layout 2 | `layout2.html` 1-6 | As described |

### Not supported (on purpose)

- 3D (perspective, `rotateX/Y` are flattened); rounded clipping of content other than images (`overflow: hidden`
  clips to the rectangle); `filter: blur()` / `drop-shadow()` and the backdrop blur; `clip-path` shapes; the
  `transitionend` of a property whose element leaves the layout; `::before` / `::after` generated content.
- A transition starts after the restyle is laid out (one layout later than in desktop browsers); transitions to
  `auto` sizes and from / to a transparent background without a box jump. Element.animate has no `currentTime`
  seeking, `playbackRate` or composite modes.
- `grid-auto-flow: dense`, `fr` rows, `subgrid`, `masonry`.
- Canvas: `drawImage` of a `<video>` frame, per-family fonts in canvas text (only sans regular / bold), `Path2D` from an SVG path string.
- `<text>` inside SVG, painting with CSS classes, filters.
- Web fonts (`@font-face`), Service Worker, WebSocket. DRM video (Widevine, FairPlay, PlayReady) can never play: the
  console has no CDM and `navigator.requestMediaKeySystemAccess` rejects. The sites that need these do not work in this browser.

## WebGL samples

Real WebGL pages run in the Browser under the console profile on the emulator (`NEXVYN_CONSOLE_PROFILE=1`, two emulators
sharing one PC). The frame numbers are **relative** (emulator, not a console): use them to compare builds, never as console fps.
The webglsamples.org demos are BSD-3-Clause (Google); they were served from a local copy that is not part of this repository.

| Sample | Result | Notes (screenshot) |
| --- | --- | --- |
| webglsamples.org dynamic-cubemap | PASS | Chrome-like sphere reflecting a cube map that is re-rendered every frame (6 faces), orbiting camera, no JS errors, about 6 fps in the page counter (0309, 0310) |
| webglsamples.org field | PASS | Grass field, about 18 fps in the page counter (0312) |
| webglsamples.org aquarium | renders, too slow | Fish scene draws, about 1 fps; the page shows "Not Responding" while a frame runs (0313) |
| three.js webgl_materials_cubemap_dynamic | FAIL (speed) | Page and controls load, the canvas stays black: `raf` frames exceed the time budget (0314) |
| three.js webgl_geometry_cube | FAIL (load) | The 1.2 MB module takes about 60 s to load under the profile; black at capture |
| three.js webgl_postprocessing_unreal_bloom | FAIL (speed) | `raf` frames exceed the time budget |
| webgl_loader_gltf, webgl_shadowmap, webgl_instancing_performance, Babylon.js playground | not run | next round |

Engine fixes this round (all general): cube-map faces as render targets (drawn through a 2D shadow texture and copied into
the face, because the emulator sends every draw to layer 0), `copyTexImage2D` / `copyTexSubImage2D`, `texImage2D` /
`texSubImage2D` from `<img>` and `ImageBitmap` (they used to upload a gray pixel), cube-map mip chains built on the CPU (the
host left the lower levels empty), canvas read-back in bands (a single large read returned only the first 256 columns), a
longer budget for the frame callback of WebGL pages, for module evaluation and for fetch completion, and credit for slow
driver calls. Tests: `tests/html5/webgl-cubemap-fbo.html`, `webgl-cube-image.html`.

## Video

What plays (software decoding on the console CPU, `media::Player` / FFmpeg; hardware decoding stays off: `media.hwdec` defaults to off and nothing assumes it):
- Progressive `<video>` / `<audio>`: mp4, webm, mkv, mp3, aac, ogg from http(s) or local files. Events, `currentTime`, `seeking`, `buffered`.
- HLS (`.m3u8`, VOD): the player picks the stream through FFmpeg's HLS demuxer. Target is H.264 up to about 480p.
- MediaSource (`blob:` URL of `new MediaSource()`): `addSourceBuffer` for `video/mp4` (avc1 up to level 3.0, mp4a.40.x) and `video/webm` (VP8, Vorbis);
  `appendBuffer` (async, `updating`, `updateend`), `remove`, `abort`, `timestampOffset`, `appendWindowStart/End`, `buffered`, `endOfStream`,
  `duration`. Data is parsed on a worker thread and held compressed (32 MiB cap per MediaSource, then `QuotaExceededError`); a broken stream only
  fails its own MediaSource. `MediaSource.isTypeSupported`, `canPlayType` and `navigator.mediaCapabilities.decodingInfo` answer the same way, so
  adaptive players choose a rung the console can decode (VP9, Opus, AV1 and H.264 above level 3.0 are reported unsupported unless `media.mse.vp9`,
  `media.mse.opus` or real-hardware `media.hwdec` are on).

Limits:
- DRM / EME is impossible: no CDM; `requestMediaKeySystemAccess` rejects. Rented or protected streams never play.
- 720p and above are not smooth in software decoding; 1080p needs hardware decoding that has not been verified on a console.
- Not done: `requestVideoFrameCallback`, text tracks (WebVTT), Picture-in-Picture, `ManagedMediaSource`, real-site YouTube end to end (the player script
  itself is heavy for the JS engine). Adaptive HLS bit-rate switching outside MSE is the FFmpeg default (first variant).
- Tests: `tests/html5/video-play.html`, `video-hls.html`, `video-mse.html` use self-generated clips (`tools/gen_html5_video.py`, no third-party media).
- **Custom elements and Shadow DOM (basic)**: `customElements.define/get/whenDefined/upgrade/getName` upgrade existing and new elements (constructor, `connectedCallback`, `disconnectedCallback`, `attributeChangedCallback` with `observedAttributes`). `attachShadow()` returns a flattened shadow root (a `display:contents` box that is the host's first child; `host`, `mode`, `shadowRoot` work, `<slot>` projection and style scoping do not).
- **EME (ClearKey only)**: `navigator.requestMediaKeySystemAccess('org.w3.clearkey')`, `MediaKeys`, `MediaKeySession` (`generateRequest`, `update` with the ClearKey JSON license, `keystatuseschange`), `video.setMediaKeys()` and the `encrypted` event for CENC fMP4 in MSE. The demuxer decrypts cenc-aes-ctr with the key from the page's license (one key per MediaSource). Widevine, PlayReady and FairPlay reject with `NotSupportedError`: they need a content decryption module that is not available here and is not faked. Test: `tests/html5/eme-clearkey.html`.

## Signing in to sites

The cookie rules follow RFC 6265bis (`source/web/web_cookies.cpp`, host tests in `tests/test_cookies.cpp`):

- `Set-Cookie` of every redirect hop (301, 302, 303, 307, 308) is stored before the next request, so a sign-in that sets its
  session cookie on the redirect works. A `303`, or a `301` / `302` after a `POST`, becomes a `GET`; `307` / `308` keep
  method and body.
- `SameSite` Lax / Strict / None, `Secure` (https only, `SameSite=None` needs it), `__Secure-` / `__Host-` prefixes,
  `Domain` and `Path` matching with a public-suffix list, `Max-Age` before `Expires`, a 400-day cap, `HttpOnly` (hidden from
  `document.cookie`, scripts cannot set or replace it), limits of 4096 bytes per cookie, 180 per domain and 3000 in all.
  A cookie without `SameSite` behaves as Lax, and still goes on a cross-site top-level `POST` for 2 minutes (single sign-on
  that posts back to the site).
- **Third-party cookies** (Settings > Privacy, "Block third-party cookies", on by default): images, stylesheets and script
  requests to another site than the page's send and store no cookies. A site that a cross-site sign-in redirect led through
  is exempt for the rest of the session.
- Cookies with an expiry and `localStorage` stay across a restart and an OS update (older cookie files load unchanged).
  "Clear site data" per site removes the cookies and the Web Storage of that site and its subdomains; "Clear browsing data"
  removes everything.
- HSTS: a site that sent `Strict-Transport-Security` is only reached over https for the rest of the session.
- Forms: `GET` and `POST` with `application/x-www-form-urlencoded`, `multipart/form-data` or `text/plain` (`enctype`,
  `formenctype`), hidden fields, `required` (an empty required field blocks the submit; `novalidate` / `formnovalidate`
  turn it off), Enter and `requestSubmit()`. Password fields have a show / hide button; `type=number` shows the numeric
  keyboard.
- Password manager: the save offer appears only after the sign-in worked (the tab left the form, or the form is gone), never
  for a wrong password and never in a private tab. Passwords fill for the exact origin only. The Passwords sheet has an "Open
  site and sign in" button. Passwords and cookies are never logged.
- Errors: a certificate problem shows a "Secure connection failed" page with no way around it; a timeout shows a page with
  Retry.

Local test: `python tests/html5/login_server.py` serves a sign-in form with a CSRF token, cookie flags, a redirect chain, a
2FA page and an OAuth redirect; `python tests/html5/run_login_ryu.py` runs the pages in the emulator. The only credential is
a fake pair that works on that server alone.

**Page errors and layout fixes.** Script errors and `console.error` lines in the browser log now carry the source URL with line:column, and a script that runs out of its time budget is logged with its URL. CSS: `mask-image` / `-webkit-mask-image` with a data: or http(s) picture (the picture's shape is painted in the background color, rasterized once and cached), cascade layers (`@layer`: unlayered rules beat layered ones, later layers beat earlier ones, `!important` reverses), `min-width: max-content` (flex items no longer shrink below their natural width), and `grid-template-columns: minmax(0, auto)` is sized by content instead of collapsing to zero (this made button labels wrap one letter per line). Test page: `tests/web/flex-mincontent.html`.

**Desktop sites by default.** The Browser now asks for desktop sites (Chrome-like desktop identity, `(hover: hover)` / `(pointer: fine)` media features, `navigator.platform` `Win32`, no touch points). Settings has "Request mobile sites" (off by default) and a per-site switch in the address-bar menu (the old "desktop by default" value is not read, so updating users get desktop sites; saved zoom is kept). Zoom and device pixel ratio are unchanged. Known gaps (checked on the console profile): github.com still shows a black header band and the compact layout (container queries and some custom properties are not supported yet); en.wikipedia.org stays unstyled for about 40 s because its loader script is cut by the 1 s script budget; old.reddit.com redirects signed-out visitors to a sign-in page and needs `CSSStyleSheet`.

## Performance and memory

- Background tabs run nothing (no JS timers, no rAF, no media); when a tab goes to the background its textures, canvases and players are freed and its JS garbage is collected once.
- Free memory of old tabs (Browser settings, `browser.discardTabs`, default on): with more than 3 (applet mode) or 6 live background tabs, the least recently used ones are closed in memory. When the OS reports low memory, all background tabs and most idle images go. A discarded tab keeps its address, history and scroll position and reloads when shown. Private tabs, loading tabs, POST pages and `about:` pages are never discarded.
- Stalls: a frame longer than `perf.stallMs` (default 150 ms) writes one `stall` line in the system log naming the phase (`web page parsed`, `web js start`, `web js tick`, `web layout start`, `web job done` = network/image completion, `web paint`) and the page address. Probe: `python tools/browser_stall.py`.
- Measurements use the console profile only (`NEXVYN_CONSOLE_PROFILE=1`); see `qa/PERFORMANS.md`.

## Security

- WebGL buffer and draw ranges (`bufferSubData`, `getBufferSubData`, `drawElements`, `drawRangeElements`) are checked without adding offset and size, so huge offsets cannot wrap around the bounds check; script numbers are clamped before they become 64-bit integers.
- `new Worker(url)` accepts only same-origin scripts, the page's own `blob:` URLs and `data:` URLs (a local page may use local files); anything else throws a `SecurityError`.
- A redirect to another origin drops `Authorization`, `Cookie`, `Proxy-Authorization` and CSRF-token headers. The sign-in redirect allowance for third-party cookies is kept separately for private tabs and cleared with them.
- Private tabs neither read nor write the in-memory bytecode cache (the disk cache was already off). A cached bytecode entry is used only when its key, an independent source hash and the source length all match (cache generation `kBytecodeGen` 2; older `bc1_*` files are simply ignored and pruned).
- Background file writes no longer hold the lock the main thread takes while they write; closing the last private tab also drops private IndexedDB databases; a failed `WebAssembly.Instance` link releases the imports it registered.
