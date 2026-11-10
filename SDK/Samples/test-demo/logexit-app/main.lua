-- Test demo: logs a few lines, shows a message for two seconds, then closes its own window.
local app = {}
local t = 0
local done = false

function app.load(arg)
  print("nxvtest-demo: logexit started")
end

function app.update(dt)
  t = t + dt
  if t > 2 and not done then
    done = true
    print("nxvtest-demo: logexit done, exiting")
    sys.exit()
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("msg"), 0, h / 2 - 10, 20, "bold", "center", w)
end

return app
