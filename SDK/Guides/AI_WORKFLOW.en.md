# AI-assisted workflow: from generated assets and code to a console game (SDK 1.9)

**English** · [Türkçe](AI_WORKFLOW.tr.md)

AI tools can write code, generate 3D models, textures, sounds and key art. None of them knows Nexvyn OS or the
console's limits. This guide is the path from what they produce to a game that loads fast, looks right with the
NexGFX pbr renderer and passes the checks. It applies to any tool: chat assistants, coding assistants in an editor or
a terminal, local models, text-to-3D and image-to-3D generators, texture and material generators, and the usual 3D
programs (DCC tools) you clean the results up in.

## Contents

1. [What to expect from AI tools](#1-what-to-expect-from-ai-tools)
2. [Code with an AI assistant](#2-code-with-an-ai-assistant)
3. [3D models: from a generator to a console-ready file](#3-3d-models-from-a-generator-to-a-console-ready-file)
4. [Textures and PBR maps](#4-textures-and-pbr-maps)
5. [Glass, transparency and emission](#5-glass-transparency-and-emission)
6. [Into NexGFX: lights, shadows, reflections](#6-into-nexgfx-lights-shadows-reflections)
7. [Sound, icon and store pictures](#7-sound-icon-and-store-pictures)
8. [Rights and credits](#8-rights-and-credits)
9. [Checklist before you publish](#9-checklist-before-you-publish)

## 1. What to expect from AI tools

| Tool | Good at | Fix before use |
|---|---|---|
| Coding assistant | Whole apps from a clear prompt, ports between languages, fixing checker output | Invented functions, wrong index base, work inside `draw`, missing `TR()` keys |
| 3D model generator | A first version of props, characters and set pieces | Too many triangles, random scale and pivot, merged meshes, baked-in lighting, no clean UVs or skeleton |
| Texture / material generator | Tileable surfaces, PBR sets (colour, normal, roughness, height) | 2K-4K sizes, DirectX-style normals, shadows painted into the colour map |
| Image generator | Key art, title backgrounds, concept sheets | Text and logos that do not belong to you, style that copies someone else |
| Audio generator | Music beds, ambience | Loudness, loops that click, licence terms |

The rule of this guide: **the tool makes a first draft, you make it console-ready and check it.**

## 2. Code with an AI assistant

The SDK ships context packs and task prompts in [`SDK/AI`](../AI/README.md). They tell an assistant the real API,
the rules (3 s callbacks, 64 MB, 60 fps, `TR()`), the quality bar for games and the store format.

1. **Give the context once.** `SDK/AI/system-prompt.en.md` plus the language pack (`SDK/AI/languages/lua.en.md`,
   `javascript.en.md`, `python.en.md` or `c.en.md`). With a long context add the full
   [SDK reference](../Reference/SDK.en.md).
   - Chat assistants: add the files to a project or knowledge area, or paste them into the first message.
   - Coding assistants in an editor or a terminal: keep the files in your repository and name them in the
     assistant's instruction file (rules, memory or custom instructions), for example:

     ```text
     This repository is a Nexvyn OS app. Before writing code, read SDK/AI/system-prompt.en.md and
     SDK/AI/languages/lua.en.md. Use only functions listed there or in SDK/Reference/SDK.en.md.
     After every change run: python SDK/Tools/nxv/nxv.py check MyGame.nxvapp
     Before answering, go through SDK/AI/checklist.en.md.
     ```

   - Local models (7-14B): only the system prompt and one language pack, at least 8k context; prefer Lua or
     JavaScript and check every answer.
   - On the console: Studio's **Ask AI** panel uses the provider and key you set up in AI Chat; attach the file you
     ask about.
2. **Ask with a task prompt** from `SDK/AI/tasks/`: `make-3d-game` (models and the pbr renderer), `make-game`,
   `make-social-app` (feeds, photos, short video, chat), `make-utility`, `port-lua-to-js`, `add-language`,
   `store-listing`, `store-icon`. Fill in every `<...>`.
3. **Check, run, feed back.** Run `nxv check` (and the language checker), then run the app in Studio. Send any
   checker output or error message back with `SDK/AI/tasks/fix-lua-check.en.md`. Repeat until it is clean.
4. **Keep the look yours.** Ask for the art direction first (rule 11 of the system prompt) and reject a game that
   copies a sample's menus or colours.
5. **Same API in four languages.** Lua, JavaScript, Python and C share the SDK names, so a prompt that worked in Lua
   can be ported with `port-lua-to-js` or the language notes. Squirrel and Java are frozen at SDK 1.8.

Never give an assistant API keys, passwords or personal data, and never let it put such values into the code.

## 3. 3D models: from a generator to a console-ready file

Generated models need the same clean-up as any bought or scanned asset. Do it in a 3D program, then export.

### Step by step

| Step | What to do | Why |
|---|---|---|
| 1. Scale | 1 unit = 1 metre. A door is about 2 m, a person 1.7 m, a crate 0.6-1 m. Apply scale and rotation | `g3d` lights, shadow distances and `range` values are in metres |
| 2. Axes | +Y up, the model faces **+Z** (glTF exporters do this by default; FBX files are converted on load) | A model lying on its side or facing away is an export problem, not a code problem |
| 3. Pivot | At the base, in the middle (feet for characters, bottom centre for props) | `g3d.draw(model, x, 0, z)` then stands it on the ground |
| 4. Triangles | Decimate to the budget: hero 3 000-8 000, props 50-1 500, a whole level 20 000-50 000 | 30-60k triangles per frame at 60 fps |
| 5. Parts | Separate meshes only where they need their own material or movement; merge static props | Fewer draw calls |
| 6. UVs | One clean, non-overlapping UV set (unwrap again if the generator's UVs are scattered) | Normal and occlusion maps need it |
| 7. LOD | g3d has no automatic LOD. For big scenes export a second, lighter file (`tree_far.glb`) and pick it by distance in code | Far objects cost the same as near ones otherwise |
| 8. Materials | One material per surface type, with a clear name (`Glass`, `Wood_Oak`, `Metal_Frame`) | `g3d.material(model, {...}, "Glass")` changes one material by name |
| 9. Lighting | Remove lighting and shadows painted into the colour map; keep only albedo | The pbr renderer lights the scene; baked light looks wrong when it moves |
| 10. Animation | Rig, name the clips (`Idle`, `Run`, `Jump`), bake constraints and IK; 20-40 bones for a character | `model:play("Run")`; morph targets are not supported |
| 11. Export | glTF binary (`.glb`): +Y up, textures embedded, apply modifiers, animations as separate actions. Or `.fbx` with its texture folder next to it | `.glb` is the most reliable format |

### Check it in the game

Load the file once and print what arrived before you build anything around it:

```lua
g3d.loadModel("bundle:/models/hero.glb", function(m, err)
  if not m then print(err) return end
  local i = m:info()
  print(i.format, i.triangles, i.materials, i.textures, i.size.w, i.size.h, i.size.d, i.skinning)
  for _, a in ipairs(i.animations) do print(a.name, a.duration) end
end)
```

| You see | Fix |
|---|---|
| Tiny or huge | Apply scale in the 3D program, export in metres |
| Lying down or facing away | +Y up, facing +Z; apply rotation before export |
| Black or inside-out faces | Recalculate normals outward; mark thin surfaces (leaves, cloth) double-sided |
| Too shiny or plastic | The roughness map is inverted (it was a smoothness map): convert it (section 4) |
| Bumps lit from the wrong side | The normal map is DirectX style: flip its green channel (section 4) |
| Washed-out colours | The colour map was exported as linear data; export it as sRGB colour |
| Slow to load | Texture sizes: scale them to 1024 px or less (section 4) |

## 4. Textures and PBR maps

The pbr renderer uses the metallic-roughness model: base colour, normal, metallic, roughness, ambient occlusion and
emission.

| Map | Content | Size on the console |
|---|---|---|
| Base colour | sRGB colour, no lighting | 1024 px (hero, large surfaces), 512 px (props) |
| Normal | OpenGL style (green up), tangent space | 1024 px |
| ORM (glTF) | R = occlusion, G = roughness, B = metallic | 512 px |
| MetallicSmoothness (exported by some engines) | R = metallic, A = smoothness | 512 px |
| Separate AO / Metallic / Roughness | greyscale | 512 px |
| Emissive | colour of the glow | 512 px |

**glTF (`.glb`)** carries every map inside the file; your exporter writes the ORM texture. **FBX** links only some
maps; the renderer finds the rest next to the base colour map by name: `T_Chair_BaseColor.png` →
`T_Chair_Normal.png`, `T_Chair_AO.png`, `T_Chair_Metallic.png`, `T_Chair_Roughness.png` or
`T_Chair_MetallicSmoothness.png`, `T_Chair_Emissive.png`. Plain meshes take maps through `g3d.material`
(`normalMap`, `metalRoughMap`, `occlusionMap`, `metalSmoothMap`, `emissiveMap`).

The SDK's texture tool ([`SDK/Tools/textures`](../Tools/textures/README.md), Python with Pillow) does the usual
conversions:

```
python SDK/Tools/textures/textures.py check  models/textures                 sizes, sets, what is missing
python SDK/Tools/textures/textures.py resize models/textures --max 1024      scale 2K-4K maps down
python SDK/Tools/textures/textures.py orm  T_AO.png T_Roughness.png T_Metallic.png T_ORM.png
python SDK/Tools/textures/textures.py smoothness T_MetallicSmoothness.png T_Roughness.png --metallic T_Metallic.png
python SDK/Tools/textures/textures.py flipgreen T_Normal_DX.png T_Normal.png  DirectX -> OpenGL normal
```

Every map is loaded at full size into memory, and a 4096 px map costs 64 MB before mipmaps. Scale down before you
ship; the difference on a 720p screen is small.

Generated tileable surfaces (stone, wood, metal) work best on plain meshes with `mesh:setTexture` for the colour and
`g3d.material` for the other maps. Keep the texture's real-world size in mind: a 1024 px stone texture usually covers
1-2 m.

## 5. Glass, transparency and emission

| Effect | In the 3D program / file | In code |
|---|---|---|
| Cut-out (leaves, fences, grilles) | glTF alpha mode `MASK` with an alpha cutoff | nothing; with MSAA the edges are smooth (alpha to coverage) |
| See-through (smoke, holograms, thick tinted glass) | alpha mode `BLEND` | nothing; drawn after opaque objects, sorted back to front |
| Thin glass with refraction (windows, bottles, visors) | glTF `KHR_materials_transmission` (+ `ior`) | or `g3d.material(model, {transmission = 0.9, roughness = 0.05, ior = 1.5}, "Glass")` |
| Varnish, wet floors, car paint | glTF `KHR_materials_clearcoat` | or `{clearcoat = 0.6, clearcoatRoughness = 0.2}` |
| Lamps, screens, signs | emissive map or colour; `KHR_materials_emissive_strength` | `{emissive = "#3CC8FF", emissiveStrength = 4}`: above 1 it feeds the bloom |

Give glass its own material with a clear name, so you can change it in code without touching the rest of the model.

## 6. Into NexGFX: lights, shadows, reflections

```lua
function app.load()
  if g3d.renderer("pbr") ~= "pbr" then print("basic renderer: no lights or shadows") end
  g3d.shadows({quality = "medium", distance = 20})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.05})
  g3d.environment({cubemap = {"bundle:/sky/px.png", "bundle:/sky/nx.png", "bundle:/sky/py.png",
                              "bundle:/sky/ny.png", "bundle:/sky/pz.png", "bundle:/sky/nz.png"}})
  g3d.loadModel("bundle:/models/room.glb", function(m, err) room = m end)
  g3d.addLight({type = "spot", x = 0, y = 2.8, z = 0, dx = 0, dy = -1, dz = 0, color = "#FFE2B8",
                intensity = 20, range = 8, inner = 30, outer = 50, shadow = true})
end
```

- **Sun and sky.** `g3d.light` is the sun (direction to it, ambient, colour); `g3d.environment` gives the ambient
  light and reflections, from sky and ground colours or from a 6-face cube map.
- **Reflection probe.** Render the 6 faces of a cube map from the middle of your level in the 3D program (+X, -X, +Y,
  -Y, +Z, -Z, 256-512 px each) and pass them as `cubemap`. Shiny floors, metal and glass then reflect the real room.
  Real-time reflections (screen-space or planar) are not available.
- **Interior lights.** A few point or spot lights where the player looks; intensity 5-20 for rooms, `range` a little
  larger than the room. Each object takes the 8 strongest lights near it.
- **Shadows.** The sun and one spot light (`shadow = true`). If surfaces show stripes, raise `bias`; if shadows
  float, lower it.
- **Budget.** Start with `msaa = 0`, shadows `"medium"`, textures up to 1024 px; measure, then raise quality.

The [PBR, Lights and Shadows sample](../Samples/lua/pbr3d/) and the [recipes](RECIPES.en.md) show complete scenes.

## 7. Sound, icon and store pictures

- **Sound.** The `sfx` kit makes layered effects and music from recipes, no files needed
  ([Sound design](SOUND_DESIGN.en.md)). Generated audio files work with `audio.play` / `audio.music`; normalise
  their loudness and cut loops at zero crossings.
- **Store icon.** 256x256 key art of the game itself. Render your own model with the icon tool
  ([`SDK/Tools/icon`](../Tools/icon/README.md)) or use an image generator with
  [`SDK/AI/tasks/store-icon.en.md`](../AI/tasks/store-icon.en.md). The style is your choice; the default is clean
  (no text, restrained effects).
- **Screenshots.** Five recommended, with the interface in English, from the best moments of play
  ([publishing guide](../Publishing/PUBLISHING.en.md), section 6).

## 8. Rights and credits

- Use generators whose terms let you publish and sell what they make, and keep a note of the tool and the date.
- Do not prompt for other people's characters, brands, logos or a living artist's style.
- List generated and third-party assets with their source and licence in your store `README.md`. The review
  checklist asks for it.

## 9. Checklist before you publish

- [ ] Models: metres, +Y up, facing +Z, pivot at the base, within the triangle budget, named materials and clips.
- [ ] Textures: 1024 px or less, OpenGL normals, roughness (not smoothness), no lighting baked into the colour map.
- [ ] Glass and emission: own materials, transmission or alpha mode set, emission above 1 only where it should glow.
- [ ] `g3d.renderer("pbr")` checked, and the game also works on `"basic"`.
- [ ] Frame rate measured on the console with shadows, bloom and MSAA as shipped.
- [ ] Code passes `nxv check` and the language checker; every visible text goes through `TR()`.
- [ ] Rights and credits listed in the store README.

## See also

[Recipes](RECIPES.en.md) · [Make a game](MAKE_A_GAME.en.md) · [Make a social app](MAKE_A_SOCIAL_APP.en.md) ·
[Graphics, UI and game feel](GAME_FEEL.en.md) · [Sound design](SOUND_DESIGN.en.md) ·
[SDK versions](SDK_VERSIONS.en.md) · [SDK reference](../Reference/SDK.en.md) (8b *Modern rendering*)
