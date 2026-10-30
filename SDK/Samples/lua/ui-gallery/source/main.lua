-- UI Gallery: every ui.* widget of the SDK, live, with the code that draws it right beside it.
--
-- What this file teaches:
--   1. immediate-mode widgets: each one is called every frame and returns what happened (clicked, new value...)
--   2. all ui functions: button (six styles, icon, disabled), iconButton, toggle, checkbox, radio, slider,
--      textfield (flags, Enter), focus, keyboard, segmented, dropdown, label, progress, spinner, row, group,
--      separator, beginScroll/endScroll, hit, mouse, contextMenu, alert, prompt, openFile, saveFile
--   3. data-driven layout: a page is a list of cards {title, height, demo function, code}; the cards are laid
--      out in a scroll view whose content height is the sum of the card heights
--   4. responsive layout: sidebar + code beside the widget on wide windows, dropdown + code below on narrow ones
-- The code samples are shown exactly as you would write them.

local app = {}
local floor, min, max, sin = math.floor, math.min, math.max, math.sin

-- ------------------------------------------------------------------ the state the demos change
local S = {
  clicks = 0, lastButton = "-", fav = false, bold = true,
  wifi = true, dark = false, check1 = true, check2 = false, size = 2,
  volume = 0.6, stars = 3, name = "", search = "", secret = "", age = "42", submitted = "",
  view = 1, city = 2, progress = 0, selectedRow = 2, opened = "-",
  boxX = 40, boxY = 20, hitInfo = "", result = "-",
}

-- ------------------------------------------------------------------ helpers
local function code(text, x, y, w, h)
  gfx.rect(x, y, w, h, 10, theme.dark and "#1B1E27" or "#F2F3F7")
  local ly = y + 10
  for line in (text .. "\n"):gmatch("(.-)\n") do
    gfx.color(line:match("^%s*%-%-") and theme.text3 or theme.text)
    gfx.text(line, x + 12, ly, 12, "mono")
    ly = ly + 16
  end
end

local function lines(text)
  local n = 1
  for _ in text:gmatch("\n") do n = n + 1 end
  return n
end

local function result(text, x, y)
  gfx.color(theme.text2)
  gfx.text(text, x, y, 12)
end

local function say(text)
  S.result = text
end

-- ------------------------------------------------------------------ 3. pages of cards
-- demo(x, y, w) draws the live widget inside the card; code is the snippet shown next to it.
local PAGES = {}

PAGES[1] = {key = "cat_buttons", cards = {
  {title = "ui.button", desc = "desc_button", h = 120, demo = function(x, y, w)
    local styles = {"default", "primary", "destructive", "plain", "toolbar", "link"}
    local bw = min(110, (w - 20) / 3)
    for i, st in ipairs(styles) do
      local bx, by = x + ((i - 1) % 3) * (bw + 10), y + floor((i - 1) / 3) * 40
      if ui.button(st .. "##b" .. i, bx, by, bw, 32, st) then S.clicks = S.clicks + 1; S.lastButton = st end
    end
    ui.button(TR("disabled"), x, y + 80, bw, 32, "default", "block", false)
    result(TR("clicked", S.lastButton, S.clicks), x + bw + 12, y + 88)
  end, code = 'if ui.button("Save", x, y, 110, 32, "primary") then\n  save()\nend\n' ..
              '-- styles: default primary destructive\n--         plain toolbar link\n' ..
              'ui.button("Off", x, y, 110, 32, "default",\n          "block", false)  -- icon, disabled'},
  {title = "ui.iconButton", desc = "desc_iconbutton", h = 64, demo = function(x, y)
    if ui.iconButton("favorite", x, y, 40, 40, S.fav and theme.pink or nil, S.fav) then S.fav = not S.fav end
    if ui.iconButton("format_bold", x + 50, y, 40, 40, nil, S.bold) then S.bold = not S.bold end
    if ui.iconButton("delete", x + 100, y, 40, 40, theme.red) then say("iconButton: delete") end
    if ui.iconButton("delete", x + 150, y, 40, 40, nil, false, "second") then say("iconButton: delete##second") end
  end, code = 'if ui.iconButton("favorite", x, y, 40, 40,\n    fav and theme.pink, fav) then\n  fav = not fav\nend\n' ..
              '-- same icon twice: add an id suffix\nui.iconButton("delete", x, y, 40, 40, nil, false, "2")'},
}}

