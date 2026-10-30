# Retro Terminal

Açılış kayıtlı yeşil fosforlu bir CRT ekran; koyu görünüm, opak paneller ve 8 bit arayüz sesleri.
A green phosphor CRT with a boot log, dark appearance, opaque panels and 8-bit interface sounds.

## Özellikler / Features

- Koyu görünüm / Dark appearance
- Fosfor yeşili vurgu rengi / Phosphor green accent color
- Tıklama, uyarı, çöp ve açılış için 8 bit sesler / 8-bit sounds for clicks, alerts, trash and startup
- Opak paneller, saat ekran koruyucusu / Opaque panels, clock screen saver

| | |
|---|---|
| Kimlik / Id | `com.sonerx7.theme.retroterminal` |
| Görünüm / Appearance | Koyu / Dark |
| Vurgu rengi / Accent | `#2FD25B` |
| Dosyalar / Files | `wallpaper.jpg`, `sounds/*.wav` |
| Ayarlar / Settings | `appearance.reduceTransparency` = `true`, `screensaver.style` = `2` |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > Retro Terminal > Al. / **Store:** App Market > Themes > Retro Terminal > Get.
- **Dosya / File:** `retro-terminal.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `retro-terminal.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/com.sonerx7.theme.retroterminal/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/com.sonerx7.theme.retroterminal/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları, sesler ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers, sounds and
the preview are generated:

    python Store/Themes/tools/gen_themes.py retro-terminal

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
