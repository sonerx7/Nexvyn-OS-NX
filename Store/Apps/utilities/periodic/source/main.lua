-- Periodic Table for Nexvyn OS: all 118 elements, detail card, search, category/state views and a temperature slider.
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
local function inside(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

-- text-field focus tracking (so typing never triggers shortcuts)
local editing, pressFlag, fieldHit = false, false, false
local function field(id, text, x, y, w, h, ph, flags)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressFlag then
    local mx, my = ui.mouse()
    if inside(mx, my, x, y, w, h) then fieldHit = true end
  end
  return nt, sub
end

-- Turkish-aware case/diacritic folding for search
local FOLD = {["ç"] = "c", ["Ç"] = "c", ["ğ"] = "g", ["Ğ"] = "g", ["ı"] = "i", ["İ"] = "i", ["ö"] = "o", ["Ö"] = "o",
              ["ş"] = "s", ["Ş"] = "s", ["ü"] = "u", ["Ü"] = "u"}
local function fold(s)
  s = s:gsub("[\195-\197][\128-\191]", function(ch) return FOLD[ch] or ch end)
  return s:lower()
end

-- ------------------------------------------------------------------ data
-- {symbol, English name, Turkish name, atomic mass, category, melting K, boiling K, discovery year (0 = antiquity)}
local E = {
  {"H", "Hydrogen", "Hidrojen", "1.008", "nm", 14.01, 20.28, 1766},
  {"He", "Helium", "Helyum", "4.0026", "ng", nil, 4.22, 1868},
  {"Li", "Lithium", "Lityum", "6.94", "am", 453.65, 1603, 1817},
  {"Be", "Beryllium", "Berilyum", "9.0122", "ae", 1560, 2742, 1798},
  {"B", "Boron", "Bor", "10.81", "md", 2349, 4200, 1808},
  {"C", "Carbon", "Karbon", "12.011", "nm", 3915, 3915, 0},
  {"N", "Nitrogen", "Azot", "14.007", "nm", 63.15, 77.36, 1772},
  {"O", "Oxygen", "Oksijen", "15.999", "nm", 54.36, 90.19, 1774},
  {"F", "Fluorine", "Flor", "18.998", "ha", 53.48, 85.03, 1886},
  {"Ne", "Neon", "Neon", "20.180", "ng", 24.56, 27.07, 1898},
  {"Na", "Sodium", "Sodyum", "22.990", "am", 370.94, 1156.09, 1807},
  {"Mg", "Magnesium", "Magnezyum", "24.305", "ae", 923, 1363, 1755},
  {"Al", "Aluminium", "Alüminyum", "26.982", "pt", 933.47, 2792, 1825},
  {"Si", "Silicon", "Silisyum", "28.085", "md", 1687, 3538, 1824},
  {"P", "Phosphorus", "Fosfor", "30.974", "nm", 317.3, 553.7, 1669},
  {"S", "Sulfur", "Kükürt", "32.06", "nm", 388.36, 717.88, 0},
  {"Cl", "Chlorine", "Klor", "35.45", "ha", 171.6, 239.11, 1774},
  {"Ar", "Argon", "Argon", "39.948", "ng", 83.8, 87.3, 1894},
  {"K", "Potassium", "Potasyum", "39.098", "am", 336.53, 1032, 1807},
  {"Ca", "Calcium", "Kalsiyum", "40.078", "ae", 1115, 1757, 1808},
  {"Sc", "Scandium", "Skandiyum", "44.956", "tm", 1814, 3109, 1879},
  {"Ti", "Titanium", "Titanyum", "47.867", "tm", 1941, 3560, 1791},
  {"V", "Vanadium", "Vanadyum", "50.942", "tm", 2183, 3680, 1801},
  {"Cr", "Chromium", "Krom", "51.996", "tm", 2180, 2944, 1797},
  {"Mn", "Manganese", "Mangan", "54.938", "tm", 1519, 2334, 1774},
  {"Fe", "Iron", "Demir", "55.845", "tm", 1811, 3134, 0},
  {"Co", "Cobalt", "Kobalt", "58.933", "tm", 1768, 3200, 1735},
  {"Ni", "Nickel", "Nikel", "58.693", "tm", 1728, 3186, 1751},
  {"Cu", "Copper", "Bakır", "63.546", "tm", 1357.77, 2835, 0},
  {"Zn", "Zinc", "Çinko", "65.38", "tm", 692.68, 1180, 1746},
  {"Ga", "Gallium", "Galyum", "69.723", "pt", 302.91, 2673, 1875},
  {"Ge", "Germanium", "Germanyum", "72.630", "md", 1211.4, 3106, 1886},
  {"As", "Arsenic", "Arsenik", "74.922", "md", 887, 887, 1250},
  {"Se", "Selenium", "Selenyum", "78.971", "nm", 494, 958, 1817},
  {"Br", "Bromine", "Brom", "79.904", "ha", 265.8, 332.0, 1826},
  {"Kr", "Krypton", "Kripton", "83.798", "ng", 115.78, 119.93, 1898},
  {"Rb", "Rubidium", "Rubidyum", "85.468", "am", 312.46, 961, 1861},
  {"Sr", "Strontium", "Stronsiyum", "87.62", "ae", 1050, 1650, 1790},
  {"Y", "Yttrium", "İtriyum", "88.906", "tm", 1799, 3609, 1794},
  {"Zr", "Zirconium", "Zirkonyum", "91.224", "tm", 2128, 4682, 1789},
  {"Nb", "Niobium", "Niyobyum", "92.906", "tm", 2750, 5017, 1801},
  {"Mo", "Molybdenum", "Molibden", "95.95", "tm", 2896, 4912, 1778},
  {"Tc", "Technetium", "Teknesyum", "[98]", "tm", 2430, 4538, 1937},
  {"Ru", "Ruthenium", "Rutenyum", "101.07", "tm", 2607, 4423, 1844},
  {"Rh", "Rhodium", "Rodyum", "102.91", "tm", 2237, 3968, 1804},
  {"Pd", "Palladium", "Paladyum", "106.42", "tm", 1828.05, 3236, 1802},
  {"Ag", "Silver", "Gümüş", "107.87", "tm", 1234.93, 2435, 0},
  {"Cd", "Cadmium", "Kadmiyum", "112.41", "tm", 594.22, 1040, 1817},
  {"In", "Indium", "İndiyum", "114.82", "pt", 429.75, 2345, 1863},
  {"Sn", "Tin", "Kalay", "118.71", "pt", 505.08, 2875, 0},
  {"Sb", "Antimony", "Antimon", "121.76", "md", 903.78, 1908, 0},
  {"Te", "Tellurium", "Tellür", "127.60", "md", 722.66, 1261, 1782},
  {"I", "Iodine", "İyot", "126.90", "ha", 386.85, 457.4, 1811},
  {"Xe", "Xenon", "Ksenon", "131.29", "ng", 161.4, 165.03, 1898},
  {"Cs", "Caesium", "Sezyum", "132.91", "am", 301.59, 944, 1860},
  {"Ba", "Barium", "Baryum", "137.33", "ae", 1000, 2170, 1808},
  {"La", "Lanthanum", "Lantan", "138.91", "la", 1193, 3737, 1839},
  {"Ce", "Cerium", "Seryum", "140.12", "la", 1068, 3716, 1803},
  {"Pr", "Praseodymium", "Praseodim", "140.91", "la", 1208, 3793, 1885},
  {"Nd", "Neodymium", "Neodim", "144.24", "la", 1297, 3347, 1885},
  {"Pm", "Promethium", "Prometyum", "[145]", "la", 1315, 3273, 1945},
  {"Sm", "Samarium", "Samaryum", "150.36", "la", 1345, 2067, 1879},
  {"Eu", "Europium", "Evropiyum", "151.96", "la", 1099, 1802, 1901},
  {"Gd", "Gadolinium", "Gadolinyum", "157.25", "la", 1585, 3546, 1880},
  {"Tb", "Terbium", "Terbiyum", "158.93", "la", 1629, 3503, 1843},
  {"Dy", "Dysprosium", "Disprozyum", "162.50", "la", 1680, 2840, 1886},
  {"Ho", "Holmium", "Holmiyum", "164.93", "la", 1734, 2993, 1878},
  {"Er", "Erbium", "Erbiyum", "167.26", "la", 1802, 3141, 1843},
  {"Tm", "Thulium", "Tulyum", "168.93", "la", 1818, 2223, 1879},
  {"Yb", "Ytterbium", "İterbiyum", "173.05", "la", 1097, 1469, 1878},
  {"Lu", "Lutetium", "Lutesyum", "174.97", "la", 1925, 3675, 1907},
  {"Hf", "Hafnium", "Hafniyum", "178.49", "tm", 2506, 4876, 1923},
  {"Ta", "Tantalum", "Tantal", "180.95", "tm", 3290, 5731, 1802},
  {"W", "Tungsten", "Tungsten", "183.84", "tm", 3695, 5828, 1783},
  {"Re", "Rhenium", "Renyum", "186.21", "tm", 3459, 5869, 1925},
  {"Os", "Osmium", "Osmiyum", "190.23", "tm", 3306, 5285, 1803},
  {"Ir", "Iridium", "İridyum", "192.22", "tm", 2719, 4403, 1803},
  {"Pt", "Platinum", "Platin", "195.08", "tm", 2041.4, 4098, 1735},
  {"Au", "Gold", "Altın", "196.97", "tm", 1337.33, 3129, 0},
  {"Hg", "Mercury", "Cıva", "200.59", "tm", 234.32, 629.88, 0},
  {"Tl", "Thallium", "Talyum", "204.38", "pt", 577, 1746, 1861},
  {"Pb", "Lead", "Kurşun", "207.2", "pt", 600.61, 2022, 0},
  {"Bi", "Bismuth", "Bizmut", "208.98", "pt", 544.7, 1837, 1753},
  {"Po", "Polonium", "Polonyum", "[209]", "pt", 527, 1235, 1898},
  {"At", "Astatine", "Astatin", "[210]", "ha", 575, 610, 1940},
  {"Rn", "Radon", "Radon", "[222]", "ng", 202, 211.3, 1899},
  {"Fr", "Francium", "Fransiyum", "[223]", "am", 300, 950, 1939},
  {"Ra", "Radium", "Radyum", "[226]", "ae", 973, 2010, 1898},
  {"Ac", "Actinium", "Aktinyum", "[227]", "ac", 1323, 3471, 1899},
  {"Th", "Thorium", "Toryum", "232.04", "ac", 2023, 5061, 1829},
  {"Pa", "Protactinium", "Protaktinyum", "231.04", "ac", 1841, 4300, 1913},
  {"U", "Uranium", "Uranyum", "238.03", "ac", 1405.3, 4404, 1789},
  {"Np", "Neptunium", "Neptünyum", "[237]", "ac", 912, 4447, 1940},
  {"Pu", "Plutonium", "Plütonyum", "[244]", "ac", 912.5, 3505, 1940},
  {"Am", "Americium", "Amerikyum", "[243]", "ac", 1449, 2880, 1944},
  {"Cm", "Curium", "Küriyum", "[247]", "ac", 1613, 3383, 1944},
  {"Bk", "Berkelium", "Berkelyum", "[247]", "ac", 1259, nil, 1949},
  {"Cf", "Californium", "Kaliforniyum", "[251]", "ac", 1173, nil, 1950},
  {"Es", "Einsteinium", "Aynştaynyum", "[252]", "ac", 1133, nil, 1952},
  {"Fm", "Fermium", "Fermiyum", "[257]", "ac", nil, nil, 1952},
  {"Md", "Mendelevium", "Mendelevyum", "[258]", "ac", nil, nil, 1955},
  {"No", "Nobelium", "Nobelyum", "[259]", "ac", nil, nil, 1966},
  {"Lr", "Lawrencium", "Lavrensiyum", "[266]", "ac", nil, nil, 1961},
  {"Rf", "Rutherfordium", "Rutherfordiyum", "[267]", "tm", nil, nil, 1964},
  {"Db", "Dubnium", "Dubniyum", "[268]", "tm", nil, nil, 1968},
  {"Sg", "Seaborgium", "Seaborgiyum", "[269]", "tm", nil, nil, 1974},
  {"Bh", "Bohrium", "Bohriyum", "[270]", "tm", nil, nil, 1981},
  {"Hs", "Hassium", "Hassiyum", "[269]", "tm", nil, nil, 1984},
  {"Mt", "Meitnerium", "Meitneriyum", "[278]", "tm", nil, nil, 1982},
  {"Ds", "Darmstadtium", "Darmstadtiyum", "[281]", "tm", nil, nil, 1994},
  {"Rg", "Roentgenium", "Röntgenyum", "[282]", "tm", nil, nil, 1994},
  {"Cn", "Copernicium", "Kopernikyum", "[285]", "tm", nil, nil, 1996},
  {"Nh", "Nihonium", "Nihonyum", "[286]", "pt", nil, nil, 2004},
  {"Fl", "Flerovium", "Flerovyum", "[289]", "pt", nil, nil, 1999},
  {"Mc", "Moscovium", "Moskovyum", "[290]", "pt", nil, nil, 2003},
  {"Lv", "Livermorium", "Livermoryum", "[293]", "pt", nil, nil, 2000},
  {"Ts", "Tennessine", "Tennesin", "[294]", "ha", nil, nil, 2010},
  {"Og", "Oganesson", "Oganesson", "[294]", "ng", nil, nil, 2002},
}

local CATS = {"am", "ae", "tm", "pt", "md", "nm", "ha", "ng", "la", "ac"}
local CATCOL = {am = "#FF6B6B", ae = "#FF922B", tm = "#FAB005", pt = "#82C91E", md = "#12B886", nm = "#15AABF",
                ha = "#4C6EF5", ng = "#9775FA", la = "#F06595", ac = "#C08552"}
local CATKEY = {am = "cat_am", ae = "cat_ae", tm = "cat_tm", pt = "cat_pt", md = "cat_md", nm = "cat_nm",
                ha = "cat_ha", ng = "cat_ng", la = "cat_la", ac = "cat_ac"}
local STATEKEY = {[0] = "state_unknown", [1] = "state_solid", [2] = "state_liquid", [3] = "state_gas"}
local ROOM = 298

-- electron configurations (Madelung rule + measured exceptions)
local ORDER = {"1s", "2s", "2p", "3s", "3p", "4s", "3d", "4p", "5s", "4d", "5p", "6s", "4f", "5d", "6p", "7s", "5f", "6d", "7p"}
local CAP = {s = 2, p = 6, d = 10, f = 14}
local LORD = {s = 0, p = 1, d = 2, f = 3}
local EXC = {[24] = "3d5 4s1", [29] = "3d10 4s1", [41] = "4d4 5s1", [42] = "4d5 5s1", [44] = "4d7 5s1", [45] = "4d8 5s1",
             [46] = "4d10", [47] = "4d10 5s1", [57] = "5d1 6s2", [58] = "4f1 5d1 6s2", [64] = "4f7 5d1 6s2",
             [78] = "4f14 5d9 6s1", [79] = "4f14 5d10 6s1", [89] = "6d1 7s2", [90] = "6d2 7s2", [91] = "5f2 6d1 7s2",
             [92] = "5f3 6d1 7s2", [93] = "5f4 6d1 7s2", [96] = "5f7 6d1 7s2", [103] = "5f14 7s2 7p1"}
local NOBLE = {{86, "Rn"}, {54, "Xe"}, {36, "Kr"}, {18, "Ar"}, {10, "Ne"}, {2, "He"}}
local SUP = {["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴", ["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹"}

local function fill(z)
  local cnt, left = {}, z
  for _, sh in ipairs(ORDER) do
    if left <= 0 then break end
    local c = min(left, CAP[sh:sub(2, 2)])
    cnt[sh] = c
    left = left - c
  end
  return cnt
end

local function configOf(z)
  local core, coreSym = 0, nil
  for _, n in ipairs(NOBLE) do
    if n[1] < z then core, coreSym = n[1], n[2]; break end
  end
  local parts = {}
  if EXC[z] then
    for tok in EXC[z]:gmatch("%S+") do parts[#parts + 1] = tok end
  else
    local a, b = fill(z), fill(core)
    local list = {}
    for _, sh in ipairs(ORDER) do
      local d = (a[sh] or 0) - (b[sh] or 0)
      if d > 0 then list[#list + 1] = {sh = sh, n = tonumber(sh:sub(1, 1)), l = LORD[sh:sub(2, 2)], c = d} end
    end
    table.sort(list, function(p, q) if p.n ~= q.n then return p.n < q.n end return p.l < q.l end)
    for _, it in ipairs(list) do parts[#parts + 1] = it.sh .. it.c end
  end
  local out = {}
  if coreSym then out[1] = "[" .. coreSym .. "]" end
  for _, p in ipairs(parts) do
    local sh, num = p:match("^(%d%a)(%d+)$")
    out[#out + 1] = sh .. num:gsub("%d", SUP)
  end
  return table.concat(out, " ")
end

-- grid position: col 1..18, row 1..7 (main) or 9..10 (f-block rows)
local function posOf(z)
  if z == 1 then return 1, 1 end
  if z == 2 then return 18, 1 end
  if z <= 4 then return z - 2, 2 end
  if z <= 10 then return z + 8, 2 end
  if z <= 12 then return z - 10, 3 end
  if z <= 18 then return z, 3 end
  if z <= 36 then return z - 18, 4 end
  if z <= 54 then return z - 36, 5 end
  if z <= 56 then return z - 54, 6 end
  if z <= 71 then return z - 54, 9 end
  if z <= 86 then return z - 68, 6 end
  if z <= 88 then return z - 86, 7 end
  if z <= 103 then return z - 86, 10 end
  return z - 100, 7
end

local INFO = {}
for z, e in ipairs(E) do
  local col, row = posOf(z)
  local period = row <= 7 and row or (row == 9 and 6 or 7)
  local group = row <= 7 and col or nil
  local block
  if row > 7 then block = "f"
  elseif col <= 2 or z == 2 then block = "s"
  elseif col <= 12 then block = "d"
  else block = "p" end
  INFO[z] = {col = col, row = row, nav = row <= 7 and row or (row - 0.6), period = period, group = group, block = block,
             config = configOf(z), fs = fold(e[1]), fen = fold(e[2]), ftr = fold(e[3])}
end

local function stateAt(e, T)
  local mp, bp = e[6], e[7]
  if not mp and not bp then return 0 end
  if mp and T < mp then return 1 end
  if bp and T >= bp then return 3 end
  if not bp then return 0 end
  return 2
end
local function stateColor(s)
  if s == 1 then return theme.gray elseif s == 2 then return theme.blue elseif s == 3 then return theme.red end
  return theme.text3
end

local isTR = false
local function nameOf(z) return isTR and E[z][3] or E[z][2] end
local function altNameOf(z) return isTR and E[z][2] or E[z][3] end

local function fmtNum(v, dec)
  local s = string.format("%." .. (dec or 1) .. "f", v)
  s = s:gsub("%.?0+$", "")
  if s == "-0" then s = "0" end
  return s
end
local function tempText(k)
  return TR("temp_value", fmtNum(k, 0), fmtNum(k - 273.15, 0))
end

-- ------------------------------------------------------------------ state
local search = ""
local sel = 1
local hoverZ = nil
local mode = 1           -- 1 = category colors, 2 = state at the chosen temperature
local temp = ROOM
local filterCat = nil
local filterState = nil
local modeT = 0
local anim = {}
for z = 1, #E do anim[z] = {h = 0, d = 1} end
local shownZ, cardT = 1, 1
local matchCache, matchRaw = {}, nil
local nameFit = {}       -- [z] = {text, size} fitted to the tile width

local function save()
  store.set("sel", sel)
  store.set("mode", mode)
  store.set("temp", temp)
  store.set("filterCat", filterCat or "")
  store.set("filterState", filterState or -1)
end

local function refreshSearch()
  if search == matchRaw then return end
  matchRaw = search
  matchCache = {}
  local q = fold((search:gsub("^%s+", ""):gsub("%s+$", "")))
  local num = tonumber(q)
  for i = 1, #E do
    local inf = INFO[i]
    local ok = q == ""
    if not ok then
      if num then ok = (i == num)
      else
        ok = inf.fs == q or (#q <= 2 and inf.fs:sub(1, #q) == q) or inf.fen:find(q, 1, true) ~= nil
          or inf.ftr:find(q, 1, true) ~= nil
      end
    end
    matchCache[i] = ok
  end
end

local function matches(z)
  local ok = matchCache[z]
  if ok and mode == 1 and filterCat and E[z][5] ~= filterCat then ok = false end
  if ok and mode == 2 and filterState and stateAt(E[z], temp) ~= filterState then ok = false end
  return ok
end

local function selectEl(z, silent)
  if z and z ~= sel then
    sel = z
    save()
    if not silent then audio.tone(1046.5, 0.04, 0.12, "sine") end
  end
end

local function firstMatch()
  refreshSearch()
  for z = 1, #E do if matches(z) then return z end end
  return nil
end

local function navigate(dx, dy)
  local c = INFO[sel]
  local best, bestScore = nil, 1e9
  for z = 1, #E do
    if z ~= sel then
      local o = INFO[z]
      local ddx, ddy = o.col - c.col, o.nav - c.nav
      local primary, secondary
      if dx ~= 0 then primary, secondary = ddx * dx, abs(ddy) else primary, secondary = ddy * dy, abs(ddx) end
      if primary > 0.01 then
        local score = primary + secondary * 3
        if score < bestScore then best, bestScore = z, score end
      end
    end
  end
  if best then selectEl(best) end
end

-- ------------------------------------------------------------------ app
function app.load()
  isTR = sys.lang() == "tr"
  sel = clamp(math.tointeger(store.get("sel", 1)) or 1, 1, #E)
  mode = store.get("mode", 1) == 2 and 2 or 1
  temp = clamp(tonumber(store.get("temp", ROOM)) or ROOM, 0, 6000)
  local fc = store.get("filterCat", "")
  filterCat = CATCOL[fc] and fc or nil
  local fs = store.get("filterState", -1)
  filterState = (type(fs) == "number" and fs >= 0 and fs <= 3) and fs or nil
  modeT = mode == 2 and 1 or 0
  shownZ = sel
  refreshSearch()
end

function app.update(dt)
  refreshSearch()
  modeT = approach(modeT, mode == 2 and 1 or 0, 10, dt)
  for z = 1, #E do
    local a = anim[z]
    a.h = approach(a.h, (z == sel and 1 or (z == hoverZ and 0.6 or 0)), 16, dt)
    a.d = approach(a.d, matches(z) and 1 or 0.16, 10, dt)
  end
  local show = hoverZ or sel
  if show ~= shownZ then shownZ = show; cardT = 0 end
  cardT = approach(cardT, 1, 12, dt)
end

local function fittedName(z, maxW)
  local f = nameFit[z]
  if f and f.w == maxW then return f.text, f.size end
  local nm = nameOf(z)
  local size = 8.5
  local wdt = gfx.textWidth(nm, size)
  if wdt > maxW then
    size = max(7, size * maxW / wdt)
    if gfx.textWidth(nm, size) > maxW then
      while utf8.len(nm) > 2 and gfx.textWidth(nm .. "…", size) > maxW do
        nm = nm:sub(1, utf8.offset(nm, -1) - 1)
      end
      nm = nm .. "…"
    end
  end
  nameFit[z] = {w = maxW, text = nm, size = size}
  return nm, size
end

local function drawTile(z, x, y, s)
  local e, a = E[z], anim[z]
  local base = CATCOL[e[5]]
  if modeT > 0.004 then base = mix(base, stateColor(stateAt(e, temp)), modeT) end
  local grow = a.h * 3
  local tx, ty, ts = x - grow, y - grow, s + grow * 2
  gfx.alpha(a.d)
  if a.h > 0.05 then gfx.shadow(tx, ty, ts, ts, 7, 10 * a.h, 3 * a.h) end
  local k = (theme.dark and 0.30 or 0.22) + a.h * 0.14
  gfx.rect(tx, ty, ts, ts, 7, mix(theme.bg, base, k))
  if z == sel then
    gfx.color(theme.accent)
    gfx.rectLine(tx, ty, ts, ts, 7, 2)
  else
    gfx.color(alpha(base, theme.dark and 0.55 or 0.65))
    gfx.rectLine(tx, ty, ts, ts, 7, 1)
  end
  gfx.color(theme.text2)
  gfx.text(tostring(z), tx + 4, ty + 3, 9, "medium")
  gfx.color(theme.text)
  gfx.text(e[1], tx, ty + ts * 0.24, s >= 46 and 18 or 15, "bold", "center", ts)
  local nm, size = fittedName(z, s - 5)
  gfx.color(theme.text2)
  gfx.text(nm, tx, ty + ts - 14, size, "sans", "center", ts)
  gfx.unalpha()
end

local function chip(id, label, col, x, y, active, size)
  local tw = gfx.textWidth(label, size, "medium")
  local w, h = tw + 30, 26
  local hit = ui.hit(id, x, y, w, h)
  if active then
    gfx.rect(x, y, w, h, 13, mix(theme.bg, col, theme.dark and 0.45 or 0.30))
    gfx.color(col)
    gfx.rectLine(x, y, w, h, 13, 1.5)
  elseif hit.hovered then
    gfx.rect(x, y, w, h, 13, theme.hover)
  end
  gfx.circle(x + 13, y + h / 2, 5, col)
  gfx.color(theme.text)
  gfx.text(label, x + 23, y + (h - gfx.textHeight(size, "medium")) / 2, size, "medium")
  return hit.clicked, w
end

local function legendWidth(labels, size)
  local tot = 0
  for _, l in ipairs(labels) do tot = tot + gfx.textWidth(l, size, "medium") + 36 end
  return tot - 6
end

local function drawLegend(x, y, w)
  local labels, cols, keys = {}, {}, {}
  if mode == 1 then
    for i, c in ipairs(CATS) do labels[i] = TR(CATKEY[c]); cols[i] = CATCOL[c]; keys[i] = c end
  else
    for i, s in ipairs({1, 2, 3, 0}) do labels[i] = TR(STATEKEY[s]); cols[i] = stateColor(s); keys[i] = s end
  end
  local size = 12
  local tot = legendWidth(labels, size)
  while tot > w and size > 9 do size = size - 0.5; tot = legendWidth(labels, size) end
  local cx = x + (w - tot) / 2
  for i, l in ipairs(labels) do
    local active = (mode == 1 and filterCat == keys[i]) or (mode == 2 and filterState == keys[i])
    local clicked, cw = chip("lg" .. mode .. "_" .. i, l, cols[i], cx, y, active, size)
    if clicked then
      if mode == 1 then filterCat = (filterCat == keys[i]) and nil or keys[i]
      else filterState = (filterState == keys[i]) and nil or keys[i] end
      audio.play("click", 0.5)
      save()
    end
    cx = cx + cw + 6
  end
end

local function infoCell(label, value, sub, x, y)
  gfx.color(theme.text3)
  gfx.text(label, x, y, 10, "medium")
  gfx.color(theme.text)
  gfx.text(value, x, y + 12, 13, "semibold")
  if sub then
    gfx.color(theme.text2)
    gfx.text(sub, x, y + 28, 10)
  end
end

local function pill(text, col, x, y, rightAlign, center, cw)
  local tw = gfx.textWidth(text, 11, "semibold")
  local w = tw + 16
  if rightAlign then x = x - w end
  if center then x = x + (cw - w) / 2 end
  gfx.rect(x, y, w, 20, 10, mix(theme.bg, col, theme.dark and 0.42 or 0.24))
  gfx.color(theme.text)
  gfx.text(text, x + 8, y + 3, 11, "semibold")
  return w
end

local function drawCard(x, y, w, h)
  local z = shownZ
  local e, inf = E[z], INFO[z]
  gfx.shadow(x, y, w, h, 12, 14, 3)
  gfx.rect(x, y, w, h, 12, theme.dark and theme.window or theme.bg)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
  local t = cardT
  gfx.alpha(0.35 + 0.65 * t)
  local slide = (1 - t) * 8
  local catC = CATCOL[e[5]]
  if h < 130 or w < 440 then
    -- small window (or a large interface scale): symbol tile, name, configuration and mass only
    local bs = h - 16
    gfx.gradient(x + 8, y + 8, bs, bs, mix(theme.bg, catC, theme.dark and 0.55 or 0.40), mix(theme.bg, catC, theme.dark and 0.28 or 0.16), false, 8)
    gfx.color(theme.text)
    gfx.text(tostring(z), x + 13, y + 11, 10, "semibold")
    local ss = floor(min(34, bs * 0.42))
    gfx.text(e[1], x + 8, y + 8 + (bs - ss * 1.2) / 2, ss, "bold", "center", bs)
    local ix = x + bs + 18 + slide
    local nm = nameOf(z)
    gfx.text(nm, ix, y + 6, h < 100 and 14 or 16, "bold")
    pill(TR(CATKEY[e[5]]), catC, x + w - 10, y + 7, true)
    gfx.text(inf.config, ix, y + h * 0.40, 12, "semibold")
    gfx.color(theme.text2)
    gfx.text(e[4] .. " " .. TR("mass_unit") .. " · " .. TR("state_at", "25 °C", TR(STATEKEY[stateAt(e, ROOM)])), ix, y + h - 22, 11)
    gfx.unalpha()
    return
  end
  -- big tile
  local bx, by, bw, bh = x + 10, y + 10, 112, h - 20
  gfx.gradient(bx, by, bw, bh, mix(theme.bg, catC, theme.dark and 0.55 or 0.40), mix(theme.bg, catC, theme.dark and 0.28 or 0.16), false, 10)
  gfx.color(theme.text)
  gfx.text(tostring(z), bx + 9, by + 7, 13, "semibold")
  gfx.text(e[1], bx, by + bh * 0.15, 42, "bold", "center", bw)
  gfx.color(theme.text2)
  local nm = nameOf(z)
  gfx.text(nm, bx, by + bh - 44, gfx.textWidth(nm, 12, "medium") > bw - 10 and 10 or 12, "medium", "center", bw)
  local rs = stateAt(e, ROOM)
  pill(TR("state_at", "25 °C", TR(STATEKEY[rs])), stateColor(rs), bx, by + bh - 25, false, true, bw)
  -- details
  local ix = x + 136 + slide
  local iw = w - 136 - 14
  gfx.color(theme.text)
  gfx.text(nm, ix, y + 8, 19, "bold")
  local catLabel = TR(CATKEY[e[5]])
  if z >= 109 then catLabel = catLabel .. " " .. TR("predicted") end
  pill(catLabel, catC, x + w - 14, y + 10, true)
  gfx.color(theme.text2)
  gfx.text(altNameOf(z), ix, y + 33, 12)
  gfx.color(theme.text3)
  gfx.text(TR("discovered", e[8] == 0 and TR("antiquity") or tostring(e[8])), x, y + 33, 12, "sans", "right", w - 14)
  -- configuration (+ state at the slider temperature)
  gfx.color(theme.text3)
  gfx.text(TR("config"), ix, y + 55, 10, "medium")
  gfx.color(theme.text)
  gfx.text(inf.config, ix, y + 67, 15, "semibold")
  if abs(temp - ROOM) >= 1 then
    local ts = stateAt(e, temp)
    pill(TR("state_at", fmtNum(temp, 0) .. " K", TR(STATEKEY[ts])), stateColor(ts), x + w - 14, y + 66, true)
  end
  -- grid
  local cw = iw / 4
  local gy = y + h - 44
  ui.separator(ix, gy - 6, ix + iw)
  infoCell(TR("mass"), e[4], TR("mass_unit"), ix, gy)
  local gp = (inf.group and tostring(inf.group) or "–") .. " / " .. inf.period
  infoCell(TR("group_period"), gp, TR("block", inf.block), ix + cw, gy)
  if e[6] then
    infoCell(TR("melting"), fmtNum(e[6] - 273.15, 1) .. " °C", fmtNum(e[6], 2) .. " K", ix + cw * 2, gy)
  else
    infoCell(TR("melting"), "—", z == 2 and TR("no_solid") or TR("no_data"), ix + cw * 2, gy)
  end
  if e[7] then
    local lbl = (e[6] and e[6] == e[7]) and TR("sublimation") or TR("boiling")
    infoCell(lbl, fmtNum(e[7] - 273.15, 1) .. " °C", fmtNum(e[7], 2) .. " K", ix + cw * 3, gy)
  else
    infoCell(TR("boiling"), "—", TR("no_data"), ix + cw * 3, gy)
  end
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- toolbar
  gfx.rect(0, 0, w, 48, 0, theme.window)
  ui.separator(0, 48, w)
  gfx.icon("science", 30, 24, 22, theme.accent)
  gfx.color(theme.text)
  gfx.text(TR("title"), 48, 14, 16, "bold")
  local sx = 200
  local ns, sub = field("search", search, sx, 9, 180, 30, TR("search_hint"), "search")
  if ns ~= search then search = ns; refreshSearch() end
  if sub then
    local f = firstMatch()
    if f then selectEl(f) end
  end
  local nm = ui.segmented("mode", {TR("view_category"), TR("view_state")}, mode, sx + 192, 10, 200, 28)
  if nm ~= mode then mode = nm; save(); audio.play("click", 0.4) end
  local tx = sx + 404
  gfx.icon("thermostat", tx + 10, 24, 20, temp > ROOM + 1 and theme.orange or (temp < ROOM - 1 and theme.blue or theme.text2))
  local nt = ui.slider("temp", temp, 0, 6000, tx + 24, 12, 170, 1)
  if nt ~= temp then
    temp = floor(nt + 0.5)
    if mode ~= 2 then mode = 2 end
    save()
  end
  gfx.color(theme.text)
  gfx.text(tempText(temp), tx + 202, 16, 12, "semibold")
  if ui.iconButton("restart_alt", w - 44, 9, 30, 30, nil, false, "rt") then
    temp = ROOM
    save()
    audio.play("click", 0.4)
  end

  -- grid metrics
  local top = 66
  local legendH = 38
  local availH = h - top - legendH - 6
  local pitch = floor(min((w - 44) / 18, availH / 9.45))
  local gap = 3
  local s = pitch - gap
  local ox = floor((w - pitch * 18) / 2 + 8)
  local fGap = floor(pitch * 0.45)
  local function cellXY(col, row)
    local y = top + (row - 1) * pitch
    if row >= 9 then y = top + 7 * pitch + fGap + (row - 9) * pitch end
    return ox + (col - 1) * pitch, y
  end

  -- group numbers (above the first element of each column) and period numbers
  gfx.color(theme.text3)
  for g = 1, 18 do
    local firstRow = (g == 1 or g == 18) and 1 or ((g == 2 or g >= 13) and 2 or 4)
    local gx, gy = cellXY(g, firstRow)
    gfx.text(tostring(g), gx, gy - 13, 9, "medium", "center", s)
  end
  for p = 1, 7 do
    local _, py = cellXY(1, p)
    gfx.text(tostring(p), ox - 18, py + s / 2 - 6, 9, "medium", "center", 12)
  end

  -- f-block placeholders in the main table and row labels
  for i, info in ipairs({{"57–71", "la"}, {"89–103", "ac"}}) do
    local px, py = cellXY(3, 5 + i)
    gfx.alpha((mode == 1 and filterCat and filterCat ~= info[2]) and 0.25 or 1)
    gfx.rect(px, py, s, s, 7, mix(theme.bg, CATCOL[info[2]], theme.dark and 0.16 or 0.10))
    gfx.color(alpha(CATCOL[info[2]], 0.6))
    gfx.rectLine(px, py, s, s, 7, 1)
    gfx.color(theme.text2)
    gfx.text(info[1], px, py + s / 2 - 7, 10, "semibold", "center", s)
    gfx.unalpha()
    local lx, ly = cellXY(1, 8 + i)
    gfx.color(theme.text2)
    gfx.text(TR(i == 1 and "lanthanides" or "actinides"), lx, ly + s / 2 - 8, 12, "semibold", "right", pitch * 2 - 10)
  end

  -- tile hit areas
  local newHover = nil
  for z = 1, #E do
    local inf = INFO[z]
    local x, y = cellXY(inf.col, inf.row)
    local hit = ui.hit("el" .. z, x, y, s, s)
    if hit.hovered then newHover = z end
    if hit.clicked then selectEl(z) end
    if hit.rightClicked then
      local zz = z
      selectEl(z, true)
      ui.contextMenu({
        {label = TR("copy_symbol"), id = 1, icon = "content_copy"},
        {label = TR("copy_name"), id = 2, icon = "content_copy"},
        "-",
        {label = TR("filter_category"), id = 3, icon = "filter_alt"},
      }, function(id)
        if id == 1 then sys.clipboard(E[zz][1])
        elseif id == 2 then sys.clipboard(nameOf(zz))
        elseif id == 3 then mode = 1; filterCat = E[zz][5]; save() end
      end)
    end
  end
  local _, _, _, hov = ui.mouse()
  hoverZ = hov and newHover or nil

  -- tiles: resting ones first, animated ones above, the selection on top
  for z = 1, #E do
    if anim[z].h < 0.02 and z ~= sel then
      local inf = INFO[z]
      local x, y = cellXY(inf.col, inf.row)
      drawTile(z, x, y, s)
    end
  end
  for z = 1, #E do
    if anim[z].h >= 0.02 and z ~= sel then
      local inf = INFO[z]
      local x, y = cellXY(inf.col, inf.row)
      drawTile(z, x, y, s)
    end
  end
  do
    local inf = INFO[sel]
    local x, y = cellXY(inf.col, inf.row)
    drawTile(sel, x, y, s)
  end

  -- detail card in the empty area above the transition metals (groups 3-12, periods 1-3)
  local cx, cy = cellXY(3, 1)
  drawCard(cx + 4, cy, pitch * 10 - gap - 8, pitch * 3 - gap - 14)

  -- search feedback
  if search ~= "" and not firstMatch() then
    local rx, ry = cellXY(13, 1)
    gfx.icon("search_off", rx + 14, ry + s / 2, 18, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_results"), rx + 28, ry + s / 2 - 8, 12, "medium")
  end

  -- legend / filters
  drawLegend(16, h - legendH + 4, w - 32)

  if pressFlag then editing = fieldHit; pressFlag = false; fieldHit = false end
end

function app.event(e)
  if e.type == "mousedown" then pressFlag = true end
  if e.type == "keydown" then
    if e.key == "escape" then
      if editing then editing = false; return end
      if search ~= "" then search = ""; refreshSearch()
      elseif filterCat or filterState then filterCat, filterState = nil, nil; save() end
      return
    end
    if editing then return end
    if e.key == "left" then navigate(-1, 0)
    elseif e.key == "right" then navigate(1, 0)
    elseif e.key == "up" then navigate(0, -1)
    elseif e.key == "down" then navigate(0, 1)
    elseif e.key == "tab" then mode = mode == 1 and 2 or 1; save()
    end
  end
end

function app.menu()
  return {
    {title = TR("menu_view"), items = {
      {label = TR("view_category"), id = 1, checked = mode == 1},
      {label = TR("view_state"), id = 2, checked = mode == 2},
      "-",
      {label = TR("reset_temp"), id = 3},
      {label = TR("clear_filters"), id = 4},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then mode = 1
  elseif id == 2 then mode = 2
  elseif id == 3 then temp = ROOM
  elseif id == 4 then filterCat, filterState, search = nil, nil, ""; refreshSearch() end
  save()
end

function app.close()
  save()
  return true
end

return app
