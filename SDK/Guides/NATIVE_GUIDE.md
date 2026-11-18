# Native SDK guide: from a clean machine to a running app

This is the short path. The reference is `docs/NATIVE_KIT.md` (every command and header), the rules are in
`docs/NATIVE_COMPAT.md` and `docs/COMPATIBILITY.md` (*Native SDK*).

## 1. Install (once)

0. The kit is the folder `SDK/Languages/c/native-kit` of the public repository (download the repository as a zip or clone it, no installer). Run every command of this guide from that folder.
1. devkitPro with the Switch packages (`switch-dev`, `switch-sdl2`, `switch-mesa`, `switch-glad`, ...). The tested versions
   are in `tools/toolchain.json`.
2. Python 3. CMake and Ninja come with devkitPro's shell. On Windows the CLI starts that shell by itself.
3. `python tools/nxv_native doctor` checks all of it. Fix every line that says `MISSING` before going on.
4. Apps that use SDL2 in a window also need the kit's SDL2: `python sdk/native/sysroot/build.py sdl2-nexvyn` (once; pass the
   result with `--sysroot`).

On Windows, extract the kit and create projects under a short path (for example
`C:/NexvynSDK`). Deeply nested paths can exceed the compiler's object/dependency-file
limit even when CMake configures successfully. If a build reports an overlong object
path or cannot create an `.o.d` file, use a fresh build from a shorter location.
Keep the original project and debug artifacts; changing global Windows path settings
alone does not establish support in every toolchain component.

## 2. New, build, package

```
python tools/nxv_native new notes --template app      # app | game | port | sdl2 | gl | ...
python tools/nxv_native build notes --sysroot <sysroot>
python tools/nxv_native package notes                 # -> notes/build/notes.nxvapp
```

| Template | What you get | Not included |
|---|---|---|
| `app` | A small real UI app: file picker (`nxn_pick`), a setting kept between runs, texts in all eight required `lang/*.json` dictionaries (`nxn_tr`), unified Nexvyn OS cards/switches/buttons via the frame layer of `<nexvyn/nxn_os_ui.h>` (UI scale, fonts, style, rows) driven live by `nxn_ui_tokens_get`, so it matches script `ui.*` apps across Light/Dark/accent/text size/interface size | A theme of its own: a utility app looks like Nexvyn OS |
| `game` | Loop with a fixed update step, resize / focus / suspend, a GL quad batch, an action map (pad, keyboard), sound from the OS mixer, a save file | Finished game art/content; ordinary launcher/settings controls still use OS helpers |
| `port` | The glue for an existing CMake project: `fetch.py` (pinned tag + commit, patches), `CMakeLists.txt` (toolchain, SDL2, compat layer, the Nexvyn target), `patches/`, a stand-in `example-upstream/` so it builds before you fetch anything | The upstream code, BIOS, firmware, game data |

The generator records the installed Native SDK version (currently `1.2`) in `minNative`
and `targetNative`. Build and package the generated project with the commands above. Edit `app.json` (id, name,
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

### Choose the language first

UI-heavy tools, utilities and productivity apps (chat clients, editors, settings, dashboards) are better written in
Lua, JavaScript or Python with `nxui.*`: they draw through the OS renderer itself (its text engine, focus navigation,
on-screen keyboard and themes) and need no build. Native C/C++ is for heavy computation (LLM inference, emulators, 3D,
codecs, ports). A hybrid (native engine, script UI) is not available yet: a script app cannot load native code today
(`sdk/SDK.md` 4b, section 8).

### The frame layer (required for ImGui apps)

Every frame of a native UI app goes through `nxn_os_frame_begin(&tok, fb_w, fb_h)` ... `nxn_os_frame_end()`. It
replaces `ImGui_ImplOpenGL3_NewFrame()` / `ImGui::NewFrame()` / `ImGui::Render()` and owns what apps used to get wrong:

* **UI scale.** 1.0 is the OS's 1280 x 720 layout. Inside Nexvyn OS the system reports the window surface scale
  (`nxn_ui_tokens.ui_scale`: the interface size of Settings > Display, handheld or TV); in a stand-alone .nro it is the
  screen height / 720. Every kit size is multiplied by it; the app writes its own numbers as `NXN_S(px)`.
* **Fonts.** The kit builds the text roles (Title, Header, Body, Caption, Strong, Mono) at
  `floorf(pt * 1.21f + 0.5f)` x text size x scale, with the glyphs of the user's language, and rebuilds them (0.2 s
  debounce, new GL texture) when the scale or the accessibility text size changes. The app adds no fonts and never
  touches `FontGlobalScale` / `SetWindowFontScale`; an app text size option is `nxn_os_set_text_zoom()`.
