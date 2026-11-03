-- fx.lua: the ONLY file of this game that sets up the SDK 1.9 modern renderer (needs minSdk 1.9).
-- F.pbr is true when g3d.renderer("pbr") really returned "pbr" (the OS falls back to "basic" on GPUs without GLES 3).
-- When it is false, or Effects is Low, every helper below does nothing and the game draws as before.
-- Effects level (options.fx): 1 Low = basic renderer, 2 Medium = lights + bloom (+ one small sun shadow),
--   3 High = 2048 px shadows + 4x MSAA + glass transmission on crystals and lamp glass (the "hi" options).
-- A material is set once per mesh (not per draw); F.mood() changes exposure / bloom per world.
local F = {pbr = false, level = 2, profile = {}, slots = {}}
local mats = setmetatable({}, {__mode = "k"})   -- mesh -> {options, high-only options}, re-applied when Effects changes

local function post()
  local p, high = F.profile, F.level >= 3
  g3d.shadows({enabled = high or p.mediumShadow == true, quality = high and "medium" or "low", distance = p.shadowDistance or 28})
  g3d.postfx({exposure = p.exposure or 1, tonemap = p.tonemap or "aces", bloom = (p.bloom or .05) * (high and 1.3 or 1),
    threshold = p.threshold or 1, msaa = high and 4 or 0})
end

local function put(mesh, o, hi)
  if hi and F.level >= 3 then
    local m = {}
    for k, v in pairs(o) do m[k] = v end
    for k, v in pairs(hi) do m[k] = v end
    g3d.material(mesh, m)
  else
    g3d.material(mesh, o)
  end
end

local function apply()
  post()
  if F.env then g3d.environment(F.env) end
  for mesh, e in pairs(mats) do put(mesh, e[1], e[2]) end
end

function F.setup(level, profile)
  F.level = math.max(1, math.min(3, math.floor(tonumber(level) or 2)))
  if profile then F.profile = profile end
  if F.level <= 1 then
    if F.pbr then
      g3d.clearLights(); F.slots = {}
      for mesh in pairs(mats) do g3d.material(mesh, nil) end
    end
    F.pbr = false; g3d.renderer("basic"); return
  end
  F.pbr = g3d.renderer("pbr") == "pbr"
  if F.pbr then apply() end
end

function F.active() return F.pbr end

-- Mood of the current world: exposure / bloom / threshold / tonemap / shadowDistance override the profile.
function F.mood(m)
  for k, v in pairs(m) do F.profile[k] = v end
  if F.pbr then post() end
end

-- Sets a light by name (created on first use, then updated); opts as g3d.addLight. nil removes it.
function F.light(name, opts)
  if not F.pbr then return end
  local id = F.slots[name]
  if opts == nil then
    if id then g3d.removeLight(id); F.slots[name] = nil end
    return
  end
  if id and g3d.updateLight(id, opts) == false then id = nil end
  if not id then F.slots[name] = g3d.addLight(opts) end
end

function F.environment(opts)
  F.env = opts
  if F.pbr then g3d.environment(opts) end
end

-- opts: PBR values; hi: extra values applied only at Effects High (e.g. transmission).
function F.material(mesh, opts, hi)
  if not mesh then return end
  mats[mesh] = {opts, hi}
  if F.pbr then put(mesh, opts, hi) end
end

return F
