# Nexvyn OS 2D oyun motoru: `nexvyn.game`

**Türkçe** · [English](GAME_ENGINE.en.md)

`nexvyn.game`, Nexvyn OS'un Lua uygulamaları için yazılmış küçük bir 2D oyun motorudur. LÖVE ya da Phaser'ın hafif bir
benzeri gibi düşünebilirsiniz: sahneler, sprite'lar, animasyon, tilemap, kamera, fizik, çarpışma, girdi eşleme,
tween, parçacıklar, ses, menüler ve kayıt hazır gelir. Motor tamamen Lua ile yazıldı ve SDK'nın `gfx`, `input`,
`audio` ve `store` API'lerinin üstünde çalışır. Sistemle birlikte `romfs:/System/Lua/nexvyn/` klasöründe gelir; her
uygulama tek satırla kullanabilir:

```lua
local game = require("nexvyn.game")
```

`require` önce uygulamanın kendi paketine bakar, modül orada yoksa sistem kütüphanesinden (`romfs:/System/Lua/`)
yükler. Yani motorun bir dosyasını kendi paketinize kopyalayıp değiştirirseniz sizin kopyanız kullanılır.

Bu belge adım adım bir oyun yaptırır. Bütün fonksiyonların listesi için: [`sdk/SDK.tr.md`](../Reference/SDK.tr.md), bölüm 8c.
Çalışan iki örnek oyun sistemde gelir:

- **Pixel Koşu** (`romfs/Applications/pixelrun.nxvapp`): platform oyunu. Tilemap, yerçekimi, altınlar, ezilen
  düşmanlar, kontrol noktaları, üç bölüm, sprite sheet ve animasyon.
- **Uzay Arenası** (`romfs/Applications/spacearena.nxvapp`): yukarıdan bakışlı nişancı. Dalgalar, parçacıklar,
  güçlendirmeler, çarpan, kaydedilen rekor. Bütün çizimler şekillerle yapılır.

## 1. Paket

Bir oyun, sıradan bir `.nxvapp` paketidir:

```
Oyunum.nxvapp/
├── app.json
├── main.lua
├── icon.png
├── lang/tr.json, lang/en.json
└── img/ (isteğe bağlı resimler)
```

`app.json` içinde oyunlar için iki ayar önemli:

```json
{"id": "com.adiniz.oyunum", "name": {"tr": "Oyunum", "en": "My Game"}, "category": "games",
 "window": {"width": 960, "height": 560, "minWidth": 480, "minHeight": 300, "resizable": true},
 "gamepad": true}
```

