# Okyanus / Ocean

Öğle güneşinde ve ay ışıklı bir gecede açık deniz. Turkuaz vurgu rengi.
The open sea under the midday sun and a moonlit night. Turquoise accent.

## Özellikler / Features

- Açık ve koyu görünümü kendiliğinden izler / Follows light and dark automatically
- Gündüz ve gece duvar kâğıtları / Day and night wallpapers
- Turkuaz vurgu rengi / Turquoise accent color

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.ocean` |
| Görünüm / Appearance | Otomatik (gündüz açık, gece koyu) / Auto (light by day, dark at night) |
| Vurgu rengi / Accent | `#0A9FD8` |
| Dosyalar / Files | `wallpaper.jpg`, `wallpaper-dark.jpg` |
| Ayarlar / Settings | `dock.magnification` = `1.7` |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Okyanus > Al. / **Store:** App Market > Themes > Ocean > Get.
- **Dosya / File:** `ocean.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `ocean.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.ocean/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.ocean/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py ocean

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
