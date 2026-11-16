local app = {}
local volume, name, selected, zoom, angle = 0.5, "", 1, 1, 0
local last = ""
local lastw, lasth = 0, 0
function app.event(e)
  if e.type == "pinch" then zoom = math.max(0.25, math.min(4, zoom * e.scale)) end
  if e.type == "rotate" then angle = angle + e.angle end
end
function app.draw(w, h)
  local compact = w < 620
  local shift = compact and 46 or 0
  if w ~= lastw or h ~= lasth then
    sys.log(string.format("Layout %s %.0f %.0f", compact and "compact" or "wide", w, h))
    lastw, lasth = w, h
  end
  gfx.clear(theme.window)
  gfx.color(theme.text)
  gfx.text("Input Lab", 20, 16, 19, "bold")
  gfx.text(compact and "Touch, scroll, type and try two fingers" or "Drag sliders, swipe inside frames, type and try two fingers", 20, 48, 13.8)
  selected = ui.dropdown("mode", {"Touch", "Gamepad", "Keyboard / mouse"}, selected, 20, 80, 230, 30)
  name = ui.textfield("name", name, compact and 20 or 270, 80 + shift, compact and (w - 40) or (w - 290), 30, "Type here")
  volume = ui.slider("volume", volume, 0, 1, 20, 126 + shift, w - 40)
  local status = string.format("Value %.2f | Pinch %.2f | Rotation %.2f", volume, zoom, angle)
  if status ~= last then sys.log(status); last = status end
  gfx.text(compact and string.format("Value %.2f | Pinch %.2f", volume, zoom) or status, 20, 164 + shift, 13.8)
  ui.beginScroll("outer", 20, 200 + shift, w - 40, h - 220 - shift, 1100)
  gfx.color(theme.text)
  gfx.text(compact and "Nested frame: swipe rows" or "Outer frame: swipe this text or any row", 12, 8, 15, "bold")
  ui.beginScroll("inner", 12, 44, w - 90, 180, 900)
  for i = 1, 20 do ui.button("Inner row " .. i, 8, (i - 1) * 44, w - 130, 36) end
  ui.endScroll()
  for i = 1, 18 do ui.button("Outer row " .. i, 12, 244 + (i - 1) * 44, w - 90, 36) end
  ui.endScroll()
end
return app