* **Style.** `nxn_os_apply_style()` x scale every frame: theme, accent and contrast changes need no code.
* **Minimum sizes.** Text controls never go below the 30 px control height (x scale), icon buttons, rail items, list rows
  and dropdown menu rows never below 44 px; each widget draws its text with its role font.
* **Rows.** `nxn_os_row_begin()` ... `nxn_os_row_end()` puts widgets on one line with equal height, vertically centred;
  `nxn_os_fill(frac)` gives a share of the width left; `nxn_os_labeled(label, widget)` is a form row.

Start from the `app` template; `product/showcase/com.nexvyn.uikit.cpp` is a complete reference screen (sidebar, toolbar, card,
message field) without one pixel literal. `python tools/nxv_native check-design <dir>` (and `python tools/nxv.py check
<dir>`) fail an ImGui app that skips the frame layer, uses raw ImGui widgets, adds fonts, scales fonts or writes pixel
literals outside `NXN_S()`; each finding names the fix. `nxv_native package` lists the same findings.

### Unified UI and Design Tokens (`<nexvyn/nxn_os_ui.h>`)

To prevent native utilities from having an inconsistent visual appearance compared to Lua/JS/Python apps, native utility and dashboard apps MUST use `<nexvyn/nxn_os_ui.h>` parameterized by live OS tokens (`nxn_ui_tokens_get(&tok)`):

* **Window Clear:** Clear the OpenGL framebuffer with `nxn_os_clear_color(tok)` (`theme.window` parity).
* **Cards & Surfaces:** Use `nxn_os_card_begin_ex("card_id", width, 16.0f, 13.0f, tok)` … `nxn_os_card_end()` for grouped white/dark panels with 10px radius, 1px border (`tok.border`), and soft drop shadows.
* **Component Kit:**
  - `nxn_os_segmented_tabs`: capsule tabs matching OS `ui.segmented`, default height 28px (the script default; pass `height` for another one).
  - `nxn_os_switch`: 38×22px animated smooth pill toggle matching `ui.toggle`.
  - `nxn_os_dropdown`: select box with trailing accent chevron chip; height from the OS token (`control_height`), 28px without one, or the `height` argument.
  - `nxn_os_button`: 30px height buttons (`NXN_OS_BTN_PRIMARY`, `DEFAULT`, `DESTRUCTIVE`, `PLAIN`).
  - `nxn_os_badge`: 22px height pill badges with tinted background and crisp text.
  - `nxn_os_separator`: 1px hairline dividers with `tok.separator`.
* **Strict rules (checked by `python tools/design_check.py`):** an ImGui app includes `nxn_os_ui.h`, runs the frame layer (`nxn_os_frame_begin` / `nxn_os_frame_end`), clears with `nxn_os_clear_color(tok)`, never sets `io.FontGlobalScale` or `SetWindowFontScale`, adds no fonts (the kit builds the role table: Title 23 px, Card Header 18 px, Body 17 px, Caption 14-15 px at scale 1), uses the `nxn_os_*` widgets instead of raw `ImGui::Button`, `Combo`, `Checkbox`, `SliderFloat`, `InputText`, `BeginTabBar`, `ProgressBar`, and writes every pixel size as `NXN_S(px)`. Card padding is `16 x 13`; pass it with `nxn_os_card_begin_ex(id, 0, NXN_S(16), NXN_S(13), tok)` or use `nxn_os_card_begin`.
* **NXUI in a GL window:** `nxn_nxui_*` never paints in a Native OpenGL window (its own thread; only the OS main thread may use the shared renderer). The tree is still built and laid out, input is routed, and `nxn_nxui_end_ex()` returns `NXN_ERR_UNSUPPORTED`. Use ImGui with `nxn_os_ui.h` there. The four SysMatrix Studio canaries (`product/showcase/com.nexvyn.parity.*`) show the same screen in Lua, JavaScript, Python and Native C++; `tests/test_design_parity.py` keeps them identical.

### Text and fonts

