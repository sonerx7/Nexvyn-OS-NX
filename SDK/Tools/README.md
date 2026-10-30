# PC tools

**English** · [Türkçe](README.tr.md)

Tools for people who make Nexvyn OS apps on a PC. The first one is ready: the [`nxv`](nxv/README.md) command line.
The list below is a prioritised proposal for the next ones, with what each would build on (files in `SnxOS/tools/` of
the Nexvyn OS source repository) and a rough effort estimate.

## Ready

**1. The `nxv` command line (v0.1, in this folder).** One Python 3 file, no extra packages: [nxv/README.md](nxv/README.md).
`nxv new <lang> <name>` (from `SDK/Languages/<lang>/template`, `--store` for the App Market item layout),
`nxv check <bundle>` (manifest, files, icon, translations, permissions that are used but not declared, `store.json`
and its `shots` script; with `--sdk` the language's official checker runs too), `nxv build` (Java `src/` → `app.jar`),
`nxv pack` (the same deterministic `.nxvapp` as `build_store.py`, `--sign` to sign), `nxv icon` (`make_icon.py`),
`nxv install` (copy into Ryujinx's or another SD card folder, optionally with `autorun.txt`) and
`nxv push --host <ip>` (upload to the console's **Connect to PC** FTP server, as a folder or one `.nxvapp`).

## Proposals (in priority order)

| # | Tool | What it gives | Builds on | Effort |
|---|---|---|---|---|
| 2 | **`nxv watch` and `nxv run`** | `watch`: sends changed files to the console over FTP as you save (only what changed) and can reopen the app. `run`: starts Ryujinx with `NexvynOS.nro` and an `autorun.txt` that says `launch <id>`, and streams the app's log (`System/Logs/Apps/<id>.log`) to the terminal. | `nxv push` / `install`, `ryu_test.sh`, `ui_smoke.py` (Ryujinx path and autorun) | 2-3 days |
| 3 | **Store submission validator (CI)** | On a pull request, runs `nxv check --sdk` + the language checker for every changed item under `Store/`, `build_store.py --check` and `catalog_check.py`, and posts the result on the PR. Half of the review checklist becomes automatic. | `nxv check`, `tools/ci/store.yml`, `catalog_check.py` | 1-2 days |
| 4 | **SDK type stubs** | Full SDK signatures for Lua (LuaLS `---@meta`), JavaScript (`nexvyn.d.ts`), Python (`nexvyn.pyi`) and Squirrel (a keyword list): completion and type checks in any editor. Generated from one source, regenerated when the SDK changes. | the function table in `source/runtimes/nxvrt_api.cpp` (already read by `gen_java_sdk.py` and `rt_check.py`), the SIGS list in `py_check.py` | 2-3 days |
| 5 | **VS Code extension** | Completion from the stubs of 4, a JSON schema for `app.json` / `store.json`, snippets (new app, scene, menu, `net.json`...), checker output in the Problems panel with line numbers, "Send to console" and "Run in Ryujinx" commands. | 2, 4, `nxv check` output | 1-2 weeks |
| 6 | **Localisation helper** | Extracts the app's `TR()` keys, compares every `lang/*.json` with `en.json` (missing, extra, `{0}` mismatches, texts that are far too long), exports/imports CSV or XLIFF for translators and suggests the shared terms of the system language packs (`common.ok`...). Machine translation only with the user's own key, opt-in. | `lang_check.py` (`--csv`), `romfs/System/Languages`, the translation check of `nxv check` | 2-3 days |
| 7 | **Icon and screenshot studio** | A desktop/web UI: a Material Icons glyph picker, colour presets, live icon preview; recording a `store.json` `shots` script visually (click on the window to get `wclick` fractions) and playing it in Ryujinx; a contact sheet. | `make_icon.py`, `Icons.codepoints`, `store_shots.py` | 4-6 days |
| 8 | **Web SDK simulator** | Quick UI prototyping in a browser: `gfx`/`ui`/`store`/`timer` implemented on a canvas; JS apps run directly, Lua apps through wasmoon/fengari. Not a console replacement (font metrics, performance, `g3d`), but layout and flow feedback in seconds. | the mock SDKs in `js_check.mjs` and `lua_check.py` | 2-4 weeks |
| 9 | **Theme editor** | An editor with preview for `Store/Themes/<slug>/source/theme.json` (appearance, accent, wallpaper, settings) and a `.nxvtheme` packer. | the theme format, `build_store.py` | 3-5 days |

Suggestion: 2 and 3 first (they speed up the daily loop and the review), then 4 (the base for 5 and for every
editor). There is no `nxlink` upload yet: `nxlink` sends `.nro` files to hbmenu, and Nexvyn OS has no listener that
accepts app bundles, so `nxv push` uses FTP. If such a listener is added on the system side, `nxv push --nxlink` can
follow.
