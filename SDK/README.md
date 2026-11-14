# Nexvyn OS SDK (N2 Architecture — SDK 2.0 / 1.13 & Native SDK 1.2)

Everything for developers and AI assistants building apps, games, ports, emulators, themes and fonts for Nexvyn OS:
the complete SDK reference, the 4 official language tracks, the **NXUI Retained & Semantic UI Engine**, the **NexGFX
PBR 3D renderer**, the **Native C/C++ ABI v1 kit**, working samples, AI context packs (`AI/llms.txt` &
`AI/system-prompt.md`), the publishing guide and command-line tools. All documentation is in English.

**Current version: SDK 2.0 / 1.13 & Native SDK 1.2** (Nexvyn OS 1.3.9). Apps made for SDK 1.0 to 1.12 and Native SDK
1.0 to 1.1 run unchanged ([SDK versions](Guides/SDK_VERSIONS.md)).

---

## What is new in Nexvyn OS N2 (SDK 2.0 / 1.13 & Native SDK 1.2)

### 1. The 4 Official Primary Runtimes
Nexvyn OS N2 standardizes on four high-performance primary runtimes while keeping earlier runtimes (`PocketPy`,
`TinyCC C`, `Squirrel 3.2`, `miniJVM Java`) available through the on-demand `ComponentService`:

| Track | Engine | `app.json` Configuration | Best For |
|---|---|---|---|
| **Lua 5.4.7** | PUC Lua 5.4.7 with Generational GC (`LUA_GCGEN`, ~0.28 ms step) | `"runtime": "lua"`, `"main": "main.lua"` | System utilities, calculators, tools, 2D games (`nexvyn.game`), PBR 3D apps |
| **JavaScript ES2023** | QuickJS-ng 0.17.0 with disk bytecode cache & Promises | `"runtime": "js"`, `"main": "main.js"` | Network/REST/WebSocket apps, social feeds, 3D voxel worlds (`g3d.voxels`) |
| **Python 3.12** | CPython 3.12.16 (full syntax & standard library) | `"runtime": "python3"` (or `"runtime": "python"` with `"targetSdk": "2.0"`) | Data analysis, scientific visualization, automation, complex logic |
| **Native C / C++** | devkitA64 GCC AOT `.nxvmod` / `.nro` (Frozen ABI v1) | `"runtime": "native"`, `"minNative": "1.2"`, `"main": "<id>.nxvmod"` | High-speed 3D games, OpenGL / SDL2 ports, emulators, CPU-intensive engines |

### 2. NXUI — Retained & Semantic UI Engine (`nxui.*` & `nxn_nxui_*`)
Available with identical semantics in **Lua**, **JavaScript**, **Python** and **Native C/C++** (`#include <nexvyn/nxn_nxui.h>`):
- **Automatic Flexbox-like Containers:** `nxui.begin(w, h)` / `nxui.endFrame()`, `nxui.row(id, gap)` / `nxui.rowEnd()`, `nxui.column(id, gap)` / `nxui.columnEnd()`, `nxui.card(id)` / `nxui.cardEnd()`, `nxui.scrollBegin(id, w, h, scrollY)` / `nxui.scrollEnd()`, `nxui.canvasBegin(id, w, h)` / `nxui.canvasEnd()`.
- **Semantic Controls:** `nxui.label(id, text, role)`, `nxui.badge(id, text, rgba)`, `nxui.button(id, label, variant)`, `nxui.toggle(id, checked)`, `nxui.slider(id, val, min, max)`, `nxui.textfield(id, text, placeholder)`, `nxui.dropdown(id, options, selected)`, `nxui.tabs(id, labels, active)`, `nxui.table(id, cols, rows, selectedRow)`, `nxui.virtuallist(id, items, rowH, viewH, selectedRow)` (10,000+ rows at 60 fps), `nxui.dialog(id, title, msg, confirm, cancel)`, `nxui.spacer(size)`.
- **Design Tokens & Spatial Focus:** `nxui.tokens()` returns the live system design tokens (`space1`..`space6`, `radiusSm`/`Md`/`Lg`, `fontSm`/`Body`/`Title`/`Hero`, `scale`, `dark`, `highContrast`, `reducedMotion`, RGBA palette). D-pad and controller navigation work out of the box via `nxui.moveFocus(dir)` and `nxui.activateFocused()`.

