# AI agent guide: build, package, test and ship a Nexvyn OS app

Operational manual for an AI coding agent that has only this repository. It tells you what to run, in
which order, and what the tools check. Every command, field, name and limit below exists in the files
of this `SDK/` folder; where something is not verified or not available, the text says so.

Paths are relative to the repository root unless they start with `SDK/Languages/c/native-kit`
(the native kit root: run native commands from there). Documentation is English; the products you
build are not (see section 8).

Companion files: [llms.txt](llms.txt) (index of every document and header), [CHANGELOG.md](CHANGELOG.md),
[README.md](README.md), [AI/AI_RULES.md](AI/AI_RULES.md) (MUST / MUST NOT rules),
[AI/system-prompt.md](AI/system-prompt.md) (API context pack), [AI/checklist.md](AI/checklist.md).

## 0. Work order

1. Pick the runtime (section 2). Install only what that runtime needs (section 3).
2. Create the project from a template (section 4). Never start from an empty folder.
3. Edit `app.json` (section 5) and write the code against the real API: [Reference/SDK.md](Reference/SDK.md)
   (scripts) or the headers in `SDK/Languages/c/native-kit/sdk/native/include/nexvyn/` (native).
   Do not invent functions: if a name is not in the reference or a header, it does not exist.
4. Fill all eight `lang/*.json` files (section 8).
5. Check, build, package (section 6). Fix every error; read every warning.
6. Test on an emulator or a console (section 7). Read the app log and look at one or two key screenshots.
7. Report what you ran, what passed, and what you could not test.

## 1. Version numbers (which one is current)

| Number | Current value | Where it is used | Meaning |
|---|---|---|---|
| Nexvyn OS release | the latest release of the public repository (see `CHANGELOG.md` of the repository root) | Settings > About | the system version |
| SDK (script API) | **1.16** | `minSdk`, `targetSdk`, `sys.sdkVersion()` | callable API for Lua, JavaScript, Python, C scripts |
| Native SDK | **1.3** | `minNative`, `targetNative`, `nxn_info_string(NXN_INFO_NATIVE_VERSION)` | `nxn_*` API for C/C++ modules |
| Native ABI | **v1**, frozen, add-only | `NXN_ABI_VERSION` | a module built with any older kit keeps loading |

`SDK/VERSION.json` carries the same numbers (`os`, `sdk`, `native`, `nativeAbi`, `requiredLocales`).

Rules:

- `minSdk` is the oldest SDK your app runs on: the newest SDK feature you use (or the floor of your
  runtime, section 2). A system with an older SDK refuses to install the app and shows
  "needs a newer Nexvyn OS". Compare versions as numbers: `1.10` is newer than `1.9`.
- `targetSdk` is the SDK you built and tested on. Default: `minSdk`, else `1.0`; a value below `minSdk`
  counts as `minSdk`. Write `"targetSdk": "1.16"` for a new app. Raising it opts in to behavior changes
  documented as "for apps that target SDK x" (for example a stuck callback ends the app from 1.8 on).
- `minNative` is the oldest Native SDK a native module needs: the newest `nxn_*` function it imports.
  An older system refuses a module that imports a name it does not have. `targetNative` is the Native
  behavior level you tested (default `minNative`). Write `"1.3"` for both when using 1.3 APIs. For an older compatibility floor, use only
  APIs available on the supported systems and test on those systems. Section 9 lists the native API additions.
- A native package must also carry `"minSdk": "1.10"` (the SDK that introduced the native runtime);
  `nxv_native package` writes it and the packer refuses a native package without it.
- The value `"2.0"` is not an SDK release. It is accepted as a target marker: `"runtime": "python"` with an
  effective `targetSdk` of 2.0 or newer selects CPython 3.12 instead of PocketPy, and a native app with a
  target of 2.0 or newer gets the responsive live-resize default. The packer warns that `targetSdk 2.0` is
  above SDK 1.16. Do not copy it: use `"runtime": "python3"` and `"targetSdk": "1.16"`, and keep
  `targetNative` at the Native SDK you actually tested. Never set `minNative` or `minSdk` to `2.0`.
- Existing apps keep working across versions: nothing is removed, only deprecated.
  Details: [Guides/COMPATIBILITY.md](Guides/COMPATIBILITY.md), [Guides/SDK_VERSIONS.md](Guides/SDK_VERSIONS.md).

## 2. Choose the runtime

`app.json` `"runtime"` selects the engine; a `main` file extension selects it when `runtime` is missing
(`.py` means `"python"`, so write `"python3"` explicitly).

| Runtime | `"runtime"` | `main` | Floor `minSdk` | Engine | Use it for |
|---|---|---|---|---|---|
| Lua | `lua` (default) | `main.lua` | 1.0 | Lua 5.4.7 | tools, dashboards, 2D games (`nexvyn.game`), anything UI-heavy |
| JavaScript | `js` (or `javascript`) | `main.js` | 1.1 | QuickJS-ng 0.17.0, ES2023, Promises | network and JSON apps |
| Python | `python3` | `main.py` | 1.6 | CPython 3.12.16 | data processing, standard library |
| Native C/C++ | `native` | `<name>.nxvmod` | 1.10 (+ `minNative`) | AArch64 module, ABI v1 | heavy computation: emulators, ports, 3D engines, codecs |
| SDL2 | `native` | `<name>.nxvmod` | 1.10 | the kit's SDL2 driver inside a Nexvyn window | existing SDL2 programs and ports |
| C script | `c` | `main.c` | 1.5 | TinyCC compiles the bundle on the console | small compatibility apps |
| PocketPy, Squirrel, Java | `python` (target below 2.0), `squirrel`, `java` | `main.py`, `main.nut`, `app.jar` | 1.3 / 1.5 / 1.5 | compatibility engines | existing apps only; Squirrel and Java are frozen at SDK 1.8 |
| Web | no packaged runtime | none | none | the Browser app | web pages run in the Browser; they are not `.nxvapp` apps |

Choose by workload:

- Utility, editor, dashboard, social or network app: **Lua, JavaScript or Python** with `nxui.*`
  (retained, automatic layout) or `ui.*` (immediate). No build step, small packages, the OS look for free.
- 2D game: Lua with `nexvyn.game` ([Guides/GAME_ENGINE.md](Guides/GAME_ENGINE.md)); 3D game: `g3d.*` in a
  script ([Guides/PBR_GAME_RECIPE.md](Guides/PBR_GAME_RECIPE.md)) or native with GL/GLES or `ngfx_*`.
- Emulator, existing engine, source port, heavy computation: **native**
  ([Guides/NATIVE_GUIDE.md](Guides/NATIVE_GUIDE.md), [Guides/PORT_AND_LAUNCHER.md](Guides/PORT_AND_LAUNCHER.md)).
- A script app cannot load native code today, and there is no native-engine plus script-UI hybrid.
- New projects use Lua, JavaScript, Python or native. The others exist for old apps.
- Native apps are not sandboxed by the kernel (section 14). Prefer a script runtime when it is enough.
- Script limits: the `"python3"` runtime runs at most 4 apps at once and is not available when Nexvyn OS runs
  as an applet (started from the Album). New script functions come to Lua, JavaScript, Python (`python3`) and C.

## 3. Set up the toolchain from zero

### 3.1 Everything: Python and the repository

- Python 3.8 or newer on `PATH` as `python` (Windows) or `python3`/`python` (Linux, macOS). The SDK tools use only
  the standard library. Tested with 3.12; other versions are not verified.
- Download this repository (zip or `git clone`) and keep the `SDK/` layout. Tools find templates relative to
  their own location: `SDK/Tools/nxv/nxv.py` reads `SDK/Languages/<language>/template`.
