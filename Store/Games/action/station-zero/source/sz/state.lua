-- Station Zero: shared state of one run (every module reads and writes this table).
local S = {
  CELL = 2,           -- metres per map cell
  WALL_H = 3,         -- wall height
  -- palette (docs/games/stationzero_art.md)
  C = {
    void = "#05070C", metal = "#1B222B", steel = "#56636F", cyan = "#3FE6FF", red = "#FF2B3A", amber = "#FFB23F",
    core = "#BFF4FF", ink = "#0A1016", text = "#CFEFF5", dim = "#5C7C86",
  },
  quality = "",          -- "balanced" (handheld) or "high" (dock); chosen from the screen size each frame
  t = 0,                 -- seconds since the app started
  level = nil,           -- the running level (sz.world)
  levelIndex = 1,
  player = nil,
  vars = {},             -- Logic variables (key, ...)
  sent = {},             -- story messages sent in this level ("shutter", "power", "code"); replayed on a checkpoint load
  alarm = 0,             -- seconds of alarm left (0 = calm)
  alert = 0,             -- 0..1: the highest suspicion of any drone this frame (HUD bar, danger music)
  toast = nil,           -- {text, t}
  save = nil,            -- persistent progress (see main.lua)
}

function S.say(text, secs)
  S.toast = {text = text, t = secs or 3}
end

return S
