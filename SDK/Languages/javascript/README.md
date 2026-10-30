# Nexvyn OS in JavaScript

**English** · [Türkçe](README.tr.md)

JavaScript apps run on QuickJS-ng (ES2023: classes, arrow functions, `async`/`await`, ES modules, `Map`/`Set`,
typed arrays). The API is the Lua one; the differences are below. Needs SDK 1.1.

## Ready-made template

[`template/`](template/) is the smallest app that passes the checker. Copy it, or run
`python SDK/Tools/nxv/nxv.py new js "My App" --author yourname`.

## app.json

The manifest above. A `main` ending in `.js`/`.mjs`, or `"runtime": "js"`, selects JavaScript.

## Program structure

`main.js` is an ES module. Assign the callbacks to the global `app` object (or `export default { load, draw }`), as
in the code above. Every asynchronous SDK function returns a Promise when you leave out the callback:
`const data = await net.fetchJson(url)`, `const i = await ui.alert(title, msg, ["OK", "Cancel"])`,
`await timer.sleep(0.5)`.

## Running it

- **Studio:** **New Project → Blank JS App** (or *Network app*), **Run** (Ctrl+R).
- **Console / Ryujinx:** copy the folder into `NexvynOS/Applications/` (`nxv push` / `nxv install`). `launch <id>` in
  `autorun.txt` opens it at boot.

## Checking it on a PC

From the root of the Nexvyn OS source repository (Node.js 18+):

    node tools/js_check.mjs <path>/MyApp.nxvapp --frames 600

It parses every `.js` file as an ES module, checks the `TR` keys and runs the app against a mock SDK, reporting
unhandled Promise rejections too. It is Node.js, not QuickJS: it catches API misuse, not engine differences.

## Common pitfalls

- **Arrays start at 0:** `ui.segmented`, `ui.dropdown`, `ui.alert` indexes and `g3d.custom` indices.
- **Several results are arrays:** `const [w, h] = gfx.size()`, `const [x, y] = input.stick("left")`.
- **`ui.textfield` returns only the text;** `ui.submitted("id")` reports Enter. `ui.row` returns 0/1/2.
- **No browser or Node API:** no `window`, `document`, `fetch`, `localStorage`, `require`, `process` or `Intl`. Use
  `net.fetch`, `store`, `fs`; `sys.date()` for local time.
- **An unhandled Promise rejection** opens the error screen: wrap `await` in `try`/`catch`.
- **`net.*` needs the `"network"` permission;** without it `res.error == "permission denied: network"`.

## More

- SDK: [SDK.md](../../Reference/SDK.en.md) section 11 · Guide: [JS_APPS.md](../../Guides/JS_APPS.en.md)
- Samples: [Samples/javascript](../../Samples/README.md#javascript)
