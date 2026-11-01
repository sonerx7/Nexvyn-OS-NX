# Oyun Motoru (Game Engine)

**Türkçe** · [English](GAME_ENGINE_PROJECTS.en.md)

Oyun Motoru (`gamemaker`, eski adıyla Oyun Atölyesi / Game Workshop), Nexvyn OS'ta 2D ve 3D oyun yapmaya yarayan ayrı
bir uygulamadır; Başlat menüsünde ve Uygulamalar'da Studio'nun yanında, **Geliştirici** grubundadır. Çocuklar için
"Kolay", daha fazlasını isteyenler için "Gelişmiş" modu vardır; ikisi aynı projeyi açar. Oyunlar `nexvyn.game`
motorunun üstünde çalışan bir Lua çalışma zamanıyla oynatılır ve sıradan bir `.nxvapp` olarak paylaşılır. Uygulama
kimliği (`gamemaker`), proje biçimi ve `Oyunlarım` klasörü değişmedi; eski projeler olduğu gibi açılır.

## Kullanım

- **Ana ekran:** ilk kart **Oyun sihirbazı**, ardından "Yeni oyun yap" resim kartları (Platform, Orman Macerası,
  Labirent, Anahtar Bulmacası, Uzay, Elma Yarışı, Meteor Yağmuru, Hazine Avı, Yarış 3D, Koşucu 3D, Top Toplama 3D,
  Boş 2D, Boş 3D), "Oyunlarım" ve "Örnek oyunlar" (Kedi Macerası, Penguen Macerası, Yıldız Avcısı, Altın Ada, Robot
  Koşusu). Örnekler salt okunurdur; ilk değişiklikte `Oyunlarım` klasörüne kopyalanır. Oyunlarım kartlarındaki yeşil
  ▶ düğmesi oyunu tek dokunuşla açıp başlatır. Bir oyuna uzun basmak (ya da X / sağ tık) Aç, Adını değiştir,
  Kopyasını yap, Çöp kutusuna at menüsünü açar.