### 3. Native SDK 1.2 & Unified Input Router
- **Window Control (`NXN_CAP_WINDOW_CTL`):** `nxn_window_set_title`, `nxn_window_set_mode` (windowed, maximized, fullscreen), `nxn_window_set_modified` (unsaved work guard before close).
- **Power & Dock Telemetry (`NXN_CAP_POWER_STATE`):** `nxn_power_get` and `NXN_EVENT_POWER` for battery percentage, charger state, dock/handheld mode and network status.
- **Native OS Dialogs (`NXN_CAP_DIALOG`):** `nxn_dialog` and `nxn_prompt` render native system sheets and text prompts.
- **Loading Grace (`"loadingHint": true`):** Extends the initial loading watchdog threshold from 5 s to 120 s for apps and games that unpack or compile large assets at startup.

---

## NexGFX PBR Renderer & Media Pipeline (SDK 1.9+)

<p align="center"><img src="../.github/assets/nexgfx-orbit.webp" width="100%" alt="A camera orbits a meeting room rendered by NexGFX: sunlight through glass, shadows, reflections on chrome and a clearcoat floor"></p>

### NexGFX PBR renderer
A physically based 3D renderer for apps and games, opt-in per app with `g3d.renderer("pbr")`:

| Feature | API |
|---|---|
| Metallic-roughness materials with normal, occlusion and emissive maps; glTF ORM, FBX map sets, MetallicSmoothness | from the model file, or `g3d.material(meshOrModel, {...}[, name])` |
| Real-time lights: the sun plus up to 16 point, spot and directional lights (8 per object) | `g3d.light`, `g3d.addLight`, `g3d.updateLight`, `g3d.removeLight` |
| Shadows: the sun (fitted to the view, filtered) and one spot light | `g3d.shadows({quality, distance, bias})` |
| Glass: thin transmission with refraction, Fresnel reflection; alpha blend and cut-out with alpha to coverage | `transmission`, `ior`, glTF alpha modes |
| Reflections and ambient light from a sky hemisphere or a 6-face cube map (reflection probe) | `g3d.environment({sky, ground, cubemap})` |
| HDR, ACES or filmic tone mapping, bloom, MSAA 2x / 4x / 8x | `g3d.postfx({exposure, tonemap, bloom, msaa})` |
| GPU instancing, up to 128 copies per call | `g3d.drawInstanced(mesh, transforms)` |
| Hardware capabilities and active backend | `g3d.caps()`, `g3d.rendererInfo()` |

| | |
|:---:|:---:|
| <img src="../.github/assets/nexgfx-effects.webp" alt="The same room without shadows and bloom, and with shadows, bloom and 4x MSAA"> | <img src="../.github/assets/sample-pbr3d.webp" alt="The PBR, Lights and Shadows sample: crates with emissive strips, spheres from rough to polished metal, pillars and coloured lights"> |
| **Post effects:** shadows, bloom, MSAA | **[PBR, Lights and Shadows](Samples/lua/pbr3d/)** sample |

### Feeds, media, network & storage

