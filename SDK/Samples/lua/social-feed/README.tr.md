# Sosyal Akış

[English](README.md) · **Türkçe**

Fotoğraf akışı, fotoğraf ızgarası ve dikey klip sayfalayıcı: SDK 1.9 fonksiyonlarıyla akış, fotoğraf ve kısa video
uygulamalarının yapı taşları. Yaklaşık 250 satır açıklamalı Lua.

| | |
|---|---|
| Id | `com.sonerx7.demo.socialfeed` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.9 |
| İzinler | `network` |
| Gamepad | imleç |
| Pencere | 720 × 640, boyutlandırılabilir |

## Ne öğretir

- `responseType = "json"`, `cache` (çevrimdışı yanıt, `stale` işaretli) ve `retry` ile `net.request`; web kopyasına
  ulaşılamazsa paketteki `media/feed.json`
- `gfx.imageUrl(url, maxSize)`: disk ve bellek önbellekli web fotoğrafları, ızgara için küçük resimler, yüklenirken yer
  tutucu
- `ui.beginFeed` / `ui.feedItem` / `ui.endFeed`: ölçülmüş gönderi yükseklikleriyle sanal liste, 3–4 sütunlu ızgara,
  çek-yenile ve sonsuz kaydırma
- `media.open` / `media.draw` / `media.set` ile `ui.pager`: sayfa başına bir klip, yalnızca şimdiki ve sonraki
  oynatıcı açık, sessize alma, ara bellek dolarken çark, `app.suspend`'de duraklatma
- `ui.richText` açıklamaları (`**kalın**`, bağlantılar, `@bahsetmeler`, `#etiketler`), `ui.measureRichText`,
  `sys.relativeTime`
- bir gönderiye dönen `sys.appUrl` bağlantısıyla `sys.share` (`app.open("post:12")`)

**Kontroller:** dokunma ya da imleç; yenilemek için akışı aşağı çekin, klipleri yukarı aşağı kaydırın (D-pad yukarı /
aşağı da olur).

## Çalıştırma

- **Konsolda:** `source/` klasörünü `sdmc:/NexvynOS/Applications/` içine `socialfeed.nxvapp` olarak kopyalayın (ya da
  `python SDK/Tools/nxv/nxv.py push SDK/Samples/lua/social-feed/source --host <konsol-ip>`) ve Launcher'dan açın.
- **PC'de denetleme:** `python tools/lua_check.py SDK/Samples/lua/social-feed/source` (SDK mock'ları).

## Medya

12 fotoğraf, 3 klip ve ikon `make_social_media.py` ile üretilir (prosedürel çizim ve tonlar). Kamu malına
bağışlanmıştır: **CC0 1.0**. Uygulama bunları webde bu depodan okur (`raw.githubusercontent.com`, resim önbelleğinin
saklayacak bir şeyi olsun diye), çevrimdışıyken kendi `media/` klasöründen.
