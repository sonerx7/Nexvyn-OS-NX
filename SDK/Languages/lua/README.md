# Nexvyn OS in Lua

**English** · [Türkçe](README.tr.md)

Lua 5.4 is Nexvyn OS's main language: the fastest scripting runtime, the `nexvyn.game` 2D engine, Studio's sprite,
tilemap and scene editors and the most samples. It has been there since SDK 1.0.

## Ready-made template

The [`template/`](template/) folder is the smallest app that passes the checker: a counter, a menu, saving with `store`
and translations in five languages. Copy it as `MyApp.nxvapp`, or run:

    python SDK/Tools/nxv/nxv.py new lua "My App" --author yourname

## app.json

The manifest above works as is. A `main` ending in `.lua` needs no `"runtime"`. With `nexvyn.game` add
`"minSdk": "1.2"`; games want `"gamepad": true` and `"resizable": true`.

## Program structure

`main.lua` returns a table of callbacks, all optional (see the code above): `load(arg)`, `update(dt)`, `draw(w, h)`,
`event(e)`, `menu()`, `onmenu(id)`, `close()`, plus `open`, `search`, `suspend`, `resume`, `focus`, `autosave` and
`unsaved` (SDK 1.4). Put every text on screen in `lang/<code>.json` and read it with `TR("key")`.

## Running it

- **On the console with Studio:** **New Project → Blank Lua App**, or open an existing folder; press **Run**
  (Ctrl+R). Errors are marked on their line, `print` output goes to Studio's console.
- **On the console from a PC:** copy the folder into `sdmc:/NexvynOS/Applications/` (FTP: **Connect to PC**, or
  `nxv push`) and reopen Launcher.
- **In Ryujinx:** copy the folder into `NexvynOS/Applications/` in the emulator's SD card folder (`nxv install`). A
  line `launch com.you.myapp` in `sdmc:/NexvynOS/autorun.txt` opens the app at boot; delete the file after testing.

## Checking it on a PC

From the root of the Nexvyn OS source repository (needs `pip install lupa`):

    python tools/lua_check.py <path>/MyApp.nxvapp --frames 600

It validates `app.json`, compiles every `.lua` file, checks that every `TR` key is in `lang/en.json` and
`lang/tr.json`, then runs the app against a mock SDK for hundreds of frames with random clicks, keys and pad
presses. `nxv check --sdk <checkout>` runs the same checker.

## Common pitfalls

- **No `io`, `os.execute` or external modules:** use `fs` for files and `store` for settings. `require("name")` loads
  only `name.lua` from the bundle or the system library (`require("nexvyn.game")`).
- **Creating tables and images every frame:** load images once in `app.load` with `gfx.image`; do not build big
  tables in `app.draw`.
- **Long loops:** a callback that runs for more than 3 seconds is stopped. Split long work across frames.
- **Permissions:** `net.*` needs `"network"`, `sys.notify` `"notifications"`, `sys.launch` / `nxv://` `"launch"`,
  `sys.clipboard` `"clipboard"`, paths outside the app's folders `"files"`; an undeclared permission is never granted.
- **Lua is 1-based:** `ui.segmented`, `ui.dropdown` and `ui.alert` indexes start at 1 (0 in JS/Python).
- **`ui` widgets need unique ids:** if a label appears twice, add a suffix like `"Delete##3"`.

## More

- SDK reference: [SDK.md](../../Reference/SDK.en.md) sections 1-10 (Lua), 8c (`nexvyn.game`), 8b (`g3d`)
- Guides: [DEVELOPER_GUIDE.md](../../Guides/DEVELOPER_GUIDE.en.md), [GAME_ENGINE.md](../../Guides/GAME_ENGINE.en.md),
  [LUA_CAPABILITIES.md](../../Guides/LUA_CAPABILITIES.en.md)
- Samples: [Samples/lua](../../Samples/README.md#lua)