Dear ImGui draws Latin-1 only unless it gets glyph ranges, so Turkish characters (dotless i, g-breve, s-cedilla, capital I-dot), Cyrillic or Greek letters show as `?`. The frame layer loads the system fonts through `nxn_imgui_add_font()` from `<nexvyn/nxn_imgui.h>` for UI apps; games and scenes without the frame layer call it themselves: it adds the ranges of the app's language, keeps the atlas small, and rasterizes UI fonts (`<= 28 px`) at `2x` atlas density (`OversampleH = 1`, `OversampleV = 1`, `PixelSnapH = true`, `RasterizerDensity = 2.0f`, `RasterizerMultiply = 1.08f`) so glyph stems and curves remain crisp without muddiness.

To strictly match script UI size and stroke weight: pass `floorf(pt * 1.21f * scale + 0.5f)` (Inter FreeType EM factor `2478 / 2048`) using `NXN_UI_FONT_BOLD` (`19.2pt`) for app titles, `NXN_UI_FONT_BOLD` (`15.2pt`) for card headers, `NXN_UI_FONT_MEDIUM` (`13.8pt`) for body/controls, and `NXN_UI_FONT_MEDIUM` (`12.0pt`) for badges/subtitles; keep `io.FontGlobalScale = 1.0f` instead of downscaling a baked atlas (rebuild on `NXN_EVENT_RESIZE` if scale changes), and round `AddText` `(x, y)` coordinates with `floorf(v + 0.5f)`. Japanese, Korean and Chinese text needs the system's CJK font, which windowed apps cannot get yet (see `NATIVE_KIT.md`, *Text and fonts*). Test your app in more than one language: `lang/*.json` plus Settings > Language.

## 6. Before you publish

- `python tools/nxv_native build <app> --clean` on a clean checkout, then `package`. No warnings left in your own code.
- Open the app, use it for a while, close it with the window button and with the app's own exit: the log ends with
  `ended`. Open and close it ten times: memory stays flat.
- Texts in `lang/*.json` (English required, any others you can), store text in English, screenshots in the English UI.


## Native UI interaction backend

Native ImGui utilities should include `nxn_os_ui.h` and use one shared input backend. After `nxn_input_poll`, call `nxn_imgui_input(backend, state, dt)` before `nxn_os_frame_begin`. Keep `nxn_imgui_input_state backend` alive for the lifetime of the ImGui context. Do not feed another platform backend or consume mouse/key/text queues a second time. The helper is header-only; it adds no host ABI imports beyond existing Native 1.1 USB input functions (use `minNative: 1.1` or newer).

```cpp
static nxn_imgui_input_state backend;
nxn_input_state state = NXN_STRUCT_INIT(nxn_input_state);
nxn_input_poll(&state);
nxn_imgui_input(backend, state, dt);
nxn_os_frame_begin(&tokens, width, height);
// nxn_os_slider, nxn_os_input, nxn_os_dropdown, buttons, child frames ...
nxn_os_frame_end();
```

The backend handles HID keyboard events, UTF-8 text, the system keyboard request, mouse buttons including short taps, wheels, mapped confirm/cancel, D-pad and left-stick focus navigation, and right-stick scrolling. Standalone libraries that do not provide USB input keep touch/gamepad input. Keyboard/gamepad sliders use normal ImGui activation and arrow adjustment; custom OS switches, tabs and list controls participate in navigation.

The frame layer supports finger dragging in the innermost scrollable child window (including raw `ImGui::BeginChild`). A drag becomes scrolling after a small movement threshold. It cancels a pending row click. Sliders and text editing retain capture. Mouse dragging keeps its usual control behavior. Existing compiled modules keep their existing headers and behavior; rebuild with the updated kit to adopt this backend.

Multi-touch UI capture follows the original finger ID, even if array indices change. Releasing that finger does not transfer its drag to a second finger. Games and gesture canvases should read all `nxn_input_touch` contacts by stable `id`; never treat the array index as identity. Reset pinch/rotation baselines when either participating ID changes. The regular UI remains a single-pointer interface; this does not make two independent ImGui widgets concurrently editable.

Script and interpreted C apps use the shared OS `ui.beginScroll` / `ui_beginScroll`, sliders and text fields. Lua, JavaScript, Python and C receive `pinch` and `rotate` events with `scale`, `angle`, local `x`/`y`, and `touch`; apply these only in a canvas or document that supports gestures. Pairing the OS renderer and a native OpenGL ImGui renderer is not supported in one frame.



## Interaction contract for every app language

