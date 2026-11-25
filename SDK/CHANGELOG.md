# SDK changelog

SDK-facing changes since Nexvyn OS 1.3.0, newest first. Taken from the release notes of each Nexvyn OS version and,
where marked, from the headers and tools in this folder. Browser, App Market and desktop changes that do not touch
the app SDK are left out; see the release notes for them. Current numbers: SDK **1.16**, Native SDK **1.2**,
native ABI **v1** (`VERSION.json`). Older SDK history: [Guides/SDK_VERSIONS.md](Guides/SDK_VERSIONS.md).

## 1.4.0 (SDK 1.16)

- Script frame pacing: `update` returning `false` lets a Lua, JavaScript or Python 3 (`"python3"`) app idle; input, a timer or
  `ui.requestFrame()` wakes it. Other return values behave as before.
- Script multitouch: `input.touches()` returns every finger as `{id, x, y, phase}`; touch events carry `e.touches`.
  Scripts that use these carry `"minSdk": "1.16"`.
- Python 3 apps start on a background thread while the window shows "Loading"; the desktop no longer freezes.
- A faulty script app is stopped alone: a broken theme, menu or callback, or a runaway Lua pattern, no longer takes
  the system down.
- On-screen performance panel (Ctrl+Alt+P, or L+R+ZL+ZR): frame time and phases, skipped frames, RAM, GPU lock time.
- `"fullscreenPause": true` in `app.json` (native apps and ports): frees the compositor's memory while fullscreen.

## 1.3.28

- Behavior of the host: an idle focused window is no longer redrawn every frame; it redraws when focus, text input
  or the pointer changes.

## 1.3.26

- System dialogs take gamepad input ahead of a native game's captured controller. Native input pauses while a shell
  modal is open, and held confirmation buttons cannot click through when focus returns.

## 1.3.25

- Graphics: models whose textures sit in a shared folder (`../tex/`) load with their textures; 2x multisampling no
  longer draws only the left half of the picture in the emulator.
- Game Engine content packs: manifest generation 2 records how parts belong together; older packs still load.

## 1.3.24

- The public SDK has a current starting guide, product and design identity standards, a gamepad / touch / multitouch
  contract, and port / launcher and production-quality guides.
- New apps, games, ports and launchers must support English, Turkish, German, Spanish, French, Japanese, Korean and
  Chinese. The authoring checker rejects missing dictionaries, incomplete or empty keys, duplicate keys and changed
  format tokens. Existing installed apps remain compatible.
- Script and native utility starters include eight-language resources. The exported native creator, build and
  package workflow works without private test tooling. SDK Markdown is English.
- Applications open directly: the extra "not sandboxed" launch modal for native modules and compatibility runtimes
  is gone. Package validation, installation review and permissions remain. Native code still shares the host process.
- General SDK remains 1.15, Native SDK 1.2, native ABI v1.

## 1.3.21 (SDK 1.15)

- 3D collision `phys`: static meshes, boxes, raycasts, sphere and capsule sweeps, a walking character controller
  (slopes, stairs, jumping), trigger volumes. Same names in Lua, JavaScript, Python (`"python3"`) and C; native apps
  get `nxn_phys_*` (`nxn_phys.h`, `NXN_CAP_PHYS`).
- Navigation `nav`: bake a walkable grid from the collision world in the background, find paths, move agents that
  re-plan. Same names in the same languages; native `nxn_nav_*` (`nxn_nav.h`, `NXN_CAP_NAV`).
- Scripts that use them carry `"minSdk": "1.15"`.

## 1.3.20

- Graphics: compressed textures (ETC2 and EAC, KTX files) cut texture memory to about a third in the test scenes;
  models and 2D images that use PNG or JPG are unchanged.

## 1.3.19

- Native C/C++ UI kit: `nxn_os_frame_begin` sets scale, fonts and spacing in one place, so native apps look like Lua,
  JavaScript and Python apps at every size. The design checker flags raw widgets, fixed pixel sizes and font scaling.
- Nexvyn Studio: a project wizard picks the language, one-key Check (manifest, languages, design rules, script
  syntax), Install and Run, and Publish builds an App Market submission package.

## 1.3.18 (SDK 1.14)

