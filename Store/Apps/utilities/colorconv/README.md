# Renk Dönüştürücü / Color Converter

Renkleri HEX, RGB, HSL, HSV ve CMYK arasında dönüştüren ve kontrastını ölçen Nexvyn OS uygulaması.
A Nexvyn OS app that converts colors between HEX, RGB, HSL, HSV and CMYK and measures their contrast.

## Özellikler

- Rengi hex, `rgb(…)` ya da `hsl(…)` yazarak veya RGB, HSL, HSV kaydırıcılarıyla düzenle; hepsi eşzamanlı güncellenir.
- Her kaydırıcıda renkli iz ve hassas ayar için -/+ düğmeleri; gri renklerde ton kaybolmaz.
- HEX, rgb(), hsl(), hsv() ve CMYK değerleri; her biri tek dokunuşla panoya kopyalanır.
- Büyük önizleme, beyaz ve siyaha karşı WCAG kontrast oranı ve AA/AAA/büyük metin etiketleri.
- Ters çevirme, gri tona çevirme, açma ve koyulaştırma; üzerinde karar kılınan renkler "Son renkler" listesine girer.
- Klavye: Ctrl+R rastgele, Ctrl+I ters çevir, Ctrl+G gri ton, Ctrl+yukarı/aşağı aç/koyulaştır, Ctrl+1/2/3 kaydırıcı seti.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Renk Dönüştürücü > Al.

İzinler: yalnızca `clipboard` (değerleri kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.colorconv/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~465 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/colorconv/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
