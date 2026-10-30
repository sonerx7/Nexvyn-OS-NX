# Fraktal Gezgini / Fractal Explorer

Mandelbrot kümesini ve Julia kümelerini kaydırarak, yakınlaştırarak keşfettiren ve PNG olarak kaydeden fraktal uygulaması.
A fractal app to explore the Mandelbrot set and its Julia sets by panning and zooming, with PNG export.

## Özellikler

- Sürükleyerek kaydırma, iki parmakla (pinch), fare tekerleğiyle, çift dokunuşla ya da düğmelerle yakınlaştırma.
- Aşamalı çizim: önce büyük bloklar, sonra ince ayrıntı; her karede en fazla ~5 ms hesap, bu yüzden arayüz hep akıcı.
- Julia modu: Mandelbrot görünümünün ortası (artı işareti) Julia sabiti olur.
- Beş renk şeması (Ateş, Okyanus, Gökkuşağı, Alacakaranlık, Siyah-Beyaz), yumuşak renk geçişi, 50–2000 ayrıntı (iterasyon), üç kalite düzeyi.
- Hazır yerler (Denizatı Vadisi, Fil Vadisi, Üçlü Sarmal…) ve kendi yerlerini kaydetme; koordinatları panoya kopyalama.
- Görünümü PNG olarak dışa aktarma (uygulamanın kendi PNG kodlayıcısı, kaydetme yerini sen seçersin).
- Klavye: oklar kaydırır, Z/X yakınlaştırır, R sıfırlar, J Julia, C renk şeması. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Fraktal Gezgini > Al.

İzinler: yalnızca `clipboard` (koordinatları kopyalamak için). Dışa aktarılan PNG, kaydetme penceresinde seçtiğin yere yazılır.
Son görünüm ve kayıtlı yerler `~/Library/Application Support/com.sonerx7.mandelbrot/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~522 satır, PNG kodlayıcı `png.lua`, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/mandelbrot/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
