# Third-party components

Nexvyn OS is distributed under the **GPL-3.0-or-later** license (see [LICENSE](LICENSE)). The components below are linked into the Nexvyn OS binary (`NexvynOS.nro`); all of them have licenses compatible with GPLv3.

| Component | License | Use |
|---|---|---|
| libnx (switchbrew) | ISC | Switch system services |
| Mesa 20.1 (devkitPro `switch-mesa` 20.1.0, nouveau) | MIT | OpenGL / OpenGL ES and EGL for the desktop and native apps |
| Mesa NVK Vulkan driver (Mesa 26.2.4 tree, commit `0ff52079`) | MIT | Vulkan for native apps and ports (on by default when the driver check passes), since 1.4.0 |
| Expat 2.10.0 | MIT | XML parser used by the NVK driver |
| SDL2, SDL2_image, SDL2_ttf, SDL2_mixer | zlib (devkitPro package may include LGPL components) | Windowing, rendering, audio |
| SDL2 (devkitPro Switch fork with Nexvyn OS window drivers) | zlib (altered source: `sdk/native/sdl2`, `sdk/native/sysroot/patches/sdl2-nexvyn.patch`) | Native kit: SDL2 in windows |
| SDL3 (devkitPro Switch fork `switch-sdl-3.4` with Nexvyn OS window & Vulkan GPU drivers) | zlib (altered source: `sdk/native/sysroot/patches/sdl3-nexvyn.patch`) | Native kit: SDL3 & GPU API in windows |
| FFmpeg (devkitPro `switch-ffmpeg`) | GPL | Video / audio decoding |
| dav1d | BSD-2-Clause | AV1 decoding |
| libcurl | curl (MIT style) | HTTP(S), FTP |
| mbed TLS | Apache-2.0 | Encryption |
| minizip / zlib | zlib | Zip archives |
| Lua 5.4 | MIT | Application language |
| QuickJS-ng | MIT | JavaScript engine (single patch: `JS_ReadRegExp` registers to the object reference table, `lib/quickjs/quickjs.c`) |
| wasm3 (`lib/wasm3`, commit 28ecb9af6d2040e474a70f7cb7f43666740141fb = v0.9.1-beta.1 + 18, Steven Massey, Volodymyr Shymanskyy) | MIT (`lib/wasm3/LICENSE`) | Browser's `WebAssembly` support (`web.wasm`) / browser WebAssembly engine; only interpreter core included (no `m3_api_*`, extensions, or platforms), custom file `lib/wasm3/source/nexvyn_shim.c` and `nexvyn_shim.h`, feature flags in Makefile (`W3DEFS`), details in `lib/wasm3/README.nexvyn` |
| pocketpy 2.2.0 (`lib/pocketpy`) | MIT | Python interpreter |
| CPython 3.12.16 (`tools/build_cpython.sh`, Python Software Foundation) and standard library (`romfs/System/Python3/lib.zip`) | PSF-2.0 (Python Software Foundation License Version 2; GPL-compatible) | `"python3"` runtime; changes marked "Nexvyn OS" in `tools/cpython_tool.py`. Includes bundled HACL* (MIT/Apache-2.0) and BLAKE2 (CC0) code |
| Squirrel 3.2 (`lib/squirrel`, Alberto Demichelis) | MIT | Squirrel runtime (SDK 1.5); marked change in `sqvm.cpp` |
| TinyCC 0.9.28rc (`lib/tinycc`, Fabrice Bellard and contributors) | LGPL-2.1-or-later | Compiles C apps in console (SDK 1.5); marked `__SWITCH__` changes in `tccrun.c` and `tcc.h`, marked "Nexvyn OS" changes in `libtcc.c` and `tccasm.c` (file access control, inline assembly rejection), custom `config.h` |
| miniJVM 2.2.0 (`lib/minijvm`, Gust) | MIT (C sources) | Java runtime (SDK 1.5); marked `__SWITCH__` changes |
| miniJVM class library `romfs/System/Java/minijvm_rt.jar` | GPLv2 + author's binary jar exception | Shipped as-is from version 2.2.0 jar |
| stb_image | MIT / Public Domain | Image decoding |
| ufbx 0.23.1 (`lib/ufbx`, Samuli Raivio) | MIT (or Public Domain, `LICENSE`) | `.fbx` 3D model loading (SDK 1.8, `g3d.model`), unmodified |
| cgltf 1.15 (`lib/cgltf`, Johannes Kuhlmann) | MIT (`LICENSE`) | `.gltf` / `.glb` 3D model loading (SDK 1.8, `g3d.model`), unmodified; custom `cgltf_impl.c` |
| libusbhsfs (ISC build) + FatFs | ISC + FatFs license | USB mass storage |
| NTFS-3G (Tuxera), lwext4 (Grzegorz Kostka) | GPLv2+ (NTFS-3G), GPLv2-only (lwext4) | Optional extended USB build only (`tools/build_usbhsfs.sh GPL`, `docs/USB.md`); not in the default or released build. lwext4 is GPLv2-only and not compatible with GPL-3.0-or-later, so the extended build is for local testing only and is never distributed |
| libretro API header | MIT | Retro core interface |
| eSpeak NG 1.52.0 (`lib/espeak-ng`, Reece H. Dunn, Jonathan Duddington and contributors) + ucd-tools | GPL-3.0-or-later (Unicode data: Unicode license, `COPYING.UCD`) | Text-to-speech (TTS) and Screen Reader; synthesizer only, custom `config.h`, `Makefile` and `src/include/compat/endian.h` |
| Inter, JetBrains Mono | SIL OFL 1.1 | Fonts |
| Pixel Operator | CC0 1.0 | Pixel font (Classic theme) |
| Material Symbols / Icons | Apache-2.0 | Icons |

