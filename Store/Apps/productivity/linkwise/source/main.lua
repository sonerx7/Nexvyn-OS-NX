-- Linkwise for Nexvyn OS: a Markdown knowledge base. Notes link to each other with [[double brackets]], every note
-- lists the notes that link to it (backlinks), a force-directed graph draws the whole web, tags group notes and the
-- search finds any word. Lines are edited one at a time in place, so the on-screen keyboard, a USB keyboard and the
-- controller all work. Undo/redo, daily notes, Markdown import/export and a JSON backup.
local K = require("kit")
local app = {}

local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt
local clamp, alpha = K.clamp, K.alpha

-- ================================================================== state
local notes, byId = {}, {}
local nextId = 1
local cur = nil                      -- the open note
local dirty, changedAt = false, 0
local hist = K.history(150)
local pendingSnap = nil              -- snapshot taken when a line edit starts, pushed on the first change
local indexDirty, indexAt = true, -1
local index = {byTitle = {}, out = {}, back = {}, tags = {}, tagList = {}, ghosts = {}, tagsOf = {}}

local view = "notes"                 -- "notes" | "graph"
local mobilePane = "list"            -- narrow windows: "list" | "note"
local showSide, showRight = true, true
local rightTab = 1                   -- 1 backlinks, 2 outline, 3 info
local sortMode = 1                   -- 1 recent, 2 title
local query, tagFilter = "", nil
local results, resultsKey = {}, nil
local listSel = 1                    -- keyboard selection in the list
local lines, linesBody = {}, nil     -- the open note split into lines
local editLine, editText = nil, ""   -- the line being edited
local lineCursor = 1                 -- keyboard line cursor (not editing)
local titleEdit, titleText = false, ""
local listScroll, edScroll, panelScroll = K.scroller(), K.scroller(), K.scroller()
local listRect, edRect, panelRect = {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}
local lineTops = {}                  -- y of each line in the editor (content coordinates)
local picker = nil                   -- {kind = "link" | "tag", q, sel, t}
local frameDt = 1 / 60
local narrowMode = false
local lastStopped = nil              -- {line, t, id}: the line that was being edited a moment ago (toolbar taps)
local cache = {}                     -- work that only changes with the note or the index

local function now() return sys.epoch() end
local function key(t) return K.lower(K.trim(t)) end
local function markDirty() dirty = true; changedAt = sys.time(); indexDirty = true end

-- ================================================================== links, tags and the index
local function stripCode(body)
  return (body:gsub("```.-```", ""):gsub("`[^`\n]*`", ""))
