# Language pack: Python (pocketpy 2)

[English](python.en.md) · **Türkçe**

Uygulama Python ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin.

## İskelet

```python
# main.py: SDK modülleri (gfx, ui, store, net, sys, timer, theme, json, TR...) yerleşiktir, import gerekmez
from model import Model             # bundle'ın diğer .py dosyaları

class App:
    def load(self, arg):
        self.model = Model(store.get("items", []))
        self.error = ""

    def draw(self, w, h):
        gfx.clear(theme.bg)
        gfx.color(theme.text)
        gfx.text(TR("title"), 0, 24, 24, "bold", "center", w)
        if ui.button(TR("refresh"), 20, 70, 140, 34, style="primary"):
            net.json("https://example.com/api.json", self.on_data)

    def on_data(self, data, error):
        if error is not None:
            self.error = error
        else:
            self.model.items = data["items"]

    def menu(self):
        return [{"title": TR("app"), "items": [{"label": TR("reset"), "id": 1}]}]

    def onmenu(self, item_id):
        if item_id == 1:
            self.model.reset()

app = App()
```

app.json: `"main": "main.py"`, `"minSdk": "1.3"` (aşağıdaki sistem kütüphanesi modülleri için `"1.5"`).

## Kurallar

- İndeksler 0 tabanlı, değer yok için `None`, birden çok sonuç tuple'dır (`w, h = gfx.size()`).
- İsteğe bağlı argument'lar adıyla verilebilir: `gfx.text("Hi", 10, 10, size=20, font="bold")`,
  `ui.button(..., style="primary")`.
- Record'lar (event'ler, `sys.date()`, `ui.hit()`, `res`, `fs.list()` girdileri) öznitelikle ve dict gibi okunur:
  `e.type`, `e["key"]`.
- `ui.textfield` yalnızca metni döndürür; `ui.submitted(id)`. `ui.row` 0/1/2 döndürür.
- async çağrılar callback alır (Promise yok): `net.get(url, cb, headers)`, `net.json(url, cb)` →
  `cb(data, error)`, `ui.alert(title, msg, buttons, cb)` (0 tabanlı), `timer.after(sec, fn)`.
- `update(dt)`'yi yalnızca animasyon için tanımla: onsuz bir uygulama yalnızca bir şey değişince yeniden çizilir.
- **pocketpy sınırları:** generator expression yok (`sum([x for x in a])`), örtük metin birleştirme yok, `nonlocal` yok,
  `try ... finally` yok, `async`/`await` yok, `[*a, 1]` yok (`list(a) + [1]` kullan), bazı yerleşikler anahtar
  sözcüklü argument almaz (`dict(a=1)` değil, `{"a": 1}`). `os`, `open()`, `socket`, `threading` yok; `.pyc`
  dosyaları yüklenmez.
- Standart modüller: math, random, time, json, collections, functools, heapq, bisect, dataclasses, datetime, operator,
  typing; SDK 1.5 sistem kütüphanesi: itertools, string, textwrap, copy, statistics, base64, colorsys.
- `sys` Python'un `sys`'iyle birleşiktir; `exit()` pencereyi kapatır; `input()` `""` döndürür.

## Denetim

`python tools/py_check.py <bundle> --frames 600`: desteklenmeyen yapıları satır numaralarıyla bulur, TR anahtarlarını
ve ağ iznini denetler, uygulamayı gerçek imzalarla kurulmuş mock bir SDK'ya karşı çalıştırır.