PAGES[2] = {key = "cat_toggles", cards = {
  {title = "ui.toggle", desc = "desc_toggle", h = 84, demo = function(x, y)
    gfx.color(theme.text); gfx.text(TR("wifi"), x, y + 6, 14)
    S.wifi = ui.toggle("wifi", S.wifi, x + 150, y)
    gfx.color(theme.text); gfx.text(TR("dark"), x, y + 44, 14)
    S.dark = ui.toggle("dark", S.dark, x + 150, y + 38)
  end, code = 'wifi = ui.toggle("wifi", wifi, x, y)\n-- returns the new value every frame'},
  {title = "ui.checkbox", desc = "desc_checkbox", h = 76, demo = function(x, y)
    S.check1 = ui.checkbox(TR("remember"), S.check1, x, y)
    S.check2 = ui.checkbox(TR("newsletter"), S.check2, x, y + 34)
  end, code = 'remember = ui.checkbox("Remember me",\n                       remember, x, y)'},
  {title = "ui.radio", desc = "desc_radio", h = 110, demo = function(x, y)
    local sizes = {TR("small"), TR("medium"), TR("large")}
    for i, s in ipairs(sizes) do
      if ui.radio(s, S.size == i, x, y + (i - 1) * 34) then S.size = i end
    end
  end, code = 'for i, s in ipairs({"Small", "Medium", "Large"}) do\n' ..
              '  if ui.radio(s, size == i, x, y + (i-1)*34) then\n    size = i       -- you keep the selection\n  end\nend'},
}}

PAGES[3] = {key = "cat_inputs", cards = {
  {title = "ui.slider", desc = "desc_slider", h = 84, demo = function(x, y, w)
    S.volume = ui.slider("volume", S.volume, 0, 1, x, y, w - 70)
    result(string.format("%d%%", floor(S.volume * 100 + 0.5)), x + w - 60, y + 6)
    S.stars = ui.slider("stars", S.stars, 1, 5, x, y + 40, w - 70, 1)
    result(string.rep("*", floor(S.stars)), x + w - 60, y + 46)
  end, code = 'volume = ui.slider("vol", volume, 0, 1, x, y, 200)\n' ..
              'stars = ui.slider("stars", stars, 1, 5, x, y, 200, 1)\n-- the last argument is the step'},
  {title = "ui.textfield", desc = "desc_textfield", h = 84, demo = function(x, y, w)
    local t, enter = ui.textfield("name", S.name, x, y, w, 32, TR("name_hint"))
    S.name = t
    if enter then S.submitted = t end
    result(TR("submitted", S.submitted), x, y + 44)
  end, code = 'local text, enter = ui.textfield("name", name,\n    x, y, 240, 32, "Your name")\nname = text\n' ..
              'if enter then greet(name) end'},
  {title = "ui.textfield flags", desc = "desc_flags", h = 168, demo = function(x, y, w)
    S.search = ui.textfield("search", S.search, x, y, w, 32, TR("search_hint"), "search")
    S.secret = ui.textfield("secret", S.secret, x, y + 40, w, 32, TR("password_hint"), "password")
    S.age = ui.textfield("age", S.age, x, y + 80, w, 32, "0", "numeric")
    ui.textfield("ro", TR("readonly_text"), x, y + 120, w, 32, nil, "readonly")
  end, code = 'ui.textfield("q", q, x, y, w, 32, "Search",\n             "search")\n' ..
              '-- also "password", "numeric", "readonly"\n-- combine: "numeric readonly"'},
  {title = "ui.focus · ui.keyboard", desc = "desc_focus", h = 84, demo = function(x, y)
    if ui.button(TR("focus_name"), x, y, 170, 32) then ui.focus("name") end
    if ui.button(TR("system_keyboard"), x + 180, y, 190, 32, "default", "keyboard") then
      ui.keyboard(S.name, function(text)
        if text then S.name = text; say("ui.keyboard: " .. text) else say("ui.keyboard: nil") end
      end, TR("name_hint"))
    end
    result(TR("focus_note"), x, y + 44)
  end, code = 'ui.focus("name")        -- focus a text field\n' ..
              'ui.keyboard(name, function(text)\n  if text then name = text end\nend, "Your name")'},
}}

