# Python ile Nexvyn OS uygulaması

**Türkçe** · [English](PY_APPS.en.md)

Nexvyn OS uygulamaları (`.nxvapp`) Lua ve JavaScript'in yanında Python ile de yazılabilir. API aynıdır; tam başvuru
kaynağı `sdk/SDK.tr.md` (bölüm 12 "Python"), çalışan örnek `romfs/Applications/hellopy.nxvapp` ("Merhaba Python").
Python desteği SDK 1.3 ile geldi: `app.json` içine `"minSdk": "1.3"` yazın.

## Nasıl seçilir

`app.json` içinde ana dosyayı `main.py` yapın:

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "main": "main.py", "minSdk": "1.3", "window": {"width": 360, "height": 260, "resizable": false}}
```

Ana dosyanın adı `.py` ile bitiyorsa ya da `"runtime": "python"` yazılmışsa uygulama Python yorumlayıcısıyla
(pocketpy) açılır.

## En küçük uygulama

```python
class Sayac:
    def load(self, arg):
        self.sayi = store.get("sayi", 0)

    def draw(self, w, h):
        gfx.clear(theme.bg)
        gfx.color(theme.text)
        gfx.text(str(self.sayi), 0, 60, 48, "bold", "center", w)
        if ui.button("+1", w / 2 - 50, 140, 100, 34, "primary"):
            self.sayi += 1
            store.set("sayi", self.sayi)


app = Sayac()
```

Geri çağırmalar Lua ve JS ile aynıdır: `load(arg)`, `open(arg)`, `update(dt)`, `draw(w, h)`, `event(e)`, `menu()`,
`onmenu(id)`, `close()`. Bunları iki şekilde verebilirsiniz:

- modül düzeyinde bir **`app`** nesnesi (yukarıdaki gibi bir sınıf örneği; `app = Sayac` yazarsanız sınıf kendisi
  örneklenir),
- ya da `app` tanımlamadan doğrudan `main.py` içinde fonksiyonlar: `def draw(w, h): ...`.

`update` tanımlayan uygulama her karede yeniden çizilir (oyunlar, animasyon); tanımlamayan uygulama yalnızca bir şey
değiştiğinde çizilir ve pil tasarrufu sağlar.

SDK modülleri (`gfx`, `ui`, `g3d`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `json`, `TR`)
hazır gelir, `import` gerekmez. Paketteki diğer dosyalar `import yardimci` / `from yardimci import f` ile yüklenir
(`yardimci.py`, alt klasör için `paket/__init__.py`). Standart modüllerden `math`, `random`, `time`, `json`,
`collections`, `functools`, `heapq`, `bisect`, `dataclasses`, `datetime` vardır.

## Lua'dan ve JS'den farklar (özet)

- **Diziler 0'dan başlar** (JS gibi): `ui.segmented`, `ui.dropdown` seçili indeksi, `ui.alert` düğme indeksi,
  `g3d.custom` indeksleri.
- **`nil`/`null` yerine `None`:** `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` başarısız
  olursa `None` döner.
- **Çoklu dönüş değerleri demet (tuple) olur:** `w, h = gfx.size()`, `x, y = input.stick()`,
  `yuzde, sarj = sys.battery()`, `sy, sx = ui.beginScroll(...)`.
- **İsimli argümanlar:** isteğe bağlı her argüman adıyla da verilebilir:
  `gfx.text("Merhaba", 20, 20, size=18, font="bold")`, `ui.button("Tamam", x, y, 100, 32, style="primary")`.
  Fonksiyon adları SDK'daki gibidir (`textWidth`, `beginScroll`, `iconButton`...).
- **Kayıtlar:** olaylar, `sys.date()`, `ui.hit()`, ağ yanıtları ve `fs.list()` öğeleri özellikli nesnelerdir:
  `e.type`, `d.hour`, `res.ok`; sözlük gibi de okunabilir: `e["key"]`, `res.get("body")`.
- **Renkler:** `"#RRGGBB"`, `(r, g, b[, a])` demeti/listesi veya `{"r": .., "g": .., "b": ..}`; `gfx.color(r, g, b)`.
- **`ui.textfield` yalnızca metni döndürür;** Enter'a basıldığını `ui.submitted("id")` söyler.
  **`ui.row`** 0, 1 (tıklandı) veya 2 (çift tıklandı) döndürür.
- **Asenkron çağrılar geri çağırma alır** (Promise yoktur):
  `net.json(url, lambda veri, hata: ...)`, `net.get(url, geri_cagirma)`, `ui.alert(baslik, mesaj, ["Tamam",
  "İptal"], lambda i: ...)`, `net.download(url, yol, lambda ok, yol_veya_hata: ...)`. Geri çağırma vermezseniz
  sonuç atılır.
- **Menü:** `menu()` sözlük listesi döndürür:
  `[{"title": TR("dosya"), "items": [{"label": TR("yeni"), "id": 1}, "-"]}]`.
- **Günlük:** `print(...)` ve `sys.log(...)` çıktısı `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.
- `sys` modülü Python'un `sys` modülüyle birleşiktir (`sys.platform`, `sys.argv` de vardır). `exit()` ve
  `sys.exit()` uygulama penceresini kapatır; `input()` boş metin döndürür. `open()` ve `os` yoktur: dosyalar için
  `fs.*` kullanın.

