# Task: port an existing Lua app or game to JavaScript

**English** · [Türkçe](port-lua-to-js.tr.md)

Send after `system-prompt.en.md` + `languages/javascript.en.md` (+ `languages/lua.en.md` helps). Paste the Lua files below the
prompt. The same prompt works for Python or Squirrel: change the target and attach that language pack.

```text
Port this Nexvyn OS app from Lua to JavaScript. Keep the behaviour, the look, the app id, the lang/*.json keys and
the store keys identical, so existing users keep their saved data.

Do this carefully:
1. app.json: change "main" to "main.js", set "minSdk" to at least "1.1" (keep a higher value if the app needs it),
   keep "permissions" exactly as they are.
2. Indexes: Lua is 1-based, JavaScript is 0-based. Convert ui.segmented / ui.dropdown selections, ui.alert button
   indexes, default ui.contextMenu ids and g3d.custom indices. Values already saved in store with Lua (for example a
   selected tab) are 1-based: convert them when loading (and say so in a comment).
3. Several results become arrays: local w, h = gfx.size() -> const [w, h] = gfx.size(); same for ui.mouse,
   ui.beginScroll, sys.battery, input.stick, input.motion, g3d.project.
4. ui.textfield returns only the text in JS; replace "text, submitted = ui.textfield(...)" with the text plus
   ui.submitted(id). ui.row returns 0/1/2.
5. nil -> null; tables -> arrays/objects; mesh:setColor -> mesh.setColor; string.format -> template strings;
   # length -> .length; string.sub/find -> slice/indexOf (watch the 1-based positions); math.floor stays Math.floor.
6. require("x") -> import from "./x.js"; module tables become ES modules with named exports.
7. Callbacks may stay callbacks; use async/await only where it makes the code clearer, with try/catch.
8. If the app uses nexvyn.game (Lua only), say so first: it cannot be ported directly; propose either keeping Lua or
   rewriting the game loop with plain gfx/input in JS.

Deliver every file in full, then list each place where the behaviour could differ and how to verify it with
node tools/js_check.mjs.
```
