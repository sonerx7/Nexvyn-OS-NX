# Nexvyn OS developer guide

[Türkçe](DEVELOPER_GUIDE.tr.md) · **English**

This guide takes anyone who wants to write apps for Nexvyn OS from zero to a published app. The detailed API is not
repeated here; every section links to the relevant reference document.

| Document | Contents |
|---|---|
| [sdk/SDK.en.md](../Reference/SDK.en.md) | Full API reference: `gfx`, `ui`, `fs`, `net`, `sys`, `audio`, `g3d`, `nexvyn.game`, JavaScript differences |
| [docs/JS_APPS.en.md](JS_APPS.en.md) | Apps in JavaScript (short guide) |
| [docs/PY_APPS.en.md](PY_APPS.en.md) | Apps in Python (short guide) |
| [docs/GAME_ENGINE.en.md](GAME_ENGINE.en.md) | The `nexvyn.game` 2D game engine, step by step |
| [docs/NXVAPP_FORMAT.en.md](NXVAPP_FORMAT.en.md) | The `.nxvapp` v2 package format, permissions, repository, Overlay |
| [docs/LUA_CAPABILITIES.en.md](LUA_CAPABILITIES.en.md) | What you can build with Lua, and the limits |
| [docs/APP_GUIDE.en.md](APP_GUIDE.en.md) | Built-in (C++) app guide |

For the user side: [USER_GUIDE.en.md](USER_GUIDE.en.md).

## Contents

