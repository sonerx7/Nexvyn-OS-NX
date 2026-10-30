# Kâğıt / Paper

Sıcak tonlu kâğıt üzerinde sakin baskı şekilleri: opak panelli, kiremit vurgu renkli sade bir açık görünüm.
Calm printed shapes on warm paper: a minimal light look with opaque panels and a terracotta accent.

## Özellikler / Features

- Açık görünüm / Light appearance
- Opak Dock ve menü çubuğu (azaltılmış saydamlık) / Opaque Dock and menu bar (reduced transparency)
- Büyütmesiz Dock / Dock without magnification
- Kiremit vurgu rengi / Terracotta accent color

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.paper` |
| Görünüm / Appearance | Açık / Light |
| Vurgu rengi / Accent | `#C8553D` |
| Dosyalar / Files | `wallpaper.jpg` |
| Ayarlar / Settings | `appearance.reduceTransparency` = `true`, `dock.magnify` = `false` |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Kâğıt > Al. / **Store:** App Market > Themes > Paper > Get.
- **Dosya / File:** `paper.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `paper.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.paper/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.paper/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py paper

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
