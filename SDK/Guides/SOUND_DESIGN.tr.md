# Nexvyn OS oyunları için ses tasarımı

[English](SOUND_DESIGN.en.md) · **Türkçe**

Ses, bir oyunun nasıl hissettirdiğinin yarısıdır. Her eylemde ham bir `audio.tone(440, 0.1, 1, "square")` oyunu ucuz
ve yorucu gösterir; aynı oyun katmanlı, mikslenmiş, çeşitlenmiş seslerle bitmiş hissettirir. Bu rehber SDK ile oraya
nasıl varılacağını anlatır, işi de **ses kiti** yapar:

- Lua: `SDK/Languages/lua/kits/sfx.lua` · JavaScript: `SDK/Languages/javascript/kits/sfx.js` (aynı kit, aynı tarifler).
- Her kits klasörü aynı zamanda çalışan bir demo app'tir (`main.lua` / `main.js`): kiti his kitiyle birlikte kullanır
  (`juice.lua` / `juice.js`, bkz. [GAME_FEEL.tr.md](GAME_FEEL.tr.md)). Kit dosyasını `main` dosyanızın yanına kopyalayın.

## 1. SDK ne veriyor, kit ne ekliyor

| SDK çağrısı | Ne yapar |
|---|---|
| `audio.play(path, volume, loops)` → kanal | `.wav` / `.ogg` / `.mp3` çalar (bir kez çözülür, bellekte kalır); `loops = -1` tekrarlar |
| `audio.tone(freq, seconds, volume, wave)` | tek ham nota: sine, square, saw, triangle ya da noise |
| `audio.music(path)`, `audio.musicPause`, `audio.musicStop` | akıtılan tek şarkı |
| `audio.stop(channel)` | bir sesi durdurur |

Çalmakta olan bir sesin perdesi, filtresi ya da ses seviyesi değiştirilemez; mikserde de bütün sistem için 24 kanal
var. Bu yüzden kit her sesi bir tariften bir kez app'in veri klasöründe 16-bit WAV dosyasına **üretir**, ham tonda
eksik olan her şeyle birlikte, ve `audio.play` ile çalar:

- ses başına katmanlar (gövde, vuruş anı, kuyruk); her birinin kendi osilatörü (sine, triangle, band-limited saw ve
  pulse, beyaz / pembe / kahverengi gürültü, FM, unison detune), perde kayması, vibrato, tremolo, ADSR zarfı ve
  kaymalı, LFO'lu low / high / band-pass filtreleri;
- eko, küçük bir oda yankısı, yumuşak kırpma (drive), DC temizleme, tepe normalizasyonu ve tıkırtısız kenarlar;
- **varyantlar**: her sesin 3-4 hafif farklı hâli (perde, filtre, seviye), son çalınanı tekrarlamadan rastgele seçilir;
- **bus**'lar `music`, `sfx`, `ui`, `amb` ve `master`, seviyeleriyle; **ducking** (büyük bir vuruş müziği bir an
  kısar), ses başına ve kit için **ses sınırı**, aynı karede on toplamanın üst üste binmemesi için **bekleme süresi**;
- **ambiyans**: kesintisiz dönen zeminler (rüzgâr, yağmur, gece, mağara, okyanus, makine uğultusu, ateş) ve rastgele
  tek seferlik ayrıntılar (kuş, damla, çıtırtı, cırcır böceği, gıcırtı);
- **müzik**: her dizide bir akor ilerlemesinden kurulan kısa döngüler (pad, bas, arpej, davul), ses yürütmeli, katman
  başına seviye, eko ve odayla mikslenmiş; tek kesintisiz döngü dosyası ya da müziğin kısılabilmesi için ölçü başına
  bir dosya.

