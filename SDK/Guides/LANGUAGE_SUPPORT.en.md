# Nexvyn OS — New language support: research and decisions (SDK 1.5)

[Türkçe](LANGUAGE_SUPPORT.tr.md) · **English**

This document summarizes the research done and the decisions made so that `.nxvapp` apps can be written in languages
other than Lua / JavaScript / Python (pocketpy). The earlier feasibility decisions come from an internal evaluation (C3
TinyCC, C4 Java postponed, pocketpy instead of MicroPython). This work revisited those decisions and added three new
runtimes: **Squirrel**, **C (TinyCC)** and **Java (miniJVM)**. On the Python side, a system library was added to
pocketpy instead of moving to CPython.

## 1. Summary table

| Language | Option | License | Status | `app.json` `"runtime"` |
|---|---|---|---|---|
| Python | pocketpy 2 (existing) + `romfs:/System/Python` system library | MIT | **Available**, extended | `"python"` |
| Python | CPython 3.12 static build (`tools/build_cpython.sh`) | PSF | **Added in 1.0.0** (the plan in section 3 was carried out; console test pending) | `"python3"` |
| Python | MicroPython | MIT | Rejected (pocketpy is more compatible, no Switch port) | — |
| C | TinyCC 0.9.28rc (compiled on the console, JIT memory) | LGPL-2.1 | **Added** | `"c"` |
| C++ | Full compiler | — | Not realistic (clang/gcc are tens of MB, builds take seconds) | — |
| C++-like | Squirrel 3.2 | MIT | **Added** (C++-like syntax, classes) | `"squirrel"` |
| C++-like | AngelScript / ChaiScript | zlib / BSD-3 | Evaluated, Squirrel chosen | — |
| Java | miniJVM 2.2.0 (interpreter, Java 8 class files) | MIT (C), runtime jar GPLv2 + author's exception | **Added** | `"java"` |
| Java | JamVM, Avian, CACAO | GPLv2 / ISC / GPLv2 | Rejected (unmaintained, need the GNU Classpath or OpenJDK class library) | — |
| Other | Wren, Berry, Janet, Fennel, Teal | MIT | Evaluated; easy to add later thanks to the shared layer | — |

## 2. Shared architecture: one SDK implementation, thin language bindings

The three existing runtimes bind every SDK function separately (~2500 lines each). For the new languages a
language-independent layer was written first: `source/runtimes/nxvrt.h/.cpp/_api.cpp`.

