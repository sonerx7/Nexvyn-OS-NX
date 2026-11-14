# Gemini & AI Agent End-to-End Workflow (Nexvyn OS 1.3.10-beta.2 / SDK 1.13 & Native 1.2)

This document is the complete operational specification for **Gemini** and any AI coding assistant building, porting, validating, or publishing apps, games, and system updates for **Nexvyn OS**. Follow every section strictly so generated code runs on real hardware without freezes, checker errors, or Store rejections.

---

## 1. Ground Rules (Zero Hallucination)

1. **Read the Contract First:** Before writing any code, inspect:
   - `SDK/AI/llms.txt` — single-file architecture & API index
   - `SDK/AI/system-prompt.md` — full SDK surface & limits
   - `SDK/AI/AI_RULES.md` — MUST / MUST NOT engineering rules
   - `SDK/AI/languages/<lang>.md` — exact bindings for `lua`, `javascript`, `python`, or `native`
2. **Never Invent APIs:** If a function, module, or `app.json` field does not appear in `SDK/Reference/SDK.md` or `SDK/AI/system-prompt.md`, it does not exist. Do not assume LÖVE2D, Node.js, browser DOM (`window`, `document`), or standard desktop OS calls inside script apps.
3. **No Secret / Local Path / Brand Leakage:** Never commit tokens, passwords, server IPs, local machine paths (`<user>` home paths), or third-party console/emulator/engine brand names into public files (`tools/release.py --only leakcheck` enforces this).

---

## 2. Manifest (`app.json`) & Exact Version Contract

Every `.nxvapp` bundle requires `app.json` at its root.

### Current Target Versions (Verified)
| Field | Script Apps (`lua`, `js`, `python3`) | Native C/C++ Apps (`native`) | Notes |
|---|---|---|---|
| `"runtime"` | `"lua"` / `"js"` / `"python"` / `"python3"` | `"native"` | Always declare `"runtime"` explicitly. Do not omit it even for non-Lua `main.js` / `main.py`. |
| `"minSdk"` | `"1.0"` (Lua), `"1.1"` (JS), `"1.3"` (Py), `"1.6"` (Py3), `"1.12"` (NXUI/tokens) | `"1.10"` (or `"1.13"` with `loadingHint`) | Use the lowest SDK version that contains all APIs your app calls. |
| `"targetSdk"` | **`"1.13"`** | **`"1.13"`** | Current OS SDK is `1.13`. Do **not** set `"targetSdk": "2.0"` in Store manifests (`catalog_check.py` warns when `targetSdk > 1.13`). |
| `"minNative"` | — | **`"1.2"`** | Current Native ABI runtime is `1.2` (`nxnative::kVersion = "1.2"`). Never set `"minNative": "2.0"` — the loader rejects it. |
| `"targetNative"` | — | **`"1.2"`** | Use `"1.2"` for existing SDL2/Native 1.2 apps (`2.0` enables N2-only coordinate/router gates). |
| `"loadingHint"` | optional `bool` | `true` for large ports | Extends initial loading watchdog from `5 s` to `120 s` (SDK `1.13`). |

### Categories, Permissions & Gamepad
- **Valid `app.json` categories:** `system`, `productivity`, `office`, `utilities`, `media`, `internet`, `games`, `switch`, `developer`, `emulator`, `showcase`, `education`, `themes`, `fonts`, `runtimes`, `other`.
- **Enforced permissions:** `network`, `files`, `launch`, `notifications`, `games`.
  - Always set `"permissions": []` if none are needed.
  - Never add `"clipboard"` to `permissions` (retired; `sys.clipboard` always works without permission).
- **Games & Ports:** Set `"gamepad": true` and `"resizable": true` so controller input goes to the app (`L+R` toggles cursor mode).

---

## 3. Choosing the Right Runtime

1. **Lua 5.4.7 (`"runtime": "lua"`):** Default for utilities, 2D games (`require "nexvyn.game"`), and 3D PBR (`g3d.*`). Uses Generational GC (`~0.28 ms` pause).
2. **JavaScript ES2023 (`"runtime": "js"`):** QuickJS-ng `0.17.0` with SD bytecode caching, Promises, `net.*`, and `g3d.voxels` (voxels are JS-only).
3. **Python 3.12 (`"runtime": "python3"` or `"python"`):** CPython `3.12.16` stdlib (`json`, `re`, `urllib.parse`, `statistics`, `uuid`, etc.).
4. **Native C/C++ (`"runtime": "native"`):** AOT ARM64 `.nxvmod` compiled with `devkitA64` GCC against **Frozen ABI v1** (`sdk/native/include/nexvyn/*.h`), `sdl2-nexvyn`, `nxn_nxui_*`, or OpenGL / NexGFX.

*(Legacy runtimes `"c"` TinyCC, `"squirrel"`, and `"java"` miniJVM remain supported for existing bundles, but use one of the 4 primary runtimes for new projects.)*

---

## 4. Porting Large Games & Maximum Input Support

When porting C/C++ games or engines (RTS, CRPG, FPS, arcade, emulators), use the dedicated porting kit in `SDK/Porting/` and the updated `sdl2-nexvyn` (`2.28.5-nexvyn.1`) + `<nexvyn/nxn_port_input.h>`:

- **16-Finger Multi-Touch & Gestures (`sdl2-nexvyn`):**
  - 1-finger drag → primary pointer / left click drag
  - **Pinch-to-zoom** (2 fingers) → mouse wheel notches (`+1`/`-1`) or `SDL_MULTIGESTURE`
  - **2-finger tap** → right-click (`SDL_BUTTON_RIGHT`)
  - **2-finger pan** → smooth mouse wheel / camera pan
  - **Long-press** → right-click for strategy / CRPG ports
