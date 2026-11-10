-- Test demo: a window with a button and a label. Every tap is printed, so a scenario can check the log.
local app = {}
local taps = 0

function app.load(arg)
  print("nxvtest-demo: loaded")
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 0, h / 2 - 90, 28, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("tapped", taps), 0, h / 2 - 30, 16, "sans", "center", w)
  gfx.color(theme.accent)
  gfx.rect(20, h - 50, math.min(taps * 60, w - 40), 24, 6) -- a bar that grows with every tap: a screenshot shows the change
  if ui.button(TR("tap"), w / 2 - 90, h / 2 + 20, 180, 40, "primary") then
    taps = taps + 1
    print("nxvtest-demo: button clicked, taps=" .. taps)
  end
end

return app
