<p align="center"><img src=".github/assets/desktop-dock.webp" width="100%" alt="The Nexvyn OS desktop in the Dock layout with clock, calendar and world clock widgets"></p>

<h1 align="center">Nexvyn OS</h1>

<h1 align="center">
Official Discord Community: https://discord.gg/gHfSaBJfFt</h1>
<p align="center"><b>A full desktop, native 3D, a real App Market and a browser, on a Switch.</b><br>
<i>Native 3D from 10 to 60 fps. A GBA game at full speed. Desktop websites, WebGL and video in the browser. Measured on a console.</i></p>

<p align="center"><a href="https://github.com/sonerx7/Nexvyn-OS-NX/blob/main/.github/assets/video/hero_30s.mp4"><img src=".github/assets/video/hero_30s.gif" width="70%" alt="30-second Nexvyn OS tour: click to play the video"></a><br><a href="https://github.com/sonerx7/Nexvyn-OS-NX/blob/main/.github/assets/video/hero_30s.mp4">Watch the 30-second tour</a> · <a href="https://github.com/sonerx7/Nexvyn-OS-NX/blob/main/.github/assets/video/overview.mp4">2-minute overview</a> · <a href="https://github.com/sonerx7/Nexvyn-OS-NX/blob/main/.github/assets/video/blockcraft_trailer.mp4">BlockCraft trailer</a></p>
<p align="center"><b>On YouTube:</b> <a href="https://www.youtube.com/@NexvynOSNX">channel</a> · <a href="https://www.youtube.com/watch?v=_DQouwS2TYQ">full showcase</a> · <a href="https://www.youtube.com/watch?v=3aze4gmaLnI">themes and the Doom port</a> · <a href="https://www.youtube.com/watch?v=5R1F_wDSVAM">BlockCraft</a> · <a href="https://www.youtube.com/watch?v=Wvk8iQVjDMw">WebGL in the browser</a></p>

- One `.nro`, opened from the Homebrew Menu. No reboot, no partitioning.
- A windowed desktop (Dock or taskbar layout), 70+ built-in apps and an App Market where every item is reviewed.
- **Nexvyn OS N2 Architecture (SDK 2.0 / 1.13 & Native SDK 1.2):** 4 official primary language tracks (**Lua 5.4.7** with Generational GC, **JavaScript ES2023** on QuickJS-ng 0.17.0, **Python 3.12** on CPython 3.12.16, and **Native C/C++** with Frozen ABI v1), the **NXUI Retained & Semantic UI Engine (`nxui.*` & `nxn_nxui_*`)**, the **NexGFX PBR 3D renderer**, and an AI-ready SDK (`SDK/AI/llms.txt`).

### What is new in 1.3.10

- **App Market & SDK Parity (`1.13` / Native `1.2`):** All `112` Store packages (`181` catalog items, `4` beta items) updated to `targetSdk: "1.13"`, explicit `runtime` declarations, and `"minNative": "1.2"` / `"targetNative": "1.2"` for native apps and emulators (`Store/catalog.json` & `Store/beta.json` pass `catalog_check` with `0` errors and `0` warnings).
- **Porting & Maximum Input (`sdl2-nexvyn` & `<nexvyn/nxn_port_input.h>`):** Added 16-finger multi-touch, pinch-to-zoom, two-finger tap right-click, two-finger pan scroll, long-press right-click, `nxn_rumble` haptics, and `<nexvyn/nxn_port_input.h>` for porting strategy/CRPG/FPS/arcade games (`SDK/Porting/`).
- **Terminal & Critical Flow Stability:** Fixed a keyboard focus/swkbd lock issue in `Terminal`, added font-metric and history-load guards, and verified core OS apps (`terminal`, `files`, `browser`, `settings`, `appstore`, `notes`, `calculator`, `textedit`, `games`, `studio`, `sysinfo`, `console`).
- **SDK CLI (`SDK/Tools/nxv/nxv.py`):** Added `"native"` runtime and `"showcase"`/`"emulator"` store category checks (`111/111` `source/` bundles pass `nxv check --frames 5`).

### What is new in 1.3.9 (N2 Architecture Final)