- **Oyun sihirbazı:** üç adım. 1) Tür: Platform, Macera (üstten), Uzay savaşı, Bulmaca, Yarış 3D, Koşucu 3D. 2) Dünya
  (tema): Orman, Kar, Çöl, Mağara, Uzay, Şeker diyarı, Okyanus; her kartta o dünyanın arka planı ve kahramanı görünür.
  3) Ad. "Oyunumu kur!" türün şablonunu kopyalar, temayı uygular (karakterler, düşmanlar, toplananlar, süsler, karolar,
  arka plan, müzik; 3D'de gökyüzü ve zemin rengi) ve hemen oynanabilen oyunu açar.
- **Rehberli tur:** ilk açılışta sekiz adımlık bir tur palete, sahneye, Geri al / Geçmiş'e, mod düğmesine, Paylaş'a ve
  Oyna'ya ışık tutar (Atla ile geçilebilir; Esc kapatır, Enter ilerletir). Yardım düğmesi ve Yardım menüsü turu
  yeniden başlatır. "Hareketi azalt" açıkken ışık kayarak değil hemen yer değiştirir ve yanıp sönmez.
- **Araç çubuğu:** simgelerin altında sözcükler (dar pencerede yalnız simgeler): Oyunlar, Geri al, Yinele, Geçmiş;
  ortada oyunun adı ve otomatik kaydın durumu (Kaydediliyor… / Kaydedildi); sağda Yardım, Kolay/Gelişmiş, Paylaş, Oyna.
- **Geçmiş:** son değişikliklerin listesi (ne yapıldığı ve saati). Bir adıma dokunup onaylayınca o andan beri yapılan
  her şey geri alınır; Yinele hepsini geri getirir.
- **Dostça uyarılar:** ilk bölümde oyuncu kontrolü olan kimse yoksa Oyna "Oyununun bir kahramana ihtiyacı var!" der
  ("Kahraman ekle" Karakterler'i açar, "Yine de oyna" başlatır). Açma, oynatma ve paketleme hataları çocukların
  anlayacağı bir cümleyle gösterilir; teknik ayrıntı sonda ayraç içinde kalır. Oyunda bir betik hata yaparsa oyun
  durmaz: kırmızı bir not hatanın satırını gösterir ve o betik kapanır.
- **Kolay mod:** solda büyük kategori düğmeleri (Karakterler, Düşmanlar, Toplananlar, Bloklar, Hedefler, Süsler,
  Benim çizimlerim, Arka plan / Gökyüzü, Müzik). Bir resmi sahneye sürükleyin ya da resme dokunup sahneye dokunun
  (kumandayla da çalışır). Bloklar fırça gibi boyanır, silgi de vardır. Bir nesneye dokununca sağda davranış
  karoları açılır: hareket (oyuncu kontrolü, sağa sola gezer, rastgele gezer, zıplar, takip eder, döner, ilerler),
  etki (toplanınca puan, toplanınca sayar, dokununca can gider, canı var, bitiş, bir şey söyler, bir süre sonra
  kaybolur), fizik (yerçekimi, katı, trambolin), çoğalma (çoğalt, ateş eder). Bir davranış açılınca ne yaptığı tek
  cümleyle gösterilir; "Bir şey söyler" açılınca söyleyeceği sözler sorulur. Büyük yeşil **▶ Oyna**
  oyunu hemen açar; oyundaki kırmızı ■ düğmesi düzenlemeye döner. Geri al / Yinele hep görünür; her ekranın büyük
  bir geri düğmesi vardır. İlk kullanımda zıplayan sarı ipuçları yol gösterir.
- **Gelişmiş mod:** sekmeler: Sahne (sayılarla denetçi, katmanlar, davranış parametreleri ve her davranışın açıklaması,
  nesne betiği), Olaylar (Scratch benzeri bloklar; paletteki her bloğun altında ne yaptığını anlatan bir satır),
  Çizimler (Studio'nun piksel editörü), Karolar (Studio'nun karo haritası editörü),
  Sesler (müzik, efektler, içe aktarılan sesler), Kod (bloklardan üretilen Lua; "Koda dönüştür" ile
  `scripts/game.lua` olur ve Kod Düzenleyici'de açılır), Ayarlar (ad, kazanma ve oyun bitti mesajı, can, süre, görünüm,
  yerçekimi, kamera; 3D'de gökyüzü ve sis).
- **Paylaş:** üç büyük düğme. "Uygulama olarak paylaş" `Belgeler/<Oyun>.nxvapp` yazar (`manifest.sha256` ile) ve
  paketi Uygulama Yükleyici'de açar (ayrıntılar, Çalıştır, Yükle). "Masaüstüne ekle" paketi kurar ve masaüstüne bir
  kısayol koyar. "Studio'da aç" oyunu (çalışma zamanı, kütüphane ve proje içinde) bir Lua uygulaması olarak kurar ve
  Studio'da açar; oradan kodla devam edilir, Oyun Motoru'ndaki proje olduğu gibi kalır.

## Dosyalar

| Yol | İçerik |
|---|---|
| `source/apps/app_gamemaker.cpp` | uygulama: ana ekran, 2D/3D sahne, palet, davranış karoları, denetçi, sekmeler, Oyna/Paylaş |
| `source/apps/workshop_doc.*` | kütüphane, davranış ve blok katalogları, proje dosyaları, paket üretimi, Lua üretimi, model içe aktarma |
| `source/apps/workshop_blocks.cpp`, `workshop_ui.h` | olay bloğu editörü ve ortak arayüz parçaları |
| `romfs/System/Lua/nexvyn/workshop.lua` | çalışma zamanı: proje yükleme, olaylar, API, 2D sahne, başlık / bitiş ekranı |
| `romfs/System/Lua/nexvyn/workshop3d.lua` | 3D sahne (g3d) |
| `romfs/System/Workshop/` | `library.json` (sihirbazın `genres` ve `themes` listeleri dahil), `art/`, `tiles.png`, `bg/`, `sounds/`, `Templates/`, `Samples/` |
| `tools/gen_workshop.py` | bütün kütüphaneyi, şablonları ve örnekleri üretir (Pillow) |
| `romfs/Applications/gamemaker.app/lang/{tr,en,de,fr,es}.json` | arayüz metinleri (`gamemaker.*`) |

Bütün resimler ve sesler `tools/gen_workshop.py` ile kodla üretilir; dışarıdan hazır varlık yoktur. Ses efektleri
48 kHz stereo WAV'dır (karıştırıcının biçimi; dönüştürme gerekmez). Müzikler dosya değil, `game.audio.song` ile
çalınan sentez melodileridir.

## Proje biçimi (`project.json`)

```json
{
  "format": "nexvyn-workshop", "version": 1,
  "title": "Kedi Macerası", "titleEn": "Cat Adventure", "id": "com.kullanici.kedimacerasi",
  "mode": "2d",
  "settings": {"view": "side", "lives": 3, "timeLimit": 0, "music": "adventure", "gravity": 900,
               "camera": "follow", "sky": "#9ED8FF", "fog": false},
  "vars": [{"name": "anahtar", "value": 0, "hud": true}],
  "events": [ {"on": {...}, "if": [...], "do": [...]} ],
  "levels": [ {...} ],
  "sprites": [{"name": "Çizimim", "file": "sprites/cizimim.png", "flip": "sprites/cizimim_flip.png", "w": 14, "h": 14}],
  "models": [{"name": "araba", "file": "models/araba.obj", "w": 1, "h": 0.4, "d": 0.6}],
  "sounds": [{"name": "kapi", "file": "sounds/kapi.wav"}],
  "layers": [{"name": "Arka"}, {"name": "Ana"}, {"name": "Ön"}],
  "script": "scripts/game.lua"
}
```

- `mode`: `"2d"` ya da `"3d"`. `settings.view` (2D): `"side"` (yandan, yerçekimi) ya da `"top"` (üstten).
  `settings.camera`: `"follow"` ya da `"fixed"`. `settings.winText` / `settings.loseText`: bitiş ekranında "Kazandın!" /
  "Oyun bitti" altında görünen sözler. Sihirbazla yapılan oyunlarda `genre` ve `theme` de yazılır (bilgi amaçlı).
- **2D bölüm:** `{"name", "background": "sky", "cols": 60, "rows": 17, "tiles": ["....1111", ...], "objects": [...]}`.
  `tiles` her satır için bir dizgedir: `.` boş, `1`…`9`, `a`…`z` = 1…35 numaralı karo (`library.json` "tiles":
  `solid`, `oneway`, `hazard`, `ice`). Bir karo 16 birimdir.
- **3D bölüm:** `{"name", "ground": {"size": 30, "color": "#7FCB6A"}, "objects": [...]}`. Birim metredir, y yukarı,
  zemin y = 0'dadır.
- **Nesne:** `{"id": 7, "kind": "cat", "x": 40, "y": 200, "z": 0, "flip": false, "sx": 1, "s": 1, "rot": 0,
  "ry": 0, "layer": 1, "name": "kapi", "beh": [{"t": "player", "style": "platform"}], "scriptFile":
  "scripts/object7.lua"}`. `kind` bir kütüphane kimliği, `spr:<ad>` (kendi çizimi) ya da `obj:<ad>` (içe aktarılan
  3D model). `beh` yoksa kütüphanedeki varsayılan davranışlar kullanılır. 2D'de x, y resmin merkezidir.
- **Davranışlar** (`t` ve isteğe bağlı parametreler): `player` (`style`: platform/top/ship, 3D'de
  walk/fps/car/runner; koşucu kendiliğinden ileri koşar, çubuk yalnız sağa sola kaydırır; `speed`, `jump`), `patrol`
  (`speed`, `dist`), `wander` (`speed`; rastgele yönlere gezer), `jumper` (`every`, `power`), `follow` (`speed`,
  `range`), `spin` (`speed`), `move` (`vx`, `vy`; 3D'de `vz`), `collect` (`points`, `life`, `sound`), `counter`
  (`var`; toplanınca değişkeni 1 artırır, tek başına da nesneyi toplanabilir yapar), `hurt` (`stomp`, `damage` = giden
  can), `health` (`hp`; o kadar vuruşta yenilir, üstünde can çubuğu), `goal`, `message` (`text`; oyuncu gelince
  söyler), `lifetime` (`sec`; sonra kaybolur, son saniyede yanıp söner), `gravity`, `solid`, `bouncy` (`power`; üstüne
  basan oyuncu zıplar), `spawn` (`what`, `every`, `max`), `shoot` (`every`, `aim`: false ise oyuncuya nişan almadan
  baktığı yöne ateş eden taret).
- **Olay kuralı:** `{"on": olay, "if": [koşullar], "do": [eylemler]}`.
  - Olaylar: `start`, `every {sec}`, `touch {a, b}`, `button {b}`, `score {n}`, `allgone {k}`, `var {name, n}`
    (değişken n'ye ulaşınca bir kez), `timeup`, `lifelost`. Seçiciler: `@player`, `@enemy`, `@item`, `@goal`, `@any`
    ya da bir `kind`.
  - Koşullar: `cmp {a, op, b}` (a = score/lives/time/level ya da değişken adı; op = `= != < > <= >=`),
    `count {k, op, n}`, `chance {p}`, `held {b}` (tuş basılı tutuluyor).
  - Eylemler: `score {n}`, `life {n}`, `hurt {n}` (oyuncudan n can alır), `setvar {name, n}`, `addvar {name, n}`,
    `sound {s}`, `music {m}`,
    `say {text}`, `spawn {k, at}` (at = self/other/player/random), `destroy {w}`, `jump {w}` (w = self/other),
    `shake`, `flash` (ekran parlaması), `confetti {at}` (konfeti patlaması), `teleport {w, at}` (nesneyi oraya
    ışınlar ve durdurur), `timer {n}`, `next`, `win`, `lose`, `restart`.
  - Betik API'sindeki karşılıkları: `ws.held(eylem)`, `ws.flash([renk])`, `ws.confetti(x, y[, z])`,
    `ws.teleport(nesne, x, y[, z])`, `ws.on("var", ad, n, fn)`, `ws.hurt([n])`.
- **Kütüphane:** kahramanlar (Köpek ve Civciv dahil), düşmanlar (Tırtıl, Balık, Kaplumbağa ve beş vuruşta yenilen Dev
  Jöle dahil), toplananlar (Kiraz, Muz, Kek, İksir ve Saat dahil), hedefler (Kupa dahil) ve süsler (Kaktüs, Fener,
  Zıplama Yayı, Kardan Adam, Palmiye dahil); Şeker ve Kale taşı karoları; Çöl ve Şeker diyarı arka planları; 3D'de
  Kardan Adam, Kaktüs, Fıçı, Mantar ve Zıplama Yayı; sentezlenmiş 22 ses efekti (Boing, Çan, Vuuş, Seviye atlama,
  Vızz, Şapırtı, Tık, Alarm dahil). Hepsi `tools/gen_workshop.py` ile çizilir ve her çalıştırmada aynı çıkar.
- **Sihirbaz verisi** (`library.json`): `genres` = `{"id", "template", "icon", "colors"}` (türün kopyalanan şablonu),
  `themes` = `{"id", "icon", "colors", "bg", "bgTop", "music", "sky", "ground", "kinds": {"cat": "penguin", ...},
  "tiles": {"grass": "snow", ...}}`. Tema uygulanırken (`ws::applyTheme`; ikizi `tools/lua_check.py` içindeki
  `apply_theme`) değişen nesne eski türünün davranışlarını korur; `what` parametrelerindeki ve olay bloklarındaki
  (`a`, `b`, `k`) türler de değişir; 2D'de arka plan görünüme göre (`bg` yandan, `bgTop` üstten) seçilir.

## Çalışma zamanı

Kod üretmek yerine proje JSON'u doğrudan yorumlanır (`nexvyn.workshop`):

- `ws.run{project = "bundle:/project.json", test = true|false}` `game.run` uygulama tablosunu döndürür.
  `test = true` (editördeki Oyna) başlık ekranını atlar ve kırmızı Durdur düğmesini gösterir.
- 2D: bölüm `game.tilemap` olur; nesneler `game.Sprite` alt sınıfıdır ve `game.world` içinde gruplara girer
  (`all`, `k:<kind>`, `player`, `enemy`, `item`, `goal`, `solid`, `body`). Davranışlar varlığa güncelleme
  fonksiyonları ve gruplar ekler; çarpışmalar `world:collide` ile kurulur (olay kuralları önce, böylece
  toplanan bir nesne "değince" olayını da tetikler).
- 3D: `nexvyn.workshop3d` nesneleri `library.json` "models" parçalarından (g3d ilkel şekilleri) ya da OBJ'den
  çizer; yerçekimi, katı nesnelere karşı eksen hizalı kutu çarpışması, taşıyan hareketli platformlar, gölge
  diski, üçüncü kişi / birinci kişi / araba kontrolü, sis ve gökyüzü rengi vardır.
- Olay blokları `ws.on(...)` çağrılarına derlenir. Aynı API betiklere de açıktır; Kod sekmesi blokların Lua
  karşılığını gösterir. Nesne betikleri `start()`, `update(dt)`, `touch(other)` tanımlayabilir ve `self`, `ws`,
  `game` görür. API: `ws.on`, `ws.score/addScore`, `ws.lives/addLife`, `ws.var/setVar/addVar`, `ws.time/addTime`,
  `ws.level`, `ws.say`, `ws.sound`, `ws.music`, `ws.spawn`, `ws.at`, `ws.destroy`, `ws.jump`, `ws.count`,
  `ws.player`, `ws.find`, `ws.shake`, `ws.chance`, `ws.win`, `ws.lose`, `ws.nextLevel`, `ws.restart`.
- Dışa aktarılan paket şunları içerir: `app.json`, `main.lua` (3 satır), `project.json`, `icon.png`, projenin
  `sprites/ sounds/ models/ scripts/` klasörleri, çalışma zamanının bir kopyası (`nexvyn/workshop*.lua`) ve kütüphane
  (`lib/`). Paketteki kopya sistemdekinden önce yüklenir, böylece oyun her Nexvyn OS'ta aynı çalışır.
- 3D Modelleme'den `.nxv3d` (ya da `.obj`) içe aktarılınca köşe renkli, tabanı y = 0'da, en uzun kenarı 1 olan bir
  OBJ'ye dönüştürülür.

## Denetim

`python tools/lua_check.py --workshop` her şablonu ve örneği hem başlık ekranından hem oyna-test modunda sahte
SDK'ya karşı çalıştırır; ardından sihirbazın her türünü her temayla (6 × 7) oyna-test modunda oynatır.

---

## English summary

Game Engine (`gamemaker`, formerly Game Workshop) is a standalone game maker for 2D and 3D games, listed in the
**Developer** group next to Studio. The **Game wizard** builds a playable game in three steps: a genre (platformer,
top-down adventure, space shooter, puzzle, racing 3D, 3D runner), a theme (forest, snow, desert, cave, space, candy
land, ocean) that swaps the pictures, tiles, background, music and 3D colours of the genre's template, and a name. A
first-run guided tour (skippable, again from Help, Reduce motion respected), hints under every event block and on
every behaviour, a History panel that undoes everything since a chosen step, an autosave indicator, a check for a
missing hero before Play and kid-friendly error messages make it easier. Share offers "Share as app" (Documents
`.nxvapp` opened in the App Installer), "Add to Desktop" and "Open in Studio" (installed as a Lua app and opened in
Studio to go on in code). New behaviours: wander, counter (collect & count into a variable), health, message,
lifetime, trampoline; hurt has a damage, shoot a turret mode, the 3D player a runner style; new blocks: the "var"
event and the "take lives" action; end-screen win / lose texts; script mistakes show a red note instead of stopping
the game. **Easy** mode is touch-first: picture
template cards, a big-button library palette (drag or tap-to-place), tile painting, picture tiles that toggle
behaviours, a big green Play button, always-visible undo, animated first-use hints and a back button on every
screen. **Advanced** mode adds a numeric inspector, layers, behaviour parameters, Scratch-like event blocks
(events → conditions → actions, variables, timers), Studio's pixel sprite and tilemap editors, sounds, generated
Lua ("turn into code") and per-object Lua scripts.

Projects live in `~/Documents/Oyunlarım/<name>/project.json` (format above). Games are not code-generated: the
`nexvyn.workshop` Lua runtime (on `nexvyn.game`; `nexvyn.workshop3d` for 3D on `g3d`) interprets the project JSON, and
event blocks compile to the same `ws.on(...)` API scripts use (newer blocks: `held` condition, `flash`, `confetti`
and `teleport` actions; templates Apple Race, Meteor Shower and Treasure Hunt). Play builds a portable bundle in
`Library/Caches/gamemaker/play` and launches it; Export writes a standalone `.nxvapp` (runtime and library copied in,
`manifest.sha256` included) to Documents; Add to Desktop installs it and drops a shortcut. All art and sounds are
generated by `tools/gen_workshop.py`. Five samples ship read-only (copied on first edit): *Kedi Macerası* (2D
platformer with a key/door event puzzle), *Penguen Macerası* (snowy platformer with trampolines, a crystal counter,
clocks and a giant slime that takes five stomps), *Yıldız Avcısı* (2D space shooter), *Altın Ada* (3D coin collector)
and *Robot Koşusu* (3D runner with turrets).
