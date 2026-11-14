# Native SDK guide: from a clean machine to a running app

This is the short path. The reference is `docs/NATIVE_KIT.md` (every command and header), the rules are in
`docs/NATIVE_COMPAT.md` and `docs/COMPATIBILITY.md` (*Native SDK*).`.

## 1. Install (once)

0. The kit is the folder `SDK/Languages/c/native-kit` of the public repository (download the repository as a zip or clone it, no installer). Run every command of this guide from that folder.
1. devkitPro with the Switch packages (`switch-dev`, `switch-sdl2`, `switch-mesa`, `switch-glad`, ...). The tested versions
   are in `tools/toolchain.json`.
2. Python 3. CMake and Ninja come with devkitPro's shell. On Windows the CLI starts that shell by itself.
3. `python tools/nxv_native doctor` checks all of it. Fix every line that says `MISSING` before going on.
4. Apps that use SDL2 in a window also need the kit's SDL2: `python sdk/native/sysroot/build.py sdl2-nexvyn` (once; pass the
   result with `--sysroot`).

## 2. New, build, package

```
python tools/nxv_native new notes --template app      # app | game | port | sdl2 | gl | ...
python tools/nxv_native build notes --sysroot <sysroot>
python tools/nxv_native package notes                 # -> notes/build/notes.nxvapp
```

| Template | What you get | Not included |
|---|---|---|
| `app` | A small real UI app: file picker (`nxn_pick`), a setting kept between runs, texts in `lang/en.json` + `lang/tr.json` (`nxn_tr`), colours, sizes and fonts from the system tokens (`nxn_ui_tokens_get`), so it follows theme, accent and text size | A theme of its own: an app looks like Nexvyn OS |
| `game` | Loop with a fixed update step, resize / focus / suspend, a GL quad batch, an action map (pad, keyboard), sound from the OS mixer, a save file | A menu or any look: a game gets its own art direction |
| `port` | The glue for an existing CMake project: `fetch.py` (pinned tag + commit, patches), `CMakeLists.txt` (toolchain, SDL2, compat layer, the Nexvyn target), `patches/`, a stand-in `example-upstream/` so it builds before you fetch anything | The upstream code, BIOS, firmware, game data |

Every template has `"minNative": "1.1"` and builds and packs with the two commands above. Edit `app.json` (id, name,
author, category, permissions) before you ship. Release builds use `-O2` and LTO (`-DNEXVYN_LTO=OFF` turns LTO off); the
toolchain already targets `-march=armv8-a+crc+crypto -mtune=cortex-a57` (NEON included). `--debug` makes a separate
`-O0 -g` build. The ImGui in the `app` template is a source you compile in, not a system shell: its shell helpers
(`fork`, `execvp`) are switched off with `IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS`.

## 3. Run

- Emulator: `python tools/nxv_native run notes --sd <SD card root>` copies the bundle to `<sd>/NexvynOS/Applications`.
  It never starts anything; start Nexvyn OS yourself and open the app.
- Console: `run --sd <SD card root>` onto the console's SD card, or install the `.nxvapp` the way Nexvyn OS installs packages.
  An unsigned package installs with a warning; for the App Market you do not sign: the maintainers build and sign the Store package from your pull request (`package --sign key.pem` is only for packages you distribute yourself).

## 4. When it does not work

Where to look, in this order:

1. **The app's log** (`System/Logs/Apps/<app id>.log` on the SD card). It has the start line, everything the app wrote with
   `nxn_log`, **and stdout / stderr** (`printf` lines, marked `O` / `E`, capped), and, for a failed start, the exact reason.
2. **Crash report**: a fault in any app thread closes the window ("<app> stopped"), writes the crash line to the log and a
   report to `System/Logs/Crashes`. Nexvyn OS keeps running. Three crashes in a row make Nexvyn OS ask "Close / Keep enabled".
3. `nxv-native check-win build/<name>.nxvmod` at build time: identity, no TLS, no text relocations, every import offered.
   `build` runs it for you and fails before you package a module that cannot load.

### Reading a crash report

The report in `System/Logs/Crashes` and the crash line in the app's log name the module and a **backtrace**: up to 16
return addresses taken from the frame pointer chain (x29) of the thread that faulted. Addresses inside your app print as
`app+0x4b488` (offset in the module), Nexvyn OS code as `os+0x...`. The report also names the module's **build-id**. The
OS walks only memory it can read and stops at the first bad frame; a leaf function's own caller shows in `lr`.

```
backtrace: os+0xd49f08 app+0x4b488 app+0x4b49c app+0x4b4cc app+0x5759c
```

Nexvyn OS has no symbol tables (size), so names come from your PC: `nxv-native symbolize <report> [--elf <module>.nxvmod.debug]`
runs addr2line and prints `function at file:line` for each `app+0x...` address. Every build links a build-id and keeps the
debug information in `build/<name>.nxvmod.debug` (the packaged module has none); `symbolize` picks the file whose
build-id matches the report, so keep the build folder of every release you ship. `package` prints the build-id.
The kit compiles with `-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer` (`-DNEXVYN_FRAME_POINTER=OFF` turns it off).

### Messages at load time

The user sees the message in their language; the log has the technical line (`load failed: ...`) and `what to do: ...`.

| What the user sees (English) | Cause | Fix |
|---|---|---|
| "This file is not a windowed native app" | the module has no windowed identity (built as a stand-alone `.nro`) | build with `nxv-native build` / `nexvyn_add_windowed` |
| "built for module interface generation N, but this system uses M" | ABI generation mismatch (`abi=` in the module's `.nxnwin` section) | rebuild with the matching kit, or update the app. The generation is raised by hand only when the interface breaks |
| "needs a newer Nexvyn OS (host interface N, this system has M)" | the module imports more than this system offers | update Nexvyn OS, or build for an older `minNative` |
| "The app needs the function X ..." | an import that the system does not offer to windowed apps (`missing symbol X` in the log) | remove the call, use the kit's equivalent, or add the compat layer (`nexvyn_use_compat`); `check-win` lists them all |
| "The app uses thread_local variables ..." | `PT_TLS` in the module or a library while setting `native.windowedTls` is off (or an older Nexvyn OS) | turn the setting on (check `NXN_CAP_TLS`), or replace with plain statics / your own per-thread data |
| "thread_local code built for another TLS model" (log) | an object compiled without the kit's `-mtls-dialect=trad -ftls-model=global-dynamic` (devkitA64's default TLS code is wrong for modules) | build through `nxv-native` / `nexvyn_add_windowed`; give Makefile objects the same flags |
| "not built as position-independent code" | text relocations | build through `nxv-native`; link only `-fPIC` static libraries |
| "no code memory for native apps in this mode" | Nexvyn OS runs as an applet (started from the Album) | start Nexvyn OS in title mode (hold R while starting a game) |
| "not enough free memory" | the app's code and data do not fit now | close other apps; check the size of the module |
| "damaged or built with an unsupported toolchain" | truncated file, wrong architecture, unknown relocation | reinstall; rebuild with `nxv-native build` |

C++ exceptions need setting `native.windowedEh` and a module built with this kit (below). Without them, or when nothing
catches it, a `throw` ends in `std::terminate`: that is a crash report, not a load error. JIT is not available in a window.

## 5. Platform limits

| Area | In a window (and full screen in Nexvyn OS) |
|---|---|
| Files, time, pipes, poll, environment | supported by the kit's compat layer; the call list is in `NATIVE_COMPAT.md` |
| Threads (`pthread`, `std::thread`) | supported; priority is limited and one core stays free for Nexvyn OS |
| TLS (`thread_local`) | with setting `native.windowedTls` (`NXN_CAP_TLS`), default on for apps with `"minNative": "1.1"` or later (off for 1.0 apps; a setting given explicitly wins); not yet verified on a console; off: the loader refuses `PT_TLS` |
| C++ exceptions | with setting `native.windowedEh` (`NXN_CAP_CXX_EXCEPTIONS`), default on for apps with `"minNative": "1.1"` or later (off for 1.0 apps; a setting given explicitly wins); not yet verified on a console; off: `throw` ends in `std::terminate` |
| JIT (`PROT_EXEC`) | **not available** in a window |
| Dynamic loading | `.nxvlib` only (`nxn_lib_open` / `dlopen`) with setting `native.windowedLibs` (`NXN_CAP_SHARED_LIBS`), default on for apps with `"minNative": "1.1"` or later (off for 1.0 apps; a setting given explicitly wins); not yet verified on a console; no Linux `.so` |
| Sockets | with the app's network permission |
| `fork`, `exec`, `system`, `popen`, pty | never |
| Memory isolation | **none**: the app shares Nexvyn OS's process (see below) |

**Graphics.** The display is OpenGL 4.x core or ES 3.2 on the console's GPU driver (`nxn_display`, glad, or SDL2 windows).
Programs written against desktop GL usually need small changes. **deko3d is not a path for existing GL ports**: it is a
different API, and the kit does not translate GL to it. A port keeps using GL through the display (or NexGFX native).

In full screen the user can always leave with the controller by holding − for one second (setting `wm.fullscreenExitHold`); a short press of − reaches the app as usual.

**Signatures and permissions are not memory isolation.** A signed package proves who made it and that it was not changed. The
`"permissions"` in `app.json` decide what Nexvyn OS offers the app (files, network, ...) and what the user is told. Neither
stops native code from writing into Nexvyn OS's memory: a wild write can damage the system. That is why the user is asked once
before native code runs, and why the Store reviews native packages. Test on the emulator before the console, and keep your
data in `nxn_fs_*` folders.

### Text and fonts

Dear ImGui draws Latin-1 only unless it gets glyph ranges, so Turkish `ı ğ ş İ`, Cyrillic or Greek letters show as `?`. Load the system font through `nxn_imgui_add_font()` from `<nexvyn/nxn_imgui.h>` (the `app` template does): it adds the ranges of the app's language and keeps the atlas small. Japanese, Korean and Chinese text needs the system's CJK font, which windowed apps cannot get yet (see `NATIVE_KIT.md`, *Text and fonts*). Test your app in more than one language: `lang/*.json` plus Settings > Language.

## 6. Before you publish

- `python tools/nxv_native build <app> --clean` on a clean checkout, then `package`. No warnings left in your own code.
- Open the app, use it for a while, close it with the window button and with the app's own exit: the log ends with
  `ended`. Open and close it ten times: memory stays flat.
- Texts in `lang/*.json` (English required, any others you can), store text in English, screenshots in the English UI.
