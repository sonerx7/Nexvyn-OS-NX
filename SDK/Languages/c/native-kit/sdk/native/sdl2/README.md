# SDL2 for Nexvyn OS windows

The kit's SDL2 for apps that run inside a Nexvyn OS window or full screen (`docs/NATIVE_KIT.en.md`, "SDL2 in a window").

- Base: the devkitPro Switch fork of SDL 2.28 (commit pinned by sha256 in `sdk/native/sysroot/recipes.json`, recipe
  `sdl2-nexvyn`), zlib license. Everything here is added or changed source of that fork, marked as such in each file.
- `overlay/src/{video,audio,joystick,filesystem}/nexvyn/`: the Nexvyn OS drivers. They call only `nxn_*` (display, audio,
  input, events, files), so a module built with them imports nothing outside the windowed host import set.
- `sdk/native/sysroot/patches/sdl2-nexvyn.patch`: the few core edits (driver lists, CMake block `NEXVYN_SDL`, thread
  priority left to Nexvyn OS).
- Build: `python sdk/native/sysroot/build.py sdl2-nexvyn` installs into `<sysroot>/windowed`. Only window builds
  (`nxv-native build`, `NEXVYN_WINDOWED=ON`) look there.
- Test: `sdk/native/examples/sdl2_check` (every part, report file) and `python tools/canary.py build-win imgui`.
- Audio queue: the audio driver lets SDL's audio thread run while the mixer queue holds less than 100 ms (hint
  `NEXVYN_AUDIO_LATENCY_MS`, 20 to 500, never less than two SDL buffers). It was two buffers (about 42 ms), too little for a
  game with slow frames. Every 5 s it logs `sdl audio: N buffers, M found the queue empty (underrun), queue avg X ms`.
  While the queue is above the budget the thread sleeps about as long as the mixer needs to play it down (1-20 ms), not
  1 ms at a time: a few wake-ups per buffer instead of ~1000 a second (the log line counts them). Hint
  `NEXVYN_AUDIO_POLL=1` brings back the 1 ms polling.
