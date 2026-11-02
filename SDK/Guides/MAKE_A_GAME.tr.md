# Oyun yap: eksiksiz tarif (SDK 1.8)

[English](MAKE_A_GAME.en.md) · **Türkçe**

Bu rehber sizi, ya da sizin için çalışan bir yapay zekâ asistanını, boş bir klasörden App Market'teki bitmiş bir
oyuna götürür: proje, 3B modeller, ses, oyun yapısı, çarpışma, Switch'te hız, size ait bir sanat yönü, mağaza ikonu,
diller ve yayın. Buradaki her kod bloğu SDK checker'larından geçti (`lua_check.py`, `js_check.mjs`, `py_check.py`);
her fonksiyon [SDK başvurusunda](../Reference/SDK.tr.md) var. Başvuruda olmayan bir şey yoktur.

Tam olarak bu yolla yapılmış küçük ama eksiksiz bir oyun SDK ile gelir: **Kor Tarlası / Ember Field** (Studio
şablonu *3B oyun: Kor Tarlası*, public depoda `SDK/Samples/lua/ember-field`). Bu rehberi okurken onun `main.lua`
dosyasına bakın. Görünüşünü kopyalamayın: nedenini ve kendi görünüşünüzü nasıl bulacağınızı 11. bölüm anlatır.

## İçindekiler

