# SDK sürümleri

[English](SDK_VERSIONS.en.md) · **Türkçe**

Her Nexvyn OS sürümü bir SDK sürümü sağlar: `.nxvapp` uygulamalarının üstüne kurulduğu API. `sys.sdkVersion()` onu
döndürür, **Sistem Ayarları > Hakkında** gösterir. Uygulama ihtiyaç duyduğu en eski SDK'yı `"minSdk"`, test edildiği
SDK'yı `"targetSdk"` ile `app.json`'da yazar.

## Söz

- **Hiçbir şey kaldırılmaz.** Her fonksiyon sonraki her Nexvyn OS'ta çalışmaya devam eder. Yerine yenisi gelen
  fonksiyon deprecated olarak işaretlenir: yine çalışır ve uygulamanın günlüğüne bir not yazar.
- **Davranış değişikliği isteğe bağlıdır.** Var olan bir fonksiyonun davranışı değişirse yeni davranışı yalnızca
  `targetSdk`'sı o sürüm ya da daha yenisi olan uygulamalar alır.
- **Eski sistemde yeni uygulama.** `minSdk`'sı sistemin SDK'sından yeni olan uygulama kurulmaz ve daha yeni bir
  Nexvyn OS gerektirdiği gösterilir.
- **Her sürüm denetlenir:** yayından önce App Market'teki her uygulama, oyun ve örnekle.

Sözleşmenin tamamı: [Uyumluluk](COMPATIBILITY.tr.md).

## Geçmiş

| SDK | İlk Nexvyn OS | Ekledikleri |
|---|---|---|
| **1.9** | **1.3.0** | **NexGFX pbr renderer** (`g3d.renderer("pbr")` ile uygulama başına isteğe bağlı): glTF ve FBX'ten normal, occlusion ve emissive haritalı metallic-roughness materyaller, `g3d.material`, gerçek zamanlı nokta, spot ve yönlü ışıklar (`g3d.addLight` ve diğerleri), güneş ve spot gölgeleri, HDR, ACES / filmic ton eşleme, bloom, MSAA, cube map yansımaları, ince cam (transmission), clearcoat, `g3d.drawInstanced`, `g3d.caps`, `g3d.rendererInfo`. **Akış, medya ve ağ:** `net.request` seçenekleri (JSON, form, multipart ve dosya gövdesi, `saveTo`, yükleme ilerlemesi, çerezler, yeniden deneme, çevrimdışı önbellek), `net.cancel` / `clearCookies` / `clearCache`, WebSocket istemcisi (`net.ws`), konsolun tarayıcısında oturum açma (`net.oauth`), disk önbellekli web resimleri (`gfx.imageUrl`), gömülü video ve ses oynatıcıları (`media.*`), sanal akış ve ızgaralar (`ui.beginFeed`), kaydırmalı sayfalayıcı (`ui.pager`), zengin metin (`ui.richText`), `sys.relativeTime`. **Runtime kütüphanesi:** Lua'da `net.request`; JavaScript'te `TextEncoder` / `TextDecoder`, `URL`, `URLSearchParams`, `structuredClone`; Python'da daha fazla `str` metodu, `dict.setdefault` / `fromkeys`, `pow()`, `urllib.parse`, `html`, `uuid`. Yalnızca Lua, JavaScript, Python ve C |
| 1.8 | 1.2.0 | 3B model dosyaları: `.glb`, `.gltf`, `.fbx` (ve `.obj`, `.stl`) için düğüm hiyerarşisi, materyaller, dokular ve iskelet animasyonuyla (oynat, geçiş, durdur, düğüm konumları ve matrisleri) `g3d.model` / `g3d.loadModel`, `g3d.drawMatrix`, GPU skinning. Fazla süren bir callback, 1.8'i hedefleyen uygulamayı hata ekranıyla bitirir; eski uygulamalar bekletilir ve kullanıcı Bekle ya da Kapat'ı seçer |
| 1.7 | 1.1.0 | JavaScript'te `g3d.voxels` voxel dünyaları (chunk'lar, arazi üretici, ışık, ışın, kutu fiziği, kaydetme); `mesh:setTexture(path, pixelated)` |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games` ve `"games"` izni, `sys.speak`, `"python3"` runtime'ı (CPython 3.12) |
| 1.5 | 1.0.0 | Squirrel, C (konsolda derlenen) ve Java runtime'ları; Python sistem kütüphanesi |
| 1.4 | 1.0.0 | Her izin zorunlu; paylaşım, zamanlanmış bildirimler, izin API'si, `nxv://` bağlantıları, yaşam döngüsü callback'leri (`suspend`, `resume`, `focus`, `autosave`, `unsaved`), uygulamalar için Hızlı Arama, imzalı paketler |
| 1.3 | 1.0.0 | Python runtime'ı (pocketpy) |
| 1.2 | 1.0.0 | 2B oyun motoru `nexvyn.game`, `sys.sdkVersion()`, `app.json`'da `minSdk` ve `permissions` |
| 1.1 | 1.0.0 | Promise'li JavaScript runtime'ı; GPU'da `g3d` dokuları |
| 1.0 | 1.0.0 | Lua runtime'ı: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |

SDK 1.0 ile 1.6 arası, ilk herkese açık sürüm olan Nexvyn OS 1.0.0'ın geliştirilmesi sırasında yapıldı; 1.0.0 hepsini
içerir. Fonksiyon listelerinin tamamı [SDK başvurusunda](../Reference/SDK.tr.md), bölüm 1, *SDK sürümleri*.

## Diller

| Dil | Başlangıç | Yeni API |
|---|---|---|
| Lua 5.4 | 1.0 | evet |
| JavaScript (ES2023) | 1.1 | evet |
| Python (`"python"`, hafif) | 1.3 | evet |
| Python (`"python3"`, CPython 3.12) | 1.6 | evet |
| C (`nexvyn.h`) | 1.5 | evet |
| Squirrel | 1.5 | 1.8'de donduruldu: uygulamaları çalışır, yeni fonksiyon gelmez |
| Java | 1.5 | 1.8'de donduruldu: uygulamaları çalışır, yeni fonksiyon gelmez |

Yeni SDK fonksiyonları Lua, JavaScript, Python ve C'de aynı adı taşır. Yeni uygulamalara bu dördünden biriyle başlayın.

## `minSdk` ve `targetSdk` seçimi

- `minSdk`: uygulamanın çağırdığı her fonksiyonu içeren en düşük sürüm. `g3d.model` kullanan bir Lua uygulaması
  `"1.8"`, `g3d.renderer` ya da `ui.beginFeed` çağıran bir uygulama `"1.9"` ister.
- `targetSdk`: test ettiğiniz en yeni sürüm. Yeni uygulamalar `"1.9"` yazar.
- Hangi fonksiyonun ne zaman geldiğinden emin değil misiniz? Başvuruda fonksiyonu arayın: her bölüm SDK sürümünü
  söyler.
