<p align="center"><img src=".github/assets/desktop-dock.webp" width="100%" alt="The Nexvyn OS desktop in the Dock layout with clock, calendar and world clock widgets"></p>

<h1 align="center">Nexvyn OS</h1>

<p align="center"><b>A full desktop, native 3D and a real App Market, on a Switch.</b><br>
<i>Native 3D from 10 to 60 fps. A GBA game at full speed. WebGL in the browser. Measured on a console.</i></p>

- One `.nro`, opened from the Homebrew Menu. No reboot, no partitioning.
- A windowed desktop (Dock or taskbar layout), 70+ built-in apps and an App Market where every item is reviewed.
- A native C/C++ SDK with a frozen ABI v1, plus Lua, JavaScript and Python, to make apps and games on the console or on a PC.

### 10 things that make it different

1. **Native apps at full speed.** C and C++ apps run in their own windows on the desktop. Measured on a console: 3D scenes went from 10 to 59 fps, the OpenGL showcase from 10-16 to 60 fps, frame handoff from 15-24 ms to 0.1 ms, scene loading from about 30 s to 0.6 s. Classic game ports (a Doom engine, a Quake engine, a GBA emulator) run in windows or full screen.

   <img src=".github/assets/hero-doom.webp" width="31%" alt="Doom engine with Freedoom"> <img src=".github/assets/hero-showcase.webp" width="31%" alt="Native SDK Showcase">

2. **WebGL in the browser.** The built-in browser runs WebGL 1, so popular open-source 3D web libraries work: a spinning 3D scene runs at about 48 fps on the console. It is on by default.

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

### For developers

Native C and C++ with a frozen ABI v1 (add-only from now on): a module built with the 1.0 kit still loads on the current system. Every new API arrives in Lua, JavaScript, Python and C with the same names. A port kit packages ports as separate apps. See [SDK](SDK/README.md).