- `"gamepad": true`: pencere odaktayken kumanda oyuna gider (imleci geri almak için L+R'ye bir saniye basılır).
- `"resizable": true`: pencere boyutlanabilir. Kategorisi `games` olan ve kumandayı kullanan boyutlanabilir
  uygulamalar tam ekran açılır.

## 2. İlk oyun

`main.lua`:

```lua
local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui

local Oyun = {controls = true}    -- dokunmatik ekranda sanal çubuk göster

function Oyun:enter()
  self.puan = 0
  self.dunya = game.world{}
  self.top = self.dunya:add(game.sprite{x = 240, y = 135, r = 10, body = true, damping = 4})
  function self.top:render() G.circle(self.x, self.y, 10, "#FFCC00") end
  for i = 1, 8 do
    local a = self.dunya:add(game.sprite{x = math.random(20, 460), y = math.random(30, 250), r = 5}, "altinlar")
    function a:render() G.circle(self.x, self.y, 5, "#4CD964") end
  end
  self.dunya:collide(self.top, "altinlar", function(top, altin)
    altin.dead = true
    self.puan = self.puan + 1
    game.audio.play("coin")
  end)
end

function Oyun:update(dt)
  local mx, my = I.vector()            -- sol çubuk, yön tuşları, WASD ya da dokunmatik çubuk
  self.top.ax, self.top.ay = mx * 900, my * 900
  self.dunya:update(dt)
end

function Oyun:draw() self.dunya:draw() end
function Oyun:ui() U.text(TR("puan", self.puan), 8, 6, 14) end
function Oyun:restart() self:enter() end   -- duraklatma menüsüne "Baştan Başla" ekler

return game.run{width = 480, height = 270, scene = Oyun, background = "#1B2A41"}
```

`lang/tr.json`: `{"puan": "Puan: {0}"}`, `lang/en.json`: `{"puan": "Score: {0}"}`.

Burada olanlar:

- `game.run{...}` uygulama tablosunu (load, update, draw, event...) kendisi kurar ve döndürür; `main.lua` bununla
  biter.
- `width = 480, height = 270` **sanal ekranın** boyutudur. Motor her şeyi bu boyutta çizer ve pencereye ölçekler.
  Pencere büyüyünce ya da tam ekrana geçince oyun da büyür.
- Sahne (`Oyun`) düz bir Lua tablosudur. `enter`, `update`, `draw`, `ui` gibi metotları isteğe bağlıdır.
- `game.world` varlıkları, fiziği ve çarpışmaları tek yerde toplar.
- **+**, **Esc** ya da **P** duraklatma menüsünü açar: Devam Et, Baştan Başla, Ses, Dokunmatik kontroller,
  Oyundan çık. Pencere odağını kaybedince de oyun kendiliğinden duraklar.

## 3. Sanal ekran ve ölçekleme

`game.run` içindeki `scale` alanı:

| Değer | Ne yapar |
|---|---|
| `"expand"` (varsayılan) | Tasarım boyutu her zaman sığar; uzun kenar pencereye göre büyür. Siyah bant yok, geniş pencerede daha çok alan görünür. `game.width` / `game.height` değişebilir. |
| `"fit"` | Boyut sabit, kenarlarda bant (`border` rengi). |
| `"pixel"` | `fit` gibi ama ölçek tam sayı. |
| `"none"` | 1 birim = 1 piksel; sanal ekran pencerenin kendisi. |

Arayüzü `game.width` ve `game.height`'e göre yerleştirin (ör. sağ üst köşe için `game.width - 8`). Pencere
piksellerini sanal birime çevirmek için `game.toVirtual(px, py)`.

## 4. Sahneler

```lua
game.switch(Oyun, {bolum = 2})             -- yığını değiştir: kararır, yeni sahne girer, açılır
game.switch(Menu, nil, {fade = 0.5, color = "#FFFFFF"})
game.push(Envanter)                        -- üstüne aç (ör. menü, diyalog)
game.pop(sonuc)                            -- kapat; alttaki sahnenin resume(sonuc) metodu çağrılır
```

Geçiş türleri `transition` ile seçilir: `"fade"` (varsayılan), `"slide"` (`dir = "left"`, `"right"`, `"up"`,
`"down"`), `"wipe"`, `"circle"` (daralan bir daire), `"blinds"` (panjur) ve `"pixels"` (kare kare dağılma).
`game.scene.defaultTransition = "circle"` bütün geçişlerin varsayılanını değiştirir.

```lua
game.switch(Harita, nil, {transition = "circle", fade = 0.5, color = "#101020"})
game.switch(Oyun, nil, {transition = "slide", dir = "up"})
```

Sahne alanları: `transparent = true` (alttaki sahne de çizilir), `updateBelow = true` (alttaki de güncellenir),
`controls = true` (dokunmatik kontroller görünür), `pausable = false` (başlık ekranı gibi; duraklatma menüsü açılmaz).
Her sahnenin kendi tween yöneticisi vardır, sahne durunca onun animasyonları da durur.

## 5. Sprite, sprite sheet ve animasyon

```lua
local sheet = game.sheet("bundle:/img/kahraman.png", 64, 64,
  {spacing = 4, scale = 0.25, flipped = "bundle:/img/kahraman_flip.png"})
local animler = game.animations{
  bekle = {frames = "1-2", fps = 3},
  kos = {frames = "3-6", fps = 12},
  zipla = {frames = {7}, loop = false},
}
local k = game.sprite{x = 40, y = 80, sheet = sheet, anims = animler, w = 9, h = 14, body = true}
k:play("kos")
k.flipX = true                 -- sola bak
k.rotation, k.sx, k.alpha, k.z = 0.2, 1.5, 0.8, 10
```

- `x, y` sprite'ın merkezidir ve çarpışma kutusunun (`w, h` ya da `r`) da merkezidir. `ox, oy` resmin hangi
  noktasının `x, y`'ye geleceğini söyler (0..1, varsayılan 0.5). `dx, dy` çizimi kaydırır (ayakları zemine oturtmak
  için).
- **Neden `flipped`?** SDK resim parçalarını aynalayamıyor. Aynalı bir kopya verirseniz motor sola bakarken onu
  kullanır. `tools/gen_game_art.py` bu kopyayı nasıl ürettiğimizi gösterir.