PAGES[4] = {key = "cat_choices", cards = {
  {title = "ui.segmented", desc = "desc_segmented", h = 76, demo = function(x, y, w)
    S.view = ui.segmented("view", {TR("day"), TR("week"), TR("month")}, S.view, x, y, min(w, 300))
    result(TR("selected", S.view), x, y + 42)
  end, code = 'view = ui.segmented("view", {"Day", "Week",\n    "Month"}, view, x, y, 300)  -- 1-based'},
  {title = "ui.dropdown", desc = "desc_dropdown", h = 76, demo = function(x, y, w)
    local cities = {"Istanbul", "Ankara", "Izmir", "Kyoto", "Lisbon"}
    S.city = ui.dropdown("city", cities, S.city, x, y, min(w, 220))
    result(TR("selected", cities[S.city]), x, y + 42)
  end, code = 'city = ui.dropdown("city", cities, city,\n                   x, y, 220)'},
}}

PAGES[5] = {key = "cat_feedback", cards = {
  {title = "ui.progress", desc = "desc_progress", h = 84, demo = function(x, y, w)
    S.progress = (S.progress + 0.004) % 1
    ui.progress(S.progress, x, y + 4, w)
    ui.progress(-1, x, y + 36, w)
    result(TR("indeterminate"), x, y + 50)
  end, code = 'ui.progress(done / total, x, y, 240)\nui.progress(-1, x, y, 240)  -- indeterminate'},
  {title = "ui.spinner", desc = "desc_spinner", h = 64, demo = function(x, y)
    ui.spinner(x + 14, y + 16, 12)
    ui.spinner(x + 64, y + 16, 8)
    result(TR("loading"), x + 90, y + 10)
  end, code = 'if loading then ui.spinner(x, y, 12) end'},
  {title = "ui.label", desc = "desc_label", h = 84, demo = function(x, y)
    ui.label(TR("label_plain"), x, y)
    ui.label(TR("label_big"), x, y + 22, 20, theme.accent, "bold")
    ui.label(TR("label_mono"), x, y + 54, 13, theme.text2, "mono")
  end, code = 'ui.label("Plain text", x, y)\nui.label("Title", x, y, 20, theme.accent, "bold")'},
}}

PAGES[6] = {key = "cat_layout", cards = {
  {title = "ui.row", desc = "desc_row", h = 150, demo = function(x, y, w)
    local items = {"Documents", "Downloads", "Music", "Pictures"}
    for i, it in ipairs(items) do
      local ry = y + (i - 1) * 34
      local clicked, double = ui.row("row" .. i, x, ry, w, 32, S.selectedRow == i)
      if clicked then S.selectedRow = i end
      if double then say("ui.row double click: " .. it) end
      gfx.icon("folder", x + 18, ry + 16, 18, S.selectedRow == i and "#FFFFFF" or theme.accent)
      gfx.color(S.selectedRow == i and "#FFFFFF" or theme.text)
      gfx.text(it, x + 36, ry + 8, 14)
    end
  end, code = 'local click, double = ui.row("r"..i, x, y, w, 32,\n                            sel == i)\n' ..
              'if click then sel = i end\nif double then open(items[i]) end\n-- draw the row content on top'},
  {title = "ui.group · ui.separator", desc = "desc_group", h = 104, demo = function(x, y, w)
    ui.group(x, y, w, 92)
    gfx.color(theme.text); gfx.text(TR("wifi"), x + 14, y + 13, 14)
    S.wifi = ui.toggle("wifi2", S.wifi, x + w - 60, y + 8)
    ui.separator(x + 14, y + 46, x + w - 14)
    gfx.color(theme.text); gfx.text(TR("dark"), x + 14, y + 59, 14)
    S.dark = ui.toggle("dark2", S.dark, x + w - 60, y + 54)
  end, code = 'ui.group(x, y, w, 92)            -- the box\n' ..
              'ui.separator(x + 14, y + 46, x + w - 14)\n-- draw rows and widgets on top'},
  {title = "ui.beginScroll", desc = "desc_scroll", h = 150, demo = function(x, y, w)
    -- a scroll view inside the page's scroll view; children use content coordinates
    gfx.rect(x, y, w, 140, 8, theme.field)
    local sy = ui.beginScroll("inner", x, y, w, 140, 40 * 22)
    for i = 1, 40 do
      gfx.color(i % 2 == 0 and theme.text2 or theme.text)
      gfx.text(TR("scroll_line", i), 12, (i - 1) * 22 + 4, 13)
    end
    ui.endScroll()
    result(TR("scroll_pos", floor(sy)), x + w - 110, y + 120)
  end, code = 'local sy = ui.beginScroll("list", x, y, w, 140,\n                          count * 22)\n' ..
              'for i = 1, count do\n  gfx.text(items[i], 12, (i-1)*22, 13)  -- content xy\nend\nui.endScroll()'},
}}

