# A Nexvyn OS app in JavaScript

[Türkçe](JS_APPS.tr.md) · **English**

Nexvyn OS apps (`.nxvapp`) can be written in JavaScript as well as Lua. The API is the same; the full reference is
`sdk/SDK.en.md` (section 11 "JavaScript"), and a working sample is `romfs/Applications/hellojs.nxvapp` ("Hello JS").

## How to choose it

Make `main.js` the main file in `app.json`:

```json
{"id": "com.adiniz.sayac", "name": {"tr": "Sayaç", "en": "Counter"}, "category": "utilities",
 "main": "main.js", "window": {"width": 360, "height": 260, "resizable": false}}
```

When the main file's name ends in `.js` / `.mjs`, or `"runtime": "js"` is set, the app opens with the JavaScript
engine (QuickJS-ng); otherwise Lua is used as before.

## The smallest app

```js
let sayi = 0;
app.load = () => { sayi = store.get("sayi", 0); };
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(String(sayi), 0, 60, 48, "bold", "center", w);
  if (ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) store.set("sayi", ++sayi);
};
```

The callbacks are the same as in Lua: `app.load(arg)`, `app.open(arg)`, `app.update(dt)`, `app.draw(w, h)`,
`app.event(e)`, `app.menu()`, `app.onmenu(id)`, `app.close()`. You can also give them as
`export default { load, draw }`.

## Differences from Lua (summary)

- **Arrays start at 0:** the selected index of `ui.segmented` and `ui.dropdown`, the button index of `ui.alert`,
  `g3d.custom` indices.
- **`null` instead of `nil`:** `fs.read`, `json.decode`, `gfx.image`, `g3d.load` return `null` on failure.
- **Several return values become an array:** `const [w, h] = gfx.size()`, `const [x, y] = input.stick()`,
  `const [yuzde, sarj] = sys.battery()`.
- **`ui.textfield` returns only the text;** `ui.submitted("id")` tells you Enter was pressed.
  **`ui.row`** returns 0 (nothing), 1 (clicked) or 2 (double-clicked).
- **Promises:** every asynchronous function you call without a callback returns a Promise:
  `const veri = await net.fetchJson(url)`, `const i = await ui.alert(baslik, mesaj, ["Tamam", "İptal"])`,
  `await timer.sleep(0.5)`. `net.fetchJson` throws an Error on failure (no connection, HTTP error, broken JSON);
  catch it with `try { ... } catch (e) { e.message }`. An uncaught Promise error opens the error screen like any other
  error.
- **Modules:** take files from the bundle with `import { f } from "./yardimci.js"`; `import veri from "./veri.json"`
  gives a JSON file as an object. `main.js` is an ES module, and `await` can be used at the top level.
- **Timers:** `timer.after/every/cancel` (seconds) and `setTimeout`/`setInterval`/`clearTimeout` (milliseconds).
- **Log:** `console.log(...)` and `print(...)` output goes to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`; objects are
  written as JSON.
- There are no browser/Node APIs (`window`, `document`, `fetch`, `localStorage`, `require`); use the SDK modules.

## SDK 1.4 additions

- **Sharing:** `sys.share(textOrPath)` opens the share sheet; apps with `"shareTargets": ["text"]` in their `app.json`
  are listed. The receiving app gets the item through `app.load(arg)` / `app.open(arg)`.
- **Links:** `sys.open("nxv://app/<id>?arg=...")`, `nxv://store/<id>`, `nxv://settings/<pane>` (`launch` permission);
  `sys.appUrl(id, arg)` builds the link.
- **Scheduled notifications:** `sys.schedule(epoch, title, body, arg)` → id (arrives even while the app is closed;
  `notifications` permission), `sys.unschedule(id)`, `sys.scheduled()`.
- **Permissions:** `network`, `files`, `launch`, `notifications` and `games` (`sys.games`, SDK 1.6) are enforced; the
  user decides once at install time (the install sheet lists them, **Customize** turns single ones off) and is asked at
  first launch only when there is no stored answer. Without the permission the call returns `false`. `sys.clipboard`
  needs no permission. `sys.hasPermission(name)`, `await sys.requestPermission(name)` → `true`/`false` (the only
  prompt at run time).
- **Memory:** `sys.memory()` → `[used, limit]`.
- **Callbacks:** `app.search = (q) => [{ title, subtitle, icon, arg }]` (Quick Search), `app.suspend`, `app.resume`,
  `app.focus = (focused) => {}`, `app.autosave`, `app.unsaved = () => hasUnsavedWork`.

## Limits and errors

- Every window runs its own JavaScript engine; the memory limit is **64 MB**.
- A single callback that runs longer than **3 seconds** is stopped ("script took too long").
- Stack overflow (`RangeError: Maximum call stack size exceeded`), running out of memory (`out of memory`), syntax
  errors and uncaught errors show up in the window as an error screen with `file.js:line:column`; the **Reload** button
  restarts the app from scratch, **Copy** puts the error on the clipboard.
- `import` can only load files inside the app bundle.

## Checking on the PC

```
node tools/js_check.mjs romfs/Applications/hellojs.nxvapp
```

It checks `app.json`, the syntax of every `.js` file and that every `TR("key")` translation used exists in
`lang/en.json` and `lang/tr.json`, then runs the app for a few hundred frames against a fake SDK (random clicks, menus,
closing). This check runs in Node.js; for the real test open the app in Ryujinx or on the console (a `launch hellojs`
line in `sdmc:/NexvynOS/autorun.txt`).
