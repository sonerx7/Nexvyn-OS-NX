# Native modules (.nxvmod): C++ apps installed from the App Market

> **Internal mechanism.** Native modules are only for Nexvyn OS's own optional C++ apps and are rebuilt in the release
> pipeline together with every NRO version. The platform for third-party developers is Lua, JavaScript and Python
> (sandbox, enforced permissions, stable API, editable in Studio); the C++ API changes with every build and is not an
> SDK.

Nexvyn OS's C++ apps come in two forms:

1. **Shipped with the system** (inside `NexvynOS.nro`). Some of them are *optional* (`"optional": true` in `app.json`):
   their code is in the NRO, but they appear in no list until the user taps "Get" in the App Market (or in Settings >
   Apps). See section 6.
2. **Native module** (`.nxvmod`). The app leaves the NRO entirely; its compiled code is downloaded from the App Market
   inside a `.nxvapp` package, and Nexvyn OS loads it into memory at run time. The NRO really gets smaller.

This document describes the second form.

## 1. How it works

A module is the app's source files compiled with **the same compiler and flags** as Nexvyn OS (only `-fPIC` instead
of `-fPIE`) and linked into an AArch64 shared object (`-shared`). Undefined symbols (`ui::button`, `theme::p`,
`std::string` members, `malloc`...) are left open; the NRO provides them.

When the app is opened for the first time, the loader (`source/runtimes/nxvmod.cpp`):

1. Reads the file and checks the ELF header and the `.nxvabi` section (section 3).
2. Puts the read-only segments (code, `.rodata`, symbol tables) into a **CodeMemory** object: the RX view becomes the
   module's address 0, the RW view is at another address for writing the code. It is the same as the JIT approach in
   C apps (TinyCC), and it works in an emulator too.
3. Puts the writable segments (`.data`, `.got`, `.init_array`, `.bss`) into **a second CodeMemory** object and maps it
   RW exactly at the address the module expects (right behind the RX view). This way the code's PC-relative (`adrp`)
   data accesses land in writable memory. `svcCreateCodeMemory` fills both objects with `0xFF` (the console's kernel
   does it, and emulators copy that), so the loader clears both views **after** mapping them and only then copies the
   segments: `.bss` and the gaps must read as zero. (Until 1.2 the loader cleared the source pages before that call;
   `.bss` came up as `0xFF`, every function-local static's guard byte read "already constructed", and the apps crashed
   on strings and mutexes made of `0xFF` bytes. That is why 1.0.0 shipped without modules.)
