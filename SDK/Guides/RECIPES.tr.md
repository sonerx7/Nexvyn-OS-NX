# Tarifler: PBR'lı bir 3B oyun ve bir sosyal uygulama (SDK 1.9)

[English](RECIPES.en.md) · **Türkçe**

SDK 1.9'un getirdikleri üstüne adım adım kurulan iki küçük, eksiksiz uygulama: NexGFX **pbr renderer** ve **akış,
resim ve ağ** fonksiyonları. Her tarif programın tamamıyla, Lua ve JavaScript olarak biter; iki sürüm de SDK
checker'larından (`lua_check.py`, `js_check.mjs`) geçer ve yalnızca [SDK başvurusundaki](../Reference/SDK.tr.md)
fonksiyonları kullanır. Her tarifin sonunda Python ve C notları var.

Tarifleri elle ya da bir AI asistanıyla başlangıç noktası olarak kullanın ([AI destekli çalışma](AI_WORKFLOW.tr.md)).
Arka planın tamamı için [Oyun yap](MAKE_A_GAME.tr.md) ve [Sosyal uygulama yap](MAKE_A_SOCIAL_APP.tr.md) rehberlerini
okuyun.

## İçindekiler

1. [Tarif 1: Shard Garden, PBR'lı bir 3B oyun](#tarif-1-shard-garden-pbrlı-bir-3b-oyun)
2. [Tarif 2: Photo Board, bir sosyal akış](#tarif-2-photo-board-bir-sosyal-akış)
3. [Denetleme ve çalıştırma](#denetleme-ve-çalıştırma)
4. [Sonra nereye](#sonra-nereye)

## Tarif 1: Shard Garden, PBR'lı bir 3B oyun

Bir fener küresi alacakaranlıkta taş bir avluda dolaşıp parlayan kristalleri toplar. Yaklaşık 120 satırdır ve bir
PBR sahnesinin her parçasını gösterir: renderer ayarları, düz mesh'lerde materyaller, kendi haritalarıyla gelen bir
model, id'li ışıklar, gölgeler, bloom, instancing ve oyunun kendi stilinde çizilen bir HUD.

### Adım 1: proje

```
ShardGarden.nxvapp/
  app.json
  main.lua            (ya da main.js)
  lang/en.json        zorunlu
  lang/tr.json        isteğe bağlı, her ek dil için bir dosya
  models/crate.glb    PBR haritalı herhangi bir .glb; pbr3d örneğinde bir tane var (CC0)
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

### Adım 2: önce görünüşe karar verin

Koddan önce `main.lua`'nın başına sanat yönünü yazın: his, palet, ışık, HUD stili. Bu tariften yapılan iki oyun
birbirine benzememeli; kendi oyununuz için paleti, ışık renklerini, pozlamayı ve bloom'u değiştirin
([Grafik, arayüz ve oyun hissi](GAME_FEEL.tr.md)).

### Adım 3: renderer'ı `app.load` içinde açın

```lua
renderer = g3d.renderer("pbr")      -- "pbr", konsol OpenGL ES 3 sunmuyorsa "basic"
g3d.shadows({quality = "medium", distance = 22})
g3d.postfx({exposure = 0.9, tonemap = "aces", bloom = 0.08})
g3d.environment({sky = "#3B4C7A", ground = "#1E1B24", intensity = 0.8, sun = 1.2})
```

Renderer ayarları uygulamaya aittir ve siz değiştirene kadar kalır. `g3d.renderer` `"basic"` döndürdüğünde de oyun
oynanabilir kalsın: aynı çağrılar ışık, gölge ve son efekt olmadan yine çizer.

### Adım 4: materyaller

Düz mesh'ler PBR değerlerini `g3d.material` ile alır. `.glb` ya da `.fbx`'ten yüklenen bir model haritalarını
(base color, normal, metallic-roughness ya da ORM, occlusion, emissive) zaten taşır, bir şey gerekmez.

| Yüzey | Materyal |
|---|---|
| Islak taş zemin | `{roughness = 0.35, clearcoat = 0.6, clearcoatRoughness = 0.2}` |
| Boyalı taş | `{roughness = 0.7}` |
| Parlatılmış metal | `{metallic = 1, roughness = 0.15}` |
| Parlayan parçalar | `{emissive = "#3CC8FF", emissiveStrength = 6}`: 1'in üstü bloom'a girer |
| İnce cam | `{transmission = 0.9, roughness = 0.05, ior = 1.5}` |

### Adım 5: id'li ışıklar

`g3d.light` güneştir. 16 ışığa kadar daha `g3d.addLight` ile gelir ve bir id döndürür; ışıkları her karede
`g3d.updateLight` ile hareket ettirin (yalnızca verdiğiniz alanlar değişir). Her nesneyi yakınındaki en güçlü 8 ışık
aydınlatır ve `shadow = true` olan bir spot ışık güneşin yanında gölge düşürür.

### Adım 6: tekrarlanan nesneler

Sütunlar, çimen, kasalar ve döküntü `g3d.drawInstanced(mesh, transforms)` ile çizilir: kopya başına 7 sayı (`x, y,
z, rx, ry, rz, scale`). pbr renderer'da 128 kopyaya kadar tek GPU çağrısıdır.

### Adım 7: konsolda ölçün

pbr renderer GPU zamanı harcar. `msaa = 0`, `"medium"` gölge ve en çok 1024 px dokularla başlayın, geliştirirken
fps'i ve üçgen sayısını gösterin, kaliteyi yalnızca kare hızı korunurken yükseltin.

### Oyunun tamamı, Lua

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

### Oyunun tamamı, JavaScript

Aynı program: seçenekler nesnedir, `input.stick` dizi döndürür, `g3d.loadModel` callback almazsa Promise döndürür.

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

### Python ve C notları

- **Python** (`"python"` ve `"python3"`): fonksiyon adları aynı; seçenekler dict'tir, callback'ler callback olarak
  kalır. `"minSdk": "1.9"`.

  ```python
  self.renderer = g3d.renderer("pbr")
  g3d.postfx({"exposure": 0.9, "tonemap": "aces", "bloom": 0.08})
  self.lamp = g3d.addLight({"type": "point", "color": "#FF9A3C", "intensity": 10, "range": 7})
  g3d.updateLight(self.lamp, {"x": x, "y": 1.4, "z": z})
  ```

- **C** (`nexvyn.h`): seçenekler JSON metnidir, mesh ve modeller `int` id'dir.

  ```c
  g3d_renderer("pbr");
  g3d_postfx("{\"exposure\":0.9,\"tonemap\":\"aces\",\"bloom\":0.08}");
  int lamp = g3d_addLight("{\"type\":\"point\",\"color\":\"#FF9A3C\",\"intensity\":10,\"range\":7}");
  g3d_drawInstanced(pillar, pillars, 16, NULL, NULL);   /* kopya başına 7 float */
  ```

- Squirrel ve Java SDK 1.8'de donduruldu; pbr renderer'ları yok.

## Tarif 2: Photo Board, bir sosyal akış

Çek-yenile ve sonsuz kaydırmalı bir fotoğraf akışı, disk önbellekli web resimleri, bağlantı, bahsetme ve etiketli
açıklamalar ve çevrimdışı yedek. Bu depodaki [Sosyal Akış örneğinin](../Samples/lua/social-feed/) `feed.json`'unu
okur; gerçek bir uygulamada `FEED`'i kendi sunucunuza yönlendirin.

### Adım 1: proje

`app.json` ağ iznini ve bağlantıları Tarayıcı'da açmak için `launch` iznini ister:

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

### Adım 2: akışı `net.request` ile yükleyin

`responseType = "json"` gövdeyi `res.data`'ya çözer; `cache = 600` yanıtı 10 dakika tutar ve konsol çevrimdışıyken son
iyi yanıtı verir (`res.stale = true`); `retry = 2` zaman aşımı ve sunucu hatalarında yeniden dener. Callback ana
thread'de çalışır, uygulamanın durumunu doğrudan değiştirebilir.

### Adım 3: sanal akış

`ui.beginFeed` yalnızca görünen gönderileri çizer; binlerce gönderilik bir liste on gönderi kadar tutar. Her gönderinin
yüksekliğini verin (`heights`, her genişlik için bir kez `ui.measureRichText` ile ölçülür), `f.first`'ten `f.last`'e
kadar öğeleri `ui.feedItem(i)` dikdörtgenine çizin ve `ui.endFeed()` ile kapatın; `refresh` (çek-yenile) ve `more`
(sona yaklaşıldı) bilgisini o döndürür.

### Adım 4: webden resimler

`gfx.imageUrl(url, 640)` resim hazır olana kadar `nil`, sonra resmi döndürür. Her karede çağırın, bu arada bir yer
tutucu çizin ve çizdiğiniz boyutu isteyin: önbellek SD kartta o boyutta bir küçük resim tutar.

### Adım 5: zengin açıklamalar

`ui.richText` `**kalın**`, bağlantı, `@bahsetme` ve `#etiket` çizer ve dokunulanı bildirir. Dokununca ne olacağı
uygulamaya kalmış; burada bağlantı `sys.launch("browser", url)` ile Tarayıcı'da açılır.

### Adım 6: yaşam döngüsü

`app.resume`'da yenileyin: konsol uyurken ağ değişmiş olabilir. `media.*` eklerseniz video oynatıcıları
`app.suspend`'de duraklatın (Sosyal Akış örneği bir klip sayfalayıcı gösterir).

### Uygulamanın tamamı, Lua

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

### Uygulamanın tamamı, JavaScript

JavaScript'te akış indeksleri 0 tabanlıdır (`for (let i = f.first; i <= f.last; i++)`).

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

### Python ve C notları

- **Python:** `net.request(options, callback)` istek id'sini döndürür, yanıt öznitelik olarak okunur (`res.ok`,
  `res.data`) ve akış indeksleri 0 tabanlıdır: `for i in range(f.first, f.last + 1)`.
- **C:** `ui_beginFeed(id, x, y, w, h, count, optionsJson)` `first` / `last` alanlı bir `nxv_feed` döndürür,
  `ui_feedItem(i, &x, &y, &w, &h)` dikdörtgeni verir, `ui_endFeed()` bit bayrakları döndürür (1 = yenile, 2 = daha
  fazla); `gfx_imageUrl(url, maxSize, &w, &h)` resim hazır olunca çizilecek yolu döndürür.

## Denetleme ve çalıştırma

1. PC'de manifest, çeviri, izin ve mağaza dosyalarını denetleyin:
   `python SDK/Tools/nxv/nxv.py check ShardGarden.nxvapp`.
2. Dil checker'ını çalıştırın (`--sdk` bir Nexvyn OS kaynak kopyasıyla `lua_check.py` / `js_check.mjs` /
   `py_check.py`'yi çalıştırır; o olmadan uygulamayı gönderdiğinizde bakımcı çalıştırır).
3. Klasörü `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da Nexvyn OS Studio'da açıp **Çalıştır**'a basın.
4. Konsolda `"pbr"` ile `"basic"`'i karşılaştırın (pbr3d örneğinde bunun için düğmeler var) ve fps'i izleyin.

## Sonra nereye

- Örnekler: [PBR, Işıklar ve Gölgeler](../Samples/lua/pbr3d/), [Sosyal Akış](../Samples/lua/social-feed/),
  [Ember Field](../Samples/lua/ember-field/) (animasyonlu modelli eksiksiz bir 3B oyun).
- Rehberler: [Oyun yap](MAKE_A_GAME.tr.md), [Sosyal uygulama yap](MAKE_A_SOCIAL_APP.tr.md),
  [Ses tasarımı](SOUND_DESIGN.tr.md), [Grafik, arayüz ve oyun hissi](GAME_FEEL.tr.md),
  [AI destekli çalışma](AI_WORKFLOW.tr.md), [SDK sürümleri](SDK_VERSIONS.tr.md).
- Başvuru: [SDK başvurusu](../Reference/SDK.tr.md), bölüm 8b (*Modern görüntü*) ve 8d (*Akış, medya ve ağ*).