1. [Yolu seç](#1-yolu-seç)
2. [Projeyi kur](#2-projeyi-kur)
3. [Çalıştır ve test et](#3-çalıştır-ve-test-et)
4. [3B modeller: yap, dışa aktar, kontrol et](#4-3b-modeller-yap-dışa-aktar-kontrol-et)
5. [Donmadan yükleme](#5-donmadan-yükleme)
6. [Animasyon ve takılan nesneler](#6-animasyon-ve-takılan-nesneler)
7. [Görseller ve yazı tipleri](#7-görseller-ve-yazı-tipleri)
8. [Ses ve titreşim](#8-ses-ve-titreşim)
9. [Oyun yapısı: sahneler, girdi, kamera, çarpışma, kayıt, duraklatma](#9-oyun-yapısı)
10. [Switch'te hız ve bellek](#10-switchte-hız-ve-bellek)
11. [Kendinin yap: sanat yönü](#11-kendinin-yap-sanat-yönü)
12. [Mağaza ikonu ve key art](#12-mağaza-ikonu-ve-key-art)
13. [Diller](#13-diller)
14. [Yayınla](#14-yayınla)
15. [Aynı döngü JavaScript ve Python ile](#15-aynı-döngü-javascript-ve-python-ile)

## 1. Yolu seç

| İstediğiniz | Kullanın | Başlangıç |
|---|---|---|
| 2D oyun (platform, nişancı, bulmaca) | Lua + `nexvyn.game` motoru: sahneler, sprite'lar, tilemap, fizik, parçacık, tween | [GAME_ENGINE.tr.md](GAME_ENGINE.tr.md), Studio şablonları *Platform oyunu*, *Arena / uzay nişancı* |
| 3B araçta yapılmış modellerle 3B oyun | Lua (ya da JavaScript, Python) + `g3d` ve `g3d.loadModel` | bu rehber, *3B oyun: Kor Tarlası* şablonu |
| Blok dünyası | JavaScript + `g3d.voxels` (chunk, ışık, ray cast, kutu fiziği) | SDK başvurusu 8b, *Voksel dünyalar* |

**Diller.** Yeni API'ler Lua, JavaScript, Python ve C'ye gelir. Squirrel ve Java SDK 1.8'de donduruldu: app'leri
çalışmaya devam eder ama onlara yeni bir şey eklenmez; yeni oyuna onlarla başlamayın. Lua'nın en çok örneği ve
Studio editörleri vardır; JavaScript'te Promise vardır (`await g3d.loadModel(...)`); Python (pocketpy) daha yavaştır.
C konsolda derlenir ve script güvenlik ağı olmadan çalışır (süre sınırı yok, sandbox yok): yalnızca uzmanlar için.

## 2. Projeyi kur

**Konsolda:** *Nexvyn OS Studio*'yu açın, *Yeni Proje*, bir şablon seçin, ad verin, **Çalıştır**'a basın (Ctrl+R).
**PC'de:** `python SDK/Tools/nxv/nxv.py new lua "Sky Hop" --author adiniz` Lua şablonundan bir klasör yapar.

Bir 3B oyunun klasör düzeni:

```
SkyHop.nxvapp/
├── app.json
├── main.lua              giriş noktası; yanında başka modüller (require("collide") collide.lua'yı yükler)
├── icon.png              256 x 256 key art (12. bölüm)
├── lang/en.json          İngilizce: zorunlu
├── lang/de.json ...      istediğiniz başka diller (13. bölüm)
├── models/hero.glb       3B modeller (4. bölüm)
├── img/                  2D görseller, sprite sheet'ler, bitmap font
└── sfx/ music/           .wav / .ogg / .mp3
```

Bugün yapılan bir oyunun `app.json`'u:

```json
{
  "id": "com.yourname.skyhop",
  "name": {"en": "Sky Hop"},
  "description": {"en": "Hop across floating islands"},
  "version": "1.0",
  "author": "Your Name",
  "category": "games",
  "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 1280, "height": 720, "minWidth": 640, "minHeight": 360, "resizable": true},
  "gamepad": true,
  "minSdk": "1.8",
  "targetSdk": "1.8",
  "permissions": []
}
```

- `"gamepad": true` kontrolcüyü oyuna verir (oyuncu imleci geri almak için L+R'ye basılı tutar), `"resizable": true`
  oyunu tam ekran açar.
- `minSdk` kullandığınız en yeni SDK özelliğidir: `g3d.model` / `g3d.loadModel` için **1.8**. `targetSdk` test
  ettiğiniz SDK'dır: 1.8 ile çok uzun süren bir callback oyunu hata ekranıyla bitirir (5. bölüm).
- `permissions`: `net.*` (`"network"`) ya da başka izinli bir çağrıyı gerçekten kullanmıyorsanız `[]`. Her izin
  zorunlu olarak uygulanır ve mağaza incelemesi her birinin nedenini sorar.
- `name` ve `description` başka diller de taşıyabilir (`{"en": "Sky Hop", "es": "Salto Celeste"}`); İngilizce yeter.

## 3. Çalıştır ve test et

1. **Studio'da:** Çalıştır (Ctrl+R) app'i değişikliklerinizle yeniden başlatır; `print()` ve hatalar Studio'nun
   konsolunda görünür.
2. **PC'de, her yüklemeden önce:** `python SDK/Tools/nxv/nxv.py check SkyHop.nxvapp` manifesti, izinleri, çevirileri
   ve mağaza dosyalarını kontrol eder. `--sdk <Nexvyn OS checkout>` ile dil checker'ını da çalıştırır: oyunu sahte
   bir SDK'ya karşı rastgele girdiyle yüzlerce kare oynatır, İngilizcede ve eklediğiniz her dilde.
3. **Konsolda:** *Bilgisayara Bağlan*'da FTP sunucusunu başlatın, sonra
   `python SDK/Tools/nxv/nxv.py push SkyHop.nxvapp --host <konsol-ip>`. Hatalar pencerede satır numarasıyla görünür
   ve `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.
4. **Ryujinx emülatöründe:** `python SDK/Tools/nxv/nxv.py install SkyHop.nxvapp` oyunu emülatörün SD kartına
   kopyalar. Bir testi elinizi sürmeden tekrar oynatmak için oraya `sdmc:/NexvynOS/autorun.txt` koyun:

   ```
   wait 2
   launch com.yourname.skyhop
   wait 4
   shot title
   dpad a
   wait 3
   shot play
   ```

   Ekran görüntüleri `sdmc:/NexvynOS/autoshots/` klasörüne düşer. İşiniz bitince `autorun.txt`'yi silin, her
   açılışta çalışır. Ryujinx mantık ve görünüş için iyidir; hızı gerçek konsolda ölçün (10. bölüm).

## 4. 3B modeller: yap, dışa aktar, kontrol et

**Araçlar.** glTF 2.0 ya da FBX dışa aktaran her 3B program ve yapay zekâ model üreticileri iş görür. Modeli,
iskeleti ve animasyonu orada yapın; oyun yalnızca sonucu yükler. En iyi biçim `.glb`'dir (ikili glTF): mesh,
iskelet, klipler ve dokular tek dosyada. `.fbx` de çalışır (eksenleri ve birimleri yüklenirken çevrilir); `.obj` ve
`.stl`'de animasyon yoktur.

**Dışa aktarma kontrol listesi**

| Konu | Kural |
|---|---|
| Birim ve ölçek | 1 birim = 1 metre. Bir insan yaklaşık 1,7 m. Dışa aktarmadan önce ölçeği ve dönüşü uygulayın (apply) |
| Eksenler | glTF: +Y yukarı (dışa aktarıcının varsayılanı). Model oyunda **+Z**'ye, varsayılan kameraya bakar; Z-yukarı bir araçta bu "ön"dür (-Y) |
| Pivot | Ayakların ortasında: modelin orijini durduğu yerdir. `g3d.model(path, size)` modeli ölçekleyip y = 0'a da oturtur |
| Klip adları | Kısa ve açık: `Idle`, `Run`, `Jump`, `Attack`. Klip adla bulunur, büyük-küçük harf ve FBX'in eklediği armature öneki fark etmez (`"Rig|Run"`, `"run"` ile eşleşir) |
| Kemik adları | Bir şey takacağınız kemiklere ad verin: `hand_R`, `head`; soket olarak vertex'siz bir kemik (`Lamp`, `Muzzle`) |
| Dokular | `.glb`'nin içine gömün (ya da dosyanın yanında tutun). Yalnızca **base color** dokusu çizilir; normal, metallic, roughness ve emissive map'leri yok sayılır. Emissive *renk* (map olmadan) malzemeyi ışıksız ve parlak çizer: vizör, lamba, lav |
| Doku boyutu | Eşyalar için 512 x 512, kahraman için 1024 x 1024, en fazla 2048; ikinin kuvvetleri. Işığı ve detayı renk dokusuna bake edin |
| Üçgen | Kahraman 3 000 - 8 000, düşmanlar 1 000 - 4 000, eşyalar 50 - 1 500, bir bölüm toplam 20 000 - 50 000 (10. bölüm) |
| Kemik | GPU'da tek çizimde en fazla 32 kemik skin edilir; daha büyük iskelet birkaç çizime bölünür. Bir karakter için 20 - 40 kemik bol bol yeter; vertex başına 4 ağırlık |
| Desteklenmeyen | Morph target (blend shape), dosyadaki kamera ve ışıklar. Cubic spline anahtarları doğrusal oynar. Constraint ve IK'yi kliplere bake edin |

**Yapay zekâyla üretilen modeller** genelde çok fazla üçgenle, dağınık pivotla ve temiz iskelet olmadan gelir.
Yukarıdaki bütçeye indirin (decimate), pivotu ayaklara alın, bir 3B araçta rig'leyip klipleri adlandırın, sonra
`.glb` dışa aktarın. Çıktısını yayınlamanıza izin veren bir üretici kullanın ve mağaza README'si için not alın
(14. bölüm).

**Script'le yapılmış bir model.** Kor Tarlası'nın kahramanı Blender'da bir script'le kuruldu ve canlandırıldı:
örneğin yanındaki `art/make_models.py` (kaynak depoda `tools/gen_ember_models.py`). Bütün tarifi yaklaşık 150
satırda gösterir: gerçek boyutta parçalar, her parça tek kemiğe ağırlıklı, soket olarak fazladan bir kemik, üç
action ve dışa aktarma çağrısı:

```python
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_texcoords=False)
```

Arayüzsüz çalıştırın: `blender -b --factory-startup -P make_models.py -- <çıktı klasörü>`.

**Modeli oyunda kontrol edin,** etrafına bir şey kurmadan önce. `model:info()` neyin yüklendiğini söyler:

```lua
local m, err = g3d.model("bundle:/models/hero.glb")
if not m then print(err) else
  local i = m:info()
  print(i.format, i.triangles, i.bones, i.skinning, i.size.w, i.size.h, i.size.d)
  for _, a in ipairs(i.animations) do print(a.name, a.duration) end
end
```

İskelet GPU'da skin ediliyorsa `skinning` `"gpu"` olur. Model dev, minik ya da yatık çıkıyorsa kodda yamamak yerine
dışa aktarmayı düzeltin (ölçek, +Y yukarı). Studio'nun *3B modeller* şablonu dosyalarınız için hızlı bir
görüntüleyicidir.

## 5. Donmadan yükleme

Nexvyn OS 3 saniyeden uzun süren bir callback'i durdurur; ana dosyanın üst seviyesi ve `app.load` **10 saniye** alır.
`"targetSdk": "1.8"` ile oyun o zaman hata ekranıyla biter; daha eski bir app *"…" yanıt vermiyor* sorusunu alır
(Bekle / Kapat). İkisi de oyuncunun görmesini isteyeceğiniz şeyler değil, o yüzden:

- **Modelleri `g3d.loadModel` ile yükleyin.** Dosyayı arka plandaki bir thread'de okur ve ayrıştırır (her seferinde
  bir model) ve sizi bir timer gibi geri çağırır. Pencere bu arada yükleme ekranınızı çizmeye devam eder.
  `g3d.model` aynı işi oyun beklerken yapar: minik bir dosya için olur, bir bölüm için yanlış.
- **Kendi uzun işlerinizi dilimlere bölün.** `yield` eden bir coroutine, her karede birkaç milisaniye devam ettirilir.
- Görselleri bir kez yükleyin (`gfx.image` önbelleğe alır), asla `draw` içinde değil.

Kuyruklu bir yükleyici, bir yükleme sahnesi ve zaman dilimli bir iş (hepsi rehberin test edilmiş paketinden):

```lua
local assets = {}
local queue = {
  {name = "hero", path = "bundle:/models/hero.glb"},
  {name = "rock", path = "bundle:/models/rock.glb", size = 1.0},
}
local loaded, failed = 0, nil

local function loadAll(done)
  for _, item in ipairs(queue) do
    local function finish(m, err)
      if m then assets[item.name] = m else failed = item.path .. ": " .. tostring(err) end
      loaded = loaded + 1
      if loaded == #queue and done then done() end
    end
    if item.size then g3d.loadModel(item.path, item.size, finish)
    else g3d.loadModel(item.path, finish) end
  end
end

-- long work in small slices: a coroutine that yields, resumed for at most 4 ms per frame
local job
local function startJob(fn) job = coroutine.create(fn) end
local function runJob()
  if not job then return end
  local stop = os.clock() + 0.004
  while job and os.clock() < stop do
    local ok, err = coroutine.resume(job)
    if not ok then print("job failed: " .. tostring(err)); job = nil
    elseif coroutine.status(job) == "dead" then job = nil end
  end
end
```

```lua
scenes.loading = {}
function scenes.loading:enter()
  loadAll(function() if not failed then go("title") end end)
  startJob(buildTerrain)              -- buildTerrain calls coroutine.yield() after every row
end
function scenes.loading:draw(w, h)
  gfx.clear("#101014")
  gfx.color("#FFFFFF")
  if failed then gfx.wrap(TR("load_failed", failed), 40, 40, w - 80, 16)
  else gfx.text(TR("loading", loaded, #queue), 40, h - 60, 16, "mono") end
end
```

`runJob()`'u `app.update`'in başında çağırın. Kor Tarlası bir adım ileri gider: modeller yüklenirken başlık ekranı
zaten oynar, modeller gelene kadar *Oyna* gri kalır.

## 6. Animasyon ve takılan nesneler

```lua
hero:play("Run", {loop = true, speed = 1.2, fade = 0.2})   -- crossfade from the current pose in 0.2 s
hero:update(dt)                                             -- once per frame, for every model you animate
```

- Klibi her karede değil, yalnızca durum değişince değiştirin (`play`'i yeniden çağırmak geçişi baştan başlatır).
- Tek seferlik klip: `hero:play("Hop", {loop = false, fade = 0.06})`; `hero:playing()` false olduğunda klip son
  karesinde durmuştur, bir sonraki klibi o zaman seçin (Kor Tarlası'nın `Hop`'u).
- `speed` harekete uysun: `{speed = 0.7 + speed * 0.12}` ayakların kaymasını önler.
- Her `g3d.model()` / `g3d.loadModel()` tutamacı kendi başına canlanır ve dosyanın verisini paylaşır: aynı dosyadan
  on düşman tek yükleme tutar.

**Takılan nesneler.** `model:nodeMatrix(kemik, x, y, z, rx, ry, rz, sx, sy, sz)` model o yerleşimle çizildiğinde
kemiğin dünyadaki matrisini verir; oraya `g3d.drawMatrix` ile her şeyi çizebilirsiniz:

```lua
g3d.draw(assets.hero, player.x, player.y, player.z, 0, player.yaw, 0)
local m = assets.hero:nodeMatrix("hand_R", player.x, player.y, player.z, 0, player.yaw, 0)
if m and assets.rock then g3d.drawMatrix(assets.rock, m) end
```

`model:node(ad, ...)` yalnızca konumu döndürür: namlunun ucunda mermi, bir ayağın altında toz bulutu doğurmak için.

## 7. Görseller ve yazı tipleri

- `gfx.image("bundle:/img/sky.png")` PNG, JPG, WEBP, BMP ya da GIF'i bir kez yükler ve önbelleğe alır;
  `gfx.draw(img, x, y, w, h)` çizer, `gfx.drawRegion(img, sx, sy, sw, sh, x, y, w, h[, angleDeg])` bir parçasını
  çizer (sprite sheet).
- 3B mesh'lerde: mesh'in UV'leriyle `mesh:setTexture("bundle:/img/wood.png")`; alfası %50'nin altındaki pikseller
  kesilir.
- 2D oyunlar: `nexvyn.game` sheet'leri ve animasyonları ([GAME_ENGINE.tr.md](GAME_ENGINE.tr.md)).

**Yazı tipleri.** Script'ler metni sistem yazı tipleriyle çizer: `"sans"`, `"medium"`, `"semibold"`, `"bold"`,
`"italic"`, `"mono"`, `"monobold"`, her boyutta. Paketten `.ttf` yükleyen bir çağrı yoktur. Size ait bir yazı tipi
için: logonuzu görsel yapın (zaten key art'ınızın parçası) ve diğer metni bir **bitmap font** ile çizin; 32-127
karakterlerini 16 hücrelik satırlarda tutan bir PNG:

```lua
-- a bitmap font: a PNG with the characters 32..127 in rows of 16 cells (cw x ch pixels each)
function T.bitmapText(img, s, x, y, cw, ch, scale)
  scale = scale or 1
  for i = 1, #s do
    local c = s:byte(i) - 32
    if c >= 0 and c < 96 then
      gfx.drawRegion(img, (c % 16) * cw, math.floor(c / 16) * ch, cw, ch, x, y, cw * scale, ch * scale)
    end
    x = x + cw * scale
  end
end
```

Sistem yazı tipleri de harf aralığı, büyük/küçük harf ve kaydırılmış ikinci baskıyla çok yol alır (Kor Tarlası'nın
`spaced`'ine bakın); `nexvyn.game` 3x5 piksel bir yazı tipi ekler (`game.ui.pixelText`). Bitmap font yalnızca
çizdiğiniz karakterleri kapsar: çevrilen metni sistem yazı tipinde tutun ya da her dilin gerektirdiği harfleri çizin.

## 8. Ses ve titreşim

| Çağrı | Kullanım |
|---|---|
| `audio.play("bundle:/sfx/jump.wav", volume, loops)` → kanal | efektler; `loops = -1` `audio.stop(kanal)`'a kadar tekrar eder (motor uğultusu, yağmur) |
| `audio.tone(freq, seconds, volume, wave)` | sentezlenmiş notalar: `"sine"`, `"square"`, `"saw"`, `"triangle"`, `"noise"`; dosyasız koca bir retro ses seti |
| `audio.music("bundle:/music/theme.ogg")` | akışla çalan tek şarkı; `audio.musicPause(true/false)`, `audio.musicStop()` |
| `game.audio` (`nexvyn.game`) | notalardan adlandırılmış efektler, döngülü synth ezgisi (`song`), sessize alma |

- Mikser 48 kHz stereo ve 24 kanalla çalışır. Efektler bir kez çözülür ve bellekte tutulur: kısa `.wav` ya da `.ogg`
  dosyaları (mono yeter), yeniden örneklenmesin diye 48 kHz. Müzik akışla çalar: `.ogg` (ya da `.mp3`).
- **Döngüler:** müzik döngülerini sıfır geçişinde, uçlarında sessizlik bırakmadan kesin; yoksa ek yerinde tık duyulur.
- **Miks:** çalan bir şarkının sesini değiştiren çağrı yok; müzik dosyasını efektlerden kısık master edin (müzik
  yaklaşık -14 LUFS, efektlerin tepesi -3 dB civarı) ve oyuncuya *müzik açık / kapalı* (`audio.musicPause`) ile her
  `audio.play`'e geçtiğiniz bir efekt ses düzeyi verin.
- Oyun başına tek ses ailesi: aynı enstrüman, aynı oda. Bir eylemin birkaç sesinden rastgele seçmek tekrarı mekanik
  olmaktan çıkarır.
- Oyunun çaldığı her şey penceresi kapanınca durur.

**Titreşim:** `sys.vibrate(güç 0..1, ms)`, en fazla 2000 ms, yalnızca pencere odaktayken; `sys.vibrate(0)` durdurur.
Frekans deseni yoktur. Toplamalarda kısa ve hafif (0,2-0,3, 40 ms), darbelerde güçlü (0,8, 150 ms) ve ayarlarda
kapatma düğmesi.

## 9. Oyun yapısı

### Sahneler (durumlar)

Her sahne bir tablo, bir de `go` fonksiyonu; her sahnede `enter`, `update`, `draw`:

```lua
local scenes, current = {}, nil
local function go(name, params)
  if current and current.leave then current:leave() end
  current = scenes[name]
  if current.enter then current:enter(params) end
end
```

```lua
function app.update(dt)
  dt = math.min(dt, 1 / 20)                              -- a long frame must not tunnel through walls
  runJob()
  if current.update then current:update(dt) end
  A.endFrame()
end

function app.draw(w, h) current:draw(w, h) end
function app.event(e) A.event(e, gfx.size()) end
function app.suspend() paused = true; saveSettings(); store.set("save", save) end
function app.focus(focused) if not focused then paused = true end end
```

Tipik sahneler: yükleme, başlık, oyun, duraklatma (oyunun içinde bir katman), oyun sonu, ayarlar. 2D oyunlar için
`nexvyn.game`'de bu hazır gelir (`game.switch`, `game.push`, `game.pop`, geçişler).

### Girdi: tuş değil eylem

Oyuncular Joy-Con, Pro Controller, dokunmatik ekran ya da klavye kullanır. Ham tuşları değil eylemleri okuyun; böylece
hepsi çalışır ve yeniden atanabilir. `actions.lua`:

```lua
-- actions.lua: one input layer for the controller, the keyboard and touch (needs "gamepad": true in app.json)
local A = {}

-- each action lists the pad buttons and keys that trigger it; let the player change these in your settings
A.bind = {
  confirm = {pad = {"a"}, key = {"enter", "space"}},
  back    = {pad = {"b"}, key = {"escape", "backspace"}},
  pause   = {pad = {"plus"}, key = {"escape", "p"}},
  jump    = {pad = {"b", "a"}, key = {"space", "k"}},
  dash    = {pad = {"zr", "r"}, key = {"j", "l"}},
}

local held, hit = {}, {}            -- "pad:a" / "key:space" -> true
local touch = {on = false, x0 = 0, y0 = 0, x = 0, y = 0, tap = false}
A.touch = touch

function A.event(e, w)
  if e.type == "paddown" and e.pad then held["pad:" .. e.pad] = true; hit["pad:" .. e.pad] = true
  elseif e.type == "padup" and e.pad then held["pad:" .. e.pad] = nil
  elseif e.type == "keydown" and e.key then held["key:" .. e.key] = true; hit["key:" .. e.key] = true
  elseif e.type == "keyup" and e.key then held["key:" .. e.key] = nil
  elseif e.type == "mousedown" and e.x then
    if e.x < (w or 1280) / 2 then           -- left half: a stick that starts where the finger lands
      touch.on, touch.x0, touch.y0, touch.x, touch.y = true, e.x, e.y, e.x, e.y
    else touch.tap = true end               -- right half: a tap is "jump"
  elseif e.type == "mousemove" and touch.on and e.x then touch.x, touch.y = e.x, e.y
  elseif e.type == "mouseup" then touch.on = false end
end

local function any(tbl, name)
  local b = A.bind[name]
  if not b then return false end
  for _, p in ipairs(b.pad or {}) do if tbl["pad:" .. p] then return true end end
  for _, k in ipairs(b.key or {}) do if tbl["key:" .. k] then return true end end
  return false
end

function A.down(name) return any(held, name) end
function A.pressed(name) return any(hit, name) or (name == "jump" and touch.tap) end

-- the move vector: left stick, D-pad, WASD / arrows or the touch stick; x right, y down (screen), length <= 1
function A.move()
  local x, y = input.stick("left")
  y = -y                                    -- the stick reports up as positive
  if held["pad:left"] or held["key:left"] or held["key:a"] then x = -1 end
  if held["pad:right"] or held["key:right"] or held["key:d"] then x = 1 end
  if held["pad:up"] or held["key:up"] or held["key:w"] then y = -1 end
  if held["pad:down"] or held["key:down"] or held["key:s"] then y = 1 end
  if touch.on then
    local dx, dy = touch.x - touch.x0, touch.y - touch.y0
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 8 then x, y = dx / math.max(len, 60), dy / math.max(len, 60) end
  end
  local len = math.sqrt(x * x + y * y)
  if len > 1 then x, y = x / len, y / len end
  return x, y
end

-- call at the end of app.update: "pressed" lasts one update
function A.endFrame()
  for k in pairs(hit) do hit[k] = nil end
  touch.tap = false
end

return A
```

Kontrolleri oyunda gösterin (başlık ekranında ya da ilk oyunda bir ipucuyla), dokunmatik kontrolleri ekrana
dokunulduktan sonra çizin ve **+**'yı duraklatmaya ayırın. `input.motion()` nişan ya da direksiyon için jiroskobu
verir.

### Kamera ve hareket

Sağ çubukla dönen üçüncü şahıs kamera, ona göre hareket ve bir yükseklik haritasına yerçekimi:

```lua
function scenes.play:update(dt)
  if A.pressed("pause") then paused = not paused end
  if paused then return end
  -- camera: right stick turns it (invert Y is a setting)
  local rx, ry = input.stick("right")
  camYaw = camYaw - rx * 2.2 * dt
  camPitch = math.max(0.1, math.min(1.2, camPitch + (settings.invertY and ry or -ry) * 1.5 * dt))
  -- move relative to the camera: forward is away from it
  local mx, my = A.move()
  local fx, fz = -math.sin(camYaw), -math.cos(camYaw)
  local rxv, rzv = -fz, fx
  local vx, vz = (rxv * mx - fx * my) * 5, (rzv * mx - fz * my) * 5
  player.x, player.z = player.x + vx * dt, player.z + vz * dt
  if vx * vx + vz * vz > 0.1 then player.yaw = math.atan(vx, vz) end
  -- gravity and the ground
  if player.onGround and A.pressed("jump") then player.vy = 6; player.onGround = false; rumble(0.2, 40) end
  player.vy = player.vy - 18 * dt
  player.y = player.y + player.vy * dt
  local g = C.groundHeight(hm, player.x, player.z) or 0
  if player.y <= g then player.y, player.vy, player.onGround = g, 0, true end
  -- animation follows the state
  local hero = assets.hero
  if hero then
    local want = not player.onGround and "Jump" or (vx * vx + vz * vz > 0.5 and "Run" or "Idle")
    if want ~= player.clip then
      player.clip = want
      hero:play(want, {loop = want ~= "Jump", fade = 0.15})
    end
    hero:update(dt)
  end
end
function scenes.play:draw(w, h)
  gfx.clear("#9CC3D5")
  local cx = player.x + math.sin(camYaw) * math.cos(camPitch) * camDist
  local cz = player.z + math.cos(camYaw) * math.cos(camPitch) * camDist
  local cy = player.y + math.sin(camPitch) * camDist
  g3d.begin(0, 0, w, h, 60, 0.1, 80)
  g3d.camera(cx, cy, cz, player.x, player.y + 1, player.z)
  g3d.light(-0.4, 1, 0.3, 0.4)
  g3d.fog("#9CC3D5", 25, 70)
  if terrain then g3d.draw(terrain, 0, 0, 0) end
  if assets.hero then
    g3d.draw(assets.hero, player.x, player.y, player.z, 0, player.yaw, 0)
    local m = assets.hero:nodeMatrix("hand_R", player.x, player.y, player.z, 0, player.yaw, 0)
    if m and assets.rock then g3d.drawMatrix(assets.rock, m) end
  end
  g3d.finish()
  if paused then
    gfx.color("#000000AA")
    gfx.rect(0, 0, w, h)
    gfx.color("#FFFFFF")
    gfx.text(TR("paused"), w / 2, h / 2 - 20, 32, "bold", "center", 0)
  end
end
```

`math.atan(vx, vz)` bir yönü `g3d.draw` için yaw'a çevirir (model yaw 0'da +Z'ye bakar). Hedefine yumuşakça yaklaşan
bir takip kamerası (`cam.x = cam.x + (hedef - cam.x) * 0.12`) ve darbede kısa bir sarsıntı "hissin" çoğunu verir;
Kor Tarlası ikisini de kullanır.

### Çarpışma

SDK'da olanlar: `g3d.voxels`'te kutu fiziği ve ray cast (JavaScript blok dünyaları); `nexvyn.game`'de (2D) gövdeler,
tile çarpışması, gruplar, tetikleyiciler ve `game.physics` yardımcıları. `g3d` ile yapılan bir 3B oyunda birkaç
fonksiyonu kendiniz yazarsınız; çoğu oyun için bu yeter. Karakterler için küre, sandık ve duvarlar için kutu
(`model:info()` modelin `min` / `max`'ını verir), zemin için yükseklik haritası. `collide.lua`:

```lua
-- collide.lua: simple 3D collision for g3d games (no physics engine needed)
local C = {}

-- sphere vs sphere: true when they overlap
function C.spheres(ax, ay, az, ar, bx, by, bz, br)
  local dx, dy, dz = ax - bx, ay - by, az - bz
  local r = ar + br
  return dx * dx + dy * dy + dz * dz < r * r
end

-- box vs box; a box is {x0, y0, z0, x1, y1, z1} (min and max corners)
function C.boxes(a, b)
  return a[1] < b[4] and a[4] > b[1] and a[2] < b[5] and a[5] > b[2] and a[3] < b[6] and a[6] > b[3]
end

-- a model's box at a position (model:info() gives min / max in model space; no rotation)
function C.modelBox(info, x, y, z, s)
  s = s or 1
  return {x + info.min.x * s, y + info.min.y * s, z + info.min.z * s,
          x + info.max.x * s, y + info.max.y * s, z + info.max.z * s}
end

-- sphere vs box: returns the push (dx, dy, dz) that moves the sphere out, or nil
function C.sphereBox(x, y, z, r, b)
  local cx = math.max(b[1], math.min(x, b[4]))
  local cy = math.max(b[2], math.min(y, b[5]))
  local cz = math.max(b[3], math.min(z, b[6]))
  local dx, dy, dz = x - cx, y - cy, z - cz
  local d2 = dx * dx + dy * dy + dz * dz
  if d2 >= r * r then return nil end
  if d2 < 1e-9 then return 0, r, 0 end              -- centre inside the box: push up
  local d = math.sqrt(d2)
  return dx / d * (r - d), dy / d * (r - d), dz / d * (r - d)
end

-- ray vs box (slab test): distance along the ray to the first hit, or nil. (dx, dy, dz) need not be normalised.
function C.rayBox(ox, oy, oz, dx, dy, dz, b)
  local t0, t1 = 0, math.huge
  local o, d = {ox, oy, oz}, {dx, dy, dz}
  for i = 1, 3 do
    if math.abs(d[i]) < 1e-9 then
      if o[i] < b[i] or o[i] > b[i + 3] then return nil end
    else
      local ta, tb = (b[i] - o[i]) / d[i], (b[i + 3] - o[i]) / d[i]
      if ta > tb then ta, tb = tb, ta end
      t0, t1 = math.max(t0, ta), math.min(t1, tb)
      if t0 > t1 then return nil end
    end
  end
  return t0
end

-- ray vs triangle (Moller-Trumbore): distance t, or nil. v = {x1,y1,z1, x2,y2,z2, x3,y3,z3}
function C.rayTriangle(ox, oy, oz, dx, dy, dz, v)
  local e1x, e1y, e1z = v[4] - v[1], v[5] - v[2], v[6] - v[3]
  local e2x, e2y, e2z = v[7] - v[1], v[8] - v[2], v[9] - v[3]
  local px, py, pz = dy * e2z - dz * e2y, dz * e2x - dx * e2z, dx * e2y - dy * e2x
  local det = e1x * px + e1y * py + e1z * pz
  if math.abs(det) < 1e-9 then return nil end
  local inv = 1 / det
  local tx, ty, tz = ox - v[1], oy - v[2], oz - v[3]
  local u = (tx * px + ty * py + tz * pz) * inv
  if u < 0 or u > 1 then return nil end
  local qx, qy, qz = ty * e1z - tz * e1y, tz * e1x - tx * e1z, tx * e1y - ty * e1x
  local w = (dx * qx + dy * qy + dz * qz) * inv
  if w < 0 or u + w > 1 then return nil end
  local t = (e2x * qx + e2y * qy + e2z * qz) * inv
  return t >= 0 and t or nil
end

-- heightmap: heights[j * n + i + 1] on an n x n grid of `step` metres starting at (x0, z0) (the same grid you gave
-- g3d.custom). Returns the ground height under (x, z), interpolated inside the cell's two triangles.
function C.groundHeight(hm, x, z)
  local fx, fz = (x - hm.x0) / hm.step, (z - hm.z0) / hm.step
  local i, j = math.floor(fx), math.floor(fz)
  if i < 0 or j < 0 or i >= hm.n - 1 or j >= hm.n - 1 then return nil end
  local u, v = fx - i, fz - j
  local function h(a, b) return hm.heights[(j + b) * hm.n + (i + a) + 1] end
  if u + v <= 1 then                                 -- triangle (a, b, c) of the cell
    return h(0, 0) + (h(1, 0) - h(0, 0)) * u + (h(0, 1) - h(0, 0)) * v
  end
  return h(1, 1) + (h(0, 1) - h(1, 1)) * (1 - u) + (h(1, 0) - h(1, 1)) * (1 - v)
end

-- ray vs heightmap: march in small steps, then refine; returns the hit point or nil
function C.rayGround(hm, ox, oy, oz, dx, dy, dz, maxDist)
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  dx, dy, dz = dx / len, dy / len, dz / len
  local step, prev = hm.step * 0.5, 0
  for t = step, maxDist, step do
    local x, y, z = ox + dx * t, oy + dy * t, oz + dz * t
    local g = C.groundHeight(hm, x, z)
    if g and y <= g then
      local lo, hi = prev, t                         -- binary search between the last two steps
      for _ = 1, 8 do
        local mid = (lo + hi) / 2
        local gm = C.groundHeight(hm, ox + dx * mid, oz + dz * mid)
        if gm and oy + dy * mid <= gm then hi = mid else lo = mid end
      end
      return ox + dx * hi, oy + dy * hi, oz + dz * hi
    end
    prev = t
  end
  return nil
end

return C
```

Yükseklik haritası, zemin mesh'ine çevirdiğiniz ızgaranın ta kendisidir; yükleme hiç takılmasın diye dilim dilim
kurulur:

```lua
local hm = {n = 48, step = 0.5, x0 = -12, z0 = -12, heights = {}}
local terrain
local function buildTerrain()
  local V, I, CC = {}, {}, {}
  for j = 0, hm.n - 1 do
    for i = 0, hm.n - 1 do
      local x, z = hm.x0 + i * hm.step, hm.z0 + j * hm.step
      local y = math.sin(x * 0.4) * math.cos(z * 0.3) * 0.8
      hm.heights[j * hm.n + i + 1] = y
      V[#V + 1], V[#V + 2], V[#V + 3] = x, y, z
      CC[#CC + 1] = {60, 120 + math.floor(y * 40), 80}
    end
    coroutine.yield()                                    -- one row per slice
  end
  for j = 0, hm.n - 2 do
    for i = 0, hm.n - 2 do
      local a = j * hm.n + i + 1
      local b, c, d = a + 1, a + hm.n, a + hm.n + 1
      I[#I + 1], I[#I + 2], I[#I + 3] = a, c, b
      I[#I + 1], I[#I + 2], I[#I + 3] = b, c, d
    end
  end
  terrain = g3d.custom(V, I, CC, true)
end
```

Çarpışmayı sağlam tutan kurallar: `dt`'yi sınırlayın (yavaş bir kare bir şeyi duvarın içinden geçirmesin), en kısa
yoldan dışarı iterek çözün (`sphereBox` o itişi döndürür), hızlı mermileri eski konumdan yenisine bir ışınla test
edin ve önce kaba bir kontrol yapın (üçgen testlerinden önce bir mesafe testi). 3B araçta yaptığınız bölüm
geometrisi için ikinci, basit bir çarpışma mesh'i dışa aktarın (kutular, low-poly zemin) ve üçgenlerini `rayTriangle`
için bir Lua tablosunda tutun: çizilen modelin vertex'leri script'ten okunamaz.

### Kayıt ve ayarlar

`store` JSON benzeri değerleri bir saniye içinde, oyun askıya alınınca ya da kapanınca kaydeder:

```lua
local settings = store.get("settings", {music = 0.6, sfx = 0.8, rumble = true, invertY = false})
local function saveSettings() store.set("settings", settings) end
local save = store.get("save", {level = 1, best = 0, unlocked = {1}})

local function rumble(strength, ms)
  if settings.rumble then sys.vibrate(strength, ms) end
end
```

İlerlemeyi kontrol noktalarında ve `app.suspend` / `app.autosave` içinde kaydedin. `nexvyn.game`'de numaralı kayıt
yuvaları vardır (`game.save.slot(i)`). Değecek bir ayarlar ekranı: müzik açık/kapalı, efekt ses düzeyi, titreşim,
kamera Y'sini ters çevirme, tuş atama (`A.bind`'ı değiştirin), dil sistemi izler.

### Duraklatma

**+** (ve Esc / P) ile, konsol HOME menüsüne geçince ya da uyuyunca (`app.suspend`) ve pencere odağı kaybedince
(`app.focus(false)`) duraklatın. Duraklatmada saati ve animasyonları durdurun, donmuş sahneyi duraklatma ekranınızın
altında çizmeye devam edin. Asla kendiliğinden devam etmeyin.

## 10. Switch'te hız ve bellek

**Ölçülen** (SDK 1.8, GPU yolu, sahnede 49 000 üçgenlik bir heykelle 5 600 üçgenlik skin'li modeller): 60 fps'de 16
animasyonlu model; 64 tanesi bir emülatörde yaklaşık 33 fps. Konsolda payı olan 60 fps'yi hedefleyin.

| Kare başına bütçe (60 fps için yol gösterici) | |
|---|---|
| Çizilen üçgen | toplam 30 000 - 60 000 (`g3d.finish()` sayıyı döndürür) |
| Çizim çağrısı | 150 civarında tutun: bir modelin her mesh'i, her malzeme ve bir iskeletin her 32 kemiklik parçası bir çağrıdır |
| Ekranda skin'li karakter | 8 - 16 |
| Dokular | 512 - 1024 px, en fazla 2048; birkaç büyük doku çok sayıda küçükten iyidir |
| Işıklar | bir güneş (`g3d.light`) ve sis; gerisini emissive renkler ve `"glow"` haleleriyle taklit edin |

- **Daha az çizin.** Sabit eşyaları tek bir `g3d.custom` mesh'inde birleştirin, kameranın arkasındakileri ve uzaktakileri
  atlayın, uzak kesme düzlemini sisle gizleyin, `far`'ı sahnenin izin verdiği kadar küçük tutun.
- **Daha az bellek ayırın.** `update` / `draw` döngülerinde yeniden kullanabileceğiniz yeni tablo ya da string
  üretmeyin; `draw` içinde görsel yüklemeyin. Lua'nın çöp toplayıcısı hızlıdır ama karede bin tablo takılma olarak
  görünür.
- **Bellek.** Her pencerenin script heap'i (Lua, JavaScript, Python) en fazla **64 MB** kullanabilir; `sys.memory()`
  ne kadar yaklaştığınızı söyler. Model ve doku verisi onun dışında, konsolun Nexvyn OS ve açık diğer app'lerle
  paylaştığı bellekte durur: oyunun model ve dokularını yüzlerce değil onlarca MB'de tutun. Bir model dosyası en
  fazla 96 MB olabilir.
- **Ölçün.** `sys.fps()`, `g3d.finish()`'in üçgen sayısı, `nexvyn.game`'in F3 katmanı ve konsolda `autorun.txt`
  içinde bir `stats` satırı. Oyununuzun aynı anda doğurduğu en çok düşmanla test edin.

## 11. Kendinin yap: sanat yönü

Bu kitle yapılan iki oyun birbirine benzememeli, hiçbir oyun da Nexvyn OS masaüstüne benzememeli. Kit size hazır
menü şablonu değil, yapı taşları verir:

- Çizim: gradyanlar, (dışbükey) çokgenler, çizgiler ve çoklu çizgiler, yaylar, daireler, görseller, sprite sheet'ler,
  kırpma, alfa.
- Yazı: her boyutta yedi sistem yazı stili, kendi çizdiğiniz harf aralığı, bitmap fontlar, 3x5 piksel yazı tipi,
  görsel olarak logonuz.
- 3B: ışık rengi ve yönü, sis, vertex renkleri, dokular, `"unlit"`, `"wire"`, eklemeli `"glow"` haleleri, emissive
  malzemeler, 3B noktaların üstüne etiket için `g3d.project`.
- Hareket: Lua'da kendi easing'iniz ya da 30'dan fazla easing'le `game.tween`, sahne geçişleri (`fade`, `slide`,
  `wipe`, `circle`, `blinds`, `pixels`) ve `game.flash`, `nexvyn.game`'de kamera sarsıntısı ve itmesi.
- Parçacıklar: `nexvyn.game`'de `game.emitter` ve on hazır ayar, ya da kendi küçük havuzunuz (Kor Tarlası'nın
  kıvılcımları).
- Ses: beş dalga biçimi, dosyalar, akışla müzik.

Script'ler için özel shader ya da post-processing yoktur: görünüş palet, ışık, biçim, yazı ve hareketten gelir.

### Yöntem: ilk menüden önce yedi karar

Bunları `main.lua`'nın başına yorum olarak yazın. Kor Tarlası'nınkiler parantez içinde.

1. **Tek satırda his** ve üç sıfat. ("Uçan adada alacakaranlık ayak işi": sıcak, küçük, telaşlı.)
2. **Palet:** bir koyu, bir açık, bir ya da iki vurgu; yaklaşık %60 / %30 / %10. Gri tonlamada kontrol edin: oyuncu ve
   tehlike yine öne çıkmalı. Oyunda `theme.*` (OS renkleri) kullanmayın. (Mürekkep `#17142A`, krem `#FFF1DC`, mercan
   `#FF6F59`, kayısı.)
3. **Tipografi:** hangi yazı stili, büyük/küçük harf, boyut adımları, aralık; logo görseli nerede. (Geniş aralıklı
   kalın büyük harfler ve mercan renkli kaydırılmış baskı, alt başlıkta italik, sayılarda monospace.)
4. **Kamera dili:** açı, görüş alanı, mesafe, nasıl hareket ettiği (yumuşak takip, yörünge, sabit odalar, sarsıntı).
   (50 derecede yüksek üç çeyrek takip; başlıkta yavaş yörünge.)
5. **Hareket stili:** keskin mi süzülen mi; süreler; taşma (overshoot) var mı. (Kısa ve yumuşak: 0,15-0,3 s geçişler.)
6. **Ses paleti:** tek enstrüman ve efekt ailesi. (Korlar için iki triangle notası, darbede alçak bir saw ve noise.)
7. **Arayüz biçim dili:** köşeler (keskin, yuvarlak, eğik, yırtık), çizgi kalınlığı, menülerin yeri ve dizilişi:
   tek bir komut, yatay sıra, kartlar, numaralı sütun, 3B dünyadaki nesneler. (Sağ altta dalgalı alt çizgili yatay
   kelime sırası; eğik kartlar.)

**Kurallar.** Bir örneğin ya da başka bir oyunun menü düzenini, renklerini ya da başlık kompozisyonunu yeniden
kullanmayın: mağaza incelemesi kopyalayan oyunları reddeder. Oyun menülerini `ui.*` widget'larından kurmayın: onlar
OS'un kendi kontrolleridir. Menü, HUD ve duraklatma ekranı oyununuzun dünyasına aittir.

### Aynı yapı taşlarından dört başlık ekranı

Aynı üç menü öğesi, dört yön. Dördü de `titles.lua`'da düz fonksiyonlar (rehberin paketinde test edildi);
kararlarını karşılaştırın, sonra kendinizinkini yapın.

```lua
-- A. "Night circuit": black and electric, a perspective grid, the logo split into two colours, no list at all
function T.circuit(w, h, t)
  gfx.clear("#05060B")
  local hy = h * 0.58                                          -- horizon
  gfx.gradient(0, hy - 120, w, 120, "#05060B", "#3B0A45")
  gfx.color("#FF2E88")
  for i = -12, 12 do                                           -- lines that run to the vanishing point
    gfx.line(w / 2 + i * 18, hy, w / 2 + i * w * 0.18, h, 1.5)
  end
  for k = 0, 9 do                                              -- cross lines that scroll towards the player
    local f = ((k + t * 0.8) % 10) / 10
    local y = hy + (h - hy) * f * f
    gfx.line(0, y, w, y, 1 + f * 2)
  end
  local size = math.floor(h * 0.14)
  gfx.color("#19E6FF")
  gfx.text(TR("logo"), w / 2 - 3, h * 0.2, size, "monobold", "center", 0)
  gfx.color("#FF2E88")
  gfx.text(TR("logo"), w / 2 + 3, h * 0.2 + 2, size, "monobold", "center", 0)
  gfx.color("#FFFFFF")
  gfx.text(TR("logo"), w / 2, h * 0.2, size, "monobold", "center", 0)
  if math.floor(t * 2) % 2 == 0 then                           -- one prompt; the options come after it
    gfx.text(TR("press_start"), w / 2, h * 0.86, 18, "mono", "center", 0)
  end
end

-- B. "Paper diorama": warm paper, a torn edge, the menu as three cards lying at angles
function T.paper(w, h, t, sel)
  gfx.clear("#F4EAD5")
  local pts = {0, h * 0.62}
  for i = 0, 16 do pts[#pts + 1] = w * i / 16; pts[#pts + 1] = h * 0.62 + ((i * 37) % 11) - 5 end
  pts[#pts + 1] = w; pts[#pts + 1] = h
  gfx.color("#2E4A3F")
  gfx.lines(pts, 3)                                            -- the torn hill line
  gfx.color("#2B2118")
  gfx.text(TR("logo"), 48, h * 0.12, math.floor(h * 0.12), "italic")
  local labels = {TR("play"), TR("options"), TR("quit")}
  for i, label in ipairs(labels) do
    local cx, cy = w * (0.3 + i * 0.16), h * 0.78 + (i == sel and -10 - math.sin(t * 4) * 3 or 0)
    local tilt = (i - 2) * 6
    gfx.poly({cx - 70, cy - 40 + tilt, cx + 70, cy - 40 - tilt, cx + 70, cy + 40 - tilt, cx - 70, cy + 40 + tilt},
             i == sel and "#E9573F" or "#FFFDF6")
    gfx.color(i == sel and "#FFFDF6" or "#2B2118")
    gfx.text(label, cx, cy - 10, 18, "semibold", "center", 0)
  end
end

-- C. "Swiss grid": white, one red block, huge numerals, a numbered column on the left
function T.swiss(w, h, t, sel)
  gfx.clear("#FAFAF7")
  gfx.rect(w * 0.62, 0, w * 0.38, h * 0.55, 0, "#E2231A")
  gfx.color("#111111")
  gfx.text("08", w * 0.6, h * 0.5, math.floor(h * 0.42), "bold")
  gfx.text(TR("logo"), 40, 36, 28, "bold")
  gfx.color("#11111133")
  for x = 40, w, 80 do gfx.line(x, 0, x, h, 1) end             -- the visible grid is part of the look
  local items = {"play", "options", "quit"}
  for i, key in ipairs(items) do
    local y = h * 0.42 + (i - 1) * 46
    gfx.color(i == sel and "#E2231A" or "#111111")
    gfx.text(string.format("%02d", i), 40, y, 16, "monobold")
    gfx.text(TR(key), 90, y - 4, 26, i == sel and "bold" or "medium")
  end
end

-- D. "Diegetic": no 2D menu; three lit doors in the 3D scene, the camera turns to the chosen one
function T.doors(w, h, t, sel, door)
  gfx.clear("#0E1116")
  local angle = (sel - 2) * 0.5
  g3d.begin(0, 0, w, h, 55, 0.1, 40)
  g3d.camera(math.sin(angle) * 0.5, 1.6, 4, math.sin(angle) * 3, 1.4, 0)
  g3d.light(0.2, 1, 0.6, 0.25)
  g3d.fog("#0E1116", 4, 14)
  local labels = {"play", "options", "quit"}
  for i = 1, 3 do
    local x = (i - 2) * 2.4
    g3d.draw(door, x, 1.1, 0, 0, 0, 0, 1, 1, 1, i == sel and "#FFC870" or "#4A5568", i == sel and "glow unlit" or nil)
  end
  local sx = {}
  for i = 1, 3 do sx[i] = {g3d.project((i - 2) * 2.4, 2.6, 0)} end   -- labels above the doors (before finish)
  g3d.finish()
  for i = 1, 3 do
    if sx[i][1] then
      gfx.color(i == sel and "#FFC870" or "#8A94A6")
      gfx.text(TR(labels[i]), sx[i][1], sx[i][2], 18, "semibold", "center", 0)
    end
  end
end
```

(`door`, `app.load`'da bir kez yapılan `g3d.mesh("box", 1.2, 2.2, 0.2)`'dir.) Beşinci yön Kor Tarlası'nın kendisi:
solda yörüngede dönen 3B kahraman, baskı hatası gibi kaymış bir afiş başlığı, dalgalı alt çizgili bir kelime sırası.
Bunlar şablon değil, karar örnekleridir: oyununuz bunlardan birine benzemeye başlarsa yedi karara geri dönün.

Her şeyin üstüne çizebileceğiniz **geçişler**; `p` 0'dan 1'e gider, 1'de sahneyi değiştirip geri oynatırsınız:

```lua
-- transitions: draw on top of everything; p goes 0 -> 1 (cover) then you switch screens and run 1 -> 0
function T.iris(w, h, p, cx, cy)                -- a closing circle (a very thick ring around a shrinking hole)
  local far = math.sqrt(w * w + h * h)
  local r = far * (1 - p)
  gfx.color("#000000")
  gfx.circleLine(cx or w / 2, cy or h / 2, r + far / 2, far)
end

function T.wipe(w, h, p, color)                 -- a slanted bar sweeping across
  local x = (w + h * 0.5 + 10) * p - 10
  gfx.poly({-10, 0, x, 0, math.max(-10, x - h * 0.5), h, -10, h}, color or "#111111")
end
```

**"Pahalı" görünen cilalar:** her yerde (HUD dahil) sabit bir palet, her değişimde yumuşak hareket (birden belirme
yok), darbede 2-4 karelik vuruş duraklaması ve kamera itmesi, toplamalarda parçacık, her eylemde ses, içinde canlı
bir şey olan bir başlık ekranı (bekleyen kahraman, yükselen korlar) ve ekranda oyuncunun ihtiyaç duymadığı hiçbir şey.

## 12. Mağaza ikonu ve key art

İkon, oyuncunun App Market'te gördüğü ilk şeydir. SDK ile yapılan oyun ve app'lerde ikon **oyunun kendi key art'ı**
olmalı: kahramanı, dünyası, ışığı, adı ya da logosu; cesur, 64 px'de okunur ve mağazadaki diğer ikonlara benzemez.
Gradyan üstünde düz bir sembol (`nxv icon` bunları yalnızca geçici olarak üretir) bir oyun için kabul edilmez.

| | |
|---|---|
| Dosya | Pakette `icon.png` (mağaza klasöründe `source/`'un yanında da) |
| Boyut | 256 x 256 PNG. 1024 x 1024 yapıp iyi bir filtreyle küçültün |
| Güvenli alan | Yüzü, kahramanın siluetini ve logoyu ortadaki %80'in içinde tutun: köşeler yuvarlanabilir ya da kesilebilir |
| Doluluk | Kareyi kenardan kenara doldurun (opak arka plan olur) |
| 64 px'de okunma | Tek konu, büyük; kahramanla arka plan arasında güçlü ton farkı; en fazla bir iki kelime |

**Nasıl yapılır**

1. **Kendi modellerinizden render alın,** bir 3B araçta: kahramana poz verin (bir klipten bir kare), ona yakın alçak
   bir kamera, sıcak bir ana ışık ve zıt renkte güçlü bir kenar (rim) ışığı, arkada oyununuzun gök renkleri, önde
   logo. Kor Tarlası'nın ikonu böyle bir script'le render edildi (örneğin yanındaki `art/make_keyart.py`, kaynak
   depoda `tools/gen_ember_keyart.py`):
   `blender -b --factory-startup -P make_keyart.py -- models/pip.glb keyart.png 1024`.
2. **Ya da oyunun içinde kurun:** kahramanı en iyi ışığınızla ve logoyla büyük çizen gizli bir key art kipi ekleyin,
   ekran görüntüsü alın (Ryujinx ya da `autorun.txt` içinde `shot`), kare kırpın ve bir görsel düzenleyicide bitirin.
3. **Ya da çizin** veya çizdirin: oyunun gerçek görünüşüne uymalı.

**Key art için AI prompt'u** (sonucunu yayınlamanıza izin veren bir görsel üretici için; ikon oyuna uysun diye
kahramanınızın bir render'ını ya da ekran görüntüsünü referans görsel olarak ekleyin). Prompt İngilizcedir, çoğu
üretici İngilizceyi en iyi anlar:

```text
Square video game key art, 1:1, for a game called "<NAME>". Subject: <your hero, from the reference image>,
<pose / action>, large in the frame, three-quarter view, seen from slightly below. Setting: <your world in a few
words>. Lighting: <key light colour> key light, strong <contrasting colour> rim light, <time of day>. Palette:
<your 3-4 palette colours>. Style: <your art direction words, e.g. low-poly faceted, painterly, pixel art>.
Bold silhouette, high contrast, readable at small size, subject and logo inside the central 80 %. Title "<NAME>"
in a <your typography> logo at the bottom. No other text, no frame, no watermark.
```

Sonra kontrol edin: açıkça sizin oyununuz mu? 64 px'de okunuyor mu? Mağaza sayfasındaki her ikondan farklı mı?

## 13. Diller

- **İngilizce zorunlu**: kullandığınız her anahtarla `lang/en.json`, `app.json` `name` / `description` içinde ve
  `store.json`'da `"en"`.
- Başka her dili tek bir dosyayla ekleyin: `lang/<kod>.json` (`de`, `es`, `fr`, `ja`, `ko`, `tr`, `zh`: Nexvyn OS arayüz dilleri).
  `TR("anahtar", ...)` konsolun dilini kullanır ve eksik anahtarlarda İngilizceye düşer; yarım bir çeviri asla ham
  anahtar göstermez.
- Metindeki `{0}`, `{1}` ek argümanlarla değişir: `"score": "Score: {0}"` ile `TR("score", 42)`.
- Çevrilen metni ölçün (`gfx.textWidth`) ve satıra bölün (`gfx.wrap`); Almanca ve Türkçe kelimeler uzundur.
- Bitmap fontlarda yalnızca çizdiğiniz karakterler vardır: onları sayılar ve yalnız İngilizce logolar için,
  çevrilen metin için sistem yazı tipini kullanın.

## 14. Yayınla

1. Public depoda **öğe klasörü**: `Store/Games/<tür>/<slug>/`; içinde `source/` (paketiniz), `store.json`,
   `README.md`, `screenshots/` (3-4 PNG ya da bakımcının oynattığı bir `shots` script'i).
2. **`store.json`:**

   ```json
   {
     "kind": "game",
     "tags": ["3d", "action", "arcade"],
     "subtitle": {"en": "Collect embers, dodge rolling stones"},
     "description": {"en": "Two or three sentences about the game.\n\n• What makes it fun\n• Controls"},
     "age": "everyone",
     "shots": [["wait 4"], ["dpad a", "wait 3"], ["wait 6"]]
   }
   ```

   İngilizce zorunlu; başka diller başka anahtarlar olarak eklenir (`"de": "..."`). Alt başlık en fazla 45 karakter.
3. **README.md:** oyunun ne olduğu, kontroller, diller, bir sürüm tablosu ve sizin yapmadığınız her parçanın lisansı
   (modeller, müzik, yazı tipleri, üretici şartları).
4. **Pull request.** Bakımcı inceler (kontrol listesi: `SDK/Publishing/REVIEW.tr.md`) ve checker'ları çalıştırır.

**İncelemede bakılanlar:** konsolda hatasız açılıp çalışıyor; hiçbir callback süre sınırlarına yaklaşmıyor (büyük
dosyalar `g3d.loadModel` ile yükleniyor); kontrolcü, dokunmatik ve klavyeyle çalışıyor, **+** ve askıya almada
duruyor; `minSdk` / `targetSdk` doğru; izinler açıklanmış; İngilizce metin eksiksiz; ikon oyunun key art'ı; görünüş
oyunun kendisine ait (kopyalanmış örnek menü yok, oyun arayüzü olarak OS widget'ı yok); her varlık sizin ya da
yayınlama izniniz var; hiçbir şey veri toplamıyor.

## 15. Aynı döngü JavaScript ve Python ile

**JavaScript** (`main.js`, `"main": "main.js"`): `g3d.loadModel` bir Promise döndürür; o çözülürken pencere çizmeye
devam eder.

```js
// The JavaScript version of the guide's 3D loop: async loading, input, a follow camera, sphere collision
let hero = null, rock = null, error = "";
const player = { x: 0, z: 0, yaw: 0, clip: "" };
const rocks = [{ x: 3, z: -2, r: 0.5 }, { x: -4, z: 1, r: 0.7 }];
const held = new Set();

async function loadAssets() {
  try {
    [hero, rock] = await Promise.all([
      g3d.loadModel("bundle:/models/hero.glb"),
      g3d.loadModel("bundle:/models/rock.glb", 1.0),
    ]);
    hero.play("Idle");
  } catch (e) {
    error = String(e.message || e);          // the reason the file could not be loaded
  }
}

function moveVector() {
  let [x, y] = input.stick("left");
  y = -y;                                   // up on the stick is positive
  if (input.down("left") || held.has("left") || held.has("a")) x = -1;
  if (input.down("right") || held.has("right") || held.has("d")) x = 1;
  if (input.down("up") || held.has("up") || held.has("w")) y = -1;
  if (input.down("down") || held.has("down") || held.has("s")) y = 1;
  const len = Math.hypot(x, y);
  return len > 1 ? [x / len, y / len] : [x, y];
}

app.load = () => { loadAssets(); };          // returns at once; the window keeps drawing

app.update = (dt) => {
  dt = Math.min(dt, 1 / 20);
  if (!hero) return;
  const [mx, my] = moveVector();
  const nx = player.x + mx * 5 * dt, nz = player.z + my * 5 * dt;
  // sphere vs sphere against every rock: refuse the step that would overlap
  const blocked = rocks.some((r) => (nx - r.x) ** 2 + (nz - r.z) ** 2 < (0.4 + r.r) ** 2);
  if (!blocked) { player.x = nx; player.z = nz; }
  const moving = Math.hypot(mx, my) > 0.2;
  if (moving) player.yaw = Math.atan2(mx, my);
  const want = moving ? "Run" : "Idle";
  if (want !== player.clip) { player.clip = want; hero.play(want, { fade: 0.2 }); }
  hero.update(dt);
};

app.draw = (w, h) => {
  gfx.clear("#20242C");
  if (!hero) {
    gfx.color("#FFFFFF");
    gfx.text(error ? TR("load_failed", error) : TR("loading"), 24, h - 48, 16, "mono");
    return;
  }
  g3d.begin(0, 0, w, h, 55, 0.1, 60);
  g3d.camera(player.x, 5, player.z + 7, player.x, 0.8, player.z);
  g3d.light(-0.4, 1, 0.3, 0.4);
  g3d.draw(hero, player.x, 0, player.z, 0, player.yaw, 0);
  for (const r of rocks) g3d.draw(rock, r.x, 0, r.z, 0, 0, 0, r.r * 2);
  const m = hero.nodeMatrix("Lamp", player.x, 0, player.z, 0, player.yaw, 0);
  if (m) g3d.drawMatrix(rock, m, "#FFB45A", "glow unlit");
  g3d.finish();
};

app.event = (e) => {
  if (e.type === "keydown" && e.key) held.add(e.key);
  if (e.type === "keyup" && e.key) held.delete(e.key);
};
```

**Python** (`main.py`): `g3d.loadModel(path, size=None, callback=None)` `callback(model, err)`'u çağırır;
`model.play(clip, loop, speed, fade)`.

```python
class Game:
    def load(self, arg):
        self.hero = None
        self.error = ""
        self.x = 0.0
        self.yaw = 0.0
        g3d.loadModel("bundle:/models/hero.glb", None, self.on_hero)   # parsed in the background

    def on_hero(self, model, err):
        if model:
            self.hero = model
            model.play("Idle", True, 1.0, 0.0)
        else:
            self.error = str(err)

    def update(self, dt):
        if self.hero:
            sx, sy = input.stick("left")
            self.x += sx * 4 * dt
            self.hero.update(dt)

    def draw(self, w, h):
        gfx.clear("#1B1F27")
        if not self.hero:
            gfx.color("#FFFFFF")
            gfx.text(TR("loading") if not self.error else self.error, 24, h - 48, 16, "mono")
            return
        g3d.begin(0, 0, w, h, 55, 0.1, 60)
        g3d.camera(self.x, 4, 7, self.x, 0.8, 0)
        g3d.light(-0.4, 1, 0.3, 0.4)
        g3d.draw(self.hero, self.x, 0, 0, 0, self.yaw, 0)
        g3d.finish()


app = Game()
```

Konsoldaki Python (pocketpy) üçünün en yavaşıdır: kare başına işi küçük tutun ya da 3B oyun için Lua kullanın.

## Ayrıca bakın

[SDK başvurusu](../Reference/SDK.tr.md) (8b *3B modeller*, 8c *2D oyun motoru*) · [Oyun motoru rehberi](GAME_ENGINE.tr.md) ·
[Geliştirici rehberi](DEVELOPER_GUIDE.tr.md) · [Uyumluluk](COMPATIBILITY.tr.md) ·
App Market'te yayın: public depoda `SDK/Publishing/PUBLISHING.tr.md` ve `SDK/Publishing/REVIEW.tr.md` ·
AI prompt'ları: `SDK/AI/tasks/make-3d-game.tr.md` ve `SDK/AI/tasks/store-icon.tr.md`.