## Yorumlayıcı farkları

Konsoldaki yorumlayıcı pocketpy'dir (Python 3 sözdizimi, küçük ve hızlı). CPython'dan bazı farkları:

- Üreteç ifadeleri yoktur: `sum(x for x in a)` yerine `sum([x for x in a])`.
- Yan yana metin birleştirme yoktur: `"a" "b"` yerine `"a" + "b"`.
- `nonlocal`, `try ... finally` ve `async`/`await` desteklenmez.
- Liste içinde `*x` açma (`[*a, 1]`) çalışmaz; `list(a) + [1]` yazın. Bazı yerleşik fonksiyonlar isimli argüman
  almaz (`dict(a=1)` yerine `{"a": 1}`).

`tools/py_check.py` bu kalıpları bulur ve satır numarasıyla bildirir.

## Sınırlar ve hatalar

- Her pencere kendi Python yorumlayıcısını çalıştırır (aynı anda en fazla 16 Python penceresi); bellek sınırı
  **64 MB**. Sınır aşılırsa uygulama `MemoryError: out of memory` hatasıyla durdurulur.
- Tek bir geri çağırma **3 saniyeden** uzun sürerse durdurulur
  (`TimeoutError: script took too long (possible infinite loop)`). Hata `except` ile yakalansa bile durdurma sürer.
- Sözdizimi hataları ve yakalanmayan hatalar pencerede hata ekranı olarak görünür: en üstte hata satırı, altında
  `File "main.py", line 12, in draw` biçimindeki iz. **Yeniden Yükle** uygulamayı sıfırdan başlatır, **Kopyala**
  hatayı panoya alır.
- `import` yalnızca uygulama paketindeki `.py` dosyalarını yükler; derlenmiş `.pyc` dosyaları yüklenmez.
- İzinler Lua ve JS ile aynıdır: SD karttan kurulan uygulama `net.*` için `app.json` içinde
  `"permissions": ["network"]`, kendi klasörleri dışındaki dosyalar için `"files"`, `sys.launch` / `nxv://`
  bağlantıları için `"launch"`, `sys.notify` / `sys.schedule` için `"notifications"` istemelidir (SDK 1.4'ten beri
  hepsi zorunlu; izin yoksa çağrı `False` döner). `sys.clipboard` izin istemez.

## SDK 1.4 eklemeleri

- `sys.share(oge)`, `sys.appUrl(id, arg=None)`, `sys.open("nxv://...")`, `sys.schedule(epoch, baslik, govde=None,
  arg=None)` → kimlik (geçersiz zamanda `ValueError`), `sys.unschedule(id)`, `sys.scheduled()`,
  `sys.hasPermission(ad)`, `sys.requestPermission(ad, callback=None)` → `callback(verildi)`, `sys.memory()` →
  `(kullanilan, sinir)`.