- SDK 1.14: `fs.readBytes` in Lua and C, `fs.unzip` and `sys.games` in C, `nxui.feedPointer` in JavaScript and
  Python; all four languages expose the same API. No native ABI change. Scripts that use them carry `"minSdk": "1.14"`.
- Native platform: streaming of large files through a shared block cache (`nxn_stream_*`, `NXN_CAP_STREAM`). (The
  release also reworked OS-internal JIT code memory and the event loop; those are not app API.)
- Input: relative mouse for first-person games and up to 8 controllers (`input.relativeMouse`, `mouseDelta`,
  `padCount`, `padDown`; `nxn_input_*`).
- Live language change: running apps get a `language_changed` event (Lua, JavaScript, Python, C and native).
- Runtimes and Frameworks: a Settings pane lists built-in engines and installed runtime packages (safe mode, remove,
  roll back, retry). Runtime providers can draw (Provider ABI 1.1); the provider loader stays off by default.
- One design language: native apps use the same OS components and sizes as script apps (`nxn_os_ui.h`); a design
  checker is part of the release gate.
- Security: HTTPS certificate verification is on for every connection; a failed verification is an error and is never
  retried without verification.

## 1.3.10

- Porting and maximum input support (`sdl2-nexvyn` and `<nexvyn/nxn_port_input.h>`): 16-finger multi-touch, pinch to
  zoom, two-finger tap right-click, two-finger pan scroll, long-press right-click, `nxn_rumble` haptics, and
  RTS / CRPG / FPS input profiles for ported games.
- SDK CLI: the `"native"` runtime and Store category checks in `SDK/Tools/nxv/nxv.py`; `nxn_port_input.h` is excluded
  from the ABI check (header-only); the end-to-end `AI/GEMINI_WORKFLOW.md` guide.
- Store packages moved to `targetSdk` 1.13, explicit `runtime` declarations, and `"minNative": "1.2"` /
  `"targetNative": "1.2"` for native ports and emulators.

## 1.3.9 (N2, final)

- Four primary runtimes: Lua 5.4.7 (generational GC), JavaScript ES2023 (QuickJS-ng 0.17.0, bytecode cache),
  Python 3.12 (CPython 3.12.16; `"runtime": "python3"`), and native C/C++ (`.nxvmod`, frozen ABI v1, Native SDK 1.2:
  `nxn_window_set_*`, `nxn_power_get`, `nxn_dialog`, and `nxn_nxui_*`).
- NXUI Retained and Semantic UI Engine (`nxui.*`, `nxn_nxui_*`): `table`, `virtuallist`, `canvasBegin` / `canvasEnd`,
  `dialog`, controller spatial focus (`moveFocus`, `activateFocused`).
- All SDK and AI documents are English `.md`; `AI/system-prompt.md` and `AI/llms.txt` carry verified starter templates
  and a zero-hallucination checklist.

## 1.3.8 (N2 architecture, beta)

- First N2 release of the runtimes and NXUI listed under 1.3.9; NXUI design standards (spatial focus, 44 px minimum
  touch targets, responsive layout across four viewports).

## 1.3.1

- Developer kit: the guide and the AI rules explain how to avoid duplicate widget IDs in Dear ImGui apps.

## Also in this kit (from headers and tools)

Read from the headers and tools in this folder, not from release notes; check capability bits at run time.

- Native: `nxn_capability_query` (`nxn_caps.h`, header-only, no `minNative` bump), `nxn_memory_budget_get` /
  `nxn_memory_budget_request` (`NXN_CAP_MEMORY_BUDGET`), `nxn_thread_hint_request` (worker core and priority hint).
- Vulkan: `nxn_vk.h` (`nxn_vk_available()`), `NXN_CAP_VULKAN`, `NXN_GFX_API_VULKAN`, the `vulkan` manifest
  flag, the `vulkan` template and the `hello_vk` / `vk_canary` examples. Nexvyn OS 1.4.0 turns Vulkan on by default when the driver check at start passes;
  check `NXN_CAP_VULKAN` at run time and fall back to GL. See `AI_GUIDE.md` section 10.4.
- `nxv_native symbolize` (crash report to function and line), `nxv_native check-design`, `nxv_native shader`.
