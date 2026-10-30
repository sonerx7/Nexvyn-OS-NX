# Python ile Nexvyn OS

[English](README.md) · **Türkçe**

Python uygulamaları pocketpy 2 yorumlayıcısıyla çalışır (Python 3 söz dizimi: sınıflar, liste kavramaları,
f-string, dekoratörler, `match`). SDK modülleri hazırdır, `import` gerekmez. SDK 1.3 gerekir.

## Hazır şablon

[`template/`](template/) denetleyiciden geçen en küçük uygulamadır. Kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new py "Benim Uygulamam" --author adiniz

## app.json

```json
{"id": "com.adiniz.uygulamam", "name": {"en": "My App", "tr": "Uygulamam"}, "version": "1.0",
 "category": "utilities", "icon": "icon.png", "main": "main.py", "minSdk": "1.3",
 "window": {"width": 560, "height": 400, "resizable": true}, "gamepad": false, "permissions": []}
```

## Program yapısı

Modül düzeyinde bir `app` nesnesi (ya da doğrudan `def draw(w, h):` fonksiyonları):

```python
class App:
    def load(self, arg):
        self.n = store.get("n", 0)

    def draw(self, w, h):
        gfx.clear(theme.bg)
        gfx.color(theme.text)
        gfx.text(TR("hello"), 0, h / 2, 24, "bold", "center", w)
        if ui.button("+1", w / 2 - 50, h / 2 + 40, 100, 34, style="primary"):
            self.n += 1
            store.set("n", self.n)

    def menu(self):
        return [{"title": TR("app"), "items": [{"label": TR("reset"), "id": 1}]}]

app = App()
```

`update` tanımlayan uygulama her karede yeniden çizilir; tanımlamayan yalnızca bir şey değişince çizilir (pil
dostu). Asenkron çağrılar geri çağırma alır: `net.json(url, lambda veri, hata: ...)`.

## Çalıştırma

- **Studio:** **Yeni Proje → Boş Python uygulaması** ya da *Yılan (Python)*, **Çalıştır** (Ctrl+R).
- **Konsol / Ryujinx:** klasörü `NexvynOS/Applications/` içine kopyalayın (`nxv push` / `nxv install`).

## PC'de denetim

Nexvyn OS kaynak deposunun kökünden:

    python tools/py_check.py <yol>/BenimUygulamam.nxvapp --frames 600

Konsoldaki yorumlayıcının desteklemediği kalıpları satır numarasıyla bulur, `TR` anahtarlarını ve `network` iznini
denetler, uygulamayı gerçek imzalarla kurulmuş sahte SDK ile çalıştırır (yanlış argüman sayısı ve adı da yakalanır).

## Sık yapılan hatalar (pocketpy farkları)

- **Üreteç ifadesi yok:** `sum(x for x in a)` yerine `sum([x for x in a])`.
- **Yan yana metin birleştirme yok:** `"a" "b"` yerine `"a" + "b"`.
- **`nonlocal`, `try ... finally`, `async`/`await` yok;** `[*a, 1]` yerine `list(a) + [1]`; `dict(a=1)` yerine `{"a": 1}`.
- **`open()` ve `os` yok:** `fs.read`, `fs.write`, `store` kullanın.
- **Dizinler 0'dan başlar,** boş değer `None`, çoklu sonuçlar demet: `w, h = gfx.size()`.
- **`ui.textfield` yalnızca metni döndürür;** Enter için `ui.submitted("id")`.
- `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys` sistem kütüphanesindedir (SDK 1.5).

## Daha fazlası

- SDK: [SDK.md](../../Reference/SDK.tr.md) bölüm 12 · Rehber: [PY_APPS.md](../../Guides/PY_APPS.tr.md)
- Örnekler: [Samples/python](../../Samples/README.tr.md#python)
