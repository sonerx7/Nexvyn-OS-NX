-- Capitals: a world capitals quiz (country -> capital or capital -> country) with continents, a practice mode for
-- the ones you missed, per-continent best scores with a chart, and a searchable list of every country.
local DATA = require("data")
local app = {}

local CONTS = {"all", "eu", "as", "af", "na", "sa", "oc", "miss"}
local CONT_KEYS = {all = "cont_all", eu = "cont_eu", as = "cont_as", af = "cont_af", na = "cont_na", sa = "cont_sa",
  oc = "cont_oc", miss = "cont_miss"}
local CONT_COLORS = {all = "#5E5CE6", eu = "#0A84FF", as = "#FF9F0A", af = "#30D158", na = "#FF375F", sa = "#64D2FF",
  oc = "#BF5AF2", miss = "#FF453A"}

local tr = false            -- show Turkish names
local screen = "home"
local contSel, modeSel, lenSel = 1, 1, 1   -- filter, 1 = country->capital / 2 = capital->country, 1 = 10 / 2 = 20
local best = {}             -- ["eu"] = best percent
local stats = {games = 0, answered = 0, correct = 0}
local mistakes = {}         -- [English country name] = times missed (decreases when answered right)
local q = nil
local search, sortSel, browseCont = "", 1, 1
local parts = {}            -- confetti
local anim = 0              -- screen transition 0..1
local toast, toastT = "", 0
local filtered, filterKey = {}, nil   -- browse list cache

-- ------------------------------------------------------------------ helpers
local function country(c) return tr and c[3] or c[1] end
local function capital(c) return tr and c[4] or c[2] end

local FOLD = {["İ"] = "i", ["I"] = "i", ["ı"] = "i", ["Ş"] = "s", ["ş"] = "s", ["Ç"] = "c", ["ç"] = "c", ["Ğ"] = "g",
  ["ğ"] = "g", ["Ö"] = "o", ["ö"] = "o", ["Ü"] = "u", ["ü"] = "u", ["é"] = "e", ["á"] = "a", ["í"] = "i", ["ó"] = "o",
  ["ș"] = "s", ["ă"] = "a", ["â"] = "a", ["î"] = "i", ["É"] = "e"}
local function fold(s)
  s = s:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch) return FOLD[ch] or ch end)
  return s:lower()
end

