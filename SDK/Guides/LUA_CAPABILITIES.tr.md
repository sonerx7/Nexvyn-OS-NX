# Nexvyn OS'ta Lua ile neler yapılabilir?

**Türkçe** · [English](LUA_CAPABILITIES.en.md)

Bu belge, Nexvyn OS'un Lua uygulama ortamıyla (`.nxvapp`) hangi tür program ve oyunların gerçekçi olarak yapılabileceğini, sınırların nerede başladığını ve bu sınırların nasıl genişletilebileceğini anlatır. API'nin tamamı için: [`sdk/SDK.tr.md`](../Reference/SDK.tr.md).

## Kısa cevap

| Ne yapmak istiyorsunuz? | Olur mu? | Not |
|---|---|---|
| Masaüstü programları: not, bütçe, kanban, günlük, hesap makinesi, sözlük, RSS okuyucu, hava durumu | **Evet, rahatça** | Arayüz bileşenleri, dosya, JSON, internet (HTTPS) hazır |
| 2D oyunlar: kart, bulmaca, platform, shoot'em up, tower defense, top-down yarış | **Evet, rahatça** | 60 FPS, dokunmatik + kumanda + klavye |
| Basit 3D oyunlar: low-poly araba yarışı, uçuş, labirent, Rubik küpü, 3D bulmaca | **Evet** | Dokusuz, renkli üçgenler; sahne başına birkaç bin üçgen |
| GTA 1 / GTA 2 tarzı (yukarıdan bakışlı açık şehir) | **Evet** | 2D çizimle tamamen yapılabilir |
| GTA 3 / GTA V tarzı (3D açık dünya, dokulu şehir, fizik) | **Hayır** | Doku, derinlik tamponu ve GPU gölgelendirici gerekir (aşağıya bakın) |
| Tam kapsamlı programlar (ofis, IDE, medya oynatıcı) | **Kısmen** | Arayüz ve mantık Lua'da olur; ağır işler (video çözme, büyük belge düzeni) yerleşik C++ uygulamalarda |

**Kanıt:** sistemde gelen **Yarışçı** (`romfs/Applications/racer.nxvapp`) tamamen Lua ile yazılmış bir 3D yarış oyunudur: tepeli pist, bordürler, ağaçlar, 3 yapay zekâ rakip, tur süresi, mini harita, dokunmatik pedallar ve jiroskopla direksiyon. Yaklaşık 1.200 satır Lua.

## Lua ortamı ne sağlıyor?

- **Çizim (`gfx`)**: dikdörtgen, yuvarlatılmış kutu, daire, çizgi, çokgen, degrade, resim (PNG/JPG), yazı (Türkçe karakterler dahil), Material ikonları, kırpma.
- **Arayüz (`ui`)**: düğme, metin alanı (ekran klavyesi otomatik açılır), kaydırıcı, anahtar, liste, kaydırma alanı, menüler. Sistem görünümünde, açık/koyu tema uyumlu.
- **Girdi**: dokunmatik, kumanda (tuşlar, analog çubuklar, jiroskop/ivmeölçer `input.motion()`), USB klavye/fare. D-pad ile düğmeler arası gezinme sistem tarafından otomatik yapılır.
- **3D (`g3d`)**: küp, küre, silindir, koni, torus, düzlem; `.obj` / `.stl` model yükleme; kendi üçgenleriniz; ışık, sis, tel kafes, kamera, 3D→2D izdüşüm.
- **Dosya ve veri**: uygulamaya özel klasör, `store` (otomatik kaydedilen ayarlar), JSON, kullanıcı klasörleri (Belgeler, Resimler…).
- **İnternet (`net`)**: HTTPS GET/POST, JSON, dosya indirme (ilerleme göstergeli).
- **Ses**: sentezlenmiş tonlar (sinüs, kare, testere, üçgen, gürültü), WAV/OGG/MP3 efekt, müzik akışı, titreşim (HD Rumble).
- **Sistem**: bildirim, pano, saat/tarih, pil, dil, başka uygulama açma, zamanlayıcılar, `coroutine`.
- **Çoklu dil**: `lang/tr.json`, `lang/en.json` + `TR("anahtar")`.

## Sınırlar (neden GTA 3 olmaz?)

