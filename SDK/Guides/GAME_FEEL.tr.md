# Nexvyn OS oyunları için grafik, arayüz ve oyun hissi

[English](GAME_FEEL.en.md) · **Türkçe**

Hızlı yapılan oyunların çoğu (insanın da AI asistanın da yaptığı) aynı yerlerden birbirine benzer: düz tek renk arka
plan, varsayılan boyutta varsayılan yazı, bir anda beliren ve kaybolan dikdörtgenler, başlık ekranında kıpırdamayan
her şey, bir şeye vurulunca hiçbir tepki yok. Bu rehber bunları düzelten yapı taşlarını ve onları uygulayan **his
kitini** anlatır:

- Lua: `SDK/Languages/lua/kits/juice.lua` · JavaScript: `SDK/Languages/javascript/kits/juice.js` (aynı kit).
- kits klasörleri çalışan demo app'lerdir (`main.lua`: "Forge", `main.js`: "Signal"); aynı taşlardan iki farklı sanat
  yönü. `juice.lua` / `juice.js` dosyasını `main` dosyanızın yanına kopyalayın.

Kit **şablon değil yapı taşı** verir: kullanmak zorunda olduğunuz bir menü düzeni, başlık ekranı ya da palet yoktur.
Oyununuzun yine kendi sanat yönü olmalı ([MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md), bölüm 11). Sesin ayrı rehberi var:
[SOUND_DESIGN.tr.md](SOUND_DESIGN.tr.md).

```lua
local J = require("juice")
function app.load() J.init() end                         -- glow, vignette, grain, shadow, ray dokularını bir kez yapar
function app.update(dt) J.update(dt); world:update(J.dt(dt)) end   -- hit-stop sırasında J.dt = 0
function app.event(e) J.event(e) end
function app.draw(w, h)
  local sx, sy = J.shakeOffset(14)
  gfx.push(sx, sy)  drawWorld()  J.drawParticles()  J.drawFloaters()  gfx.pop()
  J.vignette(w, h, 0.5)  drawHud()  J.overlay(w, h)  J.endFrame()
end
```

Aşağıdaki her taşın bir **öncesi** (hızlı yapılan oyunun yaptığı) ve bir **sonrası** (taşın yaptığı) var.

## 1. Hareket

| Taş | Önce | Sonra |
|---|---|---|
| **Easing** `J.ease.outCubic`, `outBack`, `outElastic`, `inOutSine`... | panel gizliden görünüre zıplar | hızlı kayıp yerine oturur (`outCubic`) ya da biraz taşıp döner (`outBack`) |
| **Tween** `J.tween(obj, 0.3, {y = 40}, "outBack", {delay, done, loop, yoyo})` | değerler doğrudan atanır | herhangi bir tablonun herhangi bir alanı gecikmeli ve zincirli canlanır |
| **Sönümleme** `x = J.damp(x, target, 10, dt)` | `x = target` ya da `x = x + (target - x) * 0.1` (hız kare hızına bağlı) | 30 ve 60 fps'te aynı görünen yumuşak takip |
| **Yay** `J.spring(state, target, dt, 4, 0.5)` | renk değiştiren düğmeler | hafifçe sekip yerine oturan düğmeler, imleçler, kartlar: canlı |

Kural: ekranda hiçbir şey bir anda belirmez. Her beliriş, kayboluş, hareket, değer ve renk değişimi hareket
üslubunuza uyan bir easing ile 0.1-0.4 s sürer (keskin: `outQuart`, 0.12 s; süzülen: yaylar, 0.4 s; ağır: kısa
gecikmeli `outCubic`).

## 2. Vuruş (oyun hissi)

| Taş | Önce | Sonra |
|---|---|---|
| **Ekran sarsıntısı** `J.shake(0.4)` + `J.shakeOffset(px)` | bomba patlarken ekran kıpırdamaz | trauma tabanlı (gücün karesi), yumuşakça sönen sarsıntı; rastgele titreme değil |
| **Hit-stop** `J.hitstop(0.05)`, `J.dt(dt)` | vuruşlar içinden geçip gider | ağır vuruşta oyun 2-6 kare durur: vuruş *oturur* |
| **Ağır çekim** `J.slowmo(0.3, 0.6)` | son düşman öylece kaybolur | son darbede bir anlık ağır çekim |
| **Flaş** `J.flash(color, 0.15, 0.4)` | | sönen tam ekran renk: hasar (kırmızı), toplama (altın), seviye atlama (beyaz) |
| **Parçacıklar** `J.burst(x, y, "sparks" / "embers" / "dust" / "smoke" / "confetti" / "magic" / "hit")` | altın kaybolur | kıvılcımlar saçılır, bir halka genişler, közler süzülür; yumuşak parlayan sprite'lar, ömür boyunca renk, yerçekimi, sürtünme |
| **Uçan yazı** `J.floatText("+10", x, y, color)` | skor sessizce değişir | sayı fırlar (`outBack`), yükselip söner |
| **3D kamera tekmesi** `cam:kick(8)` | | atılmada ya da vuruşta görüş açısı bir an genişler |

