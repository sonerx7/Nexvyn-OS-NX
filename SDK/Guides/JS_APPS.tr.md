# JavaScript ile Nexvyn OS uygulaması

**Türkçe** · [English](JS_APPS.en.md)

Nexvyn OS uygulamaları (`.nxvapp`) Lua'nın yanında JavaScript ile de yazılabilir. API aynıdır; tam başvuru kaynağı
`sdk/SDK.tr.md` (bölüm 11 "JavaScript"), çalışan örnek `romfs/Applications/hellojs.nxvapp` ("Merhaba JS").

## Nasıl seçilir

`app.json` içinde ana dosyayı `main.js` yapın:

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "main": "main.js", "window": {"width": 360, "height": 260, "resizable": false}}
```

Ana dosyanın adı `.js` / `.mjs` ile bitiyorsa ya da `"runtime": "js"` yazılmışsa uygulama JavaScript motoruyla
(QuickJS-ng) açılır; diğer durumlarda eskisi gibi Lua kullanılır.

## En küçük uygulama

```js
let sayi = 0;
app.load = () => { sayi = store.get("sayi", 0); };
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(String(sayi), 0, 60, 48, "bold", "center", w);
  if (ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) store.set("sayi", ++sayi);
};
```

Geri çağırmalar Lua ile aynıdır: `app.load(arg)`, `app.open(arg)`, `app.update(dt)`, `app.draw(w, h)`,
`app.event(e)`, `app.menu()`, `app.onmenu(id)`, `app.close()`. İsterseniz bunları `export default { load, draw }`
şeklinde de verebilirsiniz.

## Lua'dan farklar (özet)

- **Diziler 0'dan başlar:** `ui.segmented`, `ui.dropdown` seçili indeksi, `ui.alert` düğme indeksi, `g3d.custom`
  indeksleri.
- **`nil` yerine `null`:** `fs.read`, `json.decode`, `gfx.image`, `g3d.load` başarısız olursa `null` döner.
- **Çoklu dönüş değerleri dizi olur:** `const [w, h] = gfx.size()`, `const [x, y] = input.stick()`,
  `const [yuzde, sarj] = sys.battery()`.
- **`ui.textfield` yalnızca metni döndürür;** Enter'a basıldığını `ui.submitted("id")` söyler.
  **`ui.row`** 0 (bir şey yok), 1 (tıklandı) veya 2 (çift tıklandı) döndürür.
- **Promise:** geri çağırma vermediğiniz her asenkron fonksiyon Promise döndürür:
  `const veri = await net.fetchJson(url)`, `const i = await ui.alert(baslik, mesaj, ["Tamam", "İptal"])`,
  `await timer.sleep(0.5)`. `net.fetchJson` hata olursa (bağlantı yok, HTTP hatası, bozuk JSON) Error fırlatır;
  `try { ... } catch (e) { e.message }` ile yakalayın. Yakalanmayan Promise hatası, normal hata gibi hata ekranını açar.
- **Modüller:** paketteki dosyaları `import { f } from "./yardimci.js"` ile alın; `import veri from "./veri.json"`
  JSON dosyasını nesne olarak verir. `main.js` bir ES modülüdür, en üstte `await` kullanılabilir.
- **Zamanlayıcılar:** `timer.after/every/cancel` (saniye) ve `setTimeout`/`setInterval`/`clearTimeout` (milisaniye).
- **Günlük:** `console.log(...)` ve `print(...)` çıktısı `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır;
  nesneler JSON olarak yazılır.
- Tarayıcı/Node API'leri yoktur (`window`, `document`, `fetch`, `localStorage`, `require`); SDK modüllerini kullanın.

## SDK 1.4 eklemeleri

- **Paylaşım:** `sys.share(metinVeyaYol)` paylaşım sayfasını açar; `app.json` içinde `"shareTargets": ["text"]` olan
  uygulamalar listelenir. Alan uygulama öğeyi `app.load(arg)` / `app.open(arg)` ile alır.
- **Bağlantılar:** `sys.open("nxv://app/<id>?arg=...")`, `nxv://store/<id>`, `nxv://settings/<bölme>` (`launch` izni);
  `sys.appUrl(id, arg)` bağlantıyı üretir.
- **Zamanlanmış bildirim:** `sys.schedule(epoch, baslik, govde, arg)` → kimlik (uygulama kapalıyken de gelir;
  `notifications` izni), `sys.unschedule(id)`, `sys.scheduled()`.
- **İzinler:** dört izin de zorunludur; izin yoksa çağrı `false` döner. `sys.clipboard` izin istemez.
  `sys.hasPermission(ad)`, `await sys.requestPermission(ad)` → `true`/`false`.
- **Bellek:** `sys.memory()` → `[kullanılan, sınır]`.
- **Geri çağırmalar:** `app.search = (q) => [{ title, subtitle, icon, arg }]` (Hızlı Arama), `app.suspend`,
  `app.resume`, `app.focus = (odakta) => {}`, `app.autosave`, `app.unsaved = () => kaydedilmemisVar`.

## Sınırlar ve hatalar

- Her pencere kendi JavaScript motorunu çalıştırır; bellek sınırı **64 MB**.
- Tek bir geri çağırma **3 saniyeden** uzun sürerse durdurulur ("script took too long").
- Yığın taşması (`RangeError: Maximum call stack size exceeded`), bellek dolması (`out of memory`), sözdizimi hataları
  ve yakalanmayan hatalar pencerede `dosya.js:satır:sütun` bilgili hata ekranı olarak görünür; **Yeniden Yükle**
  düğmesi uygulamayı sıfırdan başlatır, **Kopyala** hatayı panoya alır.
- `import` yalnızca uygulama paketinin içindeki dosyaları yükleyebilir.

## Bilgisayarda kontrol

```
node tools/js_check.mjs romfs/Applications/hellojs.nxvapp
```

`app.json`'u, tüm `.js` dosyalarının sözdizimini, kullanılan `TR("anahtar")` çevirilerinin `lang/en.json` ve
`lang/tr.json` içinde bulunmasını kontrol eder, ardından uygulamayı sahte bir SDK ile birkaç yüz kare çalıştırır
(rastgele tıklamalar, menüler, kapatma). Bu denetim Node.js ile yapılır; asıl deneme için uygulamayı Ryujinx'te
veya konsolda açın (`sdmc:/NexvynOS/autorun.txt` içinde `launch hellojs` satırı).
