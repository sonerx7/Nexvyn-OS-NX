# Lua için oyun kitleri

[English](README.md) · **Türkçe**

Oyununuzun `main.lua` dosyasının yanına kopyalanacak, bağımlılığı olmayan iki dosya ve ikisini kullanan bir demo app
("Forge"). Görmek ve duymak için bu klasörü app olarak çalıştırın (Studio: klasörü açın, **Çalıştır**; ya da
`sdmc:/NexvynOS/Applications/KitDemo.nxvapp/` konumuna kopyalayın).

| Dosya | Ne verir | Rehber |
|---|---|---|
| [`sfx.lua`](sfx.lua) | Ses tasarımı: veri klasöründe bir kez WAV dosyasına üretilen katmanlı prosedürel tarifler (vuruş, altın, zıplama, lazer, patlama, güç alma, hasar, savrulma, menü tıkları, beş zeminde ayak sesi, jingle, ambiyans zeminleri ve ayrıntıları, akor ilerlemesinden müzik döngüleri); varyantlar, bus'lar, ducking, ses sınırları, bekleme süreleri | [SOUND_DESIGN.tr.md](../../../Guides/SOUND_DESIGN.tr.md) |
| [`juice.lua`](juice.lua) | Grafik, arayüz ve his: easing ve tween, yaylar, sönümleme, ekran sarsıntısı, hit-stop, ağır çekim, flaş, parlayan parçacıklar, uçan yazı, üretilen parlama / vinyet / gren / gölge / huzme dokuları, çok duraklı gradyanlar, paletler, stilli başlıklar ve harf aralığı, derinlikli paneller, durumlu düğmeler, geçişler, 2D ve 3D kameralar, 3D ışık atmosferleri | [GAME_FEEL.tr.md](../../../Guides/GAME_FEEL.tr.md) |
| `main.lua`, `app.json`, `lang/`, `icon.png` | demo | |

```lua
local sfx = require("sfx")
local J = require("juice")
function app.load()
  J.init(); sfx.init()
  sfx.define("hit", sfx.recipes.impact{weight = 0.7}, {variants = 4, duck = {"music", 0.45, 0.25}})
end
function app.update(dt) sfx.update(dt); J.update(dt) end
-- vuruşta: sfx.play("hit"); J.burst(x, y, "sparks"); J.shake(0.4); J.hitstop(0.05)
```

İkisi de yalnızca SDK 1.0 çağrıları kullanır (`minSdk` oyununuzun gerektirdiği kadar kalır). Ürettikleri dosyaları
app'in veri klasörüne (`sfx/`, `fx/`) yazar, bir tarif değişince yeniden yaparlar. Oyununuzu her zamanki gibi
denetleyin: Nexvyn OS kaynak deposunda `python tools/lua_check.py MyGame.nxvapp` ya da `nxv check --sdk`.

Demo yapı taşlarının bir örneğidir, kopyalanacak bir menü değildir: oyununuza kendi sanat yönünü verin.
