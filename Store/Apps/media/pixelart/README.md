# Piksel Sanatı / Pixel Art

8×8, 16×16 ve 32×32 piksel çizimler yapıp gerçek PNG dosyası olarak dışa aktaran çizim uygulaması.
A drawing app for 8×8, 16×16 and 32×32 pixel art that exports real PNG files.

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
