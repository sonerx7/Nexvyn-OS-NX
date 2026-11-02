# Ash Protocol / Kül Protokolü

An original fast first-person shooter built from real 3D meshes. Fight through six story chapters, 36 rooms and elevated decks with four distinct weapons, dashes, melee finishers and energy-shot reflection. Face six hostile archetypes, recover 18 records and choose between two endings. Real UV textures, per-pixel directional light plus reactive mesh-level local lighting and a flashlight. No shadow maps or PBR. Controller, keyboard/drag-mouse and touch. Supplied images are labelled software previews; real-device validation is pending.

Gerçek 3B meshlerle kurulan özgün, hızlı bir FPS. Altı hikâye bölümü, 36 oda ve yüksek güvertede dört silah, atılma, yakın dövüş ve enerji atışı yansıtmayla savaş. Altı düşman türü, 18 kayıt ve iki son. Gerçek UV dokuları, piksel başına yönlü ışık, tepki veren mesh düzeyinde yerel ışık ve fener. Gölge haritası veya PBR yok. Kumanda, klavye/sürüklemeli fare ve dokunmatik. Görseller yazılım önizlemesidir; cihaz doğrulaması bekleniyor.

| Property / Özellik | Value / Değer |
|---|---|
| Id / Kimlik | `com.sonerx7.ashprotocol` |
| Version / Sürüm | 1.0.0 |
| Runtime / Çalışma ortamı | Lua 5.4 / g3d |
| Minimum SDK / En düşük SDK | 1.4 |
| Permissions / İzinler | None / Yok (`[]`) |
| Licence / Lisans | GPL-3.0-or-later |

## Controls / Kontroller

WASD/left stick: move; right-drag/right stick: look; left click/ZR: fire; Space/A: jump; Shift/B: dash; C/ZL: melee; E/X: use; F/R3: flashlight; Esc/Plus: pause. / WASD/sol çubuk: hareket; sağ sürükleme/sağ çubuk: bakış; sol tık/ZR: ateş; Space/A: zıpla; Shift/B: atıl; C/ZL: yakın dövüş; E/X: kullan; F/R3: fener; Esc/Artı: duraklat.

Touch controls and a full help screen are included. Open the `.nxvapp` package in Nexvyn OS Files to install. / Dokunmatik kontroller ve tam yardım ekranı vardır. Kurmak için `.nxvapp` paketini Nexvyn OS Dosyalar uygulamasından aç.

## Assets / Varlıklar

24 original models, 15,716 source triangles, seven UV texture maps, six original music loops and a procedurally authored insignia. Native per-pixel directional light plus mesh/panel-level reactive local lighting; no shadow maps, normal maps or PBR. / 24 özgün model, 15.716 kaynak üçgen, yedi UV doku haritası, altı özgün müzik döngüsü ve kodla üretilmiş amblem. Piksel başına yönlü ışık ve mesh/panel düzeyinde tepki veren yerel aydınlatma; gölge haritası, normal map veya PBR yoktur.

Code, models, textures and music were authored for this game. No external franchise characters, downloaded music, bundled fonts, tracking, advertising or embedded credentials. / Kod, modeller, dokular ve müzik bu oyun için üretildi. Haricî marka karakteri, indirilmiş müzik, paketlenmiş font, izleme, reklam veya gömülü kimlik bilgisi yoktur.

## Validation / Denetim

The Lua 5.4 behavioral suite passed: 72 two-way corridor traversals, six ramps, four weapons, wall occlusion, ammunition, damage, reflected shots, independent save snapshots and six mission chains. / 72 çift yönlü koridor geçişi, altı rampa, dört silah, duvar engellemesi, cephane, hasar, atış yansıtma, bağımsız kayıt kopyaları ve altı görev zinciri.

Strict local SDK-adapter checks cover menus, keyboard/controller/touch, minimum/default window sizes, saves and suspend/resume. `nxv check`, package CRC, SHA-256 manifests and exact package/source matching pass. Real Switch/Ryujinx performance and the full OS runtime checker remain unverified. / Sıkı yerel SDK adaptörü menüleri, klavye/kumanda/dokunmatiği, en küçük/varsayılan pencere boyutlarını, kayıt ve askıya alma/devam akışlarını denetledi. `nxv check`, paket CRC, SHA-256 manifest ve birebir paket/kaynak denetimleri geçti. Gerçek Switch/Ryujinx performansı ve tam OS çalışma zamanı denetleyicisi henüz doğrulanmadı.

`screenshots/` contains labelled software previews of actual Lua scene/UI commands, not device captures. / Görseller gerçek Lua sahne/arayüz komutlarının etiketli yazılım önizlemeleridir; cihaz görüntüsü değildir.

## Versions / Sürümler

| Version / Sürüm | Changes / Değişiklikler |
|---|---|
| 1.0.0 | First Store release: six story chapters, four weapons, six enemy types and textured 3D environments. / İlk Store sürümü: altı hikâye bölümü, dört silah, altı düşman türü ve dokulu 3B ortamlar. |
