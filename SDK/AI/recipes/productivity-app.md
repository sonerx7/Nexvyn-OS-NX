# Productivity app

Use for a document/settings application with a native processing requirement.

## Runtime choice

Lua is the normal utility choice (24 MB/60 fps); use this native C++ recipe for substantial native processing or existing C/C++ dependencies. See script-app.md for the lighter alternative.

## Create

Run script commands from `<repo>`. Run native commands from `<kit>`, which means `SDK/Languages/c/native-kit`. `<project>` means an absolute project path and `<name>` its CMake project name. Create into an absent destination.

```text
python tools/nxv_native new native-app --template app --dir <repo>/SDK/AI/golden
```

Golden source: `SDK/Samples/c/golden/native-app/`. Creation produces the stock template; the golden contains small documented adaptations. Read its README before using it as a starting point.

## File layout and APIs

`src/main.cpp` (file picker, persisted settings, lifecycle and deferred resize), `src/imgui_gl_glue.cpp`, `CMakeLists.txt`, manifest/icon/locales. The kit supplies the widget implementation; do not vendor another copy.

`nexvyn/nexvyn_native.h`, `nxn_os_ui.h`, `nxn_ui.h`, `nxn_fs.h`, `nxn_sys.h`, `nxn_display.h`, `nxn_input.h`; `imgui.h` and `imgui_impl_opengl3.h`. Use `nxn_os_frame_begin/end`, `nxn_os_*` widgets and `NXN_S()` for pixel dimensions. Use `nxn_pick` for user-selected files and `nxn_fs_*` for app data.

Native contract: ABI v1 is frozen (`NXN_ABI_VERSION = 1`), headers are version 1.2. Use a C boundary, opaque handles and size-first versioned structs. New imports need a higher `minNative`; script `minSdk`/`targetSdk` are separate. Optional capabilities require a fallback. Modules run in-process with no memory isolation. GL core 4.3 / GLES 3.2, FBO, depth and fences are supported; shared contexts and worker-thread GL are unsupported.

## Performance budget

Utility recommendation: Lua 24 MB at 60 fps. The native golden adopts 24 MB as its own target, not an SDK allocation guarantee or a native-profile default.

These are proposed device targets, not measurements: frame work P95 <= 16.667 ms at 60 Hz; late presents <= 1%; resize request-to-present P95 <= 50 ms; launch-to-window <= 50 ms; memory growth <= ~43 KB per open/close cycle after warm-up; GPU lock wait P95 <= 5 ms. There is no guaranteed RAM allocation per app. Host or emulator results are never device measurements.

## Checklist

- [ ] From `<kit>` run `python tools/nxv_native build <project>`; require a successful exit and the checked `.nxvmod` line.
- [ ] Run `python tools/nxv_native check-win <project>/build/<name>.nxvmod` on the module produced by that successful build. Never accept an old binary after a failed build.
- [ ] Run `python tools/nxv_native check-design <project>`. This checks OS UI rules for ImGui apps; a zero-finding result on a custom GL frontend does not validate its visual design.
- [ ] Verify all eight `lang/{en,tr,de,es,fr,ja,ko,zh}.json` files, every used key and identical placeholder identities and multiplicities. Try long translations and CJK glyphs.
- [ ] Run `python tools/nxv_native package <project>`. Check that the package contains its module, icon, locales and required data/libraries. Signing covers the file manifest; Store packages may be unsigned.
- [ ] Exercise close, focus loss, suspend and resume: stop heavy work/audio, save meaningful state, join workers before teardown, reset timing and require deliberate resume for games.
- [ ] Force resize Busy: retain the old surface, retry on a later frame, update dimensions and viewport only after success. Never spin on Busy in render or audio loops.
- [ ] Test action held, pressed, released and cancellation separately; a focus/suspend/disconnect cancellation must not become a click. Poll on one input thread; re-arm keyboard/touch after release.
- [ ] Test controller, keyboard and touch in handheld and docked modes; use actual event dimensions and test minimum window size and fullscreen changes.
- [ ] Measure the proposed device budget on hardware; remove generated build/package files from source examples after verification.

## Common mistakes

Hardcoded fonts/colors/scales; bypassing the OS frame layer; file reads in draw; treating a cancelled picker as an error; losing settings on suspend; using a held cancel action as a new press every frame.

Verification evidence and limits: [golden results](../golden/RESULTS.md). The checklists above describe work to perform for a product; they are not claims of completed device or interactive testing.