- **Gamepad-to-Mouse & Haptics:**
  - Set `NEXVYN_GAMEPAD_MOUSE=1` (or configure `nxn_pi_profile` via `<nexvyn/nxn_port_input.h>`) for left-stick/right-stick cursor + `A`/`B` mouse buttons + triggers.
  - Rumble / haptics use `nxn_rumble` through `SDL_sysjoystick.c`.
- **Header-Only Input Helper (`<nexvyn/nxn_port_input.h>`):**
  - Supports profiles `NXN_PI_PROFILE_GAMEPAD`, `NXN_PI_PROFILE_RTS`, `NXN_PI_PROFILE_CRPG`, `NXN_PI_PROFILE_FPS`.
  - Pinch modes: `NXN_PI_PINCH_WHEEL` (default for RTS like Red Alert 2 / OpenTTD), `NXN_PI_PINCH_CTRL_PM` (`Ctrl + =/-`), or `NXN_PI_PINCH_EVENT_ONLY`.
  - Note for ABI checks: `nxn_port_input.h` is header-only (`static inline`) and listed in `SKIP_HEADERS` in `tools/abi_check.py`.

---

## 5. Preventing Freezes, Crashes & UI Bugs

1. **Never Block the Main/UI Thread:**
   - Do not perform large directory scans, synchronous file reads, network requests, or `sleep()` inside `draw()` / `update()`. Use `timer`, `net.*`, `fs.unzip`, `g3d.loadModel`, or worker threads that **never** lock the UI/GL/SDL mutex while waiting.
   - Script watchdog: `app.load` and top-level script execution have a `10 s` budget (`120 s` when `"loadingHint": true`); frame callbacks (`update` / `draw`) have a `3 s` budget.
2. **Never Claim Keyboard Focus Unconditionally Every Frame:**
   - In C++ shell apps or custom text views, never force `c->focus = id; c->focusClaimed = true;` unconditionally on every `draw()` frame. When the user is in System Keyboard (`swkbd`) mode (`input.keyboard == 1`), unconditional focus traps the OS in a repeated `swkbd` reopen loop and blocks dismissing the on-screen keyboard. Use an explicit `kbWanted` state toggled by tap or keyboard button, and clear `kbWanted` after `swkbd` submits.
3. **Protect Font Metrics, Scroll State & History Reads:**
   - Guard text width/line-height divisions against zero (`std::max(1.0f, text::width(...))`).
   - Null-check `ui::scrollState(id)` before dereferencing.
   - Bound log/history reads on startup (e.g. tail-cap large files to `256 KB`) so corrupt or huge user files cannot stall app launch.
4. **Dear ImGui (`nxn_imgui.h`):**
   - Every visible widget in a window must have a unique ID (`"Label##unique"`, or `ImGui::PushID(i)` / `PopID()` in loops) to avoid ID conflict banners.
5. **Localization (`TR()`):**
   - Every `TR("key")` call in code must exist in `lang/en.json` (and `lang/tr.json` when present). Keep `app.json` and `store.json` English (`"en"`) fields non-empty.

---

## 6. Verification, Packaging & Store Pipeline (Exact Commands)

Run this exact loop after every change before claiming completion or publishing:

1. **Bundle & Runtime Check (`nxv check`):**
   ```sh
   python SDK/Tools/nxv/nxv.py check <bundle_or_source_dir> --sdk <SnxOS_checkout> --frames 5
   ```
   - Supports `"lua"`, `"js"`, `"python"`, `"python3"`, `"squirrel"`, `"c"`, `"java"`, and `"native"` (checks manifest, `.nxvmod` presence, `lang/*.json`, permissions, and `store.json`; runs language checkers for script apps).
2. **Pack `.nxvapp`:**
   ```sh
   python SDK/Tools/nxv/nxv.py pack <bundle_dir> -o <out.nxvapp>
   ```
3. **Rebuild Store Packages & Catalogs (`Nexvyn-OS-NX`):**
   ```sh
   python Tools/build_store.py
   python Tools/build_store.py --check
   ```
   - Deterministically packs all Store `.nxvapp` / `.nxvtheme` / `.nxvfont` bundles and updates `Store/catalog.json`, `Store/beta.json`, `Store/dates.json`, and `SDK/samples.json`.
4. **Catalog Validation (`SnxOS-NX`):**
   ```sh
   python tools/catalog_check.py ../Nexvyn-OS-NX/Store/catalog.json ../Nexvyn-OS-NX/Store/beta.json
   ```
   - Must report `0 errors, 0 warnings`.
5. **Compatibility & Native ABI Verification (`SnxOS-NX`):**
   ```sh
   python tools/compat_check.py --release-repo ../Nexvyn-OS-NX
   ```
   - Validates all built-in apps, templates, SDK samples, Store apps, and frozen Native ABI v1 (`tools/abi_check.py`). Must report `0 fail`.
6. **OS Build & Live Smoke Test:**
   ```sh
   ./build.sh
   python tools/ui_smoke.py --apps terminal,files,browser,settings,appstore,notes,calculator,textedit,games,studio,sysinfo,console
   ```
   - Verifies clean NRO version matching (`NACP` == `Makefile` `APP_VERSION`), zero crashes, and captured window screenshots.
7. **Public Repo Leak Check & Release:**
   ```sh
   python tools/release.py --only leakcheck
   python tools/release.py --beta
   ```
   - Ensures no internal docs, secrets, local paths, or restricted brand names exist in `Nexvyn-OS-NX` before committing or publishing a beta pre-release.
