# Porting a large PC game or engine

How to bring a big existing PC program to Nexvyn OS as a native windowed app (Native SDK, SDK 1.10 and later). The
running example is a statically recompiled Windows strategy game from the early 2000s: the original program was turned
into C, compiled for the console, and runs against a small *host layer* that fakes the Win32 and DirectDraw calls on
top of the `nxn_*` API. Everything below was measured on that port; the same rules hold for any large port.

Read first: [Native SDK guide](NATIVE_GUIDE.md), [kit reference](NATIVE_KIT.md), [compatibility layer](NATIVE_COMPAT.md).

## 1. The shape of the port

```
original game code (recompiled C)  ->  host layer (Win32 / DirectDraw shims)  ->  nxn_* API  ->  Nexvyn OS window
```

- The game code is never edited by hand. Fixes go into the host layer, so a new build of the recompiler output drops in.
- The host layer implements only the imports the game really uses. List them first; implement the hot ones properly and
  stub the rest with a log line, so you see when they are called.
- One window, one process: no `fork`, no child processes. Turn helper programs into functions or threads.

## 2. Stay alive while loading

A big game loads for 20 seconds or more on the main thread, with no event loop. Nexvyn OS then thinks the window is
frozen and asks "not responding" after 5 seconds. Fix it in two ways:

- **Poll events.** Call `nxn_should_quit()` (it pumps events and counts as "alive") at least every 250 ms while
  loading. Put the call where the game already yields: its `Sleep` shim, its wait-for-event loop, and any yield hook
  the recompiler offers. Do not call it on every lock operation: the hot path gets slower for nothing.
- **Declare it.** From SDK 1.13 (Nexvyn OS 1.2.4) add `"loadingHint": true` to `app.json`. The not-responding dialog
  then waits 120 s instead of 5 s. Older systems ignore the field, so keep the event polling too. If the user picks
  *Wait* in the dialog, it stays quiet for 60 s and until the app answers once.

A user who closes the window during the load must still get out: `nxn_should_quit()` turns true, and your entry must
return within 5 seconds. Check the flag between load steps and exit early.

## 3. Memory

- `malloc`, `free`, `realloc`, `memalign` come from the app's own heap (apps with `"minNative": "1.1"` or later). The
  heap grows while the system has free memory, and `malloc` returns `NULL` when only the OS reserve is left
  (default 64 MB, setting `native.memoryReserveMB`). There is no fixed per-app cap.
- Large games ship their own C runtime heap (`malloc` / `free` inside the recompiled code). Route those functions to the
  host's `malloc` / `free` with a shim. The game's heap then lives in the app's heap, is freed in one step on exit, and
  its lock and last-error calls are no longer on the hot path.
- Put the real need in `app.json` as `"memory"` (MB). If that much is not free at start, the user sees "needs X MB,
  Y MB are free; close some open apps" instead of a crash later.
- Check every allocation result. A failed allocation must end in a clear message, not a null write.
- Memory the C library allocates itself (`fopen`, `asprintf`) is outside the app's heap and is not counted.

## 4. Presenting frames

The game draws into a software surface (an 8-bit palette or 16-bit buffer) and calls the shim's "flip". What the flip
costs decides the frame rate:

- **No avoidable whole-frame copies.** Draw into the buffer the host will upload; do not convert and copy it again.
- **Convert once, not per pixel in a slow loop.** Palette to RGB565 or RGBA with a 256-entry table, and only when the
  palette changes. Work in 32-bit words and keep the loop easy to vectorize.
- **Dirty rectangles.** The shim knows which regions the game touched (blit, fill, lock / unlock). Convert and upload
  only those; a strategy game's sidebar and map change in small parts.
- **Vsync off in the port.** Do not wait for vsync in the game thread (`SDL_RENDERER_PRESENTVSYNC` makes the game logic
  wait on every present). Nexvyn OS already paces the window's frames. `SDL_GL_SetSwapInterval(0)` and
  `SDL_RenderSetVSync(r, 0)` both succeed.
- **No extra render passes.** In full screen skip the border bands, and at 1x scale straight from the frame to the window
  with a linear filter instead of going through an intermediate target.
- Audio: queue sound from the game thread; the calls never block on the OS main thread.

## 5. Threads and priorities

- The OS keeps one core free for itself. Plan for the cores the app gets. A recompiled game usually runs its logic on
  one thread: give audio mixing, file streaming and decoding their own threads and keep the game logic on one.
- Thread priority is limited, and `SDL_SetThreadPriority` does nothing. Never rely on priorities for correctness.
- **Never block while holding a lock the OS main thread also takes** (SDL, GL, memory, the log). A worker that holds a
  shared lock and waits on I/O freezes the desktop. Hold locks for a few instructions, never across file or network I/O.
- Calls that need the OS main thread (pickers, permission requests, saves) make your thread wait, but the app still
  counts as alive. Put them on a worker thread so the game keeps drawing.
- After adding a thread, run the open / close test (see [Test workflow](TEST_WORKFLOW.md)): ten opens and closes in
  a row, no hang, no growing memory.

