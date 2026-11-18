-- Tap the moving square. Warm amber on deep blue; no external assets.
local app = { x = 0.5, score = 0, best = 0, paused = false }
local function save() store.set("best", app.best) end
function app.load() app.best = tonumber(store.get("best", 0)) or 0 end
function app.update(dt)
    if input.pressed("plus") then app.paused = not app.paused end
    if input.pressed("a") and not app.paused then
        app.score = math.abs(app.x - 0.5) < 0.15 and app.score + 1 or 0
        app.best = math.max(app.best, app.score); save()
    end
    if not app.paused then app.x = (app.x + math.min(math.max(dt, 0), 0.05) * 0.2) % 1 end
end
function app.draw(w, h)
    gfx.clear("#101D35")
    gfx.color("#F8EDD4")
    gfx.text(TR("title"), 16, 16, 24, "bold", "left", w - 32)
    gfx.text(TR("score", tostring(app.score), tostring(app.best)), 16, 50, 16, "sans", "left", w - 32)
    gfx.text(TR("hint"), 16, h - 45, 14, "sans", "left", w - 32)
    local x, y = 16 + app.x * math.max(0, w - 96), h * 0.5
    gfx.color(app.paused and "#8792A4" or "#F4B85D")
    gfx.rect(x, y, 64, 64)
    if app.paused then
        gfx.color("#F8EDD4")
        gfx.text(TR("paused"), 16, 80, 20, "bold", "left", w - 32)
    end
end
function app.event(e)
    if (e.type == "keydown" and e.key == "escape") then
        app.paused = not app.paused
    elseif e.type == "mousedown" and e.button == "left" and not app.paused then
        local w, h = gfx.size()
        local x = 16 + app.x * math.max(0, w - 96)
        if e.x >= x and e.x <= x + 64 and e.y >= h * 0.5 and e.y <= h * 0.5 + 64 then
            app.score = app.score + 1
            app.best = math.max(app.best, app.score); save()
        end
    elseif e.type == "keydown" and e.key == "enter" and not app.paused then
        app.score = math.abs(app.x - 0.5) < 0.15 and app.score + 1 or 0
        app.best = math.max(app.best, app.score); save()
    end
end
function app.focus(focused) if not focused then app.paused = true; save() end end
function app.suspend() app.paused = true; save() end
function app.resume() app.paused = true end
function app.close() save() end
return app