**1. Four Official Primary Runtimes, W^X JIT & On-Demand ComponentService:**
- **Lua 5.4.7 (`"runtime": "lua"`):** Generational GC (`LUA_GCGEN`, ~0.28 ms frame pause), instant startup, `nexvyn.game` 2D engine, `nxui.*`, and `g3d.*` PBR.
- **JavaScript ES2023 (`"runtime": "js"`):** QuickJS-ng 0.17.0 with persistent SD bytecode caching, native Promises, `g3d.voxels` streaming voxel worlds, `nxui.*`, and `g3d.*` PBR.
- **Python 3.12 (`"runtime": "python3"` or `"targetSdk": "2.0"`):** CPython 3.12.16 with full Python 3.12 syntax and standard library (`statistics`, `itertools`, `collections`, `datetime`, `zlib`, `hashlib`, `re`, `urllib.parse`, `uuid`, etc.), `nxui.*`, and `g3d.*` PBR.
- **Native C/C++ (`"runtime": "native"`, `.nxvmod`):** Ahead-of-Time (AOT) ARM64 compilation with devkitA64 GCC against **Frozen ABI v1** (`nxn_*`), Native SDK 1.2 system integration, hardware W^X dual-mapping JIT (`nxn_vm`), `nxn_nxui_*` Retained UI, SDL2 window driver, and OpenGL / NexGFX.
- Earlier runtimes (**PocketPy** for `targetSdk < 2.0`, **TinyCC C**, **Squirrel 3.2**, **Java miniJVM**) remain 100% supported via the on-demand `ComponentService` (SHA-256 verified with 256 MB LRU cache).

**2. NXUI — Retained & Semantic UI Engine (`nxui.*` & `nxn_nxui_*`):**
- Shared identically across Lua, JavaScript, Python and Native C/C++ (`#include <nexvyn/nxn_nxui.h>`).
- Automatic Flexbox-like layout containers (`row`, `column`, `card`, `scrollBegin`, `canvasBegin`), semantic controls (`label`, `badge`, `button`, `toggle`, `slider`, `textfield`, `dropdown`, `tabs`, `table`, `virtuallist` for 10,000+ rows at 60 fps, `dialog`, `spacer`), design tokens (`nxui.tokens()`), and controller spatial focus navigation (`moveFocus`, `activateFocused`).

**3. Desktop Shell Refinements — Click-to-Restore Session & Live Telemetry Widgets:**
- **Click-to-Restore Session Notification:** Previous session windows no longer reopen automatically at boot; a top-right notification banner (`Continue where you left off`) reopens them on demand when clicked.
- **Theme-Adaptive Widgets & CPU/RAM/FPS/GPU System Widget:** All desktop widgets adapt to the active theme palette (including Classic 3D), and the System widget displays live **CPU, RAM, FPS, and GPU** metrics.

**4. Smart Creator, Port Kit & AI-Ready SDK (`SDK/AI/`):**
- `python SDK/Tools/nxv/nxv.py create "My App" --profile <utility|network|data|game|emulator|port>` recommends the best runtime and scaffolds a complete, ready-to-pack N2 project.
- `SDK/AI/llms.txt` and `SDK/AI/system-prompt.md` give AI coding assistants and LLMs a zero-hallucination specification of the entire SDK 2.0 / 1.13 surface along with copy-pasteable Golden Templates.

---

### What is in 1.3.0 to 1.3.9

**Browser: desktop websites by default.** The Browser asks for desktop sites, so most pages load their desktop layout. Settings has "Request mobile sites" (off by default), and each site can be switched from the address-bar menu.

**Browser: more of the web works.**

- Canvas 2D: linear and radial gradients, patterns, `clip()` with `save()` / `restore()`, composite operations, affine `drawImage`, `OffscreenCanvas` and `createImageBitmap`, `setLineDash`, approximate shadows.
- WebGL 1 for 3D libraries, and early WebGL 2 (instancing, uniform buffers, 3D and array textures, multiple render targets, transform feedback). Known WebGL 2 gaps: rendering to one layer of a 2D-array texture, sampling 3D textures, and `drawArraysInstanced` after the vertex array object or instance count changes. A failing call returns wrong pixels; the page does not crash.
- ES modules, Web Workers (same-origin, module workers included), IndexedDB, Gamepad API, WebAssembly (off by default, in Settings), and link navigation with the gamepad.
- Video in the page: MP4, WebM and HLS play with the system media player (software decoding). MediaSource works for H.264 + AAC fragmented MP4 and WebM. Clear-key encrypted video (EME ClearKey) plays.
- Cookies, sign-in forms and third-party cookie blocking (on by default). Tested on a local sign-in suite; signing in to live sites is experimental.

