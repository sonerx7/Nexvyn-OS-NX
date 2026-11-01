-- levels.lua: Lanternfall's level pieces. A level is a row of handmade chunks (20 x 18 tiles of 20 units); every
-- chunk starts and ends on ground rows 15-17 (or a plateau that you drop down from), so they join in any order.
--   .  empty   #  ground   =  one-way ledge   ^  spikes   c  crumbling block   j  spring
--   o  ember   *  star shard   S  shrine (save point)   E  exit   P  start   A  ability altar   B  boss
--   e  ground enemy   f  flyer   t  shooter (the world decides which creature it is)
local L = {}

local G3 = {"####################", "####################", "####################"}
local function chunk(top) -- 15 rows on top of the ground
  local rows = {}
  for i = 1, 15 do rows[i] = top[i] or "...................." end
  for i = 1, 3 do rows[15 + i] = G3[i] end
  return rows
end
local function full(rows) return rows end
local E = "...................."

L.CHUNKS = {
  start = chunk({E, E, E, E, E, E, E, E, E, E, E, "............o.o.....", "...........======...", E, "..P.....o.o........."}),
  walk = chunk({E, E, E, E, E, E, E, E, E, E, ".......o.o.o........", E, E, E, "...........e........"}),
  steps = chunk({E, E, E, E, E, E, ".................*..", "................==..", "..............o.....", ".............====...",
                 E, ".........====.......", ".......o............", ".....====...........", "...o................"}),
  pillars = chunk({E, E, E, E, E, E, E, E, E, ".........*..........", ".....o...==....o....", E, E, "....###..e...###....",
                   "....###......###...."}),
  flyers = chunk({E, E, E, E, E, E, "...........*........", "..........===.......", ".....f........f.....", E, E,
                  "..o.........o.......", E, ".........#####......", "........#######....."}),
  shooter = chunk({E, E, E, E, E, E, E, E, E, "..............t.....", ".............=====..", E, E, E,
                   "....o..o..o........."}),
  spring = chunk({E, E, E, "..........*.........", ".........====.......", "..........o.........", E, E, E, E, E, E,
                  "..........o.........", E, "......j............."}),
  shrine = chunk({E, E, E, E, E, E, E, E, E, E, E, E, E, ".....o.......o......", "..........S........."}),
  altar = chunk({E, E, E, E, E, E, E, E, E, E, E, "........o.o.........", E, E, "..........A........."}),
  exit = chunk({E, E, E, E, E, E, E, E, E, E, E, E, "..o.o.o.............", E, "...............E...."}),
  gap = full({E, E, E, E, E, E, E, E, E, E, E, "....o.....o.........", E, ".........o..........", E,
              "#######....#########", "#######....#########", "#######^^^^#########"}),
  spikepit = full({E, E, E, E, E, E, E, E, E, E, "........o.o.........", E, "........===.........", E, E,
                   "######.......#######", "######.......#######", "######^^^^^^^#######"}),
  crumble = full({E, E, E, E, E, E, E, E, E, E, E, ".....o..o..o..o.....", E, E, E,
                  "####cccccccccccc####", "####............####", "####^^^^^^^^^^^^####"}),
  -- needs the double jump: a five-tile wall
  dj = full({E, E, E, E, E, "..............*.....", E, E, "........o...........", ".........o..........",
             "..........##########", "..........##########", "..........##########", "..........##########",
             "..........##########", "####################", "####################", "####################"}),
  -- needs the dash: a seven-tile gap
  dash = full({E, E, E, E, E, E, E, E, "..........*.........", E, E, ".......o...o........", E, E, E,
               "######.......#######", "######.......#######", "######^^^^^^^#######"}),
  -- needs the wall jump: a shaft between two walls up to a plateau
  wall = full({E, E, E, ".......##...........", ".......##...o.o..*..", ".......##..#########", ".......##..#########",
               ".......##..#########", ".......##..#########", ".......##..#########", ".......##..#########",
               ".......##..#########", ".......##..#########", "...........#########", "..o........#########",
               "####################", "####################", "####################"}),
}
-- a boss arena is one screen wide with walls at both ends
L.ARENA = {
  "################################", "#..............................#", "#..............................#",
  "#..............................#", "#..............................#", "#..............................#",
  "#..............................#", "#..............................#", "#..............................#",
  "#..............................#", "#....=====..............=====..#", "#..............................#",
  "#..............................#", "#..............................#", "#..P...........B...............#",
  "################################", "################################", "################################",
}

