# SDK sürümleri: 1.0'dan 1.9'a

[English](SDK_VERSIONS.en.md) · **Türkçe**

Nexvyn OS uygulama SDK'sının her sürümü ne ekledi, hangi Nexvyn OS sürümüyle geldi ve hangi dillerde var. Fonksiyon
fonksiyon sözleşme [SDK başvurusudur](../Reference/SDK.tr.md) (bölüm 1, *SDK sürümleri*); bu sayfanın arkasındaki uyumluluk
kuralları [COMPATIBILITY.tr.md](COMPATIBILITY.tr.md)'de.

## İçindekiler

1. [Üç sürüm numarası](#1-üç-sürüm-numarası)
2. [Bir bakışta](#2-bir-bakışta)
3. [Sürüm sürüm](#3-sürüm-sürüm)
4. [minSdk ve targetSdk](#4-minsdk-ve-targetsdk)
5. [Hiçbir şey silinmez, yalnızca deprecated olur](#5-hiçbir-şey-silinmez-yalnızca-deprecated-olur)
6. [Hangi diller yeni API alır](#6-hangi-diller-yeni-api-alır)
7. [Uygulamanız için minSdk seçmek](#7-uygulamanız-için-minsdk-seçmek)

## 1. Üç sürüm numarası

| Numara | Örnek | Anlamı |
|---|---|---|
| **Nexvyn OS** | `1.2.2` | sistem sürümü (major.minor.patch), Ayarlar > Hakkında'da görünür |
| **SDK** | `1.9` | uygulamaların karşısına yazıldığı API yüzeyi (major.minor); `sys.sdkVersion()` bunu döndürür |
| **Runtime motoru** | Lua 5.4.7, QuickJS-ng 0.17.0, pocketpy 2.2.0 | bir dilin arkasındaki yorumlayıcı ya da derleyici |

Yeni bir SDK fonksiyonu SDK'nın minor numarasını artırır ve yeni bir Nexvyn OS minor sürümüyle gelir. Var olan bir
fonksiyonun davranışını değiştiren bir değişiklik SDK'nın major numarasını artırırdı ve yalnızca yeni SDK'yı hedefleyen
uygulamalar onu alırdı (bölüm 4).

## 2. Bir bakışta

| SDK | İlk Nexvyn OS | Başlıca yenilik | Diller |
|---|---|---|---|
| 1.0 | 1.0.0 | Lua uygulamaları: çizim, widget'lar, dosyalar, ağ, sistem, ses, timer'lar, çeviriler, 3B | Lua |
| 1.1 | 1.0.0 | Promise'li JavaScript runtime'ı; GPU'da 3B dokular | Lua, JavaScript |
| 1.2 | 1.0.0 | `nexvyn.game` 2D motoru, `sys.sdkVersion()`, `minSdk` ve `permissions` | Lua, JavaScript (`nexvyn.game`: Lua) |
| 1.3 | 1.0.0 | Python runtime'ı (pocketpy) | Lua, JavaScript, Python |
| 1.4 | 1.0.0 | her izin zorunlu, paylaşım, zamanlanmış bildirimler, `nxv://` bağlantıları, yaşam döngüsü callback'leri | Lua, JavaScript, Python |
| 1.5 | 1.0.0 | Squirrel, C ve Java runtime'ları; Python sistem kütüphanesi | altısı da |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games`, metin okuma; `"python3"` runtime'ı (CPython 3.12) | bkz. bölüm 3 |
| 1.7 | 1.1.0 | `g3d.voxels` voksel dünyalar; mesh'lerde pixel art dokular | JavaScript (voksel); Lua, JavaScript (dokular) |
| 1.8 | 1.2.0 | `g3d.model`: materyal, doku ve iskelet animasyonlu `.glb` / `.gltf` / `.fbx` modeller | altısı da |
| 1.9 | 1.2.2 | runtime kütüphanesi; akış, fotoğraf ve kısa video uygulamaları; pbr renderer (NexGFX) | Lua, JavaScript, Python, C |

SDK 1.0'dan 1.6'ya kadarki sürümlerin hepsi, ilk herkese açık sürüm olan ve SDK 1.6'ya sahip Nexvyn OS 1.0.0'ın
geliştirilmesi sırasında yapıldı. Sonradan gelen bir dil, önceki SDK'nın tamamını beraberinde aldı: Squirrel, C ve Java,
1.0'dan 1.4'e kadar her şeyle SDK 1.5'te başladı.

## 3. Sürüm sürüm

### SDK 1.0 (Nexvyn OS 1.0.0)

- Lua runtime'ı ve sonraki her dilin paylaştığı modüller: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`,
  `input`, `timer`, `TR`, `g3d`.

### SDK 1.1 (Nexvyn OS 1.0.0)

- Aynı modüllerle JavaScript runtime'ı (QuickJS-ng, ES modülleri); callback verilmeyen asenkron çağrılar Promise
  döndürür.
- GPU'da `g3d` dokuları.

### SDK 1.2 (Nexvyn OS 1.0.0)

- Lua için `nexvyn.game` 2D motoru (`require("nexvyn.game")`): sahneler, sprite'lar, tilemap'ler, fizik, parçacıklar,
  tween'ler.
- `sys.sdkVersion()`; app.json `minSdk` ve `permissions`; `manifest.sha256` içeren tek dosyalık `.nxvapp` v2.

### SDK 1.3 (Nexvyn OS 1.0.0)

- Aynı modüllerle Python runtime'ı (pocketpy); asenkron çağrılar callback alır.

### SDK 1.4 (Nexvyn OS 1.0.0)

- Her izin zorunlu (`network`, `files`, `launch`, `notifications`); kullanıcının cevabı uygulama başına saklanır.
- `sys.share` ve app.json `shareTargets`; `sys.schedule` / `unschedule` / `scheduled`; `sys.hasPermission` /
  `requestPermission`; `sys.memory`; `sys.appUrl` ve `sys.open`'da `nxv://` bağlantıları.
- `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved` callback'leri.
- İmzalı paketler; Lua uygulamaları için de 64 MB script belleği sınırı.

### SDK 1.5 (Nexvyn OS 1.0.0)

- Tek ortak uygulama üzerinde üç runtime daha: Squirrel 3.2 (`"squirrel"`), konsolda TinyCC ile derlenen C (`"c"`,
  `nexvyn.h`) ve miniJVM üzerinde Java (`"java"`, `"mainClass"`).
- Fonksiyon olarak `g3d.setColor` / `flat` / `triangles` / `setTexture` / `texture` / `free`.
- Python sistem kütüphanesi: `itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`.

### SDK 1.6 (Nexvyn OS 1.0.0)

- Lua, JavaScript, Python ve Squirrel'de `fs.unzip` (arka planda, ilerlemeyle) ve yeni `"games"` izniyle `sys.games`.
- Her runtime'da `sys.speak` / `sys.stopSpeaking` (metin okuma, izin gerekmez).
- `"python3"` runtime'ı: standart kütüphanesiyle CPython 3.12.

### SDK 1.7 (Nexvyn OS 1.1.0)

- JavaScript'te `g3d.voxels` voksel dünyalar: chunk akışı, arazi üreticisi, ışık, arka plan thread'lerinde kurulan
  mesh'ler, kaydetme, ray cast'ler ve kutu fiziği.
- Lua ve JavaScript'te `mesh:setTexture(path, pixelated)`: yumuşatmadan büyütülen dokular.

### SDK 1.8 (Nexvyn OS 1.2.0)

- `g3d.model` ve `g3d.loadModel` (arka planda parse edilir): düğüm hiyerarşisi, materyaller, gömülü ve dış dokular ve
  iskelet animasyonuyla (crossfade ile oynatma, durdurma, ek parçalar için düğüm konumları ve matrisleri) `.glb`,
  `.gltf`, `.fbx` (ve `.obj`, `.stl`); `g3d.drawMatrix`; GPU'da skinning. Her runtime'da (Squirrel, C, Java ve
  `"python3"` için `g3d.model*` fonksiyonlarıyla).
- Süre sınırları: ana dosya ve `app.load` 10 saniye, diğer callback'ler 3 saniye alır; HOME menüsünde, uykuda ya da bir
  sistem diyaloğunda geçen süre sayılmaz. Durdurulan callback, SDK 1.8 ya da daha yenisini hedefleyen bir uygulamayı
  hata ekranıyla bitirir; daha eski bir uygulama bekletilir ve kullanıcı **Bekle** ya da **Kapat**'ı seçer.
- SDK 1.8'i hedefleyen C uygulamaları için: `#include` yalnızca uygulamanın kendi dosyalarını ve SDK başlıklarını okur,
  inline assembly reddedilir.

### SDK 1.9 (Nexvyn OS 1.2.2)

- **Runtime kütüphanesi:** Lua'da `net.request{url, method, body, contentType, headers}`; JavaScript'te `TextEncoder` /
  `TextDecoder`, `URL` / `URLSearchParams`, `structuredClone`; pocketpy'de eksik olan Python `str` metotları,
  `dict.setdefault` / `fromkeys`, `pow()` ve sistem modülleri `urllib.parse`, `html`, `uuid`.
- **Akış, fotoğraf ve kısa video uygulamaları** (başvuru bölüm 8d): `net.request` seçenekleri (JSON, form, multipart ve
  dosya gövdeleri, `saveTo`, yükleme ilerlemesi, çerezler, yeniden deneme, çevrimdışı cache), `net.cancel`,
  `net.clearCookies`, `net.clearCache`; WebSocket istemcisi (`net.ws`, `wsSend`, `wsPoll`, `wsClose`, `wsState`);
  `net.oauth`; `gfx.imageUrl` / `imageState`; `media.*` oynatıcıları; `ui.beginFeed` / `feedItem` / `endFeed`,
  `ui.pager`, `ui.richText` / `measureRichText`; `sys.relativeTime`.
- **pbr renderer**, NexGFX 1.0, uygulama başına `g3d.renderer("pbr")` ile isteğe bağlı: normal, occlusion ve emissive
  map'li metallic-roughness materyaller (model dosyalarından ya da `g3d.material` ile), gerçek zamanlı ışıklar
  (`g3d.addLight` / `updateLight` / `removeLight` / `clearLights` / `lights`), güneş ve spot gölgeleri (`g3d.shadows`),
  tone mapping'li HDR, bloom ve MSAA (`g3d.postfx`), yarım küre ya da cube map ambient (`g3d.environment`),
  `g3d.drawInstanced`, `g3d.caps`, `g3d.rendererInfo`. Onu hiç istemeyen bir uygulama SDK 1.8'deki gibi çizilir.
- Lua, JavaScript, Python (`"python"` ve `"python3"`) ve C. Rehberler: [PBR_GAME_RECIPE.tr.md](PBR_GAME_RECIPE.tr.md),
  [SOCIAL_APP_RECIPE.tr.md](SOCIAL_APP_RECIPE.tr.md), [MAKE_A_SOCIAL_APP.tr.md](MAKE_A_SOCIAL_APP.tr.md).

## 4. minSdk ve targetSdk

```json
{
  "minSdk": "1.9",
  "targetSdk": "1.9"
}
```

- **`minSdk`**, uygulamanın çalıştığı en eski SDK'dır: kullandığı en yeni SDK özelliği. Daha eski SDK'lı bir sistem onu
  kurmaz, App Market *Bu uygulama Nexvyn OS'un daha yeni bir sürümünü gerektiriyor* der ve onu hiçbir zaman güncelleme
  olarak sunmaz; SD kartta zaten duran bir kopya çalışmak yerine bunu söyleyen bir pencere açar (Yazılım Güncelleme
  düğmesiyle).
- **`targetSdk`**, uygulamayı üzerinde yapıp denediğiniz SDK'dır. Sonraki sistemler uygulamanız için o SDK nasıl
  davrandıysa öyle davranmaya devam eder. Varsayılan: `minSdk`, ikisi de yoksa `"1.0"`; `minSdk`'nın altındaki bir
  `targetSdk`, `minSdk` sayılır. Studio yeni projelerde ikisine de güncel SDK'yı yazar.
- **`targetSdk`'yı yükseltmek bir seçimdir.** Başvurudaki "SDK x'i hedefleyen uygulamalar için" notlarını okuyun, yeni
  sistemde deneyin, sonra yükseltin. Şimdiye kadarki örnek SDK 1.8'in süre sınırıdır: `targetSdk` 1.8 ya da daha
  yeniyse takılan bir callback uygulamayı hata ekranıyla bitirir; daha eskiyse kullanıcıya *Bekle* ya da *Kapat* sorulur.
- `runtimeVersion` (isteğe bağlı), denediğiniz motor sürümünü kaydeder; örneğin pocketpy için `"2.2"`.
- Bilinmeyen app.json alanları ve bilinmeyen izinler yok sayılır; yani daha yeni bir sistem için yazılmış bir manifest
  eski bir sistemi hiçbir zaman bozmaz.

## 5. Hiçbir şey silinmez, yalnızca deprecated olur

Başvurudaki her fonksiyon sonraki her Nexvyn OS'ta çalışmaya devam eder. Yerine yenisi gelen bir fonksiyon
*deprecated* olur: tam eskisi gibi çalışır ve bir çalıştırmadaki ilk çağrı uygulamanın log'una
`deprecated: <name> still works; use <replacement>` yazar (Studio'nun konsolu gösterir). Bugün deprecated olanlar:

| Eski | Yerine | Ne olur |
|---|---|---|
| `require("snx.*")` (Lua) | `require("nexvyn.*")` | aynı modülü yükler; uygulama log'unda bir not |
| `"clipboard"` izni | hiçbir şey: `sys.clipboard` izin istemez | kabul edilir ve yok sayılır |
| `finder`, `launchpad` uygulama id'leri | `files`, `launcher` | `sys.launch`, `nxv://` bağlantıları ve kısayollar onları çözer |

Uygulamalar kullandığı sürece runtime'lar da silinmez; yeni bir motor sürümü yayınlanmadan önce App Market'teki her
uygulamayı, oyunu ve örneği değişmeden çalıştırmalıdır.

## 6. Hangi diller yeni API alır

SDK 1.9'dan itibaren yeni fonksiyonlar dördünde de aynı adlarla **Lua, JavaScript, Python** (`"python"` ve `"python3"`)
**ve C**'ye gelir. **Squirrel ve Java SDK 1.8'de donduruldu**: SDK 1.8'in `g3d.model` fonksiyonları dahil sahip
oldukları her şey sonraki her Nexvyn OS'ta çalışmaya devam eder ve App Market'teki uygulamaları değişiklik gerektirmez,
ama onlara yeni bir şey eklenmez. 1.8'in üstündeki bir `minSdk` ya da `targetSdk` bu iki dile yeni bir şey getirmez.
Dondurulmuş, silinmiş demek değildir: bu runtime'lardaki hata ve güvenlik düzeltmeleri yine yayınlanır.

Yeni uygulamalara Lua, JavaScript, Python ya da C ile başlayın.

## 7. Uygulamanız için minSdk seçmek

`minSdk`'yı, özelliğini kullandığınız en yüksek satıra ayarlayın (ve en az dilinizin satırına):

| Kullandığınız | minSdk |
|---|---|
| Lua ve temel modüller | 1.0 (ya da hiç yazmayın) |
| JavaScript | 1.1 |
| `nexvyn.game`, app.json'da `permissions` | 1.2 |
| Python (`"python"`) | 1.3 |
| paylaşım, zamanlanmış bildirimler, `nxv://` bağlantıları, `app.suspend` / `resume` / `autosave` ve diğer yaşam döngüsü callback'leri | 1.4 |
| C | 1.5 |
| `fs.unzip`, `sys.games`, `sys.speak`, `"python3"` runtime'ı | 1.6 |
| `g3d.voxels`, pixel art dokular | 1.7 |
| `g3d.model`, `g3d.loadModel`, `g3d.drawMatrix` | 1.8 |
| `g3d.renderer("pbr")` ve *Modern görüntü*'nün geri kalanı, `net.request` seçenekleri, `net.ws`, `net.oauth`, `gfx.imageUrl`, `media.*`, `ui.beginFeed` / `ui.pager` / `ui.richText`, `sys.relativeTime` | 1.9 |

Daha yeni bir şeyi yalnızca var olduğu yerde kullanmak için çalışma anında denetleyin ve bir fallback tutun:

```lua
local app = {}

local function sdkAtLeast(major, minor)
  local v = sys.sdkVersion and sys.sdkVersion() or "1.0"   -- sys.sdkVersion arrived in SDK 1.2
  local a, b = v:match("^(%d+)%.(%d+)")
  a, b = tonumber(a) or 1, tonumber(b) or 0
  return a > major or (a == major and b >= minor)
end

function app.load()
  if sdkAtLeast(1, 9) then g3d.renderer("pbr") end   -- older systems keep the basic renderer
end

return app
```

Fonksiyonun kendisini denetlemek de olur (`if g3d.renderer then ... end`). Sürümleri metin olarak değil sayı olarak
karşılaştırın: `"1.10"`, `"1.9"`'dan yenidir.

## Ayrıca bakın

[SDK başvurusu](../Reference/SDK.tr.md) · [Uyumluluk](COMPATIBILITY.tr.md) · [Geliştirici rehberi](DEVELOPER_GUIDE.tr.md) ·
[AI destekli iş akışı](AI_WORKFLOW.tr.md)
