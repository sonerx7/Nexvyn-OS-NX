# Toolchain files

Needs devkitPro with `switch-dev` (devkitA64, libnx, switch-tools) and the portlibs you use (`switch-sdl2`, ...).
Versions are pinned in `tools/toolchain.json`; `nxv-native doctor` checks them.

- `nexvyn-switch.cmake`: CMake toolchain file (C11, C++17, -O2, exceptions + RTTI on). Wraps devkitPro's `Switch.cmake`.
- `nexvyn-native.cmake`: `nexvyn_add_nro(target TITLE AUTHOR VERSION ICON ROMFS)` builds the .nro (elf2nro + nacptool).
  `-DNEXVYN_ABI=ON` links `<nexvyn/nexvyn_native.h>` / `-lnexvyn_native` once the ABI kit exists.
- `nexvyn-switch.meson.ini`: Meson cross file (builds the ELF; package it with elf2nro).

Manual use: `cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=toolchain/nexvyn-switch.cmake && cmake --build build`
inside the devkitPro shell. `python tools/nxv_native` does this for you from any shell.
