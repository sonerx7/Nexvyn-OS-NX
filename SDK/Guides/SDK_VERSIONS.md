# SDK versions: 1.0 to 2.0 (1.13)

What each version of the Nexvyn OS app SDK added, which Nexvyn OS release shipped it and which languages have it. The
function-by-function contract is the [SDK reference](../Reference/SDK.md) (section 1, *SDK versions*); the compatibility
rules behind this page are in [COMPATIBILITY.md](COMPATIBILITY.md).

## Contents

1. [Three version numbers](#1-three-version-numbers)
2. [At a glance](#2-at-a-glance)
3. [Version by version](#3-version-by-version)
4. [minSdk and targetSdk](#4-minsdk-and-targetsdk)
5. [Nothing is removed, only deprecated](#5-nothing-is-removed-only-deprecated)
6. [Which languages get new APIs](#6-which-languages-get-new-apis)
7. [Picking minSdk for your app](#7-picking-minsdk-for-your-app)

## 1. Three version numbers

| Number | Example | Meaning |
|---|---|---|
| **Nexvyn OS** | `1.3.8` | the system release (major.minor.patch), shown in Settings > About |
| **SDK** | `1.13` / `2.0` | the API surface apps are written against (major.minor); `sys.sdkVersion()` returns it |
| **Runtime engine** | Lua 5.4.7, QuickJS-ng 0.17.0, CPython 3.12.16, Native AOT ABI v1 | the interpreter or compiler behind one language |

A new SDK function raises the SDK minor version and comes with a new Nexvyn OS minor release. A change in how an
existing function behaves would raise the SDK major version, and only apps that target the new SDK would get it
(section 4).

## 2. At a glance

| SDK | First Nexvyn OS | Headline | Languages |
|---|---|---|---|
| 1.0 | 1.0.0 | Lua apps: drawing, widgets, files, network, system, sound, timers, translations, 3D | Lua |
| 1.1 | 1.0.0 | JavaScript runtime with Promises; 3D textures on the GPU | Lua, JavaScript |
| 1.2 | 1.0.0 | `nexvyn.game` 2D engine, `sys.sdkVersion()`, `minSdk` and `permissions` | Lua, JavaScript (`nexvyn.game`: Lua) |
| 1.3 | 1.0.0 | Python runtime (pocketpy) | Lua, JavaScript, Python |
| 1.4 | 1.0.0 | every permission enforced, sharing, scheduled notifications, `nxv://` links, lifecycle callbacks | Lua, JavaScript, Python |
| 1.5 | 1.0.0 | Squirrel, C and Java runtimes; Python system library | all six |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games`, text to speech; the `"python3"` runtime (CPython 3.12) | see section 3 |
| 1.7 | 1.1.0 | `g3d.voxels` voxel worlds; pixel-art textures on meshes | JavaScript (voxels); Lua, JavaScript (textures) |
| 1.8 | 1.2.0 | `g3d.model`: `.glb` / `.gltf` / `.fbx` models with materials, textures and skeletal animation | all six |
| 1.9 | 1.2.2 | runtime library; feed, photo and short-video apps; the pbr renderer (NexGFX) | Lua, JavaScript, Python, C |
| 1.10 | 1.2.2 (same build for now) | native runtime: full-screen C / C++ apps, Native SDK 1.0 (no script API change) | C / C++ (`nxn_*`) |
| 1.11 | 1.2.2 | kept folders and save backups for script apps (`ui.chooseFolder`, `fs.folderGrants`, `fs.saveBackup`...) | Lua, JavaScript, Python, C |
| 1.12 | 1.2.2 | language parity with the native SDK (`ui.tokens`, `audio.stopAll`, C `input_action`) | Lua, JavaScript, Python, C |
| 1.13 / 2.0 | 1.3.8 | **Nexvyn OS N2 Architecture:** NXUI Retained & Semantic UI Engine (`nxui.*` / `nxn_nxui_*`), 4 Official Primary Runtimes (Lua 5.4.7 Generational GC, QuickJS-ng ES2023, CPython 3.12 default for `targetSdk: "2.0"`, Native C/C++ ABI v1), `loadingHint`, Unified Input Router, Smart Creator & Port Kit | Lua, JavaScript, Python 3.12, Native C/C++ |

SDK 1.0 to 1.6 were all built during the development of Nexvyn OS 1.0.0, the first public release, which has SDK 1.6.
A language that arrived later got the whole earlier SDK with it: Squirrel, C and Java started at SDK 1.5 with
everything from 1.0 to 1.4.

## 3. Version by version

### SDK 1.0 (Nexvyn OS 1.0.0)

- The Lua runtime and the modules every later language shares: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`,
  `audio`, `input`, `timer`, `TR`, `g3d`.

### SDK 1.1 (Nexvyn OS 1.0.0)

- The JavaScript runtime (QuickJS-ng, ES modules) with the same modules; asynchronous calls return Promises when the
  callback is left out.
- `g3d` textures on the GPU.

### SDK 1.2 (Nexvyn OS 1.0.0)

- The `nexvyn.game` 2D engine for Lua (`require("nexvyn.game")`): scenes, sprites, tilemaps, physics, particles,
  tweens.
- `sys.sdkVersion()`; app.json `minSdk` and `permissions`; the single-file `.nxvapp` v2 with `manifest.sha256`.

### SDK 1.3 (Nexvyn OS 1.0.0)

- The Python runtime (pocketpy) with the same modules; asynchronous calls take callbacks.

### SDK 1.4 (Nexvyn OS 1.0.0)

- Every permission is enforced (`network`, `files`, `launch`, `notifications`), with the user's answer kept per app.
- `sys.share` and app.json `shareTargets`; `sys.schedule` / `unschedule` / `scheduled`; `sys.hasPermission` /
  `requestPermission`; `sys.memory`; `sys.appUrl` and `nxv://` links in `sys.open`.
- Callbacks `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved`.
- Signed packages; the 64 MB script memory limit for Lua apps too.

### SDK 1.5 (Nexvyn OS 1.0.0)

- Three more runtimes on one shared implementation: Squirrel 3.2 (`"squirrel"`), C compiled on the console by TinyCC
  (`"c"`, `nexvyn.h`) and Java on miniJVM (`"java"`, `"mainClass"`).
- `g3d.setColor` / `flat` / `triangles` / `setTexture` / `texture` / `free` as functions.
- The Python system library: `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`.

### SDK 1.6 (Nexvyn OS 1.0.0)

- `fs.unzip` (in the background, with progress) and `sys.games` with the new `"games"` permission, in Lua,
  JavaScript, Python and Squirrel.
- `sys.speak` / `sys.stopSpeaking` (text to speech, no permission) in every runtime.
- The `"python3"` runtime: CPython 3.12 with its standard library.

### SDK 1.7 (Nexvyn OS 1.1.0)

- `g3d.voxels` voxel worlds in JavaScript: chunk streaming, a terrain generator, light, meshes built on background
  threads, saving, ray casts and box physics.
- `mesh:setTexture(path, pixelated)` in Lua and JavaScript: textures magnified without smoothing.

### SDK 1.8 (Nexvyn OS 1.2.0)

- `g3d.model` and `g3d.loadModel` (parsed in the background): `.glb`, `.gltf`, `.fbx` (and `.obj`, `.stl`) with node
  hierarchy, materials, embedded and external textures and skeletal animation (play with crossfade, stop, node
  positions and matrices for attachments); `g3d.drawMatrix`; skinning on the GPU. In every runtime (Squirrel, C, Java
  and `"python3"` through `g3d.model*` functions).
- Time limits: the main file and `app.load` get 10 seconds, other callbacks 3 seconds; time in the HOME menu, asleep
  or in a system dialog does not count. A stopped callback ends an app that targets SDK 1.8 or newer with the error
  screen; an older app is held and the user picks **Wait** or **Close**.
- For C apps that target SDK 1.8: `#include` reads only the app's own files and the SDK headers, and inline assembly
  is refused.

### SDK 1.9 (Nexvyn OS 1.2.2)

- **Runtime library:** `net.request{url, method, body, contentType, headers}` in Lua; JavaScript `TextEncoder` /
  `TextDecoder`, `URL` / `URLSearchParams`, `structuredClone`; the Python `str` methods pocketpy lacked,
  `dict.setdefault` / `fromkeys`, `pow()`, and the system modules `urllib.parse`, `html`, `uuid`.
- **Feed, photo and short-video apps** (reference section 8d): `net.request` options (JSON, form, multipart and file
  bodies, `saveTo`, upload progress, cookies, retries, offline cache), `net.cancel`, `net.clearCookies`,
  `net.clearCache`; the WebSocket client (`net.ws`, `wsSend`, `wsPoll`, `wsClose`, `wsState`); `net.oauth`;
  `gfx.imageUrl` / `imageState`; `media.*` players; `ui.beginFeed` / `feedItem` / `endFeed`, `ui.pager`,
  `ui.richText` / `measureRichText`; `sys.relativeTime`.
- **The pbr renderer**, NexGFX 1.0, opt-in per app with `g3d.renderer("pbr")`: metallic-roughness materials with
  normal, occlusion and emissive maps (from model files or `g3d.material`), real-time lights (`g3d.addLight` /
  `updateLight` / `removeLight` / `clearLights` / `lights`), sun and spot shadows (`g3d.shadows`), HDR with tone mapping,
  bloom and MSAA (`g3d.postfx`), hemisphere or cube map ambient (`g3d.environment`), `g3d.drawInstanced`, `g3d.caps`,
  `g3d.rendererInfo`. An app that never asks for it renders exactly as with SDK 1.8.
- Lua, JavaScript, Python (`"python"` and `"python3"`) and C. Guides: [PBR_GAME_RECIPE.md](PBR_GAME_RECIPE.md),
  [SOCIAL_APP_RECIPE.md](SOCIAL_APP_RECIPE.md), [MAKE_A_SOCIAL_APP.md](MAKE_A_SOCIAL_APP.md).

### SDK 1.10 (Nexvyn OS 1.2.2, same build for now)

- **Native runtime:** `"runtime": "native"` with `"mode": "window"` or `"fullscreen"` and a `.nxvmod` as `"main"`: a C / C++
  app that runs inside Nexvyn OS, in a window or full screen (the user can switch), and reports crashes. Its interface is the Native
  SDK 1.0 (`nxn_*`, `nexvyn_native.h`): lifecycle, display (GL / GLES), input, audio, files, logging and the
  `NXN_EVENT_RESIZE` event for docking. Kit and guide: [NATIVE_KIT.md](NATIVE_KIT.md).
- No script function changed. The SDK number is raised so that older systems refuse native packages cleanly: a native
  package carries `"minSdk": "1.10"` (`nxv-native package` writes it and `tools/nxvapp_pack.py` requires it), so a system
  with SDK 1.9 or older lists it as "needs a newer Nexvyn OS" instead of trying to read the `.nro` as a script.
- Full-screen apps are not started when Nexvyn OS runs in applet mode (started from the Album): the system asks the
  user to start it in title mode (hold R while starting a game).

### SDK 1.11 (Nexvyn OS 1.2.2, same build for now)

- **Kept folders and save backups** for script apps, the same functions the native `nxn_pick` / `nxn_grant_*` /
  `nxn_save_*` have, from one core unit (`source/core/appkeep.cpp`): `ui.chooseFolder({title, remember}, callback)`,
  `fs.folderGrants`, `fs.folderGranted`, `fs.revokeFolder`, `fs.savePath`, `fs.saveBackup`, `fs.saveRestore`,
  `fs.saveBackups`, `fs.saveDeleteBackup`. Lua, JavaScript, Python (`"python"` and `"python3"`) and C, with the same
  names and results. Copying runs on a worker thread. Older apps are not affected: nothing existing changed.

### SDK 1.12 (Nexvyn OS 1.2.2)

- **Language parity with the native SDK:** `ui.tokens()` returns the system look as one table (like `nxn_ui_tokens_get`),
  `audio.stopAll()` stops every sound (like `nxn_sfx_stop_all`), and C gets `input_action` (the other languages had
  `input.action`). Lua, JavaScript, Python and C. Older apps are not affected.

### SDK 1.13 / 2.0 (Nexvyn OS 1.3.8 — N2 Architecture)

- **NXUI Retained & Semantic UI Engine (`nxui.*` and `nxn_nxui_*`):** Declarative, automatic-layout containers (`row`,
  `column`, `card`, `scrollBegin`, `canvasBegin`) and semantic controls (`label`, `badge`, `button`, `toggle`, `slider`,
  `textfield`, `dropdown`, `tabs`, `table`, `virtuallist`, `dialog`, `spacer`, `moveFocus`, `activateFocused`,
  `tokens`), shared identically across Lua, JavaScript, Python and Native C/C++ (`#include <nexvyn/nxn_nxui.h>`).
- **4 Official Primary Runtimes:**
  1. **Lua 5.4.7** (`"runtime": "lua"`, Generational GC step per frame).
  2. **JavaScript ES2023** (`"runtime": "js"`, QuickJS-ng 0.17.0 with bytecode cache and adaptive GC).
  3. **Python 3.12** (`"runtime": "python3"` or `"runtime": "python"` with `"targetSdk": "2.0"`, running on CPython 3.12.16).
  4. **Native C/C++** (`"runtime": "native"`, devkitA64 GCC AOT `.nxvmod` / `.nro` with Frozen ABI v1 and Native SDK 1.2).
- **On-Demand Compatibility Runtimes (`ComponentService`):** PocketPy (`"runtime": "python"` with `targetSdk < 2.0`),
  TinyCC JIT C (`"runtime": "c"`), Squirrel 3.2 (`"runtime": "squirrel"`) and Java miniJVM (`"runtime": "java"`) are
  managed as on-demand system components (`romfs:/System/Components/`) with 100% backward compatibility.
- **Manifest & Tools:** `"loadingHint": true` extends the loading watchdog threshold to 120 s. Smart Creator
  (`python tools/nxv.py create <lang> <id> --template <basic|game|social|port>`) and Port Kit (`python tools/nxv_port.py`)
  generate ready-to-run projects.

## 4. minSdk and targetSdk

```json
{
  "minSdk": "1.9",
  "targetSdk": "1.9"
}
```

- **`minSdk`** is the oldest SDK the app runs on: the newest SDK feature it uses. A system with an older SDK does not
  install it, the App Market shows *This app needs a newer version of Nexvyn OS* and never offers it as an update, and a
  copy already on the SD card opens a window that says so (with a Software Update button) instead of running.
- **`targetSdk`** is the SDK you built and tested the app on. Later systems keep behaving the way that SDK did for your
  app. Default: `minSdk`, or `"1.0"` when neither is given; a `targetSdk` below `minSdk` counts as `minSdk`. Studio
  writes the current SDK into both for new projects.
- **Raising `targetSdk` is a choice.** Read the "for apps that target SDK x" notes in the reference, test on the new
  system, then raise it. The example so far is SDK 1.8's time limit: with `targetSdk` 1.8 or newer a stuck callback
  ends the app with the error screen; with an older one the user is asked *Wait* or *Close*.
- `runtimeVersion` (optional) records the engine version you tested on, for example `"2.2"` for pocketpy.
- Unknown app.json fields and unknown permissions are ignored, so a manifest written for a newer system never breaks an
  older one.

## 5. Nothing is removed, only deprecated

Every function in the reference keeps working in every later Nexvyn OS. A function that gets a replacement becomes
*deprecated*: it works exactly as before, and the first call in a run writes
`deprecated: <name> still works; use <replacement>` to the app's log (Studio's console shows it). Deprecated today:

| Old | Use instead | What happens |
|---|---|---|
| `require("snx.*")` (Lua) | `require("nexvyn.*")` | loads the same module; a note in the app log |
| permission `"clipboard"` | nothing: `sys.clipboard` needs no permission | accepted and ignored |
| app ids `finder`, `launchpad` | `files`, `launcher` | `sys.launch`, `nxv://` links and shortcuts resolve them |

Runtimes are not removed either while apps use them, and a new engine version must run every App Market app, game and
sample unchanged before it ships.

## 6. Which languages get new APIs

From SDK 1.9 on, new functions come to **Lua, JavaScript, Python** (`"python"` and `"python3"`) **and C**, with the same
names in all four. **Squirrel and Java are frozen at SDK 1.8**: everything they have, SDK 1.8's `g3d.model` functions
included, keeps working on every later Nexvyn OS and their apps on the App Market need no change, but nothing new is
added to them. A `minSdk` or `targetSdk` above 1.8 brings nothing new to these two languages. Frozen is not removed:
bug and security fixes in these runtimes still ship.

Start new apps in Lua, JavaScript, Python or C.

## 7. Picking minSdk for your app

Set `minSdk` to the highest row whose feature you use (and at least the row of your language):

| You use | minSdk |
|---|---|
| Lua and the base modules | 1.0 (or leave it out) |
| JavaScript | 1.1 |
| `nexvyn.game`, `permissions` in app.json | 1.2 |
| Python (`"python"`) | 1.3 |
| sharing, scheduled notifications, `nxv://` links, `app.suspend` / `resume` / `autosave` and the other lifecycle callbacks | 1.4 |
| C | 1.5 |
| `fs.unzip`, `sys.games`, `sys.speak`, the `"python3"` runtime | 1.6 |
| `g3d.voxels`, pixel-art textures | 1.7 |
| `g3d.model`, `g3d.loadModel`, `g3d.drawMatrix` | 1.8 |
| `g3d.renderer("pbr")` and the rest of *Modern rendering*, `net.request` options, `net.ws`, `net.oauth`, `gfx.imageUrl`, `media.*`, `ui.beginFeed` / `ui.pager` / `ui.richText`, `sys.relativeTime` | 1.9 |

To use something newer only where it exists, check at run time and keep a fallback:

```lua
local app = {}

local function sdkAtLeast(major, minor)
  local v = sys.sdkVersion and sys.sdkVersion() or "1.0"   -- sys.sdkVersion arrived in SDK 1.2
  local a, b = v:match("^(%d+)%.(%d+)")
  a, b = tonumber(a) or 1, tonumber(b) or 0
  return a > major or (a == major and b >= minor)
end

function app.load()
  if sdkAtLeast(1, 9) then g3d.renderer("pbr") end   -- older systems keep the basic renderer
end

return app
```

Testing for the function itself works too (`if g3d.renderer then ... end`). Compare versions as numbers, not as text:
`"1.10"` is newer than `"1.9"`.

## See also

[SDK reference](../Reference/SDK.md) · [Compatibility](COMPATIBILITY.md) · [Developer guide](DEVELOPER_GUIDE.md) ·
[AI-assisted workflow](AI_WORKFLOW.md)