- Script apps (Lua, JavaScript, Python, C script): nothing else is required. The language syntax checkers
  (`lua_check.py`, `js_check.mjs`, `py_check.py`, `rt_check.py`) belong to the Nexvyn OS source checkout, which
  is not part of this repository. Without it `nxv.py check` runs the manifest, file, permission, translation and
  `store.json` checks and prints a note that the language checker was skipped. Say so in your report.
- You also need the system itself to run the app: `NexvynOS.nro` from the releases of this repository
  (section 7).

### 3.2 Native C/C++: devkitPro

Needed only for `"runtime": "native"`. The pinned versions are in
`SDK/Languages/c/native-kit/tools/toolchain.json`: devkitA64 `r29-3` (GCC 15.2.0), libnx `4.10.0-1`,
and the `switch-*` portlibs `switch-sdl2`, `switch-mesa`, `switch-glad`, `switch-curl`, `switch-mbedtls`,
`switch-zlib`, `switch-libpng`, `switch-libjpeg-turbo`, `switch-freetype`, `switch-ffmpeg` and the SDL2 add-ons.
The OS itself is built in the Docker image named in the same file (`image`).

| Host | Install | Environment |
|---|---|---|
| Windows | the devkitPro installer, with the `switch-dev` package group | installs to `C:\devkitPro`; the CLI starts devkitPro's own msys2 shell by itself (`C:/devkitPro/msys2/usr/bin/bash.exe`, override with `DKP_BASH`) |
| Linux | devkitPro's `pacman`, then `sudo dkp-pacman -S switch-dev` and the portlibs above | export `DEVKITPRO=/opt/devkitpro`; `$DEVKITPRO/devkitA64/bin` and `$DEVKITPRO/tools/bin` on `PATH`; `cmake`, `make` and (optional) `ninja` on `PATH` |
| macOS | the same devkitPro `pacman` package manager for macOS | same as Linux |

On Linux and macOS the CLI runs `sh -c` in the current environment and requires `DEVKITPRO`.
The package-manager commands follow devkitPro's own documentation and were not run for this guide; the CLI behavior
described here comes from `tools/nxv_native/__main__.py`.

Then, from `SDK/Languages/c/native-kit`:

```text
python tools/nxv_native doctor
```

Fix every line that says `MISSING`. If the toolchain-version checker is not in your kit copy, `doctor` skips that
check; compare your installed versions with `tools/toolchain.json` yourself.

Only projects that include SDL (the `sdl2`, `gl`, `port` templates and ports) also need the kit's SDL2 once:

```text
python sdk/native/sysroot/build.py sdl2-nexvyn
```

It installs into `build/native-sysroot` inside the kit; `build` finds it there, or pass `--sysroot <dir>` or set
`NEXVYN_SYSROOT`. The `app` and `game` templates do not need it (they bundle Dear ImGui 1.91.5 from `sdk/native/sysroot/vendor`
and need the `switch-glad` package).

Windows: extract the kit under a short path (for example `C:/NexvynSDK`). Deep paths can exceed the compiler's
object-file limit even when CMake configures. If a build reports an overlong object path or cannot create an `.o.d`
file, build from a shorter location.

## 4. Create the project

### 4.1 Script app (Lua, JavaScript, Python, C script)

Two generators exist. Both write `app.json`, a placeholder `icon.png`, all eight `lang/*.json` and a runnable `main.*`.

```text
# from the language templates (lua, js, py, sq, c, java):
python SDK/Tools/nxv/nxv.py new lua "My Tool" --id com.you.mytool --author "You" --dir work
# the N2 creator (lua, js, python, native); picks a runtime from a profile when --runtime is missing:
python SDK/Tools/nxv/nxv.py create "My Tool" --id com.you.mytool --profile utility --runtime lua --dir work/MyTool
python SDK/Tools/nxv/nxv.py create --profile network --recommend-only
```

- `new` writes `work/My Tool.nxvapp/` (a folder). Add `--store` for the App Market layout (`<slug>/source/`,
  `store.json`, `README.md`, `screenshots/`). Its Python template already uses `"python3"`.
- `create` profiles: `calculator`, `utility` (Lua), `network` (JavaScript), `data` (Python), `game`, `qemu`,
  `emulator`, `port` (native). `--runtime` takes `lua`, `js`, `python`, `native`.
- **Always pass `--id com.<you>.<app>`.** The defaults differ and neither is yours: `new` uses `com.<author>.<name>`
  (`com.yourname.<name>` without `--author`), `create` uses `com.nexvyn.<name>`. Ids are permanent: updates match by id.
- `create` writes `"minSdk": "1.12"`, `"targetSdk": "2.0"` and, for Python, `"runtime": "python"`. After creating,
  edit as section 1 says: `"targetSdk": "1.16"`, `"runtime": "python3"` with `"minSdk": "1.6"` or newer. It writes
  `targetNative`, `uiApi` 2 and `uiTheme` 2 for every runtime: **delete `targetNative` in script apps** (it is a
  native-only field; keep `uiApi`/`uiTheme` only if you need the N2 NXUI behavior levels), and for the native profile set
  `"targetNative": "1.3"` after testing with Native SDK 1.3. It also writes a `perfBudget` object; the OS does not read it
  (it is a note for you and for reviewers).
- Replace `icon.png` before publishing (section 17).

Run the Lua template in an emulator before editing; the lifecycle is `app.load(arg)`, `app.update(dt)`,
`app.draw(w, h)`, `app.event(e)`, `app.suspend()`, `app.resume()`, `app.close()` (Lua; JavaScript and Python
use the same names). Details: [Reference/SDK.md](Reference/SDK.md) section 2.

### 4.2 Native app

```text
cd SDK/Languages/c/native-kit
python tools/nxv_native new notes --template app --dir projects
```

