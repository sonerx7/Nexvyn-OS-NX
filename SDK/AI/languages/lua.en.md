# Language pack: Lua 5.4

**English** · [Türkçe](lua.tr.md)

Add this after `system-prompt.en.md` when the app is written in Lua.

## Skeleton

```lua
-- main.lua
local app = {}
local state = {}                    -- module-level state lives as long as the window

function app.load(arg)
  state.count = store.get("count", 0)
  state.logo = gfx.image("bundle:/logo.png")   -- load images once
end

function app.update(dt) end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w)
  if ui.button(TR("add"), w / 2 - 60, 80, 120, 34, "primary") then
    state.count = state.count + 1
    store.set("count", state.count)
  end
end

function app.menu() return {{title = TR("app"), items = {{label = TR("reset"), id = 1}}}} end
function app.onmenu(id) if id == 1 then state.count = 0; store.set("count", 0) end end

return app
```

app.json: `"main": "main.lua"` (no `runtime` needed), `"minSdk": "1.0"` (`"1.2"` with `nexvyn.game`, `"1.4"` with
share / schedule / the permission API / lifecycle callbacks).

## Rules

- Indexes are 1-based: `ui.segmented`, `ui.dropdown`, the `ui.alert` button index, `g3d.custom` indices, default
  `ui.contextMenu` ids.
- Several results: `local text, submitted = ui.textfield(...)`, `local w, h = gfx.size()`,
  `local x, y = input.stick("left")`, `local clicked, double = ui.row(...)`.
- Available: `string`, `table`, `math`, `utf8`, `coroutine`, `os.time/clock/date/difftime`, `pcall`. Not available:
  `io`, `debug`, `package`, `dofile`, `loadfile`, `os.execute`.
- `require("name")` loads `name.lua` from the bundle (`require("a.b")` → `a/b.lua`), then the system library
  (`require("nexvyn.game")`).
- Mesh methods use `:`: `mesh:setColor(c)`, `mesh:setTexture("bundle:/wood.png")`.
- Games with `nexvyn.game`: `main.lua` ends with `return game.run{width = 480, height = 270, scene = Play}`; draw with
  `game.gfx` in virtual units, the HUD in `scene:ui()`, input with `game.input`.
- The checker scans comments too: do not write `TR("...")` examples in comments for keys that do not exist.

## Check

`python tools/lua_check.py <bundle> --frames 600` (needs `pip install lupa`): compiles every file, checks the TR keys
(en + tr), runs the app against a mock SDK with random input, menus and lifecycle callbacks.
