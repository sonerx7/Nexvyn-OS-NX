-- Journal for Nexvyn OS: one entry per day with mood, lines of text, tags, search, word count and a writing streak.
-- Entries are stored as JSON in the app's data folder (journal.json).
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
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
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], clamp(floor(t[4] * a + 0.5), 0, 255)}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end
local function approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function ellipsize(s, size, font, maxW)
  if gfx.textWidth(s, size, font) <= maxW then return s end
  while utf8.len(s) > 1 and gfx.textWidth(s .. "…", size, font) > maxW do
    s = s:sub(1, utf8.offset(s, -1) - 1)
  end
  return s .. "…"
end
local FOLD = {["ç"] = "c", ["Ç"] = "c", ["ğ"] = "g", ["Ğ"] = "g", ["ı"] = "i", ["İ"] = "i", ["ö"] = "o", ["Ö"] = "o",
              ["ş"] = "s", ["Ş"] = "s", ["ü"] = "u", ["Ü"] = "u"}
local function fold(s)
  s = s:gsub("[\195-\197][\128-\191]", function(ch) return FOLD[ch] or ch end)
  return s:lower()
end

-- text-field focus tracking: which field (if any) the user is typing in
local editing, editId, pressAt, hitId = false, nil, nil, nil
local function field(id, text, x, y, w, h, ph, flags, ox, oy, clip)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressAt then
    local px, py = pressAt[1], pressAt[2]
    local ax, ay = x + (ox or 0), y + (oy or 0)
    if px >= ax and px <= ax + w and py >= ay and py <= ay + h and
       (not clip or (px >= clip[1] and px <= clip[1] + clip[3] and py >= clip[2] and py <= clip[2] + clip[4])) then
      hitId = id
    end
  end
  return nt, sub
end
local requestVisible = nil
local function focusField(id)
  ui.focus(id)
  editing, editId = true, id
  pressAt, hitId = nil, nil
  local li = tonumber(id:match("^line(%d+)$"))
  if li then requestVisible = li end
end

