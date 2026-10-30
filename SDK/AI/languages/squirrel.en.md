# Language pack: Squirrel 3.2

**English** · [Türkçe](squirrel.tr.md)

Add this after `system-prompt.en.md` when the app is written in Squirrel.

## Skeleton

```squirrel
// main.nut
local Util = import("util");            // runs util.nut once and returns its result

class App {
    count = 0;
    items = null;                       // never [] or {} here: class defaults are shared by all instances

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

## Rules

- Results follow the Python rules: 0-based indexes, several results as arrays (`local s = gfx.size(); s[0]`),
  `ui.textfield` returns the text and `ui.submitted(id)` reports Enter, `ui.row` returns 0/1/2, records are tables
  (`e.type`, `res.ok`), `null` = no value.
- Reading a table slot that does not exist throws: read `e.key` only for key events and `e.pad` only for pad events;
  test with `t.rawin("slot")`.
- Integer division: `5 / 2` is `2`; use `5 / 2.0` or `.tofloat()`. `.tointeger()` converts back.
- Callbacks (timers, `net`, dialogs) run with `this` = the app: `net.json(url, function(data, err) { weather = data; })`.
- Standard library: math (`sin`, `cos`, `sqrt`, `floor`, `rand`, `srand`, `PI`...) and string (`format`, `split`,
  `strip`, `regexp`...). No io or system library: use `fs` and `sys`.
- Arrays: `append`, `insert(i, v)`, `remove(i)` (returns the value), `pop()`, `len()`, `filter(@(i, v) ...)`, `map`,
  `sort`. Tables: `{a = 1}`; add new slots with `<-`.
- Meshes are `Mesh` instances: `m.setColor(c)`, `m.flat(true)`, `m.triangles()`, `m.setTexture(p)`, `m.free()`.
- Limits: 64 MB, 3 s per callback (checked on every loop; catching the error does not help).

## Check

`python tools/rt_check.py <bundle>`: balanced brackets and strings, every SDK call exists with a valid argument
count, imported files exist, TR keys, the network permission. It does not execute the code.
