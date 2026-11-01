-- missions.lua: Banners of Aldmoor's units, terrain and the eight campaign battles.
local M = {}

-- terrain: move cost (nil = impassable), defence bonus, heal per turn
M.TERRAIN = {
  ["."] = {key = "grass", cost = 1, def = 0},
  ["="] = {key = "road", cost = 1, def = 0},
  f = {key = "forest", cost = 2, def = 0.2},
  h = {key = "hill", cost = 2, def = 0.15, range = 1},
  ["~"] = {key = "water"},
  ["^"] = {key = "mountain"},
  v = {key = "village", cost = 1, def = 0.1, heal = 3},
  c = {key = "castle", cost = 1, def = 0.3, heal = 4},
  b = {key = "bridge", cost = 1, def = 0},
}

-- classes: hp, attack, defence, move, min/max range, growth per level
M.CLASSES = {
  lord = {hp = 25, atk = 8, def = 5, mov = 5, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 1}},
  knight = {hp = 20, atk = 7, def = 4, mov = 4, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 1}},
  spear = {hp = 19, atk = 7, def = 3, mov = 4, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 1}, vsRider = 1.6},
  archer = {hp = 15, atk = 6, def = 1, mov = 4, r0 = 2, r1 = 3, grow = {hp = 1, atk = 1, def = 0}},
  rider = {hp = 19, atk = 7, def = 2, mov = 6, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 0}, rider = true},
  mage = {hp = 13, atk = 8, def = 1, mov = 4, r0 = 1, r1 = 2, grow = {hp = 1, atk = 2, def = 0}, magic = true},
  cleric = {hp = 13, atk = 2, def = 1, mov = 4, r0 = 1, r1 = 1, grow = {hp = 1, atk = 1, def = 1}, heal = 7},
  brute = {hp = 26, atk = 9, def = 2, mov = 3, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 0}},
  warlord = {hp = 36, atk = 10, def = 5, mov = 4, r0 = 1, r1 = 1, grow = {hp = 2, atk = 1, def = 1}, boss = true},
}

-- the company: who they are and when they join
M.HEROES = {
  {id = "maren", class = "lord", join = 1},
  {id = "brand", class = "spear", join = 1},
  {id = "lysa", class = "archer", join = 1},
  {id = "corin", class = "cleric", join = 2},
  {id = "tobin", class = "rider", join = 3},
  {id = "ilse", class = "mage", join = 5},
}

-- enemy letters in the unit layer
M.ELETTER = {k = "knight", s = "spear", a = "archer", r = "rider", m = "mage", b = "brute", W = "warlord", c = "cleric"}

-- missions: terrain rows (14 x 9), unit rows ("1".."6" = deployment slots, letters = enemies), objective
M.MISSIONS = {
  {key = "m1", goal = "rout", level = 1,
   map = {"..f......f....", ".fff...h......", "..f..=====....", ".....=...=.ff.", "=====v...=..f.", ".....=...====.",
          "..h..=.......f", ".hh..=..ff....", "........f....."},
   units = {"..............", "...........k..", "..............", "1..........s..", "2.........a...", "3.............",
            "..............", "..............", ".............."}},
  {key = "m2", goal = "rout", level = 2,
   map = {"......f..~~...", ".v....ff.~~...", ".....=====b===", ".=====...~~..f", ".=..h....~~.ff", ".=..hh...~~...",
          ".====...b~~...", "....=====b====", "........~~...."},
   units = {"..............", "1.............", "2...........k.", "3..........a..", "4..........s..", "............b.",
            "............r.", "..............", ".............."}},
  {key = "m3", goal = "seize", level = 3, seize = {12, 4},
   map = {"^^^.....~~..^^", "^......f~~...^", "..ff....~~.h..", "..f..===bb===.", "=====.......cc", "..h..===bb===.",
          "..hh....~~....", "^.......~~..f^", "^^^.....~~..^^"},
   units = {"..............", "..........a...", "............s.", "1..........k..", "2...........k.", "3..........a..",
            "4.............", ".5..........r.", ".............."}},
  {key = "m4", goal = "survive", level = 4, turns = 6,
   map = {"ffffff..ffffff", "ff.ff....ff.ff", "f..f..vv..f..f", "...ff.cc.ff...", "......cc......", "...ff....ff...",
          "f..f......f..f", "ff.ff....ff.ff", "ffffff..ffffff"},
   units = {"r......s.....r", "..............", "..............", "a....1..2....a", ".....3..4.....", ".....5........",
            "..............", "..............", "s.....k......b"}},
  {key = "m5", goal = "boss", level = 5,
   map = {"......^^^.....", "..ff..^c^..h..", ".fff..=c=..hh.", "......=.=.....", "======...=====", ".....=...=....",
          ".hh..=...=.ff.", ".h...=...=.f..", ".....=====...."},
   units = {"..............", ".......W......", "......a.a.....", ".......k......", "1..........s..", "2....b...b....",
            "3.........a...", "4.............", "56............"}},
  {key = "m6", goal = "rout", level = 6,
   map = {"..hhh....hhh..", ".hh^h....h^hh.", "..hhh....hhh..", "......==......", "=====......===", "......==......",
          "..fff....fff..", ".ff~ff..ff~ff.", "..fff....fff.."},
   units = {"..a........a..", "..............", "...m......m...", "..............", "1.........k...", "2...........r.",
            "3.....b.......", "4.......s.....", "56............"}},
  {key = "m7", goal = "seize", level = 7, seize = {12, 4},
   map = {"^^......^^^^^^", "^...ff...~~~c^", "...fff...~cc..", "=====.===bc...", "....=.=...cc..", "....=.===bc...",
          "...hh....~cc..", "^...hh...~~~c^", "^^......^^^^^^"},
   units = {"..............", "............a.", "...........k..", "1.......s..m..", "2.......b...W.", "3.......s..m..",
            "4..........k..", ".5..........a.", "..6..........."}},
  {key = "m8", goal = "boss", level = 8,
   map = {"cc..........cc", "cc..ff..ff..cc", "....f....f....", "..===.cc.===..", "..=...cc...=..", "..===.cc.===..",
          "....f....f....", "cc..ff..ff..cc", "cc..........cc"},
   units = {"a............a", "..............", "1....k...m....", "2...r..W..r...", "3....s...b....", "4....k...m....",
            "5.............", "6.............", "a............a"}},
}

return M