4. Applies the relocations: `R_AARCH64_RELATIVE`, `GLOB_DAT`, `JUMP_SLOT`, `ABS64` (and `RELR` if present). A symbol
   is looked up first **in the NRO's own `.dynsym` table** (the NRO reads its own table through `_DYNAMIC`), then in
   the module's own definitions: a dynamic linker's "executable first" rule. This way a single copy (the NRO's) of
   shared objects such as the static variables of inline functions is used.
5. Runs `.init_array` (inside the crash guard): `REGISTER_APP` and `REGISTER_SERVICE` register the app as if it had
   shipped with the system. `.fini_array` runs when Nexvyn OS shuts down.

Modules stay in memory for the whole session (there may be callbacks tied to their code). An updated module file is
loaded again at the next launch; the old code stays mapped until shutdown.

Native code is not sandboxed: the user is asked once on the first launch (Settings key `apps.trustedNative`, an
array of app ids). The permission system (`permissions`) cannot be applied to native code; therefore no permission
question is asked, and the list in `app.json` is for information only.

Not supported: `thread_local` variables (`PT_TLS`; the module is refused), text relocations (`-fPIC` is required), C++
exceptions and RTTI (Nexvyn OS is built with `-fno-exceptions -fno-rtti` anyway).

Shared loader (Native SDK 1.0): steps 1-4 (ELF checks, JIT code memory, segment copy and clearing, relocations, symbol
lookup) live in one plain C unit, `sdk/native/loader/nxelf.c`, that Nexvyn OS compiles (the Makefile's `SOURCES`) and
`libnexvyn_native` compiles too, for the `.nxvlib` shared libraries of exclusive-mode apps (`NATIVE_KIT.md`, "Shared
libraries"). `nxvmod.cpp` keeps the module rules: the `.nxvabi` check, the export table, the crash guard around the
constructors, trust and crash counting. The module ABI id, the error texts and the load order did not change with the
move; `tests/test_nxelf.cpp` covers the core on the PC.

## 2. The NRO side: exported symbols

`-Wl,--export-dynamic` exports all of the NRO's ~23,000 global symbols and grows the NRO by about 2 MB (more than the
modules save). So the build exports **only what the modules import**:

- `build/modules/exports.list` (`-Wl,--export-dynamic-symbol-list`): the modules' undefined symbols + the weak/unique
  objects the modules also define (inline function statics, template statics).
- `build/modules/exports.ld` (`EXTERN(...)`): forces linking library members (libstdc++, newlib) that the NRO itself
  never uses but a module wants.

Result: a few hundred symbols, a few KB. The price is that if a new module needs a new symbol, the NRO must be
rebuilt; a module built for an older OS keeps loading while every symbol it needs still exists (section 3).

## 3. ABI id

`ABI = FNV-1a 64( "nxv-module-abi-gen:" + NEXVYN_MODULE_ABI_GEN )`, 16 hex characters. The generation (`source/runtimes/nxvmod.h`) is raised by hand only
when a struct or calling convention shared with modules changes incompatibly. It does **not** change with the OS version,
with headers or with new exported functions: a module that needs a function the running OS lacks is refused cleanly
("missing symbol"); every other module built for the same generation keeps working.

- The NRO computes it at run time from its own `.dynsym` table (`nxvmod::abiId()`; if there are no exported symbols it
  is empty and no module is loaded).
- `tools/build_modules.py` computes the same value from `NexvynOS.elf` and writes it into every module as the
  `.nxvabi` section, and into the package's `app.json` as `"abi"`.
- A module of another ABI generation is never loaded. Opening it says so ("… was made for another version of Nexvyn OS")
  and at the same moment queues this system's build for the automatic install (section 7); the app opens again once
  it has arrived.
- The App Market keeps **one build per Nexvyn OS version**: a native entry of the catalog has a `"builds"` array
  (`{"nexvyn", "abi", "version", "download", "sha256", "size"}`), and every console takes the build whose `abi` is its
  own. An older console keeps finding the build made for it after newer ones are published; a console with no matching
  build does not list the app, and a console that has the app built in ignores `"builds"`. The top level of the entry
  stays what consoles before 1.2 understand (`"builtin": true` for apps they ship as optional apps), so their store
  pages keep working; it never says `"runtime": "native"`, which an older console would hide.
- After a system update every installed module of the old ABI is queued at the first boot (`osupdate`), so the user
  does not have to look for updates; "Update" in the App Market does the same by hand.

## 4. Package format

```
colorpicker.nxvapp
├── app.json            "native": "colorpicker.nxvmod", "abi": "<16 hex>", "permissions": [...]
├── colorpicker.nxvmod  shared object with debug info stripped + .nxvabi section
├── icon.png
├── lang/en.json, tr.json, de.json, fr.json, es.json
└── manifest.sha256
```

The rest of `app.json` (`id`, `name`, `window`, `fileTypes`...) is the same as that of the app shipped with the
system; there is no `"native": true` and no `"optional"`. `tools/nxvapp_pack.py` accepts this format (`"native"` must
point to an `.nxvmod` file and `"abi"` must be present). Installing, updating and uninstalling are the same as for
other packages.

## 5. Building

`tools/modules.json` lists the apps that become modules and their source files (or the file named by the
`NXVMOD_LIST` environment variable: `NXVMOD_LIST=tools/modules.full.json ./build.sh`):

```json
{"modules": [{"id": "news", "sources": ["source/apps/app_news.cpp", "source/apps/news_xml.cpp"], "permissions": ["network", "launch"]}]}
```

`./build.sh` does the rest:

| Step | What it does |
|---|---|
| `python tools/build_modules.py prepare` | `build/modules/modules.mk` (ids, sources, make rules) |
| `make modules` | `-fPIC` objects and `build/modules/<id>.so` |
| `python tools/build_modules.py exports` | `exports.list` and `exports.ld` |
| `python tools/build_modules.py romfs` | `build/romfs`: romfs without the module apps' bundles (hard links) + `System/Modules.json` and `System/Modules/<id>.png` |
| `make ROMFS=build/romfs` | `NexvynOS.nro` without the module sources |
| `python tools/build_modules.py package` | checks every import, writes the ABI, `build/modules/<id>.nxvapp` and `build/modules/catalog.json` |

The app's bundle stays in the source as `romfs/Applications/<id>.app` (icon, `lang/`, `app.json`); it just does not go
into the NRO's romfs. To embed an app in the system again, removing it from `tools/modules.json` is enough.

A list can also name `"bundles"`: script apps of `romfs/Applications` (the sample apps) that leave the NRO's romfs and
become ordinary App Market packages (`build/modules/<id>.nxvapp`, no ABI). They are listed in `System/Modules.json`
like the modules, so the same placeholders and the same automatic return after an update apply to them.

The split is staged and switched by the list alone. `tools/modules.json` is **empty in 1.2.0** (a beta that ships only
the NRO, with no Store changes): every app stays built in, `System/Modules.json` does not exist, so the Recommended
packs step, the Launcher placeholders and the update migration have nothing to do. Ready to flip, together with the
Store builds (`tools/store_pending/README.md`):

- `tools/modules.lowrisk.json`: small, self-contained apps (Color Meter, Controller Test, Fonts, Dictionary, Currency,
  Stickies, Tech Demo), the first step.
- `tools/modules.full.json`: the full split of the task plan (32 C++ apps and the 9 sample apps), after console
  testing. Its `_kept_in_nro` note lists what stays embedded and why.

Both build, load and run on the PC test setup (section 10).

`romfs:/System/Modules.json` carries the name, category and icon of the module apps: a module app that is not
installed becomes a "store only" placeholder in the registry; Quick Search says "… get it from the App Market", desktop
shortcuts look faded with a download badge, and `os::launch` and `nxv://app/` links open the App Market page.

When choosing module candidates: apps that use `REGISTER_SERVICE` (that must run without being opened), files that
define functions other system code calls, Studio's dependencies (`code`, `console`, `aichat` and their helpers) and
apps opened by system functions such as "About This Console" (`sysinfo`) must stay embedded.

## 6. Optional embedded apps and the catalog

Embedded apps with `"optional": true` in `app.json` count as "not installed" until their ids are in the settings array
`apps.optionalEnabled` (`registry::installed`, `registry::listed`, `registry::enableOptional`,
`registry::disableOptional`). On systems updating from the previous version, all of them are enabled once
(`apps.optionalV1`).

Catalog entries:

```json
{"id": "paint", "builtin": true, "name": {...}, "subtitle": {"en": "...", "tr": "...", "de": "...", "fr": "...", "es": "..."},
 "description": {...}, "category": "media", "icon": "https://.../paint.png", "screenshots": ["...", "...", "..."]}

{"id": "news", "runtime": "native", "abi": "<16 hex>", "version": "1.0", "download": "https://.../news.nxvapp",
 "sha256": "...", "size": 134144, "name": {...}, "subtitle": {...}, "description": {...}, "category": "internet",
 "icon": "https://.../news.png", "screenshots": [...]}
```

`builtin` entries have no download, `sha256` or size; if the running system has no app with that id, the entry is
hidden. For optional apps not in the catalog, the Store builds a local page from `app.json` (it opens offline too).
`subtitle` is a single-line introduction of at most 45 characters.

## 7. Automatic installs, updates and failures

**The install queue** (`source/apps/appstore_auto.h`, settings array `apps.autoInstall`): the system installs App
Market apps by itself, with no window and no question. A background service starts 8 s after boot, waits while the
console is offline (checks every 30 s), loads the catalog, picks this system's build, downloads it, checks it like any
App Market download (SHA-256, signature, App Guard) and installs it. A failure is logged and tried again after 1, 2, 4
… up to 30 minutes; an app the catalog does not have yet is looked for at the next catalog fetch. An entry leaves the
queue only when the app is installed and, for a module, built for this ABI. A changed signing key or a package App
Guard calls dangerous is never installed this way. When the queue is empty, one notification says how many apps
arrived. Nexvyn OS's own modules (ids in `System/Modules.json`) installed from the App Market are trusted at once
(`apps.trustedNative`); a module from anywhere else still asks on its first launch.

**Updating from a version that had the app built in** (`registry.cpp`, `migrateModules`): at the first boot of the new
version every app of `System/Modules.json` the user used is queued (`upgrade`). Used = pinned in the Dock, the taskbar
or Start, in the recent apps or launch counts, added as an optional app, or with data in some user's
`Library/Application Support/<id>`. Until it arrives the app waits in the Launcher as a "Downloading…" placeholder
(dimmed icon, progress ring, a cloud while offline); opening it says it is on its way. Nothing is deleted or
rewritten: pins, settings and data stay as they are and work again the moment the module is installed. Each id is
looked at once (`apps.modulesHandled`), so a later release that moves more apps handles just those. A new console
gets the same apps through the setup assistant's **Recommended packs** step (Office, Media, Modding, Tools, Retro and
Demos; only packs that contain modules of this build are shown, all chosen at first, Skip chooses none). The chosen
apps are queued at the end of the setup; offline, a notification says they will come once the console is online.

**When a module cannot run** the app shows a dialog and the desktop goes on: another ABI (the right build is fetched,
see section 3), a load error (Try Again / Reinstall / Cancel), or turned off after 3 crashes. Crashes are counted per
module file (settings `apps.moduleCrashes`): a fault isolated in its window, a crash in its constructors, or a session
that ended in it. The third one turns the app off with a Reinstall button; a new file (reinstall or update) starts the
count again. Reinstall queues the app with `force`, keeps its data and opens its App Market page. Nothing in this path
runs at boot except the queue's service, which never blocks: a missing network or catalog only delays the downloads.

## 8. Known limits

- A module's services (`REGISTER_SERVICE`) start running after the app has been opened for the first time. Apps with
  services that must run unopened (alarms, reminders, calendar alerts, the PC server) stay embedded.
- Every build of the NRO may produce a new ABI: modules must be republished together with the release
  (`build/modules/catalog.json`, one more entry in each module's `"builds"`).
- Modules are not unloaded; an updated module is loaded next to the old code at its next launch.

## 9. Result (1.0.0)

- Apps that became modules: Color Meter (`colorpicker`), Controller Test (`gamepad`), Fonts (`fontbook`),
  Dictionary (`dictionary`), Currency (`currency`), News (`news` + `news_xml.cpp`), Stickies (`stickies`), Network
  (`network`). `sysinfo` stayed embedded because it is opened by "About This Console".
- `NexvynOS.nro`: 53 563 001 bytes (without modules) → 52 854 061 bytes (with modules), 709 KB smaller; code + read-only
  data (the `.text` column) 38 983 202 → 38 388 624 bytes. The NRO exports 336 symbols (a few KB). Packages are
  51–131 KB.
- To turn it off: empty the list in `tools/modules.json`; the apps are embedded in the NRO again (as optional apps).
- Trying it in the emulator: unpack `build/modules/<id>.nxvapp` into the folder `sdmc:/NexvynOS/Applications/<id>.nxvapp/`
  (or open and install it from Files; a zip named `<id>.nxvapp` dropped into Applications is not unpacked), open the
  app and confirm the trust question (in autorun: `set apps.trustedNative ["colorpicker"]`). Log: the `nxvmod` tag
  ("loaded ... at ...", or the reason for the error).

## 10. Result (1.2)

- Loader fixed (section 1): the 8 apps of 1.0.0 load and run on the PC test setup, every module of `tools/modules.lowrisk.json` passes 3
  open/close cycles and 5 open at once closed in another order and reopened, and the 41 packages of
  `tools/modules.full.json` open and close twice each.
- Measured without CPython and the retro cores (`NexvynOS.nro`, bytes):

| | NRO | code part | romfs | packages |
|---|---|---|---|---|
| before (every app built in) | 63 488 321 | 42 958 848 | 20 494 444 | – |
| `tools/modules.lowrisk.json` (7 modules) | 62 900 625 (−574 KB) | 42 549 248 | 20 316 348 | 7, 519 KB |
| `tools/modules.full.json` (32 modules, 9 bundles) | 58 898 793 (−4.4 MB) | 39 727 104 | 19 136 660 | 41, 3.3 MB |

- 1.2.0 as shipped (`tools/modules.json` empty): 63 552 661 bytes, every app built in as before; the 64 KB more are the
  new loader, queue, setup step and strings. The same 69 C++ apps register as in 1.1.2.
- The NRO exports 306 symbols with the low-risk list and 751 with the full split. A clean `JOBS=8 ./build.sh` took 230 s
  before and 204 s with the low-risk list (same machine with other jobs running: within the noise). Boot to the first desktop
  frame on the PC test setup: 8.5–8.7 s before, 7.3–9.1 s after (no measurable change).
