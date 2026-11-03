# Recipes: a PBR 3D game and a social app (SDK 1.9)

**English** · [Türkçe](RECIPES.tr.md)

Two complete, small apps built step by step on what SDK 1.9 added: the NexGFX **pbr renderer** and the **feed, picture
and network** functions. Each recipe ends with the whole program in Lua and in JavaScript; both versions pass the SDK
checkers (`lua_check.py`, `js_check.mjs`) and use only functions from the [SDK reference](../Reference/SDK.en.md). Python
and C notes follow each recipe.

Use the recipes as a starting point, by hand or with an AI assistant ([AI-assisted workflow](AI_WORKFLOW.en.md)). For
the full background read [Make a game](MAKE_A_GAME.en.md) and [Make a social app](MAKE_A_SOCIAL_APP.en.md).

## Contents

1. [Recipe 1: Shard Garden, a PBR 3D game](#recipe-1-shard-garden-a-pbr-3d-game)
2. [Recipe 2: Photo Board, a social feed](#recipe-2-photo-board-a-social-feed)
3. [Checking and running](#checking-and-running)
4. [Where to go next](#where-to-go-next)

## Recipe 1: Shard Garden, a PBR 3D game

A lantern orb moves through a stone courtyard at dusk and collects glowing shards. It is about 120 lines and shows
every part of a PBR scene: renderer settings, materials on plain meshes, a model with its own maps, lights with ids,
shadows, bloom, instancing and a HUD drawn in the game's own style.

### Step 1: the project

```
ShardGarden.nxvapp/
  app.json
  main.lua            (or main.js)
  lang/en.json        required
  lang/tr.json        optional, one file per extra language
  models/crate.glb    any .glb with PBR maps; the pbr3d sample ships one (CC0)
```

`app.json`:

```json
{
  "id": "com.example.shardgarden",
  "name": {"en": "Shard Garden"},
  "description": {"en": "Collect glowing shards in a courtyard at dusk"},
  "version": "1.0", "author": "You",
  "category": "games", "main": "main.lua",
  "minSdk": "1.9", "targetSdk": "1.9",
  "gamepad": true,
  "window": {"width": 960, "height": 600, "minWidth": 480, "minHeight": 320, "resizable": true},
  "permissions": []
}
```

`lang/en.json`:

```json
{"score": "Shards: {0}", "best": "Best: {0}", "renderer": "Renderer: {0}"}
```

### Step 2: decide the look first

Write the art direction at the top of `main.lua` before any code: feeling, palette, light, HUD style. Two games made
from this recipe must not look alike; change the palette, the light colours, the exposure and the bloom for yours
([Graphics, UI and game feel](GAME_FEEL.en.md)).

### Step 3: turn on the renderer in `app.load`

```lua
renderer = g3d.renderer("pbr")      -- "pbr", or "basic" when the console offers no OpenGL ES 3
g3d.shadows({quality = "medium", distance = 22})
g3d.postfx({exposure = 0.9, tonemap = "aces", bloom = 0.08})
g3d.environment({sky = "#3B4C7A", ground = "#1E1B24", intensity = 0.8, sun = 1.2})
```

Renderer settings belong to the app and stay until you change them. Always keep the game playable when
`g3d.renderer` returns `"basic"`: the same calls still draw, without lights, shadows and post effects.

### Step 4: materials

Plain meshes get PBR values with `g3d.material`. A model loaded from `.glb` or `.fbx` already carries its maps
(base colour, normal, metallic-roughness or ORM, occlusion, emissive), so it needs nothing.

| Surface | Material |
|---|---|
| Wet stone floor | `{roughness = 0.35, clearcoat = 0.6, clearcoatRoughness = 0.2}` |
| Painted stone | `{roughness = 0.7}` |
| Polished metal | `{metallic = 1, roughness = 0.15}` |
| Glowing parts | `{emissive = "#3CC8FF", emissiveStrength = 6}`: above 1 they feed the bloom |
| Thin glass | `{transmission = 0.9, roughness = 0.05, ior = 1.5}` |

### Step 5: lights with ids

`g3d.light` is the sun. Up to 16 more lights come from `g3d.addLight`, which returns an id; move them every frame
with `g3d.updateLight` (only the fields you give change). Each object is lit by the 8 strongest lights near it, and
one spot light with `shadow = true` casts shadows next to the sun.

### Step 6: repeated objects

Pillars, grass, crates and debris go through `g3d.drawInstanced(mesh, transforms)`: 7 numbers per copy (`x, y, z,
rx, ry, rz, scale`). On the pbr renderer up to 128 copies are one GPU call.

### Step 7: measure on the console

The pbr renderer costs GPU time. Start with `msaa = 0`, shadows `"medium"` and textures up to 1024 px, show the fps
and the triangle count while you build, and raise quality only while the frame rate holds.

### The whole game in Lua

```lua
-- Shard Garden: a small 3D game on the SDK 1.9 pbr renderer (recipe in SDK/Guides/RECIPES.en.md).
-- Art direction: a stone courtyard at dusk. Cold blue sky light, a warm lantern that follows the player,
-- cyan shards that glow into the bloom. Palette: #0B0D14 night, #3B4C7A dusk, #FF9A3C lantern, #3CC8FF shard,
-- #FFD9A8 text. HUD: bold warm numbers, no widgets.
local app = {}

local floor, pillar, orb, shard, crate
local pillars = {}            -- g3d.drawInstanced transforms: x, y, z, rx, ry, rz, scale per pillar
local shards = {}
local keys = {}
local lamp, moon
local px, pz, vx, vz = 0, 0, 0, 0
local score, best, t = 0, 0, 0
local renderer = "basic"

local function placeShard(s)
  local a = math.random() * math.pi * 2
  local r = 2 + math.random() * 7
  s.x, s.z = math.cos(a) * r, math.sin(a) * r
end

function app.load()
  math.randomseed(os.time())
  best = store.get("best", 0)

  -- 1. the renderer and its settings (they stay until changed)
  renderer = g3d.renderer("pbr")                -- "basic" when the console offers no OpenGL ES 3
  g3d.shadows({quality = "medium", distance = 22})
  g3d.postfx({exposure = 0.9, tonemap = "aces", bloom = 0.08})
  g3d.environment({sky = "#3B4C7A", ground = "#1E1B24", intensity = 0.8, sun = 1.2})

  -- 2. materials on plain meshes
  floor = g3d.mesh("plane", 24, 24, 1)
  floor:setColor("#5A5F6B")
  g3d.material(floor, {roughness = 0.35, clearcoat = 0.6, clearcoatRoughness = 0.2})   -- wet stone
  pillar = g3d.mesh("cylinder", 0.35, 3, 20)
  pillar:setColor("#C9C1B4")
  g3d.material(pillar, {roughness = 0.7})
  for i = 0, 15 do
    local a = i / 16 * math.pi * 2
    for _, v in ipairs({math.cos(a) * 11, 1.5, math.sin(a) * 11, 0, 0, 0, 1}) do pillars[#pillars + 1] = v end
  end
  orb = g3d.mesh("sphere", 0.4, 32, 20)
  orb:setColor("#FFB45C")
  g3d.material(orb, {emissive = "#FF9A3C", emissiveStrength = 4, roughness = 0.3})
  shard = g3d.mesh("cone", 0.25, 0.7, 6)
  shard:setColor("#7FE8FF")
  g3d.material(shard, {emissive = "#3CC8FF", emissiveStrength = 6, metallic = 0.2, roughness = 0.2})
  for i = 1, 6 do shards[i] = {}; placeShard(shards[i]) end

  -- 3. a model with its own PBR maps, loaded in the background
  g3d.loadModel("bundle:/models/crate.glb", 1.2, function(m, err)
    if m then crate = m else print("crate: " .. tostring(err)) end
  end)

  -- 4. lights with ids: the lantern follows the player, the moon spot casts shadows
  lamp = g3d.addLight({type = "point", color = "#FF9A3C", intensity = 10, range = 7})
  moon = g3d.addLight({type = "spot", x = 0, y = 9, z = 0, dx = 0, dy = -1, dz = 0, color = "#9FB8FF",
                       intensity = 30, range = 16, inner = 25, outer = 40, shadow = true})
end

function app.event(e)
  local name = e.key or e.pad
  if not name then return end
  if e.type == "keydown" or e.type == "paddown" then keys[name] = true
  elseif e.type == "keyup" or e.type == "padup" then keys[name] = false end
end

function app.update(dt)
  dt = math.min(dt, 1 / 20)
  t = t + dt
  local sx, sy = input.stick("left")
  local ix = sx + ((keys.right and 1 or 0) - (keys.left and 1 or 0))
  local iz = -sy + ((keys.down and 1 or 0) - (keys.up and 1 or 0))
  local k = math.min(1, dt * 6)
  vx, vz = vx + (ix * 9 - vx) * k, vz + (iz * 9 - vz) * k
  px = math.max(-9.5, math.min(9.5, px + vx * dt))
  pz = math.max(-9.5, math.min(9.5, pz + vz * dt))
  g3d.updateLight(lamp, {x = px, y = 1.4, z = pz})
  for _, s in ipairs(shards) do
    if (s.x - px) ^ 2 + (s.z - pz) ^ 2 < 0.8 then
      score = score + 1
      audio.play("pop", 0.6)
      if score > best then best = score; store.set("best", best) end
      placeShard(s)
    end
  end
end

function app.draw(w, h)
  gfx.gradient(0, 0, w, h, "#1B2238", "#0B0D14")
  g3d.begin(0, 0, w, h, 55, 0.1, 80)
  g3d.camera(px * 0.4, 9, pz * 0.4 + 13, px * 0.6, 0, pz * 0.6)
  g3d.light(-0.4, 0.7, -0.5, 0.25, "#8FA6FF")    -- a low cold sun: direction to it, ambient, colour
  g3d.fog("#0B0D14", 18, 40)
  g3d.draw(floor, 0, 0, 0)
  g3d.drawInstanced(pillar, pillars)             -- 16 pillars, one GPU call on the pbr renderer
  if crate then
    g3d.draw(crate, -3, 0, -4, 0, 0.4, 0)
    g3d.draw(crate, 4, 0, 2, 0, -0.7, 0)
  end
  for _, s in ipairs(shards) do
    g3d.draw(shard, s.x, 0.6 + math.sin(t * 3 + s.x) * 0.15, s.z, 0, t * 2, 0)
  end
  g3d.draw(orb, px, 0.45, pz)
  g3d.finish()

  gfx.color("#FFD9A8")
  gfx.text(TR("score", score), 24, 18, 28, "bold")
  gfx.color("#9FB8FF")
  gfx.text(TR("best", best), 24, 54, 15, "semibold")
  gfx.color("#FFFFFF80")
  gfx.text(TR("renderer", renderer), w - 224, h - 30, 13, "mono", "right", 200)
end

function app.suspend() store.save() end

return app
```

### The whole game in JavaScript

The same program: options are objects, `input.stick` returns an array, `g3d.loadModel` returns a Promise when it gets
no callback.

```js
// Shard Garden: a small 3D game on the SDK 1.9 pbr renderer (recipe in SDK/Guides/RECIPES.en.md).
// Art direction: a stone courtyard at dusk. Cold blue sky light, a warm lantern that follows the player,
// cyan shards that glow into the bloom. Palette: #0B0D14 night, #3B4C7A dusk, #FF9A3C lantern, #3CC8FF shard,
// #FFD9A8 text. HUD: bold warm numbers, no widgets.
let floor, pillar, orb, shard, crate = null;
const pillars = [];           // g3d.drawInstanced transforms: x, y, z, rx, ry, rz, scale per pillar
const shards = [];
const keys = {};
let lamp, moon;
let px = 0, pz = 0, vx = 0, vz = 0;
let score = 0, best = 0, t = 0;
let renderer = "basic";

function placeShard(s) {
  const a = Math.random() * Math.PI * 2;
  const r = 2 + Math.random() * 7;
  s.x = Math.cos(a) * r;
  s.z = Math.sin(a) * r;
}

app.load = () => {
  best = store.get("best", 0);

  // 1. the renderer and its settings (they stay until changed)
  renderer = g3d.renderer("pbr");               // "basic" when the console offers no OpenGL ES 3
  g3d.shadows({ quality: "medium", distance: 22 });
  g3d.postfx({ exposure: 0.9, tonemap: "aces", bloom: 0.08 });
  g3d.environment({ sky: "#3B4C7A", ground: "#1E1B24", intensity: 0.8, sun: 1.2 });

  // 2. materials on plain meshes
  floor = g3d.mesh("plane", 24, 24, 1);
  floor.setColor("#5A5F6B");
  g3d.material(floor, { roughness: 0.35, clearcoat: 0.6, clearcoatRoughness: 0.2 });   // wet stone
  pillar = g3d.mesh("cylinder", 0.35, 3, 20);
  pillar.setColor("#C9C1B4");
  g3d.material(pillar, { roughness: 0.7 });
  for (let i = 0; i < 16; i++) {
    const a = i / 16 * Math.PI * 2;
    pillars.push(Math.cos(a) * 11, 1.5, Math.sin(a) * 11, 0, 0, 0, 1);
  }
  orb = g3d.mesh("sphere", 0.4, 32, 20);
  orb.setColor("#FFB45C");
  g3d.material(orb, { emissive: "#FF9A3C", emissiveStrength: 4, roughness: 0.3 });
  shard = g3d.mesh("cone", 0.25, 0.7, 6);
  shard.setColor("#7FE8FF");
  g3d.material(shard, { emissive: "#3CC8FF", emissiveStrength: 6, metallic: 0.2, roughness: 0.2 });
  for (let i = 0; i < 6; i++) { const s = {}; placeShard(s); shards.push(s); }

  // 3. a model with its own PBR maps, loaded in the background (a Promise without a callback)
  g3d.loadModel("bundle:/models/crate.glb", 1.2).then((m) => { crate = m; }, (e) => print("crate: " + e.message));

  // 4. lights with ids: the lantern follows the player, the moon spot casts shadows
  lamp = g3d.addLight({ type: "point", color: "#FF9A3C", intensity: 10, range: 7 });
  moon = g3d.addLight({ type: "spot", x: 0, y: 9, z: 0, dx: 0, dy: -1, dz: 0, color: "#9FB8FF",
                        intensity: 30, range: 16, inner: 25, outer: 40, shadow: true });
};

app.event = (e) => {
  const name = e.key || e.pad;
  if (!name) return;
  if (e.type === "keydown" || e.type === "paddown") keys[name] = true;
  else if (e.type === "keyup" || e.type === "padup") keys[name] = false;
};

app.update = (dt) => {
  dt = Math.min(dt, 1 / 20);
  t += dt;
  const [sx, sy] = input.stick("left");
  const ix = sx + ((keys.right ? 1 : 0) - (keys.left ? 1 : 0));
  const iz = -sy + ((keys.down ? 1 : 0) - (keys.up ? 1 : 0));
  const k = Math.min(1, dt * 6);
  vx += (ix * 9 - vx) * k;
  vz += (iz * 9 - vz) * k;
  px = Math.max(-9.5, Math.min(9.5, px + vx * dt));
  pz = Math.max(-9.5, Math.min(9.5, pz + vz * dt));
  g3d.updateLight(lamp, { x: px, y: 1.4, z: pz });
  for (const s of shards) {
    if ((s.x - px) ** 2 + (s.z - pz) ** 2 < 0.8) {
      score++;
      audio.play("pop", 0.6);
      if (score > best) { best = score; store.set("best", best); }
      placeShard(s);
    }
  }
};

app.draw = (w, h) => {
  gfx.gradient(0, 0, w, h, "#1B2238", "#0B0D14");
  g3d.begin(0, 0, w, h, 55, 0.1, 80);
  g3d.camera(px * 0.4, 9, pz * 0.4 + 13, px * 0.6, 0, pz * 0.6);
  g3d.light(-0.4, 0.7, -0.5, 0.25, "#8FA6FF");   // a low cold sun: direction to it, ambient, colour
  g3d.fog("#0B0D14", 18, 40);
  g3d.draw(floor, 0, 0, 0);
  g3d.drawInstanced(pillar, pillars);            // 16 pillars, one GPU call on the pbr renderer
  if (crate) {
    g3d.draw(crate, -3, 0, -4, 0, 0.4, 0);
    g3d.draw(crate, 4, 0, 2, 0, -0.7, 0);
  }
  for (const s of shards) g3d.draw(shard, s.x, 0.6 + Math.sin(t * 3 + s.x) * 0.15, s.z, 0, t * 2, 0);
  g3d.draw(orb, px, 0.45, pz);
  g3d.finish();

  gfx.color("#FFD9A8");
  gfx.text(TR("score", score), 24, 18, 28, "bold");
  gfx.color("#9FB8FF");
  gfx.text(TR("best", best), 24, 54, 15, "semibold");
  gfx.color("#FFFFFF80");
  gfx.text(TR("renderer", renderer), w - 224, h - 30, 13, "mono", "right", 200);
};

app.suspend = () => store.save();
```

### Python and C notes

- **Python** (`"python"` and `"python3"`): the same function names; options are dicts and callbacks stay callbacks.
  `"minSdk": "1.9"`.

  ```python
  self.renderer = g3d.renderer("pbr")
  g3d.postfx({"exposure": 0.9, "tonemap": "aces", "bloom": 0.08})
  self.lamp = g3d.addLight({"type": "point", "color": "#FF9A3C", "intensity": 10, "range": 7})
  g3d.updateLight(self.lamp, {"x": x, "y": 1.4, "z": z})
  ```

- **C** (`nexvyn.h`): options are JSON text, meshes and models are `int` ids.

  ```c
  g3d_renderer("pbr");
  g3d_postfx("{\"exposure\":0.9,\"tonemap\":\"aces\",\"bloom\":0.08}");
  int lamp = g3d_addLight("{\"type\":\"point\",\"color\":\"#FF9A3C\",\"intensity\":10,\"range\":7}");
  g3d_drawInstanced(pillar, pillars, 16, NULL, NULL);   /* 7 floats per copy */
  ```

- Squirrel and Java are frozen at SDK 1.8 and have no pbr renderer.

## Recipe 2: Photo Board, a social feed

A photo feed with pull-to-refresh and infinite scroll, pictures from the web with a disk cache, captions with links,
mentions and hashtags, and an offline fallback. It reads the `feed.json` of the [Social Feed sample](../Samples/lua/social-feed/)
from this repository; point `FEED` at your own server for a real app.

### Step 1: the project

`app.json` asks for the network, and for `launch` to open links in the Browser:

```json
{
  "id": "com.example.photoboard",
  "name": {"en": "Photo Board"},
  "description": {"en": "A photo feed with pull-to-refresh"},
  "version": "1.0", "author": "You",
  "category": "internet", "main": "main.lua",
  "minSdk": "1.9", "targetSdk": "1.9",
  "window": {"width": 560, "height": 640, "minWidth": 360, "minHeight": 420, "resizable": true},
  "permissions": ["network", "launch"]
}
```

`lang/en.json`:

```json
{"title": "Photo Board", "offline": "Offline: showing the saved feed",
 "error": "Could not load the feed: {0}", "likes": "{0} likes"}
```

### Step 2: load the feed with `net.request`

`responseType = "json"` decodes the body into `res.data`; `cache = 600` keeps the answer for 10 minutes and gives the
last good answer (`res.stale = true`) when the console is offline; `retry = 2` tries again on timeouts and server
errors. The callback runs on the main thread, so it can change the app's state directly.

### Step 3: a virtualized feed

`ui.beginFeed` draws only the visible posts, so a list of thousands of posts costs what ten cost. Give it the height
of every post (`heights`, measured once per width with `ui.measureRichText`), draw items `f.first` to `f.last` at
`ui.feedItem(i)`, and close it with `ui.endFeed()`, which reports `refresh` (pull-to-refresh) and `more` (the end is
near).

### Step 4: pictures from the web

`gfx.imageUrl(url, 640)` returns `nil` until the picture is ready and the image afterwards. Call it every frame, draw a
placeholder meanwhile, and ask for the size you draw: the cache keeps a thumbnail of that size on the SD card.

### Step 5: rich captions

`ui.richText` draws `**bold**`, links, `@mentions` and `#hashtags` and reports the one that was tapped. What a tap
does is up to the app; here a link opens in the Browser with `sys.launch("browser", url)`.

### Step 6: lifecycle

Refresh in `app.resume`: the network may have changed while the console slept. Pause video players in `app.suspend`
if you add `media.*` (the Social Feed sample shows a clip pager).

### The whole app in Lua

```lua
-- Photo Board: a photo feed on the SDK 1.9 feed, picture and network calls (recipe in SDK/Guides/RECIPES.en.md).
-- The feed is the Social Feed sample's feed.json; replace FEED with your own server.
local app = {}

local BASE = "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/"
local FEED = BASE .. "feed.json"
local TOP = 52

local posts = {}
local heights, heightsW = {}, 0
local refreshing, loadingMore = false, false
local message = ""

local function load(more)
  if more then loadingMore = true else refreshing = true end
  net.request({url = FEED, responseType = "json", cache = 600, retry = 2, timeout = 15}, function(res)
    refreshing, loadingMore = false, false
    if not res.ok or type(res.data) ~= "table" then
      message = TR("error", res.error or res.status)
      return
    end
    message = res.stale and TR("offline") or ""
    if not more then posts, heights = {}, {} end
    for _, p in ipairs(res.data.posts or {}) do
      posts[#posts + 1] = {user = p.user, photo = BASE .. p.photo, caption = p.caption, likes = p.likes,
                           time = sys.epoch() - 60 * (p.minutesAgo + #posts * 7)}
    end
  end)
end

local function postHeight(p, w)
  return 52 + (w - 24) + 36 + ui.measureRichText(p.caption, w - 24, 15) + 12
end

local function drawPost(p, x, y, w, h)
  gfx.rect(x + 6, y, w - 12, h, 12, theme.window)
  gfx.color(theme.text)
  gfx.text(p.user, x + 16, y + 10, 15, "semibold")
  gfx.color(theme.text2)
  gfx.text(sys.relativeTime(p.time), x + 16, y + 29, 12)
  local size = w - 24
  local img = gfx.imageUrl(p.photo, 640)       -- nil while it downloads; cached on the SD card
  if img then gfx.draw(img, x + 12, y + 52, size, size, 8) else gfx.rect(x + 12, y + 52, size, size, 8, theme.control) end
  gfx.color(theme.text2)
  gfx.text(TR("likes", p.likes), x + 16, y + 60 + size, 13)
  gfx.color(theme.text)
  local r = ui.richText("cap" .. p.time, p.caption, x + 12, y + 84 + size, w - 24, 15)
  if r.clicked and r.clicked.type == "link" then sys.launch("browser", r.clicked.value) end
end

function app.load()
  load(false)
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 16, 14, 20, "bold")
  if message ~= "" then
    gfx.color(theme.text2)
    gfx.text(message, 16, 14, 12, "sans", "right", w - 32)
  end
  if heightsW ~= w then heights, heightsW = {}, w end
  for i = #heights + 1, #posts do heights[i] = postHeight(posts[i], w) end
  local f = ui.beginFeed("feed", 0, TOP, w, h - TOP, #posts, {heights = heights, gap = 10, padBottom = 8,
                                                             refreshing = refreshing, loadingMore = loadingMore})
  for i = f.first, f.last do
    local r = ui.feedItem(i)
    drawPost(posts[i], r.x, r.y, r.w, r.h)
  end
  local ev = ui.endFeed()
  if ev.refresh then load(false) end
  if ev.more and #posts < 120 then load(true) end
end

function app.resume()
  load(false)                                  -- the network may have changed while the console slept
end

return app
```

### The whole app in JavaScript

Feed indexes are 0-based in JavaScript (`for (let i = f.first; i <= f.last; i++)`).

```js
// Photo Board: a photo feed on the SDK 1.9 feed, picture and network calls (recipe in SDK/Guides/RECIPES.en.md).
// The feed is the Social Feed sample's feed.json; replace FEED with your own server.
const BASE = "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/";
const FEED = BASE + "feed.json";
const TOP = 52;

let posts = [];
let heights = [], heightsW = 0;
let refreshing = false, loadingMore = false;
let message = "";

function load(more) {
  if (more) loadingMore = true; else refreshing = true;
  net.request({ url: FEED, responseType: "json", cache: 600, retry: 2, timeout: 15 }, (res) => {
    refreshing = false;
    loadingMore = false;
    if (!res.ok || !res.data) {
      message = TR("error", res.error || res.status);
      return;
    }
    message = res.stale ? TR("offline") : "";
    if (!more) { posts = []; heights = []; }
    for (const p of res.data.posts || []) {
      posts.push({ user: p.user, photo: BASE + p.photo, caption: p.caption, likes: p.likes,
                   time: sys.epoch() - 60 * (p.minutesAgo + posts.length * 7) });
    }
  });
}

function postHeight(p, w) {
  return 52 + (w - 24) + 36 + ui.measureRichText(p.caption, w - 24, 15) + 12;
}

function drawPost(p, x, y, w, h) {
  gfx.rect(x + 6, y, w - 12, h, 12, theme.window);
  gfx.color(theme.text);
  gfx.text(p.user, x + 16, y + 10, 15, "semibold");
  gfx.color(theme.text2);
  gfx.text(sys.relativeTime(p.time), x + 16, y + 29, 12);
  const size = w - 24;
  const img = gfx.imageUrl(p.photo, 640);       // null while it downloads; cached on the SD card
  if (img) gfx.draw(img, x + 12, y + 52, size, size, 8); else gfx.rect(x + 12, y + 52, size, size, 8, theme.control);
  gfx.color(theme.text2);
  gfx.text(TR("likes", p.likes), x + 16, y + 60 + size, 13);
  gfx.color(theme.text);
  const r = ui.richText("cap" + p.time, p.caption, x + 12, y + 84 + size, w - 24, 15);
  if (r.clicked && r.clicked.type === "link") sys.launch("browser", r.clicked.value);
}

app.load = () => load(false);

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("title"), 16, 14, 20, "bold");
  if (message) {
    gfx.color(theme.text2);
    gfx.text(message, 16, 14, 12, "sans", "right", w - 32);
  }
  if (heightsW !== w) { heights = []; heightsW = w; }
  for (let i = heights.length; i < posts.length; i++) heights[i] = postHeight(posts[i], w);
  const f = ui.beginFeed("feed", 0, TOP, w, h - TOP, posts.length, { heights, gap: 10, padBottom: 8,
                                                                     refreshing, loadingMore });
  for (let i = f.first; i <= f.last; i++) {      // 0-based in JavaScript
    const r = ui.feedItem(i);
    drawPost(posts[i], r.x, r.y, r.w, r.h);
  }
  const ev = ui.endFeed();
  if (ev.refresh) load(false);
  if (ev.more && posts.length < 120) load(true);
};

app.resume = () => load(false);                  // the network may have changed while the console slept
```

### Python and C notes

- **Python:** `net.request(options, callback)` returns the request id, the response reads as attributes
  (`res.ok`, `res.data`), and feed indexes are 0-based: `for i in range(f.first, f.last + 1)`.
- **C:** `ui_beginFeed(id, x, y, w, h, count, optionsJson)` returns an `nxv_feed` with `first` / `last`,
  `ui_feedItem(i, &x, &y, &w, &h)` gives the rectangle and `ui_endFeed()` returns bit flags (1 = refresh, 2 = more);
  `gfx_imageUrl(url, maxSize, &w, &h)` returns the image path to draw once it is ready.

## Checking and running

1. Check the manifest, translations, permissions and store files on a PC:
   `python SDK/Tools/nxv/nxv.py check ShardGarden.nxvapp`.
2. Run the language checker (`--sdk` with a Nexvyn OS source checkout runs `lua_check.py` / `js_check.mjs` /
   `py_check.py`; without it, the maintainer runs them when you submit the app).
3. Copy the folder to `sdmc:/NexvynOS/Applications/` or open it in Nexvyn OS Studio and press **Run**.
4. On the console, compare `"pbr"` and `"basic"` (the pbr3d sample has buttons for it) and watch the fps.

## Where to go next

- Samples: [PBR, Lights and Shadows](../Samples/lua/pbr3d/), [Social Feed](../Samples/lua/social-feed/),
  [Ember Field](../Samples/lua/ember-field/) (a complete 3D game with an animated model).
- Guides: [Make a game](MAKE_A_GAME.en.md), [Make a social app](MAKE_A_SOCIAL_APP.en.md),
  [Sound design](SOUND_DESIGN.en.md), [Graphics, UI and game feel](GAME_FEEL.en.md),
  [AI-assisted workflow](AI_WORKFLOW.en.md), [SDK versions](SDK_VERSIONS.en.md).
- Reference: [SDK reference](../Reference/SDK.en.md), sections 8b (*Modern rendering*) and 8d (*Feeds, media and network*).