PAGES[7] = {key = "cat_pointer", cards = {
  {title = "ui.hit", desc = "desc_hit", h = 150, demo = function(x, y, w)
    gfx.rect(x, y, w, 140, 8, theme.field)
    local bx, by = x + S.boxX, y + S.boxY
    local hit = ui.hit("box", bx, by, 90, 60)
    if hit.held then                          -- dx, dy: how far the pointer moved this frame
      S.boxX = max(0, min(w - 90, S.boxX + hit.dx))
      S.boxY = max(0, min(80, S.boxY + hit.dy))
    end
    if hit.doubleClicked then S.boxX, S.boxY = 40, 20 end
    if hit.rightClicked then say("ui.hit: rightClicked") end
    gfx.rect(bx, by, 90, 60, 10, hit.held and theme.orange or hit.hovered and theme.blue or theme.accent)
    gfx.color("#FFFFFF")
    gfx.text(TR("drag_me"), bx, by + 21, 13, "semibold", "center", 90)
  end, code = 'local h = ui.hit("box", bx, by, 90, 60)\nif h.held then\n  bx, by = bx + h.dx, by + h.dy\nend\n' ..
              '-- also hovered pressed clicked\n-- rightClicked doubleClicked'},
  {title = "ui.mouse · ui.contextMenu", desc = "desc_mouse", h = 120, demo = function(x, y, w)
    gfx.rect(x, y, w, 110, 8, theme.field)
    local mx, my, down, hovering = ui.mouse()
    local inside = mx >= x and mx < x + w and my >= y and my < y + 110
    if inside then
      gfx.color(down and theme.orange or theme.accent)
      gfx.line(mx, y, mx, y + 110, 1)
      gfx.line(x, my, x + w, my, 1)
      result(TR("mouse_pos", floor(mx - x), floor(my - y), down and TR("down_flag") or ""), x + 10, y + 8)
    else
      result(TR("move_here"), x + 10, y + 8)
    end
    local hit = ui.hit("ctx", x, y, w, 110)
    if hit.rightClicked then
      ui.contextMenu({{label = TR("copy"), id = 1, icon = "content_copy"}, {label = TR("rename"), id = 2, icon = "edit"},
                      "-", {label = TR("delete"), id = 3, icon = "delete"}}, function(id)
        say("ui.contextMenu: " .. tostring(id))
      end)
    end
  end, code = 'local mx, my, down, hovering = ui.mouse()\nif hit.rightClicked then\n' ..
              '  ui.contextMenu({{label = "Copy", id = 1},\n    "-", {label = "Delete", id = 3}},\n' ..
              '    function(id) ... end)\nend'},
}}

PAGES[8] = {key = "cat_dialogs", cards = {
  {title = "ui.alert", desc = "desc_alert", h = 64, demo = function(x, y)
    if ui.button(TR("show_alert"), x, y, 160, 32, "destructive", "delete") then
      ui.alert(TR("alert_title"), TR("alert_message"), {TR("delete"), TR("cancel")}, function(i)
        say("ui.alert -> " .. i)              -- 1-based button index
      end)
    end
  end, code = 'ui.alert("Delete?", "This cannot be undone.",\n  {"Delete", "Cancel"}, function(i)\n' ..
              '    if i == 1 then delete() end   -- 1-based\n  end)'},
  {title = "ui.prompt", desc = "desc_prompt", h = 64, demo = function(x, y)
    if ui.button(TR("show_prompt"), x, y, 160, 32, "default", "edit") then
      ui.prompt(TR("prompt_title"), TR("prompt_message"), S.name, function(text)
        if text then S.name = text end
        say("ui.prompt -> " .. tostring(text))
      end)
    end
  end, code = 'ui.prompt("Rename", "New name:", name,\n  function(text)  -- nil when cancelled\n' ..
              '    if text then name = text end\n  end)'},
  {title = "ui.openFile · ui.saveFile", desc = "desc_files", h = 84, demo = function(x, y)
    if ui.button(TR("open_file"), x, y, 150, 32, "default", "folder_open") then
      ui.openFile(function(path)
        S.opened = path or "-"
        say("ui.openFile -> " .. tostring(path))
      end, {".txt", ".md", ".json"}, TR("open_file"))
    end
    if ui.button(TR("save_file"), x + 160, y, 150, 32, "default", "save") then
      ui.saveFile(function(path)
        -- a path the user picked may always be written, no "files" permission needed
        if path then fs.write(path, TR("saved_text")) end
        say("ui.saveFile -> " .. tostring(path))
      end, "gallery.txt", TR("save_file"))
    end
    result(TR("opened", S.opened), x, y + 46)
  end, code = 'ui.openFile(function(path) ... end,\n            {".txt", ".md"}, "Open")\n' ..
              'ui.saveFile(function(path)\n  if path then fs.write(path, text) end\nend, "notes.txt")'},
}}

