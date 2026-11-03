# AI-assisted workflow: models, textures and code for SDK 1.9

**English** · [Türkçe](AI_WORKFLOW.tr.md)

For developers who use AI tools to make 3D models, textures and code for Nexvyn OS. The first half takes an asset from
an AI generator or a DCC tool to a console-ready `.glb` (or `.fbx`) with PBR maps and into the pbr renderer. The second
half uses the AI kit in [SDK/AI](../AI/README.md) with coding assistants: what to send, how to iterate with the
checkers and how to review what comes back. The page ends with rights and a checklist.

Everything here describes the SDK as it is in the [SDK reference](../Reference/SDK.en.md) (8b *3D models* and *Modern
rendering*). AI tools invent functions, options and file conventions; the reference is the contract, and what is not
in it does not exist.

## Contents

1. [The pipeline](#1-the-pipeline)
2. [Model files](#2-model-files)
3. [Geometry: scale, axes, pivot, budgets](#3-geometry-scale-axes-pivot-budgets)
4. [Textures and PBR maps](#4-textures-and-pbr-maps)
5. [Names](#5-names)
6. [Into the pbr renderer](#6-into-the-pbr-renderer)
7. [Code with an AI assistant](#7-code-with-an-ai-assistant)
8. [Sound, icon and store pictures](#8-sound-icon-and-store-pictures)
9. [Rights and licences](#9-rights-and-licences)
10. [Checklist](#10-checklist)

## 1. The pipeline

| Step | Where | Result | Check |
|---|---|---|---|
| Make or generate the asset | an AI model or texture generator, a DCC tool | a mesh with UVs, maybe a rig and clips | the generator's terms allow publishing (section 9) |
| Clean it up | your DCC tool | real scale, +Y up, pivot at the base, transforms applied, triangle budget | section 3 |
| Texture it | DCC tool, texture tool, AI texture generator | base colour, normal, ORM (or metallic + roughness), emissive | section 4 |
| Export | your DCC tool | `.glb` with embedded textures (or `.fbx` + texture folder) | section 2 |
| Look at it on the console | the Model Bench program below | `model:info()`: size, triangles, materials, clips | section 6 |
| Write the game or app | you, or an assistant with the AI kit | a bundle that passes the checkers | section 7 |

### What to expect from AI tools

| Tool | Good at | Fix before use |
|---|---|---|
| Coding assistant | Whole apps from a clear prompt, ports between languages, fixing checker output | Invented functions, wrong index base, work inside `draw`, missing `TR()` keys |
| 3D model generator | A first version of props, characters and set pieces | Too many triangles, random scale and pivot, merged meshes, baked-in lighting, no clean UVs or skeleton |
| Texture / material generator | Tileable surfaces, PBR sets (colour, normal, roughness, height) | 2K-4K sizes, green-down (-Y) normals, shadows painted into the colour map |
| Image generator | Key art, title backgrounds, concept sheets | Text and logos that do not belong to you, style that copies someone else |
| Audio generator | Music beds, ambience | Loudness, loops that click, licence terms |

The rule of this guide: **the tool makes a first draft, you make it console-ready and check it.**

## 2. Model files

| Format | Use it for | Notes |
|---|---|---|
| **`.glb`** (binary glTF 2.0) | everything; the best choice | one file with meshes, node hierarchy, materials, embedded textures, skeleton and clips |
| `.gltf` + files | the same, unpacked | images next to the `.gltf`, as the file names them |
| `.fbx` (binary or text, 6.x / 7.x) | assets that only come as FBX | axes and units are converted on load; textures embedded or in files next to it (section 4) |
| `.obj` / `.stl` | static meshes | no animation, no PBR maps |

Limits per file: 96 MB, 1 000 000 vertices, 1 500 000 triangles, 20 000 nodes, 1024 bones per skeleton, 4 000 000
animation key values. A damaged or unsupported file only makes the load fail with a message; it never crashes the app.
Morph targets (blend shapes), cameras and lights in the file are ignored, and cubic spline keys play linearly: bake
shape animation, constraints and IK into skeletal clips, and light the scene in code.

## 3. Geometry: scale, axes, pivot, budgets

**Scale and axes.** 1 unit = 1 metre (a person is about 1.7 m). glTF is +Y up; the model looks along **+Z** in the
game. Apply scale and rotation before export, so the file has no leftover transforms. `g3d.model(path)` keeps the
authored size; `g3d.model(path, size)` scales the largest side to `size`, centres it in x and z and stands it on
y = 0. Fix a model that is huge, tiny or lying down in the export, not in code.

**Pivot.** At the base, in the middle: the model's origin is where it stands. For a door, put it on the hinge.

**AI-generated meshes** usually need work before they are usable: too many triangles, a messy or missing pivot,
lighting baked into the colour, no clean skeleton, overlapping UVs. Decimate or retopologise to the budget, set the
pivot, rig and name the clips in your DCC tool, and remove baked shadows from the base colour (the pbr renderer lights
the model in real time; ambient occlusion belongs in its own map).

**Budgets** (guidelines for 60 fps; measure on a console):

| | |
|---|---|
| Hero character | 3 000 - 8 000 triangles, 20 - 40 bones, 4 weights per vertex |
| Enemies, NPCs | 1 000 - 4 000 triangles |
| Props | 50 - 1 500 triangles |
| Whole frame | 30 000 - 60 000 triangles, about 150 draw calls (every mesh, material and 32-bone piece of a skeleton is one) |
| Skinned characters on screen | 8 - 16 (up to 32 bones per draw are skinned on the GPU) |

**Level of detail.** The SDK has no automatic LOD. When a prop is both detailed and far away a lot of the time, export
it twice (full detail and about a quarter of the triangles), load both and pick one by distance in your code, as the
Model Bench in section 6 does. Two loads of one file share the data, and for many copies of a prop draw each detail
level with one `g3d.drawInstanced` call. Fog that hides the far plane and a `far` value as small as the scene allows
also cut what is drawn.

## 4. Textures and PBR maps

**Sizes.** Powers of two. On the console: base colour and normal at 1024 px, the other maps at 512 px, 2048 px at most
(`g3d.caps().maxTextureSize` reports the limit). The console loads every map into memory at full size, so scale 4K
sets down before you ship. Maps add up quickly: keep a game's models and textures to tens of MB.

**The maps the pbr renderer reads:**

| Map | Content | Colour space | glTF slot | FBX |
|---|---|---|---|---|
| Base colour | albedo, no lighting baked in; alpha for cut-outs and glass | sRGB | `baseColorTexture` | linked base colour / diffuse map |
| Normal | tangent space, **OpenGL style (green up)** | data | `normalTexture` (with `scale`) | linked normal map |
| Metallic-roughness | roughness in **G**, metallic in **B** | data | `metallicRoughnessTexture` | separate metallic and roughness maps |
| Occlusion | ambient occlusion in **R** | data | `occlusionTexture` (with `strength`) | where the exporter writes it, or by file name |
| MetallicSmoothness | metallic in **R**, smoothness in **A** (smoothness = 1 - roughness) | data | (not a glTF slot) | by file name |
| Emissive | glowing parts | sRGB | `emissiveTexture` × `emissiveFactor` | linked emission map |

- **Normal maps** baked with the green-down convention (Y-) look lit from the wrong side: flip the green channel
  before export (many bakers and texture tools have an option for it). Tangents are computed from the texture
  coordinates, so the normal map needs clean UVs.
- **ORM packing.** glTF reads roughness from G and metallic from B of one image; put ambient occlusion in R of the same
  image and link it as the occlusion map too: one texture for three maps.
- **Maps of game engine texture sets** work as they are: an FBX whose material does not link a map takes it from an
  image file next to the base colour map, named like it. `T_Chair_BaseColor.png` finds `T_Chair_AO.png`,
  `T_Chair_Metallic.png`, `T_Chair_Roughness.png` or the pair `T_Chair_MetallicSmoothness.png` (metallic in R,
  smoothness in A). This works when the base colour map is an image file (not embedded in the FBX); the other files are
  looked for next to it and next to the model. Normal and emissive maps are not found by name: link them in the FBX
  material.
- **Embed or neighbour.** A `.glb` with embedded textures is one file that cannot lose its maps; prefer it. A `.gltf`
  or `.fbx` with a texture folder works when the folder is copied next to it, with the names the file uses.
- **Image files:** PNG for maps with exact values (normal, ORM, alpha), JPEG is fine for base colour without alpha.
- **AI-generated textures** often come as one picture with shadows and highlights painted in. Remove the lighting
  from the base colour, make tiling textures seamless, and derive normal and roughness maps in a texture tool; check
  the result on the console under a moving light.

**Emissive and bloom.** The glow strength is the emissive colour × `emissiveStrength` (glTF:
`KHR_materials_emissive_strength`). Above 1 it is brighter than the bloom threshold (`g3d.postfx` `threshold`, default
1) and glows into the bloom: screens, lamps, visors, cores.

**Transparency and glass** (glTF materials):

| What | How |
|---|---|
| Opaque | alpha mode `OPAQUE`: the texture's alpha is ignored |
| Cut-out (leaves, fences, grilles) | alpha mode `MASK` with an alpha cutoff; with MSAA the edges use alpha to coverage and look smooth |
| See-through (plastic, smoke, holograms) | alpha mode `BLEND`: drawn after the opaque scene, sorted back to front per object, premultiplied; the reflection keeps its strength and the surface gets more opaque at grazing angles |
| Thin glass that refracts | `KHR_materials_transmission` (factor) and `KHR_materials_ior`, or `g3d.material(model, {transmission = 0.9, roughness = 0.05, ior = 1.5}, "Glass")`; the scene behind shows through, tinted by the base colour and bent by the normal map |
| Varnish, car paint | `KHR_materials_clearcoat` (factors) or `clearcoat` / `clearcoatRoughness` in `g3d.material` |
| Double-sided | the material's double-sided flag; blended double-sided materials draw their far side first |

**Reflections** come from `g3d.environment`: the sky hemisphere, or a 6-face cube map (`+X −X +Y −Y +Z −Z`) that you
render in your DCC tool from a point of your level as a reflection probe. Screen-space reflections, planar mirrors and
probes captured at run time are not available.

## 5. Names

| Name | Why it matters |
|---|---|
| Clips: `Idle`, `Run`, `Jump`, `Attack` | `model:play("Run")` finds a clip by name, without case and without the armature prefix FBX exports add (`"Rig|Run"` matches `"run"`) |
| Bones and sockets: `hand_R`, `head`, `Muzzle` | `model:node(name)` and `model:nodeMatrix(name)` attach things and spawn effects there; a bone without vertices works as a socket |
| Materials: `Glass`, `Trim_Metal`, `Screen` | `g3d.material(model, options, name)` changes one material by name; clear names let code tune or swap them |
| Files: `prop_crate.glb`, `T_Crate_BaseColor.png` | one asset per file, texture names that follow the base colour name (section 4) |

## 6. Into the pbr renderer

Look at every model on the console before you build anything around it. The **Model Bench** below is a complete
program (it passed the Lua checker): put your files in `models/`, change the two paths, run it and read what
`model:info()` reports. It also shows the distance switch for two detail levels.

`app.json`:

```json
{
  "id": "com.yourname.modelbench",
  "name": {"en": "Model Bench"},
  "description": {"en": "Checks exported models under the pbr renderer"},
  "version": "1.0",
  "author": "Your Name",
  "category": "developer",
  "main": "main.lua",
  "window": {"width": 960, "height": 600, "resizable": true},
  "gamepad": true,
  "minSdk": "1.9",
  "targetSdk": "1.9",
  "permissions": []
}
```

`lang/en.json`:

```json
{
  "loading": "Loading {0}",
  "failed": "Could not load the model: {0}",
  "info": "{0} · {1} triangles · {2} materials · {3} textures · skinning: {4}",
  "size": "Size {0} x {1} x {2} m",
  "lod": "Distance {0} m · drawing {1} · renderer {2}",
  "near": "near",
  "far": "far"
}
```

`main.lua`:

```lua
-- Model Bench: look at an exported model under the pbr renderer before you build a game around it.
-- Copy your files into models/ and change the two paths. Left stick or arrow keys: orbit and zoom.
local app = {}

local MODEL = "bundle:/models/prop_lod0.glb"       -- full detail
local MODEL_FAR = "bundle:/models/prop_lod1.glb"   -- optional: the same prop with about a quarter of the triangles
local LOD_DISTANCE = 12                            -- metres: draw the far version beyond this

local near, far, info, err
local ground
local yaw, dist, active = 0.6, 6, "basic"
local held = {}

local function fmt(v) return string.format("%.2f", v) end

function app.load(arg)
  active = g3d.renderer("pbr")
  g3d.shadows({quality = "medium", distance = 20})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.05, threshold = 1.0})
  g3d.environment({sky = "#9DB8E8", ground = "#4A4038", intensity = 1.0, sun = 2.5})
  ground = g3d.mesh("plane", 20, 20, 4)
  ground:setColor("#7A7F86")
  g3d.material(ground, {roughness = 0.8})
  g3d.loadModel(MODEL, function(m, e)                -- no size: the model keeps its authored metres
    if not m then
      err = tostring(e)
      return
    end
    near, info = m, m:info()
    for _, a in ipairs(info.animations) do print("clip", a.name, a.duration) end
    if #info.animations > 0 then near:play(1) end
  end)
  g3d.loadModel(MODEL_FAR, function(m) far = m end)  -- stays nil when there is no far version
end

function app.update(dt)
  local x, y = input.stick("left")
  if held.left then x = -1 elseif held.right then x = 1 end
  if held.up then y = 1 elseif held.down then y = -1 end
  yaw = yaw + x * 1.5 * dt
  dist = math.max(1.5, math.min(40, dist - y * 8 * dt))
  if near then near:update(dt) end
end

function app.draw(w, h)
  gfx.clear("#20242C")
  local m = near
  if far and dist > LOD_DISTANCE then m = far end      -- a distance switch: the SDK has no automatic LOD
  g3d.begin(0, 0, w, h, 50, 0.05, 200)
  g3d.camera(math.sin(yaw) * dist, dist * 0.45, math.cos(yaw) * dist, 0, 0.8, 0)
  g3d.light(0.5, 0.8, 0.3, 0.35, "#FFF1DD")
  g3d.draw(ground, 0, 0, 0)
  if m then g3d.draw(m, 0, 0, 0) end
  g3d.finish()

  gfx.color("#FFFFFF")
  if err then
    gfx.wrap(TR("failed", err), 16, 16, w - 32, 14)
  elseif not info then
    gfx.text(TR("loading", MODEL), 16, 16, 14, "mono")
  else
    gfx.text(TR("info", info.format, info.triangles, info.materials, info.textures, info.skinning), 16, 16, 14, "mono")
    gfx.text(TR("size", fmt(info.size.w), fmt(info.size.h), fmt(info.size.d)), 16, 36, 14, "mono")
    local which = m == far and TR("far") or TR("near")
    gfx.text(TR("lod", fmt(dist), which, active), 16, 56, 14, "mono")
  end
end

function app.event(e)
  if e.type == "keydown" and e.key then held[e.key] = true
  elseif e.type == "keyup" and e.key then held[e.key] = nil end
end

return app
```

What to check: the size in metres (a person about 1.7 m tall), the triangle count against the budget, `skinning` is
`"gpu"` for a character, the clip names, and the look with the light moving around it (orbit). If the renderer line says
`basic`, the console has no pbr path (or the system setting is off); the model still draws with its base colour.

**The renderer settings** belong to the app; set them in `app.load` and change them when the scene changes:

| Call | Start with | Notes |
|---|---|---|
| `g3d.renderer("pbr")` | in `app.load` | returns `"pbr"` or `"basic"`; keep the game correct on both |
| `g3d.light(dx, dy, dz, ambient, color)` | every frame, between `begin` and `finish` | the sun: direction to it, ambient, colour |
| `g3d.shadows({quality, distance, bias})` | `"medium"`, distance = the visible play area | `"high"` costs more; one spot light may cast shadows too |
| `g3d.postfx({exposure, tonemap, bloom, threshold, msaa, hdr})` | `tonemap = "aces"` or `"filmic"`, `bloom` 0.03 - 0.1, `msaa = 0` | raise `msaa` only after measuring; `hdr = false` for simple scenes |
| `g3d.environment({sky, ground, intensity, sun, cubemap})` | hemisphere colours of your art direction | a cube map gives reflections and ambient from your sky |
| `g3d.addLight({type, x, y, z, color, intensity, range, ...})` → id | 2 - 6 point or spot lights near the action | move with `g3d.updateLight(id, {...})`; up to 16, the 8 strongest per object |
| `g3d.material(meshOrModel, options[, name])` | plain meshes: `{metallic, roughness}` | on a model it overrides only the given fields; `nil` goes back to the file's values |
| `g3d.drawInstanced(mesh, transforms)` | repeated props | 7 numbers per copy; up to 128 copies per GPU call |

A complete game that uses all of it: [PBR_GAME_RECIPE.en.md](PBR_GAME_RECIPE.en.md). Budgets and the art direction
method: [MAKE_A_GAME.en.md](MAKE_A_GAME.en.md), sections 10 and 11.

## 7. Code with an AI assistant

Assistants do not know this SDK. Without the kit in [SDK/AI](../AI/README.md) they write calls from other platforms
(`fetch`, `localStorage`, `io.open`, custom shaders) that do not exist here.

**What to send.**

| File | When |
|---|---|
| [system-prompt.en.md](../AI/system-prompt.en.md) | always: bundle layout, `app.json`, permissions, program structure, rules, the API in short |
| [languages/](../AI/languages/) `<language>.en.md` | always: the pack of your language (Lua, JavaScript, Python or C for new apps) |
| [tasks/](../AI/tasks/) | the task prompt: [make a 3D game](../AI/tasks/make-3d-game.en.md), [make a social app](../AI/tasks/make-social-app.en.md), [make a game](../AI/tasks/make-game.en.md), [make a utility](../AI/tasks/make-utility.en.md), [store icon](../AI/tasks/store-icon.en.md), ... |
| [checklist.en.md](../AI/checklist.en.md) | at the end of every request: "Before you answer, go through checklist.en.md" |
| [SDK.en.md](../Reference/SDK.en.md) and a guide | when the context is large enough: the whole reference, plus the guide of the task (this page, a recipe, [MAKE_A_GAME.en.md](MAKE_A_GAME.en.md)) |

Use one language for all of them (the `.en.md` or the `.tr.md` files). Fill the task prompt with facts, not wishes:
the app id, the language, your seven art direction decisions for a game, and for every model what the Model Bench
printed (size, triangles, clip names, sockets). For a server-backed app, give the real endpoints and JSON.

**Iterate with the checkers.**

1. Put the answer into a bundle and run `python SDK/Tools/nxv/nxv.py check <bundle>`: manifest, permissions used but
   not declared, translations (`TR()` keys in `lang/en.json`), the icon, file limits ([Tools/nxv](../Tools/nxv/README.md)).
2. With `--sdk <Nexvyn OS source checkout>` the same command also runs the official checker of the language
   (`lua_check.py`, `js_check.mjs`, `py_check.py`, `rt_check.py`), which compiles every file and plays the app for
   hundreds of frames against a mock SDK with random input. The store maintainer runs these checkers on every
   submission.
3. When a check fails, send the whole output and the named files back with
   [tasks/fix-lua-check.en.md](../AI/tasks/fix-lua-check.en.md). Do not ask the assistant to skip a check.
4. Run it on the console. The checkers use a mock SDK; the real test is the console (`nxv push`).

**Review what comes back.** Read the code against the reference before you run it:

- Every function, option and field exists in [SDK.en.md](../Reference/SDK.en.md); options are spelled as there
  (`emissiveStrength`, not `emissive_strength`; `"filmic"`, not `"reinhard"`).
- The language rules hold: indexes (Lua 1-based, the others 0-based), several results (Lua returns, JavaScript arrays,
  Python tuples, C pointers), Promises with `try` / `catch` in JavaScript, callbacks in Python, JSON option text in C.
- `minSdk` / `targetSdk` match what the code uses (`"1.9"` for the pbr renderer and section 8d), and `permissions`
  lists exactly what the code needs.
- No callback can come near 3 seconds: models load with `g3d.loadModel`, long work is split across frames.
- A game draws its own menus and HUD in its own style (no `ui.*` widgets, no `theme` colours, no copied sample
  layout); an app uses `theme` and `ui`.
- Every visible text goes through `TR()` with English in `lang/en.json`.

**Never put API keys in an app.** Anyone can unzip a `.nxvapp`. Keys, client secrets and passwords stay on your server;
the app signs in (`net.oauth`) or talks to your server, which holds the keys. Do not paste keys into prompts either,
and do not let an assistant write them into code "for testing". The store rejects apps that collect API keys or
passwords. Studio's **Ask AI** panel uses the keys the user entered in AI Chat on the console; they stay there.

## 8. Sound, icon and store pictures

- **Sound.** The `sfx` kit makes layered effects and music from recipes, no files needed
  ([Sound design](SOUND_DESIGN.en.md)). Generated audio files work with `audio.play` / `audio.music`; normalise
  their loudness and cut loops at zero crossings.
- **Store icon.** 256x256 key art of the game itself. Render your own model with the icon tool
  ([`SDK/Tools/icon`](../Tools/icon/README.md)) or use an image generator with
  [`SDK/AI/tasks/store-icon.en.md`](../AI/tasks/store-icon.en.md). The style is your choice; the default is clean
  (no text, restrained effects).
- **Screenshots.** Five recommended, with the interface in English, from the best moments of play
  ([publishing guide](../Publishing/PUBLISHING.en.md), section 6).

## 9. Rights and licences

You are responsible for every asset and every line of code you publish, including what an AI tool made.

- Use generators whose terms let you publish their output (commercially, if you sell or might), and keep a note of the
  tool, the date and its terms for each asset.
- Do not generate other games' or brands' characters, logos or trademarks, and do not feed a generator material you
  do not have the rights to.
- AI-written code is yours to check: it may reproduce code under a licence. Keep what you cannot vouch for out.
- The App Market accepts an item only when you own it or have a licence that allows publishing, and lists third-party
  parts with their licences in the README ([Publishing/PUBLISHING.en.md](../Publishing/PUBLISHING.en.md), section 8;
  [review checklist](../Publishing/REVIEW.en.md), section 4). Write the generator terms there too.

## 10. Checklist

**Assets**

- [ ] `.glb` with embedded textures (or `.fbx` with its texture folder next to it); within the file limits
- [ ] Metres, +Y up, facing +Z, pivot at the base, transforms applied
- [ ] Triangles and bones within the budget; a second detail level only where it pays off
- [ ] No lighting baked into the base colour; AO in its own map (or in R of the ORM image)
- [ ] Normal maps +Y (green up); ORM = occlusion R, roughness G, metallic B; MetallicSmoothness = metallic R, smoothness A
- [ ] Textures power of two, 1024 px for base colour and normal, 512 px for the rest, 2048 px at most
- [ ] Emissive above 1 only where it should bloom; glass with transmission, cut-outs with `MASK`
- [ ] Clips, sockets and materials named; morph targets, cameras and lights baked or removed
- [ ] Checked on the console with the Model Bench: size, triangles, `skinning`, clips, the look under a moving light

**Code**

- [ ] The AI kit sent: system prompt, language pack, task prompt, checklist (and the reference when it fits)
- [ ] `nxv check` passes (with `--sdk` when you have a checkout); every call reviewed against the reference
- [ ] `g3d.renderer("pbr")` in `app.load`, and the game correct on `"basic"`
- [ ] `minSdk` / `targetSdk` and `permissions` right; English text complete in `lang/en.json`
- [ ] No API keys, secrets or passwords in the bundle
- [ ] Tested on a console

**Rights**

- [ ] Every generator's terms allow publishing; tool, date and terms noted
- [ ] Third-party and generated parts listed with their licences in the store README

## See also

[AI kit](../AI/README.md) · [SDK reference](../Reference/SDK.en.md) · [PBR game recipe](PBR_GAME_RECIPE.en.md) ·
[Social app recipe](SOCIAL_APP_RECIPE.en.md) · [Make a game](MAKE_A_GAME.en.md) · [SDK versions](SDK_VERSIONS.en.md) ·
[Tools/nxv](../Tools/nxv/README.md) · [Publishing](../Publishing/PUBLISHING.en.md)