Birleştirin: ağır bir vuruş `J.burst(x, y, "hit")` + `J.burst(x, y, "sparks")` + `J.shake(0.5)` + `J.hitstop(0.06)` +
`J.flash(...)` + katmanlı bir vuruş sesi + hafif bir `sys.vibrate(0.6, 80)`, **hepsi aynı karede**. Toplama daha
küçüktür: birkaç kıvılcım, yumuşak bir çan, bir uçan yazı, sarsıntı yok. Tepkiyi olayla ölçekleyin; her şey sarsılırsa
hiçbir şey büyük hissettirmez.

## 3. Işık ve derinlik (2D)

| Taş | Önce | Sonra |
|---|---|---|
| **Gradyan** `J.gradient(x, y, w, h, {deep, bg, mid})` | `gfx.clear("#203040")` | derinliği olan gökyüzü ya da zemin; birden çok durak |
| **Parlama** `J.glow(x, y, r, color, alpha)` | lamba sarı bir dairedir | parlak çekirdekli yumuşak hale (üretilmiş, renklendirilmiş doku) |
| **Vinyet** `J.vignette(w, h, 0.5)` | düz köşeler | koyulaşan kenarlar gözü ortaya çeker |
| **Gren** `J.grain(w, h, 0.04)` | temiz dijital düzlük | %3-5 hareketli film greni: gürültüsüz doku |
| **Yumuşak gölge** `J.blob(x, y, w, h)`, `gfx.shadow` (`J.panel` kullanır) | karakterler zeminin üstünde süzülür | her karakterin ve nesnenin altında yumuşak temas gölgesi |
| **Işık huzmeleri** `J.rays(x, y, len, count, color, alpha, t)` | | pencereden ya da gökten yavaşça salınan ışık huzmeleri |
| **Paletler** `J.palettes.ember` (deep, bg, mid, ink, accent, accent2, light), `J.mix`, `J.shade`, `J.alpha` | on rastgele renk, OS renkleri (`theme.*`) | rolleri olan 4-6 renk; her şey birbirinden karıştırılıp tonlandığı için birbirine ait |

Kitteki paletler başlangıç noktasıdır: renk tonlarını oyununuza göre kaydırın. Paletinizi gri tonda kontrol edin:
oyuncu, tehlike ve etkileşimli şeyler yine de öne çıkmalı.

## 4. Tipografi

SDK yazıyı sistem fontlarıyla (`"sans"`, `"medium"`, `"semibold"`, `"bold"`, `"italic"`, `"mono"`, `"monobold"`)
istenen boyutta çizer. Varsayılan boyutta `gfx.text(title, x, y)` ile yazılmış bir oyun başlığı bitmemiş oyunun en
açık işaretidir. Kitle:

| Taş | Kullanım |
|---|---|
| `J.scale(base, ratio)` | bir tip ölçeği (`xs` ... `display`); bütün oyunda 3-4 basamağını kullanın |
| `J.spaced(s, x, y, size, font, spacing, align, w)` | harf aralığı (tracking): başlık ve etiketler için geniş aralıklı büyük harfler |
| `J.title(s, x, y, size, {fill, fill2, outline, outlineW, shadow, glow, spacing, align, w})` | logo gibi başlık: iki tonlu dikey gradyan, dış hat, katmanlı gölge, arkada parlama |
| `J.fit(s, maxW, size, font)` | (çevrilmiş) bir yazının sığdığı boyut |

Önce: `gfx.text("SKY HOP", 0, 40, 24, "bold", "center", w)`. Sonra: `J.title("SKY HOP", 0, h * 0.12, h * 0.16,
{fill = P.light, fill2 = P.accent, outline = P.deep, shadow = "#00000099", glow = P.accent, align = "center", w = w,
spacing = 10})`, `math.sin(t)` ile hafifçe salınarak. Resim olarak çizilmiş bir logo ya da bitmap font
([MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md) bölüm 7) daha da iyidir.

## 5. Derinliği olan arayüz