Üretim `sfx.update(dt)` içinde kare başına birkaç milisaniye çalışır (3 saniye sınırına hiç yaklaşmaz), dosyalar
saklanır: oyunun ikinci açılışında hemen yüklenir. İlk açılışta yükleme ekranınızda `sfx.progress()` gösterin.
Tarif değişince yeni dosyalar kendiliğinden yapılır (dosya adında tarifin hash'i var).

## 2. On dakikada iyi ses

```lua
local sfx = require("sfx")
function app.load()
  sfx.init()
  local R = sfx.recipes
  sfx.define("jump", R.jump{weight = 0.3}, {variants = 3})
  sfx.define("coin", R.coin(), {variants = 3})
  sfx.define("hit", R.impact{weight = 0.8}, {variants = 4, duck = {"music", 0.45, 0.25}})
  sfx.define("boom", R.explosion{size = 0.7}, {duck = {"music", 0.3, 0.6}})
  sfx.define("step", R.footstep{surface = "grass"}, {variants = 4, vol = 0.5, cooldown = 0.08})
  sfx.define("tick", R.ui{kind = "tick"}, {bus = "ui"})
  sfx.define("ok", R.ui{kind = "confirm"}, {bus = "ui"})
  sfx.define("wind", R.ambience{kind = "wind"})
  sfx.define("bird", R.detail{kind = "bird"}, {bus = "amb", variants = 3})
  sfx.song("theme", R.song{bpm = 96, root = "A2", scale = "minor", chords = {1, 6, 3, 7}, drums = "soft"})
  sfx.ambience("wind", {details = {"bird"}, every = {3, 8}})
  sfx.music("theme")
end
function app.update(dt) sfx.update(dt) end
-- oyunda: sfx.play("jump"), sfx.play("hit"); ayarlarda: sfx.setBus("music", value)
```

JavaScript'te nesne ve dizilerle aynısı: `sfx.define("hit", sfx.recipes.impact({ weight: 0.8 }), { variants: 4,
duck: ["music", 0.45, 0.25] })`.

## 3. Sesler nasıl iyi hissettirir

1. **Her önemli sesi katmanlayın.** Akılda kalan bir sesin üç parçası var: **vuruş anı** (ilk 5-20 ms: bir tık, bir
   gürültü patlaması; *ne zaman* olduğunu söyler), **gövde** (duyduğunuz perde; *ne* olduğunu söyler) ve **kuyruk**
   (eko, oda, alçak bir gümleme; *ne kadar büyük* olduğunu söyler). `R.impact` bir sine gümlemesi + band-pass
   gürültü çatlaması + kısa tiz bir tık + biraz drive'dır. Kendi tariflerinizde bu deseni kopyalayın.
2. **Tam seviyede ham kare dalga yok.** Square ve saw parlak ve serttir. Filtreleyin (`lp = {cut = 1800}`), bir sine
   ya da triangle gövdenin altına indirin, daha ince ve hoş bir ton için dar `duty` kullanın ya da filtreyi aşağı
   kaydırın (`lp = {cut = 4000, to = 900}`). Saf square'i bilinçli chiptune oyunlarına bırakın, onlarda da tizleri
   kırpın.
3. **Perde hareket eder.** Yükselen şeyler (zıplama, güç alma, menüde ileri) yukarı kayar; düşen ya da biten şeyler
   (hasar, geri, oyun sonu) aşağı kayar. Sabit perde bip gibi, kayan perde olay gibi duyulur.
4. **Büyüklük bas ve uzunluktur.** Küçük şeyler: kısa, tiz, kuyruksuz. Büyük şeyler: alt bas gümlemesi (`sine`
   110 → 30 Hz), düşen low-pass'li daha uzun gürültü, bir oda. Kahramanın seslerini düşmanlarınkinden biraz ağır yapın.
5. **Çeşitlilik.** Oyuncunun dakikada birkaç kez duyduğu her şeyin 3-4 varyantı olmalı (`variants = 4`): ayak sesi,
   atış, vuruş, toplama. Kit perdeyi yaklaşık bir yarım ton, filtreyi ve seviyeyi değiştirir.
6. **Tek aile.** Bütün oyun için tek dalga seti, aynı oda, aynı eko süresi. Piksel oyununda triangle ve pulse;
   bilimkurguda FM ve saw; sıcak bir oyunda sine ve yumuşak gürültü. Aileyi sanat yönünüze yazın
   ([MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md) bölüm 11).
7. **Her eylem karşılık verir.** Menüde gezinme, onay, geri, hata, zıplama, yere inme, vurma, vurulma, toplama, kapı
   açma, kazanma, kaybetme: her birinin sesi olur ve görsel karşılık aynı karede gelir ([GAME_FEEL.tr.md](GAME_FEEL.tr.md)).
8. **Sessizlik de araçtır.** Her şeyin sesi olmak zorunda değil. Bir boss'tan önce müziği kesin, sakin anları
   ambiyans taşısın, sürekli çalan sesleri kısın (her karede ayak sesi gürültüdür: bekleme süresi kullanın ya da
   animasyonun adım karesinde çalın).

## 4. Seviyeler ve miks

Kit her dosyayı -1 dB tepeye normalize eder; seviyeler tanımdaki `vol` ve bus'lardan gelir.

| Ne | Bus | Başlangıç | Not |
|---|---|---|---|
| Oyuncunun eylemleri, vuruşlar, toplamalar | `sfx` | `vol` 0.8-1 | oyundaki en yüksek ses |
| Düşmanlar, dünya, ayak sesleri | `sfx` | `vol` 0.4-0.7 | oyuncunun kendi seslerinin altında |
| Menüde gezinme, tıklar | `ui` | bus 0.7 | kısa ve yumuşak; onay tıktan biraz yüksek |
| Ambiyans zeminleri ve ayrıntılar | `amb` | bus 0.5-0.6 | durunca fark edilir |
| Müzik | `music` | bus 0.45-0.55 | efektlerin altında; büyük anlarda kısın |

- Önemli anlarda müziği **kısın**: ağır bir vuruşta `duck = {"music", 0.45, 0.25}`, patlamada ya da boss kükremesinde
  daha derin ve uzun. Varsayılan `"loop"` modundaki müzik tek kesintisiz dosyadır ve kısılmaz (SDK çalan bir sesin
  seviyesini değiştiremez); şarkı sırasında ducking ve seviye değişikliği istiyorsanız `{mode = "bars"}` kullanın
  (bir sonraki ölçüde uygulanır).
- Ayarlarınızda oyuncuya müzik, efekt ve ambiyans seviyesi **verin** (`sfx.setBus`), `store` ile kaydedin.
- **Ses sınırı koyun**: ses başına `maxVoices` (varsayılan 3) ve kit için `sfx.maxVoices` (varsayılan 12): sistemin
  toplam 24 kanalı var, aynı sesten bir duvar birkaç tanesinden kötüdür.
- **Konsol hoparlöründe ve kulaklıkta dinleyin.** Küçük hoparlörler ~200 Hz altını kaybeder: bir vuruşa yalnızca
  alt bas değil, gürültü çatlaması ve orta frekans gövdesi de gerekir.

## 5. Müzik

`sfx.recipes.song{...}` bir akor ilerlemesinden döngü yazar:

| Seçenek | Değerler |
|---|---|
| `bpm`, `root`, `scale` | tempo; ton (`"A2"`, `"D3"`...); `major`, `minor`, `dorian`, `phrygian`, `lydian`, `mixolydian`, `harmonic`, `pentatonic` |
| `chords` | ölçü başına bir dizi derecesi: `{1, 6, 3, 7}` (hüzünlü, destansı), `{1, 5, 6, 4}` (parlak pop), `{1, 4, 6, 5}` (dorian, maceracı), `{1, 2, 6, 5}` (lydian, rüya gibi) |
| `pad`, `bass`, `arp`, `drums` | `bass` `"pulse"` / `"walk"` / `"simple"`; `arp` `"up"` / `"updown"` / `"random"`, `arpRate` 8 ya da 16; `drums` `"soft"` / `"drive"` / `"half"`; `false` o partisyonu kapatır |
| `padGain`, `bassGain`, `arpGain`, `drumsGain` | katman seviyeleri, dB |
| `sevenths`, `seed` | daha zengin akorlar; başka bir rastgele arpej |

Aynı enstrümanlarla farklı ton ya da tempoda 2-3 şarkı (başlık, oyun, gerilim) ve kazanma, kaybetme, seviye atlama
için kısa jingle'lar (`R.jingle{notes = {"C5", "E5", "G5", "C6"}}`) kullanın. Uzun bir film müziği için bir müzik
aracında yapılmış, akıtılan bir `.ogg` hâlâ en iyisidir; efektlerden kısık master edin (yaklaşık -14 LUFS).

## 6. Kendi tarifinizi yazmak

Tarif bir katman tablosudur; süreler saniye, frekanslar Hz:

```lua
local zap = {layers = {
  {wave = "saw", freq = 1400, to = 300, glide = 0.15, len = 0.2, a = 0.001, d = 0.1, s = 0.2, r = 0.08,
   lp = {cut = 5000, to = 1200, q = 1.2}, vol = 0.6, fm = {ratio = 2, index = 1.5, to = 0}},   -- gövde
  {wave = "noise", len = 0.02, a = 0.0005, d = 0.015, s = 0, r = 0.003, hp = {cut = 4000}, vol = 0.4},  -- vuruş anı
  {wave = "sine", freq = 90, to = 50, at = 0.01, len = 0.12, a = 0.001, d = 0.08, s = 0, r = 0.03, vol = 0.5}}, -- ağırlık
  echo = {time = 0.07, feedback = 0.25, mix = 0.2}, drive = 0.1}
