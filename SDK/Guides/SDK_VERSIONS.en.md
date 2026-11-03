# SDK versions

**English** · [Türkçe](SDK_VERSIONS.tr.md)

Every Nexvyn OS release provides one SDK version: the API that `.nxvapp` apps build on. `sys.sdkVersion()` returns it,
and **System Settings > About** shows it. An app states the oldest SDK it needs with `"minSdk"` and the SDK it was
tested on with `"targetSdk"` in `app.json`.

## The promise

- **Nothing is removed.** Every function keeps working on every later Nexvyn OS. A function that gets a replacement is
  marked deprecated: it still works and writes one note to the app's log.
- **Behaviour changes are opt-in.** When an existing function changes how it behaves, only apps whose `targetSdk` is
  that version or newer get the new behaviour.
- **Newer apps on older systems.** An app whose `minSdk` is newer than the system's SDK is not installed and is shown
  as needing a newer Nexvyn OS.
- **Every release is checked** against every App Market app, game and sample before it ships.

The full contract: [Compatibility](COMPATIBILITY.en.md).

## History

| SDK | First Nexvyn OS | What it added |
|---|---|---|
| **1.9** | **1.3.0** | **NexGFX pbr renderer** (opt-in per app with `g3d.renderer("pbr")`): metallic-roughness materials with normal, occlusion and emissive maps from glTF and FBX, `g3d.material`, real-time point, spot and directional lights (`g3d.addLight` and friends), sun and spot shadows, HDR, ACES / filmic tone mapping, bloom, MSAA, cube map reflections, thin glass (transmission), clearcoat, `g3d.drawInstanced`, `g3d.caps`, `g3d.rendererInfo`. **Feeds, media and network:** `net.request` options (JSON, form, multipart and file bodies, `saveTo`, upload progress, cookies, retries, offline cache), `net.cancel` / `clearCookies` / `clearCache`, WebSocket client (`net.ws`), sign-in in the console's browser (`net.oauth`), web pictures with a disk cache (`gfx.imageUrl`), embedded video and audio players (`media.*`), virtualized feeds and grids (`ui.beginFeed`), a swipe pager (`ui.pager`), rich text (`ui.richText`), `sys.relativeTime`. **Runtime library:** `net.request` in Lua; `TextEncoder` / `TextDecoder`, `URL`, `URLSearchParams`, `structuredClone` in JavaScript; more `str` methods, `dict.setdefault` / `fromkeys`, `pow()`, `urllib.parse`, `html`, `uuid` in Python. Lua, JavaScript, Python and C only |
| 1.8 | 1.2.0 | 3D model files: `g3d.model` / `g3d.loadModel` for `.glb`, `.gltf`, `.fbx` (and `.obj`, `.stl`) with node hierarchy, materials, textures and skeletal animation (play, crossfade, stop, node positions and matrices), `g3d.drawMatrix`, GPU skinning. A callback that runs too long ends apps that target 1.8 with an error screen; older apps are held and the user picks Wait or Close |
| 1.7 | 1.1.0 | `g3d.voxels` voxel worlds in JavaScript (chunks, terrain generator, light, ray casts, box physics, saving); `mesh:setTexture(path, pixelated)` |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games` and the `"games"` permission, `sys.speak`, the `"python3"` runtime (CPython 3.12) |
| 1.5 | 1.0.0 | Squirrel, C (compiled on the console) and Java runtimes; Python system library |
| 1.4 | 1.0.0 | Every permission enforced; sharing, scheduled notifications, permission API, `nxv://` links, lifecycle callbacks (`suspend`, `resume`, `focus`, `autosave`, `unsaved`), Quick Search for apps, signed packages |
| 1.3 | 1.0.0 | Python runtime (pocketpy) |
| 1.2 | 1.0.0 | The 2D game engine `nexvyn.game`, `sys.sdkVersion()`, `minSdk` and `permissions` in `app.json` |
| 1.1 | 1.0.0 | JavaScript runtime with Promises; `g3d` textures on the GPU |
| 1.0 | 1.0.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |

SDK 1.0 to 1.6 were made during the development of Nexvyn OS 1.0.0, the first public release, which ships all of them.
The complete function lists are in the [SDK reference](../Reference/SDK.en.md), section 1, *SDK versions*.

## Languages

| Language | Since | New APIs |
|---|---|---|
| Lua 5.4 | 1.0 | yes |
| JavaScript (ES2023) | 1.1 | yes |
| Python (`"python"`, light) | 1.3 | yes |
| Python (`"python3"`, CPython 3.12) | 1.6 | yes |
| C (`nexvyn.h`) | 1.5 | yes |
| Squirrel | 1.5 | frozen at 1.8: apps keep working, no new functions |
| Java | 1.5 | frozen at 1.8: apps keep working, no new functions |

New SDK functions have the same names in Lua, JavaScript, Python and C. Start new apps in one of these four.

## Choosing `minSdk` and `targetSdk`

- `minSdk`: the lowest version that has every function your app calls. A Lua app that uses `g3d.model` needs `"1.8"`;
  one that calls `g3d.renderer` or `ui.beginFeed` needs `"1.9"`.
- `targetSdk`: the newest version you tested on. New apps use `"1.9"`.
- Unsure which function came when? Search the reference for the function: each section says its SDK version.
