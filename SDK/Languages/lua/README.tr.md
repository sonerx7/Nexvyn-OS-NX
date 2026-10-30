# Lua ile Nexvyn OS

[English](README.md) · **Türkçe**

Lua 5.4, Nexvyn OS'un ana dilidir: en hızlı betik çalışma ortamı, `nexvyn.game` 2D motoru, Studio'nun sprite,
tilemap ve sahne editörleri ve en çok örnek onunla gelir. SDK 1.0'dan beri vardır.

## Hazır şablon

[`template/`](template/) klasörü denetleyiciden geçen en küçük uygulamadır: bir sayaç, bir menü, `store` ile kayıt ve
beş dilde çeviriler. Klasörü `BenimUygulamam.nxvapp` adıyla kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new lua "Benim Uygulamam" --author adiniz

## app.json

```json
{
  "id": "com.adiniz.uygulamam",
  "name": {"en": "My App", "tr": "Uygulamam"},
  "description": {"en": "What it does", "tr": "Ne yaptığı"},
  "version": "1.0", "author": "Adınız", "category": "utilities", "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 560, "height": 400, "resizable": true},
  "gamepad": false,
  "permissions": []
}
```

`main` `.lua` ile bitiyorsa `"runtime"` gerekmez. `nexvyn.game` kullanıyorsanız `"minSdk": "1.2"` yazın; oyunlar
`"gamepad": true` ve `"resizable": true` ister.

## Program yapısı

`main.lua` geri çağırma tablosunu döndürür; hepsi isteğe bağlıdır:

```lua
local app = {}
function app.load(arg) end          -- bir kez; arg = açılan dosya / bağlantı ya da ""
function app.update(dt) end         -- her kare (~60 fps)
function app.draw(w, h)             -- her kare: çiz ve bileşenleri işle
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("hello"), 0, h / 2, 24, "bold", "center", w)
  if ui.button("+1", w / 2 - 50, h / 2 + 40, 100, 34, "primary") then store.set("n", store.get("n", 0) + 1) end
end
function app.event(e) end           -- ham girdi: e.type "keydown", "mousedown", "paddown"...
function app.menu() return {{title = TR("app"), items = {{label = TR("reset"), id = 1}}}} end
function app.onmenu(id) end
function app.close() return true end
return app
```

Diğer geri çağırmalar (SDK 1.4): `app.open`, `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`,
`app.unsaved`. Ekrandaki her metni `lang/<kod>.json` dosyalarına koyun ve `TR("anahtar")` ile okuyun.

## Çalıştırma

- **Konsolda, Studio ile:** Studio'da **Yeni Proje → Boş Lua uygulaması** ya da var olan klasörü açın; **Çalıştır**
  (Ctrl+R). Hatalar satırıyla işaretlenir, `print` çıktısı Studio konsolundadır.
- **Konsolda, PC'den:** klasörü `sdmc:/NexvynOS/Applications/` içine kopyalayın (FTP: **Bilgisayara Bağlan**, ya da
  `nxv push`) ve Launcher'ı yeniden açın.
- **Ryujinx'te:** klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın (`nxv install`).
  `sdmc:/NexvynOS/autorun.txt` içine `launch com.adiniz.uygulamam` satırı açılışta uygulamayı açar; testten sonra
  dosyayı silin.

## PC'de denetim

Nexvyn OS kaynak deposunun kökünden (`pip install lupa` gerekir):

    python tools/lua_check.py <yol>/BenimUygulamam.nxvapp --frames 600

`app.json`'u, tüm `.lua` dosyalarının derlenmesini, `TR` anahtarlarının `lang/en.json` ve `lang/tr.json` içinde
olmasını denetler, sonra uygulamayı sahte bir SDK ile rastgele tıklama, tuş ve kumanda girdisiyle yüzlerce kare
çalıştırır. `nxv check --sdk <kaynak>` aynı denetleyiciyi çağırır.

## Sık yapılan hatalar

- **`io`, `os.execute`, `require` ile dış modül yok:** dosyalar için `fs`, ayarlar için `store`. `require("ad")`
  yalnızca paketteki `ad.lua`'yı ya da sistem kütüphanesini (`require("nexvyn.game")`) yükler.
- **Her karede tablo ve resim oluşturmak:** resimleri `app.load` içinde bir kez `gfx.image` ile yükleyin, `app.draw`
  içinde büyük tablo kurmayın.
- **Uzun döngüler:** 3 saniyeden uzun süren geri çağırma durdurulur. Uzun işleri karelere bölün.
- **İzinler:** `net.*` için `"network"`, `sys.notify` için `"notifications"`, `sys.launch` / `nxv://` için `"launch"`,
  `sys.clipboard` için `"clipboard"`, kendi klasörleri dışı için `"files"` gerekir; bildirilmeyen izin verilmez.
- **Lua 1 tabanlıdır:** `ui.segmented`, `ui.dropdown` ve `ui.alert` dizinleri 1'den başlar (JS/Python'da 0).
- **`ui` bileşenleri benzersiz kimlik ister:** aynı etiket iki kez varsa `"Sil##3"` gibi sonek ekleyin.

## Daha fazlası

- SDK başvurusu: [SDK.md](../../Reference/SDK.tr.md) bölüm 1-10 (Lua), 8c (`nexvyn.game`), 8b (`g3d`)
- Rehberler: [DEVELOPER_GUIDE.md](../../Guides/DEVELOPER_GUIDE.tr.md), [GAME_ENGINE.md](../../Guides/GAME_ENGINE.tr.md),
  [LUA_CAPABILITIES.md](../../Guides/LUA_CAPABILITIES.tr.md)
- Örnekler: [Samples/lua](../../Samples/README.tr.md#lua)