| Taş | Önce | Sonra |
|---|---|---|
| **Paneller** `J.panel(x, y, w, h, {shape, fill, fill2, border, shadow, depth, highlight})` | düz bir dikdörtgen | yumuşak gölgeli, altında koyu bir taban (`depth`), üst kenarında ışık (`highlight`), gradyanlı panel |
| **Şekil dili** `shape = "round" / "pill" / "cut" / "slant" / "tab"` | OS'un yuvarlak düğmeleri | bütün oyun için tek şekil: kesik köşe (bilimkurgu), eğik (aksiyon), hap (sıcak), sekme |
| **Düğmeler** `J.button(id, label, x, y, w, h, {focused, activate, shape, fill, fillHover, ink, glow, depth})` | `ui.button` (OS'un görünümü) ya da renk değiştiren bir dikdörtgen | üstüne gelince yükselir, basınca tabanına gömülür, kumanda odağı çerçeve ve parlama çizer, renkler yumuşak geçer; `J.onUi` hover ve basma seslerinizi çalar |
| **Geçişler** `J.transition("fade" / "iris" / "wipe" / "blinds" / "pixels", 0.6, switchFn, color)` | ekranlar birbirinin yerine geçer | ekran örtülür, ortada değişir, açılır |

Oyun menüleri asla `ui.*` widget'larıyla (OS'un kendi kontrolleri) kurulmaz. `J.button` yalnızca durumu yönetir ve
sizin renk ve şeklinizle çizer; yerleşim sizindir (bir sıra, kartlar, bir sütun, dünyadaki nesneler).

## 6. Kameralar

- **2D:** `cam = J.camera{lag = 7, lead = 0.25, dead = {w = 80, h = 50}, bounds = {...}}`; her karede
  `cam:follow(px, py, vx, vy, dt)`, sonra `gfx.push(cam:offset(w, h, 14))`. Hareket yönüne bakış, küçük hareketlerde
  kamerayı oynatmayan ölü bölge, yumuşak sönümleme, sınırlar; sarsıntı dahil.
- **3D:** `cam = J.cam3d{dist = 6, height = 2.5, lookHeight = 1, lag = 6, fov = 55}`; `cam:follow(x, y, z, yaw, dt)`,
  `g3d.begin(0, 0, w, h, cam:fov())`, `cam:apply()`. Kamera kahramanın arkasına en kısa yoldan, yumuşakça döner.

## 7. 3D ışık, sis ve gökyüzü

`J.looks.dusk / noon / night / toxic / frost / desert / abyss / synth` eksiksiz atmosferlerdir: gökyüzü renkleri,
ufuk, sis rengi, ışık yönü, ortam ışığı ve ışık rengi, bir parlama vurgusu.

```lua
local L = J.looks.dusk
J.sky(w, h, L)                      -- ufuk parlamalı gradyan gökyüzü (g3d.begin'den önce)
g3d.begin(0, 0, w, h, cam:fov(), 0.1, 60)
J.light3d(L, 60)                    -- g3d.light + g3d.fog (sis far'ın %35'inden %100'üne, ufuk renginde)
-- çizim; ışık saçan parçalar ve "glow unlit" mesh'ler L.glow renginde
g3d.finish()
J.vignette(w, h, 0.45)
```

Önce: gri sis, tam tepeden beyaz ışık, siyah arka plan. Sonra: gökyüzüyle aynı renkte sis (uzak düzlem görünmez),
yandan sıcak ana ışık, lambalarda ve toplanabilirlerde renkli haleler.

## 8. Kalite çıtası

Bir oyun şu maddelerin hepsi doğru olduğunda mağazaya hazırdır:

- [ ] **Geri bildirim:** oyuncunun her eyleminin aynı karede bir sesi ve görsel tepkisi var (parçacık, flaş, ezilme,
      sayı); vuruşlar ölçekli (toplama küçük, boss vuruşu kocaman).
- [ ] **Hareket:** hiçbir şey bir anda belirmiyor; ekranlar geçişle değişiyor; başlık ekranında canlı bir şey var.
- [ ] **Renk:** rolleri olan 4-6 renklik palet (koyu, açık, oyuncu ve eylemler için vurgu, tehlike ve ödül için
      vurgu); düz tek renk arka plan yok (gradyan, ışık, doku, paralaks); gri tonda okunuyor.
- [ ] **Yazı:** 3-4 boyutluk tip ölçeği; başlık bir logo (dış hat, gölge, iki ton ya da parlama ile ya da resim),
      asla varsayılan boyutta varsayılan yazı değil; etiketler aralıklı, değişen sayılar `mono`.
- [ ] **Arayüz:** her yerde tek şekil dili; derinliği olan paneller (gölge, taban, ışık kenarı); düğmelerin hover,
      basılı, odak ve devre dışı hâlleri var; kumanda odağı hep görünür.
- [ ] **Işık:** vinyet ya da çerçeve; karakterlerin altında yumuşak gölge; ışık saçan şeylerde parlama; 3D'de
      gökyüzü renginde sis ve renkli, yandan gelen ana ışık.
- [ ] **Kamera:** yumuşak takip (katı kilit yok), sarsıntı yalnızca vuruşlarda.
- [ ] **Ses:** [SOUND_DESIGN.tr.md](SOUND_DESIGN.tr.md) kontrol listesi: katmanlı efektler, müzik ve ambiyans,
      dengeli seviyeler, ducking.
- [ ] **Hız:** bunların hepsiyle konsolda 60 fps: birkaç yüzün altında parçacık, bir kez yapılmış dokular (`J.init`),
      karede parçacık başına tablo ya da string üretilmiyor (kit tek bir renk tablosunu yeniden kullanır).