## SDK 1.5 runtimes

- **TinyCC (LGPL-2.1):** Linked statically. LGPL-2.1 requires that users can modify the library and relink the application: the Nexvyn OS source code (TinyCC sources and marked changes in `lib/tinycc`) provides this. In a closed-source distribution, object files must also be provided.
- **miniJVM:** C sources are MIT. `minijvm/java` sources are GPLv2; the author states that the `minijvm_rt.jar` binary shipped with the release can be used without the GPL's copyleft (`LICENSE` file in repository). Nexvyn OS distributes this jar unmodified.
- **Squirrel (MIT)** and Java SDK `sdk/java` (Nexvyn OS, GPL-3.0-or-later).

## CPython

- **PSF-2.0:** The Python Software Foundation License is GPL-compatible and requires a summary of changes: CPython 3.12.16 is built for newlib + libnx; changes are in `tools/cpython_tool.py` (paths, random numbers, time zone names) and `lib/cpython/pyconfig_switch.h`. License text: `LICENSE` in the source archive (<https://docs.python.org/3.12/license.html>).

## Data

| Data | Source | License | Use |
|---|---|---|---|
| `romfs/System/Keyboard/words_tr.txt`, `words_en.txt`, `words_de.txt`, `words_fr.txt`, `words_es.txt` | [FrequencyWords](https://github.com/hermitdave/FrequencyWords) (Hermit Dave), OpenSubtitles 2018 frequency lists | CC BY-SA 4.0 (content), MIT (code) | On-screen keyboard word suggestions |
| `romfs/System/Speech/espeak-ng-data` (phontab, phonindex, phondata, intonations, `en`/`tr`/`de`/`fr`/`es`/`ja`/`ko` dictionaries, `lang/` files) | [eSpeak NG 1.52.0](https://github.com/espeak-ng/espeak-ng/releases/tag/1.52.0): compiled data from the official release MSI (`espeak-ng.msi`), `lang/` files from the source archive (`gmw/en-US` stored in lower-case as `en-us`) | GPL-3.0-or-later | Text-to-speech voices |

The lists are generated by `tools/gen_wordlist.py`: the 20,000 most frequent Turkish words and the 15,000 most frequent English, German, French, and Spanish words, letters only, vulgar words removed. The German, French, and Spanish lists are also filtered with the LibreOffice Hunspell dictionaries (used only as a filter; nothing is copied from them). This adapted data is also under CC BY-SA 4.0, which is one-way compatible with GPLv3 (Creative Commons, 2015).

The voice data is copied unchanged; its source (`phsource/`, `dictsource/`) is in the eSpeak NG 1.52.0 source archive. Chinese (`cmn_dict`, 1.5 MB) is omitted due to its size.

## Optional: retro cores

They are built and linked with `tools/build_retro_cores.sh`; only GPLv3-compatible cores were selected.

| Core | System | License |
|---|---|---|
| FCEUmm | NES | GPL-2.0-or-later |
| SameBoy | Game Boy / Color | MIT |
| mGBA | Game Boy Advance | MPL-2.0 |
| Supafaust (Mednafen) | SNES | GPL-2.0-or-later |
| ClownMDEmu | Mega Drive / Genesis | AGPL-3.0-or-later (combinable under GPLv3 §13) |
| BlastEm (fallback) | Mega Drive / Genesis | GPL-3.0 |

Not used: cores with "non-commercial" licenses (Snes9x 2010, Genesis Plus GX, PicoDrive) and GPLv2-only cores (Gambatte). These cannot be combined with GPLv3.

## Native SDK kit

The Native SDK kit (`sdk/native/`) includes the following UI library for developers' apps.

- **Dear ImGui** 1.91.5 (`sdk/native/sysroot/vendor/imgui/`) — MIT License, Copyright (c) 2014-2024 Omar Cornut. https://github.com/ocornut/imgui

Sysroot libraries (built as static libraries by `sdk/native/sysroot/build.py`; the kit archive includes the source version and license file):

- **zstd** 1.5.6 — BSD-3-Clause (Meta Platforms). https://facebook.github.io/zstd/
- **Expat** 2.10.0 — MIT. Nexvyn OS 1.4.0 and later also link it for the NVK driver. The kit carries the [upstream license](https://github.com/libexpat/libexpat/blob/a70841d9ffa64ddde29ab824ed6305035ebe4c47/expat/COPYING) at `licenses/expat/COPYING`.
- **LZ4** 1.10.0 (library) — BSD-2-Clause (Yann Collet). https://lz4.org/
- **SQLite** 3.47.2 — Public Domain. https://www.sqlite.org/
- **libarchive** 3.7.7 — BSD-2-Clause (Tim Kientzle and contributors). https://libarchive.org/
- **OpenAL Soft** 1.23.1 — LGPL-2.0-or-later (Chris Robinson and contributors). https://openal-soft.org/ — static linking note: `docs/NATIVE_KIT.*`.
- **GNU libiconv** 1.17 (library) — LGPL-2.1-or-later (Free Software Foundation). https://www.gnu.org/software/libiconv/ — static linking note: `docs/NATIVE_KIT.*`.
- **pixman** 0.43.4 — MIT. https://www.pixman.org/
- **GLib** 2.78.6 (glib, gobject, gthread, gmodule) — LGPL-2.1-or-later (GNOME Project). https://www.gtk.org/ — static linking note: `docs/NATIVE_KIT.*`.
- **PCRE2** 10.44 (GLib dependency) — BSD-3-Clause, with the PCRE2 exception (Philip Hazel). https://github.com/PCRE2Project/pcre2
- **libffi** 3.4.6 (GLib dependency) — MIT (Anthony Green, Red Hat and contributors). https://libffi.github.io/

The small helper sources in the sysroot (`sysroot/shims/`, `sysroot/vendor/proxy-libintl/`, `sysroot/patches/`) are the Nexvyn project's own code (GPL-3.0-or-later); the patches only make small changes to files that stay under their respective library's own license.

## Separate programs

Homebrew apps that Nexvyn OS can download and install (CorkDeck, Autorun, Moonlight, etc.) are **not** linked into Nexvyn OS; they run as separate programs under their own licenses.

## YamaNX

`romfs/Applications/yamanx.app` is a Lua port of YamaNX to Nexvyn OS. Original: **YamaNX by SertAy**, https://github.com/sertay1/YamaNX. It ships as a separate program under its own license (SertAy, non-commercial use, attribution required) and is not linked into the Nexvyn OS code. License text and list of modifications: `yamanx.app/LICENSE`, `yamanx.app/NOTICE.md`.

## three.js (browser WebGL test page)

`romfs/Applications/browser.app/test/three.min.js` is three.js r149 (official build), MIT License, Copyright 2010-2023 three.js authors, https://github.com/mrdoob/three.js. It is only the test page `webgl_cube.html` of the built-in browser; the license text is in the header of the file.
## Ports (App Market)

These three programs are installed on their own from the App Market; they are not linked into Nexvyn OS. Each package carries its own licence texts (`data/licenses/`) and source links. No commercial game data, BIOS or firmware is included.

| Component | License | Source |
|---|---|---|
| **Chocolate Doom** 3.1.0 (`Store/Games/action/chocolate-doom`) | GPL-2.0-or-later | https://github.com/chocolate-doom/chocolate-doom (tag `chocolate-doom-3.1.0`); Nexvyn OS patches in the package `data/licenses/patches/` |
| **Freedoom** 0.13.0, `freedoom1.wad` (in the Chocolate Doom package) | BSD-3-Clause | https://github.com/freedoom/freedoom (v0.13.0) |
| **Ironwail** 0.8.0 (`Store/Games/action/ironwail`) | GPL-2.0-or-later | https://github.com/andrei-drexler/ironwail (commit `08d578136ff4`) |
| **LibreQuake** v0.09-beta lite (in the Ironwail package) | BSD-3-Clause (`progs.dat`, `pop.lmp`: GPL-2.0) | https://github.com/lavenderdotpet/LibreQuake |
| Tremor (libvorbisidec) and libogg (linked into Ironwail only) | BSD-3-Clause | https://gitlab.xiph.org/xiph/tremor , https://gitlab.xiph.org/xiph/ogg |
| **mGBA** 0.10.5 (`Store/Games/arcade/mgba`) | MPL-2.0 (unmodified) | https://github.com/mgba-emu/mgba (tag `0.10.5`) |
| blip_buf (inside mGBA) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (inside mGBA) | BSD-3-Clause | https://github.com/benhoyt/inih |
| mGBA project icon (`res/mgba-1024.png`, store icon of the mGBA package) | MPL-2.0 (scaled) | https://github.com/mgba-emu/mgba/tree/master/res |
| **FCEUmm** (libretro, `Store/Games/arcade/fceumm`) | GPL-2.0-or-later (unmodified; copyright Xodnizel and contributors) | https://github.com/libretro/libretro-fceumm (commit `e0f3086a8104`) |
| **Gambatte** (libretro, `Store/Games/arcade/gambatte`) | GPL-2.0-only (unmodified; copyright Sindre Aamas and contributors) | https://github.com/libretro/gambatte-libretro (commit `77f2567d718b`) |
| **Genesis Plus GX** (libretro, `Store/Games/arcade/genesis-plus-gx`) | Custom non-commercial licence (copyright Charles MacDonald, Eke-Eke, MAME team); package is free | https://github.com/libretro/Genesis-Plus-GX (commit `b9c231644197`) |
| **Snes9x** (libretro, `Store/Games/arcade/snes9x`) | Custom non-commercial licence (copyright Gary Henderson, Jerremy Koot and contributors); package is free | https://github.com/libretro/snes9x (commit `fae2fea08f74`) |

These four cores are separate programs installed on their own, not linked into the OS; each package shows its licence text, source link and copyright holders on its About page. Frontend and port: sonerx7, GPL-3.0-or-later.

SDL2 and SDL2_mixer (zlib) are linked into these port apps only, in their own packages.

## Runtimes & Libraries (App Market)

Components in the App Market's "Runtimes & Libraries" category are not linked into `NexvynOS.nro`; they are separate packages the user installs. Each one carries its own licence text (`LICENSE` / `COPYING`) in its package and its SPDX licence and source link on its card; they are not added to this file, they stay with their own package. No component is listed at the moment.