## 6. File access

- The SD card is slow compared to a PC disk, and the OS shares it. Never read files per frame. Load assets at level or
  menu boundaries, behind a progress screen that keeps polling events.
- Read big archives in large sequential chunks (256 KB to 1 MB), not 4 KB at a time. Many recompiled games make tiny
  `fread` calls: put a buffered reader (`setvbuf` with a large buffer, or a read-ahead cache) in the shim.
- Cache directory listings once; never scan folders in the frame loop.
- Keep save files small and write them on a worker thread, through a temp file and a rename.
- The log shows the read speed at module load (`module load ... MB/s`); compare it with your own read loop.

## 7. Input

Map to what the user holds: a Joy-Con pair, a single Joy-Con, a controller, and the touch screen. The game expects a
mouse and a keyboard, so the host layer has to provide them:

- **Touch:** a tap is a left click, a long press is a right click, a two-finger drag scrolls the map. Move the cursor to
  the touch point first, then press, or the game sees a click in the wrong place.
- **Stick:** moves a software cursor with acceleration; one button is left click, another right click. Draw the cursor
  yourself if the game hides the system one.
- **D-pad and shoulder buttons:** map to the game's keyboard shortcuts (camera groups, hotkeys); show the mapping in
  the app's menu.
- Read input once per frame from the `nxn_input_state` snapshot or the event queue; do not poll devices on a second thread.

## 8. Measure the right way

- Test on the PC emulator with the **console profile**: limit it to four cores, a CPU cap and a lower priority, keep the
  GPU load at console level (1x resolution), and measure handheld and docked separately. See
  [Test workflow](TEST_WORKFLOW.md). Emulator numbers are for before / after comparisons under the same profile.
  They are never console numbers.
- Read `System/Logs/system.log`:
  - `nxwin: <id>: <n> fps, ...` is the window's frame rate over a few seconds; 0 while loading means the app drew nothing.
  - `nxwin: <id> is not responding (x s silent)` means no event poll or frame for that long: find the loop that lacks
    `nxn_should_quit()`.
  - `stall` lines list the longest parts of a slow frame (threshold 150 ms, setting `perf.stallMs`).
  - `nxwin: <id>: module load ...` gives read speed and link time of the module.
  - `stats` lines (autorun command `stats`) give memory, windows and resources, for leak checks.
- Find the hot function by sampling: a cheap heartbeat in the host (print the current function address every 2^19 or
  2^20 loop turns) gives a histogram. In the case study, 90 samples put most of the load in the game's own heap and
  lock functions: the real cost of loading was the heap, not the disk. Turn the heartbeat off in the release build.
- Write down every measurement: profile, cores, resolution, handheld or docked, version.

## 9. Packaging

- `app.json`: `"main": "<name>.nxvmod"`, `"minNative": "1.1"`, `"minSdk": "1.10"` (`"1.13"` if you use `loadingHint`),
  `"targetSdk"`, `"memory"`, the permissions the port really needs, and `"loadingHint": true` for long loads. The full
  list is in [Package format](NXVAPP_FORMAT.md).
- The module carries the **ABI generation** it was built for. The generation is raised by hand only when the module
  interface really breaks; a module built for generation N loads on every system that has N. Rebuild with the kit that
  matches the system you target, and check that a module built with the previous kit still opens.
- The package holds the module, icon, `lang/*.json`, the licence files and a source link. It never holds the game's data.
  Large packages install slowly (a 55 MB package took about 3.5 seconds to unpack): let the first launch wait for the
  install to finish.
- Keep the package small: compress what compresses, strip debug info, ship no unused tools.
- Run `nxv-native check` on the module and `python SDK/Tools/nxv/nxv.py check <folder>` on the bundle before the pull request.

## 10. Licensing and game data

- The user supplies the game data. A port package must never contain the game's files, BIOS, firmware or system files.
  The app asks for the game folder on first start (a picker), remembers it, and shows a clear message when files are
  missing.
- A free replacement data set may ship if its licence allows redistribution, together with that licence.
- Every port ships its own licence file and a link to its source (and to the original project, if any), in the package
  and in the Store text. Put the licence of every library you link in `licenses/`.
- Your host layer is a separate piece of work: publish its source under a compatible licence with the port.
- Do not use the original game's name, art or sound in the icon or screenshots unless you have the right to. Use a
  neutral description such as "a recompiled strategy game", and your own key art.

## Checklist

- [ ] `nxn_should_quit()` at least every 250 ms in every long loop; `loadingHint` set
- [ ] game heap routed to host `malloc` / `free`; `memory` field set
- [ ] vsync off in the port; dirty rectangles; no extra passes
- [ ] no lock held across I/O; open / close test ten times
- [ ] reads in large chunks, nothing per frame
- [ ] touch, controller and Joy-Con mapped; mapping shown in a menu
- [ ] measured with the console profile; numbers written down with the profile
- [ ] licence files, source link, no game data in the package
