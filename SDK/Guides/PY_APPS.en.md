# A Nexvyn OS app in Python

[Türkçe](PY_APPS.tr.md) · **English**

Nexvyn OS apps (`.nxvapp`) can be written in Python as well as Lua and JavaScript. The API is the same; the full
reference is `sdk/SDK.en.md` (section 12 "Python"), and a working sample is `romfs/Applications/hellopy.nxvapp`
("Hello Python"). Python support arrived with SDK 1.3: put `"minSdk": "1.3"` in `app.json`.

## How to choose it

Make `main.py` the main file in `app.json`:

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "main": "main.py", "minSdk": "1.3", "window": {"width": 360, "height": 260, "resizable": false}}
```

When the main file's name ends in `.py`, or `"runtime": "python"` is set, the app opens with the Python interpreter
(pocketpy).

## The smallest app

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

The callbacks are the same as in Lua and JS: `load(arg)`, `open(arg)`, `update(dt)`, `draw(w, h)`, `event(e)`,
`menu()`, `onmenu(id)`, `close()`. You can give them in two ways:

- a module-level **`app`** object (a class instance as above; if you write `app = Sayac`, the class itself is
  instantiated),
- or, without defining `app`, plain functions directly in `main.py`: `def draw(w, h): ...`.

An app that defines `update` is redrawn every frame (games, animation); an app that does not is drawn only when
something changes, which saves battery.

The SDK modules (`gfx`, `ui`, `g3d`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `json`, `TR`)
are built in; no `import` is needed. Other files of the bundle are loaded with `import yardimci` /
`from yardimci import f` (`yardimci.py`, or `paket/__init__.py` for a subfolder). Of the standard modules, `math`,
`random`, `time`, `json`, `collections`, `functools`, `heapq`, `bisect`, `dataclasses` and `datetime` are available.

## Differences from Lua and JS (summary)

- **Arrays start at 0** (as in JS): the selected index of `ui.segmented` and `ui.dropdown`, the button index of
  `ui.alert`, `g3d.custom` indices.
- **`None` instead of `nil`/`null`:** `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` return `None`
  on failure.
- **Several return values become a tuple:** `w, h = gfx.size()`, `x, y = input.stick()`,
  `yuzde, sarj = sys.battery()`, `sy, sx = ui.beginScroll(...)`.
- **Named arguments:** every optional argument can also be given by name:
  `gfx.text("Merhaba", 20, 20, size=18, font="bold")`, `ui.button("Tamam", x, y, 100, 32, style="primary")`.
  Function names are the SDK's (`textWidth`, `beginScroll`, `iconButton`...).
- **Records:** events, `sys.date()`, `ui.hit()`, network responses and `fs.list()` items are objects with attributes:
  `e.type`, `d.hour`, `res.ok`; they can also be read like a dict: `e["key"]`, `res.get("body")`.
- **Colors:** `"#RRGGBB"`, a `(r, g, b[, a])` tuple/list or `{"r": .., "g": .., "b": ..}`; `gfx.color(r, g, b)`.
- **`ui.textfield` returns only the text;** `ui.submitted("id")` tells you Enter was pressed.
  **`ui.row`** returns 0, 1 (clicked) or 2 (double-clicked).
- **Asynchronous calls take callbacks** (there are no Promises):
  `net.json(url, lambda veri, hata: ...)`, `net.get(url, geri_cagirma)`, `ui.alert(baslik, mesaj, ["Tamam",
  "İptal"], lambda i: ...)`, `net.download(url, yol, lambda ok, yol_veya_hata: ...)`. Without a callback the result is
  dropped.
- **Menu:** `menu()` returns a list of dicts:
  `[{"title": TR("dosya"), "items": [{"label": TR("yeni"), "id": 1}, "-"]}]`.
- **Log:** `print(...)` and `sys.log(...)` output goes to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.
- The `sys` module is merged with Python's `sys` module (`sys.platform` and `sys.argv` are there too). `exit()` and
  `sys.exit()` close the app's window; `input()` returns an empty string. There is no `open()` or `os`: use `fs.*` for
  files.

## Interpreter differences

The interpreter on the console is pocketpy (Python 3 syntax, small and fast). Some differences from CPython:

- There are no generator expressions: `sum([x for x in a])` instead of `sum(x for x in a)`.
- There is no implicit string concatenation: `"a" + "b"` instead of `"a" "b"`.
- `nonlocal`, `try ... finally` and `async`/`await` are not supported.
- Unpacking `*x` inside a list (`[*a, 1]`) does not work; write `list(a) + [1]`. Some built-in functions take no
  keyword arguments (`{"a": 1}` instead of `dict(a=1)`).

`tools/py_check.py` finds these patterns and reports them with line numbers.

## Limits and errors

- Every window runs its own Python interpreter (at most 16 Python windows at a time); the memory limit is **64 MB**.
  Past the limit the app is stopped with `MemoryError: out of memory`.
- A single callback that runs longer than **3 seconds** is stopped
  (`TimeoutError: script took too long (possible infinite loop)`). The stop holds even if the error is caught with
  `except`.
- Syntax errors and uncaught errors show up in the window as an error screen: the error line at the top, the trace in
  the form `File "main.py", line 12, in draw` below it. **Reload** restarts the app from scratch, **Copy** puts the
  error on the clipboard.
- `import` loads only `.py` files from the app bundle; compiled `.pyc` files are not loaded.
- Permissions are the same as in Lua and JS: an app installed from the SD card must ask for
  `"permissions": ["network"]` in `app.json` for `net.*`, `"files"` for files outside its own folders, `"launch"` for
  `sys.launch` / `nxv://` links, `"notifications"` for `sys.notify` / `sys.schedule` and `"games"` for `sys.games`
  (SDK 1.6). They are decided once at install time (the install sheet lists them, **Customize** turns single ones off);
  without the permission the call returns `False`. `sys.clipboard` needs no permission, and
  `sys.requestPermission` is the only prompt at run time.

