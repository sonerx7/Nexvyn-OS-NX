-- Isle Defense: game data (towers, raiders, waves, islands). Numbers only; no drawing here.
local D = {}

-- ------------------------------------------------------------------ towers
-- dmg per hit, rate in shots per second, range in metres; up = upgrade costs to tier 2 and 3.
-- kind "phys" is reduced by armour, "magic" is not. air = can hit flyers.
D.TOWERS = {
  {id = "archer", icon = "my_location", color = "#3E8E41", cost = 70, up = {65, 120}, kind = "phys", air = true,
   dmg = {12, 20, 32}, rate = {1.3, 1.55, 1.9}, range = {10, 11, 12.5}},
  {id = "cannon", icon = "brightness_1", color = "#5B6470", cost = 110, up = {95, 165}, kind = "phys", air = false,
   dmg = {34, 56, 92}, rate = {0.55, 0.6, 0.66}, range = {9.5, 10.5, 11.5}, splash = {2.2, 2.6, 3.0}},
  {id = "frost", icon = "ac_unit", color = "#3AA7D8", cost = 85, up = {70, 125}, kind = "magic", air = true,
   dmg = {5, 9, 14}, rate = {1.1, 1.2, 1.3}, range = {8.5, 9.5, 10.5}, slow = {0.4, 0.5, 0.62}, slowT = 2.0, splash = {0, 1.2, 1.8}},
  {id = "storm", icon = "bolt", color = "#8E5BD8", cost = 140, up = {110, 180}, kind = "magic", air = true,
   dmg = {28, 42, 64}, rate = {0.7, 0.8, 0.95}, range = {10, 11, 12}, chain = {3, 4, 6}},
}
D.TOWER = {}
for i, t in ipairs(D.TOWERS) do t.index = i; D.TOWER[t.id] = t end
D.SELL = 0.7

-- ------------------------------------------------------------------ raiders
-- hp at wave 1 on the first island; speed m/s; armour reduces "phys" damage by that share; lives taken at the heart.
D.FOES = {
  raider = {model = "raider", base = "hero", hp = 55, speed = 2.2, gold = 5, lives = 1, scale = 1.15, icon = "person", color = "#6DBF4B"},
  scuttler = {model = "scuttler", base = "creature", hp = 30, speed = 4.0, gold = 3, lives = 1, scale = 1.4, icon = "pest_control", color = "#E8622C"},
  wasp = {model = "wasp", base = "drone", hp = 60, speed = 2.8, gold = 7, lives = 1, scale = 0.95, air = true, icon = "flight", color = "#F2C230"},
  brute = {model = "brute", base = "hero", hp = 300, speed = 1.35, gold = 16, lives = 2, scale = 1.75, icon = "fitness_center", color = "#8C7FB0"},
  ironclad = {model = "ironclad", base = "hero", hp = 150, speed = 1.9, gold = 11, lives = 1, scale = 1.25, armor = 0.6, icon = "shield", color = "#AEB8C4"},
}
D.FOE_ORDER = {"raider", "scuttler", "wasp", "brute", "ironclad"}

-- ------------------------------------------------------------------ islands
-- light: sun direction (towards the sun), colour, ambient; sky / ground for the hemisphere; fog colour and range.
D.ISLES = {
  {id = "isle1", file = "isles.isle1", name = "isle1_name", gold = 250, hpMul = 1.0,
   sun = {-0.55, 0.42, 0.62}, sunColor = "#FFD9A0", ambient = 0.42, sky = "#9ED8FF", ground = "#7FA860", sunI = 2.6,
   fog = {"#CDEBF0", 110, 520}, water = "#22C3D6", deep = "#0F7FB0", clear = "#BFE6F2", horizon = "#D8EEF0",
   decor = "beach", music = "calm"},
}

-- ------------------------------------------------------------------ waves
-- Each wave: list of groups {foe, count, gap seconds, start delay seconds}. 15 waves per island.
local function W(...) return {...} end
local function G(foe, n, gap, at) return {foe = foe, n = n, gap = gap or 1.0, at = at or 0} end
D.WAVES = {
  { -- Sunspray Cove
    W(G("raider", 8, 1.3)),
    W(G("raider", 10, 1.0), G("scuttler", 5, 0.7, 8)),
    W(G("scuttler", 12, 0.55), G("raider", 6, 1.0, 4)),
    W(G("raider", 8, 1.0), G("wasp", 6, 1.3, 6)),
    W(G("ironclad", 5, 1.8), G("raider", 10, 0.8, 3)),
    W(G("brute", 2, 4.0), G("raider", 12, 0.7, 2), G("scuttler", 8, 0.5, 10)),
    W(G("wasp", 10, 0.9), G("ironclad", 5, 1.5, 5)),
    W(G("brute", 4, 2.6), G("scuttler", 16, 0.4, 3), G("wasp", 6, 1.0, 9)),
    W(G("ironclad", 10, 1.0), G("wasp", 10, 0.7, 5), G("raider", 14, 0.5, 8)),
    W(G("brute", 8, 1.6), G("ironclad", 8, 1.1, 4), G("wasp", 12, 0.6, 8), G("scuttler", 20, 0.3, 12)),
  },
}

-- hp multiplier of a wave on an island
function D.hpScale(isle, wave)
  return D.ISLES[isle].hpMul * (1 + 0.095 * (wave - 1) + 0.004 * (wave - 1) ^ 2)
end

-- stars for the lives left (of 20)
function D.stars(lives)
  if lives >= 18 then return 3 elseif lives >= 10 then return 2 elseif lives > 0 then return 1 end
  return 0
end
D.LIVES = 20
D.EARLY_BONUS = 3     -- gold per second left on the clock when the next wave is called early
D.BREAK = 14          -- seconds between waves

return D
