-- fx.lua: the ONLY file of this game that sets up the SDK 1.9 modern renderer (needs minSdk 1.9).
-- F.pbr is true when g3d.renderer("pbr") really returned "pbr" (the OS falls back to "basic" on GPUs without GLES 3).
-- When it is false, or Effects is Low, every helper below does nothing and the game draws as before.
-- Effects level (options.fx): 1 Low = basic renderer, 2 Medium = lights + bloom + one 1024 px shadow (the room's key
--   light), 3 High = 2048 px shadows (the flashlight casts them while it is on) + 4x MSAA.
-- F.area(values) changes the per-area mood (exposure, bloom, threshold, shadow distance) on top of the game profile;
-- the renderer settings are only sent again when a value really changed.
local F = {pbr = false, level = 2, profile = {}, areaValues = {}, slots = {}}
local mats = setmetatable({}, {__mode = "k"})   -- mesh/model -> PBR options, re-applied when Effects goes up again
local sent = nil                                 -- last postfx/shadow key sent to the renderer

local function value(k, default)
  local v = F.areaValues[k]
  if v == nil then v = F.profile[k] end
  if v == nil then v = default end
  return v
end

local function applyPost(force)
  local high = F.level >= 3
  local exposure, bloom, threshold = value("exposure", 1), value("bloom", .05), value("threshold", 1)
  local distance = value("shadowDistance", 24)
  local key = string.format("%d|%.3f|%.3f|%.3f|%.1f", F.level, exposure, bloom, threshold, distance)
  if key == sent and not force then return end
  sent = key
  g3d.shadows({enabled = true, quality = high and "medium" or "low", distance = high and distance or math.min(distance, 18)})
  g3d.postfx({exposure = exposure, tonemap = value("tonemap", "aces"), bloom = bloom * (high and 1.25 or 1),
    threshold = threshold, msaa = high and 4 or 0})
end

local function apply()
  applyPost(true)
  if F.env then g3d.environment(F.env) end
  for mesh, o in pairs(mats) do g3d.material(mesh, o) end
end

function F.setup(level, profile)
  F.level = math.max(1, math.min(3, math.floor(tonumber(level) or 2)))
  if profile then F.profile = profile end
  if F.level <= 1 then
    if F.pbr then
      g3d.clearLights(); F.slots = {}
      for mesh in pairs(mats) do g3d.material(mesh, nil) end
    end
    F.pbr = false; sent = nil; g3d.renderer("basic"); return
  end
  F.pbr = g3d.renderer("pbr") == "pbr"
  if F.pbr then apply() end
end

function F.active() return F.pbr end

-- Per-area mood: {exposure, bloom, threshold, shadowDistance}; nil fields fall back to the game profile.
function F.area(values)
  F.areaValues = values or {}
  if F.pbr then applyPost(false) end
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

-- Material of a mesh or model handle. Callers build `opts` once per model kind and pass the same table for every
-- handle (model overrides are stored per handle by the OS, so each handle needs this one call).
function F.material(mesh, opts)
  if not mesh then return end
  mats[mesh] = opts
  if F.pbr then g3d.material(mesh, opts) end
end

return F
