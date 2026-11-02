# Luma: Starfall Islands / Luma: Yıldız Adaları

A colourful 3D platform adventure across ten authored floating-island worlds. Double jump, dash, break crates, collect thirty star fragments, ride moving platforms and defeat the Star Guardian. Each world has its own original music, scenery and movement challenge: springs, ice, conveyors, crumbling islands or wind.

On özgün yüzen ada dünyasında geçen renkli bir 3B platform macerası. Çift zıpla, atıl, kasaları kır, otuz yıldız parçasını topla, hareketli adalara bin ve Yıldız Muhafızı'nı yen. Her dünyanın özgün müziği, çevresi ve yay, buz, taşıma bandı, çöken ada veya rüzgâr gibi ayrı bir hareket mekaniği vardır.

| Property / Özellik | Value / Değer |
|---|---|
| Id / Kimlik | `com.sonerx7.luma` |
| Runtime / Çalışma ortamı | Lua 5.4, `g3d` |
| Minimum SDK / En düşük SDK | 1.4 |
| Permissions / İzinler | None / Yok (`[]`) |
| Version / Sürüm | 1.0.1 |
| License / Lisans | GPL-3.0-or-later, the repository's default / deponun varsayılanı |

## Controls / Kontroller

| Action / Eylem | Keyboard / Klavye | Controller / Kumanda |
|---|---|---|
| Move / Hareket | WASD, arrows / oklar | Left stick, D-pad / sol çubuk, D-pad |
| Jump, double jump / Zıpla, çift zıpla | Space, press again airborne / havada tekrar | A, press again airborne / havada tekrar |
| Run / Koş | Shift | ZR or X / ZR veya X |
| Dash, break crates / Atıl, kasaları kır | X | B |
| Ground slam / Yere sert in | C | Y |
| Camera / Kamera | Q, E; R to centre / ortala | Right stick, L, R; R3 to centre / sağ çubuk, L, R; R3: ortala |
| Pause / Duraklat | Esc, P | + |

Touch: drag the left side to move, drag upward to jump; right-side buttons jump, dash and slam. / Dokunmatik: sol alanı sürükleyerek hareket et, yukarı sürükleyerek zıpla; sağ düğmelerle zıpla, atıl ve yere sert in.

Each gate requires two stars; the final gate also requires defeating the guardian. Touch checkpoint flags to save the current run. Completed-world records, stars, best times and settings persist. Guide mode replenishes lives. / Her kapı iki yıldız ister; son kapı için muhafızı da yenmelisin. Bölüm içi kaydı almak için bayraklara dokun. Tamamlanan dünyalar, yıldızlar, en iyi süreler ve ayarlar saklanır. Rehber modu canları yeniler.

## Validation and previews / Denetim ve önizlemeler

The Lua 5.4 headless suite checked jumps, moving and crumbling supports, damage, enemy stomps, crates, save/restore, boss combat, gates, 210 adjacent route transitions and all ten scene/lifecycle flows. `nxv check` validates the bundle and Store metadata. **Not yet tested on a physical Switch or Ryujinx.** The full OS source repository's official `lua_check.py` was not available.

Lua 5.4 başsız denetimleri zıplamaları, hareketli ve çöken adaları, hasarı, düşman ezmeyi, kasaları, kayıt yüklemeyi, muhafızı, kapıları, 210 komşu platform geçişini ve on sahnenin yaşam döngüsünü denetledi. `nxv check` paket ve mağaza bilgilerini doğrular. **Fiziksel Switch veya Ryujinx üzerinde henüz denenmedi.** Tam OS kaynak deposundaki resmî `lua_check.py` mevcut değildi.

`screenshots/` contains clearly labelled **offline software previews generated from the actual Lua scene/UI commands**, not device captures. They are supplied for visual review; the maintainer should replace them with real Nexvyn OS captures before publication. `store.json` includes a four-shot script for that pass. / `screenshots/`, gerçek Lua sahne ve arayüz komutlarından üretilen, açıkça etiketli **çevrimdışı yazılım önizlemelerini** içerir; cihaz görüntüsü değildir. Görsel inceleme içindir; yayımlamadan önce bakımcı bunları gerçek Nexvyn OS görüntüleriyle değiştirmelidir. `store.json` bunun için dört çekimlik betik içerir.

## Assets and credits / Varlıklar ve katkılar

- Code, 34 vertex-coloured models (21,882 authored triangles) and ten synthesized original music loops were created specifically for Luma for sonerx7. / Kod, 34 renkli model (21.882 kaynak üçgen) ve sentezlenen on özgün müzik Luma için sonerx7 adına oluşturuldu.
- The new promotional icon was generated specifically for this game with OpenAI ImageGen using the game's own character model sheet as reference. It is promotional artwork. / Yeni tanıtım ikonu, oyunun kendi karakter model görseli referans alınarak OpenAI ImageGen ile bu oyun için üretildi; tanıtım çizimidir.
- No external character art, Nintendo assets, downloaded music or bundled fonts. The app uses Nexvyn OS system fonts and the documented SDK. / Haricî karakter görseli, Nintendo varlığı, indirilmiş müzik veya paketlenmiş yazı tipi yoktur. Uygulama Nexvyn OS sistem yazı tiplerini ve belgelenmiş SDK'yı kullanır.
- No networking, telemetry, advertising or credentials. / Ağ, telemetri, reklam veya kimlik bilgisi içermez.

## Versions / Sürümler

| Version / Sürüm | Changes / Değişiklikler |
|---|---|
| 1.0.1 | New cinematic icon and first Store submission. / Yeni sinematik ikon ve ilk mağaza başvurusu. |
| 1.0.0 | Initial ten-world adventure. / İlk on dünyalık macera. |
