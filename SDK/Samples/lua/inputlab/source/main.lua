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
  local hintY = 16 + math.max(32, gfx.textHeight(19, "bold") + 6)
  local controlsY = hintY + math.max(32, gfx.textHeight(13.8) + 8)
  local controlH = math.max(30, gfx.textHeight(14) + 8)
  local shift = compact and (controlH + 16) or 0
  local sliderY = controlsY + controlH + 16 + shift
  local statusY = sliderY + 38
  local scrollY = statusY + math.max(36, gfx.textHeight(13.8) + 8)
  if w ~= lastw or h ~= lasth then
    sys.log(string.format("Layout %s %.0f %.0f", compact and "compact" or "wide", w, h))
    lastw, lasth = w, h
  end
  gfx.clear(theme.window)
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 16, 19, "bold")
  gfx.text(compact and TR("hint.compact") or TR("hint.wide"), 20, hintY, 13.8)
  selected = ui.dropdown("mode", {TR("mode.touch"), TR("mode.pad"), TR("mode.keyboard")}, selected, 20, controlsY, 230, controlH)
  name = ui.textfield("name", name, compact and 20 or 270, controlsY + shift, compact and (w - 40) or (w - 290), controlH, TR("placeholder"))
  volume = ui.slider("volume", volume, 0, 1, 20, sliderY, w - 40)
  local status = string.format("Value %.2f | Pinch %.2f | Rotation %.2f", volume, zoom, angle)
  if status ~= last then sys.log(status); last = status end
  local visible = compact and string.format("%s %.2f | %s %.2f", TR("value"), volume, TR("pinch"), zoom) or string.format("%s %.2f | %s %.2f | %s %.2f", TR("value"), volume, TR("pinch"), zoom, TR("rotation"), angle)
  gfx.text(visible, 20, statusY, 13.8)
  local innerY = 8 + math.max(36, gfx.textHeight(15, "bold") + 6)
  local rowH = math.max(36, gfx.textHeight(15, "medium") + 6)
  local rowStep = rowH + 8
  local outerRowsY = innerY + 200
  ui.beginScroll("outer", 20, scrollY, w - 40, math.max(0, h - scrollY - 20), math.max(1100, outerRowsY + 18 * rowStep))
  gfx.color(theme.text)
  gfx.text(compact and TR("frame.compact") or TR("frame.wide"), 12, 8, 15, "bold")
  ui.beginScroll("inner", 12, innerY, w - 90, 180, math.max(900, 20 * rowStep))
  for i = 1, 20 do ui.button(TR("row.inner") .. " " .. i, 8, (i - 1) * rowStep, w - 130, rowH) end
  ui.endScroll()
  for i = 1, 18 do ui.button(TR("row.outer") .. " " .. i, 12, outerRowsY + (i - 1) * rowStep, w - 90, rowH) end
  ui.endScroll()
end
return app