L.WORLDS = {
  {key = "hollow", walker = "slime", flyer = "bat", shooter = "sprout", boss = "bramble"},
  {key = "caverns", walker = "crawler", flyer = "moth", shooter = "prism", boss = "golem", dark = true},
  {key = "ruins", walker = "guard", flyer = "wisp", shooter = "cannon", boss = "owl"},
}

-- levels: world, chunk list, ability granted by an altar in it
L.LEVELS = {
  {w = 1, chunks = {"start", "walk", "steps", "gap", "shrine", "pillars", "flyers", "spring", "walk", "exit"}},
  {w = 1, chunks = {"start", "gap", "crumble", "shooter", "shrine", "steps", "altar", "dj", "flyers", "pillars", "exit"}, ability = "double"},
  {w = 1, chunks = {"start", "dj", "spikepit", "pillars", "shrine", "crumble", "spring", "shooter", "dj", "gap", "exit"}},
  {w = 1, boss = true},
  {w = 2, chunks = {"start", "walk", "spikepit", "dj", "shrine", "shooter", "crumble", "flyers", "steps", "exit"}},
  {w = 2, chunks = {"start", "steps", "gap", "shrine", "altar", "dash", "pillars", "dash", "spring", "exit"}, ability = "dash"},
  {w = 2, chunks = {"start", "dash", "dj", "shrine", "crumble", "spikepit", "flyers", "dash", "shooter", "exit"}},
  {w = 2, boss = true},
  {w = 3, chunks = {"start", "flyers", "altar", "wall", "shrine", "gap", "dash", "steps", "exit"}, ability = "wall"},
  {w = 3, chunks = {"start", "wall", "dj", "shrine", "crumble", "dash", "wall", "shooter", "spikepit", "exit"}},
  {w = 3, chunks = {"start", "dash", "wall", "spikepit", "shrine", "dj", "crumble", "wall", "flyers", "dash", "exit"}},
  {w = 3, boss = true},
}

-- the rows of level n, with exactly three star shards (extra ones become embers)
function L.rows(n)
  local lv = L.LEVELS[n]
  if lv.boss then return L.ARENA end
  local rows = {}
  for r = 1, 18 do rows[r] = {} end
  for _, key in ipairs(lv.chunks) do
    local c = L.CHUNKS[key]
    for r = 1, 18 do rows[r][#rows[r] + 1] = c[r] end
  end
  local out = {}
  for r = 1, 18 do out[r] = table.concat(rows[r]) end
  -- shards: keep three, spread out; make embers into shards when a level has too few
  local spots = {}
  for r = 1, 18 do
    for x = 1, #out[r] do if out[r]:sub(x, x) == "*" then spots[#spots + 1] = {r, x} end end
  end
  local keep = {}
  if #spots >= 3 then
    keep[1], keep[2], keep[3] = spots[1], spots[(#spots + 1) // 2], spots[#spots]
  end
  local function put(r, x, ch) out[r] = out[r]:sub(1, x - 1) .. ch .. out[r]:sub(x + 1) end
  for _, s in ipairs(spots) do put(s[1], s[2], "o") end
  if #keep < 3 then
    local embers = {}
    for r = 1, 18 do
      for x = 1, #out[r] do if out[r]:sub(x, x) == "o" then embers[#embers + 1] = {r, x} end end
    end
    keep = {embers[3], embers[(#embers + 1) // 2], embers[#embers - 2]}
  end
  for _, s in ipairs(keep) do if s then put(s[1], s[2], "*") end end
  return out
end

return L