-- JSON: the system `json` module; a tiny pure-Lua fallback keeps the app working where it is missing
local JSON = json
if not JSON then
  local ESC = {['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}
  local function esc(str)
    return '"' .. str:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
  end
  local function enc(v)
    local t = type(v)
    if t == "string" then return esc(v)
    elseif t == "number" or t == "boolean" then return tostring(v)
    elseif t == "table" then
      if #v > 0 or next(v) == nil then
        local o = {}
        for i = 1, #v do o[i] = enc(v[i]) end
        return "[" .. table.concat(o, ",") .. "]"
      end
      local o = {}
      for k, x in pairs(v) do o[#o + 1] = esc(tostring(k)) .. ":" .. enc(x) end
      return "{" .. table.concat(o, ",") .. "}"
    end
    return "null"
  end
  local UNESC = {n = "\n", r = "\r", t = "\t", b = "\b", f = "\f"}
  local function dec(str)
    local pos = 1
    local function ws() pos = str:find("[^ \t\r\n]", pos) or #str + 1 end
    local function strv()
      local out = {}
      pos = pos + 1
      while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then pos = pos + 1; return table.concat(out) end
        if c == "\\" then
          local n = str:sub(pos + 1, pos + 1)
          if n == "u" then
            out[#out + 1] = utf8.char(tonumber(str:sub(pos + 2, pos + 5), 16) or 63)
            pos = pos + 6
          else
            out[#out + 1] = UNESC[n] or n
            pos = pos + 2
          end
        else
          out[#out + 1] = c
          pos = pos + 1
        end
      end
      error("unterminated string")
    end
    local val
    function val()
      ws()
      local c = str:sub(pos, pos)
      if c == "{" then
        local o = {}
        pos = pos + 1
        ws()
        if str:sub(pos, pos) == "}" then pos = pos + 1; return o end
        while true do
          ws()
          local k = strv()
          ws()
          pos = pos + 1 -- ':'
          o[k] = val()
          ws()
          local d = str:sub(pos, pos)
          pos = pos + 1
          if d == "}" then return o end
          if d ~= "," then error("bad object") end
        end
      elseif c == "[" then
        local a = {}
        pos = pos + 1
        ws()
        if str:sub(pos, pos) == "]" then pos = pos + 1; return a end
        while true do
          a[#a + 1] = val()
          ws()
          local d = str:sub(pos, pos)
          pos = pos + 1
          if d == "]" then return a end
          if d ~= "," then error("bad array") end
        end
      elseif c == '"' then return strv()
      elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
      elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
      elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
      end
      local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num or num == "" then error("bad value") end
      pos = pos + #num
      return tonumber(num)
    end
    return val()
  end
  JSON = {encode = function(v) return enc(v) end,
          decode = function(str) local ok, r = pcall(dec, str); if ok then return r end return nil, r end}
end

-- ------------------------------------------------------------------ data
local MOODS = {
  {icon = "sentiment_very_dissatisfied", color = "red", key = "mood_1"},
  {icon = "sentiment_dissatisfied", color = "orange", key = "mood_2"},
  {icon = "sentiment_neutral", color = "yellow", key = "mood_3"},
  {icon = "sentiment_satisfied", color = "blue", key = "mood_4"},
  {icon = "sentiment_very_satisfied", color = "green", key = "mood_5"},
}
local FILE = "journal.json"
local entries = {}          -- ["YYYY-MM-DD"] = {mood, lines = {...}, tags = "a, b", updated}
local dirty, dirtyAt = false, 0

local isEmpty
local function save()
  local out = {}
  for k, e in pairs(entries) do
    if not isEmpty(e) then out[k] = e end
  end
  fs.write(FILE, JSON.encode({version = 1, entries = out}, true))
  dirty = false
end
local function markDirty()
  dirty = true
  dirtyAt = sys.time()
end

local function load()
  local txt = fs.read(FILE)
  entries = {}
  if txt then
    local d = JSON.decode(txt)
    if type(d) == "table" and type(d.entries) == "table" then
      for k, e in pairs(d.entries) do
        if type(k) == "string" and type(e) == "table" then
          local lines = {}
          if type(e.lines) == "table" then for _, l in ipairs(e.lines) do lines[#lines + 1] = tostring(l) end end
          if #lines == 0 then lines[1] = "" end
          entries[k] = {mood = math.tointeger(e.mood) or 0, lines = lines, tags = tostring(e.tags or ""),
                        updated = math.tointeger(e.updated) or 0}
        end
      end
    end
  end
end

-- ------------------------------------------------------------------ dates (days are handled at local noon)
local function noonOf(epoch)
  local d = sys.date(epoch)
  return epoch - d.hour * 3600 - d.min * 60 - d.sec + 12 * 3600
end
local function keyOf(epoch)
  local d = sys.date(epoch)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end
local todayNoon = 0
local selDay = 0            -- noon epoch of the selected day
local stripEnd = 0          -- noon epoch of the last day in the strip

function isEmpty(e)
  if not e then return true end
  if (e.mood or 0) > 0 or trim(e.tags or "") ~= "" then return false end
  for _, l in ipairs(e.lines) do if trim(l) ~= "" then return false end end
  return true
end

local function wordCount(e)
  if not e then return 0 end
  local n = 0
  for _, l in ipairs(e.lines) do for _ in l:gmatch("%S+") do n = n + 1 end end
  return n
end

local function tagsOf(e)
  local out = {}
  if e then
    for t in (e.tags or ""):gmatch("[^,#]+") do
      t = trim(t)
      if t ~= "" then out[#out + 1] = t end
    end
  end
  return out
end

local function entryFor(key, create)
  local e = entries[key]
  if not e and create then
    e = {mood = 0, lines = {""}, tags = "", updated = sys.epoch()}
    entries[key] = e
  end
  return e
end

local function has(key)
  local e = entries[key]
  return e ~= nil and not isEmpty(e)
end

local function touch(key)
  local e = entries[key]
  if e then e.updated = sys.epoch() end
  markDirty()
end

local function purge()
  for k, e in pairs(entries) do
    if isEmpty(e) then entries[k] = nil end
  end
end

-- ------------------------------------------------------------------ state
local search = ""
local listCache, listQuery, listVersion = {}, nil, -1
local version = 0
local moodAnim = {0, 0, 0, 0, 0}
local pendingAction = nil   -- {kind = "newline"/"delline"/"up"/"down", idx}
local stripAnim = 0
local stats = {streak = 0, count = 0, words = 0}

local function bump() version = version + 1 end

local function computeStats()
  local count, words = 0, 0
  for k, e in pairs(entries) do
    if has(k) then
      count = count + 1
      words = words + wordCount(e)
    end
  end
  local streak = 0
  local start = has(keyOf(todayNoon)) and 0 or 1
  for i = start, 2000 do
    if has(keyOf(todayNoon - i * 86400)) then streak = streak + 1 else break end
  end
  stats = {streak = streak, count = count, words = words}
end

local function refreshList()
  if listQuery == search and listVersion == version then return end
  listQuery, listVersion = search, version
  local q = fold(trim(search))
  listCache = {}
  for k, e in pairs(entries) do
    local ok = q == "" and has(k)
    if not ok and q ~= "" and has(k) then
      if fold(e.tags or ""):find(q, 1, true) or k:find(q, 1, true) then ok = true end
      if not ok then
        for _, l in ipairs(e.lines) do
          if fold(l):find(q, 1, true) then ok = true; break end
        end
      end
    end
    if ok then listCache[#listCache + 1] = k end
  end
  table.sort(listCache, function(a, b) return a > b end)
  computeStats()
end

local edScroll, edDrag, edRect, focusLine = 0, nil, {0, 0, 0, 0}, nil

local function selectDay(noon)
  purge()
  if dirty then save() end
  edScroll = 0
  selDay = noon
  if selDay > stripEnd then stripEnd = selDay end
  if selDay <= stripEnd - 14 * 86400 then stripEnd = selDay + 6 * 86400 end
  if stripEnd > todayNoon + 7 * 86400 then stripEnd = todayNoon + 7 * 86400 end
  editing, editId = false, nil
  pendingAction = nil
  stripAnim = 1
end

local function dayFromKey(k)
  local y, m, d = k:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  -- walk from today to find the noon epoch of that date (dates are within a few years)
  local target = tonumber(y) * 10000 + tonumber(m) * 100 + tonumber(d)
  local cur = sys.date(todayNoon)
  local guessDays = 0
  -- coarse estimate from the difference, then fine-tune
  local approxT = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})
  local approxNow = os.time({year = cur.year, month = cur.month, day = cur.day, hour = 12})
  if approxT and approxNow then guessDays = floor((approxT - approxNow) / 86400 + 0.5) end
  local e = todayNoon + guessDays * 86400
  for _ = 1, 4 do
    local dd = sys.date(e)
    local n = dd.year * 10000 + dd.month * 100 + dd.day
    if n == target then return e end
    e = e + (n < target and 86400 or -86400)
  end
  return e
end

-- ------------------------------------------------------------------ app
function app.load()
  load()
  todayNoon = noonOf(sys.epoch())
  selDay = todayNoon
  stripEnd = todayNoon + 3 * 86400
  bump()
  refreshList()
end

function app.update(dt)
  if dirty and sys.time() - dirtyAt > 0.8 then save() end
  local tn = noonOf(sys.epoch())
  if tn ~= todayNoon then todayNoon = tn; bump() end
  local e = entries[keyOf(selDay)]
  local mood = e and e.mood or 0
  for i = 1, 5 do moodAnim[i] = approach(moodAnim[i], i == mood and 1 or 0, 14, dt) end
  stripAnim = approach(stripAnim, 0, 10, dt)
end

local function monthLong(m) local k = "ml_" .. m; return TR(k) end
local function monthShort(m) local k = "ms_" .. m; return TR(k) end
local function wdShort(wd) local k = "wd_" .. wd; return TR(k) end
local function wdLong(wd) local k = "wl_" .. wd; return TR(k) end

local function drawSidebar(w, h)
  local sw = 250
  gfx.rect(0, 0, sw, h, 0, theme.sidebar)
  gfx.rect(sw - 1, 0, 1, h, 0, theme.separator)
  local ns = field("search", search, 12, 12, sw - 24, 30, TR("search_hint"), "search")
  if ns ~= search then search = ns end
  refreshList()
  -- stats card
  local cy = 52
  ui.group(12, cy, sw - 24, 64)
  local cw = (sw - 24) / 3
  local items = {
    {icon = "local_fire_department", col = theme.orange, v = stats.streak, k = "stat_streak"},
    {icon = "menu_book", col = theme.accent, v = stats.count, k = "stat_entries"},
    {icon = "notes", col = theme.green, v = stats.words, k = "stat_words"},
  }
  for i, it in ipairs(items) do
    local x = 12 + (i - 1) * cw
    local vs = tostring(it.v)
    local tw = gfx.textWidth(vs, 16, "bold")
    local sx = x + (cw - (tw + 20)) / 2
    gfx.icon(it.icon, sx + 8, cy + 21, 16, it.col)
    gfx.color(theme.text)
    gfx.text(vs, sx + 20, cy + 11, 16, "bold")
    gfx.color(theme.text2)
    gfx.text(TR(it.k), x, cy + 38, 10, "medium", "center", cw)
  end
  -- list
  local ly = cy + 76
  gfx.color(theme.text3)
  gfx.text(search ~= "" and TR("results", #listCache) or TR("all_entries"), 16, ly, 11, "semibold")
  local listY = ly + 20
  local listH = h - listY
  local rowH = 62
  if #listCache == 0 then
    gfx.icon(search ~= "" and "search_off" or "edit_note", sw / 2, listY + 40, 32, theme.text3)
    gfx.color(theme.text2)
    gfx.wrap(search ~= "" and TR("no_results") or TR("no_entries"), 20, listY + 64, sw - 40, 12, "sans", "center")
    return
  end
  ui.beginScroll("list", 0, listY, sw, listH, #listCache * rowH + 8)
  local selKey = keyOf(selDay)
  for i, k in ipairs(listCache) do
    local e = entries[k]
    local y = (i - 1) * rowH + 4
    local clicked = ui.row("row_" .. k, 6, y, sw - 12, rowH - 4, k == selKey)
    if clicked then
      local d = dayFromKey(k)
      if d then selectDay(d); audio.play("click", 0.4) end
    end
    local yy, mm, dd = k:match("^(%d+)-(%d+)-(%d+)$")
    local active = k == selKey
    gfx.color(active and "#FFFFFF" or theme.text)
    gfx.text(TR("date_short", tonumber(dd), monthShort(tonumber(mm)), yy), 16, y + 6, 13, "semibold")
    if e.mood and e.mood > 0 then
      local md = MOODS[e.mood]
      gfx.icon(md.icon, sw - 30, y + 14, 18, active and "#FFFFFF" or theme[md.color])
    end
    local preview = ""
    for _, l in ipairs(e.lines) do if trim(l) ~= "" then preview = trim(l); break end end
    if preview == "" then preview = TR("no_text") end
    gfx.color(active and alpha("#FFFFFF", 0.85) or theme.text2)
    gfx.text(ellipsize(preview, 12, "sans", sw - 40), 16, y + 24, 12)
    local tags = tagsOf(e)
    if #tags > 0 then
      local tline = "#" .. table.concat(tags, "  #")
      gfx.color(active and alpha("#FFFFFF", 0.75) or theme.accent)
      gfx.text(ellipsize(tline, 10.5, "medium", sw - 40), 16, y + 41, 10.5, "medium")
    end
  end
  ui.endScroll()
end

local function drawStrip(x, y, w)
  local n = 14
  local cw = w / n
  local selKey = keyOf(selDay)
  local todayKey = keyOf(todayNoon)
  for i = 1, n do
    local day = stripEnd - (n - i) * 86400
    local d = sys.date(day)
    local k = keyOf(day)
    local cx = x + (i - 1) * cw
    local future = day > todayNoon
    local hit = ui.hit("day_" .. i, cx + 2, y, cw - 4, 62)
    local sel = k == selKey
    if sel then
      gfx.rect(cx + 2, y, cw - 4, 62, 10, theme.accent)
    elseif hit.hovered then
      gfx.rect(cx + 2, y, cw - 4, 62, 10, theme.hover)
    end
    local tc = sel and "#FFFFFF" or (k == todayKey and theme.accent or (future and theme.text3 or theme.text))
    gfx.color(sel and alpha("#FFFFFF", 0.8) or theme.text3)
    gfx.text(wdShort(d.wday), cx, y + 6, 10, "semibold", "center", cw)
    gfx.color(tc)
    gfx.text(tostring(d.day), cx, y + 20, 16, "bold", "center", cw)
    local e = entries[k]
    if e and has(k) then
      local mc = (e.mood and e.mood > 0) and theme[MOODS[e.mood].color] or theme.text3
      gfx.circle(cx + cw / 2, y + 50, 4, sel and "#FFFFFF" or mc)
    end
    if hit.clicked and not sel then selectDay(day); audio.play("click", 0.4) end
  end
end

local function drawMain(w, h)
  local mx = 250
  local mw = w - mx
  local x0, iw = mx + 20, mw - 40
  local d = sys.date(selDay)
  local key = keyOf(selDay)
  local future = selDay > todayNoon
  -- header
  gfx.color(theme.text)
  gfx.text(TR("month_year", monthLong(d.month), d.year), x0, 14, 20, "bold")
  if ui.button(TR("today"), x0 + iw - 168, 12, 70, 28, "default", nil, key ~= keyOf(todayNoon)) then
    selectDay(todayNoon)
    stripEnd = todayNoon + 3 * 86400
  end
  if ui.iconButton("chevron_left", x0 + iw - 90, 12, 40, 28, nil, false, "prevw") then stripEnd = stripEnd - 7 * 86400 end
  if ui.iconButton("chevron_right", x0 + iw - 44, 12, 40, 28, nil, false, "nextw") then
    stripEnd = min(stripEnd + 7 * 86400, todayNoon + 7 * 86400)
  end
  drawStrip(x0, 50, iw)
  ui.separator(x0, 122, x0 + iw)

  -- day title + word count
  gfx.color(theme.text)
  gfx.text(TR("date_long", wdLong(d.wday), d.day, monthLong(d.month), d.year), x0, 134, 16, "bold")
  local e = entries[key]
  local wc = wordCount(e)
  local exists = has(key)
  gfx.color(theme.text2)
  local wcText = TR("words", wc)
  local wcw = gfx.textWidth(wcText, 12, "medium")
  gfx.text(wcText, x0 + iw - wcw - (exists and 40 or 0), 138, 12, "medium")
  if exists and ui.iconButton("delete_outline", x0 + iw - 32, 130, 32, 28, theme.text2, false, "delentry") then
    local k = key
    ui.alert(TR("delete_title"), TR("delete_msg"), {TR("delete"), TR("cancel")}, function(b)
      if b == 1 then
        entries[k] = nil
        editing, editId = false, nil
        save(); bump()
        audio.play("trash", 0.5)
      end
    end)
  end

  if future then
    gfx.icon("hourglass_empty", x0 + iw / 2, 300, 40, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("future_day"), x0, 330, 14, "medium", "center", iw)
    return
  end

  -- mood
  local my = 168
  gfx.color(theme.text3)
  gfx.text(TR("mood"), x0, my + 12, 11, "semibold")
  local bx = x0 + 70
  local bs = 46
  for i, m in ipairs(MOODS) do
    local x = bx + (i - 1) * (bs + 8)
    local hit = ui.hit("mood" .. i, x, my, bs, bs - 6)
    local a = moodAnim[i]
    local col = theme[m.color]
    if a > 0.01 then gfx.rect(x, my, bs, bs - 6, 10, alpha(col, 0.22 * a)) end
    if hit.hovered then gfx.rect(x, my, bs, bs - 6, 10, theme.hover) end
    local cur = e and e.mood or 0
    gfx.icon(m.icon, x + bs / 2, my + (bs - 6) / 2, 24 + a * 4, (cur == i or hit.hovered) and col or theme.text3)
    if hit.clicked then
      local en = entryFor(key, true)
      en.mood = (en.mood == i) and 0 or i
      touch(key); bump()
      audio.tone(300 + i * 90, 0.06, 0.15, "triangle")
    end
  end
  local cur = e and e.mood or 0
  if cur > 0 then
    gfx.color(theme[MOODS[cur].color])
    gfx.text(TR(MOODS[cur].key), bx + 5 * (bs + 8) + 6, my + 12, 13, "semibold")
  end

  -- tags
  local ty = my + 50
  gfx.color(theme.text3)
  gfx.text(TR("tags"), x0, ty + 8, 11, "semibold")
  local tagText = e and e.tags or ""
  local nt = field("tags", tagText, x0 + 70, ty, iw - 70, 30, TR("tags_hint"))
  if nt ~= tagText then
    local en = entryFor(key, true)
    en.tags = nt
    touch(key); bump()
  end

  -- editor (one text field per line)
  local ey = ty + 44
  local eh = h - ey - 14
  gfx.shadow(x0, ey, iw, eh, 12, 10, 2)
  gfx.rect(x0, ey, iw, eh, 12, theme.dark and theme.window or theme.bg)
  gfx.color(theme.separator)
  gfx.rectLine(x0, ey, iw, eh, 12, 1)
  local lines = e and e.lines or {""}
  local rowH = 36
  local contentH = #lines * rowH + 48
  local vpY = ey + 6
  local vpH = eh - 12
  edRect = {x0, vpY, iw, vpH}
  local maxS = max(0, contentH - vpH)
  if requestVisible then
    local ly = 4 + (requestVisible - 1) * rowH
    if ly - 4 < edScroll then edScroll = ly - 4 end
    if ly + rowH + 40 > edScroll + vpH then edScroll = ly + rowH + 40 - vpH end
    requestVisible = nil
  end
  edScroll = clamp(edScroll, 0, maxS)
  -- dragging the page background (or the right stick / wheel) scrolls the lines
  local bg = ui.hit("edbg", x0, vpY, iw, vpH)
  if bg.pressed then edDrag = edScroll end
  if bg.held and edDrag then edScroll = clamp(edDrag - bg.dy, 0, maxS) end
  if not bg.held then edDrag = nil end
  local sy = floor(edScroll + 0.5)
  gfx.clip(x0, vpY, iw, vpH)
  gfx.push(x0, vpY - sy)
  local clip = {x0, vpY, iw, vpH}
  for i = 1, #lines do
    local ly = 4 + (i - 1) * rowH
    if ly + rowH >= sy - 40 and ly <= sy + vpH + 40 then
      gfx.color(theme.text3)
      gfx.text(tostring(i), 6, ly + 8, 10, "medium", "right", 18)
      local id = "line" .. i
      local nl, sub = field(id, lines[i], 30, ly, iw - 44, 32, i == 1 and TR("write_hint") or "", nil, x0, vpY - sy, clip)
      if nl ~= lines[i] then
        local en = entryFor(key, true)
        en.lines[i] = nl
        lines = en.lines
        touch(key); bump()
      end
      if sub then pendingAction = {kind = "newline", idx = i} end
    end
  end
  local addY = 4 + #lines * rowH + 4
  if ui.button(TR("add_line"), 30, addY, 130, 30, "plain", "add") then
    pendingAction = {kind = "newline", idx = #lines}
  end
  gfx.pop()
  gfx.unclip()
  if maxS > 0 then
    local th = max(24, vpH * vpH / contentH)
    local ty2 = vpY + (vpH - th) * (sy / maxS)
    gfx.rect(x0 + iw - 6, ty2, 3, th, 2, alpha(theme.text, 0.25))
  end

  -- apply line operations after every field has handled this frame's keys
  if pendingAction then
    local act = pendingAction
    pendingAction = nil
    local en = entryFor(key, true)
    if act.kind == "newline" then
      local idx = clamp(act.idx, 0, #en.lines)
      if #en.lines < 200 then
        table.insert(en.lines, idx + 1, "")
        touch(key); bump()
        focusField("line" .. (idx + 1))
      end
    elseif act.kind == "delline" then
      if #en.lines > 1 and en.lines[act.idx] == "" then
        table.remove(en.lines, act.idx)
        touch(key); bump()
        focusField("line" .. max(1, act.idx - 1))
      end
    elseif act.kind == "up" then
      if act.idx > 1 then focusField("line" .. (act.idx - 1)) end
    elseif act.kind == "down" then
      if act.idx < #en.lines then focusField("line" .. (act.idx + 1)) end
    end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  drawSidebar(w, h)
  drawMain(w, h)
  if pressAt then
    editing = hitId ~= nil
    editId = hitId
    pressAt, hitId = nil, nil
  end
end

local function lineIndex(id)
  if not id then return nil end
  return tonumber(id:match("^line(%d+)$"))
end

function app.event(e)
  if e.type == "mousedown" then pressAt = {e.x, e.y} end
  if e.type == "scroll" then
    local r = edRect
    if e.x >= r[1] and e.x <= r[1] + r[3] and e.y >= r[2] and e.y <= r[2] + r[4] then edScroll = edScroll + e.dy end
    return
  end
  if e.type ~= "keydown" then return end
  if e.key == "escape" then
    if editing then editing, editId = false, nil; return end
    if search ~= "" then search = "" end
    return
  end
  if editing then
    local li = lineIndex(editId)
    if li then
      local en = entries[keyOf(selDay)]
      if e.key == "backspace" and en and en.lines[li] == "" and li > 1 then pendingAction = {kind = "delline", idx = li}
      elseif e.key == "up" then pendingAction = {kind = "up", idx = li}
      elseif e.key == "down" then pendingAction = {kind = "down", idx = li} end
    end
    return
  end
  if e.key == "left" then selectDay(selDay - 86400)
  elseif e.key == "right" then if selDay < todayNoon then selectDay(selDay + 86400) end
  elseif e.key == "up" then selectDay(selDay - 7 * 86400)
  elseif e.key == "down" then selectDay(min(todayNoon, selDay + 7 * 86400))
  elseif e.key == "enter" and selDay <= todayNoon then
    local en = entries[keyOf(selDay)]
    focusField("line" .. (en and #en.lines or 1))
  end
end

function app.menu()
  return {
    {title = TR("menu_journal"), items = {
      {label = TR("today"), id = 1},
      {label = TR("prev_day"), id = 2},
      {label = TR("next_day"), id = 3},
      "-",
      {label = TR("export"), id = 4},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then selectDay(todayNoon); stripEnd = todayNoon + 3 * 86400
  elseif id == 2 then selectDay(selDay - 86400)
  elseif id == 3 then if selDay < todayNoon then selectDay(selDay + 86400) end
  elseif id == 4 then
    local keys = {}
    for k in pairs(entries) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {TR("export_title"), ""}
    for _, k in ipairs(keys) do
      local en = entries[k]
      local head = "## " .. k
      if en.mood and en.mood > 0 then head = head .. "  (" .. TR(MOODS[en.mood].key) .. ")" end
      out[#out + 1] = head
      local tags = tagsOf(en)
      if #tags > 0 then out[#out + 1] = "#" .. table.concat(tags, " #") end
      for _, l in ipairs(en.lines) do if trim(l) ~= "" then out[#out + 1] = l end end
      out[#out + 1] = ""
    end
    local dir = fs.dir("documents")
    local path = dir .. "/" .. TR("export_file") .. ".md"
    if fs.write(path, table.concat(out, "\n")) then
      sys.notify(TR("export_done"), path)
    else
      ui.alert(TR("export_failed"), path, {TR("ok")})
    end
  end
end

function app.close()
  purge()
  save()
  return true
end

return app
