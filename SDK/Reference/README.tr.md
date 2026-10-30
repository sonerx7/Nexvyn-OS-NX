# Nexvyn OS SDK

[English](README.md) · **Türkçe**

Nexvyn OS uygulama SDK'sı, sürüm **1.6**. Uygulamalar `sys.sdkVersion()` ile sistemin sürümünü okur ve `app.json`
içinde `"minSdk"` ile gereken en düşük sürümü bildirir; daha yeni bir SDK isteyen uygulama kurulmaz ve kullanıcıya
Nexvyn OS'u güncellemesi söylenir.

## Bu klasörde

| Yol | Ne |
|---|---|
| [SDK.en.md](SDK.tr.md) | Tam başvuru (İngilizce, Türkçe özetli): paket düzeni, `app.json`, izinler, program yapısı, `gfx`, `ui`, girdi, `fs`/`store`/`json`, `net`, `sys`/`audio`/`timer`/`TR`, bağlantılar ve paylaşım, `g3d`, `nexvyn.game`, tasarım kuralları ve JavaScript (11), Python (12), Squirrel (13), C (14), Java (15) bölümleri. Belgede yazan her şey vardır, yazmayan yoktur. |
| `java/nexvyn/` | Java SDK kaynakları (`App`, `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`, `Theme`, `Json`, `Record`, `Menu`, `Event`, `Callback`, `Mesh`, `SearchResult`). Sistemin fonksiyon tablosundan üretilir; IDE'de tamamlama için `src/` yanına koyun ya da sınıf yoluna ekleyin. Konsoldaki derlenmiş hâli `romfs/System/Java/nexvyn.jar`. |
| `c/include/` | C uygulamalarının başlıkları: `nexvyn.h` (tüm SDK) ve konsoldaki küçük C kütüphanesi (`stdio.h`, `stdlib.h`, `string.h`, `math.h`, `ctype.h`, `stdint.h`...). Editörünüzün `include` yoluna ekleyin; konsol aynı başlıkları kullanır. |

Lua, JavaScript, Python ve Squirrel için ayrı SDK dosyası yoktur: modüller (`gfx`, `ui`, `store`...) çalışma
ortamında hazır gelir.

## SDK sürüm geçmişi

| SDK | Eklenenler |
|---|---|
| 1.0 | Lua çalışma ortamı: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | JavaScript çalışma ortamı (aynı modüller, Promise'ler); `g3d` dokuları GPU'da |
| 1.2 | `nexvyn.game` 2D motoru, `sys.sdkVersion()`, `app.json` `minSdk` ve `permissions`, tek dosya `.nxvapp` v2 ve `manifest.sha256` |
| 1.3 | Python çalışma ortamı (pocketpy); asenkron çağrılar geri çağırma alır |
| 1.4 | Beş iznin hepsi zorunlu; `sys.share`, `sys.schedule` / `unschedule` / `scheduled`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `sys.open` ile `nxv://` bağlantıları; `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved`; `shareTargets`; imzalı paketler (`manifest.sig`); Lua uygulamalarına da 64 MB sınırı |
| 1.5 | Squirrel, C (konsolda TinyCC) ve Java (miniJVM) çalışma ortamları; `"runtime"` değerleri `"squirrel"`, `"c"`, `"java"` ve `"mainClass"`; Python sistem kütüphanesi (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |
| 1.6 | `"games"` izni ve `sys.games` (kurulu oyunlar), `fs.unzip` (arka planda zip açma), `sys.speak` (metni sesli okuma) |

Küçük sürüm (1.x) yalnızca ekleme yapar; bir şey kaldırılır ya da anlamı değişirse büyük sürüm artar. Yeni bir şey
kullandığınızda `minSdk` değerini yükseltin.

| Dil | En düşük `minSdk` |
|---|---|
| Lua | 1.0 (`nexvyn.game` ile 1.2) |
| JavaScript | 1.1 |
| Python | 1.3 |
| Squirrel, C, Java | 1.5 |
