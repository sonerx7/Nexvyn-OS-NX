# C ile Nexvyn OS

[English](README.md) · **Türkçe**

Nexvyn OS paketteki `.c` dosyalarını uygulama açılırken **konsolda** TinyCC ile derler; PC'de derleme adımı yoktur.
API diğer dillerle aynıdır, adlarda nokta yerine alt çizgi vardır (`gfx.rect` → `gfx_rect`). Başlık `<nexvyn.h>`
([SDK/c/include](../../Reference/README.tr.md)). SDK 1.5 gerekir.

> C kodu yerel koddur: Lua/JS/Python gibi korumalı alanda çalışmaz, sonsuz döngü ya da çökme durdurulamaz (3 saniye
> sınırı yoktur). SD karttan kurulan bir C uygulaması ilk açılışta kullanıcıya bir kez sorulur. C uygulamaları JIT kod
> belleği ister (Atmosphère'in homebrew yükleyicisi sağlar); yoksa hata ekranı bunu söyler.

## Hazır şablon

[`template/`](template/) denetleyiciden (devkitA64 gcc ile derleme) geçen en küçük uygulamadır. Kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new c "Benim Uygulamam" --author adiniz

## app.json

```json
{"id": "com.adiniz.uygulamam", "name": {"en": "My App", "tr": "Uygulamam"}, "version": "1.0",
 "category": "utilities", "icon": "icon.png", "runtime": "c", "main": "main.c", "minSdk": "1.5",
 "window": {"width": 560, "height": 400, "resizable": true}, "gamepad": false, "permissions": []}
```

Paketteki (alt klasörler dahil) bütün `.c` dosyaları derlenir; kendi başlıklarınız `#include "util.h"` ile bulunur.

## Program yapısı

Geri çağırmalar sabit adlı fonksiyonlardır, hepsi isteğe bağlıdır:

```c
#include <nexvyn.h>

static int n;

void app_load(const char* arg) { n = (int)store_getNum("n", 0); }

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    gfx_color(theme_color("text"));
    gfx_text(TR("hello"), 0, h / 2, 24, "bold", "center", w);
    if (ui_button("+1", w / 2 - 50, h / 2 + 40, 100, 34, "primary", NULL, true)) store_setNum("n", ++n);
}

void app_menu(void) {
    menu_begin(TR("app"));
    menu_item(TR("reset"), 1, NULL, false, true);
}

void app_onmenu(int id) { if (id == 1) store_setNum("n", n = 0); }
```

Diğerleri: `app_update(float)`, `app_event(const nxv_event*)`, `bool app_close(void)`, `app_open`, `app_search`
(`search_result(...)` ile yanıt), `app_suspend`, `app_resume`, `app_focus(bool)`, `app_autosave`, `bool app_unsaved(void)`.

## Çalıştırma

- **Studio:** **Yeni Proje → Boş C uygulaması**, **Çalıştır** (Ctrl+R). Derleme hataları dosya ve satırıyla hata
  ekranında görünür.
- **Konsol / Ryujinx:** klasörü `NexvynOS/Applications/` içine kopyalayın (`nxv push` / `nxv install`). Emülatörün
  JIT belleği sağlamadığı durumda C uygulaması açılmaz ve hata ekranı nedenini söyler; asıl deneme konsoldadır.

## PC'de denetim

Nexvyn OS kaynak deposunun kökünden (devkitPro'nun devkitA64'ü kuruluysa):

    python tools/rt_check.py <yol>/BenimUygulamam.nxvapp

Her `.c` dosyasını `aarch64-none-elf-gcc -fsyntax-only` ile konsoldaki başlıklara karşı derler: bildirilmemiş
fonksiyon ya da yanlış argüman türü burada yakalanır. `TR` anahtarlarını ve `net_*` için `network` iznini de denetler.

## Sık yapılan hatalar

- **Dönen metinler sistemindir ve sonraki 15 SDK çağrısı boyunca geçerlidir.** Döngüde kullanacaksanız kopyalayın:
  `char renk[16]; snprintf(renk, sizeof renk, "%s", theme_color("accent"));`
- **İsteğe bağlı argümanlar:** sayılar için `0`, metinler için `NULL` (varsayılan). Renkler metindir: `"#FF8800"`,
  `theme_color("accent")`, `rgba(255, 136, 0, 255)`.
- **`ui_textfield` bir `char` tamponunu yerinde düzenler** (`sizeof` verin); metin değişince `true` döndürür.
- **`fs_read` `malloc` ile ayrılmış tampon döndürür:** `free` edin. `malloc` 64 MB ile sınırlıdır.
- **`printf` günlüğe yazar,** `FILE` yoktur; dosyalar için `fs_*`.
- **Asenkron çağrılar fonksiyon işaretçisi ve `void* user` alır:** `net_json(url, NULL, geldi, NULL)` ile
  `void geldi(const char* json, const char* hata, void* user)`.
- **`e->key` ve `e->pad` NULL olabilir:** `strcmp` öncesi denetleyin.

## Daha fazlası

- SDK: [SDK.md](../../Reference/SDK.tr.md) bölüm 14 ve `nexvyn.h` · Rehber: [C_APPS.md](../../Guides/C_APPS.tr.md)
- Örnekler: [Samples/c](../../Samples/README.tr.md#c) (Merhaba C, Hayat Oyunu, Bahşiş Bölüşücü)
