# Language pack: Python (pocketpy 2)

**English** · [Türkçe](python.tr.md)

Add this after `system-prompt.en.md` when the app is written in Python.

## Skeleton

```python
# main.py: the SDK modules (gfx, ui, store, net, sys, timer, theme, json, TR...) are built in, no import needed
from model import Model             # other .py files of the bundle

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

app.json: `"main": "main.py"`, `"minSdk": "1.3"` (`"1.5"` for the system library modules below).

## Rules

- Indexes 0-based, `None` for no value, several results are tuples (`w, h = gfx.size()`).
- Optional arguments by name: `gfx.text("Hi", 10, 10, size=20, font="bold")`, `ui.button(..., style="primary")`.
- Records (events, `sys.date()`, `ui.hit()`, `res`, `fs.list()` entries) have attributes and dict access: `e.type`, `e["key"]`.
- `ui.textfield` returns the text only; `ui.submitted(id)`. `ui.row` returns 0/1/2.
- Async calls take callbacks (no Promises): `net.get(url, cb, headers)`, `net.json(url, cb)` → `cb(data, error)`,
  `ui.alert(title, msg, buttons, cb)` (0-based), `timer.after(sec, fn)`.
- Define `update(dt)` only for animation: an app without it is redrawn only when something changes.
- **pocketpy limits:** no generator expressions (`sum([x for x in a])`), no implicit string concatenation, no
  `nonlocal`, no `try ... finally`, no `async`/`await`, no `[*a, 1]` (use `list(a) + [1]`), some built-ins take no
  keyword arguments (`{"a": 1}`, not `dict(a=1)`). No `os`, `open()`, `socket`, `threading`; `.pyc` files are not loaded.
- Standard modules: math, random, time, json, collections, functools, heapq, bisect, dataclasses, datetime, operator,
  typing; SDK 1.5 system library: itertools, string, textwrap, copy, statistics, base64, colorsys.
- `sys` is merged with Python's `sys`; `exit()` closes the window; `input()` returns `""`.

## Check

`python tools/py_check.py <bundle> --frames 600`: finds unsupported constructs with line numbers, checks the TR keys
and the network permission, runs the app against a mock SDK with the real signatures.