sfx.define("zap", zap, {variants = 3})
```

Katman alanları: `wave`, `freq`, `to`, `glide`, `at`, `len`, `a`, `d`, `s`, `r`, `vol`, `duty`, `unison`, `cents`,
`fm = {ratio, index, to}`, `vib = {rate, depth}` (yarım ton), `trem = {rate, depth}`, `lp` / `hp` / `bp =
{cut, to, q, lfo = {rate, depth}}` (oktav), `stem`. Tarif alanları: `layers`, `len`, `echo = {time, feedback, mix}`,
`room = {size, mix, damp}`, `drive`, `peak` (dB), `gain` (dB), `tail`, `loop`, `crossfade`, `stems`.

## 7. Kontrol listesi

- [ ] Oyuncunun ve menünün her eyleminin sesi var; önemlilerin 3-4 varyantı var.
- [ ] Ham, filtresiz, tam seviye square ya da saw yok; seslerin vuruş anı, gövdesi ve (büyükse) kuyruğu var.
- [ ] Tek ses ailesi; baştan sona aynı oda ve eko.
- [ ] Müzik efektlerin altında, büyük anlarda kısılıyor; sakin sahnelerde ambiyans zemini var.
- [ ] Ayarlarda müzik, efekt ve ambiyans seviyesi var ve kaydediliyor.
- [ ] İlk açılış üretim ilerlemesini gösteriyor; hiçbir şey bir kareyi kilitlemiyor.
- [ ] Konsol hoparlöründe ve kulaklıkta dinlendi.
