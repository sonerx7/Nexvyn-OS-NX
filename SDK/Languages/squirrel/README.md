# Nexvyn OS in Squirrel

**English** · [Türkçe](README.tr.md)

Squirrel 3.2 is a small language used in game engines, with syntax close to C++ and JavaScript: classes and
inheritance, closures, lambdas (`@(x) x * 2`), generators, `foreach`, integers and floats (`5 / 2` is `2`). The SDK
modules are global tables. Needs SDK 1.5.

## Ready-made template

[`template/`](template/) is the smallest app that passes the checker. Copy it, or run
`python SDK/Tools/nxv/nxv.py new sq "My App" --author yourname`.

## Program structure

`main.nut` returns the app (a class instance or a table); if it returns nothing, `load`, `draw`... are looked up as
global functions (see the code above). Other files: `local Clock = import("clock");` (`clock.nut` runs once and its
result is returned). Inside callbacks (`timer`, `net`, dialogs) `this` is the app:
`net.json(url, function(data, err) { weather = data; })`.

## Running it

- **Studio:** **New Project → Blank Squirrel App**, **Run** (Ctrl+R).
- **Console / Ryujinx:** copy the folder into `NexvynOS/Applications/` (`nxv push` / `nxv install`).

## Checking it on a PC

From the root of the Nexvyn OS source repository:

    python tools/rt_check.py <path>/MyApp.nxvapp

It checks strings, comments and brackets, that every SDK call names a real function with an accepted argument count,
that imported files exist, the `TR` keys and the `network` permission. It does not run the code: try the logic on
the console or in Ryujinx.

## Common pitfalls

- **Array/table defaults of class fields are shared by every instance:** write `items = null` and create the array in
  `load()`.
- **Integer division:** `5 / 2` is `2`; use `5 / 2.0` or `.tofloat()`.
- **A missing table slot is an error:** `e.key` exists only on keyboard events and `e.pad` only on pad events; look
  at `e.type` first or use `t.rawin("slot")`.
- **Indexes start at 0,** several results are arrays: `local s = gfx.size(); s[0], s[1]`; `ui.mouse()` → `[x, y, down, hover]`.
- **`ui.textfield` returns only the text;** `ui.submitted("id")` reports Enter. `ui.row` returns 0/1/2.
- There is no `io` or system library: use `fs` and `sys`.

## More

- SDK: [SDK.md](../../Reference/SDK.en.md) section 13 · Guide: [SQUIRREL_APPS.md](../../Guides/SQUIRREL_APPS.en.md)
- Samples: [Samples/squirrel](../../Samples/README.md#squirrel) (Hello Squirrel, Stopwatch, Snake)
