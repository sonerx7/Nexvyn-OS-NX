# Renk Paleti / Color Palette

Tek bir ana renkten uyumlu renk paletleri oluşturan Nexvyn OS uygulaması.
A Nexvyn OS app that builds harmonious color palettes from one base color.

## Özellikler

- Ana rengi hex alanı, ton/doygunluk/açıklık kaydırıcıları, dokunup sürüklenebilen ton çarkı ya da rastgele düğmesiyle seç.
- Yedi uyum: tamamlayıcı, analog, üçlü, dörtlü, ayrık tamamlayıcı, monokromatik, koyu ve açık tonlar; ton çarkında işaretlenir.
- Her renk için hex, rgb() ve hsl() değerleri; bir renge dokunmak hex kodunu panoya kopyalar.
- Favori paletler: kaydet, geri yükle, kopyala, geri alınabilir silme.
- Dışa aktarma: paleti metin ya da CSS değişkenleri olarak kopyalama, GIMP/Inkscape paleti (`.gpl`) olarak kaydetme.
- Klavye: Ctrl+R rastgele, Ctrl+S favorilere ekle, Ctrl+E paleti kopyala, Ctrl+sol/sağ uyum değiştir.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Renk Paleti > Al.

İzinler: yalnızca `clipboard` (renkleri kopyalamak için). Ağ ya da dosya erişimi istemez; `.gpl` yalnızca senin
seçtiğin dosyaya yazılır.
Veriler `~/Library/Application Support/com.sonerx7.palette/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~505 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/palette/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
