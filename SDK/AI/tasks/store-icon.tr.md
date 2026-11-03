# Görev: mağaza ikonu (key art)

[English](store-icon.en.md) · **Türkçe**

SDK ile yapılan oyun ve app'lerin App Market ikonu **öğenin kendi key art'ı** olmalı ve en çok satan bir oyunun ikonu
gibi yapılmalı: dramatik ışıkta, güçlü rim ışıklı, abartılı, gösterişli, albenili bir kahraman (ya da ana nesne),
doygun palet, derinlik, parlama ve parçacıklar, çerçeveden taşabilen sıkı bir kadraj, kalın bir logo olarak ad;
64 px'de okunur ve mağazadaki diğer ikonlara benzemez. Gradyan üstünde düz bir sembol kabul edilmez. Kurallar:
256 x 256 PNG (`source/icon.png`), 1024 x 1024 yapılıp küçültülür, kenardan kenara dolu, konu ve logo ortadaki %80'in
içinde. Ayrıntılar: `SDK/Guides/MAKE_A_GAME.tr.md`, *Mağaza ikonu ve key art*.

## 1. İkon aracıyla yapın (önerilen)

`SDK/Tools/icon`, oyununuzun zaten yüklediği modelden ikonu iki komutla çizer
([README](../../Tools/icon/README.tr.md)):

```sh
blender -b --factory-startup -P SDK/Tools/icon/hero_render.py -- --model models/hero.glb --clip Run --frame 6 --look ember
python SDK/Tools/icon/finish_icon.py hero.png --title "SKY HOP" --look ember --fill 1.0 --out art/
```

`hero_render.py` kahramana poz verir ve saydam arka planda aydınlatır (ana ışık, iki renkli rim ışığı, dolgu);
`finish_icon.py` ışık huzmeli arka planı, kahramanın arkasındaki parlamayı, kenar rim'ini, kıvılcımları, bloom'u,
vinyeti ve dış hatlı, gradyan dolgulu logo olarak başlığı ekler; `icon.png` (256), `icon_512.png`, `keyart_1024.png`
ve `preview.png` (256 / 128 / 64 px'te ve gri tonda ikon) yazar. Biri Kor Tarlası'nın `pip.glb`'sinden yapılmış
örnekler: `SDK/Tools/icon/examples/`. Oyununuza uygun seçenekli komutları asistandan isteyin (prompt İngilizce;
asistan size sizin dilinizde yanıt verir):

```text
Here is my Nexvyn OS game "<NAME>": <one paragraph>. Palette <colours>, mood <words>. Hero model: <file>, clips
<names>, model:info() size <w x h x d>. Using SDK/Tools/icon (hero_render.py options: --model --hero --clip --frame
--yaw --camera low|eye|high --look --exposure; finish_icon.py options: --title --look --fill --x --y --frame --rays
--sparks --tilt --seed --mask), give me the two commands for the most dramatic, readable icon: the clip and frame
with the strongest pose, the yaw and camera, the look closest to my palette (and the colour changes to its LOOKS
entries so it matches exactly), the fill and position (crop tight, let a part break the frame), a one- or two-word
title. Then tell me what to check in preview.png.
```

## 2. Görsel üretici için prompt

Çıktısını yayınlamanıza izin veren bir üretici kullanın ve ikon oyuna uysun diye kahramanınızın bir render'ını ya da
ekran görüntüsünü referans görsel olarak ekleyin. Çoğu üretici İngilizceyi en iyi anlar, prompt bu yüzden
İngilizcedir:

```text
Square game store icon, 1:1, key art for a game called "<NAME>". Hero: <your hero, from the reference image>,
<dynamic pose / action>, huge in the frame, tight crop, three-quarter view from slightly below, part of it breaking
out of the frame. Lighting: dramatic <key colour> key light, very strong <contrasting colour> rim light outlining the
silhouette, glowing <accent colour> highlights. Background: <your world in a few words>, a radial burst of light
behind the hero, depth (blurred elements in front and behind), floating <sparks / embers / magic particles>, bloom
and glow. Palette: <3-4 saturated colours of your game>, deep shadows, high contrast. Style: <your art direction,
e.g. stylised low-poly 3D render, painterly, cel-shaded>, polished, premium, exaggerated, eye-catching.
Logo "<NAME>" in bold chunky letters with a thick dark outline, a gradient fill and a glow, at the bottom, slightly
tilted. Readable at 64 px. No other text, no interface, no border, no watermark.
```

Üreticiler logo harflerini sık bozar: gerekirse logo satırı olmadan üretin ve başlığı `finish_icon.py` ile (üretilen
resmi kahraman olarak yalnızca saydam arka planı varsa verin) ya da bir görsel düzenleyiciyle ekleyin.

## 3. Herhangi bir asistandan plan isteyin

```text
Nexvyn OS oyunum "<AD>" için App Market ikonuna ihtiyacım var. Gradyan üstünde sembol değil, en çok satan bir oyunun
ikonu gibi olmalı: dramatik ışıkta, güçlü rim ışıklı abartılı bir kahraman, doygun renkler, derinlik, parlama ve
parçacıklar, sıkı kadraj, kalın bir logo. 256 x 256 PNG (1024 x 1024 yapılır), kenardan kenara dolu, kahraman ve logo
ortadaki %80'in içinde, 64 px'de okunur.

Oyun: <tek paragraf>. Sanat yönü: palet <renkler>, atmosfer <kelimeler>, tipografi <stil>, kamera <stil>.
Kahraman: <anlatın ya da "ekteki render'a / ekran görüntüsüne bak" deyin>. Elimdeki modeller: <dosyalar>.
Araçlarım: <Blender ve SDK/Tools/icon / bir görsel üretici / bir görsel düzenleyici / yalnızca oyun>.

Bana şunları ver:
1. Üç farklı, cesur kompozisyon fikri (kahraman pozu, kamera açısı, ışık renkleri, arka plan, parçacıklar, adın
   yeri), her biri iki cümle, ve hangisinin 64 px'de en iyi okunduğu.
2. En iyisi için araçlarımla tam adımlar (SDK/Tools/icon komutları ya da ekran görüntüsünü alabileceğim, yalnızca
   Nexvyn OS SDK'sıyla yazılmış oyun içi bir key art kipi).
3. Yukarıdaki görsel üretici prompt'u, oyunum için doldurulmuş.
4. Sonucu mağazadaki diğer ikonlarla karşılaştırmak için bir kontrol listesi.
```

## Göndermeden önce kontrol edin

- Açıkça bu oyun (ekran görüntüleriyle aynı kahraman, aynı renkler).
- Yeterince abartılı: kahraman iri ve dramatik aydınlatılmış, rim ışığı, parlama ve derinlik var, renkler doygun;
  diğer mağaza ikonlarının yanında düz ya da sönük durmuyor.
- 64 px'de okunuyor: tek konu, güçlü ton farkı (`preview.png` içindeki gri sürüme bakın), en fazla bir iki kelime.
- Mağaza kategorisindeki diğer ikonlardan farklı.
- Sizin ya da yayınlama izniniz var; aracı ya da sanatçıyı README'de belirtin.