end
local function linksOf(body)
  local out = {}
  for inner in stripCode(body):gmatch("%[%[(.-)%]%]") do
    local target = K.trim(inner:match("^([^|]*)") or inner)
    if target ~= "" and not target:find("\n") then out[#out + 1] = target end
  end
  return out
end
local function tagsOf(body)
  local out, seen = {}, {}
  for tag in ("\n" .. stripCode(body)):gmatch("[%s%(]#([%w_%-/\128-\255]+)") do
    local k = K.lower(tag)
    if not seen[k] and not tag:match("^%d+$") then seen[k] = true; out[#out + 1] = tag end
  end
  return out
end

local function rebuildIndex()
  index.byTitle, index.out, index.back, index.tags, index.ghosts, index.tagsOf = {}, {}, {}, {}, {}, {}
  for _, n in ipairs(notes) do index.byTitle[key(n.title)] = n end
  for _, n in ipairs(notes) do
    local outs, seen = {}, {}
    for _, t in ipairs(linksOf(n.body)) do
      local k = key(t)
      if not seen[k] then
        seen[k] = true
        local target = index.byTitle[k]
        if target and target ~= n then
          outs[#outs + 1] = target.id
          local b = index.back[target.id] or {}
          b[#b + 1] = n.id
          index.back[target.id] = b
        elseif not target then
          local g = index.ghosts[k] or {title = t, from = {}}
          g.from[#g.from + 1] = n.id
          index.ghosts[k] = g
        end
      end
    end
    index.out[n.id] = outs
    local tg = tagsOf(n.body)
    index.tagsOf[n.id] = tg
    for _, t in ipairs(tg) do
      local k = K.lower(t)
      local e = index.tags[k] or {name = t, key = k, count = 0}
      e.count = e.count + 1
      index.tags[k] = e
    end
  end
  index.tagList = {}
  for _, e in pairs(index.tags) do index.tagList[#index.tagList + 1] = e end
  table.sort(index.tagList, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.key < b.key
  end)
  indexDirty, indexAt = false, sys.time()
  resultsKey = nil
end

-- ================================================================== notes
local function posOf(n) for i, x in ipairs(notes) do if x == n then return i end end return nil end
local function uniqueTitle(t, except)
  t = K.trim(t)
  if t == "" then t = TR("untitled") end
  local base, i = t, 2
  while true do
    local found = false
    for _, n in ipairs(notes) do
      if n ~= except and key(n.title) == key(t) then found = true; break end
    end
    if not found then return t end
    t = base .. " " .. i
    i = i + 1
  end
end
local function addNote(title, body, at)
  local n = {id = nextId, title = uniqueTitle(title), body = body or "", pinned = false, created = now(), updated = now()}
  nextId = nextId + 1
  if at then table.insert(notes, at, n) else notes[#notes + 1] = n end
  byId[n.id] = n
  markDirty()
  return n
end
local function removeNote(n)
  local p = posOf(n)
  if p then table.remove(notes, p) end
  byId[n.id] = nil
  markDirty()
end

-- undo entries are lists of note snapshots
local function capture(id)
  local n = byId[id]
  if not n then return {id = id, exists = false} end
  return {id = id, exists = true, title = n.title, body = n.body, pinned = n.pinned, created = n.created,
          updated = n.updated, pos = posOf(n)}
end
local function captureAll(ids)
  local out = {}
  for _, id in ipairs(ids) do out[#out + 1] = capture(id) end
  return out
end
local function restore(list)
  for _, s in ipairs(list) do
    local n = byId[s.id]
    if not s.exists then
      if n then removeNote(n) end
    else
      if not n then
        n = {id = s.id}
        table.insert(notes, clamp(s.pos or (#notes + 1), 1, #notes + 1), n)
        byId[s.id] = n
      end
      n.title, n.body, n.pinned, n.created, n.updated = s.title, s.body, s.pinned, s.created, s.updated
    end
  end
  markDirty()
end

local function saveNow()
  local out = {}
  for i, n in ipairs(notes) do
    out[i] = {id = n.id, title = n.title, body = n.body, pinned = n.pinned and true or false,
              created = n.created, updated = n.updated}
  end
  store.set("notes", out)
  store.set("nextId", nextId)
  store.set("cur", cur and cur.id or 0)
  store.set("prefs", {side = showSide, right = showRight, tab = rightTab, sort = sortMode})
  dirty = false
end

-- ================================================================== sample notes
local function seed()
  local t1, t2, t3, t4, t5 = TR("s1_title"), TR("s2_title"), TR("s3_title"), TR("s4_title"), TR("s5_title")
  addNote(t1, TR("s1_body", t2, t3, t4))
  addNote(t2, TR("s2_body", t1))
  addNote(t3, TR("s3_body", t4, t5, TR("s_ghost")))
  addNote(t4, TR("s4_body", t3))
  addNote(t5, TR("s5_body", t3))
  local d = addNote(K.dayKey(now()), TR("s6_body", t1))
  d.updated = now() - 60
  notes[1].pinned = true
  cur = notes[1]
end

local function loadAll()
  notes, byId = {}, {}
  nextId = math.max(1, K.int(store.get("nextId", 1), 1))
  local raw = store.get("notes", nil)
  if type(raw) == "table" and #raw > 0 then
    for _, r in ipairs(raw) do
      if type(r) == "table" and r.title ~= nil then
        local id = K.int(r.id, 0)
        if id <= 0 or byId[id] then id = nextId end
        if id >= nextId then nextId = id + 1 end
        local n = {id = id, title = K.str(r.title, TR("untitled")), body = K.str(r.body, ""), pinned = r.pinned == true,
                   created = K.int(r.created, now()), updated = K.int(r.updated, now())}
        notes[#notes + 1] = n
        byId[id] = n
      end
    end
    cur = byId[K.int(store.get("cur", 0), 0)] or notes[1]
  else
    seed()
  end
  local p = store.get("prefs", nil)
  if type(p) == "table" then
    showSide = p.side ~= false
    showRight = p.right ~= false
    rightTab = clamp(K.int(p.tab, 1), 1, 3)
    sortMode = clamp(K.int(p.sort, 1), 1, 2)
  end
  rebuildIndex()
end

-- ================================================================== list order, search
local function sortedNotes()
  local list = {}
  for _, n in ipairs(notes) do
    if not tagFilter then list[#list + 1] = n
    else
      for _, t in ipairs(index.tagsOf[n.id] or {}) do
        if K.lower(t) == tagFilter then list[#list + 1] = n; break end
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.pinned and 1 or 0) ~= (b.pinned and 1 or 0) then return a.pinned and true or false end
    if sortMode == 2 then return key(a.title) < key(b.title) end
    if a.updated ~= b.updated then return a.updated > b.updated end
    return a.id > b.id
  end)
  return list
end

local function firstLine(body)
  for ln in (body .. "\n"):gmatch("(.-)\n") do
    local t = K.trim(ln)
    if t ~= "" and not t:match("^#+%s") and not t:match("^```") and not t:match("^%-%-%-") then
      t = t:gsub("^[-*+]%s+%[[ xX]%]%s*", ""):gsub("^[-*+]%s+", ""):gsub("^>%s*", "")
      t = t:gsub("%[%[([^%]|]*)|?([^%]]*)%]%]", function(a, b) return b ~= "" and b or a end):gsub("[*`]", "")
      return t
    end
  end
  return ""
end

local function searchNotes(q)
  local words = {}
  for w in K.lower(q):gmatch("%S+") do words[#words + 1] = w end
  local res = {}
  if #words == 0 then return res end
  for _, n in ipairs(notes) do
    local lt, lb = K.lower(n.title), K.lower(n.body)
    local score, ok = 0, true
    for _, w in ipairs(words) do
      local inT = lt:find(w, 1, true)
      local inB = lb:find(w, 1, true)
      if not inT and not inB then ok = false; break end
      if inT then score = score + (inT == 1 and 40 or 20) end
      if inB then
        score = score + 4
        local _, c = lb:gsub(w:gsub("%p", "%%%0"), "")
        score = score + min(c, 10)
      end
    end
    if ok then
      local snip = ""
      for ln in (n.body .. "\n"):gmatch("(.-)\n") do
        if K.lower(ln):find(words[1], 1, true) then snip = K.trim(ln); break end
      end
      if snip == "" then snip = firstLine(n.body) end
      res[#res + 1] = {note = n, score = score, snip = snip}
    end
  end
  table.sort(res, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.note.updated > b.note.updated
  end)
  return res
end

local function listItems()
  local k = query .. "\0" .. tostring(tagFilter) .. "\0" .. sortMode .. "\0" .. indexAt
  if k == resultsKey then return results end
  resultsKey = k
  if K.trim(query) ~= "" then
    results = {}
    for _, r in ipairs(searchNotes(query)) do
      if not tagFilter then results[#results + 1] = r
      else
        for _, t in ipairs(index.tagsOf[r.note.id] or {}) do
          if K.lower(t) == tagFilter then results[#results + 1] = r; break end
        end
      end
    end
  else
    results = {}
    for _, n in ipairs(sortedNotes()) do results[#results + 1] = {note = n, snip = firstLine(n.body)} end
  end
  return results
end

-- ================================================================== editing
local function syncLines()
  if not cur then lines, linesBody = {}, nil; return end
  if linesBody ~= cur.body then
    lines = K.split(cur.body, "\n")
    linesBody = cur.body
    lineCursor = clamp(lineCursor, 1, max(1, #lines))
  end
end
local function setBody(newBody)
  cur.body = newBody
  cur.updated = now()
  linesBody = nil
  markDirty()
end
local function commitLines()
  local b = table.concat(lines, "\n")
  cur.body = b
  linesBody = b
  cur.updated = now()
  markDirty()
end

local function stopEdit()
  if editLine then lastStopped = {line = editLine, t = sys.time(), id = cur and cur.id} end
  editLine = nil
  pendingSnap = nil
  if K.editing == "ln" then K.blur() end
end

local function startEdit(i)
  if not cur then return end
  syncLines()
  if #lines == 0 then lines[1] = "" end
  i = clamp(i, 1, #lines)
  editLine, editText = i, lines[i] or ""
  lineCursor = i
  pendingSnap = {capture(cur.id)}
  K.focus("ln")
  titleEdit = false
end

local function setEditText(t)
  if not editLine or t == editText then return end
  if pendingSnap then hist:push(pendingSnap); pendingSnap = nil end
  editText = t
  lines[editLine] = t
  commitLines()
end

-- what the next line starts with after Enter (lists continue); second result: the line was an empty item
local function continuation(line)
  local ind = line:match("^(%s*)[-*+] %[[ xX]%]")
  if ind then return ind .. "- [ ] ", line:match("^%s*[-*+] %[[ xX]%]%s*$") ~= nil end
  local ind2, mk = line:match("^(%s*)([-*+])%s")
  if ind2 then return ind2 .. mk .. " ", line:match("^%s*[-*+]%s*$") ~= nil end
  local ind3, num, sep = line:match("^(%s*)(%d+)([.)])%s")
  if ind3 then return ind3 .. (tonumber(num) + 1) .. sep .. " ", line:match("^%s*%d+[.)]%s*$") ~= nil end
  if line:match("^>") then return "> ", line:match("^>%s*$") ~= nil end
  return "", false
end

local function enterPressed()
  if not editLine then return end
  local cont, emptyItem = continuation(editText)
  if emptyItem then setEditText(""); return end
  if pendingSnap then hist:push(pendingSnap); pendingSnap = nil end
  table.insert(lines, editLine + 1, cont)
  commitLines()
  local n = editLine + 1
  editLine, editText = n, cont
  lineCursor = n
  K.focus("ln")
end

local function deleteEmptyLine()
  if not editLine or editText ~= "" or #lines <= 1 then return false end
  if pendingSnap then hist:push(pendingSnap); pendingSnap = nil end
  table.remove(lines, editLine)
  commitLines()
  local n = max(1, editLine - 1)
  editLine, editText = n, lines[n] or ""
  lineCursor = n
  K.focus("ln")
  return true
end

local function moveEdit(d)
  if not editLine then return end
  local n = editLine + d
  if n < 1 or n > #lines then return end
  startEdit(n)
end

-- the line a toolbar button acts on: the one being edited, or the one that was edited a moment ago
local function recentLine()
  if editLine then return editLine, true end
  if lastStopped and cur and lastStopped.id == cur.id and sys.time() - lastStopped.t < 1.5 then return lastStopped.line, true end
  return lineCursor, false
end

-- a whole-line change from a toolbar button or a checkbox
local function changeLine(i, newText)
  syncLines()
  if not lines[i] or lines[i] == newText then return end
  hist:push({capture(cur.id)})
  pendingSnap = nil
  lines[i] = newText
  if editLine == i then editText = newText end
  commitLines()
end

local function toggleTask(i)
  local l = lines[i]
  if not l then return end
  local a, box, b = l:match("^(%s*[-*+] %[)([ xX])(%].*)$")
  if a then
    changeLine(i, a .. (box == " " and "x" or " ") .. b)
    audio.play("click", 0.3)
  end
end

local function cycleHeading(l)
  local h, rest = l:match("^(#+)%s+(.*)$")
  if not h then return "# " .. l end
  if #h >= 3 then return rest end
  return string.rep("#", #h + 1) .. " " .. rest
end
local function toggleBullet(l)
  local rest = l:match("^%s*[-*+] %[[ xX]%]%s*(.*)$")
  if rest then return "- " .. rest end
  rest = l:match("^%s*[-*+]%s+(.*)$")
  if rest then return rest end
  return "- " .. (l:gsub("^#+%s+", ""):gsub("^>%s*", ""))
end
local function toggleTaskLine(l)
  local rest = l:match("^%s*[-*+] %[[ xX]%]%s*(.*)$")
  if rest then return rest end
  rest = l:match("^%s*[-*+]%s+(.*)$") or l:gsub("^#+%s+", "")
  return "- [ ] " .. rest
end
local function toggleQuote(l)
  local rest = l:match("^>%s?(.*)$")
  if rest then return rest end
  return "> " .. l
end

local function applyLineFormat(fn)
  if not cur then return end
  syncLines()
  local i, resume = recentLine()
  if #lines == 0 then lines[1] = "" end
  i = clamp(i, 1, #lines)
  changeLine(i, fn(lines[i]))
  if resume then startEdit(i) end
end

local function appendToLine(text, i, resume)
  if not cur then return end
  syncLines()
  if #lines == 0 then lines[1] = "" end
  i = clamp(i or lineCursor, 1, #lines)
  local l = lines[i] or ""
  local sep = (l == "" or l:match("%s$")) and "" or " "
  changeLine(i, l .. sep .. text)
  if resume then startEdit(i) end
end

local function openPicker(kind)
  if not cur then return end
  local i, resume = recentLine()
  picker = {kind = kind, q = "", sel = 1, t = 0, line = i, resume = resume}
  K.focus("pq")
end

-- ================================================================== navigation
local function openNote(n, keepEdit)
  if not n then return end
  if titleEdit and cur and titleText ~= cur.title then end
  stopEdit()
  titleEdit = false
  cur = n
  linesBody = nil
  syncLines()
  lineCursor = 1
  edScroll:to(0, true)
  panelScroll:to(0, true)
  mobilePane = "note"
  if view == "graph" and not keepEdit then end
  store.set("cur", n.id)
end

local function newNote(title, body)
  stopEdit()
  local n = addNote(title or TR("untitled"), body or "", 1)
  hist:push({{id = n.id, exists = false}})
  openNote(n)
  view = "notes"
  if not title then
    titleEdit, titleText = true, n.title
    K.focus("title")
  else
    startEdit(1)
  end
  audio.play("pop", 0.35)
  return n
end

local function followLink(target)
  local n = index.byTitle[key(target)]
  if n then openNote(n); view = "notes"; return end
  -- a link to a note that does not exist yet creates it
  local nn = addNote(target, "", 1)
  hist:push({{id = nn.id, exists = false}})
  openNote(nn)
  view = "notes"
  K.toast(TR("created", nn.title), "add")
end

local function dailyNote()
  local t = K.dayKey(now())
  local n = index.byTitle[key(t)]
  if not n then
    for _, x in ipairs(notes) do if key(x.title) == key(t) then n = x end end
  end
  if n then openNote(n) else
    n = addNote(t, "## " .. TR("daily_plan") .. "\n- [ ] \n\n## " .. TR("daily_notes") .. "\n", 1)
    hist:push({{id = n.id, exists = false}})
    openNote(n)
    K.toast(TR("created", t), "today")
  end
  view = "notes"
end

-- rename a note and every [[link]] that points to it
local function renameNote(n, newTitle)
  newTitle = uniqueTitle(newTitle, n)
  if newTitle == n.title then return end
  local old = key(n.title)
  local ids = {n.id}
  for _, x in ipairs(notes) do
    if x ~= n and x.body:find("[[", 1, true) then
      for _, t in ipairs(linksOf(x.body)) do if key(t) == old then ids[#ids + 1] = x.id; break end end
    end
  end
  hist:push(captureAll(ids))
  local changed = 0
  for i = 2, #ids do
    local x = byId[ids[i]]
    x.body = x.body:gsub("%[%[([^%]\n]-)%]%]", function(inner)
      local target, alias = inner:match("^([^|]*)|(.*)$")
      target = target or inner
      if key(target) == old then
        changed = changed + 1
        return "[[" .. newTitle .. (alias and ("|" .. alias) or "") .. "]]"
      end
      return nil
    end)
  end
  n.title = newTitle
  n.updated = now()
  linesBody = nil
  markDirty()
  if changed > 0 then K.toast(TR("renamed_links", changed), "link") end
end

local function commitTitle()
  if not titleEdit or not cur then titleEdit = false; return end
  titleEdit = false
  if K.trim(titleText) ~= "" and titleText ~= cur.title then renameNote(cur, titleText) end
  if K.editing == "title" then K.blur() end
end

local function deleteCurrent()
  if not cur then return end
  local n = cur
  ui.alert(TR("delete_title"), TR("delete_msg", n.title), {TR("delete"), TR("cancel")}, function(b)
    if b ~= 1 then return end
    stopEdit()
    hist:push({capture(n.id)})
    removeNote(n)
    if #notes == 0 then addNote(TR("untitled"), "") end
    cur = nil
    openNote(sortedNotes()[1])
    mobilePane = "list"
    audio.play("trash", 0.4)
    K.toast(TR("deleted"), "delete")
  end)
end

local function togglePin()
  if not cur then return end
  hist:push({capture(cur.id)})
  cur.pinned = not cur.pinned
  markDirty()
  K.toast(cur.pinned and TR("pinned") or TR("unpinned"), "push_pin")
end

local function doUndo()
  stopEdit()
  local top = hist.u[#hist.u]
  if not top then K.toast(TR("nothing_undo"), "undo"); return end
  local ids = {}
  for _, s in ipairs(top) do ids[#ids + 1] = s.id end
  local entry = hist:undo(captureAll(ids))
  restore(entry)
  local s = entry[1]
  if byId[s.id] then openNote(byId[s.id]) elseif not byId[cur and cur.id or -1] then openNote(sortedNotes()[1]) end
  linesBody = nil
  K.toast(TR("undone"), "undo")
end
local function doRedo()
  stopEdit()
  local top = hist.r[#hist.r]
  if not top then K.toast(TR("nothing_redo"), "redo"); return end
  local ids = {}
  for _, s in ipairs(top) do ids[#ids + 1] = s.id end
  local entry = hist:redo(captureAll(ids))
  restore(entry)
  local s = entry[1]
  if byId[s.id] then openNote(byId[s.id]) elseif not byId[cur and cur.id or -1] then openNote(sortedNotes()[1]) end
  linesBody = nil
  K.toast(TR("redone"), "redo")
end

-- ================================================================== import / export
local function importText(text, name)
  text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  local title = text:match("^#%s+([^\n]+)")
  local body = text
  if title then body = text:gsub("^#%s+[^\n]*\n?", "", 1) else title = name or TR("imported") end
  local n = addNote(title, body, 1)
  hist:push({{id = n.id, exists = false}})
  return n
end

local function importBackup(data)
  if type(data) ~= "table" or type(data.notes) ~= "table" then return 0 end
  local count = 0
  for _, r in ipairs(data.notes) do
    if type(r) == "table" and r.title then
      local n = addNote(K.str(r.title), K.str(r.body, ""))
      n.pinned = r.pinned == true
      n.created = K.int(r.created, now())
      n.updated = K.int(r.updated, now())
      count = count + 1
    end
  end
  hist:clear()
  return count
end

local function importPath(path)
  local text = fs.read(path)
  if not text then K.toast(TR("read_failed"), "error"); return end
  if path:lower():match("%.json$") then
    local data = json.decode(text)
    local c = importBackup(data)
    if c > 0 then
      K.toast(TR("imported_n", c), "file_download")
      openNote(sortedNotes()[1])
    else K.toast(TR("not_backup"), "error") end
  else
    local n = importText(text, K.baseName(path))
    openNote(n)
    view = "notes"
    K.toast(TR("imported_one", n.title), "file_download")
  end
end

local function importFile()
  stopEdit()
  ui.openFile(function(p) if p then importPath(p) end end, {".md", ".markdown", ".txt", ".json"}, TR("import"))
end

local function exportNote()
  if not cur then return end
  stopEdit()
  local n = cur
  local fname = n.title:gsub("[/\\:%*%?\"<>|]", "-") .. ".md"
  ui.saveFile(function(p)
    if not p then return end
    if not p:lower():match("%.md$") and not p:lower():match("%.txt$") then p = p .. ".md" end
    if fs.write(p, "# " .. n.title .. "\n\n" .. n.body .. "\n") then K.toast(TR("exported"), "ios_share")
    else K.toast(TR("write_failed"), "error") end
  end, fname, TR("export_md"))
end

local function exportBackup()
  stopEdit()
  ui.saveFile(function(p)
    if not p then return end
    if not p:lower():match("%.json$") then p = p .. ".json" end
    local out = {}
    for i, n in ipairs(notes) do
      out[i] = {title = n.title, body = n.body, pinned = n.pinned and true or false, created = n.created, updated = n.updated}
    end
    if fs.write(p, json.encode({app = "linkwise", version = 1, notes = out}, true)) then
      K.toast(TR("backup_done", #out), "save")
    else K.toast(TR("write_failed"), "error") end
  end, "linkwise-" .. K.dayKey(now()) .. ".json", TR("backup"))
end

-- ================================================================== Markdown rendering
local STY = {
  p = {15, "sans", 1.5}, h1 = {25, "bold", 1.3}, h2 = {20, "bold", 1.35}, h3 = {17, "semibold", 1.4},
  code = {13, "mono", 1.55}, quote = {15, "italic", 1.5},
}

local function parseInline(s, font)
  local runs, i, n = {}, 1, #s
  local buf = {}
  local function flush()
    if #buf > 0 then runs[#runs + 1] = {t = table.concat(buf), f = font, k = "text"}; buf = {} end
  end
  while i <= n do
    local nx = s:find("[%[%*_`~#h]", i)
    if not nx then buf[#buf + 1] = s:sub(i); break end
    if nx > i then buf[#buf + 1] = s:sub(i, nx - 1); i = nx end
    local c = s:sub(i, i)
    local done = false
    if c == "[" and s:sub(i + 1, i + 1) == "[" then
      local j = s:find("]]", i + 2, true)
      if j then
        local inner = s:sub(i + 2, j - 1)
        local target, label = inner:match("^([^|]*)|(.*)$")
        target = K.trim(target or inner)
        label = label and K.trim(label) or target
        if target ~= "" then
          flush()
          runs[#runs + 1] = {t = label ~= "" and label or target, f = font == "sans" and "medium" or font, k = "link", v = target}
          i, done = j + 2, true
        end
      end
    elseif c == "*" and s:sub(i + 1, i + 1) == "*" then
      local j = s:find("**", i + 2, true)
      if j and j > i + 2 then
        flush(); runs[#runs + 1] = {t = s:sub(i + 2, j - 1), f = "bold", k = "text"}; i, done = j + 2, true
      end
    elseif (c == "*" or c == "_") and (c == "*" or i == 1 or s:sub(i - 1, i - 1):match("[%s%(]")) then
      local j = s:find(c, i + 1, true)
      if j and j > i + 1 and not s:sub(i + 1, i + 1):match("%s") then
        flush(); runs[#runs + 1] = {t = s:sub(i + 1, j - 1), f = "italic", k = "text"}; i, done = j + 1, true
      end
    elseif c == "`" then
      local j = s:find("`", i + 1, true)
      if j and j > i + 1 then
        flush(); runs[#runs + 1] = {t = s:sub(i + 1, j - 1), f = "mono", k = "code"}; i, done = j + 1, true
      end
    elseif c == "~" and s:sub(i + 1, i + 1) == "~" then
      local j = s:find("~~", i + 2, true)
      if j and j > i + 2 then
        flush(); runs[#runs + 1] = {t = s:sub(i + 2, j - 1), f = font, k = "strike"}; i, done = j + 2, true
      end
    elseif c == "#" and (i == 1 or s:sub(i - 1, i - 1):match("[%s%(]")) then
      local tag = s:match("^#([%w_%-/\128-\255]+)", i)
      if tag and not tag:match("^%d+$") then
        flush(); runs[#runs + 1] = {t = "#" .. tag, f = "medium", k = "tag", v = tag}; i, done = i + 1 + #tag, true
      end
    elseif c == "h" then
      local url = s:match("^https?://[^%s%)%]]+", i)
      if url then flush(); runs[#runs + 1] = {t = url, f = font, k = "url", v = url}; i, done = i + #url, true end
    end
    if not done then buf[#buf + 1] = c; i = i + 1 end
  end
  flush()
  return runs
end

-- word-wraps runs into positioned pieces; returns items, height
local function layoutRuns(runs, maxW, size, lh)
  local items, x, line = {}, 0, 0
  local function put(r, txt, wd)
    local last = items[#items]
    if last and last.r == r and last.line == line then last.s = last.s .. txt; last.w = last.w + wd
    else items[#items + 1] = {r = r, s = txt, x = x, line = line, w = wd} end
    x = x + wd
  end
  for _, r in ipairs(runs) do
    local fsz = r.k == "code" and size - 1 or size
    r.size = fsz
    for word, sp in r.t:gmatch("([^ ]*)( *)") do
      if word ~= "" or sp ~= "" then
        local ww = gfx.textWidth(word, fsz, r.f)
        if x > 0 and x + ww > maxW then line = line + 1; x = 0 end
        if ww > maxW then
          local piece = ""
          local ok = utf8.len(word)
          local iter = ok and utf8.codes(word) or nil
          local chars = {}
          if iter then for _, cp in utf8.codes(word) do chars[#chars + 1] = utf8.char(cp) end
          else for ch in word:gmatch(".") do chars[#chars + 1] = ch end end
          for _, ch in ipairs(chars) do
            local t = piece .. ch
            if piece ~= "" and x + gfx.textWidth(t, fsz, r.f) > maxW then
              put(r, piece, gfx.textWidth(piece, fsz, r.f))
              line = line + 1; x = 0
              piece = ch
            else piece = t end
          end
          if piece ~= "" then put(r, piece, gfx.textWidth(piece, fsz, r.f)) end
        elseif word ~= "" then
          put(r, word, ww)
        end
        if sp ~= "" and x > 0 then put(r, sp, gfx.textWidth(sp, fsz, r.f)) end
      end
    end
  end
  local lineH = floor(size * lh)
  for _, it in ipairs(items) do it.y = it.line * lineH end
  return items, (line + 1) * lineH, lineH
end

local function classify(line, inCode)
  if line:match("^%s*```") then return {k = "fence"} end
  if inCode then return {k = "code", t = line} end
  local hs, ht = line:match("^(#+)%s+(.*)$")
  if hs then return {k = "h" .. min(3, #hs), t = ht} end
  if line:match("^%s*%-%-%-+%s*$") or line:match("^%s*%*%*%*+%s*$") then return {k = "hr"} end
  local ind, box, rest = line:match("^(%s*)[-*+] %[([ xX])%]%s?(.*)$")
  if ind then return {k = "task", ind = #ind // 2, done = box ~= " ", t = rest} end
  local ind2, rest2 = line:match("^(%s*)[-*+]%s+(.*)$")
  if ind2 then return {k = "bullet", ind = #ind2 // 2, t = rest2} end
  local ind3, num, rest3 = line:match("^(%s*)(%d+)[.)]%s+(.*)$")
  if ind3 then return {k = "num", ind = #ind3 // 2, n = num, t = rest3} end
  local q = line:match("^>%s?(.*)$")
  if q then return {k = "quote", t = q} end
  if K.trim(line) == "" then return {k = "blank"} end
  return {k = "p", t = line}
end

local lcache, lcacheN = {}, 0
local function lineLayout(line, inCode, width)
  local ck = (inCode and "c" or "n") .. width .. "\0" .. line
  local L = lcache[ck]
  if L then return L end
  local b = classify(line, inCode)
  L = {b = b, items = {}, h = 0, ind = 0, top = 0}
  if b.k == "blank" then L.h = 12
  elseif b.k == "hr" then L.h = 22
  elseif b.k == "fence" then L.h = 12
  elseif b.k == "code" then
    local st = STY.code
    L.items, L.h = layoutRuns({{t = b.t ~= "" and b.t or " ", f = "mono", k = "plain"}}, width - 24, st[1], st[3])
    L.ind = 12
  else
    local st = STY[b.k] or (b.k == "quote" and STY.quote) or STY.p
    local ind = 0
    if b.k == "bullet" or b.k == "task" or b.k == "num" then ind = 26 + (b.ind or 0) * 22 end
    if b.k == "quote" then ind = 16 end
    L.ind = ind
    local runs = parseInline(b.t or "", st[2])
    if #runs == 0 then runs = {{t = " ", f = st[2], k = "text"}} end
    L.items, L.h = layoutRuns(runs, max(40, width - ind), st[1], st[3])
    if b.k == "h1" then L.top = 12 elseif b.k == "h2" then L.top = 10 elseif b.k == "h3" then L.top = 6 end
    L.h = L.h + L.top + 2
    L.size = st[1]
  end
  lcacheN = lcacheN + 1
  if lcacheN > 2500 then lcache, lcacheN = {}, 0 end
  lcache[ck] = L
  return L
end

local function runColor(r, b)
  if r.k == "link" then return index.byTitle[key(r.v)] and theme.accent or alpha(theme.accent, 0.6) end
  if r.k == "tag" then return K.colorFor(K.lower(r.v)) end
  if r.k == "url" then return theme.blue end
  if b.k == "quote" then return theme.text2 end
  if b.k == "task" and b.done then return theme.text3 end
  return theme.text
end

-- draws one laid-out line; returns the clicked link/tag/url run, if any
local function drawLine(L, x, y, w, idx, interactive)
  local b = L.b
  local action = nil
  if b.k == "hr" then
    gfx.color(theme.separator); gfx.line(x, y + 11, x + w, y + 11, 1.5)
    return nil
  elseif b.k == "fence" then
    gfx.rect(x, y + 3, w, 6, 3, alpha(theme.text, 0.05))
    return nil
  elseif b.k == "code" then
    gfx.rect(x, y, w, L.h, 0, alpha(theme.text, 0.05))
    gfx.color(theme.text)
    for _, it in ipairs(L.items) do gfx.text(it.s, x + 12 + it.x, y + it.y + 2, 13, "mono") end
    return nil
  elseif b.k == "blank" then return nil end
  local ty = y + L.top
  if b.k == "bullet" then
    local bx = x + 10 + (b.ind or 0) * 22
    gfx.color(theme.text2)
    if (b.ind or 0) % 2 == 0 then gfx.circle(bx, ty + 11, 3) else gfx.circleLine(bx, ty + 11, 3, 1.2) end
  elseif b.k == "num" then
    gfx.color(theme.text2)
    gfx.text(b.n .. ".", x + (b.ind or 0) * 22, ty + 1, 15, "medium", "right", 20)
  elseif b.k == "task" then
    local bx = x + (b.ind or 0) * 22
    local hit = interactive and ui.hit("tk" .. idx, bx - 4, ty - 2, 26, 26) or nil
    if b.done then
      gfx.rect(bx + 1, ty + 2, 18, 18, 5, theme.green)
      gfx.icon("check", bx + 10, ty + 11, 15, "#FFFFFF")
    else
      gfx.rect(bx + 1, ty + 2, 18, 18, 5, hit and hit.hovered and theme.hover or theme.field)
      gfx.color(theme.text3); gfx.rectLine(bx + 1, ty + 2, 18, 18, 5, 1.5)
    end
    if hit and hit.clicked and not edScroll:dragged() then action = {k = "task"} end
  elseif b.k == "quote" then
    gfx.rect(x + 2, y + 2, 3, L.h - 4, 1.5, alpha(theme.accent, 0.6))
  end
  local ox = x + L.ind
  for j, it in ipairs(L.items) do
    local r = it.r
    local ix, iy = ox + it.x, ty + it.y
    local sz = r.size or L.size or 15
    if r.k == "code" then gfx.rect(ix - 2, iy + 1, it.w + 4, sz * 1.35, 4, alpha(theme.text, 0.08)) end
    if r.k == "tag" then gfx.rect(ix - 3, iy + 1, it.w + 6, sz * 1.35, 6, alpha(K.colorFor(K.lower(r.v)), 0.14)) end
    local c = runColor(r, b)
    gfx.color(c)
    gfx.text(it.s, ix, iy + (r.k == "code" and 2 or 0), sz, r.f)
    if r.k == "strike" or (b.k == "task" and b.done) then gfx.line(ix, iy + sz * 0.72, ix + it.w, iy + sz * 0.72, 1) end
    if r.k == "link" or r.k == "url" then
      gfx.color(alpha(c, 0.5)); gfx.line(ix, iy + sz * 1.3, ix + it.w, iy + sz * 1.3, 1)
    end
    if interactive and (r.k == "link" or r.k == "tag" or r.k == "url") then
      local hit = ui.hit("lk" .. idx .. "_" .. j, ix - 2, iy, it.w + 4, sz * 1.4)
      if hit.hovered then gfx.rect(ix - 2, iy, it.w + 4, sz * 1.4, 4, alpha(c, 0.1)) end
      if hit.clicked and not edScroll:dragged() then action = {k = r.k, v = r.v} end
    end
  end
  return action
end

-- ================================================================== graph
local G = {nodes = {}, byKey = {}, edges = {}, cx = 0, cy = 0, zoom = 1, heat = 1, sel = nil, localMode = false,
           built = -2, drag = nil, area = {0, 0, 0, 0}, fitted = false, tag = 0}
local function buildGraph()
  local old = G.byKey
  G.nodes, G.byKey, G.edges = {}, {}, {}
  local allow = nil
  if G.localMode and cur then
    allow = {[cur.id] = true}
    local frontier = {cur.id}
    for _ = 1, 2 do
      local nextF = {}
      for _, id in ipairs(frontier) do
        for _, o in ipairs(index.out[id] or {}) do if not allow[o] then allow[o] = true; nextF[#nextF + 1] = o end end
        for _, o in ipairs(index.back[id] or {}) do if not allow[o] then allow[o] = true; nextF[#nextF + 1] = o end end
      end
      frontier = nextF
    end
  end
  local tagKey = G.tag > 0 and index.tagList[G.tag] and index.tagList[G.tag].key or nil
  local function tagOk(n)
    if not tagKey then return true end
    for _, t in ipairs(index.tagsOf[n.id] or {}) do if K.lower(t) == tagKey then return true end end
    return false
  end
  local function node(k, title, note, ghost)
    local o = old[k]
    local nd = {key = k, title = title, note = note, ghost = ghost, deg = 0,
                x = o and o.x or (math.random() - 0.5) * 400, y = o and o.y or (math.random() - 0.5) * 300,
                vx = 0, vy = 0}
    G.nodes[#G.nodes + 1] = nd
    G.byKey[k] = nd
    return nd
  end
  for _, n in ipairs(notes) do
    if (not allow or allow[n.id]) and tagOk(n) then
      local nd = node("n" .. n.id, n.title, n, false)
      local tg = (index.tagsOf[n.id] or {})[1]
      nd.color = tg and K.colorFor(K.lower(tg)) or nil
    end
  end
  for _, n in ipairs(notes) do
    local a = G.byKey["n" .. n.id]
    if a then
      for _, o in ipairs(index.out[n.id] or {}) do
        local b = G.byKey["n" .. o]
        if b then G.edges[#G.edges + 1] = {a = a, b = b}; a.deg = a.deg + 1; b.deg = b.deg + 1 end
      end
    end
  end
  if not tagKey then
    for k, g in pairs(index.ghosts) do
      local any = false
      for _, id in ipairs(g.from) do if G.byKey["n" .. id] then any = true end end
      if any then
        local gn = node("g" .. k, g.title, nil, true)
        for _, id in ipairs(g.from) do
          local a = G.byKey["n" .. id]
          if a then G.edges[#G.edges + 1] = {a = a, b = gn, ghost = true}; a.deg = a.deg + 1; gn.deg = gn.deg + 1 end
        end
      end
    end
  end
  G.heat = 1
  G.built = indexAt
  if G.sel and not G.byKey[G.sel] then G.sel = nil end
end

local function simulate()
  local ns, n = G.nodes, #G.nodes
  if n == 0 or G.heat < 0.004 then return end
  for i = 1, n do local a = ns[i]; a.fx, a.fy = -a.x * 0.01, -a.y * 0.01 end
  for i = 1, n - 1 do
    local a = ns[i]
    local ax, ay = a.x, a.y
    for j = i + 1, n do
      local b = ns[j]
      local dx, dy = ax - b.x, ay - b.y
      local d2 = dx * dx + dy * dy
      if d2 < 160000 then
        if d2 < 1 then dx, dy, d2 = math.random() - 0.5, math.random() - 0.5, 1 end
        local d = sqrt(d2)
        local f = 2600 / d2
        local fx, fy = dx / d * f, dy / d * f
        a.fx, a.fy = a.fx + fx, a.fy + fy
        b.fx, b.fy = b.fx - fx, b.fy - fy
      end
    end
  end
  for _, e in ipairs(G.edges) do
    local a, b = e.a, e.b
    local dx, dy = b.x - a.x, b.y - a.y
    local d = sqrt(dx * dx + dy * dy) + 0.01
    local f = (d - 110) * 0.03
    local fx, fy = dx / d * f, dy / d * f
    a.fx, a.fy = a.fx + fx, a.fy + fy
    b.fx, b.fy = b.fx - fx, b.fy - fy
  end
  local heat = G.heat
  for i = 1, n do
    local a = ns[i]
    if G.drag ~= a then
      a.vx = (a.vx + a.fx * heat) * 0.55
      a.vy = (a.vy + a.fy * heat) * 0.55
      local sp = sqrt(a.vx * a.vx + a.vy * a.vy)
      if sp > 30 then a.vx, a.vy = a.vx / sp * 30, a.vy / sp * 30 end
      a.x, a.y = a.x + a.vx, a.y + a.vy
    end
  end
  G.heat = G.heat * 0.985
end

local function graphFit(instant)
  local ns = G.nodes
  if #ns == 0 then G.cx, G.cy, G.zoom = 0, 0, 1; return end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, a in ipairs(ns) do
    x0, y0, x1, y1 = min(x0, a.x), min(y0, a.y), max(x1, a.x), max(y1, a.y)
  end
  local aw, ah = max(100, G.area[3] - 80), max(100, G.area[4] - 120)
  G.cx, G.cy = (x0 + x1) / 2, (y0 + y1) / 2
  G.zoom = clamp(min(aw / max(1, x1 - x0), ah / max(1, y1 - y0)), 0.25, 2.2)
  G.fitted = true
end

local function toScreen(a)
  local ar = G.area
  return ar[1] + ar[3] / 2 + (a.x - G.cx) * G.zoom, ar[2] + ar[4] / 2 + (a.y - G.cy) * G.zoom
end
local function nodeRadius(a) return (a.ghost and 5 or 7 + min(10, a.deg * 1.4)) end
local function nodeAt(px, py)
  local best, bd = nil, math.huge
  for _, a in ipairs(G.nodes) do
    local sx, sy = toScreen(a)
    local r = nodeRadius(a) * max(0.7, G.zoom) + 10
    local d = (sx - px) ^ 2 + (sy - py) ^ 2
    if d < r * r and d < bd then best, bd = a, d end
  end
  return best
end
local function zoomAt(f, px, py)
  local ar = G.area
  local wx = G.cx + (px - ar[1] - ar[3] / 2) / G.zoom
  local wy = G.cy + (py - ar[2] - ar[4] / 2) / G.zoom
  G.zoom = clamp(G.zoom * f, 0.2, 4)
  G.cx = wx - (px - ar[1] - ar[3] / 2) / G.zoom
  G.cy = wy - (py - ar[2] - ar[4] / 2) / G.zoom
end
-- controller/keyboard: pick the nearest node in a direction
local function graphStep(dx, dy)
  local from = G.sel and G.byKey[G.sel]
  if not from then
    if cur and G.byKey["n" .. cur.id] then G.sel = "n" .. cur.id elseif G.nodes[1] then G.sel = G.nodes[1].key end
    return
  end
  local best, bs = nil, math.huge
  for _, a in ipairs(G.nodes) do
    if a ~= from then
      local vx, vy = a.x - from.x, a.y - from.y
      local along = vx * dx + vy * dy
      if along > 1 then
        local side = abs(vx * dy - vy * dx)
        local s = along + side * 2
        if s < bs then best, bs = a, s end
      end
    end
  end
  if best then
    G.sel = best.key
    local sx, sy = toScreen(best)
    local ar = G.area
    if sx < ar[1] + 60 or sx > ar[1] + ar[3] - 60 or sy < ar[2] + 60 or sy > ar[2] + ar[4] - 60 then
      G.cx, G.cy = best.x, best.y
    end
    audio.play("click", 0.2)
  end
end
local function graphOpen(a)
  if not a then return end
  if a.ghost then followLink(a.title) else openNote(a.note) end
  view = "notes"
end

-- ================================================================== drawing: sidebar
local function relTime(e)
  local today = K.dayKey(now())
  local d = K.dayKey(e)
  if d == today then
    local t = sys.date(e)
    return string.format("%02d:%02d", t.hour, t.min)
  elseif d == K.dayKey(now() - 86400) then return TR("yesterday") end
  return d
end

local function drawSidebar(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  local p = 12
  -- header
  gfx.color(theme.text)
  gfx.text(TR("app_name"), x + p, y + 14, 18, "bold")
  if ui.iconButton("edit_note", x + w - p - 34, y + 9, 34, 34, theme.accent, false, "##new") then newNote() end
  if ui.iconButton("hub", x + w - p - 72, y + 9, 34, 34, view == "graph" and theme.accent or theme.text2, view == "graph", "##graph") then
    stopEdit(); view = view == "graph" and "notes" or "graph"; mobilePane = "note"
  end
  if ui.iconButton("today", x + w - p - 110, y + 9, 34, 34, theme.text2, false, "##today") then dailyNote() end
  local q, sub = K.field("search", query, x + p, y + 50, w - p * 2, 32, TR("search_ph"), "search")
  if q ~= query then query = q; listSel = 1; listScroll:to(0, true) end
  if sub and listItems()[1] then openNote(listItems()[1].note); view = "notes" end
  local yy = y + 92
  -- tags
  if #index.tagList > 0 then
    local cx = x + p
    local rows = 1
    local ok, tw = K.chip("tag_all", TR("all"), cx, yy, 26, tagFilter == nil)
    if ok then tagFilter = nil; listSel = 1 end
    cx = cx + tw + 6
    for i, t in ipairs(index.tagList) do
      local label = "#" .. t.name
      local cw = K.chipWidth(label)
      if cx + cw > x + w - p then
        rows = rows + 1
        if rows > 2 then break end
        cx = x + p
        yy = yy + 32
      end
      local c, ww = K.chip("tag_" .. i, label, cx, yy, 26, tagFilter == t.key, K.colorFor(t.key))
      if c then tagFilter = (tagFilter == t.key) and nil or t.key; listSel = 1; listScroll:to(0, true) end
      cx = cx + ww + 6
    end
    yy = yy + 36
  end
  gfx.color(theme.separator); gfx.line(x, yy, x + w, yy, 1)
  -- list
  local items = listItems()
  local lh = 58
  local ly, lhh = yy + 1, y + h - yy - 1
  listRect = {x, ly, w, lhh}
  listScroll:setMax(#items * lh + 8 - lhh)
  gfx.clip(x, ly, w, lhh)
  local searching = K.trim(query) ~= ""
  if #items == 0 then
    K.empty(searching and "search_off" or "note_add", searching and TR("no_results") or TR("no_notes"),
            searching and TR("no_results_hint") or TR("no_notes_hint"), x, ly, w, lhh)
  end
  local first = max(1, floor(listScroll.y / lh) + 1)
  for i = first, min(#items, first + floor(lhh / lh) + 1) do
    local it = items[i]
    local n = it.note
    local ry = ly + 4 + (i - 1) * lh - listScroll.y
    local selected = cur == n
    local hit = ui.hit("row" .. n.id, x + 6, ry, w - 12, lh - 4)
    if selected then gfx.rect(x + 6, ry, w - 12, lh - 4, 10, alpha(theme.accent, theme.dark and 0.32 or 0.16))
    elseif hit.hovered or (i == listSel and not K.editing and mobilePane == "list") then
      gfx.rect(x + 6, ry, w - 12, lh - 4, 10, theme.hover)
    end
    local tx = x + 16
    if n.pinned then gfx.icon("push_pin", tx + 6, ry + 15, 14, theme.orange); tx = tx + 16 end
    gfx.color(theme.text)
    local stamp = relTime(n.updated)
    local sw = gfx.textWidth(stamp, 11, "sans")
    gfx.text(K.ellipsize(n.title, 14, "semibold", x + w - 22 - sw - 8 - tx), tx, ry + 7, 14, "semibold")
    gfx.color(theme.text3)
    gfx.text(stamp, x + w - 18 - sw, ry + 9, 11, "sans")
    gfx.color(theme.text2)
    local snip = it.snip ~= "" and it.snip or TR("empty_note")
    gfx.text(K.ellipsize(snip, 12, "sans", w - 34), x + 16, ry + 29, 12, "sans")
    if hit.clicked and not listScroll:dragged() then openNote(n); view = "notes"; listSel = i end
    if hit.rightClicked then
      openNote(n)
      ui.contextMenu({{label = n.pinned and TR("unpin") or TR("pin"), id = 1, icon = "push_pin"},
                      {label = TR("export_md"), id = 2, icon = "ios_share"}, "-",
                      {label = TR("delete"), id = 3, icon = "delete"}}, function(id)
        if id == 1 then togglePin() elseif id == 2 then exportNote() elseif id == 3 then deleteCurrent() end
      end)
    end
  end
  gfx.unclip()
  listScroll:bar(x + w - 6, ly + 4, lhh - 8)
  -- footer: count
  gfx.color(theme.separator); gfx.line(x + w - 1, y, x + w - 1, y + h, 1)
end

-- ================================================================== drawing: editor
local function formatBar(x, y, w)
  local tools = {
    {"title", TR("f_heading"), function() applyLineFormat(cycleHeading) end},
    {"format_list_bulleted", TR("f_bullet"), function() applyLineFormat(toggleBullet) end},
    {"check_box", TR("f_task"), function() applyLineFormat(toggleTaskLine) end},
    {"format_quote", TR("f_quote"), function() applyLineFormat(toggleQuote) end},
    {"link", TR("f_link"), function() openPicker("link") end},
    {"sell", TR("f_tag"), function() openPicker("tag") end},
  }
  local bx = x
  for i, t in ipairs(tools) do
    if ui.iconButton(t[1], bx, y, 34, 32, theme.text2, false, "##fmt" .. i) then t[3]() end
    bx = bx + 36
  end
  return bx - x
end

local function drawEditor(x, y, w, h, narrow)
  if not cur then K.empty("description", TR("no_note"), nil, x, y, w, h); return end
  syncLines()
  -- toolbar
  local tb = 48
  local bx = x + 10
  if narrow then
    if ui.iconButton("arrow_back", bx, y + 8, 34, 32, theme.text2, false, "##back") then stopEdit(); mobilePane = "list" end
    bx = bx + 38
  else
    if ui.iconButton(showSide and "menu_open" or "menu", bx, y + 8, 34, 32, theme.text2, false, "##side") then
      showSide = not showSide; saveNow()
    end
    bx = bx + 38
  end
  local right = x + w - 10
  local function rbtn(icon, id, tint, active, enabled)
    right = right - 36
    if enabled == false then
      gfx.icon(icon, right + 17, y + 24, 20, theme.text3)
      return false
    end
    return ui.iconButton(icon, right, y + 8, 34, 32, tint or theme.text2, active, id)
  end
  if rbtn("more_horiz", "##more") then
    ui.contextMenu({{label = TR("rename"), id = 1, icon = "edit"},
                    {label = cur.pinned and TR("unpin") or TR("pin"), id = 2, icon = "push_pin"}, "-",
                    {label = TR("export_md"), id = 3, icon = "ios_share"}, {label = TR("backup"), id = 4, icon = "save"},
                    {label = TR("import"), id = 5, icon = "file_download"}, "-",
                    {label = TR("delete"), id = 6, icon = "delete"}}, function(id)
      if id == 1 then titleEdit, titleText = true, cur.title; K.focus("title")
      elseif id == 2 then togglePin() elseif id == 3 then exportNote() elseif id == 4 then exportBackup()
      elseif id == 5 then importFile() elseif id == 6 then deleteCurrent() end
    end)
  end
  if not narrow and w > 560 then
    if rbtn("view_sidebar", "##right", showRight and theme.accent or theme.text2, showRight) then showRight = not showRight; saveNow() end
  end
  if rbtn("redo", "##redo", nil, false, hist:canRedo()) then doRedo() end
  if rbtn("undo", "##undo", nil, false, hist:canUndo()) then doUndo() end
  if rbtn("push_pin", "##pin", cur.pinned and theme.orange or theme.text2, cur.pinned) then togglePin() end
  -- format tools (wide) when a line is being edited or the window is roomy
  if right - bx > 230 then formatBar(bx, y + 8, right - bx) end
  gfx.color(theme.separator); gfx.line(x, y + tb, x + w, y + tb, 1)

  -- content
  local cy0 = y + tb + 1
  local ch = h - tb - 1
  edRect = {x, cy0, w, ch}
  local cw = min(w - 48, 760)
  local cx = x + floor((w - cw) / 2)
  -- heights
  local total = 70
  local inCode = false
  local tops = {}
  local layouts = {}
  for i, ln in ipairs(lines) do
    tops[i] = total
    if i == editLine then
      total = total + 42
      layouts[i] = false
    else
      local L = lineLayout(ln, inCode, cw)
      layouts[i] = L
      total = total + L.h
    end
    if ln:match("^%s*```") then inCode = not inCode end
  end
  lineTops = tops
  total = total + 140
  edScroll:setMax(total - ch)
  gfx.clip(x, cy0, w, ch)
  local oy = cy0 - edScroll.y
  -- title
  if titleEdit then
    local nt, sub = K.field("title", titleText, cx - 8, oy + 16, cw + 16, 38, TR("title_ph"))
    titleText = nt
    if sub then commitTitle(); startEdit(1) end
  else
    local th = ui.hit("titlehit", cx - 8, oy + 12, cw + 16, 44)
    if th.hovered then gfx.rect(cx - 8, oy + 12, cw + 16, 44, 8, theme.hover) end
    gfx.color(theme.text)
    gfx.text(K.ellipsize(cur.title, 26, "bold", cw), cx, oy + 18, 26, "bold")
    if th.clicked and not edScroll:dragged() then stopEdit(); titleEdit, titleText = true, cur.title; K.focus("title") end
  end
  -- meta row
  gfx.color(theme.text3)
  if cache.wordsBody ~= cur.body then
    local n = 0
    for _ in cur.body:gmatch("[^%s]+") do n = n + 1 end
    cache.wordsBody, cache.words = cur.body, n
  end
  gfx.text(TR("meta", relTime(cur.updated), cache.words, #(index.back[cur.id] or {})), cx, oy + 58, 12, "sans")
  -- lines
  local vis0, vis1 = edScroll.y - 60, edScroll.y + ch + 60
  local todo = nil   -- actions run after the loop, so the lines do not change while they are drawn
  for i = 1, #tops do
    local top = tops[i]
    local L = layouts[i]
    local hgt = L and L.h or 42
    if top + hgt >= vis0 and top <= vis1 then
      local ly = oy + top
      if not L then
        local nt, sub = K.field("ln", editText, cx - 8, ly + 4, cw + 16, 34, TR("line_ph"))
        if nt ~= editText and editLine == i then setEditText(nt) end
        if sub and editLine == i then todo = enterPressed end
      else
        local hit = ui.hit("ln" .. i, cx - 10, ly, cw + 20, hgt)
        if (hit.hovered and not hit.held) or (i == lineCursor and not editLine and not K.editing) then
          gfx.rect(cx - 10, ly, cw + 20, hgt, 6, alpha(theme.text, (i == lineCursor and not editLine) and 0.05 or 0.03))
        end
        local act = drawLine(L, cx, ly, cw, i, true)
        if act and not todo then
          if act.k == "task" then todo = function() toggleTask(i) end
          elseif act.k == "link" then todo = function() followLink(act.v) end
          elseif act.k == "tag" then todo = function() tagFilter = K.lower(act.v); showSide = true; mobilePane = "list"; listSel = 1 end
          elseif act.k == "url" then todo = function() sys.open(act.v) end end
        elseif hit.clicked and not edScroll:dragged() and not todo then
          todo = function() startEdit(i) end
        end
      end
    end
  end
  -- tap below the last line: continue writing
  local endY = oy + total - 140
  local eh = ui.hit("endhit", cx - 10, endY, cw + 20, 120)
  if eh.hovered and not editLine then
    gfx.color(theme.text3)
    gfx.text(TR("tap_to_write"), cx, endY + 10, 13, "italic")
  end
  if todo then
    todo()
  elseif eh.clicked and not edScroll:dragged() then
    syncLines()
    if #lines == 0 or lines[#lines] ~= "" then
      hist:push({capture(cur.id)})
      lines[#lines + 1] = ""
      commitLines()
    end
    startEdit(#lines)
  end
  gfx.unclip()
  edScroll:bar(x + w - 7, cy0 + 4, ch - 8)
  -- a narrow window shows the format tools at the bottom while editing
  local _, editingNow = recentLine()
  if editingNow and right - bx <= 230 then
    local fw = 6 * 36 + 8
    local fx, fy = x + floor((w - fw) / 2), y + h - 52
    gfx.shadow(fx, fy, fw, 42, 12, 10, 3)
    gfx.rect(fx, fy, fw, 42, 12, theme.window)
    formatBar(fx + 4, fy + 5, fw)
  end
end

-- ================================================================== drawing: side panel
local function drawPanel(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  gfx.color(theme.separator); gfx.line(x, y, x, y + h, 1)
  rightTab = ui.segmented("rtab", {TR("backlinks"), TR("outline"), TR("info")}, rightTab, x + 10, y + 10, w - 20, 30)
  local cy = y + 50
  local chh = h - 50
  panelRect = {x, cy, w, chh}
  if not cur then return end
  gfx.clip(x, cy, w, chh)
  local oy = cy - panelScroll.y
  local total = 0
  if rightTab == 1 then
    local pd = cache.panelKey == (cur.id .. ":" .. indexAt .. ":" .. cur.title) and cache.panel or nil
    if not pd then
      pd = {back = {}, mentions = {}}
      local ck = key(cur.title)
      local linkedFrom = {}
      for _, id in ipairs(index.back[cur.id] or {}) do
        local n = byId[id]
        if n then
          linkedFrom[id] = true
          local ctx = ""
          for ln in (n.body .. "\n"):gmatch("(.-)\n") do
            if ln:find("[[", 1, true) then
              for _, t in ipairs(linksOf(ln)) do if key(t) == ck then ctx = K.trim(ln); break end end
            end
            if ctx ~= "" then break end
          end
          ctx = ctx:gsub("%[%[([^%]|]*)|?([^%]]*)%]%]", function(a, b) return b ~= "" and b or a end)
          pd.back[#pd.back + 1] = {note = n, ctx = ctx}
        end
      end
      -- unlinked mentions: the title written without brackets
      if #cur.title >= 3 then
        for _, n in ipairs(notes) do
          if n ~= cur and not linkedFrom[n.id] and n.body:find(cur.title, 1, true) then pd.mentions[#pd.mentions + 1] = n end
          if #pd.mentions >= 8 then break end
        end
      end
      cache.panelKey, cache.panel = cur.id .. ":" .. indexAt .. ":" .. cur.title, pd
    end
    if #pd.back == 0 then
      gfx.color(theme.text3)
      gfx.wrap(TR("no_backlinks", cur.title), x + 14, oy + 10, w - 28, 13)
      total = 80
    end
    local yy = oy + 4
    for i, bl in ipairs(pd.back) do
      local n, ctx = bl.note, bl.ctx
      if n then
        local hh = 30 + min(54, gfx.measureWrap(ctx, w - 40, 12))
        local hit = ui.hit("bl" .. i, x + 8, yy, w - 16, hh)
        gfx.rect(x + 8, yy, w - 16, hh, 10, hit.hovered and theme.hover or alpha(theme.text, 0.04))
        gfx.icon("north_west", x + 24, yy + 15, 14, theme.accent)
        gfx.color(theme.text)
        gfx.text(K.ellipsize(n.title, 13, "semibold", w - 60), x + 36, yy + 7, 13, "semibold")
        gfx.color(theme.text2)
        gfx.clip(x + 8, yy, w - 16, hh - 4)
        gfx.wrap(ctx, x + 20, yy + 27, w - 40, 12)
        gfx.unclip()
        if hit.clicked and not panelScroll:dragged() then openNote(n) end
        yy = yy + hh + 6
      end
    end
    total = max(total, yy - oy)
    local mentions = pd.mentions
    if #mentions > 0 then
      yy = yy + 8
      K.heading(TR("mentions"), x + 14, yy, w - 28)
      yy = yy + 22
      for i, n in ipairs(mentions) do
        if i > 8 then break end
        local hit = ui.hit("mn" .. i, x + 8, yy, w - 92, 34)
        if hit.hovered then gfx.rect(x + 8, yy, w - 92, 34, 8, theme.hover) end
        gfx.color(theme.text)
        gfx.text(K.ellipsize(n.title, 13, "medium", w - 110), x + 16, yy + 9, 13, "medium")
        if hit.clicked then openNote(n) end
        if ui.button(TR("link_it"), x + w - 80, yy + 3, 70, 28, "default") then
          hist:push({capture(n.id)})
          local t = cur.title
          local s, e = n.body:find(t, 1, true)
          if s then
            n.body = n.body:sub(1, s - 1) .. "[[" .. t .. "]]" .. n.body:sub(e + 1)
            n.updated = now()
            markDirty()
            K.toast(TR("linked"), "link")
          end
        end
        yy = yy + 38
      end
      total = yy - oy
    end
  elseif rightTab == 2 then
    local yy = oy + 4
    local any = false
    for i, ln in ipairs(lines) do
      local hs, ht = ln:match("^(#+)%s+(.*)$")
      if hs then
        any = true
        local lvl = min(3, #hs)
        local hit = ui.hit("ol" .. i, x + 8, yy, w - 16, 30)
        if hit.hovered then gfx.rect(x + 8, yy, w - 16, 30, 8, theme.hover) end
        gfx.color(lvl == 1 and theme.text or theme.text2)
        local plain = ht:gsub("[*`]", ""):gsub("%[%[([^%]|]*)|?([^%]]*)%]%]", function(a, b) return b ~= "" and b or a end)
        gfx.text(K.ellipsize(plain, 13, lvl == 1 and "semibold" or "sans", w - 40 - (lvl - 1) * 14), x + 18 + (lvl - 1) * 14, yy + 7, 13,
                 lvl == 1 and "semibold" or "sans")
        if hit.clicked and not panelScroll:dragged() then
          stopEdit()
          lineCursor = i
          edScroll:to((lineTops[i] or 0) - 10)
        end
        yy = yy + 32
      end
    end
    if not any then
      gfx.color(theme.text3)
      gfx.wrap(TR("no_headings"), x + 14, yy + 6, w - 28, 13)
      yy = yy + 60
    end
    total = yy - oy
  else
    local yy = oy + 6
    local words, chars, tasks, done = 0, 0, 0, 0
    for _ in cur.body:gmatch("[^%s]+") do words = words + 1 end
    chars = K.ulen(cur.body)
    for _, ln in ipairs(lines) do
      local box = ln:match("^%s*[-*+] %[([ xX])%]")
      if box then tasks = tasks + 1; if box ~= " " then done = done + 1 end end
    end
    local rows = {
      {TR("i_words"), tostring(words)}, {TR("i_chars"), tostring(chars)}, {TR("i_lines"), tostring(#lines)},
      {TR("i_links"), tostring(#(index.out[cur.id] or {}))}, {TR("i_backlinks"), tostring(#(index.back[cur.id] or {}))},
      {TR("i_created"), K.dayKey(cur.created)}, {TR("i_updated"), K.dayKey(cur.updated) .. " " .. relTime(cur.updated)},
    }
    for _, r in ipairs(rows) do
      gfx.color(theme.text2); gfx.text(r[1], x + 16, yy, 13)
      gfx.color(theme.text); gfx.text(r[2], x + 16, yy, 13, "medium", "right", w - 32)
      yy = yy + 26
    end
    if tasks > 0 then
      yy = yy + 6
      gfx.color(theme.text2); gfx.text(TR("i_tasks", done, tasks), x + 16, yy, 13)
      yy = yy + 22
      gfx.rect(x + 16, yy, w - 32, 8, 4, alpha(theme.text, 0.1))
      gfx.rect(x + 16, yy, (w - 32) * done / tasks, 8, 4, theme.green)
      yy = yy + 22
    end
    local tg = index.tagsOf[cur.id] or {}
    if #tg > 0 then
      yy = yy + 6
      K.heading(TR("tags"), x + 16, yy, w - 32)
      yy = yy + 22
      local cx = x + 16
      for i, t in ipairs(tg) do
        local cw = K.chipWidth("#" .. t)
        if cx + cw > x + w - 16 then cx = x + 16; yy = yy + 32 end
        local c, ww = K.chip("itag" .. i, "#" .. t, cx, yy, 26, false, K.colorFor(K.lower(t)))
        if c then tagFilter = K.lower(t); showSide = true; mobilePane = "list" end
        cx = cx + ww + 6
      end
      yy = yy + 36
    end
    total = yy - oy
  end
  panelScroll:setMax(total + 20 - chh)
  gfx.unclip()
end

-- ================================================================== drawing: graph view
local function drawGraph(x, y, w, h, narrow)
  if G.built ~= indexAt then buildGraph() end
  -- toolbar
  local tb = 48
  gfx.rect(x, y, w, tb, 0, theme.window)
  local bx = x + 10
  if ui.iconButton("arrow_back", bx, y + 8, 34, 32, theme.text2, false, "##gback") then view = "notes" end
  bx = bx + 40
  gfx.color(theme.text)
  if w > 640 then gfx.text(TR("graph"), bx, y + 14, 17, "bold"); bx = bx + gfx.textWidth(TR("graph"), 17, "bold") + 14 end
  local seg = ui.segmented("gmode", {TR("g_all"), TR("g_local")}, G.localMode and 2 or 1, bx, y + 9, narrow and 150 or 190, 30)
  if (seg == 2) ~= G.localMode then G.localMode = seg == 2; buildGraph(); G.fitted = false end
  bx = bx + (narrow and 150 or 190) + 10
  if #index.tagList > 0 and w > 700 then
    local items = {TR("all_tags")}
    for _, t in ipairs(index.tagList) do items[#items + 1] = "#" .. t.name end
    local nt = ui.dropdown("gtag", items, G.tag + 1, bx, y + 9, 150, 30) - 1
    if nt ~= G.tag then G.tag = nt; buildGraph(); G.fitted = false end
  end
  local right = x + w - 10
  right = right - 36
  if ui.iconButton("fit_screen", right, y + 8, 34, 32, theme.text2, false, "##gfit") then graphFit() end
  right = right - 36
  if ui.iconButton("zoom_in", right, y + 8, 34, 32, theme.text2, false, "##gzi") then zoomAt(1.25, x + w / 2, y + h / 2) end
  right = right - 36
  if ui.iconButton("zoom_out", right, y + 8, 34, 32, theme.text2, false, "##gzo") then zoomAt(0.8, x + w / 2, y + h / 2) end
  gfx.color(theme.separator); gfx.line(x, y + tb, x + w, y + tb, 1)
  -- canvas
  local ay, ah = y + tb + 1, h - tb - 1
  G.area = {x, ay, w, ah}
  if not G.fitted and G.heat < 0.5 then graphFit() end
  gfx.clip(x, ay, w, ah)
  gfx.rect(x, ay, w, ah, 0, theme.bg)
  -- dotted grid
  gfx.color(alpha(theme.text, 0.06))
  local step = 40 * G.zoom
  if step > 12 then
    local gx0 = x + w / 2 - (G.cx * G.zoom) % step
    local gy0 = ay + ah / 2 - (G.cy * G.zoom) % step
    for gx = gx0 - floor((gx0 - x) / step) * step, x + w, step do
      for gy = gy0 - floor((gy0 - ay) / step) * step, ay + ah, step do gfx.rect(gx - 1, gy - 1, 2, 2) end
    end
  end
  local hit = ui.hit("gcanvas", x, ay, w, ah)
  local mx, my = ui.mouse()
  local hover = hit.hovered and nodeAt(mx, my) or nil
  if hit.pressed then
    local a = nodeAt(mx, my)
    G.drag = a
    G.press = {mx = mx, my = my, cx = G.cx, cy = G.cy, ax = a and a.x, ay = a and a.y, moved = false}
  end
  if hit.held and G.press then
    local dx, dy = mx - G.press.mx, my - G.press.my
    if abs(dx) + abs(dy) > 6 then G.press.moved = true end
    if G.press.moved then
      if G.drag then
        G.drag.x, G.drag.y = G.press.ax + dx / G.zoom, G.press.ay + dy / G.zoom
        G.drag.vx, G.drag.vy = 0, 0
        G.heat = max(G.heat, 0.3)
      else
        G.cx, G.cy = G.press.cx - dx / G.zoom, G.press.cy - dy / G.zoom
      end
    end
  end
  if hit.clicked and G.press and not G.press.moved then
    local a = nodeAt(mx, my)
    if a then
      if G.sel == a.key or hit.doubleClicked then graphOpen(a) else G.sel = a.key; audio.play("click", 0.2) end
    else G.sel = nil end
  end
  if not hit.held then G.drag = nil end
  -- neighbourhood of the hovered/selected node
  local focus = hover or (G.sel and G.byKey[G.sel])
  local near = {}
  if focus then
    near[focus] = true
    for _, e in ipairs(G.edges) do
      if e.a == focus then near[e.b] = true elseif e.b == focus then near[e.a] = true end
    end
  end
  -- edges
  for _, e in ipairs(G.edges) do
    local x1, y1 = toScreen(e.a)
    local x2, y2 = toScreen(e.b)
    local lit = focus and (e.a == focus or e.b == focus)
    gfx.color(lit and alpha(theme.accent, 0.85) or alpha(theme.text, focus and 0.08 or (e.ghost and 0.12 or 0.2)))
    gfx.line(x1, y1, x2, y2, lit and 2 or 1.2)
  end
  -- nodes
  local curKey = cur and ("n" .. cur.id) or nil
  for _, a in ipairs(G.nodes) do
    local sx, sy = toScreen(a)
    if sx > x - 40 and sx < x + w + 40 and sy > ay - 40 and sy < ay + ah + 40 then
      local r = nodeRadius(a) * clamp(G.zoom, 0.6, 1.6)
      local dim = focus and not near[a]
      local col = a.ghost and theme.gray or (a.color or theme.accent)
      if dim then gfx.alpha(0.3) end
      if a.key == curKey then gfx.circle(sx, sy, r + 5, alpha(theme.accent, 0.25)) end
      if a.ghost then
        gfx.circle(sx, sy, r, theme.bg)
        gfx.color(col); gfx.circleLine(sx, sy, r, 1.5)
      else
        gfx.circle(sx, sy, r, col)
        gfx.color(alpha("#FFFFFF", 0.35)); gfx.circleLine(sx, sy, r, 1)
      end
      if G.sel == a.key then gfx.color(theme.text); gfx.circleLine(sx, sy, r + 4, 2) end
      local showLabel = G.zoom > 0.75 or a == focus or near[a] or a.deg >= 4 or a.key == curKey
      if showLabel then
        local fs = a == focus and 14 or 12
        local label = K.ellipsize(a.title, fs, a == focus and "semibold" or "medium", 180)
        local lw = gfx.textWidth(label, fs, "medium")
        gfx.rect(sx - lw / 2 - 5, sy + r + 3, lw + 10, fs + 6, 6, alpha(theme.bg, 0.75))
        gfx.color(a.ghost and theme.text3 or theme.text)
        gfx.text(label, sx - lw / 2, sy + r + 5, fs, a == focus and "semibold" or "medium")
      end
      if dim then gfx.unalpha() end
    end
  end
  if #G.nodes == 0 then K.empty("hub", TR("graph_empty"), nil, x, ay, w, ah) end
  -- legend / selection card
  local sel = G.sel and G.byKey[G.sel]
  if sel then
    local cw, chh = min(320, w - 24), 92
    local cx, cy = x + 12, ay + ah - chh - 12
    gfx.shadow(cx, cy, cw, chh, 12, 14, 4)
    gfx.rect(cx, cy, cw, chh, 12, theme.window)
    gfx.color(theme.text)
    gfx.text(K.ellipsize(sel.title, 15, "semibold", cw - 24), cx + 12, cy + 10, 15, "semibold")
    gfx.color(theme.text2)
    if sel.ghost then gfx.text(TR("g_missing"), cx + 12, cy + 32, 12)
    else
      gfx.text(TR("g_counts", #(index.out[sel.note.id] or {}), #(index.back[sel.note.id] or {})), cx + 12, cy + 32, 12)
    end
    if ui.button(sel.ghost and TR("create") or TR("open"), cx + 12, cy + 52, 110, 30, "primary") then graphOpen(sel) end
  else
    gfx.color(theme.text3)
    gfx.text(TR("g_hint"), x + 14, ay + ah - 26, 12)
  end
  gfx.unclip()
end

-- ================================================================== picker sheet (insert link / tag)
local function drawPicker(w, h)
  if not picker then return end
  picker.t = min(1, picker.t + frameDt * 8)
  local mx, my, cw, ch, outside = K.modal("picker", w, h, 420, 440, picker.t)
  gfx.color(theme.text)
  gfx.text(picker.kind == "link" and TR("insert_link") or TR("insert_tag"), mx + 18, my + 16, 17, "bold")
  if ui.iconButton("close", mx + cw - 46, my + 10, 34, 32, theme.text2, false, "##pclose") or outside then
    picker = nil
    return
  end
  local q, sub = K.field("pq", picker.q, mx + 16, my + 50, cw - 32, 34, picker.kind == "link" and TR("find_note") or TR("new_tag_ph"), "search")
  if q ~= picker.q then picker.q = q; picker.sel = 1 end
  local items = {}
  local lq = K.lower(K.trim(picker.q))
  if picker.kind == "link" then
    for _, n in ipairs(sortedNotes()) do
      if n ~= cur and (lq == "" or K.lower(n.title):find(lq, 1, true)) then items[#items + 1] = {label = n.title, value = n.title} end
    end
    if lq ~= "" and not index.byTitle[lq] then table.insert(items, 1, {label = TR("new_link", K.trim(picker.q)), value = K.trim(picker.q), icon = "add"}) end
  else
    for _, t in ipairs(index.tagList) do
      if lq == "" or t.key:find(lq, 1, true) then items[#items + 1] = {label = "#" .. t.name, value = t.name} end
    end
    local clean = K.trim(picker.q):gsub("^#", ""):gsub("%s+", "-")
    if clean ~= "" and not index.tags[K.lower(clean)] then table.insert(items, 1, {label = TR("new_tag", clean), value = clean, icon = "add"}) end
  end
  local ly = my + 96
  local lh = ch - 110
  picker.sel = clamp(picker.sel, 1, max(1, #items))
  local sy = ui.beginScroll("plist", mx + 8, ly, cw - 16, lh, #items * 40 + 8)
  for i, it in ipairs(items) do
    local rclick = ui.row("pr" .. i, 0, (i - 1) * 40 + 4, cw - 16, 38, i == picker.sel)
    if it.icon then gfx.icon(it.icon, 20, (i - 1) * 40 + 23, 18, theme.accent) end
    gfx.color(theme.text)
    gfx.text(K.ellipsize(it.label, 14, "medium", cw - 70), it.icon and 36 or 14, (i - 1) * 40 + 14, 14, "medium")
    if rclick then picker.sel = i; sub = true end
  end
  ui.endScroll()
  if #items == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("no_results"), mx, ly + 30, 14, "sans", "center", cw)
  end
  if sub and items[picker.sel] then
    local it, pk = items[picker.sel], picker
    picker = nil
    if pk.kind == "link" then appendToLine("[[" .. it.value .. "]]", pk.line, pk.resume)
    else appendToLine("#" .. it.value, pk.line, pk.resume) end
  end
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
  syncLines()
  if type(arg) == "string" and arg ~= "" then app.open(arg) end
end

function app.open(arg)
  if type(arg) ~= "string" or arg == "" then return end
  local id = arg:match("^note:(%d+)$")
  if id then
    local n = byId[tonumber(id)]
    if n then openNote(n); view = "notes" end
    return
  end
  if arg:find(":/", 1, true) and (arg:lower():match("%.md$") or arg:lower():match("%.markdown$") or arg:lower():match("%.txt$") or arg:lower():match("%.json$")) then
    importPath(arg)
  else
    -- shared text becomes a new note
    local first = K.trim(arg:match("^[^\n]*") or "")
    local n = importText(arg, first ~= "" and K.utf8sub(first, 1, 40) or TR("shared"))
    openNote(n)
    view = "notes"
    K.toast(TR("imported_one", n.title), "note_add")
  end
end

function app.update(dt)
  frameDt = dt
  if indexDirty and sys.time() - indexAt > 0.4 then rebuildIndex() end
  if dirty and sys.time() - changedAt > 1.0 then saveNow() end
  listScroll:update(dt)
  edScroll:update(dt)
  panelScroll:update(dt)
  if view == "graph" then
    simulate()
    -- keyboard / controller panning with the left stick when nothing else uses it
    local sx, sy = input.stick("left")
    if abs(sx) > 0.2 or abs(sy) > 0.2 then
      G.cx = G.cx + sx * dt * 500 / G.zoom
      G.cy = G.cy - sy * dt * 500 / G.zoom
    end
  end
  -- the title field lost focus: rename now
  if titleEdit and K.editing ~= "title" and not picker then commitTitle() end
  if editLine and K.editing ~= "ln" and not picker then stopEdit() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local narrow = w < 700
  narrowMode = narrow
  if narrow then edRect, panelRect = {0, 0, 0, 0}, {0, 0, 0, 0} end
  if narrow then
    if view == "graph" then drawGraph(0, 0, w, h, true)
    elseif mobilePane == "list" then drawSidebar(0, 0, w, h)
    else drawEditor(0, 0, w, h, true) end
  else
    local sideW = showSide and clamp(floor(w * 0.26), 230, 320) or 0
    if sideW > 0 then drawSidebar(0, 0, sideW, h) end
    if view == "graph" then
      drawGraph(sideW, 0, w - sideW, h, false)
    else
      local rightW = (showRight and w - sideW >= 760) and clamp(floor(w * 0.24), 230, 330) or 0
      drawEditor(sideW, 0, w - sideW - rightW, h, false)
      if rightW > 0 then drawPanel(w - rightW, 0, rightW, h) end
    end
  end
  drawPicker(w, h)
  K.drawToast(w, h)
  K.frameEnd()
end

local function listMove(d)
  local items = listItems()
  if #items == 0 then return end
  listSel = clamp(listSel + d, 1, #items)
  listScroll:reveal((listSel - 1) * 58, listSel * 58 + 8, listRect[4])
  openNote(items[listSel].note)
  if narrowMode then mobilePane = "list" end
end

function app.event(e)
  if K.press(e) then
    if picker then picker = nil end
    if editLine then stopEdit() end
    if titleEdit then commitTitle() end
    return
  end
  if picker then
    if e.type == "keydown" then
      if e.key == "escape" then picker = nil
      elseif e.key == "down" then picker.sel = picker.sel + 1
      elseif e.key == "up" then picker.sel = max(1, picker.sel - 1) end
    end
    return
  end
  if e.type == "pinch" and view == "graph" then zoomAt(e.scale or 1, e.x, e.y); return end
  if view == "graph" and e.type == "scroll" then
    local ar = G.area
    if e.x >= ar[1] and e.y >= ar[2] and e.x <= ar[1] + ar[3] and e.y <= ar[2] + ar[4] then
      if (e.dy or 0) ~= 0 then zoomAt(math.exp(-(e.dy or 0) * 0.004), e.x, e.y) end
      if (e.dx or 0) ~= 0 then G.cx = G.cx + e.dx / G.zoom end
      return
    end
  end
  if listScroll:event(e, listRect) then return end
  if view == "notes" then
    if edScroll:event(e, edRect) then return end
    if panelScroll:event(e, panelRect) then return end
  end
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl then
    if k == "n" then newNote()
    elseif k == "d" then dailyNote()
    elseif k == "f" then view = "notes"; showSide = true; mobilePane = "list"; K.focus("search")
    elseif k == "g" then stopEdit(); view = view == "graph" and "notes" or "graph"
    elseif k == "z" then if e.shift then doRedo() else doUndo() end
    elseif k == "y" then doRedo()
    elseif k == "o" then importFile()
    elseif k == "e" then exportNote()
    elseif k == "s" then saveNow(); K.toast(TR("saved"), "save")
    elseif k == "p" then togglePin()
    elseif k == "k" then openPicker("link")
    elseif k == "1" then view = "notes" elseif k == "2" then view = "graph" end
    return
  end
  -- typing into a line
  if K.editing == "ln" and editLine then
    if k == "up" then moveEdit(-1)
    elseif k == "down" then moveEdit(1)
    elseif k == "backspace" then deleteEmptyLine()
    elseif k == "tab" then
      if e.shift then setEditText((editText:gsub("^  ", ""))) else setEditText("  " .. editText) end
    end
    return
  end
  if K.editing then return end
  if view == "graph" then
    if k == "left" then graphStep(-1, 0) elseif k == "right" then graphStep(1, 0)
    elseif k == "up" then graphStep(0, -1) elseif k == "down" then graphStep(0, 1)
    elseif k == "enter" or k == "space" then graphOpen(G.sel and G.byKey[G.sel])
    elseif k == "escape" or k == "g" then view = "notes"
    elseif k == "f" then graphFit()
    elseif k == "l" then G.localMode = not G.localMode; buildGraph(); G.fitted = false end
    if e.text == "+" or k == "=" then zoomAt(1.2, G.area[1] + G.area[3] / 2, G.area[2] + G.area[4] / 2) end
    if e.text == "-" or k == "-" then zoomAt(1 / 1.2, G.area[1] + G.area[3] / 2, G.area[2] + G.area[4] / 2) end
    return
  end
  syncLines()
  local inList = narrowMode and mobilePane == "list"
  if k == "g" then view = "graph"
  elseif k == "/" then showSide = true; mobilePane = "list"; K.focus("search")
  elseif k == "up" then
    if e.shift or inList then listMove(-1)
    else lineCursor = max(1, lineCursor - 1); edScroll:reveal((lineTops[lineCursor] or 0), (lineTops[lineCursor] or 0) + 40, edRect[4]) end
  elseif k == "down" then
    if e.shift or inList then listMove(1)
    else lineCursor = min(#lines, lineCursor + 1); edScroll:reveal((lineTops[lineCursor] or 0), (lineTops[lineCursor] or 0) + 40, edRect[4]) end
  elseif k == "pageup" or k == "left" then listMove(-1)
  elseif k == "pagedown" or k == "right" then listMove(1)
  elseif k == "enter" then
    if inList then mobilePane = "note" else startEdit(lineCursor) end
  elseif k == "space" then
    local l = lines[lineCursor]
    if l and l:match("^%s*[-*+] %[[ xX]%]") then toggleTask(lineCursor) end
  elseif k == "delete" then deleteCurrent()
  elseif k == "f2" then if cur then titleEdit, titleText = true, cur.title; K.focus("title") end
  elseif k == "escape" then
    if mobilePane == "note" then mobilePane = "list" end
  end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("new_note"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("daily"), id = 2, shortcut = "Ctrl+D"},
      "-",
      {label = TR("import"), id = 3, shortcut = "Ctrl+O"},
      {label = TR("export_md"), id = 4, shortcut = "Ctrl+E"},
      {label = TR("backup"), id = 5},
      "-",
      {label = TR("delete"), id = 6, shortcut = "Del"},
    }},
    {title = TR("m_edit"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("find"), id = 12, shortcut = "Ctrl+F"},
      {label = TR("insert_link"), id = 13, shortcut = "Ctrl+K"},
      {label = TR("rename"), id = 14, shortcut = "F2"},
      {label = TR("pin"), id = 15, shortcut = "Ctrl+P"},
    }},
    {title = TR("m_view"), items = {
      {label = TR("notes"), id = 20, shortcut = "Ctrl+1"},
      {label = TR("graph"), id = 21, shortcut = "Ctrl+G"},
      "-",
      {label = TR("sidebar"), id = 22},
      {label = TR("side_panel"), id = 23},
      "-",
      {label = TR("sort_recent"), id = 24},
      {label = TR("sort_title"), id = 25},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newNote() elseif id == 2 then dailyNote() elseif id == 3 then importFile()
  elseif id == 4 then exportNote() elseif id == 5 then exportBackup() elseif id == 6 then deleteCurrent()
  elseif id == 10 then doUndo() elseif id == 11 then doRedo()
  elseif id == 12 then view = "notes"; showSide = true; mobilePane = "list"; K.focus("search")
  elseif id == 13 then openPicker("link")
  elseif id == 14 then if cur then view = "notes"; titleEdit, titleText = true, cur.title; K.focus("title") end
  elseif id == 15 then togglePin()
  elseif id == 20 then view = "notes" elseif id == 21 then stopEdit(); view = "graph"
  elseif id == 22 then showSide = not showSide; saveNow() elseif id == 23 then showRight = not showRight; saveNow()
  elseif id == 24 then sortMode = 1; saveNow() elseif id == 25 then sortMode = 2; saveNow() end
end

function app.search(q)
  local out = {}
  for i, r in ipairs(searchNotes(q)) do
    if i > 5 then break end
    out[#out + 1] = {title = r.note.title, subtitle = r.snip ~= "" and r.snip or TR("app_name"), icon = "description",
                     arg = "note:" .. r.note.id}
  end
  return out
end

function app.suspend() if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close()
  if titleEdit then commitTitle() end
  saveNow()
  store.save()
  return true
end

return app