- **Neden `scale = 0.25`?** Resimler doğrusal filtreyle büyütülür; 16 piksellik bir çizim 3 kat büyütülünce
  bulanıklaşır. Piksel sanatını 4 kat büyük kaydedip `scale = 0.25` vermek keskin kalmasını sağlar.
- Resim kullanmak istemezseniz `render` metodunu yazın ve `game.gfx` ile şekil çizin (Uzay Arenası böyle yapar):

```lua
local Gemi = game.class(game.Sprite)
function Gemi:render()
  game.gfx.polyT({14, 0, -9, -9, -5, 0, -9, 9}, self.x, self.y, self.angle, 1, 1, "#E8F4FF")
end
local gemi = Gemi{x = 100, y = 100, r = 8, body = true, damping = 3}
```

## 6. Tilemap

En kolay yol, bölümü yazıyla çizmek:

```lua
local satirlar = {
  "....................",
  "......ooo...........",
  ".....=====.......G..",
  "..P.......e.....####",
  "####################",
}
local harita = game.tilemap.fromStrings(satirlar, {
  ["#"] = 1, ["="] = 4,
  o = {object = "altin"}, e = {object = "dusman"}, P = {object = "oyuncu"}, G = {object = "bitis"},
}, {tileset = game.sheet("bundle:/img/tiles.png", 64, 64, {margin = 4, spacing = 8}),
    tiles = {[1] = {solid = true}, [4] = {oneway = true}, [5] = {hazard = true}}})

for _, o in ipairs(harita.objects) do
  if o.type == "altin" then ... end         -- o.x, o.y karonun merkezi
end
```

- Karo özellikleri: `solid` (katı), `oneway` (alttan geçilen platform), `color` (resim yoksa renkli kare),
  `draw = function(map, id, x, y, size)` (kendi çiziminiz) ve istediğiniz başka alanlar.
  `harita:findTile(x, y, w, h, "hazard")` bir dikdörtgende o özelliğe sahip karoyu bulur (dikenler için).
- Yalnızca kamerada görünen karolar çizilir; harita ne kadar büyük olursa olsun hız değişmez.
- JSON'dan: `game.tilemap.fromJSON("bundle:/bolum1.json")`.
- **Tiled** ile çizdiyseniz JSON olarak dışa aktarın (katman biçimi CSV) ve
  `game.tilemap.fromTiled("bundle:/maps/bolum1.json")` ile yükleyin. Karolarda `solid` / `oneway` (bool) özellikleri,
  katmanda `collide` ya da `above` özellikleri okunur; nesne katmanları `harita.objects` olur.

## 7. Dünya, fizik ve çarpışma

```lua
self.dunya = game.world{gravity = 920, map = harita, camera = self.kamera}
self.kahraman = self.dunya:add(Kahraman{x = 40, y = 80}, "kahraman")
self.dunya:add(Dusman{x = 300, y = 80}, "dusmanlar")

self.dunya:collide(self.kahraman, "dusmanlar", function(k, d)
  if k.vy > 0 and k.y < d.y then d.dead = true; k.vy = -230   -- üstüne bastı
  else self:ol() end
end)
self.dunya:collide("mermiler", "dusmanlar", vur)           -- yüzlerce nesne: uzamsal karma (spatial hash)
self.dunya:collide("kutular", "kutular", nil, true)        -- birbirini itsin
self.dunya:trigger{x = 400, y = 0, w = 32, h = 200, filter = "kahraman",
                   onEnter = function(k) game.toast("Kontrol noktası!") end}
```

`body = true` olan varlıklar her adımda hareket eder: `vx, vy` hız, `ax, ay` ivme, `gravity` yerçekimi çarpanı,
`dragX` (girdi yokken yavaşlama), `damping` (uzay oyunları için sürtünme), `maxVx, maxVy`, `bounce` (sekme).
Haritaya çarpınca `onFloor`, `onWall`, `onCeiling` dolar. Platform oyunu için tipik zıplama:

```lua
if self.onFloor then self.coyote = 0.1 else self.coyote = self.coyote - dt end
if game.input.pressed("jump") and self.coyote > 0 then self.vy = -320 end
if game.input.released("jump") and self.vy < -120 then self.vy = -120 end   -- kısa basışta alçak zıpla
```

