# Ayaz Feneri / Frost Lantern

Türkçe / English · 1.0.0 · Nexvyn OS SDK 1.4+ · GPL-3.0-or-later

Beş bölgede yolunu seç, otuz lütfu birleştir ve beş bekçiyi yen. Ölüm yolculuğu bitirir; şafak kırıkları kalıcı atölye geliştirmeleri için saklanır. / Choose a path across five regions, combine thirty boons and defeat five keepers. Death ends a journey; dawn shards remain for permanent workshop upgrades.

Başlangıç silahları / Starting weapons: Fener Kılıcı / Lantern Blade, Bakır Arbalet / Copper Crossbow, Ayaz Asası / Frost Staff.

| Eylem / Action | Klavye / Keyboard | Kumanda / Controller |
|---|---|---|
| Hareket / Move | WASD / arrows | Left stick |
| Nişan / Aim | Mouse | Right stick |
| Saldırı / Attack | Left click / J | ZR |
| Atılma / Dash | Space / right click | B |
| Fener / Lantern | Q | Y |
| İksir / Potion | H | L |
| Etkileş / Use | E | X |
| Lütuflar / Build | Tab | Minus |
| Duraklat / Pause | Esc / P | Plus |

Oda temizlenince bir lütuf seç; kuzey kapısına yaklaşıp E / X kullan. Sandık, sunak ve tüccar için odanın ortasındaki nesneyle etkileş. / After clearing a room, choose a boon; approach the north gate and press E / X. Interact with the central object for treasure, shrines and merchants.

Dokunmatikte sol alan hareket + otomatik saldırı, sağ alan otomatik nişanla saldırıdır; alt düğmeler özel eylemleri yapar. Tam rehber ve ayarlar oyun içindedir. / Touch: left area moves and auto-attacks, right area attacks with auto aim; bottom buttons perform special actions. Full help and settings are available in game.

Grafikler, bitmap alfabe ve sesler bu oyun için oluşturuldu. Açılış illüstrasyonu yerleşik OpenAI ImageGen ile üretildi. / Graphics, bitmap alphabet and audio were authored for this game. The title illustration was generated using built-in OpenAI ImageGen.

İlk Store sürümü. Gerçek Switch / Ryujinx performansı henüz doğrulanmamıştır. / First Store release; real Switch / Ryujinx performance is not yet validated.

## Validation / Denetim

The Lua 5.4 behavioral suite passes: 780 connected generated rooms, bridge navigation, collision, three weapons, boons and synergies, economy, JSON-round-tripped immutable saves, five boss loops and the complete victory chain. Strict SDK-adapter checks cover keyboard, controller and touch, 640/1280 layouts, suspend and resume. `nxv check`, archive CRC and SHA-256 manifest checks pass. Real Switch/Ryujinx validation and the full OS runtime checker remain pending.

Lua 5.4 davranış denetimleri geçti: 780 bağlantılı oda, köprü navigasyonu, çarpışma, üç silah, lütuflar ve birliktelikler, ekonomi, JSON üzerinden yeniden yüklenen bağımsız kayıtlar, beş boss döngüsü ve tam bitiş zinciri. Sıkı SDK adaptörü klavye, kumanda, dokunmatik, 640/1280 düzenleri, askıya alma ve devamı denetledi. `nxv check`, paket CRC ve SHA-256 denetimleri geçti. Gerçek Switch/Ryujinx ve tam OS çalışma zamanı denetimi bekleniyor.

`screenshots/` contains labelled software previews rendered from this game's actual Lua draw commands. They are not device captures. / Görseller bu oyunun gerçek Lua çizim komutlarından üretilmiş, etiketli yazılım önizlemeleridir; cihaz görüntüsü değildir.

Code, sprites, the bitmap alphabet and synthesized music are original. The title illustration was generated specifically for this game using OpenAI ImageGen. No external character art, downloaded audio, bundled fonts, tracking, advertising or credentials. / Kod, sprite’lar, bitmap alfabe ve sentez müzikler özgündür. Açılış illüstrasyonu OpenAI ImageGen ile bu oyun için üretildi. Haricî karakter görseli, indirilmiş ses, paketlenmiş font, izleme, reklam veya kimlik bilgisi yoktur.

## Versions / Sürümler

| Version / Sürüm | Changes / Değişiklikler |
|---|---|
| 1.0.0 | Five regions, five bosses, thirty boons and permanent progression. / Beş bölge, beş boss, otuz lütuf ve kalıcı gelişim. |
