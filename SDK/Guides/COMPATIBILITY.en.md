# App compatibility: versions, targetSdk, deprecation

[Türkçe](COMPATIBILITY.tr.md) · **English**

> **The promise.** An app that works on Nexvyn OS today keeps working on every later Nexvyn OS: after a system update,
> a new SDK, a new or replaced language runtime or an API change. This page is the contract behind that promise, for
> the people who change the system and for the people who write apps.

## 1. Three version numbers

| Number | Where | Example | Meaning |
|---|---|---|---|
| **Nexvyn OS** | `APP_VERSION` in the Makefile, Settings > About | `1.0.0` | the system release (semver: major.minor.patch) |
| **SDK** | `NEXVYN_SDK_VERSION` (`source/core/sdk_version.h`), `sys.sdkVersion()` | `1.6` | the API surface apps build on (major.minor) |
| **Runtime engine** | `nxvruntime::kRuntimes` (`source/runtimes/runtime_kind.h`) | pocketpy `2.2.0` | the interpreter or compiler behind one app language |

What bumps what:

| Change | Nexvyn OS | SDK |
|---|---|---|
| bug fix, translation, new built-in app, look and feel | patch (`1.0.1`) | — |
| new SDK function, module, optional parameter, permission, app.json field or runtime (additive) | minor (`1.1.0`) | minor (`1.7`) |
| an existing function **changes behaviour** (only for apps that target the new SDK, rule 2) | minor or major | major (`2.0`) |
| a runtime engine upgrade apps could notice (rule 5) | minor | — (the compat suite decides) |
| removing a function or a runtime | never (rules 1 and 5) | never |

### SDK versions

Every SDK version so far shipped in the development of Nexvyn OS 1.0.0, the first public release, which has SDK 1.6.