`self.dropThrough = true` tek yönlü platformdan aşağı indirir.

## 8. Kamera

```lua
self.kamera = game.camera{lerp = 0.14, deadzone = {w = 36, h = 44}}
self.kamera:follow(self.kahraman)
self.kamera:setBounds(0, 0, harita.pixelWidth, harita.pixelHeight)
self.kamera:shake(4, 0.3)                    -- sarsıntı
self.kamera:attach(0.3) ... self.kamera:detach()   -- uzak tepeler: paralaks
local dx, dy = self.kamera:toWorld(game.input.pointer.x, game.input.pointer.y)
```

`world:draw()` kamerayı kendisi kullanır; kendi çizimleriniz için `attach` / `detach` kullanın.

```lua
self.kamera:zoomTo(2, 0.6, "inOutSine")      -- yumuşak yakınlaşma
self.kamera:panTo(kapi.x, kapi.y, 1.2)       -- kapıyı göster (bu sırada takip durur, sonra devam eder)
self.kamera:kick(0, 3)                       -- geri tepme: kısa bir itiş, kendiliğinden geri gelir
if self.kamera:visible(x, y, 16, 16) then ... end   -- kendi çizimleriniz için ekran dışını atlayın
game.flash("#FFFFFF", 0.15)                  -- bütün ekranda sönen bir renk (vuruş, toplama, şimşek)
```

## 8a. Işıklar

Karanlık bir sahnede meşale, fener ya da büyü ışığı:

```lua
self.isiklar = game.lights{ambient = 0.85, color = "#05060F", cell = 8}
self.mesale = self.isiklar:add{x = kahraman.x, y = kahraman.y, radius = 80, flicker = 0.08}
function Oyun:draw()
  self.dunya:draw()
  self.mesale.x, self.mesale.y = self.kahraman.x, self.kahraman.y
  self.isiklar:draw(self.kamera)       -- dünyadan sonra, arayüzden önce
end
```

`ambient` ışık olmayan yerin karanlığıdır (0 = yok, 1 = simsiyah). Ekran `cell` birimlik hücrelere bölünür, her
hücrenin karanlığı birkaç düzeye yuvarlanır ve bir satırdaki aynı düzeyli komşular tek dikdörtgenle çizilir; bu
yüzden birkaç ışıklı karanlık bir oda yüzlerce, binlerce değil, dikdörtgen tutar. Işık alanları: `radius`,
`intensity` (0..1), `flicker` (titreme), `on`. `isiklar:remove(isik)`, `isiklar:clear()`.

## 8b. Yol bulma (A*)

```lua
local yol = harita:path(dusman.x, dusman.y, kahraman.x, kahraman.y)   -- {x1, y1, x2, y2, ...} karo merkezleri
local yol = harita:path(x0, y0, x1, y1, {diagonal = true, maxNodes = 2000,
                                          avoid = function(tx, ty) return kapiKapali(tx, ty) end})
local karolar = game.path.find(gen, yuk, function(tx, ty) return izgara[ty][tx] == 0 end, sx, sy, hx, hy)
```

Katı karolar engeldir, tek yönlü platformlar geçilebilir. `cost(tx, ty)` bir karoya girmenin ek bedelini verir
(çamur, tehlike). `maxNodes` aramayı sınırlar; uzun bir arama kareyi dondurmak yerine vazgeçer. Çalışma dizileri
yeniden kullanılır, yalnızca sonuç tablosu oluşturulur. Düşmanlar için yolu her karede değil, saniyede birkaç kez
hesaplayın. Örnek: Studio'daki **Zindan** şablonu.

## 9. Girdi: eylemler

Oyun "A tuşu"nu değil "zıpla" eylemini sorar. Bir eyleme kumanda tuşları, klavye tuşları, çubuk yönleri ve
dokunmatik düğmeler bağlanır:

```lua
local I = game.input
I.bind("jump", {pad = {"a", "b"}, key = {"space", "up", "w"}, touch = {"button:jump", "stick:up"}})
I.bind("fire", {pad = "zr", key = "j", axis = "rx+"})
I.touchControls{stick = true, buttons = {{id = "jump", icon = "arrow_upward", action = "jump"}}}

if I.pressed("jump") then ... end     -- bu adımda basıldı
if I.down("fire") then ... end        -- basılı
local mx, my = I.vector()             -- -1..1 hareket (y aşağı)
local ax, ay, nisan = I.aim()         -- sağ çubuk
```

