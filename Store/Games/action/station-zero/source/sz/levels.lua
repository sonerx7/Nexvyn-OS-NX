-- Station Zero: the four sections. One map cell is 2 x 2 m; row 1 is the far (north, -z) side.
--
-- Map legend
--   #  solid            V  solid; the wall next to it is a viewport onto space
--   .  floor            ,  floor grate
--   P  player start     X  exit to the next section (a bulkhead)
--   D  sliding door     L  door locked by a keycard (Logic: door_key)
--   S  shutter opened by the lever (Logic: lever, message "shutter")
--   G  gate held open by the pressure plate (Logic: pressure_plate, messages "gate_open" / "gate_close")
--   Q  power door: opens when the reactor is back (terminal puzzle "power")
--   Y  lockdown door: opens with the bridge code (terminal puzzle "code")
--   K  keycard          l  lever            p  pressure plate      T  terminal
--   H  log hologram (one digit of the bridge code)                 c  checkpoint (Logic: checkpoint_save)
--   o  cargo crates (cover)   w  workbench   b  bunk   k  locker   s  shelf   t  specimen tank
--   x  sparking panel   v  steam vent   R  reactor core (solid)   E  escape pod (solid)   W  security sentry (Logic: aim_fire)
--   n  control console (cover)
--
-- Drones: {path = {{col,row}, ...}, speed, armed}. They patrol the path (looping) and join the hunt on an alert
-- (Logic: guard_alert).
local L = {}

L[1] = {
  id = "hangar",
  music = "calm",
  map = {
    "######################################",
    "#VVVV############VVVVVVVVVVVVV########",
    "#b..k############.............#s...k##",
    "#.P..D...........o...o........S....K##",
    "#b..s############.............#....w##",
    "#################.o.....o.....########",
    "#################......l......#H...c##",
    "#################.o.......o...L.....X#",
    "#################..,......,...#.v...##",
    "######################################",
  },
  drones = {
    {path = {{19, 4}, {29, 4}, {29, 5}, {19, 5}}, speed = 2.0},
    {path = {{28, 9}, {20, 9}, {20, 7}, {28, 7}}, speed = 1.7},
  },
  rail = {  -- opening fly-through (cells, height in metres)
    {pos = {29.5, 8.6, 2.5}, look = {20, 5, 1.0}, fov = 62},
    {pos = {24, 4, 2.4}, look = {18, 8, 1.0}, fov = 60},
    {pos = {16, 4, 1.9}, look = {8, 4, 1.3}, fov = 56},
    {pos = {27.4, 4.4, 1.2}, look = {22, 4.6, 1.95}, fov = 46},  -- key art
  },
  objective = "obj_hangar",
  hero = {24, 8, -1.2},
}

L[2] = {
  id = "reactor",
  music = "calm",
  map = {
    "######################################",
    "#VVVVVV########VVVVVVVVVVVVVVVVV######",
    "#t....t########.................######",
    "#.....H########..W..............######",
    "#.P....D..p...G.................######",
    "#.....t########.......RRR.......######",
    "#t....t########.......RRR.......Q...X#",
    "###############.......RRR.......######",
    "###############.................######",
    "###############.T.............W.######",
    "###############..c..........v...######",
    "######################################",
  },
  drones = {
    {path = {{18, 4}, {30, 4}, {30, 10}, {19, 10}}, speed = 2.1},
    {path = {{30, 9}, {19, 9}, {19, 4}, {30, 4}}, speed = 1.8, armed = true},
  },
  rail = {
    {pos = {31, 10.5, 2.4}, look = {24, 7, 2.2}, fov = 62},
    {pos = {18, 3.6, 2.3}, look = {24, 7, 2.6}, fov = 60},
    {pos = {10, 5, 1.9}, look = {4, 5, 1.2}, fov = 56},
  },
  objective = "obj_reactor",
  hero = {20, 10, 2.2},
}

L[3] = {
  id = "bridge",
  music = "calm",
  map = {
    "######################################",
    "######VVVVVVVVVVVVVVVVVVVVVVVVVV######",
    "######..........................######",
    "######..w....T........H......w..######",
    "######..........................######",
    "######....nn..........nn........######",
    "######..........................######",
    "#.P..D..........................Y..X##",
    "######..........................######",
    "######...H....W..........c......######",
    "######################################",
  },
  drones = {
    {path = {{8, 7}, {31, 7}}, speed = 2.2},
    {path = {{12, 3}, {30, 3}, {30, 5}, {12, 5}}, speed = 1.9, armed = true},
    {path = {{30, 9}, {9, 9}}, speed = 2.0},
  },
  rail = {
    {pos = {10, 9.5, 2.2}, look = {26, 3, 1.6}, fov = 64},
    {pos = {30, 9.4, 2.3}, look = {16, 3, 1.6}, fov = 60},
    {pos = {5, 8, 1.9}, look = {2, 8, 1.2}, fov = 56},
    {pos = {19, 4.2, 1.7}, look = {19, 1, 1.2}, fov = 60},
  },
  objective = "obj_bridge",
  hero = {19, 8, 3.14},
}

L[4] = {
  id = "escape",
  music = "danger",
  alarm = true,
  countdown = 90,
  map = {
    "######################################",
    "#VVVV###########VVVVVVVVVVVVVVVVVVV###",
    "#....###########...................###",
    "#.P..D.........D......o.....o......###",
    "#....###########...................###",
    "################.....o.......o.....###",
    "################......v............###",
    "################........EEE........###",
    "################........EEE........###",
    "######################################",
  },
  drones = {
    {path = {{18, 3}, {34, 3}, {34, 7}, {18, 7}}, speed = 2.3, armed = true},
    {path = {{34, 9}, {18, 9}, {18, 5}, {34, 5}}, speed = 2.0},
    {path = {{20, 6}, {32, 6}}, speed = 2.4},
  },
  rail = {
    {pos = {20, 3.6, 2.4}, look = {26, 8.5, 1.2}, fov = 62},
    {pos = {34, 5, 2.3}, look = {26, 8.5, 1.5}, fov = 60},
    {pos = {10, 4, 1.9}, look = {3, 4, 1.2}, fov = 56},
  },
  objective = "obj_escape",
  hero = {22, 5, 2.5},
}

-- Sector 4: the maintenance ducts between the two doors come from the Game Engine level generator (sz/levels_gen.lua,
-- made by tools/stationzero_levels.py with ge_gen "maze"); they replace map rows 1-9, columns 7-15.
do
  local ok, gen = pcall(require, "sz.levels_gen")
  if ok and type(gen) == "table" and gen.ducts then
    local map = L[4].map
    for i, row in ipairs(gen.ducts) do
      local r = map[i]
      if r and #row == 9 then map[i] = r:sub(1, 6) .. row .. r:sub(16) end
    end
  end
end

return L
