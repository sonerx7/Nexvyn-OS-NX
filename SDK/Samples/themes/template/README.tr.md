# Tema şablonu

[English](README.md) · **Türkçe**

Geçerli en küçük tema paketi. Bu klasörü kopyalayın, sonra:

1. `theme.json` içinde `id` (ters alan adı, en az bir nokta), `name`, `description`, `author` ve renkleri değiştirin.
2. `wallpaper.jpg` yerine kendi 1280x720 resminizi koyun (kendinizin çizdiği, render ettiği ya da ürettiği).
3. Denetleyip paketleyin: `python SDK/Tools/theme/themecheck.py MyTheme --pack`.
4. `.nxvtheme` dosyasını konsolda Dosyalar ile açın ve Kur ve Uygula'yı seçin.

İsterseniz `icons/<app id>.png` (128 px), `sounds/*.wav`, `wallpapers`, `wallpaperDark` ve `preview.jpg` ekleyin.
Her şey özgün iş olmalı. Tam rehber: [Tema yapımı](../../../Guides/THEMES.tr.md).
