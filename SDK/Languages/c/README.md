# Nexvyn OS in C

**English** · [Türkçe](README.tr.md)

Nexvyn OS compiles the bundle's `.c` files **on the console** with TinyCC when the app opens; there is no build step
on the PC. The API is the same as in the other languages with an underscore instead of the dot
(`gfx.rect` → `gfx_rect`). The header is `<nexvyn.h>` ([SDK/c/include](../../Reference/README.md)). Needs SDK 1.5.

> C is native code: it is not sandboxed like Lua/JS/Python, and an endless loop or a crash cannot be stopped (there is
> no 3 second limit). A C app installed from the SD card asks the user once before it runs. C apps need JIT code
> memory (Atmosphère's homebrew loader provides it); without it the error screen says so.

## Ready-made template

[`template/`](template/) is the smallest app that passes the checker (a devkitA64 gcc compile). Copy it, or run
`python SDK/Tools/nxv/nxv.py new c "My App" --author yourname`.

## Program structure

Callbacks are functions with fixed names, all optional (see the code above): `app_load`, `app_update(float)`,
`app_draw(float, float)`, `app_event(const nxv_event*)`, `app_menu` (built with `menu_begin` / `menu_item` /
`menu_separator`), `app_onmenu(int)`, `bool app_close(void)`, `app_open`, `app_search` (answer with
`search_result(...)`), `app_suspend`, `app_resume`, `app_focus(bool)`, `app_autosave`, `bool app_unsaved(void)`.
Every `.c` file of the bundle (subfolders included) is compiled; your own headers are found with `#include "util.h"`.

## Running it

- **Studio:** **New Project → Blank C App**, **Run** (Ctrl+R). Compile errors show on the error screen with file and line.
- **Console / Ryujinx:** copy the folder into `NexvynOS/Applications/` (`nxv push` / `nxv install`). If the emulator
  does not provide JIT memory the C app does not open and the error screen says why; the real test is on the console.

## Checking it on a PC

From the root of the Nexvyn OS source repository (with devkitPro's devkitA64 installed):

    python tools/rt_check.py <path>/MyApp.nxvapp

It compiles every `.c` file with `aarch64-none-elf-gcc -fsyntax-only` against the console's headers, so an undeclared
function or a wrong argument type fails here. It also checks the `TR` keys and the `network` permission for `net_*`.

## Common pitfalls

- **Returned strings belong to the system and stay valid for the next 15 SDK calls.** Copy them before a loop:
  `char color[16]; snprintf(color, sizeof color, "%s", theme_color("accent"));`
- **Optional arguments:** `0` for numbers, `NULL` for strings (the default). Colors are strings: `"#FF8800"`,
  `theme_color("accent")`, `rgba(255, 136, 0, 255)`.
- **`ui_textfield` edits a `char` buffer in place** (pass `sizeof`); it returns `true` when the text changed.
- **`fs_read` returns a `malloc`'d buffer:** `free` it. `malloc` is limited to 64 MB.
- **`printf` writes to the app's log,** there is no `FILE`; use `fs_*` for files.
- **Async calls take a function pointer and a `void* user`:** `net_json(url, NULL, on_data, NULL)` with
  `void on_data(const char* json, const char* error, void* user)`.
- **`e->key` and `e->pad` can be NULL:** check before `strcmp`.

## More

- SDK: [SDK.md](../../Reference/SDK.en.md) section 14 and `nexvyn.h` · Guide: [C_APPS.md](../../Guides/C_APPS.en.md)
- Samples: [Samples/c](../../Samples/README.md#c) (Hello C, Game of Life, Tip Splitter)
