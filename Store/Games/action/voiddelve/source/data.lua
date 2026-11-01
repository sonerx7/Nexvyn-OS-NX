-- data.lua: Void Delve's relics, enemies, room shapes and permanent upgrades.
local D = {}

-- relics: picked from three cards; `apply(p)` changes the player's stats (p.s)
D.RELICS = {
  {id = "twin", icon = "call_split", rare = 2, apply = function(p) p.s.shots = p.s.shots + 1; p.s.spread = math.max(p.s.spread, 0.16) end},
  {id = "ember", icon = "local_fire_department", rare = 1, apply = function(p) p.s.dmg = p.s.dmg * 1.25 end},
  {id = "rapid", icon = "speed", rare = 1, apply = function(p) p.s.rate = p.s.rate * 1.22 end},
  {id = "ricochet", icon = "replay", rare = 2, apply = function(p) p.s.bounce = p.s.bounce + 1 end},
  {id = "pierce", icon = "arrow_forward", rare = 2, apply = function(p) p.s.pierce = p.s.pierce + 1 end},
  {id = "seeker", icon = "my_location", rare = 3, apply = function(p) p.s.homing = p.s.homing + 2.2 end},
  {id = "heart", icon = "favorite", rare = 1, apply = function(p) p.maxHp = p.maxHp + 1; p.hp = math.min(p.maxHp, p.hp + 2) end},
  {id = "boots", icon = "directions_run", rare = 1, apply = function(p) p.s.speed = p.s.speed * 1.12 end},
  {id = "crit", icon = "flare", rare = 2, apply = function(p) p.s.crit = p.s.crit + 0.15 end},
  {id = "drone", icon = "satellite_alt", rare = 3, apply = function(p) p.s.drones = p.s.drones + 1 end},
  {id = "shrapnel", icon = "grain", rare = 2, apply = function(p) p.s.shrapnel = p.s.shrapnel + 3 end},
  {id = "big", icon = "circle", rare = 1, apply = function(p) p.s.size = p.s.size * 1.35; p.s.dmg = p.s.dmg * 1.3; p.s.rate = p.s.rate * 0.88 end},
  {id = "glass", icon = "diamond", rare = 2, apply = function(p) p.s.dmg = p.s.dmg * 1.5; p.maxHp = math.max(1, p.maxHp - 1); p.hp = math.min(p.hp, p.maxHp) end},
  {id = "magnet", icon = "attractions", rare = 1, apply = function(p) p.s.magnet = p.s.magnet + 70; p.s.shardK = p.s.shardK + 0.25 end},
  {id = "nova", icon = "brightness_7", rare = 1, apply = function(p) p.bombs = p.bombs + 2 end},
  {id = "chain", icon = "bolt", rare = 3, apply = function(p) p.s.chain = p.s.chain + 2 end},
  {id = "frost", icon = "ac_unit", rare = 2, apply = function(p) p.s.slow = p.s.slow + 0.35 end},
  {id = "phase", icon = "blur_on", rare = 2, apply = function(p) p.s.dashCd = p.s.dashCd * 0.7; p.s.dashHit = p.s.dashHit + 2 end},
  {id = "vamp", icon = "water_drop", rare = 3, apply = function(p) p.s.vamp = p.s.vamp + 1 end},
  {id = "range", icon = "open_in_full", rare = 1, apply = function(p) p.s.range = p.s.range * 1.3; p.s.bspeed = p.s.bspeed * 1.15 end},
  {id = "overcharge", icon = "battery_charging_full", rare = 2, apply = function(p) p.s.over = p.s.over + 1 end},
  {id = "angel", icon = "self_improvement", rare = 3, apply = function(p) p.revive = p.revive + 1 end},
}
D.RELIC = {}
for _, r in ipairs(D.RELICS) do D.RELIC[r.id] = r end

-- enemies: hp, speed, radius, colour, contact damage, shards dropped, score
D.ENEMIES = {
  wisp = {hp = 3, speed = 95, r = 9, col = "#FF4D8D", dmg = 1, shards = 1, score = 10},
  spitter = {hp = 6, speed = 45, r = 11, col = "#FFB020", dmg = 1, shards = 2, score = 25},
  brute = {hp = 22, speed = 40, r = 17, col = "#FF5A36", dmg = 1, shards = 4, score = 60},
  splitter = {hp = 9, speed = 60, r = 14, col = "#3DDC97", dmg = 1, shards = 2, score = 30},
  mini = {hp = 2, speed = 120, r = 7, col = "#7CFFB2", dmg = 1, shards = 0, score = 5},
  orbiter = {hp = 7, speed = 80, r = 10, col = "#5CC8FF", dmg = 1, shards = 2, score = 35},
  bomber = {hp = 4, speed = 130, r = 10, col = "#FFE14D", dmg = 1, shards = 1, score = 20},
  sentinel = {hp = 14, speed = 0, r = 14, col = "#B98CFF", dmg = 1, shards = 3, score = 50},
  phantom = {hp = 8, speed = 70, r = 11, col = "#E3E8FF", dmg = 1, shards = 3, score = 45},
}
-- which enemies each floor sends
D.FLOOR_POOL = {
  {"wisp", "wisp", "spitter", "splitter", "bomber"},
  {"wisp", "spitter", "brute", "splitter", "orbiter", "bomber", "sentinel"},
  {"spitter", "brute", "orbiter", "bomber", "sentinel", "phantom", "splitter"},
}
D.BOSSES = {"warden", "maw", "heart"}

-- room interiors: 13 x 7 cells, "#" block, "." floor
D.ROOMS = {
  {".............", ".............", ".............", ".............", ".............", ".............", "............."},
  {".............", "..#.......#..", ".............", "......#......", ".............", "..#.......#..", "............."},
  {".............", ".##.......##.", ".............", ".............", ".............", ".##.......##.", "............."},
  {".............", ".....###.....", ".............", "..#.......#..", ".............", ".....###.....", "............."},
  {".............", "...#.....#...", "...#.....#...", ".............", "...#.....#...", "...#.....#...", "............."},
  {".............", ".............", "....#####....", ".............", "....#####....", ".............", "............."},
  {"#...........#", ".............", "...#.....#...", ".............", "...#.....#...", ".............", "#...........#"},
  {".............", ".#.#.....#.#.", ".............", ".............", ".............", ".#.#.....#.#.", "............."},
  {".............", ".............", "..##.....##..", "..#.......#..", "..##.....##..", ".............", "............."},
  {".............", "......#......", "......#......", "..#.......#..", "......#......", "......#......", "............."},
}

-- permanent upgrades bought with void essence in the Sanctum
D.META = {
  {id = "vitality", icon = "favorite", max = 3, cost = {30, 70, 140}},
  {id = "power", icon = "local_fire_department", max = 5, cost = {20, 45, 80, 130, 200}},
  {id = "agility", icon = "directions_run", max = 3, cost = {25, 60, 120}},
  {id = "fortune", icon = "diamond", max = 3, cost = {25, 60, 120}},
  {id = "relic", icon = "auto_awesome", max = 1, cost = {150}},
  {id = "arsenal", icon = "brightness_7", max = 2, cost = {35, 90}},
}

return D
