# Görev: mağaza ikonu (key art)

[English](store-icon.en.md) · **Türkçe**

SDK ile yapılan oyun ve app'lerin App Market ikonu **öğenin kendisini gösterir**: kahramanını, ana nesnesini ya da
dünyasını; 64 px'de okunur. Gradyan üstünde düz, geçici bir sembol kabul edilmez. **Stil yapımcının seçimidir.**
Asistan stili sorar ya da yapımcının söylediğine uyar; hiçbir şey söylenmediyse **clean** bir ikon yapar: oyunun kendi
konusunun özenli, çekici bir resmi, yumuşak ışık, ölçülü parlama, sakin renk ayarı, yazı yok, çerçeveden taşma yok.
Kurallar: 256 x 256 PNG (`source/icon.png`), 1024 x 1024 yapılıp küçültülür, kenardan kenara dolu, konu ortadaki
%80'in içinde. Ayrıntılar: `SDK/Guides/MAKE_A_GAME.tr.md`, *Mağaza ikonu ve key art*.

## 1. İkon aracıyla yapın (önerilen)

`SDK/Tools/icon`, oyununuzun zaten yüklediği modelden ikonu iki komutla çizer
([README](../../Tools/icon/README.tr.md)):

```sh
blender -b --factory-startup -P SDK/Tools/icon/hero_render.py -- --model models/hero.glb --clip Idle --frame 10 --look ember
python SDK/Tools/icon/finish_icon.py hero.png --look ember --out art/
```

Bu varsayılan **clean** stildir. `--style bold` ya da `--style loud` (iki betikte de) kontrast, ışık huzmeleri,
kıvılcım ve bloom ekler; `--title "AD"` bir başlık logosu ekler. Bunları yalnızca yapımcı isterse kullanın. Çıktılar:
`icon.png` (256), `icon_512.png`, `keyart_1024.png` ve `preview.png` (256 / 128 / 64 px'te ve gri tonda ikon). Biri
Kor Tarlası'nın `pip.glb`'sinden yapılmış örnekler: `SDK/Tools/icon/examples/`. Komutları asistandan isteyin (prompt
İngilizce; asistan size sizin dilinizde yanıt verir):

```text
Here is my Nexvyn OS game "<NAME>": <one paragraph>. Palette <colours>, mood <words>. Hero model: <file>, clips
<names>, model:info() size <w x h x d>. Icon style I want: <clean (default) / bold / loud / my own words>; title text:
<none / the name>. Using SDK/Tools/icon (hero_render.py options: --model --hero --clip --frame --yaw --camera
low|eye|high --look --style --exposure; finish_icon.py options: --style --title --look --fill --x --y --frame --rays
--sparks --tilt --seed --mask), give me the two commands for a readable icon in that style: the clip and frame with a
good pose, the yaw and camera, the look closest to my palette (and the colour changes to its LOOKS entries so it
matches exactly), the fill and position. Then tell me what to check in preview.png.
```

## 2. Görsel üretici için prompt

Çıktısını yayınlamanıza izin veren bir üretici kullanın ve ikon oyuna uysun diye kahramanınızın bir render'ını ya da
ekran görüntüsünü referans görsel olarak ekleyin. Çoğu üretici İngilizceyi en iyi anlar, prompt bu yüzden
İngilizcedir. Varsayılan (clean):

```text
Square app icon, 1:1, for a game called "<NAME>". Subject: <your hero or main object, from the reference image>,
<a calm, characteristic pose>, centred, three-quarter view, filling most of the frame. Soft key light, a subtle rim
light, a simple softly lit background in <your 2-3 palette colours>, gentle depth. Style: <your art direction, e.g.
stylised low-poly 3D render, painterly, flat-shaded>, clean, polished, appealing, readable at 64 px. No text, no
interface, no border, no watermark.
```

Yapımcı daha gösterişli bir ikon isterse şunu ekleyin: `dramatic lighting, strong coloured rim light, saturated
colours, a burst of light behind the subject, floating particles, glow`; başlık için `the name "<NAME>" as a bold logo
at the bottom` (üreticiler adı sık yanlış yazar: başlığı `finish_icon.py --title` ile eklemek daha güvenlidir).

## 3. Herhangi bir asistandan plan isteyin

```text
Nexvyn OS oyunum "<AD>" için App Market ikonuna ihtiyacım var. Gradyan üstünde sembol değil, oyunun kendisini
(kahraman, ana nesne ya da dünya) göstermeli: 256 x 256 PNG (1024 x 1024 yapılır), kenardan kenara dolu, konu
ortadaki %80'in içinde, 64 px'de okunur. Stil: <clean, sakin ve özenli (varsayılan) / bold / loud / kendi tarifim>.

Oyun: <tek paragraf>. Sanat yönü: palet <renkler>, atmosfer <kelimeler>, kamera <stil>.
Kahraman: <anlatın ya da "ekteki render'a / ekran görüntüsüne bak" deyin>. Elimdeki modeller: <dosyalar>.
Araçlarım: <Blender ve SDK/Tools/icon / bir görsel üretici / bir görsel düzenleyici / yalnızca oyun>.

Bana şunları ver:
1. Benim stilimde üç kompozisyon fikri (poz, kamera açısı, ışık, arka plan), her biri iki cümle, ve hangisinin
   64 px'de en iyi okunduğu.
2. En iyisi için araçlarımla tam adımlar (SDK/Tools/icon komutları ya da ekran görüntüsünü alabileceğim, yalnızca
   Nexvyn OS SDK'sıyla yazılmış oyun içi bir key art kipi).
3. Yukarıdaki görsel üretici prompt'u, oyunum ve stilim için doldurulmuş.
4. Sonuç için kısa bir kontrol listesi.
```

## Göndermeden önce kontrol edin

- Açıkça bu oyun (ekran görüntüleriyle aynı kahraman, aynı renkler).
- Yapımcının seçtiği stilde (bir şey söylenmediyse clean).
- 64 px'de okunuyor: tek konu, yeterli ton farkı (`preview.png` içindeki gri sürüme bakın).
- Gradyan üstünde düz, geçici bir sembol değil.
- Sizin ya da yayınlama izniniz var; aracı ya da sanatçıyı README'de belirtin.