| SDK | First Nexvyn OS | Adds |
|---|---|---|
| 1.0 | 1.0.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | 1.0.0 | JavaScript runtime (QuickJS-ng), Promises; `g3d` textures on the GPU |
| 1.2 | 1.0.0 | `nexvyn.game` engine, `sys.sdkVersion()`, app.json `minSdk` and `permissions`, `.nxvapp` v2 |
| 1.3 | 1.0.0 | Python runtime (pocketpy) |
| 1.4 | 1.0.0 | every permission enforced, sharing, scheduled notifications, `nxv://` links, lifecycle callbacks |
| 1.5 | 1.0.0 | Squirrel, C (TinyCC) and Java (miniJVM) runtimes; Python system library |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games` and the `"games"` permission, text to speech; the `"python3"` runtime (CPython 3.12) |
| 1.7 | 1.1.0 | `g3d.voxels` voxel worlds (JavaScript), `mesh:setTexture(path, pixelated)` |
| 1.8 | 1.2.0 | `g3d.model`: `.glb` / `.gltf` / `.fbx` models with materials, textures and skeletal animation; `g3d.drawMatrix` |
| 1.9 | 1.2.2 | runtime library: `net.request` in Lua, JavaScript `TextEncoder` / `URL` / `URLSearchParams` / `structuredClone`, Python `str` methods and `urllib.parse` / `html` / `uuid`; feed, photo and short-video apps: `net.request` uploads, cookies, retries and offline cache, WebSocket client, `net.oauth`, `gfx.imageUrl`, `media.*` players, `ui.beginFeed` / `ui.pager` / `ui.richText`, `sys.relativeTime`; the opt-in pbr renderer (`g3d.renderer("pbr")`): PBR materials, real-time lights, shadows, HDR, bloom, MSAA, instancing (Lua, JavaScript, Python, C); apps that do not ask for it render exactly as with 1.8 |
| 1.10 | 1.2.2 (same build for now) | native runtime: C / C++ apps inside Nexvyn OS, in a window or full screen (`"runtime": "native"`, `"mode": "window"` or `"fullscreen"`, a `.nxvmod`; packages that say `"windowed"` or the retired `"exclusive"` still run), Native SDK 1.0 (`NATIVE_KIT.en.md`); Native SDK 1.1 only adds (`nxn_audio_clear`, USB keyboard / mouse / text, dock and sleep events, the SDL2 driver for windows), each announced by an `nxn_caps` bit, so apps built for 1.0 run unchanged; no script API change; native packages carry `"minSdk": "1.10"`, so systems with SDK 1.9 or older say "needs a newer Nexvyn OS" |
| 1.11 | 1.2.2 (same build for now) | kept folders and save backups for script apps: `ui.chooseFolder`, `fs.folderGrants` / `folderGranted` / `revokeFolder`, `fs.savePath`, `fs.saveBackup` / `saveRestore` / `saveBackups` / `saveDeleteBackup` (Lua, JavaScript, Python, C; the same functions as the native `nxn_pick` / `nxn_grant_*` / `nxn_save_*`); apps built for older SDKs behave as before; scripts that use them carry `"minSdk": "1.11"` |
| 1.12 | 1.2.2 (same build for now) | language parity with the native SDK: `ui.tokens`, `audio.stopAll`, C `input_action` (Lua, JavaScript, Python, C); apps built for older SDKs behave as before; scripts that use them carry `"minSdk": "1.12"` |

The full list of functions per version is in the SDK reference (`sdk/SDK.en.md`, "SDK versions").

### Native SDK

The native runtime (C / C++ apps, `.nxvmod`) has its own version, `NATIVE_VERSION` in `tools/sdkinfo.py`; an app states
the oldest one it needs as `"minNative"`. A newer Native SDK only adds: every addition is announced by an `nxn_caps` bit,
so an app built for an older one runs unchanged, and an app that needs a newer one says so before it starts.

**ABI v1 is frozen (2026-11-09).** Every function, signature, struct layout, constant value, host import name and the
module identity of Native SDK 1.0 and 1.1 are recorded in `sdk/native/toolchain/nxn_abi_v1.json`; from now on they are only
added to, never removed or changed. `tools/abi_check.py` (part of `tools/compat_check.py`) fails on any removal or layout
change, and a module built with the 1.0 kit (`tests/golden/`) is loaded by every build's tests. `NXN_ABI_GEN` and the
host generation stay hand-raised numbers, never derived from a version.

| Native SDK | Brought by SDK | What it contains |
|---|---|---|
| 1.0 | 1.10 | `nxn_*` C interface: window display (GL), input, audio streams, files, log, return; `.nxvmod` apps, `.nxvlib` libraries |
| 1.1 | 1.10 | SDL2 driver for windows; sound and input events (`nxn_audio_clear`, USB keyboard / mouse / text, dock and sleep events); POSIX calls in a window (compat layer); system services (file and folder dialogs, kept folder access, save data, permissions); UI tokens, system fonts and the app's own texts (`nxn_ui.h`, `lang/<code>.json`); NexGFX native (`nexgfx_native.h`); the OS sound mixer (`nxn_sfx_play`, `nxn_tone`); package v2 (`nxvapp` with the module, `lang/`, `data/`) |

Native apps need no change when Nexvyn OS is updated; the kit's own rules are in `docs/NATIVE_COMPAT.en.md`. Load errors
(missing function, other interface generation, `thread_local`) are shown in the user's language with what to do about
them, and written to the app's log; see `docs/NATIVE_GUIDE.en.md`.

### Runtimes

| `"runtime"` | Engine in Nexvyn OS 1.0.0 | Since SDK |
|---|---|---|
| `"lua"` (default) | Lua 5.4.7 | 1.0 |
| `"js"` | QuickJS-ng 0.17.0 | 1.1 |
| `"python"` | pocketpy 2.2.0 | 1.3 |
| `"python3"` | CPython 3.12.16 | 1.6 |
| `"squirrel"` | Squirrel 3.2 | 1.5 |
| `"c"` | TinyCC 0.9.28rc | 1.5 |
| `"java"` | miniJVM 2.2.0 | 1.5 |

### Which languages get new APIs

New SDK functions come to **Lua, JavaScript, Python** (`"python"` and `"python3"`) **and C**. **Squirrel and Java
are frozen**: everything they have today, SDK 1.8's `g3d.model` functions included, stays and keeps working, and the
compat suite keeps checking it, but SDK 1.8 is the last version that adds anything to them.

What this means for you:

- A Squirrel or Java app on the App Market keeps running on every later Nexvyn OS, unchanged. Nothing to do.
- `minSdk` / `targetSdk` above 1.8 bring nothing new to these two languages; keep them at 1.8 or below.
- For a new app, or when an existing one needs a newer API, pick one of the four languages that keep growing. The
  SDK calls have the same names in all of them, so moving code over is mostly syntax.

Frozen is not removed: rule 5 still holds, and a bug or security fix in these runtimes still ships.

## 2. What an app states in app.json

```json
{
  "minSdk": "1.4",
  "targetSdk": "1.6",
  "runtime": "python",
  "runtimeVersion": "2.2"
}
```

- **`minSdk`**: the oldest SDK the app runs on. A system with an older SDK does not install it.
- **`targetSdk`**: the SDK the app was built and tested against. The system keeps behaving the way that SDK did for
  this app. Default: `minSdk`, or `"1.0"` when neither is given (a `targetSdk` below `minSdk` counts as `minSdk`).
  Studio writes `targetSdk` = the current SDK and `minSdk` = the newest SDK that changed the script API (1.9) into
  every new script project, so SDK versions that only add the native runtime (1.10) do not lock new apps out.
- **`runtime`**: the language (default from the main file's extension; `"python3"` only by name).
- **`runtimeVersion`** (optional): the engine version the app was tested on. Without it, the engine that came with
  its `targetSdk` (table above). It is recorded on install; it only matters once an engine changes in a way apps can
  notice (rule 5).

## 3. The rules

1. **Every SDK function stays forever.** Nothing is removed. A function that is replaced becomes *deprecated*: it
   keeps working exactly as before, its binding calls `sdkcompat::deprecated(desc, "<api>", "use <new api>")`, which
   writes `deprecated: <api> still works; use ...` to the app's log once per run, and it is listed in section 4. The
   checkers' mocks keep it too (the compat suite enforces this).
2. **Behaviour never changes under an old app.** When an existing function has to work differently, the new behaviour
   only applies to apps whose `targetSdk` is the SDK that introduces it; every other app keeps the old path:

   ```cpp
   if (sdkcompat::atLeast(desc, 2, 0)) newBehaviour(); else oldBehaviour();   // or sdkcompat::behaves(desc, "2.0")
   ```

   Built-in apps ship with the system and always get the current behaviour. The change is documented in the SDK
   reference as "for apps that target SDK x".
3. **Newer apps are ignored gracefully, never rejected for what this system does not know.** Unknown app.json fields
   are ignored. An unknown permission is accepted in the manifest and grants nothing (`permrules::decide`). A retired
   permission (`"clipboard"`) is accepted and ignored. The manifest v2 fields (`type`, `arch`, `minOs`, `needs`, `size`,
   `hashes`, `dataVersion`; `docs/NXVAPP_FORMAT.en.md`) are all optional: a package without them installs exactly as before,
   and an update never costs the installed version, even when it is interrupted (the previous version is kept for going back).
4. **An app written for a newer system says so.** When its `minSdk` is above this SDK or its `runtime` is not in this
   build's runtime table (`sdkcompat::runnable`):
   - the App Market shows *This app needs a newer version of Nexvyn OS* instead of Get, leaves it out of the New
     shelf, and **never offers an update** that needs a newer system (the installed version keeps working; its page
     says *Version x needs a newer Nexvyn OS*);
   - the install sheet blocks Install and Run with the reason (*It needs SDK 1.8; this system has 1.6* or
     *It is written in X, which this version of Nexvyn OS does not have*);
   - a copy already on the SD card (put there by hand, or left after a downgrade) stays in the Launcher and opens a
     window with the same message and a Software Update button. It is never run by the wrong interpreter.
5. **Runtimes are never removed** from the NRO while store apps use them. A replacement engine (or an upgrade apps
   could notice, such as a new pocketpy) must pass the compat suite first; if it breaks an app, the old behaviour stays
   for apps whose `runtimeVersion` (or, without it, `targetSdk`) predates the change, through a shim or by keeping the
   old engine. A new runtime is added to `nxvruntime::kRuntimes`, `tools/sdkinfo.py`, a checker and this page.
6. **Old names keep working** (section 4).
7. **A stuck app never takes the system down, and an old app is never ended without the user** (SDK 1.8). Every
   runtime stops a script callback that runs longer than 3 seconds (10 for the main file and `app.load`; time in the
   HOME menu, asleep or in a system dialog does not count). For `targetSdk` 1.8+ the app ends with its error screen
   ("not responding", Reload / Close). For an older app the stop only interrupts that callback: the window is held and
   the user picks Wait (the app goes on) or Close (normal close). The frozen Squirrel and Java runtimes keep their old
   behaviour (the error screen). Native code (C apps, C++ apps) is never stopped from outside: when such a callback
   held the system for 12 seconds and comes back, the user is asked Force Quit / Wait; while it stays stuck, holding
   + and - for two seconds quits Nexvyn OS and the next start brings the other windows back. Tests: `tools/tests/hang_apps/` (section 5).
8. **A closed app leaves no resources behind; no app has a memory limit** (SDK 1.10). Its meshes, models, voxel worlds
   and GPU buffers are freed when it closes, textures once every app that drew them has closed (`g3d_gl.h`
   `maintain`). A soft texture budget releases idle textures only of apps that target SDK 1.10; under older apps it
   only logs. The `res` lines and the autorun `stats` line (`source/core/resmon.h`) show what is still alive.
9. **Packages: old packages and catalogs work unchanged** (Native 1.1 work). Delta updates (`store.deltaUpdates`) and side-by-side
   libraries (`libs.sideBySide`) are off by default; an entry without `delta` and a library installed as one version behave
   as before. A delta is never trusted more than a full package (same hashes, signature and atomic swap) and any problem
   falls back to the full package. A library already installed as a single-version folder is read as it is and moved
   without loss; no installed version an app needs is ever removed. Compatibility identities stay hand-raised numbers.

## 4. Deprecated and renamed (kept forever)

| Old | Use instead | Since | What happens |
|---|---|---|---|
| `require("snx.*")` (Lua) | `require("nexvyn.*")` | Nexvyn OS 1.0.0 | loads the same module; a deprecation note in the app log |
| permission `"clipboard"` | nothing (`sys.clipboard` needs no permission) | 1.0.0 | accepted and ignored |
| app ids `finder`, `launchpad` | `files`, `launcher` | 1.0.0 | `sys.launch`, `nxv://` links and shortcuts resolve them |
| `sdmc:/SnxOS` and the old file extensions | `sdmc:/NexvynOS`, `.nxv*` | 1.0.0 | moved and renamed once at start |
| `"snx-workshop"` projects | `"nexvyn-workshop"` | 1.0.0 | the Game Engine still opens them |