-- ------------------------------------------------------------------ 4. layout
local page = 1

local function cardHeight(card, wide)
  local codeH = lines(card.code) * 16 + 20
  if wide then return 56 + max(card.h, codeH) + 16 end
  return 56 + card.h + codeH + 26
end

local function drawCard(card, x, y, w, wide)
  local ch = cardHeight(card, wide)
  gfx.shadow(x, y, w, ch - 12, 12, 10, 2)
  gfx.rect(x, y, w, ch - 12, 12, theme.window)
  gfx.color(theme.text)
  gfx.text(card.title, x + 16, y + 12, 15, "monobold")
  gfx.color(theme.text2)
  gfx.text(TR(card.desc), x + 16, y + 34, 12)
  local inner = y + 56
  if wide then
    local half = (w - 48) / 2
    card.demo(x + 16, inner, half)
    code(card.code, x + 32 + half, inner, half, lines(card.code) * 16 + 20)
  else
    card.demo(x + 16, inner, w - 32)
    code(card.code, x + 16, inner + card.h + 10, w - 32, lines(card.code) * 16 + 20)
  end
  return ch
end

function app.load()
  page = store.get("page", 1)
  if not PAGES[page] then page = 1 end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local side = w >= 820 and 200 or 0
  local top = 0
  if side > 0 then
    -- sidebar: one ui.row per page
    gfx.rect(0, 0, side, h, 0, theme.sidebar)
    gfx.color(theme.text)
    gfx.text(TR("title"), 16, 16, 18, "bold")
    for i, p in ipairs(PAGES) do
      local ry = 52 + (i - 1) * 36
      if ui.row("page" .. i, 8, ry, side - 16, 32, page == i) then page = i; store.set("page", i) end
      gfx.color(page == i and "#FFFFFF" or theme.text)
      gfx.text(TR(p.key), 20, ry + 8, 14)
    end
  else
    local names = {}
    for i, p in ipairs(PAGES) do names[i] = TR(p.key) end
    gfx.color(theme.text)
    gfx.text(TR("title"), 16, 18, 18, "bold")
    local np = ui.dropdown("pages", names, page, w - 216, 14, 200, 32)
    if np ~= page then page = np; store.set("page", np) end
    top = 56
  end
  -- result of the last dialog / callback, always visible at the bottom
  local barH = 34
  gfx.rect(side, h - barH, w - side, barH, 0, theme.window)
  gfx.color(theme.text2)
  gfx.text(TR("last_result", S.result), side + 16, h - barH + 9, 13, "mono")

  -- the cards in a scroll view
  local x, cw = side + 16, w - side - 32
  local wide = cw >= 620
  local cards = PAGES[page].cards
  local total = 16
  for _, c in ipairs(cards) do total = total + cardHeight(c, wide) end
  ui.beginScroll("page_scroll" .. page, side, top, w - side, h - top - barH, total)
  local y = 16
  for _, c in ipairs(cards) do y = y + drawCard(c, 16, y, cw, wide) end
  ui.endScroll()
end

function app.event(e)
  if e.type == "keydown" and (e.key == "pagedown" or e.key == "pageup") then
    local d = e.key == "pagedown" and 1 or -1
    page = (page - 1 + d) % #PAGES + 1
    store.set("page", page)
  end
end

function app.menu()
  local items = {}
  for i, p in ipairs(PAGES) do items[i] = {label = TR(p.key), id = i} end
  return {{title = TR("menu_pages"), items = items}}
end

function app.onmenu(id)
  if PAGES[id] then page = id; store.set("page", id) end
end

return app
