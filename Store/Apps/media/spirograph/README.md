# Spirograf / Spirograph

Klasik spirograf oyuncağı gibi dönen dişlilerle renkli eğri desenleri çizen yaratıcı bir uygulama.
A creative app that draws colourful curve patterns with rolling gears, just like the classic spirograph toy.

## Özellikler

- İç halka (hipotrokoid) ve dış halka (epitrokoid) eğrileri; halka, çark ve kalem uzaklığı kaydırıcıları.
- 8 katmana kadar üst üste eğri; her katmanın kendi rengi ve çizgi kalınlığı.
- Kalem eğriyi canlı çizer, dönen çark ve kalem kolu ekranda görünür; hız ayarı, duraklat ve yeniden çiz.
- Hazır desenler (Çiçek, Yıldız, Gül, Galaksi, Dantel) ve tek dokunuşla rastgele katman.
- Galeri: 24 tasarıma kadar küçük resimli kayıt, açma, silme ve silmeyi geri alma; ayarları panoya kopyalama.
- Koyu ya da açık tuval; klavye: Boşluk, R, sol/sağ ok katman seçer, Enter yeniden çizer. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Spirograf > Al.

İzinler: yalnızca `clipboard` (ayarları kopyalamak için). Ağ ya da dosya erişimi istemez.
Tasarımlar `~/Library/Application Support/com.sonerx7.spirograph/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~429 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/spirograph/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
