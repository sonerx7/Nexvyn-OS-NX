# Squirrel ile Nexvyn OS

[English](README.md) · **Türkçe**

Squirrel 3.2, oyun motorlarında sık kullanılan, C++ ve JavaScript'e benzeyen küçük bir dildir: sınıflar ve kalıtım,
kapanışlar, lambdalar (`@(x) x * 2`), üreteçler, `foreach`, tamsayı ve ondalık ayrımı (`5 / 2` = `2`). SDK modülleri
genel tablolardır. SDK 1.5 gerekir.

## Hazır şablon

[`template/`](template/) denetleyiciden geçen en küçük uygulamadır. Kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new sq "Benim Uygulamam" --author adiniz

## app.json

```json
{"id": "com.adiniz.uygulamam", "name": {"en": "My App", "tr": "Uygulamam"}, "version": "1.0",
 "category": "utilities", "icon": "icon.png", "runtime": "squirrel", "main": "main.nut", "minSdk": "1.5",
 "window": {"width": 560, "height": 400, "resizable": true}, "gamepad": false, "permissions": []}
```

## Program yapısı

`main.nut` uygulamayı (bir sınıf örneği ya da tablo) döndürür; döndürmezse `load`, `draw`... genel fonksiyonlar
olarak aranır:

```squirrel
class App {
    n = 0;
    items = null;                       // dizi/tablo varsayılanları paylaşılır: load() içinde oluşturun
    function load(arg) { n = store.get("n", 0); items = []; }
    function draw(w, h) {
        gfx.clear(theme.bg);
        gfx.color(theme.text);
        gfx.text(TR("hello"), 0, h / 2, 24, "bold", "center", w);
        if (ui.button("+1", w / 2 - 50, h / 2 + 40, 100, 34, "primary")) store.set("n", ++n);
    }
    function menu() { return [{title = TR("app"), items = [{label = TR("reset"), id = 1}]}]; }
    function onmenu(id) { if (id == 1) store.set("n", n = 0); }
}
return App();
```

Diğer dosyalar: `local Saat = import("saat");` (`saat.nut` bir kez çalışır, döndürdüğü değer gelir). Geri çağırmalarda
(`timer`, `net`, iletişim kutuları) `this` uygulamadır: `net.json(url, function(veri, hata) { hava = veri; })`.

## Çalıştırma

- **Studio:** **Yeni Proje → Boş Squirrel uygulaması**, **Çalıştır** (Ctrl+R).
- **Konsol / Ryujinx:** klasörü `NexvynOS/Applications/` içine kopyalayın (`nxv push` / `nxv install`).

## PC'de denetim

Nexvyn OS kaynak deposunun kökünden:

    python tools/rt_check.py <yol>/BenimUygulamam.nxvapp

Metinleri, yorumları ve parantezleri, her SDK çağrısının gerçek bir fonksiyon olduğunu ve argüman sayısını,
`import` edilen dosyaların varlığını, `TR` anahtarlarını ve `network` iznini denetler. Kodu çalıştırmaz: mantık
hatalarını konsolda ya da Ryujinx'te deneyin.

## Sık yapılan hatalar

- **Sınıf alanındaki dizi/tablo varsayılanı tüm örneklerce paylaşılır:** `items = []` yerine `items = null` yazıp
  `load()` içinde oluşturun.
- **Tamsayı bölmesi:** `5 / 2` = `2`; ondalık için `5 / 2.0` ya da `.tofloat()`.
- **Olmayan tablo alanı hata verir:** `e.key` yalnızca klavye olaylarında, `e.pad` yalnızca kumanda olaylarında
  vardır; önce `e.type`'a bakın ya da `t.rawin("alan")` kullanın.
- **Dizinler 0'dan başlar,** çoklu sonuçlar dizidir: `local s = gfx.size(); s[0], s[1]`; `ui.mouse()` → `[x, y, down, hover]`.
- **`ui.textfield` yalnızca metni döndürür;** Enter için `ui.submitted("id")`. `ui.row` 0/1/2 döndürür.
- `io` ve sistem kütüphanesi yoktur: `fs`, `sys` kullanın.

## Daha fazlası

- SDK: [SDK.md](../../Reference/SDK.tr.md) bölüm 13 · Rehber: [SQUIRREL_APPS.md](../../Guides/SQUIRREL_APPS.tr.md)
- Örnekler: [Samples/squirrel](../../Samples/README.tr.md#squirrel) (Merhaba Squirrel, Kronometre, Yılan)
