-- Reading List for Nexvyn OS: books with author, pages, progress, status, rating and notes; filter tabs, search and
-- sort, page stepping with auto-finish, a yearly goal ring, confetti when a book is finished, CSV export and undo.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

-- ------------------------------------------------------------------ helpers
local ccache = {}
local function rgba(c)
  if type(c) == "table" then return c end
  local t = ccache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    ccache[c] = t
  end
  return t
end
local function fade(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end
local function approach(v, target, speed, dt) return v + (target - v) * min(1, dt * speed) end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local FOLD = {["Ç"] = "ç", ["Ğ"] = "ğ", ["İ"] = "i", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü", ["ı"] = "i"}
local function fold(s)
  return (trim(s):gsub("[\195\196\197][\128-\191]", function(ch) return FOLD[ch] or ch end)):lower()
end

local fieldRects, nFields, editing = {}, 0, false
local function field(id, text, x, y, w, h, ph, flags)
  nFields = nFields + 1
  local r = fieldRects[nFields]
  if not r then r = {}; fieldRects[nFields] = r end
  r[1], r[2], r[3], r[4] = x, y, w, h
  return ui.textfield(id, text, x, y, w, h, ph, flags)
end
local function pointInField(x, y)
  for i = 1, nFields do
    local r = fieldRects[i]
    if x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4] then return true end
  end
  return false
end

local function todayKey()
  local d = sys.date()
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end
local function thisYear() return sys.date().year end

-- ------------------------------------------------------------------ data
local STATUS = {"st_toread", "st_reading", "st_finished"}
local STATUS_ICON = {"bookmark", "auto_stories", "check_circle"}
local STATUS_COLOR = {"blue", "orange", "green"}
local SPINES = {"#5E5CE6", "#FF9F0A", "#30B0C7", "#FF375F", "#34C759", "#AF52DE", "#A2845E", "#0A84FF"}
local SORTS = {"sort_recent", "sort_title", "sort_author", "sort_progress", "sort_rating"}
local statusNames, sortNames, filterNames = {}, {}, {}

local books = {}
local nextId = 1
local goal = 12
local version = 0
local filter = 1          -- 1 all, 2 to-read, 3 reading, 4 finished
local sortBy = 1
local search = ""
local sel = 0
local sheet, sheetT = nil, 0
local undoItem = nil      -- {book, index, t}
local message, messageT = "", 0
local shown = {}          -- book id -> eased progress
local flash = {}          -- book id -> time of the last change
local ringShown = 0
local confetti = {}
local tabT = 1

local function save()
  store.set("books", books)
  store.set("nextId", nextId)
  version = version + 1
end
local function say(s) message, messageT = s, sys.time() end

local function spine(b)
  local h = 0
  for i = 1, #b.title do h = (h * 31 + b.title:byte(i)) % 9973 end
  return SPINES[h % #SPINES + 1]
end

local function sanitize(b)
  if type(b) ~= "table" or type(b.title) ~= "string" or trim(b.title) == "" then return nil end
  local pages = max(1, floor(tonumber(b.pages) or 1))
  local st = floor(tonumber(b.status) or 1)
  return {id = floor(tonumber(b.id) or 0), title = b.title, author = type(b.author) == "string" and b.author or "",
          pages = pages, page = max(0, min(pages, floor(tonumber(b.page) or 0))),
          status = (st >= 1 and st <= 3) and st or 1, rating = max(0, min(5, floor(tonumber(b.rating) or 0))),
          notes = type(b.notes) == "string" and b.notes or "", added = tonumber(b.added) or 0,
          finished = type(b.finished) == "string" and b.finished or ""}
end

-- ------------------------------------------------------------------ yearly numbers (cached)
local yearInfo = {key = ""}
local function yearStats()
  local y = thisYear()
  local key = version .. ":" .. y
  if yearInfo.key == key then return yearInfo end
  local s = {key = key, done = 0, pages = 0, reading = 0, toread = 0, rated = 0, ratingSum = 0, counts = {0, 0, 0}}
  local prefix = string.format("%04d-", y)
  for _, b in ipairs(books) do
    s.counts[b.status] = s.counts[b.status] + 1
    if b.status == 3 and b.finished:sub(1, 5) == prefix then
      s.done = s.done + 1
      s.pages = s.pages + b.pages
    end
    if b.rating > 0 then s.rated, s.ratingSum = s.rated + 1, s.ratingSum + b.rating end
  end
  yearInfo = s
  return s
end

-- ------------------------------------------------------------------ confetti
local function celebrate(x, y)
  for i = 1, 46 do
    local a = -pi / 2 + (math.random() - 0.5) * 2.2
    local sp = 160 + math.random() * 240
    confetti[#confetti + 1] = {x = x, y = y, vx = cos(a) * sp, vy = sin(a) * sp, life = 1.2 + math.random() * 0.6,
                               c = SPINES[i % #SPINES + 1], r = 2 + math.random() * 3}
  end
  audio.tone(784, 0.09, 0.3, "triangle")
  timer.after(0.09, function() audio.tone(988, 0.09, 0.3, "triangle") end)
  timer.after(0.18, function() audio.tone(1319, 0.16, 0.3, "triangle") end)
end

-- ------------------------------------------------------------------ actions
local function setPage(b, p, cx, cy)
  if not b then return end
  p = max(0, min(b.pages, floor(p)))
  if p == b.page then return end
  b.page = p
  flash[b.id] = sys.time()
  if p > 0 and b.status == 1 then b.status = 2 end
  if p >= b.pages and b.status ~= 3 then
    b.status = 3
    b.finished = todayKey()
    say(TR("finished_msg", b.title))
    celebrate(cx or 120, cy or 100)
  elseif p < b.pages and b.status == 3 then
    b.status = 2
    b.finished = ""
  end
  undoItem = nil
  save()
end

local function setStatus(b, st)
  if not b or b.status == st then return end
  b.status = st
  if st == 3 then
    b.page = b.pages
    if b.finished == "" then b.finished = todayKey() end
    say(TR("finished_msg", b.title))
    celebrate(120, 100)
  else
    b.finished = ""
    if st == 1 then b.page = 0 end
    if st == 2 and b.page >= b.pages then b.page = 0 end
  end
  flash[b.id] = sys.time()
  save()
end

local function deleteBook(b)
  for i, x in ipairs(books) do
    if x == b then
      table.remove(books, i)
      undoItem = {book = b, index = i, t = sys.time()}
      if sheet and sheet.id == b.id then sheet = nil end
      save()
      say(TR("deleted", b.title))
      audio.play("trash")
      return
    end
  end
end

local function undo()
  if not undoItem then return end
  table.insert(books, min(undoItem.index, #books + 1), undoItem.book)
  flash[undoItem.book.id] = sys.time()
  undoItem = nil
  save()
  say(TR("restored"))
end

local function setGoal(n)
  goal = max(1, min(365, floor(n)))
  store.set("goal", goal)
end

local function askPage(b)
  ui.prompt(TR("set_page"), TR("set_page_msg", b.pages), tostring(b.page), function(s)
    local n = tonumber(trim(s or ""))
    if not n or n ~= floor(n) or n < 0 or n > b.pages then
      if s then say(TR("err_page", b.pages)); audio.play("error") end
      return
    end
    setPage(b, n)
  end)
end

local function askGoal()
  ui.prompt(TR("yearly_goal"), TR("goal_msg"), tostring(goal), function(s)
    local n = tonumber(trim(s or ""))
    if not n or n ~= floor(n) or n < 1 or n > 365 then
      if s then say(TR("err_goal")); audio.play("error") end
      return
    end
    setGoal(n)
  end)
end

-- ------------------------------------------------------------------ view (filtered + sorted, cached)
local view, viewKey = {}, ""
local function buildView()
  local key = version .. ":" .. filter .. ":" .. sortBy .. ":" .. search
  if key == viewKey then return end
  viewKey = key
  view = {}
  local q = fold(search)
  for _, b in ipairs(books) do
    if (filter == 1 or b.status == filter - 1) and
       (q == "" or fold(b.title):find(q, 1, true) or fold(b.author):find(q, 1, true)) then
      view[#view + 1] = b
    end
  end
  local cmp
  if sortBy == 2 then cmp = function(a, b) return fold(a.title) < fold(b.title) end
  elseif sortBy == 3 then cmp = function(a, b)
    local x, y = fold(a.author), fold(b.author)
    if x ~= y then return x < y end
    return fold(a.title) < fold(b.title) end
  elseif sortBy == 4 then cmp = function(a, b)
    local x, y = a.page / a.pages, b.page / b.pages
    if x ~= y then return x > y end
    return a.id > b.id end
  elseif sortBy == 5 then cmp = function(a, b)
    if a.rating ~= b.rating then return a.rating > b.rating end
    return a.id > b.id end
  else cmp = function(a, b)
    -- recent: reading first, then to-read, then finished; newest first inside each
    local ra = a.status == 2 and 0 or (a.status == 1 and 1 or 2)
    local rb = b.status == 2 and 0 or (b.status == 1 and 1 or 2)
    if ra ~= rb then return ra < rb end
    return a.id > b.id end
  end
  table.sort(view, cmp)
  if sel > #view then sel = #view end
end

-- ------------------------------------------------------------------ export
local function csvField(s)
  s = tostring(s or "")
  if s:find('[,"\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end
local function exportCsv()
  local out = {"title,author,pages,page,status,rating,finished,notes"}
  for _, b in ipairs(books) do
    out[#out + 1] = table.concat({csvField(b.title), csvField(b.author), tostring(b.pages), tostring(b.page),
                                  ({"to-read", "reading", "finished"})[b.status], tostring(b.rating), b.finished,
                                  csvField(b.notes)}, ",")
  end
  local text = table.concat(out, "\n") .. "\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("csv_saved")) else say(TR("save_failed")) end
  end, "reading-list.csv", TR("export_csv"))
end
local function copyList()
  local out = {}
  for st = 2, 3 do
    for _, b in ipairs(books) do
      if b.status == st or (st == 2 and b.status == 1) then
        local line = "• " .. b.title .. (b.author ~= "" and (" — " .. b.author) or "") .. " (" .. statusNames[b.status]
        if b.status == 2 then line = line .. ", " .. floor(b.page / b.pages * 100 + 0.5) .. "%" end
        if b.rating > 0 then line = line .. ", " .. string.rep("★", b.rating) end
        out[#out + 1] = line .. ")"
      end
    end
  end
  sys.clipboard(table.concat(out, "\n"))
  say(TR("copied"))
end

-- ------------------------------------------------------------------ editor sheet
local function openEditor(b)
  local s = {isNew = b == nil, id = b and b.id}
  if b then
    s.title, s.author, s.pages, s.page = b.title, b.author, tostring(b.pages), tostring(b.page)
    s.status, s.rating, s.notes = b.status, b.rating, b.notes
  else
    s.title, s.author, s.pages, s.page, s.status, s.rating, s.notes = "", "", "", "0", 1, 0, ""
  end
  s.err = ""
  sheet, sheetT = s, 0
  editing = false
  audio.play("pop")
end

local function commitEditor()
  local s = sheet
  if not s then return end
  local title = trim(s.title)
  if title == "" then s.err = TR("err_title"); audio.play("error"); ui.focus("ed_title"); return end
  local pages = tonumber(trim(s.pages))
  if not pages or pages ~= floor(pages) or pages < 1 or pages > 20000 then
    s.err = TR("err_pages"); audio.play("error"); return
  end
  local page = tonumber(trim(s.page)) or 0
  if page ~= floor(page) or page < 0 or page > pages then s.err = TR("err_page", pages); audio.play("error"); return end
  local b
  for _, x in ipairs(books) do if x.id == s.id then b = x end end
  local wasDone = b and b.status == 3
  if not b then
    b = {id = nextId, added = nextId, finished = ""}
    nextId = nextId + 1
    books[#books + 1] = b
  end
  b.title, b.author, b.pages, b.page = title:sub(1, 120), trim(s.author):sub(1, 80), pages, page
  b.rating, b.notes = s.rating, s.notes:sub(1, 500)
  b.status = s.status
  if page >= pages and b.status ~= 1 then b.status = 3 end
  if b.status == 3 then
    b.page = pages
    if b.finished == "" then b.finished = todayKey() end
  else
    b.finished = ""
    if b.status == 2 and page == 0 then b.page = 0 end
  end
  flash[b.id] = sys.time()
  sheet = nil
  editing = false
  undoItem = nil
  save()
  if b.status == 3 and not wasDone then say(TR("finished_msg", b.title)); celebrate(120, 100) end
end

local function bookMenu(b)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    {label = TR("set_page"), id = 2, icon = "menu_book"},
    "-",
    {label = TR("mark_toread"), id = 3, icon = "bookmark"},
    {label = TR("mark_reading"), id = 4, icon = "auto_stories"},
    {label = TR("mark_finished"), id = 5, icon = "check_circle"},
    "-",
    {label = TR("delete"), id = 6, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(b) elseif id == 2 then askPage(b)
    elseif id >= 3 and id <= 5 then setStatus(b, id - 2)
    elseif id == 6 then deleteBook(b) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  for i, k in ipairs(STATUS) do statusNames[i] = TR(k) end
  for i, k in ipairs(SORTS) do sortNames[i] = TR(k) end
  nextId = floor(tonumber(store.get("nextId", 1)) or 1)
  goal = floor(tonumber(store.get("goal", 12)) or 12)
  setGoal(goal)
  books = {}
  local raw = store.get("books", {})
  if type(raw) == "table" then
    for _, b in ipairs(raw) do
      local o = sanitize(b)
      if o then
        if o.id <= 0 then o.id = nextId end
        nextId = max(nextId, o.id + 1)
        books[#books + 1] = o
      end
    end
  end
  filter = floor(tonumber(store.get("filter", 1)) or 1)
  if filter < 1 or filter > 4 then filter = 1 end
  sortBy = floor(tonumber(store.get("sort", 1)) or 1)
  if sortBy < 1 or sortBy > #SORTS then sortBy = 1 end
  for _, b in ipairs(books) do shown[b.id] = b.page / b.pages end
end

function app.update(dt)
  tabT = approach(tabT, 1, 10, dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  local ys = yearStats()
  ringShown = approach(ringShown, min(1, ys.done / max(1, goal)), 6, dt)
  for _, b in ipairs(books) do shown[b.id] = approach(shown[b.id] or 0, b.page / b.pages, 9, dt) end
  -- confetti physics
  local i = 1
  while i <= #confetti do
    local p = confetti[i]
    p.vy = p.vy + 520 * dt
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then table.remove(confetti, i) else i = i + 1 end
  end
end

-- ------------------------------------------------------------------ drawing
local function header(w, ys, interactive)
  local y = 58
  -- goal ring
  local rx, ry, rr = 56, y + 40, 32
  gfx.color(theme.dark and "#FFFFFF1A" or "#00000012")
  gfx.arc(rx, ry, rr, 0, pi * 2, 7)
  if ringShown > 0.002 then
    gfx.color(ys.done >= goal and theme.green or theme.accent)
    gfx.arc(rx, ry, rr, -pi / 2, -pi / 2 + pi * 2 * ringShown, 7)
  end
  gfx.color(theme.text)
  gfx.text(ys.done .. "/" .. goal, rx - 30, ry - 10, 15, "bold", "center", 60)
  local gh = interactive and ui.hit("goalring", rx - rr - 6, ry - rr - 6, rr * 2 + 12, rr * 2 + 12)
  if gh and gh.clicked then askGoal() end
  local tx = rx + rr + 18
  gfx.color(theme.text)
  gfx.text(TR("year_goal_title", thisYear()), tx, y + 10, 15, "semibold")
  gfx.color(theme.text2)
  local left = goal - ys.done
  gfx.text(left > 0 and TR("books_left", left) or TR("goal_done"), tx, y + 32, 12)
  if interactive then
    if ui.iconButton("remove", tx, y + 50, 34, 30, theme.text2, false, "gm") then setGoal(goal - 1) end
    if ui.iconButton("add", tx + 38, y + 50, 34, 30, theme.text2, false, "gp") then setGoal(goal + 1) end
  end
  -- small stat chips on the right
  local cw = 118
  local cx = w - 20 - cw * 3 - 16
  if cx > tx + 190 then
    local items = {
      {"auto_stories", theme.orange, tostring(ys.counts[2]), TR("now_reading")},
      {"menu_book", theme.blue, tostring(ys.pages), TR("pages_year")},
      {"star", theme.yellow, ys.rated > 0 and string.format("%.1f", ys.ratingSum / ys.rated) or "—", TR("avg_rating")},
    }
    for i, it in ipairs(items) do
      local x = cx + (i - 1) * (cw + 8)
      gfx.rect(x, y + 6, cw, 68, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
      gfx.icon(it[1], x + 20, y + 26, 18, it[2])
      gfx.color(theme.text)
      gfx.text(it[3], x + 36, y + 16, 17, "bold")
      gfx.color(theme.text2)
      gfx.clip(x + 4, y + 6, cw - 8, 68)
      gfx.text(it[4], x + 12, y + 48, 11)
      gfx.unclip()
    end
  end
end

local function drawEmpty(x, y, w, h)
  local cy = y + h / 2 - 70
  gfx.circle(x + w / 2, cy, 42, fade(theme.orange, 0.14))
  gfx.icon(#books == 0 and "library_books" or "search", x + w / 2, cy, 44, theme.orange)
  gfx.color(theme.text)
  gfx.text(#books == 0 and TR("empty_title") or TR("nothing_here"), x, cy + 58, 17, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(#books == 0 and TR("empty_body") or TR("nothing_body"), x, cy + 84, 13, "sans", "center", w)
end

local function drawBook(b, i, y, w, rh, interactive)
  local x = 20
  local cw = w - 40
  local hit = interactive and ui.hit("bk" .. b.id, x, y + 3, cw - 150, rh - 6)
  local ft = flash[b.id]
  local fa = ft and max(0, 1 - (sys.time() - ft) / 0.8) or 0
  if fa <= 0 then flash[b.id] = nil end
  gfx.rect(x, y + 3, cw, rh - 6, 12, i == sel and fade(theme.accent, 0.14) or (theme.dark and "#FFFFFF0A" or "#00000008"))
  if fa > 0 then gfx.rect(x, y + 3, cw, rh - 6, 12, fade(theme.accent, 0.25 * fa)) end
  if hit and hit.hovered then gfx.rect(x, y + 3, cw, rh - 6, 12, theme.hover) end
  -- spine
  local sc = spine(b)
  gfx.gradient(x + 12, y + 11, 38, rh - 22, sc, fade(sc, 0.7), true, 4)
  gfx.rect(x + 16, y + 11, 3, rh - 22, 0, {255, 255, 255, 70})
  local initial = b.title:match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
  gfx.color("#FFFFFF")
  gfx.text(initial:upper(), x + 12, y + rh / 2 - 11, 18, "bold", "center", 38)
  -- texts
  local tx = x + 62
  local tw = cw - 62 - 160
  gfx.clip(tx, y, tw, rh)
  gfx.color(theme.text)
  gfx.text(b.title, tx, y + 10, 14, "semibold")
  gfx.color(theme.text2)
  gfx.text(b.author ~= "" and b.author or TR("unknown_author"), tx, y + 29, 12)
  gfx.unclip()
  -- progress
  local prog = shown[b.id] or 0
  local pw = max(60, tw - 120)
  local col = theme[STATUS_COLOR[b.status]] or theme.accent
  gfx.rect(tx, y + rh - 20, pw, 6, 3, theme.dark and "#FFFFFF14" or "#0000000F")
  if prog > 0.005 then gfx.rect(tx, y + rh - 20, max(6, pw * min(1, prog)), 6, 3, col) end
  gfx.color(theme.text3)
  gfx.text(b.page .. " / " .. b.pages .. " · " .. floor(b.page / b.pages * 100 + 0.5) .. "%", tx + pw + 8, y + rh - 26, 11)
  -- status chip + stars (right)
  local rx = x + cw - 150
  gfx.rect(rx, y + 10, 136, 22, 11, fade(col, 0.16))
  gfx.icon(STATUS_ICON[b.status], rx + 14, y + 21, 13, col)
  gfx.color(col)
  gfx.text(statusNames[b.status] or "", rx + 24, y + 13, 11, "semibold", "center", 108)
  if b.status == 2 and interactive then
    if ui.iconButton("remove", rx, y + rh - 40, 34, 30, theme.text2, false, "pm" .. b.id) then setPage(b, b.page - 1) end
    if ui.button(tostring(b.page) .. "##pg" .. b.id, rx + 38, y + rh - 40, 60, 30) then askPage(b) end
    if ui.iconButton("add", rx + 102, y + rh - 40, 34, 30, theme.text2, false, "pp" .. b.id) then
      setPage(b, b.page + 1, rx + 118, y + rh - 26)
    end
  elseif b.status == 1 and interactive then
    if ui.button(TR("start") .. "##st" .. b.id, rx, y + rh - 40, 136, 30, "default", "play_arrow") then setStatus(b, 2) end
  else
    for k = 1, 5 do
      local sx = rx + 12 + (k - 1) * 24
      local sh = interactive and ui.hit("rt" .. b.id .. k, sx - 2, y + rh - 42, 24, 30)
      gfx.icon(k <= b.rating and "star" or "star_border", sx + 10, y + rh - 27, 18, k <= b.rating and theme.yellow or theme.text3)
      if sh and sh.clicked then
        b.rating = (b.rating == k) and 0 or k
        save()
        audio.play("click")
      end
    end
  end
  if hit then
    if hit.clicked then sel = i; openEditor(b) end
    if hit.rightClicked then sel = i; bookMenu(b) end
  end
end

local function drawList(w, h, interactive)
  local ys = yearStats()
  local fy = 154
  local counts = ys.counts
  filterNames[1] = TR("f_all", #books)
  filterNames[2] = TR("f_toread", counts[1])
  filterNames[3] = TR("f_reading", counts[2])
  filterNames[4] = TR("f_finished", counts[3])
  local sw = min(440, w - 40 - 160 - 12)
  if interactive then
    local nf = ui.segmented("filter", filterNames, filter, 20, fy, sw, 30)
    if nf ~= filter then filter = nf; sel = 0; tabT = 0; store.set("filter", filter) end
    local ns = ui.dropdown("sort", sortNames, sortBy, w - 180, fy, 160, 30)
    if ns ~= sortBy then sortBy = ns; store.set("sort", sortBy) end
  end
  local sy = fy + 40
  if interactive then
    local t = field("search", search, 20, sy, w - 40, 32, TR("search_ph"), "search")
    if t ~= search then search = t:sub(1, 60); sel = 0 end
  end
  buildView()
  local top = sy + 42
  local areaH = h - top - 10
  if #view == 0 then drawEmpty(0, top, w, areaH) return end
  local rh = 80
  gfx.alpha(0.3 + 0.7 * tabT)
  ui.beginScroll("books", 0, top, w, areaH, #view * rh + 8)
  for i, b in ipairs(view) do drawBook(b, i, (i - 1) * rh, w, rh, interactive) end
  ui.endScroll()
  gfx.unalpha()
end

local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw, shh = min(500, w - 40), min(h - 20, 430)
  local sx, sy = floor((w - sw) / 2), floor((h - shh) / 2 + (1 - sheetT) * 20)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, shh, 14, 30, 10)
  gfx.rect(sx, sy, sw, shh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, shh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_book") or TR("edit_book"), sx + 20, sy + 16, 17, "bold")
  local x, iw = sx + 20, sw - 40
  local y = sy + 50
  local function label(t, lx, ly) gfx.color(theme.text2); gfx.text(t, lx, ly, 12, "semibold") end
  label(TR("book_title"), x, y)
  local t, sub1 = field("ed_title", s.title, x, y + 18, iw, 32, TR("book_title"))
  if t ~= s.title then s.title = t; s.err = "" end
  y = y + 58
  label(TR("author"), x, y)
  local a, sub2 = field("ed_author", s.author, x, y + 18, iw, 32, TR("author"))
  if a ~= s.author then s.author = a; s.err = "" end
  y = y + 58
  local hw = (iw - 12) / 2
  label(TR("total_pages"), x, y)
  label(TR("current_page"), x + hw + 12, y)
  local p, sub3 = field("ed_pages", s.pages, x, y + 18, hw, 32, "320", "numeric")
  if p ~= s.pages then s.pages = p:sub(1, 6); s.err = "" end
  local cp, sub4 = field("ed_page", s.page, x + hw + 12, y + 18, hw, 32, "0", "numeric")
  if cp ~= s.page then s.page = cp:sub(1, 6); s.err = "" end
  y = y + 58
  s.status = ui.segmented("ed_status", statusNames, s.status, x, y, iw - 150, 30)
  for k = 1, 5 do
    local hx = x + iw - 140 + (k - 1) * 28
    local hh = ui.hit("ed_star" .. k, hx, y, 28, 30)
    gfx.icon(k <= s.rating and "star" or "star_border", hx + 14, y + 15, 22, k <= s.rating and theme.yellow or theme.text3)
    if hh.clicked then s.rating = (s.rating == k) and 0 or k end
  end
  y = y + 42
  label(TR("notes"), x, y)
  local n = field("ed_notes", s.notes, x, y + 18, iw, 32, TR("notes_ph"))
  if n ~= s.notes then s.notes = n end
  if s.err ~= "" then
    gfx.color(theme.red)
    gfx.text(s.err, x, y + 56, 12)
  end
  local fy = sy + shh - 46
  if not s.isNew and ui.button(TR("delete") .. "##sh", x, fy, 92, 32, "destructive") then
    for _, b in ipairs(books) do if b.id == s.id then deleteBook(b) break end end
    sheet = nil
  end
  if sheet and ui.button(TR("cancel") .. "##sh", sx + sw - 220, fy, 96, 32) then sheet = nil; editing = false end
  if sheet and (ui.button(TR("save") .. "##sh", sx + sw - 116, fy, 96, 32, "primary") or sub1 or sub2 or sub3 or sub4) then
    commitEditor()
  end
  gfx.unalpha()
end

function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  local interactive = sheet == nil
  local ys = yearStats()
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 20, "bold")
  if interactive then
    if ui.button(TR("add_book") .. "##top", w - 160, 14, 140, 32, "primary", "add") then openEditor(nil) end
    if undoItem and sys.time() - undoItem.t < 8 and ui.button(TR("undo") .. "##undo", w - 270, 14, 100, 32, "default", "undo") then
      undo()
    end
  end
  if message ~= "" and sys.time() - messageT < 3.5 and not (undoItem and sys.time() - undoItem.t < 8) then
    gfx.color(theme.text2)
    gfx.clip(180, 14, max(0, w - 360), 32)
    gfx.text(message, 180, 22, 12, "sans", "right", w - 360)
    gfx.unclip()
  end
  header(w, ys, interactive)
  drawList(w, h, interactive)
  if sheet then drawSheet(w, h) end
  for _, p in ipairs(confetti) do
    gfx.alpha(min(1, p.life * 2))
    gfx.circle(p.x, p.y, p.r, p.c)
    gfx.unalpha()
  end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if sheet then
    if e.key == "escape" then sheet = nil; editing = false
    elseif e.key == "enter" and not editing then commitEditor() end
    return
  end
  if e.ctrl then
    if e.key == "n" then openEditor(nil)
    elseif e.key == "f" then ui.focus("search"); editing = true
    elseif e.key == "z" and not editing then undo()
    elseif e.key == "s" then exportCsv()
    elseif e.key == "c" and not editing then copyList() end
    return
  end
  if editing then
    if e.key == "escape" or e.key == "enter" then editing = false end
    return
  end
  buildView()
  local b = view[sel]
  if e.key == "down" then sel = min(#view, sel + 1)
  elseif e.key == "up" then sel = max(#view > 0 and 1 or 0, sel - 1)
  elseif e.key == "tab" then filter = filter % 4 + 1; sel = 0; tabT = 0; store.set("filter", filter)
  elseif e.key == "right" and b then setPage(b, b.page + (e.shift and 10 or 1))
  elseif e.key == "left" and b then setPage(b, b.page - (e.shift and 10 or 1))
  elseif e.key == "enter" and b then openEditor(b)
  elseif e.key == "p" and b then askPage(b)
  elseif (e.key == "delete" or e.key == "backspace") and b then deleteBook(b)
  elseif e.key == "escape" then sel = 0 end
end

function app.menu()
  return {
    {title = TR("menu_books"), items = {
      {label = TR("add_book"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("find"), id = 2, shortcut = "Ctrl+F"},
      "-",
      {label = TR("page_fwd"), id = 3, shortcut = "→"},
      {label = TR("page_back"), id = 4, shortcut = "←"},
      {label = TR("set_page"), id = 5, shortcut = "P"},
      {label = TR("delete"), id = 6, shortcut = "Delete"},
      {label = TR("undo"), id = 7, shortcut = "Ctrl+Z"},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("next_filter"), id = 10, shortcut = "Tab"},
      {label = TR("yearly_goal"), id = 11},
      "-",
      {label = TR("copy_list"), id = 12, shortcut = "Ctrl+C"},
      {label = TR("export_csv"), id = 13, shortcut = "Ctrl+S"},
    }},
  }
end

function app.onmenu(id)
  if sheet then return end
  buildView()
  local b = view[sel]
  if id == 1 then openEditor(nil)
  elseif id == 2 then ui.focus("search"); editing = true
  elseif id == 3 and b then setPage(b, b.page + 1)
  elseif id == 4 and b then setPage(b, b.page - 1)
  elseif id == 5 and b then askPage(b)
  elseif id == 6 and b then deleteBook(b)
  elseif id == 7 then undo()
  elseif id == 10 then filter = filter % 4 + 1; sel = 0; tabT = 0; store.set("filter", filter)
  elseif id == 11 then askGoal()
  elseif id == 12 then copyList()
  elseif id == 13 then exportCsv() end
end

function app.close()
  store.set("books", books)
  store.save()
  return true
end

return app
