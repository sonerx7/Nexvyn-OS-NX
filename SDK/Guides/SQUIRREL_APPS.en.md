# A Nexvyn OS app in Squirrel

[Türkçe](SQUIRREL_APPS.tr.md) · **English**

Squirrel is a small language common in game engines, with a syntax close to C++ and JavaScript (classes,
inheritance, closures, generators, separate integers and floats). In Nexvyn OS the API is the same as in Lua/Python;
full reference: `sdk/SDK.en.md` section 13; working sample: `romfs/Applications/hellosq.nxvapp` ("Hello Squirrel").
Requires SDK 1.5.

## How to choose it

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "runtime": "squirrel", "main": "main.nut", "minSdk": "1.5",
 "window": {"width": 360, "height": 260, "resizable": false}, "permissions": []}
```

When the main file ends in `.nut`, Squirrel is selected even without `"runtime"`. In Studio, the **New Project → Empty
Squirrel app** template gives you a ready start.

## The smallest app

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

`main.nut` returns the app (a class instance or a table); if it returns nothing, `load`, `draw`... are looked up as
global functions. Other files are loaded with `import("yardimci")` (`yardimci.nut`, runs once, gives back the value it
returns).

## Differences from Lua

| Topic | Squirrel |
|---|---|
| Indexes | start at 0 (`ui.segmented`, `ui.alert` button order, `g3d.custom`) |
| No value | `null` |
| Several results | an array: `local s = gfx.size(); s[0], s[1]`; the same for `ui.mouse()`, `sys.battery()`, `input.stick()` |
| `ui.textfield` | returns the new text only; `ui.submitted("id")` for Enter |
| `ui.row` | `0` nothing, `1` clicked, `2` double-clicked |
| Records | tables: `e.type`, `res.ok`, `d.hour` |
| Division | `5 / 2` → `2` (integer), `5 / 2.0` → `2.5` |
| Asynchronous | callbacks: `net.json(url, function(veri, hata) { ... })`; inside the callback `this` is the app |
| Mesh | `m.setColor(renk)`, `m.flat(true)`, `m.setTexture(yol)` |

Careful: array/table defaults given to class fields are shared between all instances; create them in `load`
(`yapilacaklar = [];`).

## Limits and checking

64 MB of memory per window, 3 seconds per callback (checked on every loop; catching the error does not help). Errors
appear on the error screen with line numbers, and `print` output goes to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.
Checking on the PC: `python tools/rt_check.py Uygulamam.nxvapp` (SDK names, argument counts, brackets, translations,
`network` permission).