- `nxvrt::Value`: nil, bool, number, string, list, dict, callback (function reference), mesh.
- `nxvrt::api()`: every SDK function (`gfx`, `ui`, `g3d`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`,
  `timer`, `TR`) written once, with the same behaviour as the Python runtime.
- `nxvrt::ScriptApp`: the app lifecycle (load/update/draw/event/menu/close, SDK 1.4 callbacks, timers, asynchronous
  results, store, Quick Search, the error screen, the 3-second limit).

Adding a language now only means value conversion plus a few virtual functions (Squirrel ~450, Java ~250 lines of
C++). The rules are the same as Python's: 0-based indexes, several results as a list (`[w, h] = gfx.size()`),
asynchronous calls take callbacks, `ui.textfield` returns the text and `ui.submitted(id)` reports Enter.

## 3. Python: CPython or pocketpy?

### Existing ports
- **PyNX / nx-python**: a CPython 3.5 port that runs `main.py` from hbmenu; last release 0.6.0-alpha (August 2019),
  threads and the `signal` module were missing, and the project is unmaintained. Sources:
  <https://github.com/nx-python/PyNX>, <https://gamebrew.org/wiki/PyNX_Switch>, <https://nx-python.readthedocs.io/>.
- **Ren'Py Switch port** (based on Python 2.7, statically linked): archived. Source:
  <https://lemmasoft.renai.us/forums/viewtopic.php?p=530030>.
- **MicroPython**: no Switch port for devkitPro could be found. pocketpy offers broader Python 3 syntax (f-strings,
  `match`, classes, decorators), so the earlier decision stands.

### What moving CPython 3.x to devkitA64 would take
1. **Cross-compiling**: `configure --host=aarch64-none-elf` does not know newlib; `pyconfig.h` has to be written by
   hand (`HAVE_FORK`, `HAVE_DLOPEN`, `HAVE_MMAP`, signals, `getpwnam`, subprocesses off). PyNX did this with patches
   for 3.5; for 3.12+ every extension module has to be listed statically in `Modules/Setup.local`, and
   `_posixsubprocess`, part of `_socket`, `mmap`, `_ctypes` (libffi on aarch64 bare metal) and `_ssl` (mbedtls cannot
   stand in for OpenSSL) have to be removed.
2. **Size** (estimate, aarch64 with `-Os` and strip): `libpython3.x.a` ~4–6 MB of code; the pure-Python standard
   library ~8–12 MB as a compressed zip (without the test packages), a minimal subset ~3 MB. Embedded in the NRO this
   grows romfs, so distributing it as a separately downloadable package through the package manager (`nxvpkg`) is
   recommended.
3. **Memory**: an empty interpreter takes ~8–15 MB and grows with every imported module. With the 64 MB per-window
   limit, several CPython apps at once are hard; subinterpreters (PEP 684, 3.12+) could give every window its own
   state.
4. **Time limit**: the 3 seconds per callback can be enforced with `PyErr_SetInterrupt` / `Py_AddPendingCall`.
5. **Effort**: too large to finish reliably in one session (patching + testing, trying on the device), so it was not
   done in this release.

### What was done: extending pocketpy compatibility
`import x` now looks for modules not found in the bundle in `romfs:/System/Python/x.py`. The added modules implement
the CPython APIs within the subset pocketpy supports, and were tested by comparing their results with CPython:
`itertools`, `string` (constants, `capwords`, `Template`), `textwrap`, `copy`, `statistics`, `base64`, `colorsys`.
`python tools/py_check.py` also checks these files for console compatibility.

## 4. C: compiling on the console with TinyCC

- **TinyCC** (<https://repo.or.cz/tinycc.git>, mob branch 0.9.28rc, LGPL-2.1): has an arm64 code generator and compiles
  in memory with `libtcc`. All the `.c` files of an app are compiled in a few hundred milliseconds when the window
  opens.
- **JIT memory**: libnx `jitCreate` offers two paths: `svcSetProcessMemoryPermission` and [4.0.0+]
  `svcCreateCodeMemory` / `svcControlCodeMemory` (one view RW, the other R-X). Source:
  <https://switchbrew.github.io/libnx/jit_8h.html>, SVC table <https://switchbrew.org/w/index.php?diff=4091>. After
  5.0.0, `svcControlCodeMemory` fails when called from the same process; Atmosphère relaxes this for homebrew with a
  kernel patch ("kernel patches for JIT support", Atmosphère changelog:
  <https://git.nold.in/nold/Atmosphere/raw/commit/be772b40e1f12680597c4ad27548c9c08d7d877a/docs/changelog.md>). The
  homebrew loader reports the available system calls with `envIsSyscallHinted(0x4B/0x4C)`; without that hint Nexvyn OS
  shows a clear error.
- **Why our own mapping code**: TinyCC accesses global data PC-relative (`adrp`, ±4 GB). libnx `jitCreate` puts the RW
  and RX views at independent random addresses; the distance between them can exceed 4 GB. Nexvyn OS maps a single
  CodeMemory object as RW and RX **side by side** and uses TinyCC's "two views" path written for SELinux
  (`tcc_relocate_ex(rx, rw - rx)`).
- **Changes made to TinyCC** (marked, 4 of them): no `sys/mman.h`; `protect_pages` does nothing on the Switch (cache
  maintenance happens on the JIT side); the RW–RX distance is 64-bit; path lists are separated with `;` (`romfs:/`
  device names contain `:`).
- **SDK**: `romfs:/System/C/include/nexvyn.h` (the Lua/Python SDK with underscores: `gfx_rect`, `ui_button`...) and a
  small libc bound to newlib (`stdio.h`, `stdlib.h`, `string.h`, `math.h`, `ctype.h`...). `malloc` is counted (64 MB),
  `printf` writes to the app's log. arm64 `long double` arithmetic is linked from libgcc.
- **Limits**: native code is not sandboxed and an endless loop cannot be stopped, so third-party C apps ask the user
  once on their first launch (`apps.trustedC`). Running in the emulator (Ryujinx) depends on its CodeMemory support.
- **License**: with static linking, LGPL-2.1 requires that the user can modify the library and relink. Since the source
  code is open (once the project is made public) this condition is met; a closed-source distribution would also have
  to ship the object files (`THIRD_PARTY_NOTICES.md`).

## 5. C++ options

Running a real C++ compiler (clang/gcc) on the console is not realistic because of size (tens of MB), memory and
compile time. Scripting languages close to C++ were examined:

| Language | License | Pros | Cons |
|---|---|---|---|
| **Squirrel 3.2** | MIT | C++/JS-like syntax, classes, inheritance, generators, integer/float distinction, small (~240 KB of code), common in game engines | Somewhat dated embedding API |
| AngelScript | zlib | Closest to C++ (static types) | Needs a type signature for every SDK function, larger |
| ChaiScript | BSD-3 | Embedded as a header file | Heavy template code, requires exceptions, long compile times; the project uses `-fno-exceptions` |

**Squirrel** was chosen. One marked change was made to `sqvm.cpp`: on every backward branch (that is, on every loop)
it asks the host whether 3 seconds or 64 MB have been exceeded, and throws an error if so.

## 6. Java

| Option | Status | Note |
|---|---|---|
| **miniJVM** (<https://github.com/digitalgust/miniJVM>) | **Chosen** | The C VM is MIT; Java 8 class files, lambdas, reflection, threads; class library `minijvm_rt.jar` (GPLv2, with the author's exception that "using the jar binary from the release avoids the contagious GPL") |
| JamVM | Rejected | GPLv2, needs the GNU Classpath or OpenJDK class library (hundreds of MB) |
| Avian | Rejected | Archived, large with the OpenJDK library |
| CACAO, Kaffe | Rejected | Unmaintained, GPL |

What was done for the Switch (`lib/minijvm`, marked `__SWITCH__` changes): the Linux code paths, plain malloc instead
of mimalloc, interpreter only (the sljit JIT is off), no `dlopen`, no Java sockets and no TLS (apps use `nexvyn.Net`,
which respects the `network` permission), heap chunks from malloc instead of `mmap`, tinycthread's functions renamed so
they do not clash with newlib's C11 thread functions, and a 3-second limit check on every backward branch in the
interpreter (`NEXVYN_JVM_INTERRUPT`). The `minijvm_rt.jar` of release 2.2.0 is used as is.

**Java SDK**: `sdk/java/nexvyn` (App, Gfx, Ui, Sys, Net, Store...); the SDK classes are generated from the shared
function table with `tools/gen_java_sdk.py`, so Java always has the whole SDK. Values cross the boundary as JSON
text. **PC side**: `python tools/java_build.py app MyApp.nxvapp` compiles the sources against miniJVM's class library
(an API the console does not have fails on the PC) and produces `app.jar`.

**Limits**: miniJVM keeps a single VM per process, so one Java app runs at a time. Java's own class library (`java.io`
files, `sun.misc.Unsafe`) can get around the permissions, so Java apps also ask once on their first launch
(`apps.trustedJava`). The interpreter is slower than Lua/JS; Lua is recommended for drawing-heavy games.

## 7. Other small languages

| Language | License | Evaluation |
|---|---|---|
| Wren | MIT | Very small, class-based; but foreign methods must be declared with a signature on the Wren side (solvable with a generator script) |
| Berry | MIT | Python-like, for embedded systems; pocketpy already fills this gap |
| Janet | MIT | Lisp family, powerful; small audience |
| Fennel | MIT | A Lisp that compiles to Lua; can be added on the existing Lua runtime with `fennel.lua` (no C++ needed) |
| Teal | MIT | Typed Lua; compiles to Lua on the PC, needs no extra runtime |

Thanks to the shared `nxvrt` layer, any of these can be added in a few hundred lines with value conversion and
lifecycle hooks.

## 8. Measurements (this build)

| Component | Code (`.text`) | romfs |
|---|---|---|
| Squirrel core + std (sqvm_build) | ~238 KB | — |
| TinyCC (tcc_build) | ~281 KB | C headers ~65 KB |
| miniJVM (jvm_build) | ~446 KB | `minijvm_rt.jar` 1.4 MB + `nexvyn.jar` 27 KB |
| Shared layer + bindings (nxvrt, sqapp, capp, javaapp) | ~330 KB | — |
| Python system library | — | ~84 KB |

## 9. Interface languages: Japanese, Chinese and Korean

Besides programming languages, Nexvyn OS 1.0 adds three interface languages: **ja** (日本語), **zh** (简体中文,
Simplified Chinese) and **ko** (한국어). They are partial packs in `romfs/System/Languages/<code>/` (`_meta.json` +
module files) and app bundles' `lang/<code>.json`; a missing string falls back to English. A console set to
`zh-Hans` / `zh-CN` starts in `zh`, `ja` in `ja`, `ko` in `ko` (`main.cpp` pickLanguage).

- **Fonts.** No CJK font is bundled in the NRO or the repo. `text.cpp` draws characters Inter / JetBrains Mono lack
  with the console's **shared fonts** (pl:u): Standard (Japanese), ChineseSimplified + ExtChineseSimplified,
  ChineseTraditional, KO and NintendoExt (button symbols). Han characters take the regional shapes of the interface
  language (ja → Standard, zh → ChineseSimplified, ko → KO), else of the console language. Glyphs are baseline-aligned
  with the Latin font. Emulators serve the shared fonts from their installed firmware.
- **Without shared fonts** (an emulator without firmware fonts) a **font pack** on the SD card is used:
  `sdmc:/NexvynOS/System/Fonts/` (also `System/Library/Fonts/`). File names tell the region:
  `NotoSansCJK-Regular.ttc` (a collection: JP, KR, SC, TC faces), `NotoSansJP-Regular.ttf`, `NotoSansKR-…`,
  `NotoSansSC-…`, `NotoSansTC-…`, `SourceHanSans…`. The file is streamed by FreeType, not read into memory. Without
  either, CJK characters show as `?`. Settings > Language & Region shows the source ("CJK font").
- **Line breaking.** `text::wrapLines` and the web layout may break between two ideographs / kana and never before
  closing punctuation (、。」） small kana, ー) or after opening punctuation (「（). Hangul keeps words together in the
  interface (Korean is written with spaces); web pages break it anywhere like CSS `word-break: normal`.
- **Input.** The on-screen keyboard has **Korean 2-set** (jamo compose into syllables while typing, Backspace takes back
  the last jamo) and **Japanese romaji** (romaji → hiragana; Shift / caps lock → katakana) layouts. Kanji, hanzi and
  Chinese pinyin come from the **Nintendo system keyboard** (swkbd), opened with the keyboard type the language needs
  (Korean, Simplified Chinese, all languages for Japanese) by the IME key (shown with a CJK interface or layout), the
  keyboard menu or the text editing bubble. swkbd is not available in applet mode: a notification explains it.
- **Formats.** Dates come from `date.json` (`format_long`, `format_short`, `menubar`, month and day names); 12-hour
  times from `date.am`, `date.pm` and `date.time_12h` (`"{ap}{t}"` → 午後9:05).
- **App Market.** Catalog text maps (`name`, `subtitle`, `description`, `changelog`) take `ja`, `zh` / `zh-Hans`,
  `ko` / `ko-KR`; `tools/catalog_check.py` counts a CJK character as two for the 45-character subtitle limit.

## 10. Sources

- PyNX / nx-python: <https://github.com/nx-python/PyNX>, <https://nx-python.readthedocs.io/>, <https://gamebrew.org/wiki/PyNX_Switch>
- Ren'Py Switch port: <https://lemmasoft.renai.us/forums/viewtopic.php?p=530030>
- libnx JIT API: <https://switchbrew.github.io/libnx/jit_8h.html>; libnx `jit.c`: <https://github.com/switchbrew/libnx/blob/master/nx/source/kernel/jit.c>
- SVC table (CodeMemory): <https://switchbrew.org/w/index.php?diff=4091>, JIT services: <https://switchbrew.org/w/index.php?diff=9212>
- Atmosphère changelog (JIT kernel patches): <https://git.nold.in/nold/Atmosphere/raw/commit/be772b40e1f12680597c4ad27548c9c08d7d877a/docs/changelog.md>
- devkitPro development environment: <https://switchbrew.org/w/index.php?diff=4672>
- TinyCC: <https://repo.or.cz/tinycc.git>
- Squirrel: <https://github.com/albertodemichelis/squirrel>
- miniJVM: <https://github.com/digitalgust/miniJVM> (release 2.2.0)
- pocketpy: <https://github.com/pocketpy/pocketpy>
