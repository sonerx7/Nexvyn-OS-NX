# JavaScript ile Nexvyn OS

[English](README.md) · **Türkçe**

JavaScript uygulamaları QuickJS-ng motoruyla çalışır (ES2023: sınıflar, ok fonksiyonları, `async`/`await`, ES
modülleri, `Map`/`Set`, typed array). API Lua ile aynıdır; farklar aşağıdadır. SDK 1.1 gerekir.

## Hazır şablon

[`template/`](template/) denetleyiciden geçen en küçük uygulamadır. Kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new js "Benim Uygulamam" --author adiniz

## app.json

```json
{"id": "com.adiniz.uygulamam", "name": {"en": "My App", "tr": "Uygulamam"}, "version": "1.0",
 "category": "utilities", "icon": "icon.png", "main": "main.js", "minSdk": "1.1",
 "window": {"width": 560, "height": 400, "resizable": true}, "gamepad": false, "permissions": []}
```

`main` `.js`/`.mjs` ile bitiyorsa ya da `"runtime": "js"` yazılmışsa JavaScript seçilir.

## Program yapısı

`main.js` bir ES modülüdür. Geri çağırmaları genel `app` nesnesine atayın (ya da `export default { load, draw }`):

```js
import { formatScore } from "./util.js";   // paketteki diğer dosyalar; "./data.json" JSON verir
let n = 0;
app.load = (arg) => { n = store.get("n", 0); };
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("hello"), 0, h / 2, 24, "bold", "center", w);
  if (ui.button("+1", w / 2 - 50, h / 2 + 40, 100, 34, "primary")) store.set("n", ++n);
};
app.menu = () => [{ title: TR("app"), items: [{ label: TR("reset"), id: 1 }] }];
app.onmenu = (id) => { if (id === 1) store.set("n", n = 0); };
```

Geri çağırma vermediğiniz her asenkron fonksiyon Promise döndürür: `const veri = await net.fetchJson(url)`,
`const i = await ui.alert(baslik, mesaj, ["Tamam", "İptal"])`, `await timer.sleep(0.5)`.

## Çalıştırma

- **Studio:** **Yeni Proje → Boş JS uygulaması** (ya da *Ağ uygulaması*), **Çalıştır** (Ctrl+R).
- **Konsol / Ryujinx:** klasörü `NexvynOS/Applications/` içine kopyalayın (`nxv push` / `nxv install`).
  `autorun.txt` içine `launch <id>` uygulamayı açılışta açar.

## PC'de denetim

Nexvyn OS kaynak deposunun kökünden (Node.js 18+):

    node tools/js_check.mjs <yol>/BenimUygulamam.nxvapp --frames 600

Her `.js` dosyasını ES modülü olarak ayrıştırır, `TR` anahtarlarını denetler ve uygulamayı sahte SDK ile çalıştırır;
yakalanmayan Promise hatalarını da bildirir. Node.js'tir, QuickJS değil: API yanlışlarını yakalar, motor farklarını
yakalamaz.

## Sık yapılan hatalar

- **Diziler 0'dan başlar:** `ui.segmented`, `ui.dropdown`, `ui.alert` dizinleri ve `g3d.custom` indeksleri.
- **Çoklu sonuçlar dizidir:** `const [w, h] = gfx.size()`, `const [x, y] = input.stick("left")`.
- **`ui.textfield` yalnızca metni döndürür;** Enter'ı `ui.submitted("id")` söyler. `ui.row` 0/1/2 döndürür.
- **Tarayıcı / Node API'si yok:** `window`, `document`, `fetch`, `localStorage`, `require`, `process`, `Intl` yoktur.
  `net.fetch`, `store`, `fs` kullanın; yerel saat için `sys.date()`.
- **Yakalanmayan Promise hatası** hata ekranını açar: `await`'i `try`/`catch` içine alın.
- **`net.*` için `"network"` izni** gerekir; izin yoksa `res.error == "permission denied: network"`.

## Daha fazlası

- SDK: [SDK.md](../../Reference/SDK.tr.md) bölüm 11 · Rehber: [JS_APPS.md](../../Guides/JS_APPS.tr.md)
- Örnekler: [Samples/javascript](../../Samples/README.tr.md#javascript)