Templates: `app` (UI app with the OS look, default), `game` (loop, resize/focus/suspend, GL quads, action map,
mixer sound, save file), `port` (glue for an existing CMake project: `fetch.py`, patches), `sdl2`, `gl`,
`vulkan` (Vulkan-aware, GL fallback, section 10.4), `emu-skeleton`, `decomp-skeleton`, `shared-lib`.
Names: lower-case letters, digits, `-`, `_`, starting with a letter (max 41 characters).
The generator writes `CMakeLists.txt`, `src/`, `app.json` (id `com.example.<name>`, `"runtime": "native"`,
`"mode": "window"`, `minNative`/`targetNative` = the kit's Native SDK, `minSdk`/`targetSdk` `1.10`), a placeholder
icon and eight starter `lang/*.json`. Each template overrides some defaults (its `template.json`): `app` is category
`utilities`, permission `files`, `liveResize`, a 720x480 window; `game` is category `games`, no permissions and
`"mode": "fullscreen"`; `port` is category `games`, permission `files`, a 960x600 window; `vulkan` is category `developer`,
no permissions. Edit `id`, `name`, `author`, `category`, `permissions`, and set
`"targetSdk": "1.16"` if you use script-SDK semantics (native apps normally leave it).

An existing CMake or SDL2 project: use `--template port` (see [Guides/PORT_AND_LAUNCHER.md](Guides/PORT_AND_LAUNCHER.md),
[Guides/PORTING_LARGE_GAMES.md](Guides/PORTING_LARGE_GAMES.md), [Guides/NATIVE_COMPAT.md](Guides/NATIVE_COMPAT.md)).
Before you ship a port, go through [Guides/PORTING_CHECKLIST.md](Guides/PORTING_CHECKLIST.md) (input gestures, memory budget,
`"fullscreenPause"`, GL or Vulkan, testing).
The golden samples under `AI/golden/` carry `"targetSdk": "2.0"`. The current SDKs are `1.16` / `1.3`.
Finished, reviewed starting points with all eight locales: `Samples/c/golden/` (`native-app`, `native-game3d`,
`native-tool`, `native-port`, `native-emu`) and `AI/golden/` (script apps).

## 5. `app.json` reference

JSON, UTF-8, at the root of the bundle. Fields the checkers read (`nxv.py check`, `nxvapp_pack.py`, and the
loader). Unknown fields and unknown permissions are ignored by the OS (older systems accept newer manifests);
a field with an unusable shape is a clean install error.

### 5.1 Identity and display

| Field | Type | Rule |
|---|---|---|
| `id` | string, required | reverse domain, `[A-Za-z0-9_-]` first, then also `.`; at most 128 characters; no `..`. Unique and permanent |
| `name` | string or `{code: text}`, required | the check reports a missing name; a map without `en` warns and the Store requires `en`. Product names may be the same in every language |
| `description` | string or map | short sentence; missing gives a warning |
| `version` | string | dotted numbers, 1 to 4 parts (`1.0`, `1.2.3`); compared numerically. Raise it with every update |
| `author`, `homepage` | string | shown in About and the App Market |
| `category` | string | safe values: `system`, `productivity`, `office`, `utilities`, `media`, `internet`, `games`, `switch`, `developer`, `emulator`, `showcase`, `other`. `nxv.py check` also accepts `education`, `themes`, `fonts`, `runtimes`; the packer also knows `ai`. Unknown: warning, shown as `other` |
| `icon` | string | default `icon.png`; PNG, 256x256 (128x128 accepted; other sizes warn). Required |
| `type` | string | `app` (default), `game`, `lib`, `theme`, `runtime`. Eight locales are enforced for `app` and `game` |

### 5.2 Entry and runtime

| Field | Type | Rule |
|---|---|---|
| `runtime` | string | `lua`, `js`/`javascript`, `python`, `python3`, `squirrel`, `c`, `java`, `native` (section 2). Unknown value: error |
| `main` | string | entry file; default per runtime (`main.lua`, `main.js`, `main.py`, `main.nut`, `main.c`, `app.jar`). The file must exist in the bundle |
| `mainClass` | string | Java only |
| `mode` | string | native only: `window` (default in the kit) or `fullscreen`; the user can switch while it runs. `windowed` is the old spelling of `window`; `exclusive` (own `.nro`) is a retired fallback |
| `window` | object | `width`, `height` (content size), `minWidth`, `minHeight`: numbers; `resizable`: boolean |
| `singleInstance`, `hidden`, `dpadArrows` | boolean | window behavior; listed in the package format, `singleInstance` is described in [Reference/SDK.md](Reference/SDK.md) section 1 |
| `gamepad` | boolean | `true`: the controller goes to the app instead of moving the cursor (games). `check` warns when `category` is `games` and it is missing |
| `fileTypes` | string array | extensions the app opens (`[".txt"]`) |
| `shareTargets` | string array | `text`, `url`, `file`, `image` or an extension (`.txt`); arrives in `app.load(arg)` / `app.open(arg)` |
| `loadingHint` | boolean | SDK 1.13: the not-responding dialog waits 120 s instead of 5 s for an app that loads a lot |
| `liveResize` | boolean | native, `minNative` 1.1 or newer: the app receives live sizes while the user drags a window edge |
| `vulkan` | boolean | native windowed/fullscreen module only; declares Vulkan awareness; does not enable it (section 10.4) |
| `memory` | number | native: heap in MB (1 to 16384) set aside at start; anything else is ignored |

### 5.3 Versions and compatibility

| Field | Type | Rule |
|---|---|---|
| `minSdk` | string | `"1.16"` style (`\d+.\d+` or three parts). Floors by runtime in section 2. Native: at least `1.10` |
| `targetSdk` | string | section 1. Warned when missing, below `minSdk`, or above 1.16 |
| `minNative`, `targetNative` | string | native only (section 1) |
| `runtimeVersion` | string | optional record of the engine version you tested |
| `minOs` | string | oldest Nexvyn OS release that can run it (`"1.3.0"`); a pre-release counts as older than its release |
| `arch` | string | only `aarch64` |
| `build` | integer >= 0 | build counter within one `version` |
| `uiApi`, `uiTheme` | integer >= 1 | NXUI behavior and token levels (default 1 = legacy) |
| `dataSchema` | integer >= 0 | version of the data format the app writes; raising it makes an update copy the user's data first (`dataVersion` is the old name; both with different values is an error) |
| `needs` | array | shared libraries: `"id"`, `"id@6.1"` or `{"id", "version"}` |
| `size`, `hashes` | number, object | written by the packer of the Nexvyn OS source checkout (`--stamp`); you normally leave them out. `hashes` is `{file: sha256}`, 64 hex digits each |
| `provider` | object | `lib`/`runtime` packages only |
| `perfBudget` | object | free-form note; not read by the OS |

### 5.4 Permissions

`"permissions": []` lists what the app needs beyond its own folders. Valid: `network`, `files`, `launch`,
`notifications`, `games`. `clipboard` is retired (every app may use `sys.clipboard`; listing it only warns).
Every permission is enforced for apps installed from the SD card; the user decides once, at install.
A missing array means "ask about everything". The check fails when code calls an API that needs a permission
the manifest does not declare (for example `net.*` without `network`) and warns about declared permissions with
no matching call. Section 13 has the table.

### 5.5 Package limits

At most 20000 files and 1 GiB unpacked; larger packages are refused before anything is written. Hidden files
(names starting with `.`) and `__pycache__` are not packaged. `app.json` must be at the zip root.
Full format: [Guides/NXVAPP_FORMAT.md](Guides/NXVAPP_FORMAT.md).

## 6. Check, build, package

### 6.1 Script apps

```text
python SDK/Tools/nxv/nxv.py check "work/My Tool.nxvapp"
python SDK/Tools/nxv/nxv_i18n.py --check "work/My Tool.nxvapp"
python SDK/Tools/nxv/nxv.py pack "work/My Tool.nxvapp" -o dist/mytool.nxvapp
```

- `check` exit codes: 0 passed, 1 problems, 2 wrong usage. It reports `error:` and `warning:` lines. Run it on every
  edit. It does not run the language checker without a Nexvyn OS source checkout (`--sdk <checkout>`), so a syntax
  error can pass the PC-side check. Test in the emulator for that.
- `pack` runs the eight-locale check and refuses to write when it fails. It writes a deterministic zip (sorted
  entries, fixed timestamps, `manifest.sha256` last). The output must be outside the bundle.
- Signing (optional): `pack --sign key.pem --sdk <source checkout>` uses the checkout's tools. A key is an ECDSA
  P-256 PEM (`openssl ecparam -name prime256v1 -genkey -noout -out key.pem`); keep it secret and back it up: updates
  must be signed with the same key. The App Market does not need your signature (section 17); sign only packages you
  distribute yourself.
- Java: `nxv.py build <bundle> --sdk <checkout>` compiles `src/` into `app.jar`; the template ships a built jar.

### 6.2 Native apps

From `SDK/Languages/c/native-kit` (the `new`, `build`, `check-design`, `package` and `run` flow below was run on Windows
from an exported copy of this kit with devkitA64 15.2.0 for the `app` template; Linux and macOS were not run):

```text
python tools/nxv_native build projects/notes --clean
python tools/nxv_i18n.py --check projects/notes
python tools/nxv_native check-design projects/notes     # ImGui apps: OS design rules
python tools/nxv_native package projects/notes          # -> projects/notes/build/notes.nxvapp
```

- `build` configures CMake in `projects/notes/build`, builds `<name>.nxvmod`, and runs `check-win` on it
  (module identity, position-independent code, no text relocations, only imports the host offers). It fails
  before you can package a module that cannot load. Options: `--debug` (`-O0 -g`), `--clean`, `--sysroot DIR`.
  Release builds use `-O2` and LTO (`-DNEXVYN_LTO=OFF` turns LTO off).
- `package` re-checks locales (eight required) and design findings, stages `build/bundle/<name>.nxvapp` with
  `app.json` (`runtime: native`, `main: <name>.nxvmod`, `minNative`, `minSdk >= 1.10`) and your `lang/`, `data/`,
  `romfs/` folders, packs it, and prints the build-id. Keep `build/<name>.nxvmod.debug` of every release you
  ship: crash symbolization needs it. `--sign key.pem` signs the package.
- Shared libraries: `python tools/nxv_native lib <dir>` builds `.nxvlib`; `check-lib` verifies it.
- Shaders: `python tools/nxv_native shader FILE --target gl|vulkan [-o out.spv]` validates GLSL
  (`--target vulkan` needs glslang and SPIRV-Tools).
- Make the next steps cheap: use `nxn_fs_*` folders for data, keep the build folder of each release.

## 7. Install and test

### 7.1 The system

Get `NexvynOS.nro` from the releases of this repository. Copy it to `sdmc:/switch/` on the console's SD card, or open
it in a PC emulator that runs homebrew `.nro` files. This SDK does not provide, link or support an emulator, keys or
firmware: use your own. Use a separate emulator profile for tests so your real saves stay untouched.
Always start from one current `NexvynOS.nro`; old copies in the same folder can be started by mistake.

### 7.2 Install an app

| Target | Command |
|---|---|
| SD folder (emulator or a mounted card) | `python SDK/Tools/nxv/nxv.py install "work/My Tool.nxvapp" --sd <SD root>` (`<SD root>` holds `NexvynOS/`; or set `NXV_SD`) |
| same, and open at boot | add `--autorun` (writes `NexvynOS/autorun.txt`; delete it afterwards) |
| native | `python tools/nxv_native run projects/notes --sd <SD root>` (from the kit; copies only, never starts anything) |
| console over FTP | `python SDK/Tools/nxv/nxv.py push <bundle> --host <console IP> [--port 5000] [--user U --password P] [--packed]`; start the console's FTP server feature first |
| by hand | copy the folder or the `.nxvapp` into `<SD>/NexvynOS/Applications/`; opening a `.nxvapp` in Files shows an install sheet with Run and Install |

Wait until a large package has finished installing before launching it; reopen the Launcher to see a new folder.
`install` and `run` replace the app folder directly. A `.nxvapp` **file** (dropped into `Applications/`, opened in
Files, or from the App Market) whose id **and** `version` are already installed is left alone: **bump `version` for
every test build** you install that way, or delete the installed folder first. A different id installs beside it.

### 7.3 Scripted run (emulator or console)

Create `<SD>/NexvynOS/autorun.txt`; Nexvyn OS runs it line by line after boot while the file exists:

```text
setup en
wait 4
launch com.you.mytool
wait 6
shot start
wclick 0.5 0.5
wait 2
shot after_click
stats after_click
log done
exit
```

Commands: `wait`, `setup <lang>`, `unlock`, `launch <appId> [arg]`, `close`, `closeall`, `shot <name>`, `click x y`,
`wclick fx fy`, `move`, `drag`, `scroll`, `finger <n> down|move|up x y`, `key`, `hold`, `text`, `dpad`, `padhold`,
`dark 0|1|2`, `lang <code>`, `langreq <code>`, `sleep`, `wake`, `stats [label]`, `log <message>`, `exit`.
The full table and the screenshot and log rules are in [Guides/TEST_WORKFLOW.md](Guides/TEST_WORKFLOW.md).

- Screenshots land in `<SD>/NexvynOS/autoshots/<name>.png`. Look at one or two key ones; do not scan dozens.
- Logs: `<SD>/NexvynOS/System/Logs/system.log`, `System/Logs/Apps/<app id>.log` (what your app printed,
  errors, refused permissions, native `nxn_log` and stdout/stderr), `System/Logs/Crashes/` (native crash reports).
- Search logs for `not responding`, `stopped`, `stall`, `fps`, `FAIL`, `error`; add `log` marks to cut by step.
- Delete `autorun.txt` when done.
- Console profile: emulator frame rates are not console frame rates. Compare before/after under one profile and
  never quote emulator numbers as console numbers. Only a console gives console numbers
  ([Guides/TEST_WORKFLOW.md](Guides/TEST_WORKFLOW.md) section 5).
- Test both handheld and docked, window and full screen, touch only and controller only, a fresh install and an
  update from the previous version ([Guides/INPUT_AND_PLAY_MODES.md](Guides/INPUT_AND_PLAY_MODES.md)).
- Report what you could not test (physical multi-touch, console timing, thermal behavior are not provable in an
  emulator).

## 8. Localization (eight locales are required)

New apps, games, ports and launchers must ship complete dictionaries for **`en`, `tr`, `de`, `es`, `fr`, `ja`, `ko`,
`zh`** as `lang/<code>.json` (type `app` and `game`).

How it is checked (`SDK/Tools/nxv/nxv_i18n.py`, run by `nxv.py check`, `nxv.py pack`, `nxv_native package`):

- `lang/` exists and has `en.json` and all eight files;
- every file is valid JSON with no duplicate keys, no empty keys or empty values; nested objects are flattened to
  dotted keys;
- `en.json` is the source: every other file must have exactly its keys (missing and unknown keys are errors);
- format tokens must match `en` in kind and count (`{0}`, `{name}`, `%d`, `%s`, `%1$s`).

```text
python SDK/Tools/nxv/nxv_i18n.py --check <bundle>        # exit 0 = PASS, 1 = FAIL with the list
python SDK/Tools/nxv/nxv_i18n.py --pseudo "Long label {0}"   # pseudo-localized string for layout stress tests
```

What no tool checks: translation quality, hard-coded labels, CJK layout. Do the following yourself: all user-facing
text (menus, errors, launcher and settings pages) goes through `TR("key")` (scripts) or `nxn_tr("key")` (native);
translate real text, not copies of English; test a long language (German) and CJK in the real layout; keep numbers
and dates locale-neutral or formatted with tokens. `app.json` `name`/`description` maps carry the same eight codes
in the generated projects. A running app is told when the system language changes: `app.language_changed(code)` (script) or
`NXN_EVENT_LANGUAGE` then `nxn_app_language()` (native, `minNative` 1.1 or newer); reload your text then.
Fallback when a key is missing: exact locale, base locale, `en`, then the key itself.
Contract: [Guides/LOCALIZATION_CONTRACT.md](Guides/LOCALIZATION_CONTRACT.md). Task recipe:
[AI/tasks/add-language.md](AI/tasks/add-language.md). Store listings need all eight languages for `subtitle` and
`description` (section 17).

## 9. Input

Support touch, controller (attached controller pair in handheld mode, detached controllers, wireless full-size controller), keyboard and mouse, in handheld and
docked mode. Nothing may need touch when docked, and nothing may need a controller when handheld.
Contract: [Guides/INPUT_CONTRACT.md](Guides/INPUT_CONTRACT.md),
[Guides/INPUT_AND_PLAY_MODES.md](Guides/INPUT_AND_PLAY_MODES.md).

| Runtime | Touch | Controller | Keyboard, mouse |
|---|---|---|---|
| Native `nxn_*` | `nxn_input_poll` then `nxn_input_touch(i, &t)` for `i < state.touch_count`: **up to 16 contacts, stable `id`** (0, 1, 2...; one finger is always 0) when the manifest says `"minNative": "1.1"` or newer. `minNative` 1.0 keeps the old single-pointer touch | `buttons`, `pressed`, `released`, `lx ly rx ry`, `NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL` (the user's mapping) | `nxn_input_key_held`, `nxn_input_key_poll`, `nxn_input_mouse` (`NXN_CAP_USB_INPUT`) |
| SDL2 (kit) | `SDL_FINGERDOWN` / `SDL_FINGERMOTION` / `SDL_FINGERUP`, up to 16 fingers with stable `SDL_FingerID` (needs `minNative` 1.1). SDL also derives mouse events | one pad, 16 buttons, 4 axes (game controller mapping built in) | USB keyboard (HID usage = SDL scancode), mouse, `SDL_TEXTINPUT` |
| Lua, JavaScript, Python, C script | **one pointer** (`"mousedown"`, `"mousemove"`, `"mouseup"`, `e.touch` is true for a finger) plus synthesized gestures `"scroll"`, `"pinch"` (`e.scale`), `"rotate"` (`e.angle`). Raw finger list only from SDK 1.16 (`input.touches()`, below) | `"paddown"` / `"padup"` (`e.pad`), `input.stick("left"|"right")`, `input.action(name)` | `"keydown"`, `"keyup"`, `"text"`, mouse events |
| Web (Browser app) | pointer, mouse and wheel events only; **no DOM `TouchEvent`**; the Browser reports no touch points | Gamepad API | keyboard, mouse |

Rules that follow from the truth above:

- Native games read every finger **by `id`, never by array index**; keep a bounded id map; an id that disappears
  is a release or cancel; clear captures on focus loss, suspend, close. Positions are window-surface pixels: map
  them through your viewport.
- Script apps (Lua, JavaScript, Python `"python3"`; SDK 1.16, `"minSdk": "1.16"`): `input.touches()` returns every finger as
  `{id, x, y, phase}` (`phase` is `"began"`, `"moved"`, `"stationary"` or `"ended"`; read by `id`, not by index),
  and touch-made mouse and gesture events carry `e.touches`. It is empty without input focus. There is no manifest
  `multitouch` flag: do not invent one. Do not rely on `touches` in Squirrel, C scripts, Java or PocketPy (`"runtime": "python"` below `targetSdk` 2.0).
  Lua: `for _, t in ipairs(input.touches()) do gfx.circle(t.x, t.y, 30, theme.accent) end`.
  Handheld shows touch, docked TV does not: keep controller and mouse paths working.
- Native ImGui apps: call `nxn_imgui_input(backend, state, dt)` once per frame after `nxn_input_poll`, forward
  lifecycle events to `nxn_imgui_input_event(event)`, and draw with the frame layer of `<nexvyn/nxn_os_ui.h>`
  (`nxn_os_frame_begin` / `nxn_os_frame_end`). `nxn_nxui_*` does not paint inside a GL window
  (`nxn_nxui_end_ex()` returns `NXN_ERR_UNSUPPORTED`).
- Ports: `<nexvyn/nxn_port_input.h>` (header-only) supplies input profiles; `nxn_rumble` gives haptics.
- Touch targets at least 44 px, no hover-only actions, TV safe margin 5 percent, no hard-coded 1280x720: handheld
  is normally 1280x720, docked 1920x1080 (720p selectable). Native: `NXN_EVENT_RESIZE`, `NXN_EVENT_DOCK`.
- In full screen the user leaves by holding the minus button for one second; never use a held minus.
- Emulator touch tests: the autorun command `finger <n> down|move|up x y` (two ids make pinch/rotate/pan).
- Controller on the console profile: HOME, L+R (hold), and the menu bar belong to Nexvyn OS.

What the Native SDK versions add (`minNative`):

| `minNative` | Adds |
|---|---|
| 1.0 | `nxn_init`/`nxn_run`, display (GL/GLES), input, audio, files, logging, `NXN_EVENT_RESIZE`/`QUIT`/`FOCUS`, crash reports |
| 1.1 | multi-touch, USB keyboard/mouse/text, `NXN_EVENT_DOCK`/`SUSPEND`/`RESUME`/`THEME`/`MENU`, `nxn_sys.h` services (notify, clipboard, rumble, picker, save backups, permissions), `nxn_ui.h` tokens and `nxn_tr`, `nxn_menu.h`, shared libraries, TLS and C++ exceptions on by default (TLS and exceptions: `native.windowedTls`, `native.windowedEh`), app-owned heap arena, `liveResize` |
| 1.2 | `nxn_window_set_title`/`set_mode`/`set_modified`, `nxn_power_get` + `NXN_EVENT_POWER`, `nxn_dialog`/`nxn_prompt`; add-ons announced by capability bits: `NXN_EVENT_LANGUAGE` + `nxn_app_language()`, `nxn_input_relative_mouse` / `nxn_input_mouse_delta` and `nxn_input_pad_count` / `nxn_input_pad_poll` (`NXN_CAP_INPUT_ROUTER`, up to 8 controllers) |
| 1.3 | See [Native SDK releases](Guides/SDK_VERSIONS.md#native-sdk-releases) for sparse VM, frame pacing, CPU information, audio statistics, per-pad input and stream cancellation. |

Capability bits (`nxn_caps_get`, `NXN_CAP_*`) say what the running system offers; test the bit before an optional
call, and treat any negative result you do not know as a failure.

## 10. Graphics

### 10.1 Script apps

- 2D: `gfx.*` (immediate) and `ui.*` / `nxui.*` (widgets); the OS compositor draws, no GL setup.
- 2D games: `nexvyn.game` (Lua `require("nexvyn.game")`): scenes, sprites, tilemaps, physics, particles, tweens.
- 3D: `g3d.*` loads `.glb`, `.gltf`, `.fbx`, `.obj`, `.stl`. The default renderer is the basic GLES2 one; opt in to
  the PBR renderer (NexGFX: metallic-roughness, lights, shadows, HDR, bloom, MSAA) with `g3d.renderer("pbr")`
  (`minSdk` 1.9). Check `g3d.caps()` / `g3d.rendererInfo()`. 3D collision `phys` and navigation `nav` need
  `minSdk` 1.15.
- Idle apps (SDK 1.16, Lua, JavaScript, Python `"python3"`): return `false` from `update` when nothing animates; the window is
  drawn only on input, a timer callback or `ui.requestFrame()`. Call `ui.requestFrame()` after a network or job
  result changes what is on screen, or the screen stays stale. Any other return value keeps drawing every frame.
- `gfx.size()` returns the current content size and changes on resize.
  [Reference/SDK.md](Reference/SDK.md) sections 3, 4, 4a, 8b, 8c, 8e, 8f.

### 10.2 Native: OpenGL / OpenGL ES (the default path)

- One display and one GL context per app. Desktop OpenGL core profile up to 4.3 (`NXN_GFX_GL_CORE`, default 4.3)
  or OpenGL ES up to 3.2 (`NXN_GFX_GLES`, default 3.2). No compatibility profile, no shared contexts. SDL2 defaults
  to ES 2.0 unless you ask for 3.x or core 4.3. Maximum surface 4096x4096; framebuffer 0 has RGBA8, 24-bit depth,
  8-bit stencil.
- Load GL functions only through `nxn_display_proc(name)` (glad: `gladLoadGLLoader((GLADloadproc)nxn_display_proc)`);
  SDL2 forwards `SDL_GL_GetProcAddress` to it. Never link `libEGL` or `libGLESv2` directly (the import check
  rejects it). All GL calls run on the thread that opened the display.
- Frame: `nxn_event_poll` every frame, `nxn_display_swap` once per frame (it paces to the OS frame; do not
  busy-wait), on `NXN_EVENT_RESIZE` call `nxn_display_resize` then fix your viewport.
- Capability bits and ceilings (`NXN_CAP_GL_CORE`, `NXN_CAP_GLES`, `gl_max_*`, `gles_max_*`) are advertisements,
  not hardware probes: also check `glGetString(GL_VERSION)`, extensions and function pointers.
- Windowed `.nxvmod` modules can only import what the host offers (`sdk/native/toolchain/nxwin_imports.txt`); the
  kit's `libnexvyn_window.a` carries ES 3.2 and desktop-core GL shims that resolve through `nxn_display_proc`.
- deko3d is not a path for existing GL ports.

### 10.3 Native: NexGFX scene API (`ngfx_*`)

`<nexvyn/nexgfx_native.h>`: baked 3D scenes with the PBR renderer. Scenes are baked
`.nxsc` + `.nxtx` files; the baking tool `nxv_asset` is part of the Nexvyn OS source checkout and is not in this
repository, so use pre-baked scenes you were given. The calls: `ngfx_device_create`, `ngfx_device_prepare`, `ngfx_scene_load`/`ngfx_scene_step`, `ngfx_render`. It needs
`NXN_CAP_NEXGFX` (OpenGL 4.3 core). It draws what you give it; menus, HUD and art direction are yours.
Example: `sdk/native/examples/scenes`.

### 10.4 Native: Vulkan

**Vulkan is on by default but can be missing. Always keep a GL fallback.**

- Since Nexvyn OS 1.4.0 the release build includes Vulkan. It is on by default, but apps get it only when the
  driver check at start succeeds (a failed check leaves it off). It was verified on the console with the
  `vk_canary` example and the GPU load test. Older releases (1.3.x) have no Vulkan.
- Apps **must** check the capability `NXN_CAP_VULKAN` at run time and fall back to GL when it is absent. The
  header-only helper `nxn_vk_available()` in `<nexvyn/nxn_vk.h>` checks `NXN_CAP_VULKAN`, the
  `NXN_GFX_API_VULKAN` build bit and the weak `nxn_vk_proc` resolver together. Then check the advertised version
  ceiling (`vk_max_major`, `vk_max_minor` in `nxn_caps`) and that every entry point you need resolves.
- Without the capability, an SDL2 window created with `SDL_WINDOW_VULKAN` fails and `SDL_GetError()` says
  `Vulkan is not available on this system`.
- `"vulkan": true` in `app.json` only declares a Vulkan-aware windowed or fullscreen module and makes the packer
  run the import check; it does not turn Vulkan on. Select the graphics path before acquiring the host Vulkan
  lookup (it reserves the content producer).
- Kit parts: template `vulkan`, examples `hello_vk` and `vk_canary`, `<nexvyn/nxn_imgui_vk.h>` (opt-in
  `NEXVYN_IMGUI_VULKAN=ON`), link-time shims (`NEXVYN_VK_SHIMS=1` with the `vulkan-headers` sysroot recipe).
  Details: [Guides/NATIVE_KIT.md](Guides/NATIVE_KIT.md) ("Vulkan in the native kit").

Minimal, header-correct pattern (the capability decides; GL is the fallback):

```c
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_vk.h>

static int app_main(int argc, char** argv) {
    (void)argc; (void)argv;
    nxn_display_params dp = NXN_STRUCT_INIT(nxn_display_params);
    dp.api = NXN_GFX_GL_CORE;                       /* the path that always exists */
    nxn_display* display = NULL;
    if (nxn_display_open(&dp, &display) != NXN_OK) return 1;
    nxn_log(nxn_vk_available() ? NXN_LOG_INFO : NXN_LOG_WARN,
            nxn_vk_available() ? "Vulkan advertised; GL stays the fallback" : "no Vulkan: using GL");
    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE) nxn_display_resize(display, ev.width, ev.height);
        }
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        for (uint32_t i = 0; i < in.touch_count; ++i) {
            nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
            if (nxn_input_touch(i, &t) != NXN_OK) continue;   /* t.id is the stable identity */
        }
        /* ... draw with GL through nxn_display_proc, then: */
        nxn_display_swap(display);
    }
    nxn_display_close(display);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
```

This snippet uses only declarations in `nexvyn_native.h`, `nxn_vk.h`, `nxn_display.h`, `nxn_event.h`, `nxn_input.h`
and `nxn_sys.h`. It was compiled syntax-only with devkitA64 GCC 15.2.0 (`-Wall -Wextra`, as C11 and as C++17) against
the headers of this kit; it was not linked or run. Drop it into a project's `src/` as `main.c` or `main.cpp` and add
your drawing.

## 11. Audio

- Script apps: `audio.play(name_or_path)`, `audio.tone`, `audio.music` and the music controls, `audio.stopAll()`
  (SDK 1.12). The system mixer and the user's volume apply.
- Native: `nxn_audio_open` / `nxn_audio_queue` (a push stream of your own), `nxn_audio_clear` (`NXN_CAP_AUDIO_CLEAR`),
  or the OS mixer with `nxn_sfx_play(name_or_path, volume, loops)`, `nxn_tone(freq, seconds, volume, wave)`,
  `nxn_sfx_stop_all()` (`NXN_CAP_MIXER`). SDL2 audio accepts any format and rates from 11025 to 48000 Hz and queues at
  most about 100 ms by default.
- Start at moderate volume; never exceed the user's setting; offer your own volume or mute control; do not add a
  second master volume at full.
- Pause on focus loss and sleep: scripts in `app.focus(false)` / `app.suspend()`; native on `NXN_EVENT_FOCUS`
  (`focused` 0) and `NXN_EVENT_SUSPEND`. After suspend the system plays no sound of the app and drops what was
  queued until resume.
- Design guidance: [Guides/SOUND_DESIGN.md](Guides/SOUND_DESIGN.md).

## 12. Files and storage

| Need | Script | Native |
|---|---|---|
| app data (kept) | relative paths in `fs.*`, `fs.dir("data")`, `store.get/set` (small values) | `nxn_fs_path` / `nxn_fs_write` / `nxn_fs_read` with `NXN_DIR_DATA` |
| cache (may be cleared) | `fs.dir("cache")` | `NXN_DIR_CACHE` |
| shipped files (read-only) | `"bundle:/..."` | `NXN_DIR_BUNDLE` |
| user's files | `ui.openFile`, `ui.saveFile`, `ui.chooseFolder` (SDK 1.11), `fs.dir("documents")` etc. | `nxn_pick`, `nxn_grant_*` (kept folders), `nxn_save_*` (save folder and backups) |
| paths outside the above | need permission `files` | need permission `files` |

- The app's data folder is `~/Library/Application Support/<id>/` (`~` is the user's home, `sdmc:/NexvynOS/Users/<name>/`); the cache is `Caches/<id>/`; both are created for
  you. Uninstalling keeps data unless the user chooses "Uninstall with data".
- `rel` paths for `nxn_fs_*` must not contain `..`, a leading `/` or a drive. Writes use a recoverable replace
  (temp file plus rename). Reserve the `.tmp` and `.nxn-old~` sibling names. Raw stdio is outside that lock and no
  power-loss durability is promised.
- Make saves atomic yourself in scripts too: write a temp file, rename it over the target, keep the previous save
  until the new one is complete. Save on suspend and quit.
- Some folders stay closed even with `files`: Nexvyn OS's own data, other apps' bundles and data
  ([Guides/APP_GUARD.md](Guides/APP_GUARD.md)). Files the user picks, the file the app was opened with, and shared
  files need no permission.
- `fs.unzip` (SDK 1.6) runs in the background. Native large read-only files: `nxn_stream_*` (`NXN_CAP_STREAM`).
- Native temp work: write under `sdmc:/`, never next to the program (read-only package folder).

## 13. Networking and permissions

| Permission | Gates | Refused call |
|---|---|---|
| `network` | `net.*` (`get`, `post`, `json`, `download`, `request`, `fetch`, `ws`, `oauth`), `gfx.imageUrl`; native BSD sockets | `"permission denied: network"`; native sockets fail with `EACCES` |
| `files` | paths outside the app's own folders | empty path / `nil` |
| `launch` | `sys.launch(otherId)`, `sys.open("nxv://...")` | `nil, "permission denied: launch"` |
| `notifications` | `sys.notify`, `sys.schedule` | `nil, "permission denied: notifications"` |
| `games` | `sys.games` | call fails |

- Declare only what you use and be ready to explain each one in the store pull request. Query with
  `sys.hasPermission(name)`; `sys.requestPermission(name, fn)` asks again once per session for a declared
  permission the user refused. Native: `nxn_perm_query`, `nxn_perm_request` (`NXN_CAP_PERMISSIONS`).
- Check `sys.online()` (scripts) or `nxn_power_get` (native, `minNative` 1.2) before a request; show a friendly
  offline message. HTTPS certificates are verified; a failed verification is an error.
- No hard-coded secrets or API keys in the package. Do not download and run unreviewed code.
- Native sockets also work through the compat layer (`nexvyn_use_compat()` in CMake; [Guides/NATIVE_COMPAT.md](Guides/NATIVE_COMPAT.md)).

## 14. Threads, memory, limits, lifecycle

Script apps:

- 64 MB script heap per window (Lua, JavaScript, Python); beyond it the app stops with an out-of-memory screen.
  `sys.memory()` reports use and limit.
- A faulty script app is stopped alone, never the system. This includes a runaway Lua pattern (`string.find` /
  `match` / `gmatch` / `gsub` obey the callback time limit). Python 3 starts on a background thread while the window
  shows "Loading": the first frame comes later and the desktop does not freeze. Python work inside one C call (a
  catastrophic regular expression, `sum(range(10**15))`) cannot be interrupted.
- A callback that runs longer than 3 seconds is stopped; the main file and `app.load` get 10 seconds (time in the
  HOME menu, asleep or in a system dialog does not count). With `targetSdk` 1.8 or newer the app ends with the error
  screen; older targets get a "Wait / Close" question. Do long work in the background (`net`, `fs.unzip`,
  `g3d.loadModel`, timers).
- Python: at most 16 PocketPy windows, at most 4 `python3` apps at once. No `os`, `open()`, `socket`, `threading`:
  use the SDK modules.
- JavaScript has no `window`, `document`, `fetch`, `XMLHttpRequest`, `localStorage`, `require`: use SDK modules.

Native apps:

- Memory: the app's `malloc` comes from its own heap (freed in one step when the app ends). There is no fixed limit;
  the heap grows while the system has memory, and `malloc` returns `NULL` with `ENOMEM` when only the reserve
  Nexvyn OS needs is left (setting `native.memoryReserveMB`, default 64). `"memory"` in `app.json` asks for a heap up
  front: if it is not free the app does not open and the user is told. `NXN_CAP_MEMORY_BUDGET`:
  `nxn_memory_budget_get` / `nxn_memory_budget_request` (advisory). Applet mode has much less memory: full-screen
  native apps are not started when Nexvyn OS runs as an applet (hold R while starting a game for title mode).
- Threads: `pthread`, `std::thread` and `nxn_thread_start` work. Core 0 is reserved for the shell, input loop and
  system audio mixer; core 3 for the system; the host grants up to two worker cores from 1 and 2.
  `nxn_thread_hint_request(worker_cores, priority, &granted)` (`nxn_sys.h`) sets an app-wide hint for future workers;
  the grant is advisory; check what you got before sizing parallel work. Worker priority is limited (normal 0x2D or
  lower). Keep display and GL calls on the display-owner thread.
- `thread_local` and C++ exceptions work in the module (`NXN_CAP_TLS`, `NXN_CAP_CXX_EXCEPTIONS`; on by default for
  `minNative` 1.1 or newer; verified in the emulator, not yet verified on a console). JIT (`NXN_CAP_JIT`) is off by default
  and `PROT_EXEC` is not available in a window. `fork`, `exec`, `system`, `popen`, pty never work; sockets need
  `network`; `dlopen` loads only your `.nxvlib` files.
- Code memory: the system holds the code of only a few native apps, libraries and C-script apps at once (see
  `0xCE01` in section 18).
- Lifecycle: handle `NXN_EVENT_QUIT` (save, return from your entry within about 5 seconds), `FOCUS`, `SUSPEND`/`RESUME`,
  `RESIZE`. A close ends only the app: `exit`, `abort`, a failed `assert` end the app, not the system.
- **Native code shares Nexvyn OS's process. There is no memory isolation.** A wild write can damage the system.
  Signatures and permissions are not isolation. That is why the user is asked before native code runs and the
  Store reviews native packages. Test in an emulator before a console.

## 15. Crash behavior and debugging

- Script error: the window shows the message and traceback with **Reload**; the same text goes to
  `System/Logs/Apps/<id>.log`. `print()` / `sys.log()` output is in that log.
- Native crash: a fault in any app thread closes the window ("<app> stopped"), writes a crash line to the app log and
  a report to `System/Logs/Crashes/`. Nexvyn OS keeps running. Three crashes in a row make Nexvyn OS ask
  "Close / Keep enabled". Native stdout and stderr are in the app log (marked `O` / `E`, capped); use `nxn_log`.
- Load errors: the user sees a message in their language; the log has `load failed: ...` and `what to do: ...`
  (see section 18).
- Symbolize a native crash on the PC: the report holds up to 16 return addresses (`app+0x4b488` in your module,
  `os+0x...` in the system) and the module build-id.

```text
python tools/nxv_native symbolize <SD>/NexvynOS/System/Logs/Crashes/<report>.txt [--elf build/<name>.nxvmod.debug]
```

  It runs `aarch64-none-elf-addr2line` (from devkitPro) on the debug ELF whose build-id matches the report.
  Keep `build/<name>.nxvmod.debug` for every release you ship (the packaged module has no symbols).
  `python tools/nxv_native check-win build/<name>.nxvmod` re-checks a module's imports.
- Dear ImGui: every visible widget needs a unique ID in its window (`Button("Rescan##toolbar")`); the red
  "conflicting ID" banner means two widgets share one.
- Isolate first: reproduce on the emulator with an `autorun.txt` script, add `log` marks and `stats` lines, then
  read the app log before changing code.

## 16. Performance budgets

These numbers come from the SDK documents; they are budgets to design against, not guarantees.

| Item | Budget |
|---|---|
| frame time | under 16.6 ms (60 Hz); let `nxn_display_swap` / the OS pace the loop; no busy-wait or sleep-loop timing |
| script callback | 3 s hard stop; load 10 s; the not-responding dialog appears after 5 s (120 s with `loadingHint`) |
| script heap | 64 MB per window |
| package | 20000 files, 1 GiB unpacked; keep packages small |
| 3D textures (script, targetSdk 1.10+) | soft budget 256 MB (64 MB when started from the Album); compressed KTX ETC2/EAC textures cut texture memory to about a third |
| `nav` grids | at most 8 per app and 64 MB in all |
| dynamic resolution | the system setting `gfx.dynamicRes` (`auto`, `on`, `off`; not an app API) lowers the render size towards 60 fps; `auto` applies to apps targeting SDK newer than 1.12. Do not fight it with your own scaler |
| `native.frameAhead` | leave 0 for games unless you measured a gain (costs up to a frame of latency) |

Turn on the on-screen performance panel with Ctrl+Alt+P (or L+R+ZL+ZR on a controller): frame time and its phases,
skipped frames, RAM and GPU lock time. Measure before and after under the same profile; benchmarks run uncapped and the shipped build keeps the cap. Only a
console gives console numbers. The `stats` autorun command writes memory, windows, GL objects, mixer, stalls and frame
time to `system.log`. Quality bar: [Guides/PRODUCT_QUALITY.md](Guides/PRODUCT_QUALITY.md),
[Guides/GAME_FEEL.md](Guides/GAME_FEEL.md).

## 17. Store submission

The App Market is fed from this repository by a pull request that the maintainer reviews. Nothing is published
without that review. Full rules: [Publishing/PUBLISHING.md](Publishing/PUBLISHING.md); checklist:
[Publishing/REVIEW.md](Publishing/REVIEW.md). Since 1.4.0 the console checks every Store and package download against its SHA-256 before
unpacking it, so the published files must match the catalog exactly (Publishing/PUBLISHING.md, section 12).

1. Fork the repository, branch `app/<slug>`. Add only your folder: `Store/Apps/<category>/<slug>/` or
   `Store/Games/<genre>/<slug>/` (`Store/Emulators/<subcat>/<slug>/` for emulators).
   Start it with `python SDK/Tools/nxv/nxv.py new lua "Water Tracker" --store --dir Store/Apps/productivity`.
2. The folder has `source/` (the bundle), `store.json`, `README.md`, `screenshots/*.png` (5 recommended, 3 at least).
3. `source/icon.png`: 256x256, key art of the item itself (a flat placeholder glyph is not accepted).
4. `store.json`: `kind` (`app`, `game`, `demo`, `port`, `emulator`, `template`), `subtitle` (max 45 characters) and
   `description` as maps with **all eight languages**, optional `tags`, `features`
   (`3d`, `online`, `multiplayer`, `coop`, `offline`, `touch`, `controller`, `keyboard`), `players`, `age`
   (`everyone` or `teen`), `shots` (3 to 5 scripted screenshot steps).
5. Run `python SDK/Tools/nxv/nxv.py check Store/Apps/<category>/<slug>/source` (it also checks `store.json`) and
   `python SDK/Tools/nxv/nxv_i18n.py --check <source>`. Then `python Tools/build_store.py --check`.
6. Open the pull request with the template: what it is, why each permission is needed, which checks you ran, where
   you tested.
7. Updates: same `id`, higher `version`, a README versions line, ideally a `changelog` in `store.json`.
8. Store packages are not signed by you. `Tools/build_store.py` packs the item's `source/` folder into the `.nxvapp`
   (with `manifest.sha256`, no `manifest.sig`) and the App Market checks each download against the catalog `sha256`.
   A native item puts the already built `<name>.nxvmod` inside `source/` (existing native items do; for example an
   emulator item's `source/` holds its `.nxvmod` files next to `app.json`, `lang/` and `data/`), so build with
   `nxv_native build` and copy the module there. `package --sign` is only for packages you distribute yourself.

Not accepted: broken or copied items, malware, hidden tracking, unexplained permissions, rights you do not hold,
adult-only or illegal content, missing English text, flat placeholder icons, games that copy a sample's menu layout.
Third-party code, art, sound and fonts are listed with their licences in the README.
No trademark or product names of other companies in your UI, listing or documentation.

## 18. Common errors and fixes

| Symptom (exact text where one exists) | Cause | Fix |
|---|---|---|
| `0xCE01`, "Too many native apps are open at the same time: the system holds the code of only a few at once." | the console kernel gives the system a small fixed pool of code-memory objects; the loader accounts for 10; each windowed native app takes 2, each `.nxvlib` 2, each JIT buffer 1, each C-script app 1 (one object mapped twice) | close another native app, library or C-script app and start again; if that does not help, restart Nexvyn OS; ship fewer `.nxvlib` files |
| installed app does not change after installing a `.nxvapp` again | same `id` and same `version` is left alone (nothing happens) | bump `version` (and `build`), or delete the installed folder |
| "needs a newer Nexvyn OS" | `minSdk`, `minNative` or `minOs` is above the system | lower the floor to what you really use, or update Nexvyn OS |
| `eight complete locales required before packaging: ...` | `lang/` incomplete | run `nxv_i18n.py --check`; add every locale, same keys and tokens as `en.json` |
| `uses network calls but app.json "permissions" does not declare "network"` | undeclared permission | add it to `permissions` (and explain it in the store pull request) |
| `permission denied: network` at run time | the user turned it off, or it is not declared | check `sys.hasPermission`; show a message; `sys.requestPermission` |
| `app.json: "native" apps cannot be packaged` from `nxv.py` | a package that uses the internal `"native"` string field | use `"runtime": "native"` and `nxv_native package` |
| `a native app needs "minSdk": "1.10"` | native package without the SDK floor | add `"minSdk": "1.10"` |
| `devkitPro not found (set DEVKITPRO or DKP_BASH)` | toolchain missing | section 3.2 |
| `this project includes SDL: a windowed build needs the SDL2 of the kit` | kit SDL2 not built | `python sdk/native/sysroot/build.py sdl2-nexvyn` |
| `no CMakeLists.txt in ...` | wrong directory | pass the project folder |
| overlong object path / cannot create `.o.d` | very deep Windows path | build from a short path |
| "This file is not a windowed native app" | module without windowed identity | build with `nxv_native build` / `nexvyn_add_windowed` |
| "The app needs the function X ..." (`missing symbol X` in the log) | the app imports something the host does not offer | remove the call, use the kit's equivalent, or link the compat layer; `check-win` lists all |
| "built for module interface generation N, but this system uses M" | ABI generation mismatch | rebuild with the matching kit |
| "The app uses thread_local variables ..." | TLS setting off | turn on `native.windowedTls` (check `NXN_CAP_TLS`) or avoid `thread_local` |
| "no code memory for native apps in this mode" | Nexvyn OS runs as an applet | start in title mode (hold R while starting a game) |
| "not enough free memory" / "needs X MB" | heap or `memory` request does not fit | close apps; lower `memory` |
| "This app stopped responding" | callback longer than 3 s (10 s at load) | move work to the background; `loadingHint` for long loads |
| `MemoryError: out of memory (the app used more than 64 MB)` | script heap limit | free data; stream assets |
| `nxn_nxui_end_ex()` returns `NXN_ERR_UNSUPPORTED` | NXUI does not paint in a GL window | use ImGui with `nxn_os_ui.h` |
| `nxv_native check-design` FAIL | raw ImGui widgets, own fonts, pixel literals | use `nxn_os_*` widgets, `NXN_S(px)`, the frame layer |
| Vulkan: `Vulkan is not available on this system` | no Vulkan on this system | check `NXN_CAP_VULKAN`, fall back to GL (section 10.4) |
| "does not include Python 3" | a build without CPython | use another runtime or a CPython-enabled build |
| `icon.png missing` / not a PNG | icon problem | add a 256x256 PNG |

## 19. Where to read next

| Need | Document |
|---|---|
| exact script API | [Reference/SDK.md](Reference/SDK.md), C header [Reference/c/include/nexvyn.h](Reference/c/include/nexvyn.h) |
| native API | headers under `Languages/c/native-kit/sdk/native/include/nexvyn/` (index in [llms.txt](llms.txt)), [Guides/NATIVE_KIT.md](Guides/NATIVE_KIT.md) |
| package format, permissions, signing | [Guides/NXVAPP_FORMAT.md](Guides/NXVAPP_FORMAT.md) |
| versions and compatibility | [Guides/SDK_VERSIONS.md](Guides/SDK_VERSIONS.md), [Guides/COMPATIBILITY.md](Guides/COMPATIBILITY.md) |
| recipes per product type | [AI/recipes/README.md](AI/recipes/README.md), [AI/tasks/](AI/tasks/make-game.md) |
| keyword lookup map | [AI/map/INDEX.md](AI/map/INDEX.md) |
| validating AI-made apps | [AI/CHECK.md](AI/CHECK.md) |

What this SDK does not promise: a frame rate, a sandbox for native code, universal foreign executable support,
a future graphics backend, Vulkan on any particular release, or console certification. Real-device testing,
translation review and profiling stay with you.