1. [Nexvyn OS Studio and templates](#1-nexvyn-os-studio-and-templates)
2. [app.json](#2-appjson)
3. [Choosing a language: Lua, JavaScript, Python](#3-choosing-a-language-lua-javascript-python)
4. [2D games with nexvyn.game](#4-2d-games-with-nexvyngame)
5. [3D with g3d](#5-3d-with-g3d)
6. [Packaging: .nxvapp v2](#6-packaging-nxvapp-v2)
7. [Community catalog](#7-community-catalog)
8. [Overlay: replacing system files](#8-overlay-replacing-system-files)
9. [Testing in Ryujinx](#9-testing-in-ryujinx)
10. [Built-in (native) app development](#10-built-in-native-app-development)
11. [English summary](#english-summary)

---

## 1. Nexvyn OS Studio and templates

The shortest path is the **Nexvyn OS Studio** app on the console itself. No computer is needed.

1. Open Studio and choose **New Project**. The template gallery opens.
2. Pick a template and name the app. Every template runs as it is and its code is commented.
3. Edit the code. Studio shows errors as you type and offers autocompletion.
4. Open the app with **Run**. `print()` output and errors appear in Studio's console.
5. When it is ready, use **Export Package**. The package is written to the Documents folder
   (`~/Documents/<name>.nxvapp`).

| Template | Language | What it shows |
|---|---|---|
| Empty Lua app | Lua | The smallest app; every callback commented |
| Empty JS app | JS | The same start: callbacks, `store` and a Promise |
| Utility app | Lua | List, detail and settings pages; data saved with `store` |
| Platformer | Lua | `nexvyn.game`: a tilemap level, a hero that runs and jumps, coins, enemies |
| Arena / space shooter | Lua | `nexvyn.game`: enemy waves, aiming, particles; rocks placed with the scene editor |
| Puzzle / grid game | Lua | `nexvyn.game`: a sliding tile puzzle; tweens, touch, controller, keyboard |
| 3D scene | Lua | `g3d` on the GPU: lit models, orbit camera, fog, labels |
| Network app | JS | Weather with `await net.fetchJson`, with error handling |
| Empty Python app | Python | The same start in Python: a class with callbacks, `store` and a menu |
| Snake (Python) | Python | A complete small game in Python: grid, timer, controller, keyboard, swipes, high score |

The templates are in `romfs/System/Templates/`. Python templates show a green Python badge in the gallery and declare
`1.3` as their `minSdk`. Studio opens `.py` files with Python highlighting.

Studio's other tools:

- **Sprite, tilemap and scene editors** open as tabs. The sprite editor offers frame size and animation preview. The
  tilemap editor edits tile flags (solid, one-way). Scenes are loaded with `game.loadScene`.
- The **Ask AI** panel answers questions with the API keys from AI Chat. It does not change files by itself; you add
  the suggested code.

If you prefer to work on a computer, create a `Name.nxvapp/` folder, write it with any editor and copy the folder into
`sdmc:/NexvynOS/Applications/`. The app appears on the Apps screen and in Search.

---

## 2. app.json

Every app has an `app.json` at its root. The most important fields:

```json
{
  "id": "com.adiniz.uygulama",
  "name": {"en": "My App", "tr": "Uygulamam"},
  "description": {"en": "What it does", "tr": "Ne yaptığı"},
  "version": "1.0",
  "author": "Adınız",
  "homepage": "https://github.com/kullaniciadiniz",
  "category": "utilities",
  "main": "main.lua",
  "window": {"width": 640, "height": 480, "minWidth": 320, "minHeight": 240, "resizable": true},
  "gamepad": false,
  "fileTypes": [".txt"],
  "minSdk": "1.2",
  "permissions": ["network"]
}
```

| Field | Description |
|---|---|
| `id` | Unique id in reverse-domain form. Updates are matched by this id. |
| `author`, `homepage` | Developer name and an optional web/GitHub address. Shown in the app's About window and in the store. |
| `main` | Entry file. `.js`/`.mjs` selects JavaScript, `.py` Python; the default is `main.lua`. |
| `runtime` | Selects the runtime explicitly instead of the `main` extension (`"js"`, `"python"`). |
| `window` | The **content** size; the system adds the title bar. |
| `gamepad` | When `true`, the controller goes to the app while the window is focused (games). The user gets the cursor back by holding L+R for a second. |
| `fileTypes` | Extensions it can open. The app appears in the "Open With" list and receives the file path in `load(arg)`. |
| `minSdk` | The oldest SDK version the app needs. An older Nexvyn OS does not install the app and asks for an update. |
| `permissions` | What the app needs beyond its own folders (see below). |

**SDK versions:** `sys.sdkVersion()` returns the system's version.

| SDK | Brings |
|---|---|
| 1.0 | The Lua runtime and the core modules, `g3d` |
| 1.1 | The JavaScript runtime; `g3d` textures on the GPU |
| 1.2 | `nexvyn.game`, `sys.sdkVersion()`, `minSdk` and `permissions`, single-file `.nxvapp` v2 |
| 1.3 | The Python runtime (see [PY_APPS.en.md](PY_APPS.en.md)) |

Put the version of the newest feature you use in `minSdk`.

**Permissions:** `network`, `files`, `launch`, `notifications`, `games` (`sys.games`, SDK 1.6). They are enforced for
apps installed on the SD card, with one decision per app at install time: the install sheet lists them, **Install**
allows them, **Customize** turns single ones off. Only when there is no stored answer is the user asked once at first
launch; `sys.requestPermission` is the only prompt at run time. With a refused or undeclared permission, `net.*` calls
fail with `permission denied` and file calls fail. Files the user picked in the file chooser, or opened the app with,
are always allowed. `sys.clipboard` needs no permission. Do not ask for permissions you do not need.

Full field list: [SDK.en.md section 1](../Reference/SDK.en.md#1-package-layout) and
[NXVAPP_FORMAT.en.md sections 2–3](NXVAPP_FORMAT.en.md#2-appjson).

---

## 3. Choosing a language: Lua, JavaScript, Python

All three languages use the same SDK: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`,
`theme`, `TR`, `g3d`. The difference is in the syntax.

| | Lua | JavaScript | Python |
|---|---|---|---|
| Version / engine | Lua 5.4 | QuickJS-ng (ES2023) | pocketpy |
| Entry file | `main.lua` | `main.js` / `.mjs` | `main.py` |
| Minimum SDK | 1.0 | 1.1 | 1.3 |
| Asynchronous calls | Callbacks | Callbacks or Promises (`await`) | Callbacks (no `async`/`await`) |
| Modules | `require("name")` (bundle, then the system library) | `import` (bundle only) | `import` (bundle only) |
| `nexvyn.game` | Yes | No (it is a Lua module) | No |
| Details | [SDK.en.md](../Reference/SDK.en.md) | [JS_APPS.en.md](JS_APPS.en.md), SDK.en.md section 11 | [PY_APPS.en.md](PY_APPS.en.md) |
| Sample | `hello.nxvapp` | `hellojs.nxvapp` | `hellopy.nxvapp` |

Shared rules:

- A program is a table of callbacks: `load`, `open`, `update(dt)`, `draw(w, h)`, `event(e)`, `menu`, `onmenu`,
  `close`. All are optional.
- `draw` is called every frame; the UI widgets (immediate mode) are drawn here and return clicks in the same call.
- A callback that runs longer than 3 seconds is stopped. On an error the window shows an error screen with line
  numbers and a **Reload** button; output goes to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.
- Lua has no `io`, `debug`, `package`, `dofile`, `loadfile`; use `fs` for files. JavaScript has no browser or Node.js
  API (`window`, `fetch`, `require`…); every window has a 64 MB memory limit.
- Translations live in `lang/en.json` and `lang/tr.json` and are read with `TR("key")`.
- Two-finger gestures arrive in `event` as `"pinch"` and `"rotate"` (in all three languages). `e.touch` is true,
  `e.x, e.y` is the midpoint of the fingers. `"pinch"`: `e.scale` is the change in finger distance since the previous
  event (> 1 means spreading); multiply your zoom by it. `"rotate"`: `e.angle` is the change in angle (radians,
  positive = clockwise). Both start once the fingers have moved a little; a plain two-finger drag stays a `"scroll"`,
  and `"scroll"` keeps arriving during the gesture, so panning and zooming can happen together. Details:
  [SDK.en.md](../Reference/SDK.en.md), `pinch` / `rotate`.

```lua
function app.event(e)
  if e.type == "pinch" then zoom = math.max(0.25, math.min(8, zoom * e.scale))
  elseif e.type == "rotate" then angle = angle + e.angle end
end
```

**Which one to choose?** Lua if you are writing a game with `nexvyn.game`. JavaScript if you are used to web
development or want to write network code with `async/await`. Python support has been added (SDK 1.3); a sample and
the differences are in [PY_APPS.en.md](PY_APPS.en.md).

The Python runtime is the newest addition. Confirm its behaviour on a real console with your own tests too.

---

## 4. 2D games with nexvyn.game

`nexvyn.game` is a small 2D game engine for Lua apps. It ships with the system in `romfs:/System/Lua/nexvyn/` and is
used with one line:

```lua
local game = require("nexvyn.game")
```

It includes a fixed-step game loop, scenes with transitions, sprites and animation, tilemaps (Lua/ASCII/JSON/Tiled),
a camera, arcade physics and collision, input actions and touch controls, tweens, particles, synthesized sound, a UI
with a pause menu, saving and a debug overlay.

- Step-by-step guide: [GAME_ENGINE.en.md](GAME_ENGINE.en.md).
- Function list: [SDK.en.md section 8c](../Reference/SDK.en.md#8c-2d-oyun-motoru-nexvyngame).
- Sample games: **Pixel Koşu** (`romfs/Applications/pixelrun.nxvapp`) and **Uzay Arenası**
  (`romfs/Applications/spacearena.nxvapp`).
- Known limits: a single touch point, no sloped tiles, no camera rotation (details in GAME_ENGINE.en.md section 16).

Do not forget `"gamepad": true` and `"minSdk": "1.2"` in `app.json`.

### Game Engine projects

**Game Engine** (`gamemaker`, formerly Game Workshop) is an app that runs on top of the same engine and makes games
without writing code. Projects are `~/Documents/Oyunlarım/<name>/project.json` files (`"format": "nexvyn-workshop"`):
settings, variables, event rules (`on` / `if` / `do`), levels (tile strings and objects in 2D, ground and objects in
3D), your own drawings, models, sounds and layers.

- A project is played by interpreting the JSON, not by generating code: `nexvyn.workshop` (2D, on top of
  `nexvyn.game`) and `nexvyn.workshop3d` (3D, on top of `g3d`). Event blocks compile to the `ws.on(...)` API that
  scripts also use; object scripts can define `start()`, `update(dt)`, `touch(other)`.
- **Export** writes a standalone `.nxvapp`: `main.lua`, `project.json`, the assets, and a copy of the runtime and the
  library. The copy in the bundle is loaded before the system's one.
- Every picture, sound and model in the library is generated with `tools/gen_workshop.py`. To check the templates and
  samples: `python tools/lua_check.py --workshop`.

The project format, behaviours, events and the whole API: [GAME_ENGINE_PROJECTS.en.md](GAME_ENGINE_PROJECTS.en.md).

---

## 5. 3D with g3d

`g3d` is a small real-time 3D renderer. It runs on the GPU: a depth buffer, per-pixel lighting, fog and textures. The
target is 30–60 thousand triangles per frame. If the GPU path is unavailable (or the system setting `g3d.gpu` is
`false`), the same calls fall back to the older CPU renderer: no textures, a few thousand triangles. `g3d.gpu()` tells
you which one is active.

```lua
local cube
function app.load() cube = g3d.mesh("cube", 1) end
function app.draw(w, h)
  gfx.clear("#101418")
  g3d.begin(0, 0, w, h, 60)
  g3d.camera(0, 2, 5, 0, 0, 0)
  g3d.light(0.5, 1, 0.3, 0.35)
  g3d.draw(cube, 0, 0, 0, sys.time(), 0, 0)
  g3d.finish()
end
```

Create models once in `load` and reuse them every frame. OBJ files (and `map_Kd` textures in the `mtl`) can be loaded.

**Glow:** adding `"glow"` to the `g3d.draw` flags adds the model's color on top of whatever is behind it (additive
blending); overlapping parts look brighter: stars, sparks, light trails, lamp halos. Glow models are drawn last, stay
behind the solid geometry in front of them but cover nothing; fog fades them too. Use dark colors for faint light and
combine with `"unlit nocull"`. It is the same in Lua, JavaScript and Python. The CPU fallback draws glow models like
normal models.

```lua
g3d.draw(spark, x, y, z, 0, 0, 0, 0.3, 0.3, 0.3, theme.orange, "unlit nocull glow")
```

Built-in (C++) apps also have `g3d::append(dst, src, matrix, color)` (adds a transformed copy of a model to another
model: hundreds of objects, one draw call), `DrawOpts::additive` (the counterpart of the `"glow"` flag) and
`g3d::lastDrawCalls()` next to `g3d::lastTriangles()`. Example use: the Showcase app
(`source/apps/techdemo_scenes.cpp`).

Full reference: [SDK.en.md section 8b](../Reference/SDK.en.md#8b-3d--g3d). Examples of what can be done:
[LUA_CAPABILITIES.en.md](LUA_CAPABILITIES.en.md). Template: "3D scene" in Studio.

---

## 6. Packaging: .nxvapp v2

An app is distributed in two forms:

- **Folder:** `Name.nxvapp/` (during development).
- **Single file (v2):** a zip of the folder's contents with the `.nxvapp` extension. `app.json` is at the root of the
  zip.

To package:

```
python tools/nxvapp_pack.py Uygulamam.nxvapp              # Uygulamam.nxvapp (zip) is written next to the folder
python tools/nxvapp_pack.py Uygulamam.nxvapp -o dist/x.nxvapp
python tools/nxvapp_pack.py Uygulamam.nxvapp --index      # also prints the repository entry (size, sha256 …)
```

The packer checks `app.json` (id, name, entry file, `minSdk` format, unknown permissions), skips hidden files and adds
`manifest.sha256`. Studio's **Export Package** command produces the same format.

On the user side:

- Opening a `.nxvapp` file in Files shows the install sheet: **Run** (once, without installing) or **Install**.
- Verification status: *Verified* when every file matches `manifest.sha256`, *Modified* when not, *Unsigned* when there
  is no manifest. This is an integrity check, not a signature.
- Installation is atomic. A new version with the same `id` replaces the old copy; the app's data
  (`~/Library/Application Support/<id>`) is kept.
- Built-in (C++) apps cannot be packaged.

Details: [NXVAPP_FORMAT.en.md](NXVAPP_FORMAT.en.md).

Check on the computer before publishing:

```
python tools/lua_check.py path/to/Uygulamam.nxvapp     # Lua: syntax + a few hundred headless frames
node tools/js_check.mjs path/to/Uygulamam.nxvapp       # JavaScript: the same check
```

For Python there is `tools/py_check.py`; its use is described in [PY_APPS.en.md](PY_APPS.en.md).

---

## 7. Community catalog

The App Market lists a JSON repository index (`index.json`). The address is in **System Settings > Apps > Community app
repository**; when it is empty the default catalog is used:
`https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json` (while that returns 404, the older
`AppStore/catalog.json` and `store/catalog.json` in turn). Everything in the official catalog is reviewed by the
maintainer before it is published: the full flow (fork, `Store/<Apps|Games|Themes|Fonts>/...`, checks, pull request,
review) is in `SDK/Publishing/PUBLISHING.en.md` of the release repository.

To publish an app in the catalog:

1. Build the package with `--index`: `python tools/nxvapp_pack.py Uygulamam.nxvapp --index`. The entry in the output
   contains the `size` and `sha256` values.
2. Host the `.nxvapp` file at a public address (for example a GitHub release).
3. Complete the entry with the `download` address, icon, screenshots, `minSdk` and `permissions`, and have it added to
   the catalog's `apps` array.

The store checks the `sha256` of every download and does not install on a mismatch. If `minSdk` is newer than the
system, the app is listed but cannot be installed. If `version` is greater than the installed version, "Update"
appears.

You can host your own catalog as well: publish an `index.json` in the same format and put its address in the settings
field. Entry format: [NXVAPP_FORMAT.en.md section 6](NXVAPP_FORMAT.en.md#6-community-repository-indexjson).

---

## 8. Overlay: replacing system files

A file in `sdmc:/NexvynOS/System/Overlay/` is used instead of the system file at the same relative path in romfs. This
way a translation fix, a wallpaper or a new version of a built-in Lua app can be shipped without rebuilding the `.nro`.

| Overlay path | Replaces |
|---|---|
| `Overlay/Languages/tr/shell.json` | `romfs:/System/Languages/tr/shell.json` |
| `Overlay/Wallpapers/x.jpg` | `romfs:/System/Wallpapers/x.jpg` |
| `Overlay/Applications/notes.nxvapp/` (with `app.json` inside) | The whole bundle |
| `Overlay/Applications/notes.nxvapp/lang/tr.json` | Only that file |

- File reads, images, fonts, sounds, language files and the app scan follow this rule.
- Changes take full effect when Nexvyn OS restarts.
- The user sees the Overlay status in **System Settings > About > System folder** and can move the folder aside as
  `Overlay.off` with **Reset system updates**.
- Overlay cannot change the built-in C++ code; it only replaces romfs files.

---

## 9. Testing in Ryujinx

Nexvyn OS runs in the Ryujinx emulator. Hardware-dependent features (USB, MTP, brightness, launching games, PC games)
are off there.

### Running by hand

- `./build.sh run`: builds and opens `NexvynOS.nro` in Ryujinx.
- The path to Ryujinx is given with the `RYUJINX` environment variable. The default path in the scripts is the project
  owner's computer; give your own path.
- Copy your app into `NexvynOS/Applications/` in Ryujinx's SD card folder.

### Automatic tour with autorun.txt

If `sdmc:/NexvynOS/autorun.txt` exists, Nexvyn OS runs the commands in it one by one at startup. Screenshots are saved
as `sdmc:/NexvynOS/autoshots/<name>.png`. Lines starting with `#` are comments.

```
# go through the setup assistant in Turkish, open the app, take a screenshot
setup tr
wait 2
launch com.adiniz.uygulama
wait 3
shot uygulamam
click 640 360
wait 1
shot tiklandi
exit
```

Commands: `wait <sec>`, `setup <lang>`, `unlock`, `launch <appId> [arg]`, `shot <name>`, `launcher`,
`search <text>`, `overview`, `cc`, `nc`, `close`, `closeall`, `minimize`, `click <x> <y>`, `rclick`, `mclick`,
`move`, `key <name>`, `text <text>`, `dark <0|1|2>`, `lang <code>`, `log <message>`, `exit`. Besides these there are
commands such as `drag`, `dpad`, `a`, `up`, `down`, `set`, `saver`, `desktop`, `closeask`. The current list and syntax
are at the top of `source/wm/shell_autorun.cpp`.

Delete `autorun.txt` after testing; otherwise it runs again at every startup.

### tools/ryu_test.sh

```
tools/ryu_test.sh <cikti.png> [bekleme_sn] [keep]
```

It closes a running Ryujinx, starts `NexvynOS.nro`, waits the given time (default 14 s) and saves a screenshot of the
window. If the third argument is `keep`, Ryujinx stays open. The script runs in Git Bash and uses PowerShell (Windows).
Together with `autorun.txt`, an app tour can be run headless.

---

## 10. Built-in (native) app development

This section is for those who contribute to Nexvyn OS itself. Built-in apps are C++17 classes compiled into
`NexvynOS.nro`. Detailed guide: [APP_GUIDE.en.md](APP_GUIDE.en.md).

### Requirements

- devkitPro: devkitA64, libnx, switch-sdl2, switch-sdl2_ttf/image/mixer, switch-curl, switch-mbedtls.
- Build: `./build.sh` (output `NexvynOS.nro`).
- Single-file check: `tools/check.sh source/apps/app_<id>.cpp` (syntax and type check with the real compiler).

### Parts of an app

- `source/apps/app_<id>.cpp` (extra files `source/apps/<id>_*.cpp/.h`; file names must be unique in the repository).
- `romfs/Applications/<id>.app/`: `app.json`, `icon.png`, `lang/en.json`, `lang/tr.json`.
- An entry in `tools/apps_manifest.json`: name, category, icon glyph and colors. The icon is generated from this list
  with `python tools/gen_assets.py apps`.

### REGISTER_APP

```cpp
#include "../wm/app.h"
#include "../wm/registry.h"
#include "../core/ui.h"
#include "../core/theme.h"

class HelloApp : public App {
public:
    int count = 0;
    void draw(float w, float h) override {
        const Palette& p = theme::p();
        ui::label(TRF("hello.clicked", std::to_string(count)), 20, 20, 15, p.text);
        if (ui::button(TR("hello.click"), Rect(20, 50, 140, 30), ui::BTN_PRIMARY)) count++;
    }
};
REGISTER_APP("hello", HelloApp)
```

The `App` class offers `onStart(arg)`, `onOpen(arg)`, `update(dt)`, `draw(w, h)`, `onEvent`, `menus()`/`onMenu(id)`
and `canClose()`. Use `aliveToken()` in callbacks that run later, such as network, dialogs or timers; the app object is
deleted when the window closes.

### UI: ui::

Widgets are immediate mode: the same call draws and returns the interaction. `ui::button`, `toggle`, `checkbox`,
`slider`, `segmented`, `popup`, `textField`, `listRow`, `sidebarItem`, `groupBox`, `beginScroll/endScroll`,
`contextMenu`, `TextArea` and others are in `source/core/ui.h`. Use `ui::pushId(i)/popId()` in loops. Touch scrolling,
controller focus and right click (X button, long press) are handled by the widgets.

### Translation: i18n

- Strings live in `romfs/Applications/<id>.app/lang/en.json` and `tr.json` and are namespaced by the app id:
  `save_title` in `notes.app` → `TR("notes.save_title")`. `TRF("key", a, b)` fills `{0}`, `{1}`.
- Shared strings are ready: `common.*`, `places.*`, `date.*`, `cat.*`, `color.*`, `sys.*`.
- Every key must exist in both languages: `python tools/lang_check.py`.
- Turkish strings are written with the correct characters (ç ğ ı İ ö ş ü).

### The modding core: modkit

The apps in the modding folder (Mod Manager `modmanager`, Cheat Manager `cheats`, System Modules `sysmodules`, Game
Info `gameinfo`) share a core: `source/core/modkit.h`. If you are writing a new built-in tool that touches game mods,
start here.

- **Paths:** `contentsDir(tid)`, `romfsDir`, `exefsDir`, `cheatsDir`, `flagsDir`, `exefsPatchesRoot()`,
  `modsLibraryRoot()` (`sdmc:/mods`), `nexvynModsRoot()` (`sdmc:/NexvynOS/Mods`: disabled mods and records).
- **Safety:** `safeSdPath(path)` before every write; `safeRel()` for archive entries (absolute paths, drive letters,
  `..` and control characters are rejected), `safeName()` for file names. Modding apps do not write outside the SD
  card.
- **Games:** `requestTitles(rescan)`, `titles()`, `findTitle()`, `icon()`; `revision()` increases when the list or a
  build ID changes. It does not block the main thread; scans run on the modkit worker.
- **Build ID:** `buildId(tid, &out)` does not block (`BID_PENDING` / `BID_READY` / `BID_UNKNOWN`). `cheatName()` gives
  the cheat file name, `hex()` the `.ips` name.
- **Cheats:** `cheat::parse()` (with Atmosphère's rules), `readToggles` / `writeToggles` (`toggles.txt`), and for the
  running game `cheat::attach`, `list`, `toggle` (dmnt:cht).
- **System:** `runningTitle()`, `programRunning()`, `launchProgram()` / `terminateProgram()` (pm:shell),
  `systemInfo()` (firmware, Atmosphère, emuMMC, SD space).
- **Long jobs:** `post(job)` runs jobs such as copying and extracting one after another on the modkit worker. Write
  the result to your own shared state and read it in `update()`/`draw()`.
- Horizon services other than ns are called only on a real console (`sys::realHardware()`); elsewhere the result is
  "unknown". Shared UI pieces are in `source/apps/modding_ui.*`, mod records in `source/apps/mod_store.*`. Turkish
  Patches (`turkceyama`) and Save Backup (`savebackup`) are separate apps; [TURKISH_PATCHES.en.md](TURKISH_PATCHES.en.md)
  describes the design.

### Contribution rules

- Everything must be real: no fake data and no simulated features. The console's services, the real file system and
  the network are used.
- Every string the user sees is translated.
- Other companies' product names are not used in the UI as Nexvyn OS features: "Search", "Apps", "Window View",
  "Night Mode", "Dock layout", "Taskbar layout". Third-party services are named only when describing themselves
  (Steam, CorkDeck, provider names).
- The license is GPL-3.0-or-later. Only GPLv3-compatible code is linked; external homebrew programs are not linked,
  only launched. If you add a new component, update [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
- After checking a file, try it in Ryujinx with `autorun.txt` (section 9).

---

## English summary

This guide takes a developer from zero to a published Nexvyn OS app. It links to the detailed references instead of
repeating them: [sdk/SDK.en.md](../Reference/SDK.en.md) (full API), [JS_APPS.en.md](JS_APPS.en.md), [PY_APPS.en.md](PY_APPS.en.md),
[GAME_ENGINE.en.md](GAME_ENGINE.en.md), [NXVAPP_FORMAT.en.md](NXVAPP_FORMAT.en.md) and [APP_GUIDE.en.md](APP_GUIDE.en.md).

1. **Studio:** *New Project* opens a gallery of ten templates (blank Lua, blank JS, utility, platformer, arena
   shooter, puzzle, 3D scene, network app, blank Python, Snake in Python). `.py` files open with Python
   highlighting; Python templates use `minSdk` 1.3. Studio has live error checking, completion, Run with a console, sprite,
   tilemap and scene editors, an *Ask AI* panel that never edits files, and *Export Package*.
2. **app.json:** `id`, `main`/`runtime`, `window`, `gamepad`, `fileTypes`, `minSdk` (1.0 Lua, 1.1 JS, 1.2 nexvyn.game and
   permissions, 1.3 Python) and `permissions` (enforced for apps installed on the SD card; decided once at install time).
3. **Languages:** Lua 5.4, JavaScript (QuickJS-ng) and Python (pocketpy, SDK 1.3) share one API. `nexvyn.game` is
   Lua-only. Two-finger gestures arrive as `"pinch"` (`e.scale`, a factor since the last event) and `"rotate"`
   (`e.angle`, radians) events in all three languages.
4. **nexvyn.game:** a 2D engine in `romfs:/System/Lua/nexvyn/` (`require("nexvyn.game")`); samples Pixel Koşu and Uzay Arenası.
   Game Engine (`gamemaker`, formerly Game Workshop) projects are `project.json` files interpreted by `nexvyn.workshop` /
   `nexvyn.workshop3d` and exported as standalone `.nxvapp` bundles; see [GAME_ENGINE_PROJECTS.en.md](GAME_ENGINE_PROJECTS.en.md).
5. **g3d:** GPU 3D renderer with a CPU fallback. The `"glow"` flag draws additively (stars, sparks, light trails);
   native code also has `g3d::append` (merge transformed copies into one mesh, one draw call) and
   `g3d::lastDrawCalls()`.
6. **Packaging:** `python tools/nxvapp_pack.py <folder> [-o out.nxvapp] [--index]` writes a zip `.nxvapp` v2 with
   `manifest.sha256`. Check bundles with `tools/lua_check.py` and `tools/js_check.mjs`.
7. **Catalog:** the App Market reads an `index.json` (default `sonerx7/Nexvyn-OS-NX/Store/catalog.json`, configurable in
   *Settings > Apps*) and verifies each download's SHA-256.
8. **Overlay:** files under `sdmc:/NexvynOS/System/Overlay/` replace the romfs file with the same relative path.
9. **Testing:** `./build.sh run`, `sdmc:/NexvynOS/autorun.txt` scripts (command list at the top of
   `source/wm/shell_autorun.cpp`) and `tools/ryu_test.sh <out.png> [wait] [keep]` for Ryujinx screenshots.
10. **Native apps:** C++17 classes registered with `REGISTER_APP`, strings in `lang/*.json` read with `TR()`, immediate
    mode `ui::` widgets, an entry in `tools/apps_manifest.json`, and `tools/check.sh` per file. Modding tools share
    `source/core/modkit.h`: Atmosphère paths, SD-only path checks (`safeSdPath`, `safeRel`), installed titles, build
    ids, the cheat parser and dmnt:cht client, system facts and a worker thread (`post`). No other vendors'
    product names in the UI; GPL-3.0-or-later.
