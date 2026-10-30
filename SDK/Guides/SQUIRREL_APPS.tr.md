# Squirrel ile Nexvyn OS uygulaması

**Türkçe** · [English](SQUIRREL_APPS.en.md)

Squirrel, oyun motorlarında sık kullanılan, sözdizimi C++ ve JavaScript'e benzeyen küçük bir dildir (sınıflar,
kalıtım, kapanışlar, üreteçler, tamsayı ve ondalık sayı ayrımı). Nexvyn OS'ta API Lua/Python ile aynıdır; tam başvuru
`sdk/SDK.tr.md` bölüm 13, çalışan örnek `romfs/Applications/hellosq.nxvapp` ("Merhaba Squirrel"). SDK 1.5 gerekir.

## Nasıl seçilir

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "runtime": "squirrel", "main": "main.nut", "minSdk": "1.5",
 "window": {"width": 360, "height": 260, "resizable": false}, "permissions": []}
```

Ana dosya `.nut` ile bitiyorsa `"runtime"` yazmasanız da Squirrel seçilir. Studio'da **Yeni Proje → Boş Squirrel
uygulaması** şablonu hazır bir başlangıç verir.

## En küçük uygulama

```squirrel
class Sayac {
    sayi = 0;
    function load(arg) { sayi = store.get("sayi", 0); }
    function draw(w, h) {
        gfx.clear(theme.bg);
        gfx.color(theme.text);
        gfx.text(sayi.tostring(), 0, 60, 48, "bold", "center", w);
        if (ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) {
            sayi++;
            store.set("sayi", sayi);
        }
    }
}
return Sayac();
```

`main.nut` uygulamayı (bir sınıf örneği ya da tablo) döndürür; döndürmezse `load`, `draw`... genel fonksiyonlar olarak
aranır. Diğer dosyalar `import("yardimci")` ile yüklenir (`yardimci.nut`, bir kez çalışır, döndürdüğü değer gelir).

## Lua'dan farkları

| Konu | Squirrel |
|---|---|
| İndeksler | 0'dan başlar (`ui.segmented`, `ui.alert` düğme sırası, `g3d.custom`) |
| Boş değer | `null` |
| Çoklu sonuç | dizi: `local s = gfx.size(); s[0], s[1]`; `ui.mouse()`, `sys.battery()`, `input.stick()` de öyle |
| `ui.textfield` | yalnızca yeni metni döndürür; Enter için `ui.submitted("id")` |
| `ui.row` | `0` hiçbir şey, `1` tıklandı, `2` çift tıklandı |
| Kayıtlar | tablo: `e.type`, `res.ok`, `d.hour` |
| Bölme | `5 / 2` → `2` (tamsayı), `5 / 2.0` → `2.5` |
| Asenkron | geri çağırma: `net.json(url, function(veri, hata) { ... })`; geri çağırmada `this` uygulamadır |
| Mesh | `m.setColor(renk)`, `m.flat(true)`, `m.setTexture(yol)` |

Dikkat: sınıf alanlarına verilen dizi/tablo varsayılanları tüm örnekler arasında paylaşılır; bunları `load` içinde
oluşturun (`yapilacaklar = [];`).

## Sınırlar ve denetim

Pencere başına 64 MB bellek, geri çağırma başına 3 saniye (her döngüde denetlenir, hatayı yakalamak işe yaramaz).
Hatalar satır numaralı hata ekranında görünür, `print` çıktısı `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına
gider. PC'de denetim: `python tools/rt_check.py Uygulamam.nxvapp` (SDK adları, argüman sayıları, parantezler,
çeviriler, `network` izni).
