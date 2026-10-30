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

The full list of functions per version is in the SDK reference (`sdk/SDK.en.md`, "SDK versions").

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
  Studio writes `minSdk` and `targetSdk` = the current SDK into every new project.
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
   permission (`"clipboard"`) is accepted and ignored.
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

- **New function / module / permission / app.json field**: implement it in every runtime it belongs to, add it to the
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
