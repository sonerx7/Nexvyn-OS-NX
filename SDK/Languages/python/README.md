# Nexvyn OS in Python

**English** · [Türkçe](README.tr.md)

Python apps run on the pocketpy 2 interpreter (Python 3 syntax: classes, comprehensions, f-strings, decorators,
`match`). The SDK modules are built in, no `import` needed. Needs SDK 1.3.

## Ready-made template

[`template/`](template/) is the smallest app that passes the checker. Copy it, or run
`python SDK/Tools/nxv/nxv.py new py "My App" --author yourname`.

## Program structure

A module-level `app` object (or plain `def draw(w, h):` functions), as in the code above. Optional arguments can be
passed by name (`style="primary"`). An app that defines `update` is redrawn every frame; one without it only when
something changes (battery friendly). Asynchronous calls take callbacks: `net.json(url, lambda data, err: ...)`.

## Running it

- **Studio:** **New Project → Blank Python App** or *Snake (Python)*, **Run** (Ctrl+R).
- **Console / Ryujinx:** copy the folder into `NexvynOS/Applications/` (`nxv push` / `nxv install`).

## Checking it on a PC

From the root of the Nexvyn OS source repository:

    python tools/py_check.py <path>/MyApp.nxvapp --frames 600

It finds constructs the console's interpreter does not support (with line numbers), checks the `TR` keys and the
`network` permission, and runs the app against a mock SDK with the real signatures (wrong argument counts and keyword
names fail too).

## Common pitfalls (pocketpy differences)

- **No generator expressions:** `sum([x for x in a])` instead of `sum(x for x in a)`.
- **No implicit string concatenation:** `"a" + "b"` instead of `"a" "b"`.
- **No `nonlocal`, `try ... finally`, `async`/`await`;** `list(a) + [1]` instead of `[*a, 1]`; `{"a": 1}` instead of `dict(a=1)`.
- **No `open()` or `os`:** use `fs.read`, `fs.write`, `store`.
- **Indexes start at 0,** no value is `None`, several results are tuples: `w, h = gfx.size()`.
- **`ui.textfield` returns only the text;** `ui.submitted("id")` reports Enter.
- `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys` come from the system library (SDK 1.5).

## More

- SDK: [SDK.md](../../Reference/SDK.en.md) section 12 · Guide: [PY_APPS.md](../../Guides/PY_APPS.en.md)
- Samples: [Samples/python](../../Samples/README.md#python)