Hazır eylemler: `left`, `right`, `up`, `down` (yön tuşları, WASD, sol çubuk, dokunmatik çubuk), `confirm` (A, Enter,
Boşluk), `back` (B, Esc), `pause` (+, Esc, P).

**Dokunmatik:** ekrana dokunulunca sol yarıda sanal çubuk, sağ altta düğmeler, sağ üstte duraklat düğmesi
görünür; kumanda ya da klavye kullanılınca gizlenir (Retro uygulamasındaki gibi). Sahnenin `controls = true` olması
gerekir. SDK yalnızca tek parmağı bildirir; bu yüzden çubuğu tutarken düğmeye basılamaz. Zıplamayı `"stick:up"`'a
da bağlamak bu sorunu çözer (çubuğu yukarı itmek zıplatır). Duraklatma menüsündeki "Dokunmatik kontroller" ayarı
Otomatik / Açık / Kapalı arasında geçer; Açık iken fare ile de kullanılabilir.

**Tuş atama:** `game.run{controls = {"jump", "fire"}}` duraklatma menüsüne "Kontroller" ekler: oyuncu bir eylemi
seçer ve yeni tuşa ya da kumanda düğmesine basar (Esc vazgeçer). Seçimler motor ayarlarına kaydedilir ve oyun
eylemi sonradan yeniden bağlasa da korunur. Kendi ekranınız için: `I.listen(function(tur, deger) ... end)` (sonraki
tuş ya da düğme), `I.setBinding("jump", "key", "z")`, `I.binding("jump", "pad")`, `I.bindingLabel("jump")`
(ör. `"Space / A"`, ipuçları için), `I.resetBindings()`, `I.saveBindings(kayit)`, `I.loadBindings(kayit)`.

## 10. Tween ve zamanlayıcılar

```lua
game.tween.to(altin, 0.35, {y = altin.y - 18, alpha = 0}, "outQuad")
  :oncomplete(function() altin.dead = true end)
game.tween.to(yazi, 0.3, {sx = 1.2}, "outBack"):after(yazi, 0.2, {sx = 1})   -- zincir
game.tween.after(1.5, function() self:yeniDalga() end)
game.tween.every(0.5, yanipSon, 6)
```

Yumuşatma adları: `linear`, `inQuad`, `outQuad`, `inOutQuad`, `outCubic`, `outBack`, `outElastic`, `outBounce`
ve diğerleri (SDK.tr.md 8c); `smoothstep`, `inOutBack`, `inOutElastic`, `inOutBounce`, `inCirc`/`outCirc` da var.
`game.tween.steps(4)` dört adımlı, kesik bir yumuşatma verir (retro hareket, yanıp sönme).

```lua
game.tween.to(ok, 0.4, {y = ok.y - 6}, "inOutSine"):loop(0, true)   -- sonsuza dek aşağı yukarı (yoyo)
game.tween.to(isik, 0.2, {alpha = 0.3}):loop(3)                     -- 3 kez daha
game.tween.from(baslik, 0.6, {y = -40}, "outBack")                  -- -40'tan şimdiki yerine uçarak gelir
```

## 11. Parçacıklar

```lua
self.patlama = self.dunya:addEmitter(game.emitter{max = 400, life = {0.3, 0.9}, speed = {40, 260},
  size = {4, 0}, damping = 2.5, colors = {"#FFFFFF", "#FFC94D", "#FF4D6D00"}, shape = "square"})
self.patlama:emit(30, x, y)              -- tek seferde
self.iz.rate = 60; self.iz:start()       -- sürekli
```

Hazır efektler: `"explosion"`, `"smoke"`, `"sparkle"`, `"rain"`, `"snow"`, `"fire"`, `"confetti"`, `"dust"`,
`"blood"`, `"magic"`.

```lua
local yagmur = self.dunya:addEmitter(game.particles.preset("rain", {x = game.width / 2, y = -10}))
yagmur:start()                                              -- area ile ekranın üstüne yayılır
game.particles.burst(self.dunya, "explosion", x, y)        -- tek seferlik: dünya başına paylaşılan bir yayıcı
game.particles.burst(self.dunya, "confetti", x, y, 80)
```

