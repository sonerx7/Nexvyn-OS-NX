# Language pack: C (TinyCC on the console)

**English** · [Türkçe](c.tr.md)

Add this after `system-prompt.en.md` when the app is written in C. The full API is `<nexvyn.h>`
(`SDK/Reference/c/include/nexvyn.h`): give it to the assistant as well when its context allows.

## Skeleton

```c
#include <nexvyn.h>
#include <stdio.h>
#include <string.h>

static int count;
static char name[64];

void app_load(const char* arg) {
    count = (int)store_getNum("count", 0);
    snprintf(name, sizeof name, "%s", store_getStr("name", ""));
}

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    gfx_color(theme_color("text"));
    gfx_text(TR("title"), 0, 24, 24, "bold", "center", w);
    if (ui_textfield("name", name, sizeof name, 20, 70, w - 40, 34, TR("name_hint"), NULL)) store_setStr("name", name);
    if (ui_button(TR1("count", nxv_fmt("%d", count)), w / 2 - 80, 120, 160, 34, "primary", NULL, true))
        store_setNum("count", ++count);
}

void app_event(const nxv_event* e) {
    if (strcmp(e->type, "keydown") == 0 && e->key && strcmp(e->key, "space") == 0) store_setNum("count", ++count);
}

void app_menu(void) {
    menu_begin(TR("app"));
    menu_item(TR("reset"), 1, NULL, false, count > 0);
}

void app_onmenu(int id) { if (id == 1) store_setNum("count", count = 0); }
```

app.json: `"runtime": "c"`, `"main": "main.c"`, `"minSdk": "1.5"`. Every `.c` file of the bundle is compiled.

## Rules

- SDK names use `_`: `gfx_rect`, `ui_iconButton`, `sys_schedule`. Optional numbers `0`, optional strings `NULL`.
  Colors are strings: `"#RRGGBB"`, `theme_color("accent")`, `rgba(r, g, b, a)`; `theme_dark()`.
- **Returned strings live for the next 15 SDK calls.** Copy them before keeping them or before a loop:
  `char c[16]; snprintf(c, sizeof c, "%s", theme_color("accent"));`
- `nxv_fmt("%d", n)` formats into such a string; translations with arguments: `TR1`, `TR2`, `TR3`.
- Several results through pointers: `gfx_size(&w, &h)`, `ui_mouse(&x, &y, &down, &hover)`, `input_stick("left", &x, &y)`.
  Records are structs: `nxv_hit`, `nxv_date`, `nxv_entry`, `nxv_response`, `nxv_event` (`e->key` and `e->pad` may be NULL).
- `ui_textfield(id, buf, sizeof buf, ...)` edits the buffer in place and returns true when it changed;
  `ui_submitted(id)` for Enter. `ui_segmented(id, items, count, selected, ...)` takes `const char* items[]`.
- `fs_read(path, &len)` returns a `malloc`'d buffer: `free` it. Images are drawn by path:
  `gfx_draw("bundle:/a.png", x, y, 0, 0, 0, NULL)`. Meshes are `int` ids.
- Async: function pointers with `void* user`: `net_json(url, NULL, on_data, NULL)` with
  `void on_data(const char* json, const char* error, void* user)`; `timer_after(1.0, on_tick, NULL)` with
  `void on_tick(void* user)`; `ui_alert(title, msg, buttons, 2, on_button, NULL)` with
  `void on_button(int index, void* user)`. `store_getJson` / `store_setJson` keep JSON values; `json_pretty` formats.
- Small libc: stdio (`printf` → log, `snprintf`, `sscanf`; no `FILE`), stdlib (counted `malloc`, `qsort`, `strtod`,
  `rand`), string, math, ctype, stdint, limits, assert, stdbool, stdarg.
- **Not sandboxed:** no 3 s guard, an endless loop or a crash stops Nexvyn OS. Keep loops bounded. Users consent once.

## Check

`python tools/rt_check.py <bundle>`: compiles each .c file with devkitA64 gcc `-fsyntax-only` against the console's
headers (implicit declarations and wrong pointer types are errors), checks the TR keys and the network permission.
