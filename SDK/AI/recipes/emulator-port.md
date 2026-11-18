# Emulator port

Use for a guest CPU or machine frontend with strict frame-time slices.

## Runtime choice

Native C++ for bounded guest CPU execution and explicit memory ownership; start with an interpreter.

## Create

Run script commands from `<repo>`. Run native commands from `<kit>`, which means `SDK/Languages/c/native-kit`. `<project>` means an absolute project path and `<name>` its CMake project name. Create into an absent destination.

```text
python tools/nxv_native new native-emu --template emu-skeleton --dir <repo>/SDK/AI/golden
```

Golden source: `SDK/Samples/c/golden/native-emu/`. Creation produces the stock template; the golden contains small documented adaptations. Read its README before using it as a starting point.

## File layout and APIs

`src/cpu.h`, `src/cpu.cpp` (toy ISA and overflow-safe memory checks), `src/main.cpp` (500-instruction slices), `src/window.h`, `CMakeLists.txt`, manifest/icon/locales. This is a toy interpreter, not a port of a real machine.

`nexvyn/nexvyn_native.h`, `nxn_app.h`, `nxn_display.h`, `nxn_event.h`, `nxn_input.h`. Optional `nxn_jit.h`, `nxn_sys.h` (threads), `nxn_audio.h` for a later core. The golden deliberately removes the obsolete platform JIT placeholder and stays interpreter-only.

Native contract: ABI v1 is frozen (`NXN_ABI_VERSION = 1`), headers are version 1.2. Use a C boundary, opaque handles and size-first versioned structs. New imports need a higher `minNative`; script `minSdk`/`targetSdk` are separate. Optional capabilities require a fallback. Modules run in-process with no memory isolation. GL core 4.3 / GLES 3.2, FBO, depth and fences are supported; shared contexts and worker-thread GL are unsupported.

Optional JIT scope is LIMITED and was proven on host/emulator only, not measured on device: 1–64 RW/RX buffers, <=256 MiB total, admitted against free heap, opt-in `native.windowedJit` per the facts. Always keep the interpreter fallback. Join executing workers before rewriting/destroying published code. Heap-block whole-page guards are limited to 32 ranges. Data-abort handling is limited: no SIMD/FPCR/x17 edits, no arbitrary fault recovery or sandbox promise. Threads/TLS/mutex/condition variables are supported. No JIT is enabled or claimed by this golden.

## Performance budget

Emulator profile: 256 MB, 60 fps. Slice guest work; a guest must never run an unbounded loop on the UI/render thread.

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

Assuming precise VM reserve/commit/decommit exists (unsupported); relying on guards as a sandbox; treating arbitrary faults as recoverable; executing malloc memory; rewriting published code while workers can execute it; integer overflow in guest address bounds.

Verification evidence and limits: [golden results](../golden/RESULTS.md). The checklists above describe work to perform for a product; they are not claims of completed device or interactive testing.
