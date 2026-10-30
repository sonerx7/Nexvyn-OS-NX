# Language pack: JavaScript (QuickJS-ng, ES2023)

**English** · [Türkçe](javascript.tr.md)

Add this after `system-prompt.en.md` when the app is written in JavaScript.

## Skeleton

```js
// main.js (an ES module, strict mode)
import { Model } from "./model.js";      // relative imports inside the bundle; "./data.json" gives parsed JSON

const model = new Model();

app.load = (arg) => { model.items = store.get("items", []); };
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w);
  if (ui.button(TR("refresh"), 20, 70, 140, 34, "primary")) refresh();   // async, runs in the background
};
app.menu = () => [{ title: TR("app"), items: [{ label: TR("reset"), id: 1 }] }];
app.onmenu = (id) => { if (id === 1) model.reset(); };

async function refresh() {
  try {
    const data = await net.fetchJson("https://example.com/api.json");   // rejects on network / HTTP / JSON errors
    model.items = data.items;
  } catch (e) {
    model.error = e.message;
  }
}
```

app.json: `"main": "main.js"` (or `"runtime": "js"`), `"minSdk": "1.1"`, `"permissions": ["network"]` when `net` is used.

## Rules

- Indexes are 0-based. `null` instead of nil. Several results are arrays: `const [w, h] = gfx.size()`,
  `const [x, y, down, hovering] = ui.mouse()`, `const [scrollY, scrollX] = ui.beginScroll(...)`.
- `ui.textfield(id, text, ...)` returns the new text only; `ui.submitted(id)` is true on the Enter frame.
  `ui.row(...)` returns 0, 1 (clicked) or 2 (double-clicked).
- Promises: every SDK call that takes a callback returns a Promise without it: `await net.get(url)` (never rejects,
  check `res.ok`), `await net.json(url)` / `await net.fetchJson(url[, headers])` (reject on failure),
  `await net.fetch(url, {method, headers, body, contentType})`, `await ui.alert(...)` (0-based index),
  `await ui.prompt(...)`, `await ui.openFile(exts)`, `await ui.saveFile(name)`, `await timer.sleep(s)`.
  An unhandled rejection opens the error screen: always `try`/`catch`.
- Extras: `setTimeout`/`setInterval`/`clearTimeout`/`clearInterval` (ms), `console.log`, `fs.readBytes` →
  `Uint8Array`, `JSON.parse` / `JSON.stringify`, `ui.submitted`, `net.request`.
- Not available: `window`, `document`, `fetch`, `XMLHttpRequest`, `localStorage`, `require`, `process`, `Intl`.
  Use `sys.date()` for local time.
- Meshes: `mesh.setColor(c)` (dot, not colon).

## Check

`node tools/js_check.mjs <bundle> --frames 600`: parses every .js file as a module, checks the TR keys, runs the app
against a mock SDK in both languages and reports uncaught errors and unhandled rejections.