`area = {w, h}` parçacıkları bir kutunun içinde doğurur (yağmur, kar). Renkler ömür boyunca karışır; son rengin
alfası 00 ise parçacık söner. Parçacıklar dizilerde tutulur, kare başına
çöp üretmez. Çok parçacık için `"square"` en hızlısıdır.

## 12. Ses ve müzik

```lua
local A = game.audio
A.play("coin")                                            -- hazır efektler: jump, coin, hit, explode, power, win...
A.define("ez", {wave = "square", volume = 0.2, notes = "E5:0.04 E6:0.08"})
A.play("bundle:/ses/kapi.wav")
A.song{bpm = 140, wave = "triangle", volume = 0.05, notes = "E5 G5 A5 G5 E5 D5 C5 -", bass = "A2:2 E3:2"}
A.music("bundle:/muzik/tema.ogg")
```

`A.song` hiç ses dosyası olmadan çalan küçük bir sentez melodisidir. Ses ayarı duraklatma menüsünden kapatılabilir
ve kaydedilir.

## 13. Arayüz ve menüler

```lua
U.text("Merhaba", 8, 6, 14)                                  -- gölgeli yazı
U.score(1234, game.width - 8, 6, 2, "#FFE066", 6, "right")   -- piksel yazıyla puan: 001234
U.pixelText("BÖLÜM 2", 0, 40, 3, "#FFFFFF", "center", game.width)
U.bar(8, 20, 60, 6, can / 100, "#FF5050")

self.menu = U.menu{width = 190, items = {
  {label = function() return TR("basla") end, action = function() game.switch(Oyun) end},
  {label = function() return TR("ses") end, action = sesiDegistir, left = sesiDegistir, right = sesiDegistir},
}}
function Baslik:update() self.menu:update() end            -- yön tuşları + A, ya da dokunma
function Baslik:ui() self.menu:draw(game.width / 2, 100) end
```

Menüler kumanda, klavye, fare ve dokunmatikle çalışır. `U.button(...)` tek düğme içindir. `game.toast("...")`
ekranın üstünde kısa bir bildirim gösterir.

Diğer parçalar:

```lua
U.hearts(can, 5, 8, 8, 12)                        -- dolu / boş kalpler (2.5 yarım kalp çizer; icon = "star" da olur)
ses = U.slider(ses, 20, 60, 140, 14)              -- 0..1, parmakla sürüklenir
acik = U.toggle(acik, 20, 90)                     -- anahtar
if U.iconButton("pause", game.width - 20, 20, 24) then game.pause() end
U.dialog{title = "Çıkılsın mı?", text = "İlerleme kaydedildi.", buttons = {"Çık", "Kal"},
         onClose = function(i) if i == 1 then sys.exit() end end}    -- kumandayla da kullanılan pencere
self.konusma = U.dialogue{lines = {"Merhaba!", {who = "Tilki", text = "Beni izle."}}, speed = 40}
-- update: self.konusma:update(dt), bitince self.konusma.done; ui: self.konusma:draw()
```

`U.dialogue` alttaki kutuda yazıyı harf harf yazar; A ya da dokunma önce satırı tamamlar, sonra bir sonrakine geçer.

## 14. Kayıt

```lua
local kayit = game.save.open("ilerleme")
kayit:set("bolum", 3)
local b = kayit:get("bolum", 1)
if kayit:best("rekor", puan) then game.toast("Yeni rekor!") end
kayit:best("sure1", sure, true)      -- küçük olan kazanır
```

Veriler uygulamanın `store` deposunda tutulur ve bir saniye içinde diske yazılır.

Kayıt yuvaları ("Oyun yükle" ekranları):

```lua
local yuva = game.save.slot(2)
yuva:set("bolum", 4)
yuva:stamp("Bölüm 4 · 120 altın")            -- zamanı ve kısa bir özeti saklar
for _, bilgi in ipairs(game.save.slots(3)) do
  -- bilgi.index, bilgi.used, bilgi.summary, bilgi.when ("2 dk önce"), bilgi.save
end
yuva:copyTo(3); game.save.slot(1):delete(); yuva:exists()
```

## 15. Hata ayıklama ve hız

- **F3** (ya da `game.debug = true`): FPS, adım sayısı, güncelleme ve çizim süresi, varlık, gövde, parçacık
  sayıları; çarpışma kutuları yeşil, tetik alanları sarı çizilir.
