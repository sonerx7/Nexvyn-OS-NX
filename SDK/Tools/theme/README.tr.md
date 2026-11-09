# theme

[English](README.md) · **Türkçe**

`themecheck.py` bir tema paketi klasörünü denetler ve `.nxvtheme` olarak paketler. Düz Python 3.8+, paket gerekmez.

    python SDK/Tools/theme/themecheck.py MyTheme            # biçim, sınırlar, kontrast
    python SDK/Tools/theme/themecheck.py MyTheme --pack     # ayrıca MyTheme.nxvtheme yazar

`theme.json`'u (id, appearance, accent, adı geçen dosyalar, ayar değerleri, palet adları), paket sınırlarını (160 dosya,
32 MB, dosya başına 12 MB, izinli uzantılar) ve ayarladığınız palet çiftlerinin WCAG AA kontrastını (pencere, içerik ve
kenar çubuğu üstünde yazı, menü yazısı, seçim yazısı) denetler. Hatalar paketlemeyi durdurur; uyarılar öneridir. Bkz.
[Tema yapımı](../../Guides/THEMES.tr.md).