- Geri çağırmalar: `search(sorgu)` (Hızlı Arama için `[{"title": ..., "arg": ...}]`), `suspend()`, `resume()`,
  `focus(odakta)`, `autosave()`, `unsaved()` → `True`/`False`.

## Sistem kütüphanesi (SDK 1.5)

pocketpy'de olmayan bazı standart modüller `romfs:/System/Python` içinde saf Python olarak gelir ve `import` ile
doğrudan kullanılır: `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`. API'leri CPython
ile aynıdır. Pakette aynı adlı bir modül varsa o kullanılır. Standart kütüphanenin tamamı için CPython'u kullanın (`"runtime": "python3"`, aşağıda "CPython (python3)" bölümü).

## CPython (python3)

Nexvyn OS 1.0.0'dan beri bir uygulama, standart kütüphanesiyle birlikte referans Python olan **CPython 3.12** ile de
çalışabilir:

```json
{"id": "com.adiniz.istatistik", "name": "İstatistik", "runtime": "python3", "main": "main.py", "minSdk": "1.6"}
```

Yukarıdaki pocketpy farklarının hiçbiri geçerli değildir: generator expression'lar, `try`/`finally`, `nonlocal`,
`async`/`await`, `dataclasses`, `statistics`, `collections`, `datetime`, `re`, `json`, `hashlib`, `random`,
`typing`... hepsi çalışır. `open()` ve `os` de çalışır; `fs.*` ile aynı izinlerle (bundle ve veri klasörü her zaman,
diğer yollar `"files"` ile). SDK aynıdır ve import da edilebilir: `from nexvyn import gfx, ui, fs`.

| | `"python"` (pocketpy) | `"python3"` (CPython) |
|---|---|---|
| Dil | Python 3'ün bir alt kümesi | Python 3.12'nin tamamı |
| Standart kütüphane | `math`, `random`, `json`... + `romfs:/System/Python` | büyük kısmı (`lib.zip`, ~290 modül) |
| Açılış | anında | daha yavaş, pencere başına birkaç MB (konsolda ölçülecek) |
| Aynı anda pencere | 16 | 4 |
| Applet modu | evet | hayır (bellek) |
| Dosyalar | `fs.*` | `fs.*`, `open()`, `os` |

Olmayanlar: thread'ler, `subprocess`, `ctypes`, `ssl` (HTTPS için `net.*`), `unicodedata`, `sqlite3`, `asyncio`, pip'ten
C extension modülleri. `sys.exit()` pencereyi kapatır. Tam liste: `sdk/SDK.tr.md`, bölüm 12, "CPython". Çalışan bir
örnek `romfs/Applications/hellopy3.nxvapp`; `python tools/py_check.py`, python3 bundle'larını pocketpy kuralları yerine
bu bilgisayarın Python'u (3.12) ile kontrol eder (`--cpython` her bundle için zorlar).

## Bilgisayarda kontrol

```
python tools/py_check.py romfs/Applications/hellopy.nxvapp
```

`app.json`'u, tüm `.py` dosyalarının sözdizimini ve konsolda çalışmayan kalıpları, kullanılan `TR("anahtar")`
çevirilerinin `lang/en.json` ve `lang/tr.json` içinde bulunmasını ve `net.*` kullanan uygulamanın `network` iznini
istemesini kontrol eder; ardından uygulamayı gerçek imzalarla kurulmuş sahte bir SDK ile birkaç yüz kare çalıştırır
(rastgele tıklamalar, tuşlar, zamanlayıcılar, geri çağırmalar, menüler, kapatma). Denetim CPython ile yapılır; asıl
deneme için uygulamayı Ryujinx'te veya konsolda açın (`sdmc:/NexvynOS/autorun.txt` içinde `launch hellopy` satırı).