local function pool(cont)
  local out = {}
  for _, c in ipairs(DATA) do
    if cont == "all" or c[5] == cont or (cont == "miss" and (mistakes[c[1]] or 0) > 0) then out[#out + 1] = c end
  end
  return out
end

local function shuffle(t)
  for i = #t, 2, -1 do local j = math.random(1, i); t[i], t[j] = t[j], t[i] end
  return t
end

local function showToast(s) toast, toastT = s, 2.2 end

local function confetti(w, h)
  for i = 1, 90 do
    parts[i] = {x = w / 2 + math.random(-40, 40), y = h * 0.3, vx = math.random(-260, 260), vy = math.random(-420, -120),
      r = math.random() * 6.28, vr = math.random(-8, 8), c = ({"#FF453A", "#FFD60A", "#30D158", "#0A84FF", "#BF5AF2"})[i % 5 + 1],
      life = 2.4 + math.random()}
  end
end

-- ------------------------------------------------------------------ quiz
local function makeQuestion(c, list)
  local opts, seen = {c}, {[c[1]] = true}
  local cands = shuffle({table.unpack(list)})
  for _, o in ipairs(cands) do
    if #opts >= 4 then break end
    if not seen[o[1]] then seen[o[1]] = true; opts[#opts + 1] = o end
  end
  if #opts < 4 then
    for _, o in ipairs(shuffle({table.unpack(DATA)})) do
      if #opts >= 4 then break end
      if not seen[o[1]] then seen[o[1]] = true; opts[#opts + 1] = o end
    end
  end
  return {c = c, opts = shuffle(opts)}
end

local function startQuiz()
  local cont = CONTS[contSel]
  local list = pool(cont)
  if #list == 0 then showToast(TR("no_mistakes")) return end
  local n = math.min(#list, lenSel == 1 and 10 or 20)
  local order = shuffle({table.unpack(list)})
  -- distractors come from the same continent when possible
  local qs = {}
  for i = 1, n do
    local c = order[i]
    local same = {}
    for _, o in ipairs(DATA) do if o[5] == c[5] then same[#same + 1] = o end end
    qs[i] = makeQuestion(c, same)
  end
  q = {cont = cont, reverse = modeSel == 2, list = qs, i = 1, correct = 0, streak = 0, bestStreak = 0, picked = nil,
    wait = 0, missed = {}, slide = 1, newBest = false}
  screen, anim = "quiz", 0
end

local function finish(w, h)
  local pct = math.floor(q.correct * 100 / #q.list + 0.5)
  q.pct = pct
  stats.games = stats.games + 1
  store.set("stats", stats)
  if q.cont ~= "miss" and pct > (best[q.cont] or -1) then
    q.newBest = (best[q.cont] or -1) >= 0 or pct > 0
    best[q.cont] = pct
    store.set("best", best)
  end
  if q.newBest and pct > 0 then confetti(w, h); audio.play("notify") end
  screen, anim = "result", 0
end

local function answer(opt)
  if not q or q.wait > 0 or not opt then return end
  local cur = q.list[q.i]
  local ok = opt == cur.c
  q.picked = opt
  stats.answered = stats.answered + 1
  if ok then
    q.correct = q.correct + 1
    q.streak = q.streak + 1
    q.bestStreak = math.max(q.bestStreak, q.streak)
    stats.correct = stats.correct + 1
    if (mistakes[cur.c[1]] or 0) > 0 then mistakes[cur.c[1]] = mistakes[cur.c[1]] - 1 end
    audio.tone(740 + math.min(q.streak, 6) * 50, 0.1, 0.35, "triangle")
    q.wait = 0.8
  else
    q.streak = 0
    mistakes[cur.c[1]] = (mistakes[cur.c[1]] or 0) + 1
    q.missed[#q.missed + 1] = cur.c
    audio.tone(190, 0.22, 0.35, "square")
    sys.vibrate(0.35, 70)
    q.wait = 1.7
  end
  store.set("mistakes", mistakes)
  store.set("stats", stats)
  filterKey = nil
end

local function advance()
  local w, h = gfx.size()
  if q.i >= #q.list then finish(w, h) return end
  q.i = q.i + 1
  q.picked, q.slide = nil, 0
end

-- ------------------------------------------------------------------ callbacks
function app.load()
  tr = sys.lang() == "tr"
  best = store.get("best", {})
  if type(best) ~= "table" then best = {} end
  local s = store.get("stats", {})
  stats = {games = tonumber(s.games) or 0, answered = tonumber(s.answered) or 0, correct = tonumber(s.correct) or 0}
  mistakes = store.get("mistakes", {})
  if type(mistakes) ~= "table" then mistakes = {} end
  contSel = math.max(1, math.min(#CONTS, store.get("cont", 1)))
  modeSel = store.get("mode", 1) == 2 and 2 or 1
  lenSel = store.get("len", 1) == 2 and 2 or 1
  math.randomseed(math.floor(sys.epoch()))
end

function app.update(dt)
  anim = math.min(1, anim + dt * 4)
  if toastT > 0 then toastT = toastT - dt end
  if q and screen == "quiz" then
    q.slide = math.min(1, q.slide + dt * 5)
    if q.wait > 0 then
      q.wait = q.wait - dt
      if q.wait <= 0 then q.wait = 0; advance() end
    end
  end
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.vy = p.vy + 520 * dt
    p.x, p.y, p.r = p.x + p.vx * dt, p.y + p.vy * dt, p.r + p.vr * dt
    p.life = p.life - dt
    if p.life <= 0 then table.remove(parts, i) end
  end
end

local function ease(t) return 1 - (1 - t) ^ 3 end

local function missCount()
  local n = 0
  for _, v in pairs(mistakes) do if (tonumber(v) or 0) > 0 then n = n + 1 end end
  return n
end

local function drawHome(w, h)
  gfx.color(theme.text)
  gfx.text(TR("app_name"), 20, 18, 24, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("subtitle", #DATA), 20, 50, 13)
  if ui.button(TR("browse"), w - 156, 18, 136, 32, "default", "search") then screen, anim = "browse", 0 end

  local y = 82
  local half = (w - 52) / 2
  ui.group(20, y, w - 40, 152)
  gfx.color(theme.text2)
  gfx.text(TR("continent"), 36, y + 14, 13, "semibold")
  local labels = {}
  for i, c in ipairs(CONTS) do labels[i] = TR(CONT_KEYS[c]) .. (c == "miss" and " (" .. missCount() .. ")" or "") end
  local ns = ui.dropdown("cont", labels, contSel, 36, y + 34, half - 16, 32)
  if ns ~= contSel then contSel = ns; store.set("cont", ns) end
  gfx.color(theme.text2)
  gfx.text(TR("questions"), 36 + half, y + 14, 13, "semibold")
  local nl = ui.segmented("len", {"10", "20"}, lenSel, 36 + half, y + 34, half - 32, 32)
  if nl ~= lenSel then lenSel = nl; store.set("len", nl) end
  gfx.color(theme.text2)
  gfx.text(TR("direction"), 36, y + 78, 13, "semibold")
  local nm = ui.segmented("mode", {TR("mode_cap"), TR("mode_country")}, modeSel, 36, y + 98, w - 72 - 176, 32)
  if nm ~= modeSel then modeSel = nm; store.set("mode", nm) end
  if ui.button(TR("start"), w - 196, y + 98, 160, 32, "primary", "play_arrow") then startQuiz() end

  -- best score per continent chart
  local cy = y + 168
  gfx.color(theme.text)
  gfx.text(TR("best_scores"), 20, cy, 15, "semibold")
  gfx.color(theme.text3)
  local acc = stats.answered > 0 and math.floor(stats.correct * 100 / stats.answered + 0.5) or 0
  gfx.text(TR("overall", stats.games, acc), 0, cy + 2, 12, "sans", "right", w - 20)
  local top, bottom = cy + 30, h - 40
  local ch = bottom - top
  if ch < 40 then return end
  local n = 7
  local bw = (w - 40) / n
  gfx.color(theme.separator)
  gfx.line(20, bottom, w - 20, bottom, 1)
  for i = 1, n do
    local c = CONTS[i]
    local v = best[c]
    local bx = 20 + (i - 1) * bw
    local bh = (tonumber(v) or 0) / 100 * (ch - 18) * ease(anim)
    gfx.rect(bx + bw * 0.2, bottom - (ch - 18), bw * 0.6, ch - 18, 6, theme.field)
    if bh > 1 then gfx.gradient(bx + bw * 0.2, bottom - bh, bw * 0.6, bh, CONT_COLORS[c], CONT_COLORS[c] .. "99", false, 6) end
    gfx.color(theme.text2)
    gfx.text(v and (v .. "%") or "–", bx, bottom - (ch - 18) - 16, 11, "semibold", "center", bw)
    gfx.text(TR(CONT_KEYS[c]), bx, bottom + 6, 11, "sans", "center", bw)
  end
end

local function drawQuiz(w, h)
  local cur = q.list[q.i]
  if not cur then return end
  if ui.button(TR("quit"), 16, 12, 100, 32, "plain", "close") then screen, anim = "home", 0; return end
  gfx.color(theme.text2)
  gfx.text(TR("q_of", q.i, #q.list), 0, 20, 14, "semibold", "center", w)
  gfx.text(TR("score", q.correct), 0, 20, 14, "sans", "right", w - 20)
  ui.progress((q.i - 1 + (q.wait > 0 and 1 or 0)) / #q.list, 20, 54, w - 40, 6)

  local s = ease(q.slide)
  gfx.alpha(s)
  gfx.push((1 - s) * 60, 0)
  local cardH = math.min(130, h * 0.26)
  local col = CONT_COLORS[cur.c[5]]
  gfx.shadow(20, 72, w - 40, cardH, 16, 12, 3)
  gfx.gradient(20, 72, w - 40, cardH, col, col .. "AA", true, 16)
  gfx.color("#FFFFFFCC")
  gfx.text(q.reverse and TR("which_country") or TR("which_capital"), 20, 86, 14, "semibold", "center", w - 40)
  gfx.color("#FFFFFF")
  local name = q.reverse and capital(cur.c) or country(cur.c)
  local size = math.min(34, (w - 80) / math.max(6, utf8.len(name) or #name) * 1.7)
  gfx.text(name, 20, 72 + cardH / 2 - size * 0.45, size, "bold", "center", w - 40)
  gfx.pop()
  gfx.unalpha()

  local top = 72 + cardH + 18
  local gap = 12
  local bw = (w - 40 - gap) / 2
  local bh = math.min(72, (h - top - 50 - gap) / 2)
  for i, o in ipairs(cur.opts) do
    local x = 20 + ((i - 1) % 2) * (bw + gap)
    local y = top + ((i - 1) // 2) * (bh + gap)
    local hit = ui.hit("opt" .. i, x, y, bw, bh)
    local bg, fg = theme.field, theme.text
    if q.picked then
      if o == cur.c then bg, fg = theme.green, "#FFFFFF" elseif o == q.picked then bg, fg = theme.red, "#FFFFFF" end
    elseif hit.hovered then bg = theme.hover end
    gfx.shadow(x, y, bw, bh, 12, 6, 2)
    gfx.rect(x, y, bw, bh, 12, bg)
    gfx.color(theme.separator)
    gfx.rectLine(x, y, bw, bh, 12, 1)
    gfx.color(fg)
    local label = q.reverse and country(o) or capital(o)
    gfx.wrap(label, x + 30, y + bh / 2 - 11, bw - 44, 17, "semibold", "center")
    gfx.color(theme.text3)
    gfx.text(tostring(i), x + 10, y + 8, 11, "semibold")
    if hit.clicked then answer(o) end
  end
  gfx.color(theme.text2)
  local msg = ""
  if q.picked and q.picked ~= cur.c then
    msg = TR("wrong", country(cur.c), capital(cur.c))
  elseif q.picked then msg = TR("right")
  elseif q.streak >= 3 then msg = TR("streak", q.streak) end
  gfx.text(msg, 20, h - 30, 14, "semibold", "center", w - 40)
end

local function resultText()
  local cont = TR(CONT_KEYS[q.cont])
  return TR("share_text", q.correct, #q.list, cont, q.pct or 0)
end

local function drawResult(w, h)
  local cx = w / 2
  local r = math.min(70, h * 0.14)
  local cy = 40 + r
  local p = (q.pct or 0) / 100 * ease(anim)
  gfx.color(theme.field)
  gfx.arc(cx, cy, r, 0, math.pi * 2, 12)
  gfx.color(p >= 0.8 and theme.green or p >= 0.5 and theme.orange or theme.red)
  if p > 0.001 then gfx.arc(cx, cy, r, -math.pi / 2, -math.pi / 2 + p * math.pi * 2, 12) end
  gfx.color(theme.text)
  gfx.text(math.floor(p * 100 + 0.5) .. "%", cx - r, cy - 18, 30, "bold", "center", r * 2)
  local y = cy + r + 14
  gfx.text(TR("result", q.correct, #q.list), 0, y, 18, "semibold", "center", w)
  gfx.color(q.newBest and theme.orange or theme.text2)
  gfx.text(q.newBest and TR("new_best") or TR("best_streak", q.bestStreak), 0, y + 26, 14, q.newBest and "bold" or "sans", "center", w)

  local by = h - 50
  local bw = math.min(150, (w - 64) / 3)
  local x0 = cx - (bw * 3 + 24) / 2
  if ui.button(TR("again"), x0, by, bw, 36, "primary", "refresh") then startQuiz() end
  if ui.button(TR("home"), x0 + bw + 12, by, bw, 36, "default", "home") then screen, anim = "home", 0 end
  if ui.button(TR("copy"), x0 + (bw + 12) * 2, by, bw, 36, "default", "content_copy") then
    sys.clipboard(resultText()); showToast(TR("copied"))
  end

  -- mistakes to review
  local top = y + 56
  local lh = by - 12 - top
  if lh < 40 then return end
  ui.group(20, top, w - 40, lh)
  if #q.missed == 0 then
    gfx.icon("emoji_events", cx, top + lh / 2 - 12, 34, theme.yellow)
    gfx.color(theme.text2)
    gfx.text(TR("no_errors"), 0, top + lh / 2 + 12, 14, "sans", "center", w)
    return
  end
  gfx.color(theme.text2)
  gfx.text(TR("review"), 36, top + 10, 13, "semibold")
  local rh = 30
  ui.beginScroll("miss", 20, top + 32, w - 40, lh - 36, #q.missed * rh)
  for i, c in ipairs(q.missed) do
    local ry = (i - 1) * rh
    gfx.color(theme.text)
    gfx.text(country(c), 16, ry + 6, 14, "semibold")
    gfx.color(theme.accent)
    gfx.text(capital(c), 0, ry + 6, 14, "sans", "right", w - 72)
  end
  ui.endScroll()
end

local function refilter()
  local key = search .. "|" .. sortSel .. "|" .. browseCont .. "|" .. tostring(tr)
  if key == filterKey then return end
  filterKey = key
  filtered = {}
  local f = fold(search)
  local cont = CONTS[browseCont]
  for _, c in ipairs(DATA) do
    if cont == "all" or c[5] == cont or (cont == "miss" and (mistakes[c[1]] or 0) > 0) then
      if f == "" or fold(country(c)):find(f, 1, true) or fold(capital(c)):find(f, 1, true) then filtered[#filtered + 1] = c end
    end
  end
  local idx = sortSel == 1 and 1 or 2
  table.sort(filtered, function(a, b)
    local x, y = fold(idx == 1 and country(a) or capital(a)), fold(idx == 1 and country(b) or capital(b))
    return x < y
  end)
end

local function drawBrowse(w, h)
  if ui.button(TR("back"), 16, 12, 100, 32, "plain", "arrow_back") then screen, anim = "home", 0; return end
  gfx.color(theme.text)
  gfx.text(TR("browse"), 0, 16, 20, "bold", "center", w)
  local fw = w - 40 - 300
  search = ui.textfield("search", search, 20, 56, math.max(140, fw), 32, TR("search_hint"), "search")
  local labels = {}
  for i, c in ipairs(CONTS) do labels[i] = TR(CONT_KEYS[c]) end
  local nb = ui.dropdown("bcont", labels, browseCont, w - 290, 56, 140, 32)
  if nb ~= browseCont then browseCont = nb end
  sortSel = ui.segmented("sort", {TR("sort_country"), TR("sort_capital")}, sortSel, w - 142, 56, 122, 32)
  refilter()
  local top = 100
  local lh = h - top - 16
  ui.group(20, top, w - 40, lh)
  if #filtered == 0 then
    gfx.icon("travel_explore", w / 2, top + lh / 2 - 14, 40, theme.text3)
    gfx.color(theme.text3)
    gfx.text(TR("no_results"), 0, top + lh / 2 + 14, 14, "sans", "center", w)
    return
  end
  local rh = 36
  ui.beginScroll("list", 20, top, w - 40, lh, #filtered * rh + 8)
  for i, c in ipairs(filtered) do
    local ry = 4 + (i - 1) * rh
    gfx.color(CONT_COLORS[c[5]])
    gfx.circle(18, ry + rh / 2, 5)
    gfx.color(theme.text)
    gfx.text(country(c), 32, ry + 9, 14, "semibold")
    gfx.color(theme.text2)
    gfx.text(capital(c), 0, ry + 9, 14, "sans", "right", w - 60)
    if (mistakes[c[1]] or 0) > 0 then gfx.icon("error_outline", w - 60 - gfx.textWidth(capital(c), 14) - 16, ry + rh / 2, 14, theme.red) end
    if i < #filtered then ui.separator(32, ry + rh, w - 56) end
  end
  ui.endScroll()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local a = ease(anim)
  gfx.alpha(0.35 + 0.65 * a)
  gfx.push(0, (1 - a) * 14)
  if screen == "quiz" and q then drawQuiz(w, h)
  elseif screen == "result" and q then drawResult(w, h)
  elseif screen == "browse" then drawBrowse(w, h)
  else screen = "home"; drawHome(w, h) end
  gfx.pop()
  gfx.unalpha()
  for _, p in ipairs(parts) do
    gfx.color(p.c)
    local s = 5
    gfx.poly({p.x + math.cos(p.r) * s, p.y + math.sin(p.r) * s, p.x + math.cos(p.r + 2.2) * s, p.y + math.sin(p.r + 2.2) * s,
      p.x + math.cos(p.r + 3.6) * s, p.y + math.sin(p.r + 3.6) * s})
  end
  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, h - 86, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, h - 78, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if screen == "quiz" and q then
    local n = tonumber(k)
    local cur = q.list[q.i]
    if n and cur and cur.opts[n] then answer(cur.opts[n])
    elseif k == "escape" then screen, anim = "home", 0 end
  elseif screen == "result" then
    if k == "enter" then startQuiz() elseif k == "escape" then screen, anim = "home", 0 end
  elseif screen == "browse" then
    if k == "escape" then screen, anim = "home", 0 end
  elseif k == "enter" or k == "space" then startQuiz()
  end
end

function app.menu()
  return {{title = TR("app_name"), items = {
    {label = TR("start"), id = 1, shortcut = "Enter"},
    {label = TR("practice"), id = 2},
    {label = TR("browse"), id = 3},
    "-",
    {label = TR("reset_stats"), id = 4},
  }}}
end

function app.onmenu(id)
  if id == 1 then startQuiz()
  elseif id == 2 then contSel = #CONTS; startQuiz()
  elseif id == 3 then screen, anim = "browse", 0
  elseif id == 4 then
    ui.alert(TR("reset_stats"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then
        best, mistakes, stats = {}, {}, {games = 0, answered = 0, correct = 0}
        store.set("best", best); store.set("mistakes", mistakes); store.set("stats", stats)
        filterKey = nil
      end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
