# Language pack: C (konsolda TinyCC)

[English](c.en.md) · **Türkçe**

Uygulama C ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin. API'nin tamamı `<nexvyn.h>`
dosyasıdır (`SDK/Reference/c/include/nexvyn.h`): asistanın bağlamı yetiyorsa onu da verin.

## İskelet

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

app.json: `"runtime": "c"`, `"main": "main.c"`, `"minSdk": "1.5"`. Bundle'daki her `.c` dosyası derlenir.

## Kurallar

- SDK adları `_` kullanır: `gfx_rect`, `ui_iconButton`, `sys_schedule`. İsteğe bağlı sayılar `0`, isteğe bağlı
  metinler `NULL`. Renkler metindir: `"#RRGGBB"`, `theme_color("accent")`, `rgba(r, g, b, a)`; `theme_dark()`.
- **Döndürülen metinler sonraki 15 SDK çağrısı boyunca yaşar.** Saklamadan ya da bir döngüden önce kopyala:
  `char c[16]; snprintf(c, sizeof c, "%s", theme_color("accent"));`
- `nxv_fmt("%d", n)` böyle bir metne biçimlendirir; argumentli çeviriler: `TR1`, `TR2`, `TR3`.
- Birden çok sonuç işaretçilerle: `gfx_size(&w, &h)`, `ui_mouse(&x, &y, &down, &hover)`, `input_stick("left", &x, &y)`.
  Record'lar yapıdır (struct): `nxv_hit`, `nxv_date`, `nxv_entry`, `nxv_response`, `nxv_event` (`e->key` ve `e->pad`
  NULL olabilir).
- `ui_textfield(id, buf, sizeof buf, ...)` buffer'ı yerinde düzenler ve değiştiğinde true döndürür; Enter için
  `ui_submitted(id)`. `ui_segmented(id, items, count, selected, ...)` `const char* items[]` alır.
- `fs_read(path, &len)` `malloc` ile ayrılmış bir buffer döndürür: `free` et. Resimler yoluyla çizilir:
  `gfx_draw("bundle:/a.png", x, y, 0, 0, 0, NULL)`. Mesh'ler `int` id'lerdir.
- async: `void* user` alan function işaretçileri: `void on_data(const char* json, const char* error, void* user)`
  ile `net_json(url, NULL, on_data, NULL)`; `void on_tick(void* user)` ile `timer_after(1.0, on_tick, NULL)`;
  `void on_button(int index, void* user)` ile `ui_alert(title, msg, buttons, 2, on_button, NULL)`. `store_getJson` /
  `store_setJson` JSON değerlerini saklar; `json_pretty` biçimlendirir.
- Küçük libc: stdio (`printf` → günlük, `snprintf`, `sscanf`; `FILE` yok), stdlib (sayılan `malloc`, `qsort`,
  `strtod`, `rand`), string, math, ctype, stdint, limits, assert, stdbool, stdarg.
- **sandbox'ta değil:** 3 sn koruması yok; sonsuz bir döngü ya da bir çökme Nexvyn OS'u durdurur. Döngüleri
  sınırlı tut. Kullanıcılar bir kez onay verir.

## Denetim

`python tools/rt_check.py <bundle>`: her .c dosyasını konsolun header'larına karşı devkitA64 gcc
`-fsyntax-only` ile derler (örtük bildirimler ve yanlış işaretçi türleri hatadır), TR anahtarlarını ve ağ iznini
denetler.
