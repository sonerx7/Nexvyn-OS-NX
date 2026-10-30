# C ile Nexvyn OS uygulaması

**Türkçe** · [English](C_APPS.en.md)

Nexvyn OS, paketteki `.c` dosyalarını uygulama açılırken **konsolda** TinyCC ile derler; PC'de derleme adımı yoktur.
API diğer dillerle aynıdır, adlarda nokta yerine alt çizgi kullanılır (`gfx.rect` → `gfx_rect`). Tam başvuru
`sdk/SDK.tr.md` bölüm 14 ve `romfs/System/C/include/nexvyn.h`, çalışan örnek `romfs/Applications/helloc.nxvapp`
("Merhaba C"). SDK 1.5 gerekir.

## Nasıl seçilir

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "runtime": "c", "main": "main.c", "minSdk": "1.5",
 "window": {"width": 360, "height": 260, "resizable": false}, "permissions": []}
```

Paketteki (alt klasörler dahil) bütün `.c` dosyaları derlenir; başlık dosyalarınız `#include "util.h"` ile bulunur.
Studio'da **Yeni Proje → Boş C uygulaması** şablonu vardır.

## En küçük uygulama

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

## Kurallar

- Geri çağırmalar sabit adlı fonksiyonlardır ve hepsi isteğe bağlıdır: `app_load`, `app_update`, `app_draw`,
  `app_event`, `app_menu` (`menu_begin` / `menu_item` / `menu_separator` ile), `app_onmenu`, `app_close`, `app_search`...
- İsteğe bağlı sayılar için `0`, isteğe bağlı metinler için `NULL` verin. Renkler metindir: `"#FF8800"`,
  `theme_color("accent")`, `rgba(255, 136, 0, 255)`.
- Dönen metinler sistemindir ve sonraki 15 SDK çağrısı boyunca geçerlidir; saklamak için kopyalayın. `nxv_fmt`
  biçimlendirir: `TR1("puan", nxv_fmt("%d", puan))`.
- `ui_textfield` bir `char` tamponunu yerinde düzenler; `fs_read` `malloc` ile ayrılmış bir tampon döndürür (`free` edin).
- Asenkron çağrılar fonksiyon işaretçisi ve `void* user` alır: `net_json(url, NULL, veri_geldi, NULL)`.
- Küçük bir C kütüphanesi vardır: `stdio.h` (`printf` günlüğe yazar, `snprintf`, `sscanf`; `FILE` yok, dosyalar için
  `fs_*`), `stdlib.h`, `string.h`, `math.h`, `ctype.h`, `stdint.h`, `assert.h`.

## Güvenlik ve sınırlar

C kodu yerel koddur: Lua/JS/Python gibi korumalı alanda çalışmaz, sonsuz döngü ya da çökme durdurulamaz (3 saniye
sınırı yoktur). Bu yüzden SD karttan kurulan bir C uygulaması ilk açılışta kullanıcıya bir kez sorulur. `malloc`
64 MB ile sınırlıdır ve pencere kapanınca kalan bellek serbest bırakılır. Derleme hataları dosya ve satır numarasıyla
hata ekranında görünür. C uygulamaları JIT kod belleği ister (Atmosphère'in homebrew yükleyicisi sağlar).

PC'de denetim: `python tools/rt_check.py Uygulamam.nxvapp` (devkitA64 gcc ile aynı başlıklara karşı derler).
