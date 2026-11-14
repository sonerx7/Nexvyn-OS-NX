# Nexvyn OS SDK Reference

The complete contract for Nexvyn OS applications and games (**SDK 2.0 / 1.13** and **Native SDK 1.2**, shipped with
**Nexvyn OS 1.3.8**). Apps read the system's SDK version with `sys.sdkVersion()` (`"1.13"`) and declare the oldest
version they need with `"minSdk"` in `app.json`.

## In this folder

| Path | Description |
|---|---|
| [SDK.md](SDK.md) | **The Complete SDK Contract (English):** package layout, `app.json`, permissions, lifecycle callbacks, `gfx` (2D drawing), `ui` (immediate-mode widgets), **`nxui` (Section 4a: Retained & Semantic UI Engine)**, unified input, `fs` / `store` / `json`, `net` (HTTP, WebSockets, OAuth), `sys` / `audio` / `timer` / `TR`, `g3d` (3D meshes, skeletal `.glb`/`.fbx` models, `g3d.voxels`, **NexGFX PBR renderer**), `nexvyn.game` (2D engine), and language bindings for Lua 5.4.7, JavaScript (QuickJS-ng ES2023), Python (CPython 3.12 & PocketPy), Native C/C++ (`.nxvmod`), TinyCC C, Squirrel and Java. |
| `../Languages/c/native-kit/include/` | **Native C/C++ SDK Headers (`nxn_*` & `nxn_nxui_*`):** `nexvyn/nexvyn_native.h`, `nexvyn/nxn_app_api.h`, `nexvyn/nxn_nxui.h`, `nexvyn/nxn_ui.h`, `nexvyn/nxn_gl.h`, `nexvyn/nexgfx.h`. Frozen ABI v1 for AArch64 `.nxvmod` windowed and fullscreen native apps. |
| `c/include/` | Headers for on-console TinyCC C apps (`"runtime": "c"`): `nexvyn.h` and the console's small C library (`stdio.h`, `stdlib.h`, `string.h`, `math.h`, `ctype.h`, `stdint.h`). |
| `java/nexvyn/` | Java SDK sources (`App`, `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`, `Theme`, `Json`, `Record`, `Menu`, `Event`, `Callback`, `Mesh`, `SearchResult`) for `"runtime": "java"` (frozen at SDK 1.8). |

## SDK Version Summary

| SDK | Headline Additions |
|---|---|
| **1.0** | Lua 5.4 runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| **1.1** | JavaScript runtime (QuickJS-ng ES2023, Promises); `g3d` GPU textures |
| **1.2** | `nexvyn.game` 2D engine, `sys.sdkVersion()`, `minSdk` & `permissions`, `.nxvapp` v2 with `manifest.sha256` |
| **1.3** | Python runtime (`"python"`, PocketPy) |
| **1.4** | Enforced permissions, `sys.share`, `sys.schedule`, `nxv://` links, lifecycle callbacks (`suspend`, `resume`, `autosave`), ECDSA package signing |
| **1.5** | C (`"c"`, TinyCC), Squirrel (`"squirrel"`) and Java (`"java"`) runtimes; Python system library |
| **1.6** | **CPython 3.12 (`"python3"`)**, `fs.unzip` (background thread), `sys.games`, `sys.speak` (TTS) |
| **1.7** | `g3d.voxels` streaming voxel worlds in JavaScript; pixel-art mesh textures |
| **1.8** | `g3d.model` & `g3d.loadModel`: `.glb` / `.gltf` / `.fbx` hierarchy, materials and GPU skeletal animation |
| **1.9** | **NexGFX PBR Renderer** (`g3d.renderer("pbr")`, real-time lights, shadows, HDR, bloom, MSAA, instancing); rich `net.request`, WebSockets (`net.ws`), OAuth (`net.oauth`), `gfx.imageUrl`, `media.*` video/audio players, `ui.beginFeed`, `ui.pager`, `ui.richText` |
| **1.10** | **Native C/C++ Runtime (`"runtime": "native"`):** `.nxvmod` windowed and fullscreen apps, Frozen ABI v1 (`nxn_*`) |
| **1.11** | Kept folders and save backups (`ui.chooseFolder`, `fs.folderGrants`, `fs.saveBackup`, `fs.saveRestore`) across script and native runtimes |
| **1.12** | Design system tokens (`ui.tokens()`), `audio.stopAll()`, C `input_action`, Native SDK 1.1 (SDL2 in a window, POSIX compat, per-app heap arena) |
| **1.13 / 2.0** | **Nexvyn OS N2 Architecture:** **NXUI Retained & Semantic UI Engine (`nxui.*` & `nxn_nxui_*`)**, 4 Official Primary Runtimes (Lua 5.4.7 Generational GC, QuickJS-ng ES2023, CPython 3.12 default for `targetSdk: "2.0"`, Native C/C++ ABI v1), Native SDK 1.2 (`nxn_window_set_*`, `nxn_power_get`, `nxn_dialog`, `nxn_prompt`), `loadingHint`, Smart Creator (`nxv.py create`) |
