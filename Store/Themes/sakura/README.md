# Sakura

Yumuşak bahar ışığında, geceleri de ay altında bir kiraz çiçeği dalı. Pembe vurgu rengi.
A cherry blossom branch in soft spring light, and at night under the moon. Pink accent.

## Özellikler / Features

- Açık ve koyu görünümü kendiliğinden izler / Follows light and dark automatically
- Gündüz ve gece duvar kâğıtları / Light and night wallpapers
- Pembe vurgu rengi / Pink accent color

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.sakura` |
| Görünüm / Appearance | Otomatik (gündüz açık, gece koyu) / Auto (light by day, dark at night) |
| Vurgu rengi / Accent | `#E86A92` |
| Dosyalar / Files | `wallpaper.jpg`, `wallpaper-dark.jpg` |
| Ayarlar / Settings | — |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Sakura > Al. / **Store:** App Market > Themes > Sakura > Get.
- **Dosya / File:** `sakura.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `sakura.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.sakura/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.sakura/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py sakura

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
