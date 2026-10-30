# Orman / Forest

Sabah güneşinde sisli çam sırtları ve ateş böcekli yıldızlı bir gece. Yeşil vurgu rengi.
Misty pine ridges in the morning sun and a starry night with fireflies. Green accent.

## Özellikler / Features

- Açık ve koyu görünümü kendiliğinden izler / Follows light and dark automatically
- Sabah ve gece duvar kâğıtları / Morning and night wallpapers
- Orman yeşili vurgu rengi / Forest green accent color

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.forest` |
| Görünüm / Appearance | Otomatik (gündüz açık, gece koyu) / Auto (light by day, dark at night) |
| Vurgu rengi / Accent | `#3E9B5B` |
| Dosyalar / Files | `wallpaper.jpg`, `wallpaper-dark.jpg` |
| Ayarlar / Settings | — |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Orman > Al. / **Store:** App Market > Themes > Forest > Get.
- **Dosya / File:** `forest.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `forest.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.forest/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.forest/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py forest

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
