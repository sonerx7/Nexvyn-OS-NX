# Piksel Sanatı / Pixel Art

8×8, 16×16 ve 32×32 piksel çizimler yapıp gerçek PNG dosyası olarak dışa aktaran çizim uygulaması.
A drawing app for 8×8, 16×16 and 32×32 pixel art that exports real PNG files.

## Yenilikler 1.1 / What's new in 1.1

**Türkçe:** 64×64'e kadar sprite, PNG dışa aktarma.

- 8×8, 16×16, 32×32 ve 64×64 tuval
- Kalem, silgi, doldurma, çizgi, dikdörtgen, renk değiştirme ve damlalık
- 16 renkli retro palet ve kendi 8 rengin
- İki ve dört yönlü ayna; döndürme, çevirme, kaydırma
- Izgara, 60 adıma kadar geri alma, küçük resimli galeri
- ×1, ×8 ya da ×16 PNG dışa aktarma

**English:** Sprites up to 64×64, exported as PNG.

- 8×8, 16×16, 32×32 and 64×64 canvases
- Pencil, eraser, fill, line, rectangle, replace colour and eyedropper
- A 16-colour retro palette plus 8 colours of your own
- Two-way and four-way mirroring; rotate, flip and shift
- Grid, up to 60 undo steps, gallery with thumbnails
- PNG export at ×1, ×8 or ×16

## Özellikler

- Araçlar: kalem, silgi, kova ile doldurma, çizgi, dikdörtgen ve renk seçici; çizgi ve dikdörtgende canlı önizleme.
- PICO-8 tarzı 16 renkli palet ve ton/doygunluk/parlaklık seçiciyle 8 özel renk.
- Ayna çizim (yatay simetri), ızgara, yatay çevirme, temizleme; 60 adıma kadar geri al / yinele (Ctrl+Z / Ctrl+Y).
- Galeri: küçük resimli kayıtlar, açma, silme ve silmeyi geri alma; son çizim otomatik saklanır.
- Gerçek PNG dışa aktarma (saydam arka plan), ×1, ×8 ya da ×16 büyütme; uygulamanın kendi PNG kodlayıcısıyla.
- Kısayollar: P, E, F, L, R, I araç seçer; G ızgara, M ayna. Dokunma, kalem gibi sürükleme ve kontrolcü imleci. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Piksel Sanatı > Al.

İzinler: yok. PNG dosyası kaydetme penceresinde seçtiğin yere yazılır, ayrıca dosya izni gerekmez.
Çizimler `~/Library/Application Support/com.sonerx7.pixelart/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~582 satır, PNG kodlayıcı `png.lua`, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/pixelart/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