## SDK 1.4 additions

- `sys.share(item)`, `sys.appUrl(id, arg=None)`, `sys.open("nxv://...")`, `sys.schedule(epoch, title, body=None,
  arg=None)` → id (`ValueError` for an invalid time), `sys.unschedule(id)`, `sys.scheduled()`,
  `sys.hasPermission(name)`, `sys.requestPermission(name, callback=None)` → `callback(granted)`, `sys.memory()` →
  `(used, limit)`.
- Callbacks: `search(query)` (`[{"title": ..., "arg": ...}]` for Quick Search), `suspend()`, `resume()`,
  `focus(focused)`, `autosave()`, `unsaved()` → `True`/`False`.

## System library (SDK 1.5)

Some standard modules pocketpy lacks come as pure Python in `romfs:/System/Python` and are used directly with
`import`: `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`. Their APIs are the same as in
CPython. A module of the same name in the bundle is used instead. For the whole standard library, use CPython
(`"runtime": "python3"`, section "CPython (python3)" below).

## CPython (python3)

Since Nexvyn OS 1.0.0 an app can also run on **CPython 3.12**, the reference Python, with its standard library:

```json
{"id": "com.adiniz.istatistik", "name": "Stats", "runtime": "python3", "main": "main.py", "minSdk": "1.6"}
```

None of the pocketpy differences above apply: generator expressions, `try`/`finally`, `nonlocal`, `async`/`await`,
`dataclasses`, `statistics`, `collections`, `datetime`, `re`, `json`, `hashlib`, `random`, `typing`... all work.
`open()` and `os` work too, under the same permissions as `fs.*` (bundle and data folder always; other paths with
`"files"`). The SDK is the same and also importable: `from nexvyn import gfx, ui, fs`.

| | `"python"` (pocketpy) | `"python3"` (CPython) |
|---|---|---|
| Language | Python 3 subset | full Python 3.12 |
| Standard library | `math`, `random`, `json`... + `romfs:/System/Python` | most of it (`lib.zip`, ~290 modules) |
| Start-up | instant | slower, several MB per window (to be measured on the console) |
| Windows at once | 16 | 4 |
| Applet mode | yes | no (memory) |
| Files | `fs.*` | `fs.*`, `open()`, `os` |

Not there: threads, `subprocess`, `ctypes`, `ssl` (use `net.*` for HTTPS), `unicodedata`, `sqlite3`, `asyncio`, C
extension modules from pip. `sys.exit()` closes the window. Full list: `sdk/SDK.en.md`, section 12, "CPython". A
working sample is `romfs/Applications/hellopy3.nxvapp`; `python tools/py_check.py` checks python3 bundles with this
PC's Python (3.12) instead of the pocketpy rules (`--cpython` forces it for any bundle).

## Checking on the PC

```
python tools/py_check.py romfs/Applications/hellopy.nxvapp
```

It checks `app.json`, the syntax of every `.py` file and the patterns that do not work on the console, that every
`TR("key")` translation used exists in `lang/en.json` and `lang/tr.json`, and that an app using `net.*` asks for the
`network` permission; then it runs the app for a few hundred frames against a fake SDK built with the real signatures
(random clicks, keys, timers, callbacks, menus, closing). The check runs in CPython; for the real test open the app in
Ryujinx or on the console (a `launch hellopy` line in `sdmc:/NexvynOS/autorun.txt`).
