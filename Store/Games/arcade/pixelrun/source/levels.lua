-- Pixel Koşu levels. Each level is built on a character grid that becomes ASCII rows for
-- game.tilemap.fromStrings (see LEGEND in main.lua):
--   # ground   S stone   B brick   = one-way platform   ^ spikes   b bush   f flower
--   o coin     h heart   e walker  v flyer   c checkpoint   G goal   P player start
-- Rows are 15 tall; the ground top is usually row 12. Jump reach: about 3 tiles up, 4 tiles across.

local H = 15

local Builder = {}
Builder.__index = Builder

local function new(w)
  local g = {}
  for y = 0, H - 1 do
    g[y] = {}
    for x = 0, w - 1 do g[y][x] = "." end
  end
  return setmetatable({g = g, w = w}, Builder)
end

function Builder:put(x, y, ch) if x >= 0 and x < self.w and y >= 0 and y < H then self.g[y][x] = ch end end
function Builder:fill(x0, y0, x1, y1, ch) for y = y0, y1 do for x = x0, x1 do self:put(x, y, ch) end end end
function Builder:ground(x0, x1, top) self:fill(x0, top or 12, x1, H - 1, "#") end
function Builder:plat(x, y, len) self:fill(x, y, x + len - 1, y, "=") end
function Builder:coins(x, y, n, step) for i = 0, n - 1 do self:put(x + i * (step or 1), y, "o") end end
function Builder:rows()
  local out = {}
  for y = 0, H - 1 do out[y + 1] = table.concat(self.g[y], "", 0, self.w - 1) end
  return out
end

local L = {}

-- 1: meadow, teaches running, jumping, coins, stomping
L[1] = {name = "level1", sky = {"#7EC8F8", "#D8F0FF"}, hills = {"#8FD3A0", "#5FB878"}, build = function()
  local b = new(118)
  b:ground(0, 24)
  b:put(2, 11, "P")
  b:coins(6, 10, 3, 2)
  b:put(4, 11, "b"); b:put(12, 11, "f")
  b:plat(14, 9, 5); b:coins(15, 8, 3)
  b:put(21, 11, "e")
  b:ground(28, 46)
  b:fill(32, 11, 33, 11, "S"); b:fill(34, 10, 35, 11, "S")
  b:coins(34, 8, 2)
  b:put(39, 11, "e"); b:put(30, 11, "f")
  b:fill(43, 11, 44, 11, "^")
  b:put(48, 11, "c")
  b:ground(47, 61)
  b:plat(51, 8, 5); b:coins(52, 7, 3)
  b:put(58, 7, "v"); b:put(55, 11, "b")
  b:ground(65, 81)
  b:fill(68, 8, 72, 8, "B"); b:coins(68, 7, 5)
  b:put(76, 11, "e"); b:put(66, 11, "f")
  b:ground(82, 91, 11); b:coins(84, 9, 4, 2)
  b:ground(92, 117)
  b:put(96, 11, "e"); b:put(102, 11, "e"); b:put(99, 6, "h"); b:plat(97, 7, 5)
  b:put(108, 11, "b")
  b:put(112, 11, "G")
  return b:rows()
end}

-- 2: cave with a ceiling, one-way platforms, spikes and flyers
L[2] = {name = "level2", sky = {"#2B2F4A", "#4B4F78"}, hills = {"#3A3E62", "#2E3254"}, build = function()
  local b = new(132)
  b:fill(0, 0, 131, 1, "S")
  b:ground(0, 18)
  b:put(2, 11, "P")
  b:coins(5, 10, 4, 2)
  b:fill(14, 10, 15, 11, "S")
  b:put(10, 11, "e")
  b:plat(20, 9, 4); b:coins(20, 8, 4)
  b:ground(26, 40)
  b:fill(30, 11, 32, 11, "^")
  b:plat(29, 8, 5); b:coins(30, 7, 3)
  b:put(36, 11, "e")
  b:fill(38, 9, 40, 11, "S")
  b:put(44, 6, "v")
  b:ground(43, 52)
  b:put(46, 11, "c")
  b:plat(55, 10, 3); b:plat(60, 8, 3); b:plat(65, 10, 3); b:coins(60, 7, 3)
  b:fill(55, 13, 67, 14, "^")
  b:ground(70, 88)
  b:fill(74, 9, 79, 9, "B"); b:coins(74, 8, 6)
  b:put(77, 11, "e"); b:put(84, 11, "e")
  b:put(81, 5, "v")
  b:fill(86, 10, 88, 11, "S")
  b:ground(91, 104, 10); b:put(93, 9, "c")
  b:coins(96, 8, 4, 2); b:put(101, 9, "e")
  b:plat(106, 9, 4); b:put(108, 4, "h")
  b:ground(112, 131)
  b:fill(114, 11, 115, 11, "^")
  b:put(120, 11, "e"); b:put(118, 6, "v")
  b:put(127, 11, "G")
  return b:rows()
end}

-- 3: castle walls of brick, longer gaps, mixed enemies
L[3] = {name = "level3", sky = {"#F6A86B", "#FDE3B8"}, hills = {"#C98B6B", "#A86B58"}, build = function()
  local b = new(146)
  b:ground(0, 14)
  b:put(2, 11, "P")
  b:fill(8, 9, 9, 11, "B"); b:coins(8, 8, 2)
  b:put(12, 11, "e")
  b:ground(18, 30); b:fill(18, 10, 19, 11, "B")
  b:coins(22, 9, 4, 2); b:put(27, 11, "e"); b:put(24, 7, "v")
  b:plat(33, 10, 3)
  b:ground(38, 52)
  b:fill(42, 11, 45, 11, "^"); b:plat(42, 8, 4); b:coins(42, 7, 4)
  b:put(49, 11, "e")
  b:put(40, 11, "c")
  b:fill(52, 9, 53, 11, "B")
  b:ground(56, 70, 11)
  b:put(60, 10, "e"); b:put(66, 10, "e"); b:coins(58, 8, 6, 2)
  b:put(64, 5, "v")
  b:plat(73, 9, 3); b:plat(78, 7, 3); b:plat(83, 9, 3); b:coins(78, 6, 3)
  b:put(80, 3, "v")
  b:ground(88, 104)
  b:put(90, 11, "c")
  b:fill(94, 10, 96, 11, "B"); b:fill(97, 8, 99, 11, "B"); b:coins(97, 6, 3)
  b:put(102, 11, "e")
  b:fill(100, 11, 101, 11, "^")
  b:plat(107, 9, 4); b:put(109, 5, "h")
  b:ground(113, 145)
  b:fill(116, 11, 117, 11, "^"); b:put(121, 11, "e"); b:put(126, 11, "e"); b:put(124, 6, "v")
  b:fill(130, 10, 131, 11, "B"); b:coins(133, 9, 4, 2)
  b:put(140, 11, "G")
  return b:rows()
end}

return L
