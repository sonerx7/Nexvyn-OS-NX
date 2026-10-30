# Native modules (.nxvmod): C++ apps installed from the App Market

[Türkçe](NATIVE_MODULES.tr.md) · **English**

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
   C apps (TinyCC), and it works in Ryujinx too.
3. Puts the writable segments (`.data`, `.got`, `.init_array`, `.bss`) into **a second CodeMemory** object and maps it
   RW exactly at the address the module expects (right behind the RX view). This way the code's PC-relative (`adrp`)
   data accesses land in writable memory.
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

## 2. The NRO side: exported symbols

`-Wl,--export-dynamic` exports all of the NRO's ~23,000 global symbols and grows the NRO by about 2 MB (more than the
modules save). So the build exports **only what the modules import**:

- `build/modules/exports.list` (`-Wl,--export-dynamic-symbol-list`): the modules' undefined symbols + the weak/unique
  objects the modules also define (inline function statics, template statics).
- `build/modules/exports.ld` (`EXTERN(...)`): forces linking library members (libstdc++, newlib) that the NRO itself
  never uses but a module wants.

Result: a few hundred symbols, a few KB. The price is that if a new module needs a new symbol, the NRO must be
rebuilt; since the ABI id changes with every build anyway, modules are always built together with the NRO.

## 3. ABI id

`ABI = FNV-1a 64( sorted exported symbol names, each followed by "\n" + NEXVYN_VERSION )`, 16 hex characters.

- The NRO computes it at run time from its own `.dynsym` table (`nxvmod::abiId()`; if there are no exported symbols it
  is empty and no module is loaded).
- `tools/build_modules.py` computes the same value from `NexvynOS.elf` and writes it into every module as the
  `.nxvabi` section, and into the package's `app.json` as `"abi"`.
- A module with a different ABI: loading is refused ("… needs to be rebuilt for Nexvyn OS x.y"), the App Market lists
  only module entries that match the running system's ABI, and if an installed module's ABI differs from the
  catalog's, "Update" appears.

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

`tools/modules.json` lists the apps that become modules and their source files:

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

## 7. Known limits

- Apps that were embedded before an update and are modules now (for example News) must be downloaded once from the
  Store after the update; their data (`Application Support/<id>`) is kept.
- A module's services (`REGISTER_SERVICE`) start running after the app has been opened for the first time.
- Every build of the NRO may produce a new ABI: modules must be republished together with the release
  (`build/modules/catalog.json`).

## 8. Result (1.0.0)

- Apps that became modules: Color Meter (`colorpicker`), Controller Test (`gamepad`), Fonts (`fontbook`),
  Dictionary (`dictionary`), Currency (`currency`), News (`news` + `news_xml.cpp`), Stickies (`stickies`), Network
  (`network`). `sysinfo` stayed embedded because it is opened by "About This Console".
- `NexvynOS.nro`: 53 563 001 bytes (without modules) → 52 854 061 bytes (with modules), 709 KB smaller; code + read-only
  data (the `.text` column) 38 983 202 → 38 388 624 bytes. The NRO exports 336 symbols (a few KB). Packages are
  51–131 KB.
- To turn it off: empty the list in `tools/modules.json`; the apps are embedded in the NRO again (as optional apps).
- Trying it in the emulator: put `build/modules/<id>.nxvapp` into `sdmc:/NexvynOS/Applications/` (or open and install it
  from Files), open the app and confirm the trust question (in autorun: `set apps.trustedNative ["colorpicker"]`). Log:
  the `nxvmod` tag ("loaded ... at ...", or the reason for the error).
