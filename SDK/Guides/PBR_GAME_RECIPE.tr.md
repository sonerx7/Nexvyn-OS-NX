# PBR oyun tarifi: tek dosyada ışıklı bir avlu (SDK 1.9)

[English](PBR_GAME_RECIPE.en.md) · **Türkçe**

pbr renderer üzerinde, `app.json`'dan son callback'e kadar eksiksiz küçük bir 3B oyun: **Lumen Yard**. Bir bekçi,
alacakaranlıkta duvarlarla çevrili bir avluda süre bitmeden parlayan çekirdekleri topluyor. Oyun, *Modern görüntü*
bölümünün (SDK başvurusu, bölüm 8b) gerçek bir oyunun ihtiyaç duyduğu her parçasını kullanır: fallback'iyle birlikte
renderer'ı açma, gölge veren bir güneş, id'li ve hareket eden nokta ışıklar, bloom'a taşan emissive materyaller, GPU
instancing, arka planda yüklenen ve gelene kadar yerini primitive'lerin tuttuğu bir model, tone mapping. Program burada
Lua ve JavaScript ile eksiksiz; Python ve C, farklı olan çağrılarla daha kısa programlar olarak gelir.

Bu sayfadaki her program, basıldığı hâliyle SDK checker'larından (`lua_check.py`, `js_check.mjs`, `py_check.py`,
`rt_check.py`) geçti. Her fonksiyon [SDK başvurusunda](../Reference/SDK.tr.md) var; orada olmayan şey yoktur. Daha geniş
oyun rehberi (sahneler, girdi katmanı, çarpışma yardımcıları, yükleme ekranları, mağaza ikonu)
[MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md); en küçük PBR sahnesi [pbr3d](../Samples/lua/pbr3d/) örneği.

## İçindekiler