**Browser: what does not work yet.**

- **Netflix and other DRM streaming do not play.** There is no Widevine, FairPlay or PlayReady support, so protected video is refused.
- **YouTube is experimental.** The page loads and the player starts, but playback is not yet reliable on every video.
- Web fonts (`@font-face`), Service Workers and WebSocket are not supported yet.

**Browser: speed and memory.** Background tabs are freed from memory when many are open or when the console reports low memory, and they reload when shown. Large scripts are kept as compiled code on the SD card, so a revisit starts faster. A stuck script is cut after one second, so the Browser no longer shows a "not responding" window for it.

**Five emulators in the App Market.** NES, Game Boy and Game Boy Color, Mega Drive, SNES and Game Boy Advance. Each one is a separate app that installs from the App Market. They share one library:

- A home page with covers, search, sort, favourites, recently played, and a detail pane for each game.
- In-game screenshots (a hotkey or the pause menu), used as covers when you choose.
- Per-game and per-system settings, state slots (1 to 9), and an option to save the state on leaving and load it on start.
- Optional online artwork (box art, screenshots, title screens) from a community library. It is off until you agree on the first run, and you can change it in Library settings. Only game names and the console's address are sent.

**Native SDK 1.2: system integration for windows.** Apps built with `"minNative": "1.2"` can:

- Set the window title and subtitle, switch to full screen or maximized, and show the OS "unsaved work" mark. Nexvyn OS asks before it closes an app with unsaved work.
- Read battery, charger, dock and network state, and get an event when one changes. Power state is cheap to read every frame.
- Show the OS alert, question and text prompt boxes, so a native app looks like the rest of the system.
- Trust model (all native apps, not tied to `minNative`): a native app is checked when it is installed and trusted once, by a record of its id and hash. It is not asked again on every launch.

The native kit also includes the request for the OS on-screen keyboard when a text field is focused (`nxn_input_text_request`) and the app's own menus in the OS menu bar (`nxn_menu_set`).

Older native apps (1.0 and 1.1) run unchanged. See [SDK/Reference](SDK/Reference/README.md) and [SDK/Guides](SDK/Guides/README.md).

**App Market: Runtimes & Libraries.** A new category for runtimes and shared libraries that other apps use.

**Performance and security.** Stall logging names the slow step in the system log, so a slow page can be found. Browser security fixes: cross-site redirects no longer carry sign-in headers, workers stay same-origin, WebGL range overflows are checked, and the bytecode cache is keyed by a digest of the source.

<p align="center"><img src=".github/assets/screenshots/browser_hero.jpg" width="80%" alt="The Browser showing a desktop website with its tabs and address bar"></p>

<table>
<tr>
<td><img src=".github/assets/screenshots/browser_wikipedia.jpg" alt="A styled Wikipedia article in the Browser"><br><sub>A desktop Wikipedia article</sub></td>
<td><img src=".github/assets/screenshots/browser_webgl.jpg" alt="A WebGL scene in the Browser"><br><sub>WebGL in the page</sub></td>
<td><img src=".github/assets/screenshots/browser_github.jpg" alt="A GitHub repository page in the Browser"><br><sub>A desktop GitHub page</sub></td>
</tr>
<tr>
<td colspan="3" align="center"><img src=".github/assets/screenshots/emulators_home.jpg" width="48%" alt="The emulator library home page with cover art"> <img src=".github/assets/screenshots/emulators_detail.jpg" width="48%" alt="A game's detail pane with screenshots"></td>
</tr>
<tr>
<td colspan="3" align="center"><img src=".github/assets/screenshots/emulators_play.jpg" width="48%" alt="A game running in the emulator frontend"> <img src=".github/assets/screenshots/emulators_settings.jpg" width="48%" alt="The emulator settings page"></td>
</tr>
</table>

---

### 10 things that make it different

