-- fx.lua: effect level of Frost Lantern ("Atmosphere" in the settings).
-- Frost Lantern is 2D pixel art drawn with gfx, so it does not use the SDK 1.9 pbr renderer. The level only drives
-- the added sound layers, ambience beds and impact shake: 1 = Low (the 1.3.0 sound, no extra shake),
-- 2 = Medium (default: layered sound, ambience, shake), 3 = High (same, stronger shake).
local F = {level = 2}
function F.setup(level) F.level = math.max(1, math.min(3, math.floor(tonumber(level) or 2))) end
function F.active() return false end
return F