1. [Ne yapıyorsunuz](#1-ne-yapıyorsunuz)
2. [Önce sanat yönü](#2-önce-sanat-yönü)
3. [Paket](#3-paket)
4. [main.lua](#4-mainlua)
5. [Nasıl çalışıyor](#5-nasıl-çalışıyor)
6. [Model](#6-model)
7. [JavaScript](#7-javascript)
8. [Python ve C](#8-python-ve-c)
9. [Denetleme ve çalıştırma](#9-denetleme-ve-çalıştırma)
10. [Yayından önce](#10-yayından-önce)

## 1. Ne yapıyorsunuz

| Oyunun parçası | SDK 1.9 çağrısı |
|---|---|
| `app.load`'da bir kez seçilen renderer; oyun `"basic"`ta da doğru çalışır | `g3d.renderer("pbr")` |
| Avlunun üzerine gölge düşüren alçak bir akşam güneşi | `g3d.light`, `g3d.shadows` |
| Gökyüzü ve zemin ambient'i | `g3d.environment` |
| Exposure, filmic tone mapping, bloom | `g3d.postfx` |
| Her birinin kendi kehribar nokta ışığı olan ve onunla birlikte taşınan dört çekirdek | `g3d.addLight`, `g3d.updateLight` |
| Bekçinin turkuaz feneri: oyuncuyu izleyen bir ışık | `g3d.updateLight` |
| Çekirdekler ve fener bloom'a taşar | `emissiveStrength` 1'in üstünde `g3d.material` |
| 28 sütun ve 6 sandık iki GPU çağrısında | `g3d.drawInstanced` |
| Düz mesh'lerde taş, ahşap ve metal görünümü | `g3d.material` (`metallic`, `roughness`) |
| Arka planda parse edilen bekçi modeli; gelene kadar (ya da hiç yoksa) primitive'ler | `g3d.loadModel` |

Oyunun kuralları: 60 saniye, her çekirdek 1,5 saniye ekler, en iyi sayı `store` ile saklanır. Kontrolcü, klavye ve
dokunmatik çalışır; **+** (ya da Esc / P) duraklatır; oyun suspend'de ve pencere odağı kaybedince kendini duraklatır.

## 2. Önce sanat yönü

Bu SDK ile yapılan iki oyun birbirine benzememeli, bir oyun da Nexvyn OS masaüstüne benzememeli. Lumen Yard yedi
kararını `main.lua`'nın başına yazar (his, palet, yazı, kamera, hareket, ses, arayüz biçimi) ve ekrandaki her şey onlara
uyar: `theme` renkleri yok, `ui.*` widget'ları yok, panel yok; başlık, HUD ve duraklatma ekranı ince bir kehribar çizgi
üzerinde `gfx` ile çizilir.

**Bu görünümü kopyalamayın.** Bir oyun için bir cevaptır. Yapıyı alın, sonra önce kendi yedi kararınızı verin (yöntem
ve birbirinden çok farklı dört başlık ekranı [MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md), bölüm 11'de). Mağaza incelemesi,
bir örneğin ya da rehberin menü düzenini, renklerini veya başlık kompozisyonunu kullanan oyunları kabul etmez.

## 3. Paket

```
LumenYard.nxvapp/
├── app.json
├── main.lua
├── icon.png              oyununuzun 256 x 256 key art'ı (MAKE_A_GAME.tr.md, bölüm 12)
├── lang/en.json          İngilizce zorunlu; başka diller için lang/<kod>.json ekleyin
└── models/keeper.glb     isteğe bağlı: yoksa oyun primitive bir bekçi çizer
```

`app.json`: bir oyun (`"gamepad": true`, tam ekran açılan yeniden boyutlanabilir pencere), pbr renderer için SDK 1.9,
izin yok.

```json
{
  "id": "com.yourname.lumenyard",
  "name": {"en": "Lumen Yard"},
  "description": {"en": "Gather glowing cores in a walled courtyard before the light runs out"},
  "version": "1.0",
  "author": "Your Name",
  "category": "games",
  "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 1280, "height": 720, "minWidth": 640, "minHeight": 360, "resizable": true},
  "gamepad": true,
  "minSdk": "1.9",
  "targetSdk": "1.9",
  "permissions": []
}
```

`lang/en.json`: görünen her metin `TR()`'den geçer.

```json
{
  "title": "lumen yard",
  "tagline": "Gather the last light before the yard goes dark.",
  "start": "Press A, Enter or tap to begin",
  "cores": "CORES",
  "best": "Best: {0}",
  "over": "The yard is dark",
  "score": "You gathered {0} cores",
  "again": "Press A, Enter or tap to play again",
  "paused": "Paused",
  "resume": "Press A, Enter or tap to continue",
  "debug": "{0} renderer · {1} triangles · {2} fps"
}
```

## 4. main.lua

```lua
-- Lumen Yard: gather glowing cores in a walled courtyard at dusk (SDK 1.9, pbr renderer).
-- Art direction:
--   1 Feeling: "last light in a walled yard": calm, warm, a little uneasy.
--   2 Palette: slate ink #0E151B, sandstone #C9B79C, amber #FFB24A (cores), teal #4FD1C5 (the keeper's lamp).
--   3 Type: a large lowercase bold title, italic tagline, monospace numbers.
--   4 Camera: high three-quarter follow, eased; a slow orbit behind the title.
--   5 Motion: slow and soft; cores bob and spin, nothing snaps.
--   6 Sound: two soft notes a fifth apart, rising with the count.
--   7 UI: no panels or boxes; text hangs on a thin amber line at the left edge.
local app = {}

local INK, SAND, AMBER, TEAL = "#0E151B", "#C9B79C", "#FFB24A", "#4FD1C5"
local YARD = 10        -- the courtyard spans -YARD..YARD on x and z (metres)
local CORES = 4        -- cores on the ground at a time, each with its own point light
local ROUND = 60       -- seconds per round

local active = "basic" -- the renderer frames use: "pbr", or "basic" when the GPU does not offer it
local keeper           -- the model, once g3d.loadModel delivered it
local ground, pillar, crate, coreMesh, body, head
local pillars, crates = {}, {}   -- g3d.drawInstanced transforms: x, y, z, rx, ry, rz, scale per copy
local solids = {}                -- circles {x, z, r} the keeper cannot enter
local cores = {}
local lamp
local player = {x = 0, z = 0, yaw = 0, vx = 0, vz = 0, clip = ""}
local cam = {x = 0, z = 8}
local state, paused, showDebug = "title", false, false
local score, best, timeLeft, t, flash = 0, 0, ROUND, 0, 0
local held = {}
local touch = {on = false, x = 0, y = 0}
local screenW, screenH = 1280, 720

-- ------------------------------------------------------------------ renderer and scene
local function setupRenderer()
  active = g3d.renderer("pbr")   -- "pbr", or "basic": the same calls still draw
  g3d.shadows({enabled = true, quality = "medium", distance = 24})
  g3d.postfx({exposure = 1.1, tonemap = "filmic", bloom = 0.09, threshold = 1.0, msaa = 0})
  g3d.environment({sky = "#3A4E66", ground = "#2B241E", intensity = 0.8, sun = 1.8})
end

local function buildYard()
  ground = g3d.mesh("plane", YARD * 2 + 4, YARD * 2 + 4, 8)
  ground:setColor("#5E574C")
  g3d.material(ground, {metallic = 0, roughness = 0.9})

  pillar = g3d.mesh("box", 0.6, 3.2, 0.6)
  pillar:setColor(SAND)
  g3d.material(pillar, {roughness = 0.7})
  for i = 0, 27 do                         -- a colonnade: 7 pillars on each side
    local side, k = i // 7, i % 7
    local u = -YARD + 1 + k * (YARD * 2 - 2) / 6
    local x, z = u, -YARD
    if side == 1 then x, z = YARD, u elseif side == 2 then x, z = -u, YARD elseif side == 3 then x, z = -YARD, -u end
    for _, v in ipairs({x, 1.6, z, 0, 0, 0, 1}) do pillars[#pillars + 1] = v end
  end

  crate = g3d.mesh("box", 1, 1, 1)
  crate:setColor("#7A5A3C")
  g3d.material(crate, {roughness = 0.6})
  for i, p in ipairs({{-4, -3}, {5, -5}, {-6, 5}, {3, 4}, {0, -7}, {7, 2}}) do
    for _, v in ipairs({p[1], 0.5, p[2], 0, i * 0.7, 0, 1}) do crates[#crates + 1] = v end
    solids[#solids + 1] = {x = p[1], z = p[2], r = 0.75}
  end

  coreMesh = g3d.mesh("sphere", 0.28, 6, 4)   -- few segments: a cut gem
  coreMesh:flat(true)
  coreMesh:setColor(AMBER)
  g3d.material(coreMesh, {emissive = AMBER, emissiveStrength = 6, roughness = 0.3})   -- above 1: it blooms

  -- the keeper drawn from primitives until (or unless) models/keeper.glb arrives
  body = g3d.mesh("cylinder", 0.32, 1.1, 16)
  body:setColor("#2E3A44")
  g3d.material(body, {metallic = 0.6, roughness = 0.35})
  head = g3d.mesh("sphere", 0.26, 20, 14)
  head:setColor(TEAL)
  g3d.material(head, {emissive = TEAL, emissiveStrength = 3})
end

local function freeSpot()
  local x, z = 0, 0
  for _ = 1, 20 do                         -- bounded: never loops forever
    x, z = (math.random() * 2 - 1) * (YARD - 2), (math.random() * 2 - 1) * (YARD - 2)
    local ok = (x - player.x) ^ 2 + (z - player.z) ^ 2 > 9
    for _, s in ipairs(solids) do
      if (x - s.x) ^ 2 + (z - s.z) ^ 2 < (s.r + 0.8) ^ 2 then ok = false end
    end
    if ok then break end
  end
  return x, z
end

local function placeCore(c)
  c.x, c.z = freeSpot()
  c.phase = math.random() * 6.28
  g3d.updateLight(c.light, {x = c.x, y = 0.9, z = c.z})
end

-- ------------------------------------------------------------------ rounds
local function startRound()
  state, paused = "play", false
  score, timeLeft = 0, ROUND
  player.x, player.z, player.vx, player.vz = 0, 0, 0, 0
  cam.x, cam.z = 0, 8
  for _, c in ipairs(cores) do placeCore(c) end
end

local function finishRound()
  state = "over"
  if score > best then
    best = score
    store.set("best", best)
  end
end

local function collect(c)
  score = score + 1
  timeLeft = math.min(ROUND, timeLeft + 1.5)
  flash = 1
  local step = score % 5
  audio.tone(523 + step * 66, 0.16, 0.22, "triangle")
  audio.tone(784 + step * 99, 0.24, 0.10, "sine")   -- a fifth above, quieter
  sys.vibrate(0.25, 40)
  placeCore(c)
end

local function confirm()
  if state == "title" or state == "over" then startRound()
  elseif paused then paused = false end
end

-- ------------------------------------------------------------------ input
local function moveInput()
  local x, y = input.stick("left")
  y = -y                                   -- the stick reports up as positive
  if input.down("left") or held.left or held.a then x = -1 end
  if input.down("right") or held.right or held.d then x = 1 end
  if input.down("up") or held.up or held.w then y = -1 end
  if input.down("down") or held.down or held.s then y = 1 end
  if touch.on then                         -- touch: walk towards the finger
    local dx, dy = touch.x - screenW / 2, touch.y - screenH / 2
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 24 then x, y = dx / len, dy / len end
  end
  local len = math.sqrt(x * x + y * y)
  if len > 1 then x, y = x / len, y / len end
  return x, y
end

-- ------------------------------------------------------------------ callbacks
function app.load(arg)
  best = store.get("best", 0)
  setupRenderer()
  buildYard()
  for i = 1, CORES do
    cores[i] = {light = g3d.addLight({type = "point", color = AMBER, intensity = 4, range = 5})}
    placeCore(cores[i])
  end
  lamp = g3d.addLight({type = "point", x = 0, y = 1.9, z = 0, color = TEAL, intensity = 3, range = 6})
  g3d.loadModel("bundle:/models/keeper.glb", 1.7, function(m, err)
    if m then
      keeper = m
      keeper:play("Idle")
    else
      print("keeper.glb not loaded (" .. tostring(err) .. "): drawing the primitive keeper")
    end
  end)
end

function app.update(dt)
  dt = math.min(dt, 1 / 20)                -- a long frame must not move things through walls
  t = t + dt
  flash = math.max(0, flash - dt * 3)
  if keeper then keeper:update(dt) end
  if state ~= "play" or paused then return end

  timeLeft = timeLeft - dt
  if timeLeft <= 0 then
    finishRound()
    return
  end

  local mx, my = moveInput()
  local k = math.min(1, dt * 10)           -- ease the velocity: soft starts and stops
  player.vx = player.vx + (mx * 5.5 - player.vx) * k
  player.vz = player.vz + (my * 5.5 - player.vz) * k
  local nx = math.max(-YARD + 1, math.min(YARD - 1, player.x + player.vx * dt))
  local nz = math.max(-YARD + 1, math.min(YARD - 1, player.z + player.vz * dt))
  for _, s in ipairs(solids) do            -- push out of the crates
    local dx, dz = nx - s.x, nz - s.z
    local d, r = math.sqrt(dx * dx + dz * dz), s.r + 0.35
    if d < r and d > 1e-6 then nx, nz = s.x + dx / d * r, s.z + dz / d * r end
  end
  player.x, player.z = nx, nz
  local moving = player.vx * player.vx + player.vz * player.vz > 0.2
  if moving then player.yaw = math.atan(player.vx, player.vz) end   -- a model faces +Z at yaw 0
  if keeper then
    local want = moving and "Run" or "Idle"
    if want ~= player.clip then
      player.clip = want
      keeper:play(want, {loop = true, fade = 0.2})
    end
  end
  g3d.updateLight(lamp, {x = player.x, y = 1.9, z = player.z})

  for _, c in ipairs(cores) do
    if (c.x - player.x) ^ 2 + (c.z - player.z) ^ 2 < 0.8 then collect(c) end
  end

  local e = math.min(1, dt * 4)            -- eased follow camera
  cam.x = cam.x + (player.x - cam.x) * e
  cam.z = cam.z + (player.z + 8 - cam.z) * e
end

local function drawScene(w, h)
  g3d.begin(0, 0, w, h, 50, 0.1, 60)
  if state == "title" then
    local a = t * 0.12
    g3d.camera(math.sin(a) * 14, 6, math.cos(a) * 14, 0, 1, 0)
  else
    g3d.camera(cam.x, 9, cam.z, cam.x, 0.6, cam.z - 8)
  end
  g3d.light(-0.6, 0.45, -0.35, 0.25, "#FFB98A")   -- a low dusk sun: direction to it, ambient, colour
  g3d.fog(INK, 18, 45)
  g3d.draw(ground, 0, 0, 0)
  g3d.drawInstanced(pillar, pillars)       -- 28 pillars, one GPU call on the pbr renderer
  g3d.drawInstanced(crate, crates)
  local flags = active == "pbr" and "" or "unlit"   -- on "basic" the glowing parts are drawn unlit
  for _, c in ipairs(cores) do
    g3d.draw(coreMesh, c.x, 0.75 + math.sin(t * 2 + c.phase) * 0.12, c.z, t, t * 0.7, 0, 1, 1, 1, nil, flags)
  end
  if keeper then
    g3d.draw(keeper, player.x, 0, player.z, 0, player.yaw, 0)
  else
    g3d.draw(body, player.x, 0.55, player.z, 0, player.yaw, 0)
    g3d.draw(head, player.x, 1.35, player.z, 0, 0, 0, 1, 1, 1, nil, flags)
  end
  return g3d.finish()
end

local function hairline(x, y, h) gfx.rect(x, y, 3, h, 0, AMBER) end

local function drawHud(w, h)
  hairline(28, 28, 58)
  gfx.color(SAND)
  gfx.text(TR("cores"), 42, 28, 13, "semibold")
  gfx.color(flash > 0 and AMBER or "#FFFFFF")
  gfx.text(tostring(score), 42, 44, 34 + flash * 8, "monobold")
  local frac = math.max(0, timeLeft / ROUND)   -- the light that is left: a thin bar along the bottom
  gfx.rect(0, h - 4, w, 4, 0, "#FFFFFF22")
  gfx.rect(0, h - 4, w * frac, 4, 0, frac < 0.2 and "#FF5A3C" or AMBER)
  gfx.color(SAND)
  gfx.text(string.format("%02d", math.ceil(timeLeft)), w - 120, 28, 34, "monobold", "right", 92)
end

local function drawBlock(w, h, big, line1, line2)
  gfx.gradient(0, h * 0.4, w, h * 0.6, "#0E151B00", "#0E151BE6")
  local x, y = 64, h - 220
  hairline(x - 22, y + 8, 140)
  gfx.color("#FFFFFF")
  gfx.text(big, x, y, 64, "bold")
  gfx.color(SAND)
  gfx.text(line1, x, y + 78, 18, "italic")
  gfx.alpha(0.55 + math.sin(t * 3) * 0.45)
  gfx.color(AMBER)
  gfx.text(line2, x, y + 116, 16, "semibold")
  gfx.unalpha()
end

function app.draw(w, h)
  screenW, screenH = w, h
  gfx.clear(INK)
  local tris = drawScene(w, h)
  if state == "title" then
    drawBlock(w, h, TR("title"), TR("tagline"), TR("start"))
    if best > 0 then
      gfx.color(SAND)
      gfx.text(TR("best", best), 64, h - 72, 14, "mono")
    end
  elseif state == "over" then
    drawBlock(w, h, TR("over"), TR("score", score), TR("again"))
    gfx.color(SAND)
    gfx.text(TR("best", best), 64, h - 72, 14, "mono")
  else
    drawHud(w, h)
    if paused then
      gfx.rect(0, 0, w, h, 0, "#0E151BB0")
      drawBlock(w, h, TR("paused"), "", TR("resume"))
    end
  end
  if showDebug then
    gfx.color("#FFFFFF99")
    gfx.text(TR("debug", active, tris, math.floor(sys.fps() + 0.5)), w - 420, h - 28, 12, "mono", "right", 400)
  end
end

function app.event(e)
  if e.type == "keydown" and e.key then
    held[e.key] = true
    if e.key == "enter" or e.key == "space" then confirm()
    elseif (e.key == "escape" or e.key == "p") and state == "play" then paused = not paused
    elseif e.key == "f3" then showDebug = not showDebug end
  elseif e.type == "keyup" and e.key then
    held[e.key] = nil
  elseif e.type == "paddown" then
    if e.pad == "a" then confirm()
    elseif e.pad == "plus" and state == "play" then paused = not paused
    elseif e.pad == "minus" then showDebug = not showDebug end
  elseif e.type == "mousedown" then
    if state == "play" and not paused then touch.on, touch.x, touch.y = true, e.x or 0, e.y or 0
    else confirm() end
  elseif e.type == "mousemove" and touch.on then
    touch.x, touch.y = e.x or touch.x, e.y or touch.y
  elseif e.type == "mouseup" then
    touch.on = false
  end
end

function app.suspend() if state == "play" then paused = true end end
function app.focus(focused) if not focused and state == "play" then paused = true end end

return app
```

## 5. Nasıl çalışıyor

**Renderer isteğe bağlıdır ve hayır diyebilir.** `g3d.renderer("pbr")`, karelerin kullanacağı renderer'ı döndürür:
`"pbr"`, ya da GPU yolu kapalıysa, konsol OpenGL ES 3 sunmuyorsa veya sistem ayarı kapattıysa `"basic"`. Oyun bu cevabı
`active`'te tutar ve `"basic"`ta çekirdekleri ve feneri `"unlit"` bayrağıyla çizer; böylece yine ışık gibi görünürler.
Gölgeler, nokta ışıklar ve post efektler orada gösterilmez; oyun oynanabilir kalır. `app.load`'da çağırın: ilk `"pbr"`
çağrısı shader'ları kurar (yaklaşık yarım saniye).

**Ayarlar uygulamanındır.** `g3d.shadows`, `g3d.postfx` ve `g3d.environment` bir kez verilir ve siz değiştirene kadar
kalır; başka uygulamalar onları görmez. `distance = 24` avlunun görünen kısmını kapsar ve gölge haritasını keskin tutar.
`msaa = 0` bütçe dostu başlangıçtır; ölçmeden yükseltmeyin.

**Işıkların id'si var.** Her çekirdek `app.load`'da bir nokta ışık alır ve bütün oyun boyunca onu tutar: `placeCore`
ışığı `g3d.updateLight(id, {x, y, z})` ile taşır (yalnızca verdiğiniz alanlar değişir). Beş ışık sınırların çok altında
kalır (16 ışık, her nesnenin yakınındaki en güçlü 8'i).

**Parlama bir materyaldir.** `g3d.material(coreMesh, {emissive = AMBER, emissiveStrength = 6})`: 1'in üstündeki ışıma
bloom `threshold`'undan (1) parlaktır, bu yüzden çekirdekler bloom'a taşar. Çekirdekler `flat(true)` ile 6 x 4'lük bir
küredir: bir primitive'den kesme taş.

**Instancing.** Sütun ve sandık dönüşümleri, kopya başına 7 sayılık (`x, y, z, rx, ry, rz, scale`) düz listelerdir ve
`buildYard`'da bir kez kurulur. pbr renderer'da 128'e kadar kopya tek çağrıda GPU'ya gider; `"basic"`ta aynı çağrı
onları tek tek çizer.

**Yer tutucusu olan bir model.** `g3d.loadModel`, `models/keeper.glb`'yi arka planda parse eder ve bir timer gibi geri
çağırır; o zamana kadar, ya da dosya yoksa veya bozuksa, bekçi bir silindir ve parlayan bir küredir. Oyun hiçbir
dosyayı beklemez ve bir dosya yüzünden hiç çökmez. Klipler yalnızca durum değişince çalınır (`Idle` / `Run`, 0,2 sn
crossfade); dosyada olmayan bir klip için `play` false döndürür, zararsızdır.

**Hareket ve çarpışma.** Girdi; stick'ten, D-pad'den, WASD / ok tuşlarından ya da ekrandaki parmaktan bir hareket
vektörü olarak okunur. Hız ona doğru yumuşakça yaklaşır (yumuşak kalkış ve duruş), konum avluya sıkıştırılır ve bekçi
her sandığın çemberinden dışarı itilir. `dt` 1/20 sn'ye sınırlanır; yavaş bir kare onu sandığın içinden geçiremez.
Yaw `math.atan(vx, vz)`'den gelir: bir model yaw 0'da +Z'ye bakar.

**Hiçbir callback süre sınırına yaklaşmaz.** Yükleme arka planda, `freeSpot` en fazla 20 konum dener ve
`g3d.updateLight`'ın kısa seçenek tablolarından başka hiçbir şey her karede tablo oluşturmaz.

## 6. Model

`models/keeper.glb` sizin karakterinizdir. Oyun onu 1,7 m isteğiyle yükler (`g3d.loadModel(path, 1.7, ...)` en uzun
kenarı 1,7'ye ölçekler ve y = 0'a oturtur); yani her export ölçeği çalışır, ama yine de doğru export edin:

- glTF binary (`.glb`), metre, +Y yukarı, +Z'ye bakan, pivot ayaklarda, transform'lar uygulanmış.
- PBR dokuları gömülü: base colour, normal, ORM (occlusion R, roughness G, metallic B), fener için emissive.
- `Idle` ve `Run` adlı klipler (başka adlar: iki `play` çağrısını değiştirin).
- 3 000 - 8 000 üçgen; GPU'da tek çizimde 32 kemiğe kadar skin'lenir.

AI ile üretilmiş modeller dahil, export ve doku kontrol listesinin tamamı [AI_WORKFLOW.tr.md](AI_WORKFLOW.tr.md)'de.

## 7. JavaScript

Aynı oyun `main.js` olarak. `app.json`'da `"main": "main.js"` yazın; `lang/en.json` aynı dosyadır.

```js
// Lumen Yard: gather glowing cores in a walled courtyard at dusk (SDK 1.9, pbr renderer). JavaScript version.
// Art direction: see the Lua version (slate ink, sandstone, amber cores, teal lamp; lowercase bold title; eased
// high follow camera; soft notes a fifth apart; text on a thin amber line, no panels).
const INK = "#0E151B", SAND = "#C9B79C", AMBER = "#FFB24A", TEAL = "#4FD1C5";
const YARD = 10;       // the courtyard spans -YARD..YARD on x and z (metres)
const CORES = 4;       // cores on the ground at a time, each with its own point light
const ROUND = 60;      // seconds per round

let active = "basic";  // the renderer frames use: "pbr", or "basic" when the GPU does not offer it
let keeper = null;     // the model, once g3d.loadModel resolved
let ground, pillar, crate, coreMesh, body, head, lamp;
const pillars = [], crates = [];   // g3d.drawInstanced transforms: x, y, z, rx, ry, rz, scale per copy
const solids = [];                 // circles {x, z, r} the keeper cannot enter
const cores = [];
const player = { x: 0, z: 0, yaw: 0, vx: 0, vz: 0, clip: "" };
const cam = { x: 0, z: 8 };
let state = "title", paused = false, showDebug = false;
let score = 0, best = 0, timeLeft = ROUND, t = 0, flash = 0;
const held = new Set();
const touch = { on: false, x: 0, y: 0 };
let screenW = 1280, screenH = 720;

// ------------------------------------------------------------------ renderer and scene
function setupRenderer() {
  active = g3d.renderer("pbr");    // "pbr", or "basic": the same calls still draw
  g3d.shadows({ enabled: true, quality: "medium", distance: 24 });
  g3d.postfx({ exposure: 1.1, tonemap: "filmic", bloom: 0.09, threshold: 1.0, msaa: 0 });
  g3d.environment({ sky: "#3A4E66", ground: "#2B241E", intensity: 0.8, sun: 1.8 });
}

function buildYard() {
  ground = g3d.mesh("plane", YARD * 2 + 4, YARD * 2 + 4, 8);
  ground.setColor("#5E574C");
  g3d.material(ground, { metallic: 0, roughness: 0.9 });

  pillar = g3d.mesh("box", 0.6, 3.2, 0.6);
  pillar.setColor(SAND);
  g3d.material(pillar, { roughness: 0.7 });
  for (let i = 0; i < 28; i++) {             // a colonnade: 7 pillars on each side
    const side = Math.floor(i / 7), k = i % 7;
    const u = -YARD + 1 + k * (YARD * 2 - 2) / 6;
    const [x, z] = [[u, -YARD], [YARD, u], [-u, YARD], [-YARD, -u]][side];
    pillars.push(x, 1.6, z, 0, 0, 0, 1);
  }

  crate = g3d.mesh("box", 1, 1, 1);
  crate.setColor("#7A5A3C");
  g3d.material(crate, { roughness: 0.6 });
  [[-4, -3], [5, -5], [-6, 5], [3, 4], [0, -7], [7, 2]].forEach(([x, z], i) => {
    crates.push(x, 0.5, z, 0, (i + 1) * 0.7, 0, 1);
    solids.push({ x, z, r: 0.75 });
  });

  coreMesh = g3d.mesh("sphere", 0.28, 6, 4);  // few segments: a cut gem
  coreMesh.flat(true);
  coreMesh.setColor(AMBER);
  g3d.material(coreMesh, { emissive: AMBER, emissiveStrength: 6, roughness: 0.3 });   // above 1: it blooms

  // the keeper drawn from primitives until (or unless) models/keeper.glb arrives
  body = g3d.mesh("cylinder", 0.32, 1.1, 16);
  body.setColor("#2E3A44");
  g3d.material(body, { metallic: 0.6, roughness: 0.35 });
  head = g3d.mesh("sphere", 0.26, 20, 14);
  head.setColor(TEAL);
  g3d.material(head, { emissive: TEAL, emissiveStrength: 3 });
}

function freeSpot() {
  let x = 0, z = 0;
  for (let n = 0; n < 20; n++) {             // bounded: never loops forever
    x = (Math.random() * 2 - 1) * (YARD - 2);
    z = (Math.random() * 2 - 1) * (YARD - 2);
    const farFromPlayer = (x - player.x) ** 2 + (z - player.z) ** 2 > 9;
    if (farFromPlayer && !solids.some((s) => (x - s.x) ** 2 + (z - s.z) ** 2 < (s.r + 0.8) ** 2)) break;
  }
  return [x, z];
}

function placeCore(c) {
  [c.x, c.z] = freeSpot();
  c.phase = Math.random() * 6.28;
  g3d.updateLight(c.light, { x: c.x, y: 0.9, z: c.z });
}

async function loadKeeper() {
  try {
    keeper = await g3d.loadModel("bundle:/models/keeper.glb", 1.7);   // parsed in the background
    keeper.play("Idle");
  } catch (e) {
    console.log(`keeper.glb not loaded (${e.message || e}): drawing the primitive keeper`);
  }
}

// ------------------------------------------------------------------ rounds
function startRound() {
  state = "play";
  paused = false;
  score = 0;
  timeLeft = ROUND;
  Object.assign(player, { x: 0, z: 0, vx: 0, vz: 0 });
  cam.x = 0;
  cam.z = 8;
  cores.forEach(placeCore);
}

function finishRound() {
  state = "over";
  if (score > best) {
    best = score;
    store.set("best", best);
  }
}

function collect(c) {
  score++;
  timeLeft = Math.min(ROUND, timeLeft + 1.5);
  flash = 1;
  const step = score % 5;
  audio.tone(523 + step * 66, 0.16, 0.22, "triangle");
  audio.tone(784 + step * 99, 0.24, 0.10, "sine");   // a fifth above, quieter
  sys.vibrate(0.25, 40);
  placeCore(c);
}

function confirm() {
  if (state === "title" || state === "over") startRound();
  else if (paused) paused = false;
}

// ------------------------------------------------------------------ input
function moveInput() {
  let [x, y] = input.stick("left");
  y = -y;                                    // the stick reports up as positive
  if (input.down("left") || held.has("left") || held.has("a")) x = -1;
  if (input.down("right") || held.has("right") || held.has("d")) x = 1;
  if (input.down("up") || held.has("up") || held.has("w")) y = -1;
  if (input.down("down") || held.has("down") || held.has("s")) y = 1;
  if (touch.on) {                            // touch: walk towards the finger
    const dx = touch.x - screenW / 2, dy = touch.y - screenH / 2;
    const len = Math.hypot(dx, dy);
    if (len > 24) { x = dx / len; y = dy / len; }
  }
  const len = Math.hypot(x, y);
  return len > 1 ? [x / len, y / len] : [x, y];
}

// ------------------------------------------------------------------ callbacks
app.load = () => {
  best = store.get("best", 0);
  setupRenderer();
  buildYard();
  for (let i = 0; i < CORES; i++) {
    const c = { light: g3d.addLight({ type: "point", color: AMBER, intensity: 4, range: 5 }) };
    cores.push(c);
    placeCore(c);
  }
  lamp = g3d.addLight({ type: "point", x: 0, y: 1.9, z: 0, color: TEAL, intensity: 3, range: 6 });
  loadKeeper();                              // returns at once; the window keeps drawing
};

app.update = (dt) => {
  dt = Math.min(dt, 1 / 20);                 // a long frame must not move things through walls
  t += dt;
  flash = Math.max(0, flash - dt * 3);
  if (keeper) keeper.update(dt);
  if (state !== "play" || paused) return;

  timeLeft -= dt;
  if (timeLeft <= 0) {
    finishRound();
    return;
  }

  const [mx, my] = moveInput();
  const k = Math.min(1, dt * 10);            // ease the velocity: soft starts and stops
  player.vx += (mx * 5.5 - player.vx) * k;
  player.vz += (my * 5.5 - player.vz) * k;
  let nx = Math.max(-YARD + 1, Math.min(YARD - 1, player.x + player.vx * dt));
  let nz = Math.max(-YARD + 1, Math.min(YARD - 1, player.z + player.vz * dt));
  for (const s of solids) {                  // push out of the crates
    const dx = nx - s.x, dz = nz - s.z, d = Math.hypot(dx, dz), r = s.r + 0.35;
    if (d < r && d > 1e-6) { nx = s.x + dx / d * r; nz = s.z + dz / d * r; }
  }
  player.x = nx;
  player.z = nz;
  const moving = player.vx * player.vx + player.vz * player.vz > 0.2;
  if (moving) player.yaw = Math.atan2(player.vx, player.vz);   // a model faces +Z at yaw 0
  if (keeper) {
    const want = moving ? "Run" : "Idle";
    if (want !== player.clip) {
      player.clip = want;
      keeper.play(want, { loop: true, fade: 0.2 });
    }
  }
  g3d.updateLight(lamp, { x: player.x, y: 1.9, z: player.z });

  for (const c of cores) {
    if ((c.x - player.x) ** 2 + (c.z - player.z) ** 2 < 0.8) collect(c);
  }

  const e = Math.min(1, dt * 4);             // eased follow camera
  cam.x += (player.x - cam.x) * e;
  cam.z += (player.z + 8 - cam.z) * e;
};

function drawScene(w, h) {
  g3d.begin(0, 0, w, h, 50, 0.1, 60);
  if (state === "title") {
    const a = t * 0.12;
    g3d.camera(Math.sin(a) * 14, 6, Math.cos(a) * 14, 0, 1, 0);
  } else {
    g3d.camera(cam.x, 9, cam.z, cam.x, 0.6, cam.z - 8);
  }
  g3d.light(-0.6, 0.45, -0.35, 0.25, "#FFB98A");   // a low dusk sun: direction to it, ambient, colour
  g3d.fog(INK, 18, 45);
  g3d.draw(ground, 0, 0, 0);
  g3d.drawInstanced(pillar, pillars);        // 28 pillars, one GPU call on the pbr renderer
  g3d.drawInstanced(crate, crates);
  const flags = active === "pbr" ? "" : "unlit";   // on "basic" the glowing parts are drawn unlit
  for (const c of cores) {
    g3d.draw(coreMesh, c.x, 0.75 + Math.sin(t * 2 + c.phase) * 0.12, c.z, t, t * 0.7, 0, 1, 1, 1, null, flags);
  }
  if (keeper) {
    g3d.draw(keeper, player.x, 0, player.z, 0, player.yaw, 0);
  } else {
    g3d.draw(body, player.x, 0.55, player.z, 0, player.yaw, 0);
    g3d.draw(head, player.x, 1.35, player.z, 0, 0, 0, 1, 1, 1, null, flags);
  }
  return g3d.finish();
}

const hairline = (x, y, h) => gfx.rect(x, y, 3, h, 0, AMBER);

function drawHud(w, h) {
  hairline(28, 28, 58);
  gfx.color(SAND);
  gfx.text(TR("cores"), 42, 28, 13, "semibold");
  gfx.color(flash > 0 ? AMBER : "#FFFFFF");
  gfx.text(String(score), 42, 44, 34 + flash * 8, "monobold");
  const frac = Math.max(0, timeLeft / ROUND);   // the light that is left: a thin bar along the bottom
  gfx.rect(0, h - 4, w, 4, 0, "#FFFFFF22");
  gfx.rect(0, h - 4, w * frac, 4, 0, frac < 0.2 ? "#FF5A3C" : AMBER);
  gfx.color(SAND);
  gfx.text(String(Math.ceil(timeLeft)).padStart(2, "0"), w - 120, 28, 34, "monobold", "right", 92);
}

function drawBlock(w, h, big, line1, line2) {
  gfx.gradient(0, h * 0.4, w, h * 0.6, "#0E151B00", "#0E151BE6");
  const x = 64, y = h - 220;
  hairline(x - 22, y + 8, 140);
  gfx.color("#FFFFFF");
  gfx.text(big, x, y, 64, "bold");
  gfx.color(SAND);
  gfx.text(line1, x, y + 78, 18, "italic");
  gfx.alpha(0.55 + Math.sin(t * 3) * 0.45);
  gfx.color(AMBER);
  gfx.text(line2, x, y + 116, 16, "semibold");
  gfx.unalpha();
}

app.draw = (w, h) => {
  screenW = w;
  screenH = h;
  gfx.clear(INK);
  const tris = drawScene(w, h);
  if (state === "title") {
    drawBlock(w, h, TR("title"), TR("tagline"), TR("start"));
    if (best > 0) {
      gfx.color(SAND);
      gfx.text(TR("best", best), 64, h - 72, 14, "mono");
    }
  } else if (state === "over") {
    drawBlock(w, h, TR("over"), TR("score", score), TR("again"));
    gfx.color(SAND);
    gfx.text(TR("best", best), 64, h - 72, 14, "mono");
  } else {
    drawHud(w, h);
    if (paused) {
      gfx.rect(0, 0, w, h, 0, "#0E151BB0");
      drawBlock(w, h, TR("paused"), "", TR("resume"));
    }
  }
  if (showDebug) {
    gfx.color("#FFFFFF99");
    gfx.text(TR("debug", active, tris, Math.round(sys.fps())), w - 420, h - 28, 12, "mono", "right", 400);
  }
};

app.event = (e) => {
  if (e.type === "keydown" && e.key) {
    held.add(e.key);
    if (e.key === "enter" || e.key === "space") confirm();
    else if ((e.key === "escape" || e.key === "p") && state === "play") paused = !paused;
    else if (e.key === "f3") showDebug = !showDebug;
  } else if (e.type === "keyup" && e.key) {
    held.delete(e.key);
  } else if (e.type === "paddown") {
    if (e.pad === "a") confirm();
    else if (e.pad === "plus" && state === "play") paused = !paused;
    else if (e.pad === "minus") showDebug = !showDebug;
  } else if (e.type === "mousedown") {
    if (state === "play" && !paused) Object.assign(touch, { on: true, x: e.x ?? 0, y: e.y ?? 0 });
    else confirm();
  } else if (e.type === "mousemove" && touch.on) {
    touch.x = e.x ?? touch.x;
    touch.y = e.y ?? touch.y;
  } else if (e.type === "mouseup") {
    touch.on = false;
  }
};

app.suspend = () => { if (state === "play") paused = true; };
app.focus = (focused) => { if (!focused && state === "play") paused = true; };
```

Lua'dan farklar:

- Callback verilmeyen `g3d.loadModel(path, size)` bir **Promise** döndürür; onu `try` / `catch` içinde `await` edin
  (kimsenin karşılamadığı reddedilmiş Promise hata ekranını açar).
- Seçenekler nesnedir (`{ quality: "medium" }`), mesh ve modeller `.` kullanır (`mesh.setColor`, `keeper.play`).
- `input.stick()` dizi döndürür (`const [x, y] = ...`); `g3d.draw`'un "tint yok" argümanı `null`'dır.
- `Math.atan2(vx, vz)`, Lua'daki `math.atan(vx, vz)`'dir.

## 8. Python ve C

Python ve C aynı fonksiyonları çağırır. Aşağıdaki programlar eksiksizdir (`py_check.py` ve `rt_check.py`'den geçer)
ama küçüktür: sahne kurulumu, hareket eden bir ışık, instancing ve callback'iyle model. Oyun mantığını Lua sürümünden
satır satır taşıyın.

**Python** (`main.py`, `"main": "main.py"`). Seçenekler dict'tir, `True` / `False` / `None`; `g3d.loadModel(path,
size, callback)` `callback(model, err)`'i çağırır; `model.play(clip, loop, speed, fade)` sıralı değerler alır; `math`
import edilir. Python (pocketpy) en yavaş runtime'dır: kare başına işi küçük tutun.

```python
import math

AMBER = "#FFB24A"


class Yard:
    def load(self, arg):
        self.keeper = None
        self.t = 0.0
        self.active = g3d.renderer("pbr")                  # "pbr" or "basic"
        g3d.shadows({"enabled": True, "quality": "medium", "distance": 24})
        g3d.postfx({"exposure": 1.1, "tonemap": "filmic", "bloom": 0.09, "msaa": 0})
        g3d.environment({"sky": "#3A4E66", "ground": "#2B241E", "intensity": 0.8, "sun": 1.8})
        self.ground = g3d.mesh("plane", 24, 24, 8)
        g3d.material(self.ground, {"metallic": 0, "roughness": 0.9})
        self.core = g3d.mesh("sphere", 0.28, 6, 4)
        self.core.setColor(AMBER)
        g3d.material(self.core, {"emissive": AMBER, "emissiveStrength": 6})
        self.light = g3d.addLight({"type": "point", "y": 0.9, "color": AMBER, "intensity": 4, "range": 5})
        self.pillar = g3d.mesh("box", 0.6, 3.2, 0.6)
        self.pillars = []
        for i in range(7):                                  # 7 numbers per copy: x, y, z, rx, ry, rz, scale
            self.pillars += [-9 + i * 3, 1.6, -10, 0, 0, 0, 1]
        g3d.loadModel("bundle:/models/keeper.glb", 1.7, self.on_keeper)   # callback(model, err)

    def on_keeper(self, model, err):
        if model:
            self.keeper = model
            model.play("Idle", True, 1.0, 0.2)              # clip, loop, speed, fade
        else:
            print("keeper.glb not loaded: " + str(err))

    def update(self, dt):
        self.t += dt
        g3d.updateLight(self.light, {"x": math.cos(self.t) * 2, "z": math.sin(self.t) * 2})
        if self.keeper:
            self.keeper.update(dt)

    def draw(self, w, h):
        gfx.clear("#0E151B")
        g3d.begin(0, 0, w, h, 50, 0.1, 60)
        g3d.camera(0, 9, 8, 0, 0.6, 0)
        g3d.light(-0.6, 0.45, -0.35, 0.25, "#FFB98A")
        g3d.draw(self.ground, 0, 0, 0)
        g3d.drawInstanced(self.pillar, self.pillars)
        flags = "" if self.active == "pbr" else "unlit"
        g3d.draw(self.core, math.cos(self.t) * 2, 0.75, math.sin(self.t) * 2, 0, self.t, 0, 1, 1, 1, None, flags)
        if self.keeper:
            g3d.draw(self.keeper, 0, 0, 0)
        g3d.finish()


app = Yard()
```

**C** (`main.c`, `"runtime": "c"`). Her seçenek tablosu **JSON metnidir** (`g3d_shadows("{\"quality\": \"medium\"}")`,
`g3d_addLight(...)` id döndürür); `nxv_fmt` sayılarla JSON kurar; `g3d_renderer` `"pbr"` ya da `"basic"` döndürür;
`g3d_drawInstanced(obj, floats, count, tint, flags)` kopya başına 7 float ve kopya sayısını alır;
`g3d_loadModel(path, size, fn, user)` `fn(model, error, user)`'ı çağırır; model çağrıları önce modeli alır
(`g3d_modelPlay`, `g3d_modelUpdate`). C, script süre sınırı olmadan çalışır ve deneyimli geliştiriciler içindir
([C_APPS.tr.md](C_APPS.tr.md)).

```c
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <nexvyn.h>

static int ground, core, pillar, keeper, light;
static bool pbr;
static float t;
static float pillars[7 * 7];   /* 7 floats per copy: x, y, z, rx, ry, rz, scale */

static void on_keeper(int model, const char* error, void* user) {
    if (model) {
        keeper = model;
        g3d_modelPlay(model, "Idle", true, 1, 0.2f);
    } else {
        printf("keeper.glb not loaded: %s\n", error);
    }
}

void app_load(const char* arg) {
    pbr = strcmp(g3d_renderer("pbr"), "pbr") == 0;    /* options below are JSON text */
    g3d_shadows("{\"enabled\": true, \"quality\": \"medium\", \"distance\": 24}");
    g3d_postfx("{\"exposure\": 1.1, \"tonemap\": \"filmic\", \"bloom\": 0.09, \"msaa\": 0}");
    g3d_environment("{\"sky\": \"#3A4E66\", \"ground\": \"#2B241E\", \"intensity\": 0.8, \"sun\": 1.8}");
    ground = g3d_mesh("plane", 24, 24, 8, 0);
    g3d_material(ground, "{\"metallic\": 0, \"roughness\": 0.9}", NULL);
    core = g3d_mesh("sphere", 0.28f, 6, 4, 0);
    g3d_setColor(core, "#FFB24A");
    g3d_material(core, "{\"emissive\": \"#FFB24A\", \"emissiveStrength\": 6}", NULL);
    light = g3d_addLight("{\"type\": \"point\", \"y\": 0.9, \"color\": \"#FFB24A\", \"intensity\": 4, \"range\": 5}");
    pillar = g3d_mesh("box", 0.6f, 3.2f, 0.6f, 0);
    for (int i = 0; i < 7; i++) {
        float* p = &pillars[i * 7];
        p[0] = -9 + i * 3; p[1] = 1.6f; p[2] = -10; p[3] = 0; p[4] = 0; p[5] = 0; p[6] = 1;
    }
    g3d_loadModel("bundle:/models/keeper.glb", 1.7f, on_keeper, NULL);
}

void app_update(float dt) {
    t += dt;
    g3d_updateLight(light, nxv_fmt("{\"x\": %.3f, \"z\": %.3f}", cosf(t) * 2, sinf(t) * 2));
    if (keeper) g3d_modelUpdate(keeper, dt);
}

void app_draw(float w, float h) {
    gfx_clear("#0E151B");
    g3d_begin(0, 0, w, h, 50, 0.1f, 60);
    g3d_camera(0, 9, 8, 0, 0.6f, 0);
    g3d_light(-0.6f, 0.45f, -0.35f, 0.25f, "#FFB98A");
    g3d_draw(ground, 0, 0, 0, 0, 0, 0, 1, 1, 1, NULL, NULL);
    g3d_drawInstanced(pillar, pillars, 7, NULL, NULL);
    g3d_draw(core, cosf(t) * 2, 0.75f, sinf(t) * 2, 0, t, 0, 1, 1, 1, NULL, pbr ? NULL : "unlit");
    if (keeper) g3d_draw(keeper, 0, 0, 0, 0, 0, 0, 1, 1, 1, NULL, NULL);
    g3d_finish();
}
```

Squirrel ve Java SDK 1.8'de donduruldu: uygulamalarını çalıştırmaya devam ederler ama pbr çağrıları yoktur. 3B oyunlara
Lua, JavaScript, Python ya da C ile başlayın.

## 9. Denetleme ve çalıştırma

1. **PC'de:** `python SDK/Tools/nxv/nxv.py check LumenYard.nxvapp` manifest'i, izinleri, çevirileri ve ikonu denetler.
   `--sdk <Nexvyn OS kaynak checkout'u>` ile dilin checker'ını da çalıştırır; o da oyunu sahte bir SDK'ya karşı rastgele
   girdiyle yüzlerce kare oynatır ([Tools/nxv](../Tools/nxv/README.tr.md)).
2. **Konsolda:** *Connect to PC* FTP sunucusunu çalıştırırken
   `python SDK/Tools/nxv/nxv.py push LumenYard.nxvapp --host <konsol-ip>`, sonra oyunu Başlatıcı'dan açın. Hatalar
   pencerede satır numarasıyla görünür ve `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`'a yazılır; `print()` çıktısı da
   oraya gider.
3. **`models/keeper.glb` olmadan** log bunu bir kez yazar ve primitive bekçi çizilir: bu yolu da deneyin.
4. **Konsolda ölçün**, PC'de değil: renderer'ı, üçgen sayısını ve fps'i gösteren hata ayıklama satırı için F3'e (ya da
   **−**'ye) basın. `msaa` 0 / 2 / 4 ve gölge `"medium"` / `"high"` karşılaştırın; doğru görünen en ucuz ayarda kalın.

## 10. Yayından önce

Bu tarif çalışan bir temeldir, bitmiş bir mağaza oyunu değil. Mağaza incelemesi [GAME_FEEL.tr.md](GAME_FEEL.tr.md)
(bölüm 8) ve [SOUND_DESIGN.tr.md](SOUND_DESIGN.tr.md)'deki kalite çıtasını denetler:

- **Ses.** İki `audio.tone` notasını ses kitinin katmanlı tarifleriyle değiştirin
  ([Languages/lua/kits](../Languages/lua/kits/), `sfx.lua`; JavaScript: `sfx.js`), bir müzik döngüsü ve ortam sesi
  ekleyin, oyuncuya müzik ve efekt ses ayarı verin.
- **His.** Çekirdek toplanınca parçacıklar, kısa bir kamera sarsıntısı, başlıkla oyun arasında bir geçiş: his kiti
  (`juice.lua` / `juice.js`) bunları hazır yapı taşları olarak verir.
- **Kendi görünümünüz.** Bu sayfanınki değil; sizin paletiniz, başlık işleyişiniz ve HUD biçiminiz.
- **Mağaza ikonu:** oyununuzun kendi modelinden render edilmiş key art ([Tools/icon](../Tools/icon/README.tr.md)).
- **Ekran görüntüleri** İngilizce arayüzle; konsolda denedikten sonra `"targetSdk": "1.9"`.
- Yayın adımları: [Publishing/PUBLISHING.tr.md](../Publishing/PUBLISHING.tr.md).

## Ayrıca bakın

[SDK başvurusu](../Reference/SDK.tr.md) (8b *3B modeller* ve *Modern görüntü*) · [Oyun yapmak](MAKE_A_GAME.tr.md) ·
[AI destekli iş akışı](AI_WORKFLOW.tr.md) · [Grafik, arayüz ve oyun hissi](GAME_FEEL.tr.md) ·
[Ses tasarımı](SOUND_DESIGN.tr.md) · [SDK sürümleri](SDK_VERSIONS.tr.md) · Örnek: [pbr3d](../Samples/lua/pbr3d/) ·
AI prompt'u: [3B oyun yapmak](../AI/tasks/make-3d-game.tr.md)
