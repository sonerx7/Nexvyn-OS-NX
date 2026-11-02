# Kor Tarlası (Ember Field)

[English](README.md) · **Türkçe**

[Oyun yap](../../../Guides/MAKE_A_GAME.tr.md) rehberinin anlattığı yolla yapılmış küçük ama eksiksiz bir 3B oyun:
yuvarlak bir kurye kuş, alacakaranlıkta uçan bir adada korları toplar, taşlar adanın üzerinden yuvarlanır. Üç fener
söndü mü oyun biter.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.emberfield` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.8 (hedef 1.8) |
| İzinler | yok |
| Kumanda | evet (klavye ve dokunmatik de) |
| Pencere | 960 × 540, boyutlandırılabilir (tam ekran açılır) |
| Diller | İngilizce, Türkçe |

## Ne öğretir

- `g3d.loadModel`: iki model de başlık ekranı oynarken arka plandaki bir thread'de yüklenir; modeller gelene kadar
  *Oyna* gri kalır, yükleme hatası bir mesajla gösterilir
- Üç klipli, skin'li bir `.glb` kahraman: `Idle` ve `Run` döngüde ve geçişli, `Hop` bir kez oynar ve geri verir
  (`model:playing()`); koşu hızı harekete uyar
- Takılan nesne: parlak hale `model:nodeMatrix` + `g3d.drawMatrix` ile `Lamp` kemiğinde durur
- `g3d.custom` ile kurulan yükseklik haritalı ada; aynı yükseklik fonksiyonu kahramanı ve taşları zeminde tutar
- Fizik motorsuz çarpışma: daire-daire (taşlar, korlar, ağaç gövdeleri) ve ada kenarı
- Durumlar (başlık, nasıl oynanır, oyun, duraklatma, oyun sonu); +, askıya alma ve odak kaybında duraklatma;
  `store`'da en iyi puan
- Kendine ait bir sanat yönü: alacakaranlık paleti, kaydırılmış baskılı geniş aralıklı başlıklar, dalgalı alt
  çizgili yatay menü, eğik kartlar. **Kopyalamayın:** oyununuzun kendi yönü olmalı (rehberin 11. bölümü)
- `art/make_models.py` iki modeli Blender'da bir script'le kurar ve canlandırır; `art/make_keyart.py` mağaza ikonunu
  aynı modelden render eder (sembol değil key art)

**Kullanılan API'ler:** `g3d.loadModel`, `model:play/update/playing/nodeMatrix`, `g3d.drawMatrix`, `g3d.custom`,
`g3d.mesh`, `"glow unlit nocull"` ile `g3d.draw`, `g3d.fog/light/camera`, `gfx.gradient/poly/lines/text/wrap`,
`audio.tone`, `sys.vibrate`, `timer.after`, `store`

**Kontroller:** sol çubuk, yön tuşları, WASD / oklar ya da parmak sürükleme: yürü · A / Enter: seç · sol / sağ: menü ·
+ / Esc / P ya da sağ üstteki düğme: duraklat.

## Koddan bir parça

Hale, animasyonlu modelin bir kemiğini izler; klip yalnızca durum değişince değişir:

```lua
if hero.clip == "Hop" then
    if not pip:playing() then hero.clip = "" end
elseif speed > 0.8 then playClip("Run", {fade = 0.15, speed = 0.7 + speed * 0.12})
else playClip("Idle", {fade = 0.25}) end
pip:update(dt)
-- ...
g3d.draw(pip, x, y, z, 0, yaw, 0)
local m = pip:nodeMatrix("Lamp", x, y, z, 0, yaw, 0)                 -- the halo rides on the "Lamp" bone
if m then g3d.drawMatrix(halo, m, "#FFFFFF", "glow unlit nocull") end
```

## Çalıştırma

`source/` klasörünü `sdmc:/NexvynOS/Applications/` içine `EmberField.nxvapp` adıyla kopyalayın ya da Studio'nun
şablonlarından başlatın (*3B oyun: Kor Tarlası*). Dosyalar: `main.lua`, `app.json`, `lang/en.json`, `lang/tr.json`,
`icon.png`, `models/pip.glb` (986 üçgen, 8 kemik, 3 klip), `models/rock.glb` (80 üçgen).

PC'de denetleme (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/ember-field/source --frames 1500

Modelleri ya da ikonu yeniden üretmek için (Blender 5.2 ile denendi):

    blender -b --factory-startup -P art/make_models.py -- source/models
    blender -b --factory-startup -P art/make_keyart.py -- source/models/pip.glb keyart.png 1024

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |

Modeller, ikon ve kod bu örnek için yapıldı (SDK örnekleri gibi GPL-3.0-or-later).