1. **Native apps at full speed.** C and C++ apps run in their own windows on the desktop. Measured on a console: 3D scenes went from 10 to 59 fps, the OpenGL showcase from 10-16 to 60 fps, frame handoff from 15-24 ms to 0.1 ms, scene loading from about 30 s to 0.6 s. Classic game ports (a Doom engine, a Quake engine, a GBA emulator) run in windows or full screen.

   <img src=".github/assets/hero-doom.webp" width="31%" alt="Doom engine with Freedoom"> <img src=".github/assets/hero-showcase.webp" width="31%" alt="Native SDK Showcase">

2. **Desktop websites and WebGL in the browser.** The built-in browser asks for desktop sites and runs WebGL 1, so popular open-source 3D web libraries work: a spinning 3D scene runs at about 48 fps on the console. Early WebGL 2 is in testing. It is on by default.

   <img src=".github/assets/hero-webgl.webp" width="31%" alt="WebGL cube in the browser">

3. **One SDK, four languages.** Lua, JavaScript, Python and C use the same API with the same names: windows, UI, files, network, sound, input, 2D and 3D. Each new feature reaches all four. The kit has guides, samples, checkers and AI prompts for makers.
4. **A modern 3D renderer.** NexGFX has a physically based renderer: metal and roughness materials, normal and emissive maps, real-time lights, sun and spot shadows, HDR, tone mapping, bloom, MSAA and instancing. Apps opt in, and old apps look the same.

   <img src=".github/assets/nexgfx-materials.webp" width="31%" alt="PBR materials">

5. **Real 3D models.** `.glb`, `.gltf`, `.fbx`, `.obj` and `.stl` files load with node trees, materials, textures and skeletal animation with crossfades, skinned on the GPU.
6. **A voxel engine.** Endless block worlds stream in around the player on background threads, with sunlight and torch light, smooth lighting, ambient occlusion, water, saving, ray picks and physics, so a block-building game is a few hundred lines.
7. **Full theme packs.** A theme changes everything: colours, window frames, a dock or a taskbar, every icon (apps, folders, file types, disks), sounds and wallpapers. Pick one at first start: Glass, Classic, Terminal and more, with more themes in the App Market. Missing icons fall back to the default pack, and a theme kit lets anyone make their own.

   <img src=".github/assets/hero-theme-glass.webp" width="31%" alt="Glass style"> <img src=".github/assets/anim-theme-switch.gif" width="31%" alt="Switching styles">

8. **Performance mode.** Official maximum clocks are on by default, with faster loading and an optional overclock that warns first. Installs run in the background, and a stuck app never freezes the desktop: there is an exit watchdog, and the system asks before it closes anything.

   <img src=".github/assets/settings-performance.webp" width="31%" alt="Performance settings">

9. **App Market.** About 170 apps, games, themes and fonts, with tabs, categories, a Showcase of tech demos, full-page details with screenshots, live install progress (MB, speed, time left) and one-tap updates. Some built-in apps update from it too.

   <img src=".github/assets/hero-market-discover.webp" width="31%" alt="App Market"> <img src=".github/assets/anim-market-browse.gif" width="31%" alt="App Market">

10. **A real desktop for the Switch.** Movable windows, multi-touch gestures, Joy-Con, touch, handheld and docked play, 8 languages, a first-start wizard that works offline, safe mode, deep reset, and an AI Chat app that works with several providers.

   <img src=".github/assets/anim-window-snap.gif" width="31%" alt="Window snapping">



<p align="center"><img src=".github/assets/anim-window-snap.gif" width="80%" alt="Dragging a window to the screen edge snaps it to half of the screen"></p>

### Two desktops, your choice

Pick a Dock or a taskbar layout in the first-run setup and switch any time. Windows, snapping, virtual desktops, Quick Search, Control Center and widgets work the same in both.

| Dock | Taskbar |
|---|---|
| <img src=".github/assets/desktop-dock.webp" alt="Dock layout with widgets"> | <img src=".github/assets/desktop-taskbar.webp" alt="Taskbar layout with an aurora wallpaper and widgets"> |

### Pick your style

The first-run setup asks for a look. Colors, bars, icons and sounds change together, and more styles wait in the App Market under Themes.

<p align="center"><img src=".github/assets/hero-pick-your-style.webp" width="80%" alt="The Pick your style step of the first-run setup with four style cards"></p>