- Katmanın altında son 90 karenin süre grafiği (yeşil 16,7 ms altı, turuncu 33 ms altı, kırmızı üstü), işaretçinin
  sanal ve dünya koordinatları ve izlediğiniz değerler görünür: `game.watch("hiz", kahraman.vx)` (her karede),
  `game.unwatch("hiz")`.
- Güncelleme sabit adımlarla (saniyede 60) çalışır; çizim karede bir kez yapılır.
- Tilemap aynı renkli karoları bir satırda tek dikdörtgen olarak çizer; renkli karolu büyük haritalar daha az
  çizim çağrısı yapar.
- Sıcak döngülerde tablo oluşturmayın: şekiller için `G.polyT`, karşılaştırmalar için yerel değişkenler kullanın.
  Motorun kendisi her karede tablo üretmez (dünya, karma, parçacıklar, tween listeleri yeniden kullanılır).
- Çok sayıda nesne çarpışacaksa `world:collide("grupA", "grupB", ...)` kullanın; uzamsal karma kullanır.

## 16. Bilinen sınırlar

- SDK'da odak sorgusu yok. Motor odağı tahmin eder: kumanda tuşu basıldığı hâlde oyuna olay gelmiyorsa ya da
  pencere çizilmiyorsa (küçültülmüş) oyun duraklar. Başka pencereye dokunup sonra yalnızca sol çubuğu oynatmak
  algılanmaz.
- Tek dokunma noktası (çoklu dokunma yok).
- Resim parçaları aynalanamaz ve renklendirilemez (`flipped` kopya gerekir; `tint` yalnız tek resimde, döndürmeden).
- Tilemap çarpışması dikdörtgen karolarla; eğimli karo yok. Tiled'da yalnız ilk karo seti ve CSV katmanlar.
- Kamera döndürme yok.

---

## English summary

`nexvyn.game` is a pure-Lua 2D engine shipped in `romfs:/System/Lua/nexvyn/`. `require("nexvyn.game")` works from any app
because `require` now falls back to the system Lua library when a module is not in the app bundle (the bundle always
wins). `main.lua` ends with `return game.run{width, height, scene, ...}`, which builds the app table.

- **Loop:** fixed-step updates (1/60), one draw per frame, a virtual screen scaled to the window (`expand`, `fit`,
  `pixel`, `none`), automatic pause menu on + / Esc / P / touch pause button and when the window seems unfocused.
- **Scenes:** `game.switch/push/pop` with fade transitions; scene tables with `enter/leave/pause/resume/update/draw/ui/event`.
- **Entities:** `game.sprite`, `game.class(game.Sprite)`, sheets with mirrored copies for `flipX`, frame animations,
  origin, rotation, scale, alpha, tint, z-order, groups.
- **World:** physics bodies (velocity, acceleration, gravity, drag, damping, bounce), tile collision with one-way
  platforms, overlap callbacks through a spatial hash, trigger zones, emitters, camera-culled drawing, debug colliders.
- **Tilemaps:** from Lua tables, ASCII rows, a simple JSON format or Tiled JSON exports; collision flags; culled drawing.
- **Camera:** follow with deadzone and smoothing, bounds, zoom, shake, parallax, screen-to-world.
- **Input:** named actions over pad, keys, stick directions and on-screen touch controls (shown after a touch).
- **Also:** tweens with easing, chaining, loops/yoyo and `from`, timers, particle emitters with presets
  (`game.particles.preset/burst`), synth sound effects and tunes, music, HUD text, pixel-font scores, hearts,
  sliders, toggles, icon buttons, modal dialogs, a typewriter dialogue box, menus for pad and touch, key/value saves
  with numbered slots, F3 debug overlay with a frame-time graph and watched values.
- **Newer:** scene transitions (`fade`, `slide`, `wipe`, `circle`, `blinds`, `pixels`), camera `zoomTo`, `panTo`,
  `kick`, `visible`, `game.flash`, a darkness-and-lights overlay (`game.lights`), A* path finding (`map:path`,
  `game.path.find`), player key rebinding from the pause menu (`game.run{controls = {...}}`), `game.chance`,
  `game.randInt`, `game.weighted`.

Full API: `sdk/SDK.tr.md` section 8c. Samples: `pixelrun.nxvapp` (platformer) and `spacearena.nxvapp` (arena shooter).
Known limits: focus is inferred (no SDK focus query), single touch point, no mirrored or tinted image regions in the
SDK, no slopes, first Tiled tileset only, no camera rotation.
