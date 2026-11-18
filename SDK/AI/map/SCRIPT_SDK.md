# SCRIPT_SDK

## Purpose
Maps the public script SDK modules and lifecycle callbacks across the primary script runtimes (Lua 5.4.7, QuickJS-ng ES2023, CPython 3.12) and interpreted C (`<nexvyn.h>`).

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `app.load` / `app.open` | Lifecycle | Entry on start (`arg`) and when opened with new item while running |
| `app.update` / `app.draw` | Lifecycle | Per-frame logic (`dt`) and drawing (`w, h` content pixels) |
| `app.event` / `app.close` | Lifecycle | Raw input event handler and close confirmation (return `false` to stay open) |
| `app.menu` / `app.onmenu` | Lifecycle | OS menu bar specification and menu item selection callback |
| `app.suspend` / `resume` / `focus` | Lifecycle | Background/foreground, sleep/wake, and window focus (`SDK 1.4+`) |
| `app.search` / `autosave` / `unsaved` | Lifecycle | System search results, periodic save hook, and unsaved state (`SDK 1.4+`) |
| `gfx.*` (`clear`, `rect`, `text`, `image`) | `gfx` | 2D immediate drawing, Material icon glyphs, cached images, and `gfx.imageUrl` |
| `ui.*` (`button`, `tokens`, `beginScroll`) | `ui` | Immediate-mode OS widgets, file/folder pickers, feeds (`beginFeed`), and `ui.tokens()` |
| `nxui.*` (`begin`, `endFrame`, `card`) | `nxui` | Retained semantic auto-layout UI (`SDK 1.13 / 2.0`) for Lua, JS, and Python |
| `g3d.*` (`mesh`, `model`, `renderer`) | `g3d` | 3D primitives, `.glb`/`.fbx` models, PBR renderer (`g3d.renderer("pbr")`), `g3d.voxels` (JS) |
| `phys.*` / `nav.*` | `phys` / `nav` | 3D collision worlds/controllers (`SDK 1.15`) and async navmesh/agents (`SDK 1.15`) |
| `fs.*` / `store.*` / `json.*` | `fs` / `store` | Sandboxed path I/O, `fs.unzip`, save backups, auto-persisted KV `store`, JSON encode/decode |
| `net.*` (`get`, `request`, `ws`, `oauth`) | `net` | Async HTTPS requests, offline cache, WebSockets, and browser OAuth (`"network"` perm) |
| `sys.*` (`time`, `online`, `share`, `memory`) | `sys` | Monotonic clock, connectivity, permissions, TTS (`speak`), `nxv://` links, 64 MB heap stats |
| `audio.*` / `timer.*` | `audio` / `timer` | Synthesized tones, SFX/music playback, `audio.stopAll()`, and frame timers (`after`/`every`) |
| `TR(key, ...)` | `TR` | Localized string lookup from `lang/<code>.json` with `{0}` placeholder substitution |

## Rules
- Never load images, read files, build large tables, or call `net.*` inside `app.draw`; load assets once in `app.load`.
- Script callbacks have a 3 s watchdog (`app.load` and top-level get 10 s; `targetSdk >= 1.8` terminates on timeout).
- Script window heap limit is 64 MB (`sys.memory()`); interpreted C `malloc` is also counted against 64 MB.
- Check `sys.online()` before network work and declare all gated permissions (`network`, `files`, `launch`, `notifications`, `games`) in `app.json`.
- Language differences: Lua uses 1-based indices and `nil`; JS and Python use 0-based indices, `null`/`None`, and array/tuple multi-returns.
- JS SDK async functions without a callback return Promises; Python uses callbacks; interpreted C uses underscore names (`gfx_rect`, `nxv_fmt`) and `<nexvyn.h>`.

## Pitfalls
- Using `io`, `os.execute`, `dofile` in Lua, Node/browser APIs in JS, or `open()`/`os` in Python—use `fs`, `store`, and `net` instead.
- Forgetting that `g3d.loadModel` / `fs.unzip` run asynchronously; blocking the main thread triggers the 3 s / 10 s watchdog.
- Hardcoding resolution instead of laying out from `app.draw(w, h)` / `gfx.size()` and `ui.tokens().textScale`.

## See also
- [INDEX](INDEX.md)
- [UI_NXUI](UI_NXUI.md)
- [INPUT](INPUT.md)
- [PACKAGING](PACKAGING.md)