| Feature | API |
|---|---|
| HTTP with JSON, form, multipart and file bodies, upload progress, cookies, retries, offline cache | `net.request(options, callback[, progress])`, `net.cancel` |
| WebSocket client | `net.ws`, `net.wsSend`, `net.wsPoll`, `net.wsClose`, `net.wsState` |
| Sign-in through the console's browser (OAuth 2.0 with PKCE) | `net.oauth` |
| Web pictures with a disk and memory cache, thumbnails | `gfx.imageUrl(url, maxSize)`, `gfx.imageState` |
| Video and audio players inside the app (files, MP4, HLS) | `media.open`, `media.draw`, `media.play` ... |
| Virtualized lists and grids, pull-to-refresh, infinite scroll | `nxui.virtuallist`, `ui.beginFeed`, `ui.feedItem`, `ui.endFeed` |
| Full-screen swipe pager & rich text | `ui.pager`, `ui.richText`, `sys.relativeTime` |
| Kept folders and save backups (SDK 1.11) | `ui.chooseFolder`, `fs.folderGrants`, `fs.savePath`, `fs.saveBackup`, `fs.saveRestore` |

<p align="center"><img src="../.github/assets/sample-social-feed.webp" width="90%" alt="The Social Feed sample: a photo feed in dark mode, a photo grid and a vertical clip pager"></p>

---

## Kits and tools

| Tool / Kit | Purpose |
|---|---|
| **[nxv (`create` / `new` / `check` / `pack`)](Tools/nxv/README.md)** | Smart Creator (`nxv.py create MyApp --profile game`), template generator, static checker, deterministic `.nxvapp` packer, signer and FTP pusher |
| **[Native SDK kit (`nxv-native`)](Languages/c/native-kit/README.md)** | Builds C/C++ `.nxvmod` windowed/fullscreen apps and `.nxvlib` shared libraries (`nxn_*`, `nxn_nxui_*`, SDL2, OpenGL, POSIX compat) |
| **[Sound kit (`sfx`)](Languages/lua/kits/README.md)** | Layered procedural sound effects and music from recipes: variants, buses, ducking, ambience, music loops ([Sound design](Guides/SOUND_DESIGN.md)) |
| **[Feel kit (`juice`)](Languages/lua/kits/README.md)** | Easing/tweens, screen shake, hit-stop, particles, glow, styled titles, panels, transitions, 2D/3D cameras and 3D light moods ([Game feel](Guides/GAME_FEEL.md)) |
| **[Icon tool](Tools/icon/README.md)** | Renders the game's 3D model and composites its 256x256 key-art store icon (`clean`, `bold`, `loud`) |
| **[Texture tool](Tools/textures/README.md)** | Validates PBR texture sets, downscales maps, packs glTF ORM, and converts MetallicSmoothness / -Y normal maps |
| **[Theme tool](Tools/theme/README.md)** | Validates a theme pack (`theme.json`, WCAG AA contrast) and packs `.nxvtheme` ([Making themes](Guides/THEMES.md)) |

<p align="center"><img src="Tools/icon/examples/ember-field/preview.png" width="32%" alt="Key-art icon made with the icon tool for Ember Field, clean style"> <img src="Tools/icon/examples/orbit-rush/preview.png" width="32%" alt="Key-art icon made with the icon tool for Orbit Rush"> <img src="Tools/icon/examples/shard/preview.png" width="32%" alt="Key-art icon made with the icon tool for Shard"></p>

---

## Start here