1. **Lua yorumlanan bir dildir.** Oyun mantığı tek çekirdekte çalışır. Switch'in işlemcisi (4× Cortex-A57, ~1 GHz) için bu, kare başına binlerce nesneyi güncellemek demek; on binlercesini değil.
2. **Her çağrı en fazla 3 saniye sürebilir.** Uzun işler (yapay zekâ araması, bulmaca üretme) karelere bölünmeli ya da `coroutine` ile parça parça yapılmalı. Satranç motoru böyle çalışır.
3. **`g3d` dokusuz ve derinlik tamponsuzdur.** Üçgenler renkli ve ışıklıdır, ama üzerine resim (doku) giydirilemez. Görünürlük, üçgenleri uzaktan yakına sıralayarak çözülür (ressam algoritması); iç içe geçen büyük yüzeylerde hatalar görülebilir. Dönüşüm ve ışık hesabı işlemcide, çizim GPU'da yapılır.
4. **Üçgen bütçesi**: SDK'ya göre kare başına birkaç bin üçgen 60 FPS'te çizilir. Gerçek donanımdaki rakamı sistemdeki **Benchmark** uygulamasıyla ölçün; emülatördeki sonuç farklı olabilir.
5. **Yerel (C/C++) kütüphane yüklenemez**, iş parçacığı açılamaz, ağ soketlerine doğrudan erişilemez (yalnızca HTTP/HTTPS). Bu güvenlik için bilinçli bir tercih: dışarıdan indirilen bir `.nxvapp` sistemi bozamaz.

GTA 3 tarzı bir oyun; dokulu binalar, yüz binlerce üçgen, derinlik tamponu, gölgeler, araç ve karakter fiziği, dünyanın parça parça yüklenmesi ister. Bunların hiçbiri şu anki Lua 3D katmanında yok.

## Örnek 1: basit 3D araba (kamera arabayı takip eder)

```lua
local app = {}
local car, wheel, ground
local x, z, yaw, speed = 0, 0, 0, 0

function app.load()
  car = g3d.mesh("box", 1.6, 0.5, 3.2); car:setColor("#E53935")
  wheel = g3d.mesh("cylinder", 0.35, 0.3, 12); wheel:setColor("#222222")
  ground = g3d.mesh("plane", 400, 400, 20); ground:setColor("#3C8D40")
end

function app.update(dt)
  local lx = input.stick("left")                -- sol çubuk: direksiyon
  local gas = input.down("zr") and 1 or 0       -- ZR: gaz, ZL: fren
  local brake = input.down("zl") and 1 or 0
  speed = speed + (gas * 18 - brake * 30 - speed * 0.6) * dt
  speed = math.max(-5, math.min(speed, 40))
  yaw = yaw - lx * dt * 1.8 * math.min(1, math.abs(speed) / 8)
  x = x - math.sin(yaw) * speed * dt
  z = z - math.cos(yaw) * speed * dt
end

function app.draw(w, h)
  gfx.clear("#8EC5FF")
  g3d.begin(0, 0, w, h, 60)
  -- kamera: arabanın 8 m arkasında, 3 m yukarıda
  g3d.camera(x + math.sin(yaw) * 8, 3, z + math.cos(yaw) * 8, x, 0.5, z)
  g3d.light(0.4, 1, 0.2, 0.4)
  g3d.fog("#8EC5FF", 60, 180)
  g3d.draw(ground, 0, 0, 0)
  g3d.draw(car, x, 0.6, z, 0, yaw, 0)
  for _, o in ipairs({{-0.8, 1.1}, {0.8, 1.1}, {-0.8, -1.1}, {0.8, -1.1}}) do
    local wx = x + math.cos(yaw) * o[1] + math.sin(yaw) * o[2]
    local wz = z - math.sin(yaw) * o[1] + math.cos(yaw) * o[2]
    g3d.draw(wheel, wx, 0.35, wz, 0, yaw, math.pi / 2)
  end
  g3d.finish()
  gfx.color("#FFFFFF")
  gfx.text(string.format("%d km/sa", math.floor(math.abs(speed) * 3.6)), 20, 20, 24, "bold")
end

return app
```

Buradan sonrası: pist (bir eğri boyunca sıralanmış düzlem şeritleri), çarpışma (yolun merkez çizgisine uzaklık), rakipler (aynı eğriyi takip eden arabalar), tur sayacı. Yarışçı uygulaması tam olarak bunları yapıyor.

## Örnek 2: GTA 1 / GTA 2 tarzı şehir (yukarıdan bakış)

İlk iki GTA oyunu yukarıdan bakışlıydı; bu tarz Nexvyn OS'ta 2D çizimle rahatça yapılabilir:

- **Harita**: ızgara (ör. 200×200 kare), her karede yol / bina / çimen / su. Yalnızca ekrandaki kareler çizilir, harita ne kadar büyük olursa olsun hız değişmez.
- **Araba fiziği**: hız, yön, sürtünme, drift için yan kayma azaltma (yukarıdaki 3D örneğin 2D hali).
- **Yayalar ve trafik**: yollarda giden basit "ajanlar"; ekran dışındakiler seyrek güncellenir.
- **Görevler**: telefonun çaldığı noktalar, bir yerden bir yere araba götürme, süre sınırı; `store` ile kayıt.
- **Polis seviyesi**, radyo (sentez sesleri ya da `audio.music`), mini harita (`gfx` ile küçültülmüş çizim).

Binaları "sahte 3D" göstermek için, her binanın çatısını kameradan uzaklığa göre biraz kaydırarak çizmek (GTA 2'deki gibi) iyi sonuç verir. İsterseniz bina blokları `g3d` kutularıyla da çizilebilir: birkaç yüz kutu sorunsuz.

## Örnek 3: tam kapsamlı bir program

Sistemdeki **Kanban**, **Bütçe**, **Günlük**, **Hızlı Kartlar** uygulamaları Lua ile yazıldı. Tipik bir programın parçaları:

```lua
local app = {}
local items, kurlar = {}, nil

function app.load()
  items = store.get("items", {})                -- kalıcı veri
  net.json("https://api.example.com/kurlar", function(data, err)
    if data then kurlar = data end              -- internetten veri
  end)
end

function app.draw(w, h)
  ui.label(TR("baslik"), 20, 16, 20)
  local y = 60
  for i, it in ipairs(items) do
    if ui.button(it.ad .. "##" .. i, 20, y, w - 40, 36) then sys.open(it.dosya) end
    y = y + 44
  end
end

function app.menu()                              -- menü çubuğu
  return { { title = TR("dosya"), items = { {label = TR("disa_aktar"), id = 1, shortcut = "Ctrl+E"} } } }
end
function app.onmenu(id)
  if id == 1 then
    fs.write(fs.dir("documents") .. "/liste.json", json.encode(items, true))
    sys.notify(TR("bitti"), TR("kaydedildi"))
  end
end

return app
```

Lua ile rahat yapılanlar: formlar, listeler, grafikler (`gfx` ile çizilen çubuk/pasta), internetten veri çeken araçlar, oyunlaştırılmış uygulamalar, eğitim programları (periyodik tablo, grafik çizici gibi). Ağır işler (video çözme, büyük metin düzeni, web sayfası işleme) sistemdeki yerleşik C++ uygulamalarda (Video Oynatıcı, Tarayıcı, Kelime İşlemci) yapılıyor.

## Nasıl yazılır?

- **Konsolda**: **Nexvyn OS Studio** uygulaması (Geliştirici kategorisi). Şablonlar (Boş, Araç, 2D Oyun, 3B Sahne, Ağ ve JSON), anlık hata denetimi, otomatik tamamlama, Çalıştır + konsol, paketleme.
- **Bilgisayarda**: bir klasör oluşturun (`benim-oyunum.nxvapp/` içinde `app.json`, `main.lua`, `icon.png`, `lang/`), SD karta `sdmc:/NexvynOS/Applications/` içine kopyalayın; uygulama Başlatıcı'da görünür. Yapay zekâ ile yazdırmak için ona `sdk/SDK.tr.md` dosyasını vermeniz yeterli.

## Sınırları büyütmek mümkün mü?

Evet, ama sistem tarafında (C++) çalışma gerektirir:

| Geliştirme | Ne kazandırır |
|---|---|
| `g3d` için GPU tabanlı çizim + derinlik tamponu | İç içe geçme hataları biter, 10× daha fazla üçgen |
| Dokulu modeller (`.obj` + `.png`) | Gerçekçi araba/bina görünümü, PS1–PS2 dönemi görünüm |
| Yerleşik fizik (çarpışma kutuları, araç fiziği) | Lua'da yazmaya gerek kalmadan sağlam çarpışma |
| Sahne parçalama (görünmeyen bölgeleri çizmeme) | Daha büyük 3D dünyalar |

Bunlar eklense bile hedef "GTA 3" değil, en fazla **PS1/erken PS2 düzeyinde** (ör. Crazy Taxi'nin sade bir hali, Driver 1 benzeri) bir 3D şehir oyunu olur. Daha ötesi için oyunun doğrudan C++ ile, Switch'in GPU'sunu kullanan bir motorla (ör. deko3d/OpenGL) yazılması gerekir; o da artık Nexvyn OS uygulaması değil, ayrı bir homebrew oyunu olur.
