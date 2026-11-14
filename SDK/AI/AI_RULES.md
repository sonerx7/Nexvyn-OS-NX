# Nexvyn app rules for AI assistants (N2 Architecture — SDK 2.0 / 1.13 & Native SDK 1.2)

Read this file before writing any Nexvyn app. Short rules first, reasons after. For the full SDK contract read
`SDK/Reference/SDK.md` and `SDK/AI/llms.txt`.

## 1. MUST

1. Read `app.json` first. Set `minSdk` to the newest SDK function you use. Set `targetSdk` to `"2.0"` (or `"1.13"`) for new N2 apps.
2. Use only names that appear in `SDK/Reference/SDK.md` / `SDK/AI/system-prompt.md`. If a name is not there, do not invent it. Say so.
3. Pick the runtime from the **4 Official Primary Runtimes** in section 3: **Lua 5.4.7** (`"lua"`), **JavaScript ES2023** (`"js"`), **Python 3.12** (`"python3"` or `"python"` with `"targetSdk": "2.0"`), or **Native C/C++** (`"native"`).
4. Native apps (C / C++): set `"runtime": "native"` and `"minNative"` to `"1.2"` (or the version of the newest `nxn_*` function you call). Test every optional call with `nxn_caps_get` bits first. You can use `nxn_nxui_*` (`#include <nexvyn/nxn_nxui.h>`) for retained UI in native apps as well as `nxui.*` in Lua, JS and Python.
5. Keep all user-visible text in English and in `lang/<code>.json`. Call `TR(key)` (script) or `nxn_tr(key)` (native). Add `lang/en.json` before you use `TR`.
6. Make saves atomic: write a temporary file, then rename it over the real one. Keep the previous save until the new one is complete.
7. Do file, network and folder-scan work off the UI thread: `timer`, `net.*`, `fs.unzip`, `g3d.loadModel`, or a background thread that never holds the UI lock.
8. Handle touch, controller (single or pair), handheld and docked modes, windowed and full-screen. Check `sys.online()` before a request and show a friendly message when offline.
9. Handle the first launch (no network, no settings, default theme) and an update from an older version (settings and data kept, a new default never overwrites an old setting).
10. Give every game its own art direction (palette, type, layout, motion). Games do not copy the OS menu look. Games build their own menus from SDK building blocks.
11. Test with the SDK test tool (`nxvtest`, section 6). Read `result.json` and at least one or two key screenshots. Do not claim success without a PASS.
12. Store the app's icon as a real picture of the app (not a flat symbol on a gradient). Use the Store screenshot rules from the kit.
13. Use plain ASCII identifiers. Comments in English.
14. Tell the user, in the user's language, what you changed and what you did not test.

11. Dear ImGui apps (native, nxn_imgui.h): every visible widget needs a UNIQUE ID in its window. Two buttons with the same label (for example a toolbar "Rescan" and an empty-state "Rescan") trigger the red "2 visible items with conflicting ID!" banner on screen. Always give repeated labels a suffix: `ImGui::Button("Rescan##toolbar")`, `ImGui::Button("Rescan##empty")`; inside loops use `ImGui::PushID(i)` / `PopID()`; never use an empty label (`Button("")`), use `Button("##name")`. Test every screen state (empty library, first run, error) with the test tool and fail on this banner text.

## 2. MUST NOT

1. Do not rescale window pointer coordinates. Use the coordinates the SDK gives (`e.x`, `e.y`, `ui.mouse()`, `nxn_input_touch`) as they are.
2. Do not block the UI thread with file reads, folder scans, network calls, or sleeps. Do not hold a lock that the UI thread also needs while you wait on something else.
3. Do not start a background thread that takes a shared lock (SDL, GL, memory pool) while the main thread may wait for it. This freezes the desktop.
4. Do not store secrets in code, `app.json`, `lang` files, logs, screenshots or saves: no tokens, passwords, server addresses or `.env` values.
5. Do not remove or rename a public SDK function. Mark it deprecated instead; the SDK never removes a name.
6. Do not raise `minSdk` or `minNative` for no reason. Each raise drops users on older systems.
7. Do not kill an app from code because it is slow. The system asks the user (Wait or Close). Old apps (targetSdk below 1.8) are never killed automatically.
8. Do not quote emulator frame rates as console numbers. Emulator numbers are only valid as before/after comparisons on the same profile.
9. Do not use `require("snx.*")` (deprecated). Use `require("nexvyn.*")`.
10. Do not use Squirrel or Java for new apps. They are frozen at SDK 1.8: existing apps keep working, no new API.
11. Do not put a browser, OS or product brand name in UI text, store text or docs. Do not add emulator names to public text.
12. Do not read or write outside the app's folders without the matching permission. `fs` paths are relative to the app's data folder unless the user chose a folder.
13. Do not rely on a function that exists only in one runtime. Check the runtime column in the index.
14. Do not write to `romfs:/` or to the system folders. Do not call `sys.launch` or `nxv://` links without the `launch` permission.
15. Do not leave debug screens, test buttons or self-tests in the release build.

## 3. Which runtime? (4 Official Primary Tracks)

```
Need native C/C++ code, an existing C/C++ engine, SDL2, emulators, or raw GL/NexGFX?
  yes -> Native C/C++ ("runtime": "native", "minNative": "1.2", .nxvmod). Uses SDK/Languages/c/native-kit.
  no  -> Need a 2D game with scenes, sprites, tilemaps?  -> Lua 5.4.7 (nexvyn.game is Lua only)
         Need 3D voxels (g3d.voxels)?  -> JavaScript ES2023 (voxels are JavaScript only)
         Need the fastest startup, lowest RAM, utilities, or 3D PBR apps?  -> Lua 5.4.7 (default)
         Need full Python 3.12 stdlib, data analysis, or scientific math?  -> Python 3.12 ("runtime": "python3" or "targetSdk": "2.0")
         Need web-style async code, Promises, REST/WebSocket, JSON-heavy feeds?  -> JavaScript ES2023 ("runtime": "js")
```