## 5. The compat suite

`tools/compat_check.py` runs every app users can have through the checker of its runtime with the current SDK mocks:
the store apps, games and SDK samples of the release repository (`Store/Apps`, `Store/Games`, `SDK/Samples`), the
built-in script apps (`romfs/Applications/*.nxvapp`) and the Studio templates. It also checks that every function the
runtimes register exists in the checkers' mocks (deprecated ones too) and that `tools/sdkinfo.py` matches
`sdk_version.h` and `runtime_kind.h`.

```
python tools/compat_check.py                     # compare with tools/compat_baseline.json
python tools/compat_check.py --update-baseline   # record the current results (after a deliberate change)
```

The result of every app is kept in `tools/compat_baseline.json` (one line per app). An app that passed there and fails
now is a **compatibility break**: the run fails. `tools/release.py` runs the suite before it syncs the release
repository and stops on a break unless `--allow-compat-break`; CI (`.github/workflows/ci.yml`) runs it on the built-in
apps, since the release repository is not part of the source checkout. Baseline of Nexvyn OS 1.0.0: 159 apps,
159 pass.

## 6. Checklist for system changes

- **New function / module / permission / app.json field**: implement it in every runtime it belongs to (Lua,
  JavaScript, Python, C; not Squirrel or Java, section 1 "Which languages get new APIs"), add it to the
  checkers' mocks (the suite reports a missing one), document it in `sdk/SDK.*.md`, bump `NEXVYN_SDK_VERSION`,
  `tools/sdkinfo.py` and the mocks' `sys.sdkVersion()`, and add a row to the tables above.
