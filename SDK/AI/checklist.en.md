# Checklist for the assistant (run through it before answering)

**English** · [Türkçe](checklist.tr.md)

Give this file to the assistant together with `system-prompt.en.md`, or paste it at the end of a request:
"Before you answer, go through checklist.en.md and fix anything that fails."

## API

- [ ] Every function, module, field, event type, key name and app.json key I used is in SDK.en.md / system-prompt.en.md.
      Nothing is invented (no `fetch`, `localStorage`, `io.open`, `os.listdir`, `ui.image`, `gfx.sprite`...).
- [ ] The language rules are applied: index base (Lua 1, others 0), several results (Lua multiple returns, JS arrays,
      Python tuples, Squirrel arrays, C pointers, Java `double[]`/`List`), `ui.textfield` / `ui.submitted`, `ui.row`.
- [ ] Async: Lua/Python/Squirrel callbacks; JS Promises with `try`/`catch`; C function pointers with `void* user`;
      Java `(Callback)` lambdas.
- [ ] `minSdk` matches the newest feature used and the language (JS 1.1, Python 1.3, Squirrel/C/Java 1.5,
      `nexvyn.game` 1.2, share/schedule/permission API/lifecycle callbacks 1.4).

## app.json

- [ ] Valid JSON; `id` reverse-domain (`com.name.app`); `name` and `description` with at least `en` and `tr`.
- [ ] `runtime` / `main` (and `mainClass` for Java) match the files I delivered.
- [ ] `permissions` lists exactly what the code uses (`network`, `files`, `launch`, `notifications`, `games`);
      `[]` when nothing.
- [ ] `category` is one of system, productivity, utilities, media, internet, games, developer, other. Games have
      `"gamepad": true` and a resizable window.

## Behaviour

- [ ] No callback can run near 3 seconds (no unbounded loops; long work split across frames or timers). C code has
      bounded loops (it is not stopped by the system).
- [ ] `draw` is cheap: no image loading, file reading, network calls or big allocations per frame; meshes and images
      are created once.
- [ ] Data is saved with `store` / `fs` when it changes; nothing is lost on `suspend` or close.
- [ ] Network: `sys.online()` checked, loading and error states shown, no API keys or secrets in the code.
- [ ] Works with touch, the controller cursor and a keyboard; games also with the controller (and pause).
- [ ] Every visible string goes through `TR()`; every key exists in `lang/en.json` and `lang/tr.json`; placeholders
      `{0}` match the arguments. No `TR("...")` examples in comments for keys that do not exist.
- [ ] `theme` colors for UI (light and dark mode); controls ≥ 28 px; the layout fits the minimum window size.
- [ ] Widget ids are unique in the window (`"Delete##" + i` in lists).

## Answer

- [ ] Every file is complete (no "..." or "rest unchanged"), with its path in the bundle.
- [ ] I said how to check it (`lua_check.py` / `js_check.mjs` / `py_check.py` / `rt_check.py`, or `nxv check`) and
      how to run it (copy to `sdmc:/NexvynOS/Applications/<Name>.nxvapp/`, or Studio → Run).
- [ ] I listed what I am unsure about instead of guessing silently.
- [ ] For a store submission: `store.json` with `subtitle` / `description` in en, tr, de, fr, es, `kind`, `tags` and
      `shots` using only `wait`, `wclick`, `wmove`, `key`, `dpad`, `text`, `dark`.
