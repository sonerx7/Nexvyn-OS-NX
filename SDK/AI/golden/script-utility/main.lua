-- A persistent counter. SDK globals are provided by the host.
local app = { count = 0 }
local function save() store.set("count", app.count) end
function app.load() app.count = tonumber(store.get("count", 0)) or 0 end
function app.draw(w, h)
    gfx.clear(theme.bg)
    nxui.begin(w, h)
    nxui.card("counter")
    nxui.label("title", TR("title"), "title")
    nxui.label("value", TR("count", tostring(app.count)), "body")
    if nxui.button("add", TR("add"), "primary") then
        app.count = app.count + 1; save()
    end
    if nxui.button("reset", TR("reset"), "default") then app.count = 0; save() end
    nxui.cardEnd()
    nxui.endFrame()
end
function app.suspend() save() end
function app.autosave() save() end
function app.close() save() end
return app