- **Behaviour change**: gate it with `sdkcompat::atLeast` (rule 2) and bump the SDK major.
- **Replacing a function**: keep the old one, call `sdkcompat::deprecated` from its binding, list it in section 4.
- **Engine upgrade or new runtime**: update `nxvruntime::kRuntimes` and `tools/sdkinfo.py`, run the suite (rule 5).
- **Before every release**: `python tools/compat_check.py` (release.py does it), `python tools/catalog_check.py` on the
  catalog (it warns about a `minSdk` / `targetSdk` above the SDK and a runtime newer than the entry's `minSdk`).

## 7. For app developers

- Set `minSdk` to the oldest SDK whose functions you use and `targetSdk` to the SDK you tested on (`sys.sdkVersion()`
  tells you which one the console has). `python tools/nxvapp_pack.py` warns when `targetSdk` is missing.
- To use something newer only where it exists, check `sys.sdkVersion()` or the function itself (`if g3d.free then`).
- When you raise `targetSdk`, read the "for apps that target SDK x" notes in the SDK reference: those are the only
  behaviour changes you opt into.
- Deprecation notes in your app's log (Studio's console shows it) tell you what to move to; the old call keeps working.
- New APIs arrive in Lua, JavaScript, Python and C. Squirrel and Java apps keep working but get nothing after SDK 1.8
  (section 1).
