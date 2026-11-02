# Görev: mağaza ikonu (key art)

[English](store-icon.en.md) · **Türkçe**

SDK ile yapılan oyun ve app'lerin App Market ikonu **öğenin kendi key art'ı** olmalı: kahramanı ya da ana nesnesi,
dünyası, ışığı, adı; cesur, 64 px'de okunur ve mağazadaki diğer ikonlara benzemez. Gradyan üstünde düz bir sembol
kabul edilmez. Kurallar: 256 x 256 PNG (`source/icon.png`), 1024 x 1024 yapılıp küçültülür, kenardan kenara dolu,
konu ve logo ortadaki %80'in içinde. Ayrıntılar: `SDK/Guides/MAKE_A_GAME.tr.md`, *Mağaza ikonu ve key art*.

## 1. Asistandan bir plan isteyin (herhangi bir asistan)

```text
Nexvyn OS oyunum "<AD>" için App Market ikonuna ihtiyacım var. Gradyan üstünde sembol değil, oyunun kendi key art'ı
olmalı: 256 x 256 PNG (1024 x 1024 yapacağım), kenardan kenara dolu, kahraman ve logo ortadaki %80'in içinde, 64 px'de
okunur.

Oyun: <tek paragraf>. Sanat yönü: palet <renkler>, atmosfer <kelimeler>, tipografi <stil>, kamera <stil>.
Kahraman: <anlatın ya da "ekteki render'a / ekran görüntüsüne bak" deyin>. Elimdeki modeller: <dosyalar>.
Araçlarım: <bir 3B araç / bir görsel üretici / bir görsel düzenleyici / yalnızca oyun>.

Bana şunları ver:
1. Üç farklı kompozisyon fikri (kahraman pozu, kamera açısı, ışık, arka plan, adın yeri), her biri iki cümle, ve
   hangisinin 64 px'de en iyi okunduğu.
2. En iyisi için araçlarımla tam adımlar: ya modellerimden bir render (poz karesi, kamera, ana ışık, kenar ışığı,
   arka plan, logo) ya da ekran görüntüsünü alabileceğim oyun içi bir key art kipi (yalnızca Nexvyn OS SDK'sını
   kullanan kod).
3. Oyunum için doldurulmuş, bir görsel üretici prompt'u (aşağıda).
4. Sonucu mağazadaki diğer ikonlarla karşılaştırmak için bir kontrol listesi.
```

## 2. Görsel üretici için prompt

Çıktısını yayınlamanıza izin veren bir üretici kullanın ve ikon oyuna uysun diye kahramanınızın bir render'ını ya da
ekran görüntüsünü referans görsel olarak ekleyin. Çoğu üretici İngilizceyi en iyi anlar, prompt bu yüzden
İngilizcedir:

```text
Square video game key art, 1:1, for a game called "<NAME>". Subject: <your hero, from the reference image>,
<pose / action>, large in the frame, three-quarter view, seen from slightly below. Setting: <your world in a few
words>. Lighting: <key light colour> key light, strong <contrasting colour> rim light, <time of day>. Palette:
<your 3-4 palette colours>. Style: <your art direction words, e.g. low-poly faceted, painterly, pixel art>.
Bold silhouette, high contrast, readable at small size, subject and logo inside the central 80 %. Title "<NAME>"
in a <your typography> logo at the bottom. No other text, no frame, no watermark.
```

## 3. Oyunun modellerinden kendiniz render alın

`SDK/Samples/lua/ember-field` örneği ikonunu `art/make_keyart.py` ile render eder (Blender, arayüzsüz):
`blender -b --factory-startup -P make_keyart.py -- models/pip.glb keyart.png 1024`. Kopyalayın ve pozu, ışıkları,
renkleri ve adı kendi oyununuza göre değiştirin.

## Göndermeden önce kontrol edin

- Açıkça bu oyun (ekran görüntüleriyle aynı kahraman, aynı renkler).
- 64 px'de okunuyor: tek konu, güçlü kontrast, en fazla bir iki kelime.
- Mağaza kategorisindeki diğer ikonlardan farklı.
- Sizin ya da yayınlama izniniz var; aracı ya da sanatçıyı README'de belirtin.