Lua 5.4.7 is the default for new script apps. All script tracks share `gfx`, `ui`, `nxui` (Retained UI), `g3d` (NexGFX PBR), `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer` and `TR`.

## 4. Compatibility checklist (run before every release)

- [ ] `minSdk` equals the newest SDK function used (grep the index for each name).
- [ ] Native: `minNative` equals the newest `nxn_*` function used; optional calls guarded by `nxn_caps_get`.
- [ ] Any `targetSdk` change was tested on the new system before the value was raised.
- [ ] Old save files still load. New defaults do not overwrite saved settings.
- [ ] First launch works with no network and no saved data.
- [ ] `lang/en.json` has every key used by `TR`. Other languages may be partial.
- [ ] No deprecated name used (`require("snx.*")`, permission `"clipboard"`).
- [ ] No secret in any file. No local path in any file.

## 5. Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| App closes on first start on an older system with "needs a newer system" | `minSdk` / `minNative` higher than the system | Use only functions the target system has; lower the minimum or add a guard |
| `NXN_ERR_UNSUPPORTED` from a native call | Cap bit missing (stand-alone build, older system) | Check `nxn_caps_get` features first; use a fallback |
| Desktop freezes for seconds | File scan, network or sleep on the UI thread; or a background thread holding the shared lock | Move work to `timer`, `net.*`, `fs.unzip` or a thread that does not hold the UI lock |
| "This app stopped responding" | A callback ran longer than 3 s (10 s for `app.load` and the main file) | Split the work over frames or start it in the background |
| Clicks land in the wrong place after window resize | Coordinates rescaled twice | Remove your own rescale; use the SDK coordinates as they are |
| Text shows `?` or wrong letters | Missing `lang/<code>.json` key or non-UTF-8 file | Save files as UTF-8; add the key to `lang/en.json` |
| Save lost after a crash | Save written in place, not atomically | Write temp file, then rename |
| Settings reset after an update | New default written over the saved value | Write defaults only when the key is absent |
| Function "not found" in one language | Function exists only in some runtimes | Check the runtime column in `API_INDEX.md` |
| `require("snx.foo")` warning in the log | Deprecated module name | Use `require("nexvyn.foo")` |
| Native app refuses to load after the OS update | `minNative` missing for a newer `nxn_*` name | Set `minNative` to that function's version |
| Gamepad does nothing in a Native ImGui app | Gamepad navigation not enabled | Call `nxn_imgui_enable_gamepad(io)` after `ImGui::CreateContext()` |
| Turkish or Cyrillic text shows as `?` in ImGui | Only Latin-1 loaded | Use `nxn_imgui_add_font` with the language ranges |
| Test passes but the real console crashes | Checker or mock differs from the real runtime | Test on the emulator with the test tool; check the real runtime semantics |
| Screenshot is all black in tests | Frame not drawn before capture | Wait 2-4 s after launch; redraw once before the screenshot step |

## 6. Build, package, test, publish loop

Each step ends with a visible result. Repeat the loop after every change.

1. **Build (native only).** Use the Native SDK kit command `nxv-native` from the kit folder (`SDK/Languages/c/native-kit` in the kit). Script apps have no build step.
2. **Package.** Pack the app folder into a `.nxvapp` with the SDK packer (`python tools/nxvapp_pack.py MyApp.nxvapp`, as in the SDK reference section 1). Native and library packages use the same packer with the kit's options. Check that `manifest.sha256` is written.
3. **Install for test.** Copy the `.nxvapp` folder or zip to the SD card folder the SDK reference names (`sdmc:/NexvynOS/Applications/`). Reopen the Launcher.
4. **Write a scenario.** One JSON file in your project's `tests/` folder. See `SDK/Guides/AutomatedTesting.md` section 3. Add `expect_log` lines your app prints at start and at each action.
5. **Run the test.** `python SDK/Tools/nxvtest/nxvtest.py run tests/start.json`. Only one emulator run at a time. Exit code 0 is PASS, 1 is FAIL, 2 is a setup problem.
6. **Read the result.** Open `result.json` in the run folder. Check `result`, every `checks[*].ok` and `detail`, `not_responding`, `crash_lines`, `app_errors`. Read `app.log` for your own prints.
7. **Look at screenshots.** Open one or two key screenshots (start screen and the screen after the main action). Do not scan every file.
8. **Fix and repeat** from step 1 until PASS and the screenshots look right.
9. **Test both user paths.** Update path (old settings and data kept) and fresh install (first launch, no network). Both must pass.
10. **Publish.** Upload only the `.nxvapp` package and its store text. Keep source code and test scenarios private. The Store entry needs an English description and `lang` files for each language you ship. Do not publish builds that failed any step above.

Notes for the loop:
- Run the test tool in the background when another run is waiting. Do not poll it in a tight loop.
- Keep each scenario short; `time_limit` defaults to 90 s. The tool stops the emulator after each run.
- Never leave test scenarios, tokens or emulator paths in the packaged app.

## 7. Where to look

- `SDK/Guides/DevelopmentGuide.md`: full guide (in progress).
- `SDK/Reference/API_INDEX.md`: every public name, signature, version and runtime.
- `SDK/Guides/AutomatedTesting.md`: test tool setup and scenarios.
- `SDK/Samples/test-demo/`: a small app and test scenarios for the test tool.
- `SDK/Guides/README.md`: list of all guides.
