# Kutup Işıkları / Aurora

Dağ gölünün üzerinde kuzey ışıkları; koyu görünüm ve nane yeşili vurgu rengi.
Northern lights over a mountain lake, in the dark appearance with a mint accent.

## Özellikler / Features

- Koyu görünüm / Dark appearance
- Nane yeşili vurgu rengi / Mint accent color
- Yıldız yolculuğu ekran koruyucusu / Star warp screen saver

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.aurora` |
| Görünüm / Appearance | Koyu / Dark |
| Vurgu rengi / Accent | `#3DDC97` |
| Dosyalar / Files | `wallpaper.jpg` |
| Ayarlar / Settings | `screensaver.style` = `1` |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Kutup Işıkları > Al. / **Store:** App Market > Themes > Aurora > Get.
- **Dosya / File:** `aurora.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `aurora.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.aurora/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.aurora/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py aurora

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
