# Language pack: Squirrel 3.2

[English](squirrel.en.md) · **Türkçe**

Uygulama Squirrel ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin.

## İskelet

```squirrel
// main.nut
local Util = import("util");            // util.nut dosyasını bir kez çalıştırır ve sonucunu döndürür

class App {
    count = 0;
    items = null;                       // burada asla [] ya da {} yazma: sınıf varsayılanları tüm örneklerce paylaşılır

    function load(arg) {
        count = store.get("count", 0);
        items = store.get("items", []);
    }

    function draw(w, h) {
        gfx.clear(theme.bg);
        gfx.color(theme.text);
        gfx.text(TR("title"), 0, 24, 24, "bold", "center", w);
        if (ui.button(TR("add"), w / 2 - 60, 80, 120, 34, "primary")) {
            count++;
            store.set("count", count);
        }
    }

    function event(e) {
        if (e.type == "keydown" && e.key == "space") count++;
    }

    function menu() { return [{title = TR("app"), items = [{label = TR("reset"), id = 1}]}]; }
    function onmenu(id) { if (id == 1) count = 0; }
}

return App();
```

app.json: `"runtime": "squirrel"`, `"main": "main.nut"`, `"minSdk": "1.5"`.

## Kurallar

- Sonuçlar Python kurallarını izler: 0 tabanlı indeksler, birden çok sonuç dizi olarak
  (`local s = gfx.size(); s[0]`), `ui.textfield` metni döndürür ve `ui.submitted(id)` Enter'ı bildirir, `ui.row`
  0/1/2 döndürür, record'lar tablodur (`e.type`, `res.ok`), `null` = değer yok.
- Var olmayan bir tablo yuvasını okumak hata fırlatır: `e.key`'i yalnızca tuş event'lerinde, `e.pad`'i yalnızca kumanda
  event'lerinde oku; `t.rawin("slot")` ile sına.
- Tamsayı bölmesi: `5 / 2` `2`'dir; `5 / 2.0` ya da `.tofloat()` kullan. `.tointeger()` geri dönüştürür.
- callback'ler (timer'lar, `net`, iletişim kutuları) `this` = uygulama olarak çalışır:
  `net.json(url, function(data, err) { weather = data; })`.
- Standart kütüphane: math (`sin`, `cos`, `sqrt`, `floor`, `rand`, `srand`, `PI`...) ve string (`format`, `split`,
  `strip`, `regexp`...). io ya da system kütüphanesi yok: `fs` ve `sys` kullan.
- Diziler: `append`, `insert(i, v)`, `remove(i)` (değeri döndürür), `pop()`, `len()`, `filter(@(i, v) ...)`, `map`,
  `sort`. Tablolar: `{a = 1}`; yeni yuvaları `<-` ile ekle.
- Mesh'ler `Mesh` örnekleridir: `m.setColor(c)`, `m.flat(true)`, `m.triangles()`, `m.setTexture(p)`, `m.free()`.
- Sınırlar: 64 MB, callback başına 3 sn (her döngüde denetlenir; hatayı yakalamak işe yaramaz).

## Denetim

`python tools/rt_check.py <bundle>`: dengeli parantezler ve metinler, her SDK çağrısının geçerli bir argument
sayısıyla var olması, içe aktarılan dosyaların varlığı, TR anahtarları, ağ izni. Kodu çalıştırmaz.
