-- Hello SDK: a tour of the Nexvyn OS Lua SDK (see sdk/SDK.md). Every widget here is live.
local app = {}

local tab = 1
local clicks = 0
local name = ""
local volume = 0.5
local dark = false
local choice = 1
local started = 0
local notes = {}

function app.load(arg)
  clicks = store.get("clicks", 0)
  name = store.get("name", sys.username())
  started = sys.time()
end

local function header(w, title)
  gfx.color(theme.text)
  gfx.text(title, 24, 64, 20, "bold")
end

local function drawWidgets(w, h)
  header(w, TR("widgets"))
  local y = 100
  ui.group(20, y, w - 40, 190)
  gfx.color(theme.text)
  gfx.text(TR("your_name"), 36, y + 16, 14)
  local newName, submitted = ui.textfield("name", name, 200, y + 10, w - 236, 30, TR("name_hint"))
  if newName ~= name then name = newName; store.set("name", name) end
  if submitted then sys.notify(TR("hello_title"), TR("greeting", name)) end
  ui.separator(36, y + 50, w - 36)
  gfx.color(theme.text)
  gfx.text(TR("volume"), 36, y + 64, 14)
  volume = ui.slider("vol", volume, 0, 1, 200, y + 60, w - 236)
  ui.separator(36, y + 98, w - 36)
  gfx.color(theme.text)
  gfx.text(TR("option"), 36, y + 112, 14)
  dark = ui.toggle("t1", dark, w - 78, y + 108)
  ui.separator(36, y + 146, w - 36)
  gfx.color(theme.text)
  gfx.text(TR("choice"), 36, y + 158, 14)
  choice = ui.segmented("seg", {"A", "B", "C"}, choice, 200, y + 152, 180)

  if ui.button(TR("click_me"), 20, y + 210, 160, 34, "primary") then
    clicks = clicks + 1
    store.set("clicks", clicks)
    audio.tone(440 + clicks * 40, 0.12, 0.4, "triangle")
  end
  gfx.color(theme.text2)
  gfx.text(TR("clicked", clicks), 196, y + 218, 14)
  if ui.button(TR("show_alert"), w - 180, y + 210, 160, 34) then
    ui.alert(TR("hello_title"), TR("greeting", name), {TR("nice"), TR("close")}, function(b)
      if b == 1 then sys.notify(TR("hello_title"), TR("nice")) end
    end)
  end
end

local function drawCanvas(w, h)
  header(w, TR("drawing"))
  local t = sys.time() - started
  local cx, cy = w / 2, 230
  gfx.shadow(cx - 120, cy - 100, 240, 200, 16, 20)
  gfx.gradient(cx - 120, cy - 100, 240, 200, theme.accent, theme.purple, false, 16)
  for i = 0, 11 do
    local a = t + i * math.pi / 6
    gfx.color(255, 255, 255, 220)
    gfx.circle(cx + math.cos(a) * 70, cy + math.sin(a) * 70, 6 + 4 * math.sin(t * 3 + i))
  end
  gfx.color("#FFFFFF")
  gfx.arc(cx, cy, 40, -math.pi / 2, -math.pi / 2 + (t % 2) * math.pi, 6)
  gfx.icon("auto_awesome", cx, cy, 34, "#FFFFFF")
  gfx.color(theme.text2)
  gfx.text(TR("fps", math.floor(sys.fps())), 0, cy + 120, 13, "sans", "center", w)
end

local function drawSystem(w, h)
  header(w, TR("system"))
  local d = sys.date()
  local pct, charging = sys.battery()
  local rows = {
    {TR("time"), string.format("%02d:%02d:%02d", d.hour, d.min, d.sec)},
    {TR("date"), string.format("%02d.%02d.%04d", d.day, d.month, d.year)},
    {TR("battery"), pct .. "%" .. (charging and " +" or "")},
    {TR("online"), sys.online() and TR("yes") or TR("no")},
    {TR("model"), sys.model()},
    {TR("firmware"), sys.firmware()},
    {TR("language"), sys.lang()},
  }
  ui.group(20, 100, w - 40, #rows * 36 + 8)
  for i, r in ipairs(rows) do
    local y = 104 + (i - 1) * 36
    gfx.color(theme.text)
    gfx.text(r[1], 36, y + 9, 14)
    gfx.color(theme.text2)
    gfx.text(r[2], 0, y + 9, 14, "sans", "right", w - 36)
    if i < #rows then ui.separator(36, y + 35, w - 36) end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  tab = ui.segmented("tabs", {TR("widgets"), TR("drawing"), TR("system")}, tab, w / 2 - 170, 14, 340, 30)
  if tab == 1 then drawWidgets(w, h) elseif tab == 2 then drawCanvas(w, h) else drawSystem(w, h) end
end

function app.event(e)
  if e.type == "keydown" and e.key == "right" then tab = tab % 3 + 1 end
  if e.type == "keydown" and e.key == "left" then tab = (tab + 1) % 3 + 1 end
end

function app.menu()
  return {{title = TR("hello_title"), items = {{label = TR("reset"), id = 1}, "-", {label = TR("open_sdk"), id = 2}}}}
end

function app.onmenu(id)
  if id == 1 then clicks = 0; store.set("clicks", 0) end
  if id == 2 then sys.launch("browser", "https://github.com/sonerx7") end
end

return app