| Classic 95 | Glass | Terminal Blue |
|---|---|---|
| <img src=".github/assets/hero-theme-classic95.webp" alt="Classic 95 style: a beige desktop with bevelled buttons"> | <img src=".github/assets/hero-theme-glass.webp" alt="Glass style: a dark desktop with translucent windows"> | <img src=".github/assets/hero-theme-terminalblue.webp" alt="Terminal Blue style: a deep blue desktop with a taskbar"> |

<p align="center"><img src=".github/assets/anim-theme-switch.gif" width="80%" alt="Switching between styles: the colors, the window frames and the wallpaper change at once"></p>

### Redesigned App Market

Discover, Apps, Games, Showcase, Themes and Updates. Full-page app details with a screenshot gallery, and live download speed and MB while an app installs. Installs run in the background, so a slow SD card no longer freezes the desktop.

| Discover | App details | Themes |
|---|---|---|
| <img src=".github/assets/hero-market-discover.webp" alt="App Market, Discover tab with a featured game"> | <img src=".github/assets/hero-market-detail.webp" alt="App Market, details page of the Native SDK Showcase"> | <img src=".github/assets/hero-market-themes.webp" alt="App Market, Themes section with large preview cards"> |

<p align="center"><img src=".github/assets/anim-market-browse.gif" width="80%" alt="Browsing the App Market: Discover, then the Themes section"></p>

### Wow

| | |
|---|---|
| **Native SDK Showcase**<br>A C++ app in a window with its own 3D view, tests and live status. <img src=".github/assets/hero-showcase.webp" alt="The Native SDK Showcase app in a window"> | **Doom engine with Freedoom**<br>Free game data, clean sound, touch and Joy-Con. <img src=".github/assets/hero-doom.webp" alt="Doom engine running with the free Freedoom data"> |
| **GBA at full speed**<br>A free homebrew GBA game (MIT license) at 59.2 fps in the first console test; the first build gave 4-5. <img src=".github/assets/hero-gba.webp" alt="A free homebrew GBA game running in a window"> | **WebGL in the browser**<br>A three.js cube at about 57-58 fps in testing (experimental, off by default). <img src=".github/assets/hero-webgl.webp" alt="A spinning WebGL cube in the browser"> |
| **What is new in 1.2.2**<br>A short tour of the release the first time you open it, and any time from Settings. <img src=".github/assets/hero-whatsnew.webp" alt="The What's new screen: A new App Market"> | **Official max clocks**<br>On by default, plus an optional overclock behind a warning. <img src=".github/assets/settings-performance.webp" alt="Settings, Performance pane with the official maximum clocks"> |

<p align="center"><img src=".github/assets/anim-doom-play.gif" width="80%" alt="Playing the Doom engine with the free Freedoom data"></p>

### Numbers

Measured on a Switch OLED, first test against the final round (default settings).

| Test | Before | Now |
|---|---|---|
| Native 3D scene | 10 / 15 fps | 59.5 / 59.6 fps |
| OpenGL showcase | 10-16 fps | 51.4 fps default, 59.9 fps tuned |
| GBA emulation (a real game) | 4-5 fps | 59.2 fps, full speed |
| App frame to screen | 15-24 ms | 0.10-0.22 ms |
| Scene loading | ~30 s | 0.58 s |
| Handheld GPU clock, official max | 307 MHz | 460 MHz (benchmark 69.0 to 84.5 fps) |

60 fps is the screen limit, so some tests are "locked at 60".

### For developers & AI assistants

Native C and C++ with a frozen ABI v1 (add-only from now on): a module built with the 1.0 kit still loads on the current system. Every new API — including the **NXUI Retained & Semantic UI Engine (`nxui.*` / `nxn_nxui_*`)** and **NexGFX PBR renderer (`g3d.*`)** — arrives across the 4 official primary tracks (**Lua 5.4.7**, **JavaScript ES2023**, **CPython 3.12**, and **Native C/C++**). Smart Creator (`nxv.py create`) and the Port Kit scaffold apps and ports in one command, and `SDK/AI/llms.txt` + `SDK/AI/system-prompt.md` let AI coding assistants build full Nexvyn OS apps with zero hallucination. See [SDK](SDK/README.md).

The SDK guides cover the complete platform: [SDK Reference](SDK/Reference/SDK.md), [Native kit](SDK/Guides/NATIVE_KIT.md), [SDK versions](SDK/Guides/SDK_VERSIONS.md), and [Browser](SDK/Guides/BROWSER.md).
