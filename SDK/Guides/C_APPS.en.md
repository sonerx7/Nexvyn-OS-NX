# A Nexvyn OS app in C

[Türkçe](C_APPS.tr.md) · **English**

Nexvyn OS compiles the `.c` files of a bundle with TinyCC **on the console** when the app opens; there is no build step
on the PC. The API is the same as in the other languages, with underscores instead of dots in the names (`gfx.rect` →
`gfx_rect`). Full reference: `sdk/SDK.en.md` section 14 and `romfs/System/C/include/nexvyn.h`; working sample:
`romfs/Applications/helloc.nxvapp` ("Hello C"). Requires SDK 1.5.

## How to choose it

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "runtime": "c", "main": "main.c", "minSdk": "1.5",
 "window": {"width": 360, "height": 260, "resizable": false}, "permissions": []}
```

Every `.c` file in the bundle (subfolders included) is compiled; your own headers are found with `#include "util.h"`.
Studio has a **New Project → Empty C app** template.

## The smallest app

```c
#include <nexvyn.h>

static int sayi;

void app_load(const char* arg) { sayi = (int)store_getNum("sayi", 0); }

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    gfx_color(theme_color("text"));
    gfx_text(nxv_fmt("%d", sayi), 0, 60, 48, "bold", "center", w);
    if (ui_button("+1", w / 2 - 50, 140, 100, 34, "primary", NULL, true)) store_setNum("sayi", ++sayi);
}
```

## Rules

- Callbacks are functions with fixed names, all optional: `app_load`, `app_update`, `app_draw`, `app_event`,
  `app_menu` (with `menu_begin` / `menu_item` / `menu_separator`), `app_onmenu`, `app_close`, `app_search`...
- Pass `0` for optional numbers and `NULL` for optional strings. Colors are strings: `"#FF8800"`,
  `theme_color("accent")`, `rgba(255, 136, 0, 255)`.
- Returned strings belong to the system and stay valid for the next 15 SDK calls; copy them to keep them. `nxv_fmt`
  formats: `TR1("puan", nxv_fmt("%d", puan))`.
- `ui_textfield` edits a `char` buffer in place; `fs_read` returns a `malloc`'d buffer (`free` it).
- Asynchronous calls take a function pointer and a `void* user`: `net_json(url, NULL, veri_geldi, NULL)`.
- A small C library is included: `stdio.h` (`printf` writes to the log, `snprintf`, `sscanf`; no `FILE`, use `fs_*`
  for files), `stdlib.h`, `string.h`, `math.h`, `ctype.h`, `stdint.h`, `assert.h`.

## Security and limits

C code is native code: unlike Lua/JS/Python it is not sandboxed, and an endless loop or a crash cannot be stopped
(there is no 3-second limit). That is why a C app installed from the SD card asks the user once, on its first launch.
`malloc` is limited to 64 MB and whatever memory is left is freed when the window closes. Compile errors appear on the
error screen with file and line number. C apps need JIT code memory (Atmosphère's homebrew loader provides it).

Checking on the PC: `python tools/rt_check.py Uygulamam.nxvapp` (compiles with devkitA64 gcc against the same headers).
