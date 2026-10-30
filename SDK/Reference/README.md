# Nexvyn OS SDK

**English** · [Türkçe](README.tr.md)

The Nexvyn OS app SDK, version **1.6**. Apps read the system's version with `sys.sdkVersion()` and declare the oldest
version they need with `"minSdk"` in `app.json`; an app that needs a newer SDK is not installed and the user is told
to update Nexvyn OS.

## In this folder

| Path | What |
|---|---|
| [SDK.en.md](SDK.en.md) | The complete reference (English, with Turkish summaries): package layout, `app.json`, permissions, program structure, `gfx`, `ui`, input, `fs`/`store`/`json`, `net`, `sys`/`audio`/`timer`/`TR`, links and sharing, `g3d`, `nexvyn.game`, design guidelines and the JavaScript (11), Python (12), Squirrel (13), C (14) and Java (15) sections. Everything it lists exists; nothing else does. |
| `java/nexvyn/` | The Java SDK sources (`App`, `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`, `Theme`, `Json`, `Record`, `Menu`, `Event`, `Callback`, `Mesh`, `SearchResult`), generated from the system's function table. Add them next to `src/` or to the class path for IDE completion. The compiled copy on the console is `romfs/System/Java/nexvyn.jar`. |
| `c/include/` | Headers for C apps: `nexvyn.h` (the whole SDK) and the console's small C library (`stdio.h`, `stdlib.h`, `string.h`, `math.h`, `ctype.h`, `stdint.h`...). Add the folder to your editor's include path; the console uses the same headers. |

Lua, JavaScript, Python and Squirrel need no SDK files: the modules (`gfx`, `ui`, `store`...) are built into the
runtime.

## SDK version history

| SDK | Added |
|---|---|
| 1.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | JavaScript runtime (same modules, Promises); `g3d` textures on the GPU |
| 1.2 | the `nexvyn.game` 2D engine, `sys.sdkVersion()`, `app.json` `minSdk` and `permissions`, single-file `.nxvapp` v2 with `manifest.sha256` |
| 1.3 | Python runtime (pocketpy); asynchronous calls take callbacks |
| 1.4 | all five permissions enforced; `sys.share`, `sys.schedule` / `unschedule` / `scheduled`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `nxv://` links in `sys.open`; `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved`; `shareTargets`; signed packages (`manifest.sig`); the 64 MB limit for Lua apps too |
| 1.5 | Squirrel, C (TinyCC on the console) and Java (miniJVM) runtimes; `"runtime"` values `"squirrel"`, `"c"`, `"java"` and `"mainClass"`; the Python system library (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |
| 1.6 | the `"games"` permission and `sys.games` (installed games), `fs.unzip` (zip on a background thread), `sys.speak` (text to speech) |

A minor version (1.x) only adds; removing or changing something bumps the major version. Raise `minSdk` when you use
something new. Minimum `minSdk` per language: Lua 1.0 (1.2 with `nexvyn.game`), JavaScript 1.1, Python 1.3,
Squirrel / C / Java 1.5.