| Track | 1. Quick start | 2. Template | 3. Guide | 4. Samples |
|---|---|---|---|---|
| **Lua 5.4.7** (recommended) | [Languages/lua](Languages/lua/README.md) | [template](Languages/lua/template/) | [Developer guide](Guides/DEVELOPER_GUIDE.md), [game engine](Guides/GAME_ENGINE.md) | [Samples/lua](Samples/lua/) |
| **JavaScript (ES2023)** | [Languages/javascript](Languages/javascript/README.md) | [template](Languages/javascript/template/) | [Apps in JavaScript](Guides/JS_APPS.md) | [Samples/javascript](Samples/javascript/) |
| **Python 3.12** | [Languages/python](Languages/python/README.md) | [template](Languages/python/template/) | [Apps in Python](Guides/PY_APPS.md) | [Samples/python](Samples/python/) |
| **Native C / C++ (`.nxvmod`)** | [Languages/c/native-kit](Languages/c/native-kit/README.md) | templates in the kit | [Native SDK guide](Guides/NATIVE_GUIDE.md), [kit reference](Guides/NATIVE_KIT.md) | kit `examples/` |
| C (TinyCC on-console) | [Languages/c](Languages/c/README.md) | [template](Languages/c/template/) | [Apps in C](Guides/C_APPS.md) | [Samples/c](Samples/c/) |
| Squirrel (compat, frozen at 1.8) | [Languages/squirrel](Languages/squirrel/README.md) | [template](Languages/squirrel/template/) | [Apps in Squirrel](Guides/SQUIRREL_APPS.md) | [Samples/squirrel](Samples/squirrel/) |
| Java (compat, frozen at 1.8) | [Languages/java](Languages/java/README.md) | [template](Languages/java/template/) | [Apps in Java](Guides/JAVA_APPS.md) | [Samples/java](Samples/java/) |

---

## Building with an AI assistant (Zero-Hallucination Workflow)

The `SDK/AI/` folder is engineered so any LLM or coding agent can build complete, 60 fps Nexvyn OS apps and games without inventing non-existent functions:

1. **Feed the AI Context:**
   - **Quick index for LLMs / IDE agents:** [`AI/llms.txt`](AI/llms.txt) and [`AI/AI_RULES.md`](AI/AI_RULES.md).
   - **Full system prompt (~8k tokens):** [`AI/system-prompt.md`](AI/system-prompt.md) + the language pack in [`AI/languages/`](AI/languages/) (`lua.md`, `javascript.md`, `python.md`, `native.md`, `c.md`).
   - **Complete contract:** [`Reference/SDK.md`](Reference/SDK.md).
2. **Use a Task Prompt:** Pick a structured prompt from [`AI/tasks/`](AI/tasks/) (3D PBR game, 2D game, social/feed app, utility, port, theme pack, store icon, store listing).
3. **Verify Automatically:** Run `python SDK/Tools/nxv/nxv.py check <folder>` and walk through [`AI/checklist.md`](AI/checklist.md).

---

## Your first app in 5 minutes

**With Smart Creator on a PC:**
```bash
# 1. Create a ready-to-run N2 app (Lua, JS, Python 3.12, or Native C/C++)
python SDK/Tools/nxv/nxv.py create "My App" --profile utility --runtime lua

# 2. Check manifest, translations, permissions and syntax
python SDK/Tools/nxv/nxv.py check myapp

# 3. Pack into a deterministic .nxvapp or push over FTP to the console
python SDK/Tools/nxv/nxv.py pack myapp
```

## Contents

| Folder | What is in it |
|---|---|
| [Reference/](Reference/README.md) | Complete SDK contract (`SDK.md`), C headers (`c/include/nexvyn.h`), Java SDK sources |
| [Languages/](Languages/README.md) | Quick starts, templates, Lua/JS `sfx` & `juice` game kits, and the **Native C/C++ SDK kit (`Languages/c/native-kit/`)** |
| [Guides/](Guides/README.md) | 34 engineering guides: PBR games, social apps, Native SDK, NexGFX, input modes, compatibility, packaging |
| [Samples/](Samples/README.md) | Working sample apps and games; [`samples.json`](samples.json) powers Studio's sample browser |
| [AI/](AI/README.md) | `llms.txt`, `system-prompt.md`, `AI_RULES.md`, language packs, task prompts and verification checklist |
| [Publishing/](Publishing/README.md) | App Market submission flow, review checklist, security & privacy rules |
| [Fonts/](Fonts/) | System fonts (Inter, JetBrains Mono, Material Symbols with `Icons.codepoints`) |
| [Tools/](Tools/README.md) | `nxv` CLI (with Smart Creator), `icon` key-art generator, `textures` PBR pipeline, `theme` packer |
