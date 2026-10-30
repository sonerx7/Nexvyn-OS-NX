-- My App: a minimal Nexvyn OS app in Lua (SDK.md sections 1-10).
-- main.lua returns a table of callbacks; every callback is optional, delete the ones you do not need.
-- Text shown to the user comes from lang/<code>.json through the TR function.

local app = {}

local taps = 0

local function bump(n)
  taps = n
  store.set("taps", taps)        -- store keeps small values between runs (the app's own data folder)
end

-- Once, when the window opens. arg = the file / link the app was opened with, or "".
function app.load(arg)
  taps = store.get("taps", 0)
end

-- Every frame: draw everything and handle widgets. w, h = content size in pixels.
function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("edit_me"), 40, h / 2 - 24, 14, "sans", "center", w - 80)
  if ui.button(TR("tap", taps), w / 2 - 90, h / 2 + 20, 180, 40, "primary") then
    bump(taps + 1)
    audio.play("pop")
  end
end

-- Raw input (SDK.md section 5).
function app.event(e)
  if e.type == "keydown" and e.key == "space" then bump(taps + 1) end
end

-- Menu bar: a list of menus, each with items {label, id}; "-" is a separator.
function app.menu()
  return {{title = TR("app"), items = {{label = TR("reset"), id = 1}}}}
end

function app.onmenu(id)
  if id == 1 then bump(0) end
end

return app
