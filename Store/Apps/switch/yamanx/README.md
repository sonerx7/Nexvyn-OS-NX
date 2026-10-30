# YamaNX

**SertAy'ın [YamaNX](https://github.com/sertay1/YamaNX)'i temel alınmıştır / Based on [YamaNX](https://github.com/sertay1/YamaNX) by SertAy.**

Nintendo Switch oyunları için Türkçe yama yükleyici. Konsolundaki oyunların Türkçe yamalarını bulur, indirir ve
`sdmc:/atmosphere/contents/<Title ID>/` içine kurar; güncellemeleri gösterir, kaldırırken yalnızca kurduğu dosyaları
siler ve değiştirdiği dosyaları geri koyar.

Turkish patch installer for Nintendo Switch games. It finds the Turkish patches for the games on your console,
downloads them and installs them to `sdmc:/atmosphere/contents/<Title ID>/`; it shows updates, and uninstalling removes
only the files it installed and puts replaced files back.

| | |
|---|---|
| Kimlik / Id | `yamanx` |
| Kategori / Category | Switch Araçları / Switch Tools |
| Özgün geliştirici / Original author | SertAy — <https://github.com/sertay1/YamaNX>, <https://linktr.ee/yamanx> |
| Nexvyn OS uyarlaması / Nexvyn OS port | Soner Çakır (sonerx7), Lua |
| İzinler / Permissions | `network`, `files` (sdmc:/atmosphere), `games` (yüklü oyunlar / installed games) |
| SDK | 1.6 (`fs.unzip`, `sys.games`) |
| Lisans / License | YamaNX lisansı / the YamaNX license — © 2026 SertAy, tüm hakları saklıdır / all rights reserved; ticari olmayan kullanım / non-commercial use. [YamaNX](https://github.com/sertay1/YamaNX) |

## Lisans notu / License note

Bu uygulama YamaNX'in değiştirilmiş bir uyarlamasıdır ve YamaNX lisansıyla dağıtılır: SertAy özgün geliştirici olarak
anılır, değişiklikler `NOTICE.md` dosyasında listelenir, uygulama ücretsizdir, reklam ve ücretli özellik içermez.
Nexvyn OS'un (GPL-3.0-or-later) parçası değildir ve `NexvynOS.nro` içine gömülmez; App Market'ten ayrı olarak kurulur.

This app is a modified port of YamaNX and is distributed under the YamaNX license: SertAy is credited as the original
creator, the changes are listed in `NOTICE.md`, and the app is free, with no ads and no paid features. It is not part
of Nexvyn OS (GPL-3.0-or-later) and is not built into `NexvynOS.nro`; it is installed separately from the App Market.

Yamalar çevirmenlerine aittir (Swatalk, Soner Çakır, Profesör Pikachu, Dede00, emre, davetsiz57 ve diğerleri).
The patches belong to their translators (Swatalk, Soner Çakır, Profesör Pikachu, Dede00, emre, davetsiz57 and others).

## Kurulum / Install

Nexvyn OS'ta **Uygulama Mağazası > Switch Araçları > YamaNX**. Yamaların yüklenmesi için Atmosphère gerekir.

In Nexvyn OS: **App Market > Switch Tools > YamaNX**. Atmosphère is needed for the patches to load.
