# Gece Yarısı Neonu / Midnight Neon

Parlayan bir ızgaranın üzerinde retro dalga güneşi; koyu görünüm ve eflatun vurgu rengi.
A retro-wave sun over a glowing grid, in the dark appearance with a magenta accent.

## Özellikler / Features

- Koyu görünüm / Dark appearance
- Eflatun vurgu rengi / Magenta accent color
- Yıldız yolculuğu ekran koruyucusu, daha güçlü Dock büyütmesi / Star warp screen saver, stronger Dock magnification

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.midnightneon` |
| Görünüm / Appearance | Koyu / Dark |
| Vurgu rengi / Accent | `#FF2BD6` |
| Dosyalar / Files | `wallpaper.jpg` |
| Ayarlar / Settings | `screensaver.style` = `1`, `dock.magnification` = `1.8` |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Gece Yarısı Neonu > Al. / **Store:** App Market > Themes > Midnight Neon > Get.
- **Dosya / File:** `midnight-neon.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `midnight-neon.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.midnightneon/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.midnightneon/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers and
the preview are generated:

    python Store/Themes/tools/gen_themes.py midnight-neon

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