An OS application uses the same theme tokens, text roles, scaled dimensions and control behavior in Lua, JavaScript, Python, interpreted C and native C++. Native utilities use `nxn_os_ui.h` with its shared input backend. Games may choose their own visual style; controls still obey capture, cancellation and stable contact identity.

| Control | Touch / mouse | Keyboard / gamepad |
|---|---|---|
| Button, switch, list row | Activate on release inside the target; a scroll drag cancels the click | Reach by focus navigation, activate with confirm |
| Slider | Keep the initial pointer until release, including outside bounds; preserve capture inside a scroll pane | Focus, activate, adjust left/right; cancel exits editing |
| Text field | Focus opens the system keyboard when needed; typing is UTF-8 | Tab/Shift+Tab focus, text and editing keys, modifiers and shortcuts |
| Scroll pane | Drag inside the deepest eligible pane; inner movement leaves the outer pane in place; mouse wheel scrolls the hovered pane | Right stick scrolls the hovered or focused pane, left stick/D-pad navigates controls |
| Gesture canvas | Pinch/rotate only where supported; track stable IDs and reset the baseline when a contact changes | Provide a reachable control for the same operation |

C source packages must pass the real-header compilation check as well as manifest/design validation. Compiler skips are reported explicitly. Native OS-look source projects that omit the shared input backend fail the design check. Rebuilding an existing native module adopts the new app-side backend; previously compiled modules keep their existing widget code. The native host supplies one coherent touch snapshot per `nxn_input_poll` and clears access while unfocused.

## Responsive interaction quality

Native ImGui OS apps forward every polled lifecycle event to `nxn_imgui_input_event(event)`
before the next frame, in addition to calling `nxn_imgui_input` once per frame. Focus loss
releases held keys and cancels touch motion. The frame layer supplies kinetic touch scrolling;
a new press stops a fast list without activating a moving row. Mouse-wheel and gamepad input
remain direct. All UI adapters use the shared header-only `nxn_scroll_physics.h` finite-stop
model; frame-rate-independent integration avoids a longer fling at a lower refresh rate.

Lifecycle-capable native apps (`minNative` 1.1 or later) can opt in with `liveResize: true`; the current app template does so explicitly. Hosts also recognize a responsive default for targets 2.0 or later. Keep `targetNative` at the SDK version actually tested; do not invent a newer SDK target to select behavior. Responsive apps receive the latest coalesced content size while resizing. Existing
`native.liveResize: false` settings and manifest opt-outs are respected; legacy apps keep the
settled path. Handle the newest size, keep UI state, and call `nxn_display_resize`; do not
recreate the ImGui context or font atlas just because the window dimensions changed. Follow
OS UI scale and text scale separately from viewport size. Native resize diagnostics report
build and request-to-compose distributions; these are not input-to-photon measurements.

OS apps preserve common tokens, typography, focus, control states and behavior across languages.
Use a compact layout when rows no longer fit; do not shrink every control to fit the window.
The Input Lab samples in all five runtime lanes stack their fields below 620 logical pixels.
Test nested scrolling, fast release/stop, keyboard focus reveal, focus loss, pinch contact
changes and resize while controls contain user input. Existing compiled app-side UI code
requires rebuilding to receive new header helpers. Games retain their own visual direction.

### Complete settings writes and recovery

Use nxn_fs_write/nxn_fs_read for whole app settings files. Both adapters share a
recoverable commit policy and serialize these helpers per app. Overwrite rename
is preferred; a filesystem rejecting overwrite uses an old-copy swap and rollback.
Helper readers can recover a missing target from its old copy after interruption;
they never accept an incomplete temporary file. Reserve .tmp and .nxn-old~ sibling
names. Raw stdio/POSIX readers are outside this lock and can observe a missing
target during fallback. No fsync or physical power-loss durability is promised.
Windowed apps receive the host change; exclusive apps must relink the SDK.
Parse the entire settings record into temporary values before applying it, as in
the app template; reject incomplete, out-of-range and trailing data.

Native streaming admission counts open handles and opens in flight together under
the existing per-app limit. NXN_ERR_LIMIT leaves the output handle null and size
zero; close a stream before retrying. File I/O runs outside the registry mutex.
This is a host fix for windowed modules; existing compiled callers need no rebuild.
It does not change stream format, cache budget, exclusive-mode services or offline
access. Closing an app still requires actual producer quiescence before reclaim.
