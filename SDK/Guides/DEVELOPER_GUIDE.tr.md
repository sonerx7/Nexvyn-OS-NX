# Nexvyn OS geliştirici rehberi

**Türkçe** · [English](DEVELOPER_GUIDE.en.md)

Bu rehber, Nexvyn OS için uygulama yazmak isteyenleri sıfırdan yayımlanmış bir uygulamaya kadar götürür. Ayrıntılı API
burada tekrar edilmez; her bölüm ilgili başvuru belgesine bağlantı verir.

| Belge | İçerik |
|---|---|
| [sdk/SDK.tr.md](../Reference/SDK.tr.md) | Tam API başvurusu (İngilizce): `gfx`, `ui`, `fs`, `net`, `sys`, `audio`, `g3d`, `nexvyn.game`, JavaScript farkları |
| [docs/JS_APPS.tr.md](JS_APPS.tr.md) | JavaScript ile uygulama (Türkçe kısa rehber) |
| [docs/PY_APPS.tr.md](PY_APPS.tr.md) | Python ile uygulama (Türkçe kısa rehber) |
| [docs/GAME_ENGINE.tr.md](GAME_ENGINE.tr.md) | `nexvyn.game` 2D oyun motoru, adım adım |
| [docs/NXVAPP_FORMAT.tr.md](NXVAPP_FORMAT.tr.md) | `.nxvapp` v2 paket biçimi, izinler, depo, Overlay |
| [docs/LUA_CAPABILITIES.tr.md](LUA_CAPABILITIES.tr.md) | Lua ile neler yapılabilir, sınırlar |
| [docs/APP_GUIDE.tr.md](APP_GUIDE.tr.md) | Yerleşik (C++) uygulama rehberi (İngilizce) |

Kullanıcı tarafı için: [USER_GUIDE.tr.md](USER_GUIDE.tr.md).

## İçindekiler

1. [Nexvyn OS Studio ve şablonlar](#1-nexvyn-os-studio-ve-şablonlar)
2. [app.json](#2-appjson)
3. [Dil seçimi: Lua, JavaScript, Python](#3-dil-seçimi-lua-javascript-python)
4. [nexvyn.game ile 2D oyun](#4-nexvyngame-ile-2d-oyun)
5. [g3d ile 3D](#5-g3d-ile-3d)
6. [Paketleme: .nxvapp v2](#6-paketleme-nxvapp-v2)
7. [Topluluk kataloğu](#7-topluluk-kataloğu)
8. [Overlay: sistem dosyalarını değiştirmek](#8-overlay-sistem-dosyalarını-değiştirmek)
9. [Ryujinx'te test](#9-ryujinxte-test)
10. [Yerleşik (native) uygulama geliştirme](#10-yerleşik-native-uygulama-geliştirme)
11. [English summary](#english-summary)

---

## 1. Nexvyn OS Studio ve şablonlar

En kısa yol konsolun içindeki **Nexvyn OS Studio** uygulamasıdır. Bilgisayar gerekmez.

1. Studio'yu açın ve **Yeni Proje**'yi seçin. Şablon galerisi açılır.
2. Bir şablon seçin, uygulamaya ad verin. Her şablon olduğu gibi çalışır ve kodu açıklamalıdır.
3. Kodu düzenleyin. Studio yazarken hataları gösterir ve otomatik tamamlama sunar.
4. **Çalıştır** ile uygulamayı açın. `print()` çıktısı ve hatalar Studio'nun konsolunda görünür.
5. Hazır olunca **Paketi Dışa Aktar**. Paket Belgeler klasörüne (`~/Documents/<ad>.nxvapp`) yazılır.

| Şablon | Dil | Ne gösterir |
|---|---|---|
| Boş Lua uygulaması | Lua | En küçük uygulama; tüm geri çağrılar açıklamalı |
| Boş JS uygulaması | JS | Aynı başlangıç: geri çağrılar, `store` ve bir Promise |
| Araç uygulaması | Lua | Liste, ayrıntı ve ayarlar sayfaları; veriler `store` ile kaydedilir |
| Platform oyunu | Lua | `nexvyn.game`: tilemap bölüm, koşup zıplayan kahraman, altınlar, düşmanlar |
| Arena / uzay nişancı | Lua | `nexvyn.game`: düşman dalgaları, nişan alma, parçacıklar; sahne editörüyle yerleştirilmiş kayalar |
| Bulmaca / ızgara oyunu | Lua | `nexvyn.game`: kaydırmalı karo bulmacası; tween, dokunmatik, kumanda, klavye |
| 3B sahne | Lua | GPU'da `g3d`: ışıklı modeller, yörünge kamerası, sis, etiketler |
| Ağ uygulaması | JS | `await net.fetchJson` ile hava durumu, hata yönetimiyle |
| Boş Python uygulaması | Python | Aynı başlangıç Python ile: geri çağrılı bir sınıf, `store` ve menü |
| Yılan (Python) | Python | Python ile tam küçük oyun: ızgara, zamanlayıcı, kumanda, klavye, kaydırma, en yüksek skor |

Şablonlar `romfs/System/Templates/` içindedir. Python şablonları galeride yeşil bir Python rozetiyle görünür ve
`minSdk` olarak `1.3` yazar. Studio `.py` dosyalarını Python renklendirmesiyle açar.

Studio'nun diğer araçları:

- **Sprite, tilemap ve sahne editörleri** sekme olarak açılır. Sprite editörü kare boyutu ve animasyon önizlemesi
  sunar. Tilemap editörü karo bayraklarını (katı, tek yönlü) düzenler. Sahneler `game.loadScene` ile yüklenir.
- **Yapay zekâya sor** paneli, AI Sohbet'teki API anahtarlarıyla soruları yanıtlar. Dosyaları kendisi değiştirmez;
  önerilen kodu siz eklersiniz.

Bilgisayarda çalışmayı tercih ederseniz bir `Adı.nxvapp/` klasörü oluşturup herhangi bir editörle yazın ve klasörü
`sdmc:/NexvynOS/Applications/` içine kopyalayın. Uygulama Uygulamalar ekranında ve Arama'da görünür.

---

## 2. app.json

Her uygulamanın kökünde bir `app.json` bulunur. En önemli alanlar:

```json
{
  "id": "com.adiniz.uygulama",
  "name": {"en": "My App", "tr": "Uygulamam"},
  "description": {"en": "What it does", "tr": "Ne yaptığı"},
  "version": "1.0",
  "author": "Adınız",
  "homepage": "https://github.com/kullaniciadiniz",
  "category": "utilities",
  "main": "main.lua",
  "window": {"width": 640, "height": 480, "minWidth": 320, "minHeight": 240, "resizable": true},
  "gamepad": false,
  "fileTypes": [".txt"],
  "minSdk": "1.2",
  "permissions": ["network"]
}
```

| Alan | Açıklama |
|---|---|
| `id` | Benzersiz kimlik, ters alan adı biçiminde. Güncellemeler bu kimlikle eşleşir. |
| `author`, `homepage` | Geliştirici adı ve isteğe bağlı web/GitHub adresi. Uygulamanın Hakkında penceresinde ve mağazada görünür. |
| `main` | Giriş dosyası. `.js`/`.mjs` JavaScript'i, `.py` Python'u seçer; varsayılan `main.lua`. |
| `runtime` | `main` uzantısı yerine çalışma ortamını açıkça seçmek için (`"js"`, `"python"`). |
| `window` | **İçerik** boyutu; başlık çubuğunu sistem ekler. |
| `gamepad` | `true` ise pencere odaktayken kumanda uygulamaya gider (oyunlar). Kullanıcı L+R'yi bir saniye basılı tutarak imleci geri alır. |
| `fileTypes` | Açabildiği uzantılar. Uygulama "Birlikte Aç" listesinde görünür ve dosya yolunu `load(arg)` ile alır. |
| `minSdk` | Uygulamanın gerektirdiği en eski SDK sürümü. Daha eski bir Nexvyn OS uygulamayı kurmaz ve güncelleme ister. |
| `permissions` | Uygulamanın kendi klasörleri dışında neye ihtiyacı olduğu (aşağıya bakın). |

**SDK sürümleri:** `sys.sdkVersion()` sistemin sürümünü döndürür.

| SDK | Getirdiği |
|---|---|
| 1.0 | Lua çalışma ortamı ve temel modüller, `g3d` |
| 1.1 | JavaScript çalışma ortamı; `g3d` dokuları GPU'da |
| 1.2 | `nexvyn.game`, `sys.sdkVersion()`, `minSdk` ve `permissions`, tek dosyalı `.nxvapp` v2 |
| 1.3 | Python çalışma ortamı (bkz. [PY_APPS.tr.md](PY_APPS.tr.md)) |

Kullandığınız en yeni özelliğin sürümünü `minSdk`'ye yazın.

**İzinler:** `network`, `files`, `launch`, `notifications`. SD karta kurulan uygulamalarda dördü de zorunlu tutulur.
Kullanıcı uygulama başına bir kez karar verir: yükleme sayfası izinleri listeler, "Yükle" demek onları vermektir
(*Özelleştir* ile bazıları kapatılabilir); yükleme sayfası görmeden gelen uygulamaya ilk açılışta bir kez sorulur.
Reddedilen ya da bildirilmeyen izinde `net.*` çağrıları `permission denied` hatası verir, dosya çağrıları başarısız
olur; çağrı anında soru çıkmaz. Kullanıcının dosya seçicide seçtiği ya da uygulamayı onunla açtığı dosyalara her zaman
izin vardır. `sys.clipboard` izin istemez (eski `"clipboard"` girdisi yok sayılır). Gerekmeyen izni istemeyin.

Tam alan listesi: [SDK.tr.md bölüm 1](../Reference/SDK.tr.md#1-bundle-yapısı) ve [NXVAPP_FORMAT.tr.md bölüm 2–3](NXVAPP_FORMAT.tr.md#2-appjson).

---

## 3. Dil seçimi: Lua, JavaScript, Python

Üç dil de aynı SDK'yı kullanır: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`,
`TR`, `g3d`. Fark sözdizimindedir.

| | Lua | JavaScript | Python |
|---|---|---|---|
| Sürüm / motor | Lua 5.4 | QuickJS-ng (ES2023) | pocketpy |
| Giriş dosyası | `main.lua` | `main.js` / `.mjs` | `main.py` |
| En az SDK | 1.0 | 1.1 | 1.3 |
| Asenkron çağrılar | Geri çağırma | Geri çağırma ya da Promise (`await`) | Geri çağırma (`async`/`await` yok) |
| Modüller | `require("ad")` (paket, sonra sistem kütüphanesi) | `import` (yalnızca paket içi) | `import` (yalnızca paket içi) |
| `nexvyn.game` | Var | Yok (Lua modülüdür) | Yok |
| Ayrıntı | [SDK.tr.md](../Reference/SDK.tr.md) | [JS_APPS.tr.md](JS_APPS.tr.md), SDK.tr.md bölüm 11 | [PY_APPS.tr.md](PY_APPS.tr.md) |
| Örnek | `hello.nxvapp` | `hellojs.nxvapp` | `hellopy.nxvapp` |

Ortak kurallar:

- Program bir geri çağrı tablosudur: `load`, `open`, `update(dt)`, `draw(w, h)`, `event(e)`, `menu`, `onmenu`,
  `close`. Hepsi isteğe bağlıdır.
- `draw` her karede çağrılır; arayüz bileşenleri (immediate mode) burada çizilir ve tıklamayı aynı çağrıda döndürür.
- 3 saniyeden uzun süren bir geri çağrı durdurulur. Hata olursa pencerede satır numaralı bir hata ekranı ve **Yeniden
  Yükle** düğmesi çıkar; çıktı `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.
- Lua'da `io`, `debug`, `package`, `dofile`, `loadfile` yoktur; dosyalar için `fs` kullanılır. JavaScript'te tarayıcı ya
  da Node.js API'si yoktur (`window`, `fetch`, `require`…); her pencerenin 64 MB bellek sınırı vardır.
- Çeviriler `lang/en.json` ve `lang/tr.json` içinde durur; `TR("anahtar")` ile okunur.
- İki parmak hareketleri `event` ile `"pinch"` ve `"rotate"` olarak gelir (üç dilde de). `e.touch` doğrudur,
  `e.x, e.y` parmakların ortasıdır. `"pinch"`: `e.scale`, bir önceki olaydan bu yana parmak aralığındaki değişimdir
  (> 1 açılıyor); yakınlaştırmayı bununla çarpın. `"rotate"`: `e.angle`, açıdaki değişimdir (radyan, pozitif = saat
  yönü). İkisi de parmaklar biraz hareket edince başlar; düz iki parmak sürükleme `"scroll"` olarak kalır ve hareket
  sırasında `"scroll"` gelmeye devam eder, böylece kaydırma ve yakınlaştırma birlikte yapılabilir. Ayrıntı:
  [SDK.tr.md](../Reference/SDK.tr.md), `pinch` / `rotate`.

```lua
function app.event(e)
  if e.type == "pinch" then zoom = math.max(0.25, math.min(8, zoom * e.scale))
  elseif e.type == "rotate" then angle = angle + e.angle end
end
```

**Hangisini seçmeli?** `nexvyn.game` ile oyun yazacaksanız Lua. Web geliştirmeye alışkınsanız ya da `async/await` ile ağ
kodu yazacaksanız JavaScript. Python desteği eklendi (SDK 1.3); örnek ve farklar [PY_APPS.tr.md](PY_APPS.tr.md) içinde.

Python çalışma ortamı en yeni eklentidir. Gerçek konsoldaki davranışını kendi testlerinizle de doğrulayın.

---

## 4. nexvyn.game ile 2D oyun

`nexvyn.game`, Lua uygulamaları için küçük bir 2D oyun motorudur. Sistemle birlikte `romfs:/System/Lua/nexvyn/` içinde
gelir; bir satırla kullanılır:

```lua
local game = require("nexvyn.game")
```

Sabit adımlı oyun döngüsü, geçişli sahneler, sprite ve animasyon, tilemap (Lua/ASCII/JSON/Tiled), kamera, arcade
fiziği ve çarpışma, girdi eylemleri ve dokunmatik kontroller, tween, parçacıklar, sentez ses, duraklatma menülü arayüz,
kayıt ve hata ayıklama katmanı içerir.

- Adım adım rehber: [GAME_ENGINE.tr.md](GAME_ENGINE.tr.md).
- Fonksiyon listesi: [SDK.tr.md bölüm 8c](../Reference/SDK.tr.md#8c-2d-oyun-motoru-nexvyngame).
- Örnek oyunlar: **Pixel Koşu** (`romfs/Applications/pixelrun.nxvapp`) ve **Uzay Arenası**
  (`romfs/Applications/spacearena.nxvapp`).
- Bilinen sınırlar: tek dokunma noktası, eğimli karo yok, kamera döndürme yok (ayrıntı GAME_ENGINE.tr.md bölüm 16).

`app.json` içinde `"gamepad": true` ve `"minSdk": "1.2"` yazmayı unutmayın.

### Oyun Motoru projeleri

**Oyun Motoru** (`gamemaker`) aynı motorun üstünde çalışan, kod yazmadan oyun yapan bir uygulamadır. Projeler
`~/Documents/Oyunlarım/<ad>/project.json` dosyasıdır (`"format": "nexvyn-workshop"`): ayarlar, değişkenler, olay kuralları
(`on` / `if` / `do`), bölümler (2D'de karo dizgeleri ve nesneler, 3D'de zemin ve nesneler), kendi çizimler, modeller,
sesler ve katmanlar.

- Proje kod üretilerek değil, JSON yorumlanarak oynatılır: `nexvyn.workshop` (2D, `nexvyn.game` üstünde) ve
  `nexvyn.workshop3d` (3D, `g3d` üstünde). Olay blokları betiklerin de kullandığı `ws.on(...)` API'sine derlenir; nesne
  betikleri `start()`, `update(dt)`, `touch(other)` tanımlayabilir.
- **Dışa aktar** bağımsız bir `.nxvapp` yazar: `main.lua`, `project.json`, varlıklar, çalışma zamanının ve kütüphanenin
  bir kopyası. Paketteki kopya sistemdekinden önce yüklenir.
- Kütüphanedeki bütün resim, ses ve modeller `tools/gen_workshop.py` ile üretilir (her çalıştırmada aynı çıktı).
  Oyun sihirbazının türleri ve temaları da `library.json` içindedir (`genres`, `themes`). Şablon ve örnekleri, ayrıca
  her türü her temayla denetlemek için: `python tools/lua_check.py --workshop`.
- Betikler için yeni API: `ws.on("var", ad, n, fn)` (değişken n'ye ulaşınca) ve `ws.hurt([n])`. Hata yapan bir betik
  oyunu durdurmaz; ilk hata kırmızı bir notta gösterilir ve o fonksiyon kapanır.

Proje biçimi, davranışlar, olaylar ve API'nin tamamı: [GAME_ENGINE_PROJECTS.tr.md](GAME_ENGINE_PROJECTS.tr.md).

---

## 5. g3d ile 3D

`g3d` küçük bir gerçek zamanlı 3D çizicidir. GPU'da çalışır: derinlik tamponu, piksel başına ışık, sis ve dokular.
Kareye 30–60 bin üçgen hedeflenir. GPU yolu kullanılamazsa (ya da sistem ayarı `g3d.gpu` `false` ise) aynı çağrılar
eski CPU çiziciye düşer: dokusuz, birkaç bin üçgen. Hangisinin etkin olduğunu `g3d.gpu()` söyler.

```lua
local cube
function app.load() cube = g3d.mesh("cube", 1) end
function app.draw(w, h)
  gfx.clear("#101418")
  g3d.begin(0, 0, w, h, 60)
  g3d.camera(0, 2, 5, 0, 0, 0)
  g3d.light(0.5, 1, 0.3, 0.35)
  g3d.draw(cube, 0, 0, 0, sys.time(), 0, 0)
  g3d.finish()
end
```

Modelleri `load` içinde bir kez oluşturun ve her karede yeniden kullanın. OBJ (ve `mtl` içindeki `map_Kd` dokuları)
yüklenebilir.

**Parlama (glow):** `g3d.draw` bayraklarına `"glow"` eklenince modelin rengi arkasındakinin üstüne eklenir (eklemeli
karışım); üst üste binen parçalar daha parlak görünür: yıldızlar, kıvılcımlar, ışık izleri, lamba haleleri. Glow
modelleri en son çizilir, önlerindeki katı geometrinin arkasında kalır ama hiçbir şeyi örtmez; sis onları da soldurur.
Soluk ışık için koyu renkler kullanın ve `"unlit nocull"` ile birleştirin. Lua, JavaScript ve Python'da aynıdır. CPU
yedek yolu glow modellerini normal model gibi çizer.

```lua
g3d.draw(spark, x, y, z, 0, 0, 0, 0.3, 0.3, 0.3, theme.orange, "unlit nocull glow")
```

Yerleşik (C++) uygulamalar için ayrıca `g3d::append(dst, src, matrix, color)` (bir modelin dönüştürülmüş kopyasını
başka bir modele ekler: yüzlerce nesne, tek çizim çağrısı), `DrawOpts::additive` (`"glow"` bayrağının karşılığı) ve
`g3d::lastTriangles()` yanında `g3d::lastDrawCalls()` vardır. Örnek kullanım: Gösteri uygulaması
(`source/apps/techdemo_scenes.cpp`).

Tam başvuru: [SDK.tr.md bölüm 8b](../Reference/SDK.tr.md#8b-3b--g3d). Neler yapılabileceğine dair örnekler:
[LUA_CAPABILITIES.tr.md](LUA_CAPABILITIES.tr.md). Şablon: Studio'daki "3B sahne".

---

## 6. Paketleme: .nxvapp v2

Bir uygulama iki biçimde dağıtılır:

- **Klasör:** `Adı.nxvapp/` (geliştirme sırasında).
- **Tek dosya (v2):** klasörün içeriğinin zip'i, uzantısı `.nxvapp`. `app.json` zip'in kökündedir.

Paketlemek için:

```
python tools/nxvapp_pack.py Uygulamam.nxvapp              # Uygulamam.nxvapp (zip) klasörün yanına yazılır
python tools/nxvapp_pack.py Uygulamam.nxvapp -o dist/x.nxvapp
python tools/nxvapp_pack.py Uygulamam.nxvapp --index      # depo kaydını (size, sha256 …) da yazdırır
```

Paketleyici `app.json`'u denetler (kimlik, ad, giriş dosyası, `minSdk` biçimi, bilinmeyen izinler), gizli dosyaları
atlar ve `manifest.sha256` ekler. Studio'nun **Paketi Dışa Aktar** komutu aynı biçimi üretir.

Kullanıcı tarafında:

- `.nxvapp` dosyası Dosyalar'da açılınca yükleme sayfası çıkar: **Çalıştır** (kurmadan bir kez) ya da **Yükle**.
- Doğrulama durumu: her dosya `manifest.sha256` ile eşleşirse *Doğrulandı*, eşleşmezse *Değiştirilmiş*, manifest
  yoksa *İmzasız*. Bu bir bütünlük denetimidir, imza değildir.
- Kurulum atomiktir. Aynı `id` ile yeni sürüm, eski kopyanın yerine yazılır; uygulama verileri
  (`~/Library/Application Support/<id>`) korunur.
- Yerel (C++) uygulamalar paketlenemez.

Ayrıntılar: [NXVAPP_FORMAT.tr.md](NXVAPP_FORMAT.tr.md).

Yayımlamadan önce bilgisayarda denetleyin:

```
python tools/lua_check.py path/to/Uygulamam.nxvapp     # Lua: sözdizimi + başsız birkaç yüz kare
node tools/js_check.mjs path/to/Uygulamam.nxvapp       # JavaScript: aynı denetim
```

Python için `tools/py_check.py` vardır; kullanımı [PY_APPS.tr.md](PY_APPS.tr.md) içinde anlatılır.

---

## 7. Topluluk kataloğu

Uygulama Mağazası bir JSON depo dizinini (`index.json`) listeler. Adres **Sistem Ayarları > Uygulamalar > Topluluk
uygulama deposu** alanındadır; boşsa varsayılan katalog kullanılır:
`https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json` (404 döndükçe sırayla eski
`AppStore/catalog.json` ve `store/catalog.json`). Resmî katalogdaki her şey yayımlanmadan önce bakımcı tarafından
incelenir: akışın tamamı (fork, `Store/<Apps|Games|Themes|Fonts>/...`, denetimler, pull request, inceleme) yayın
deposundaki `SDK/Publishing/PUBLISHING.tr.md` dosyasındadır.

Bir uygulamayı katalogda yayımlamak için:

1. Paketi `--index` ile oluşturun: `python tools/nxvapp_pack.py Uygulamam.nxvapp --index`. Çıktıdaki kayıt `size` ve
   `sha256` değerlerini içerir.
2. `.nxvapp` dosyasını herkese açık bir adreste barındırın (örneğin bir GitHub sürümü).
3. Kaydı `download` adresi, simge, ekran görüntüleri, `minSdk` ve `permissions` ile tamamlayıp katalogdaki `apps`
   dizisine ekletin.

Mağaza her indirmenin `sha256` değerini denetler; eşleşmezse kurmaz. `minSdk` sistemden yeniyse uygulama listede
görünür ama kurulamaz. `version` kurulu sürümden büyükse "Güncelle" çıkar.

Kendi katalogunuzu da barındırabilirsiniz: aynı biçimde bir `index.json` yayımlayın ve adresini ayarlardaki alana
yazın. Kayıt biçimi: [NXVAPP_FORMAT.tr.md bölüm 6](NXVAPP_FORMAT.tr.md#6-topluluk-deposu-indexjson).

---

## 8. Overlay: sistem dosyalarını değiştirmek

`sdmc:/NexvynOS/System/Overlay/` içindeki bir dosya, romfs'te aynı göreli yoldaki sistem dosyasının yerine kullanılır.
Böylece `.nro`'yu yeniden derlemeden çeviri düzeltmesi, duvar kâğıdı ya da yerleşik bir Lua uygulamasının yeni sürümü
dağıtılabilir.

| Overlay yolu | Yerine geçtiği |
|---|---|
| `Overlay/Languages/tr/shell.json` | `romfs:/System/Languages/tr/shell.json` |
| `Overlay/Wallpapers/x.jpg` | `romfs:/System/Wallpapers/x.jpg` |
| `Overlay/Applications/notes.nxvapp/` (içinde `app.json`) | Bütün paket |
| `Overlay/Applications/notes.nxvapp/lang/tr.json` | Yalnızca o dosya |

- Dosya okuma, resimler, yazı tipleri, sesler, dil dosyaları ve uygulama taraması bu kuralı izler.
- Değişiklikler Nexvyn OS yeniden başlayınca tam olarak geçerli olur.
- Kullanıcı **Sistem Ayarları > Hakkında > Sistem klasörü** bölümünde Overlay durumunu görür ve **Sistem
  güncellemelerini sıfırla** ile klasörü `Overlay.off` adıyla kenara alabilir.
- Overlay, yerleşik C++ kodunu değiştiremez; yalnızca romfs dosyalarının yerine geçer.

---

## 9. Ryujinx'te test

Nexvyn OS, Ryujinx emülatöründe çalışır. Donanıma bağlı özellikler (USB, MTP, parlaklık, oyun başlatma, PC oyunları)
orada kapalıdır.

### Elle çalıştırma

- `./build.sh run`: derler ve `NexvynOS.nro`'yu Ryujinx'te açar.
- Ryujinx'in yolu `RYUJINX` ortam değişkeniyle verilir. Betiklerdeki varsayılan yol proje sahibinin bilgisayarına
  göredir; kendi yolunuzu verin.
- Uygulamanızı Ryujinx'in SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

### autorun.txt ile otomatik tur

`sdmc:/NexvynOS/autorun.txt` varsa Nexvyn OS açılışta içindeki komutları sırayla çalıştırır. Ekran görüntüleri
`sdmc:/NexvynOS/autoshots/<ad>.png` olarak kaydedilir. `#` ile başlayan satırlar yorumdur.

```
# kurulum yardımcısını Türkçe geç, uygulamayı aç, ekran görüntüsü al
setup tr
wait 2
launch com.adiniz.uygulama
wait 3
shot uygulamam
click 640 360
wait 1
shot tiklandi
exit
```

Komutlar: `wait <sn>`, `setup <dil>`, `unlock`, `launch <appId> [arg]`, `shot <ad>`, `launcher`, `search <metin>`,
`overview`, `cc`, `nc`, `close`, `closeall`, `minimize`, `click <x> <y>`, `rclick`, `mclick`, `move`, `key <ad>`,
`text <metin>`, `dark <0|1|2>`, `lang <kod>`, `log <mesaj>`, `exit`. Bunların yanında `drag`, `dpad`, `a`, `up`, `down`,
`set`, `saver`, `desktop`, `closeask` gibi komutlar da vardır. Güncel liste ve sözdizimi
`source/wm/shell_autorun.cpp` dosyasının başındadır.

Testten sonra `autorun.txt`'yi silin; yoksa her açılışta yeniden çalışır.

### tools/ryu_test.sh

```
tools/ryu_test.sh <cikti.png> [bekleme_sn] [keep]
```

Açık bir Ryujinx'i kapatır, `NexvynOS.nro`'yu başlatır, verilen süre (varsayılan 14 sn) bekler ve pencerenin ekran
görüntüsünü kaydeder. Üçüncü argüman `keep` ise Ryujinx açık kalır. Betik Git Bash'te çalışır ve PowerShell kullanır
(Windows). `autorun.txt` ile birlikte kullanılınca bir uygulama turu başsız çalıştırılabilir.

---

## 10. Yerleşik (native) uygulama geliştirme

Bu bölüm Nexvyn OS'un kendisine katkı yapanlar içindir. Yerleşik uygulamalar C++17 sınıflarıdır ve `NexvynOS.nro`'ya
derlenir. Ayrıntılı rehber (İngilizce): [APP_GUIDE.tr.md](APP_GUIDE.tr.md).

### Gerekenler

- devkitPro: devkitA64, libnx, switch-sdl2, switch-sdl2_ttf/image/mixer, switch-curl, switch-mbedtls.
- Derleme: `./build.sh` (çıktı `NexvynOS.nro`).
- Tek dosya denetimi: `tools/check.sh source/apps/app_<id>.cpp` (gerçek derleyiciyle sözdizimi ve tür denetimi).

### Bir uygulamanın parçaları

- `source/apps/app_<id>.cpp` (ek dosyalar `source/apps/<id>_*.cpp/.h`; dosya adları depoda benzersiz olmalı).
- `romfs/Applications/<id>.app/`: `app.json`, `icon.png`, `lang/en.json`, `lang/tr.json`.
- `tools/apps_manifest.json` içinde bir kayıt: ad, kategori, ikon glifi ve renkleri. İkon
  `python tools/gen_assets.py apps` ile bu listeden üretilir.

### REGISTER_APP

```cpp
#include "../wm/app.h"
#include "../wm/registry.h"
#include "../core/ui.h"
#include "../core/theme.h"

class HelloApp : public App {
public:
    int count = 0;
    void draw(float w, float h) override {
        const Palette& p = theme::p();
        ui::label(TRF("hello.clicked", std::to_string(count)), 20, 20, 15, p.text);
        if (ui::button(TR("hello.click"), Rect(20, 50, 140, 30), ui::BTN_PRIMARY)) count++;
    }
};
REGISTER_APP("hello", HelloApp)
```

`App` sınıfı `onStart(arg)`, `onOpen(arg)`, `update(dt)`, `draw(w, h)`, `onEvent`, `menus()`/`onMenu(id)` ve
`canClose()` sunar. Ağ, diyalog ya da zamanlayıcı gibi sonradan çalışan geri çağrılarda `aliveToken()` kullanın;
pencere kapanınca uygulama nesnesi silinir.

### Arayüz: ui::

Bileşenler immediate mode'dur: aynı çağrı çizer ve etkileşimi döndürür. `ui::button`, `toggle`, `checkbox`, `slider`,
`segmented`, `popup`, `textField`, `listRow`, `sidebarItem`, `groupBox`, `beginScroll/endScroll`, `contextMenu`,
`TextArea` ve diğerleri `source/core/ui.h` içindedir. Döngülerde `ui::pushId(i)/popId()` kullanın. Dokunmatik kaydırma,
kumanda odağı ve sağ tık (X tuşu, uzun basış) bileşenlerce yönetilir.

### Çeviri: i18n

- Metinler `romfs/Applications/<id>.app/lang/en.json` ve `tr.json` içinde durur ve uygulama kimliğiyle ad alanına
  girer: `notes.app` içindeki `save_title` → `TR("notes.save_title")`. `TRF("anahtar", a, b)` `{0}`, `{1}`'i doldurur.
- Ortak metinler hazırdır: `common.*`, `places.*`, `date.*`, `cat.*`, `color.*`, `sys.*`.
- Her anahtar iki dilde de bulunmalı: `python tools/lang_check.py`.
- Türkçe metinler doğru karakterlerle (ç ğ ı İ ö ş ü) yazılır.

### Modlama çekirdeği: modkit

Modlama klasöründeki uygulamalar (Mod Yöneticisi `modmanager`, Hile Yöneticisi `cheats`, Sistem Modülleri
`sysmodules`, Oyun Bilgileri `gameinfo`) ortak bir çekirdek kullanır: `source/core/modkit.h`. Oyun modlarına dokunan
yeni bir yerleşik araç yazıyorsanız buradan başlayın.

- **Yollar:** `contentsDir(tid)`, `romfsDir`, `exefsDir`, `cheatsDir`, `flagsDir`, `exefsPatchesRoot()`,
  `modsLibraryRoot()` (`sdmc:/mods`), `nexvynModsRoot()` (`sdmc:/NexvynOS/Mods`: kapalı modlar ve kayıtlar).
- **Güvenlik:** her yazmadan önce `safeSdPath(path)`; arşiv girdileri için `safeRel()` (mutlak yol, sürücü harfi,
  `..` ve kontrol karakteri reddedilir), dosya adları için `safeName()`. Modlama uygulamaları SD kartın dışına
  yazmaz.
- **Oyunlar:** `requestTitles(rescan)`, `titles()`, `findTitle()`, `icon()`; `revision()` liste ya da build ID
  değişince artar. Ana iş parçacığında bloklamaz; taramalar modkit işçisinde çalışır.
- **Build ID:** `buildId(tid, &out)` bloklamaz (`BID_PENDING` / `BID_READY` / `BID_UNKNOWN`). `cheatName()` hile
  dosyası adını, `hex()` `.ips` adını verir.
- **Hileler:** `cheat::parse()` (Atmosphère kurallarıyla), `readToggles` / `writeToggles` (`toggles.txt`), çalışan
  oyun için `cheat::attach`, `list`, `toggle` (dmnt:cht).
- **Sistem:** `runningTitle()`, `programRunning()`, `launchProgram()` / `terminateProgram()` (pm:shell),
  `systemInfo()` (firmware, Atmosphère, emuMMC, SD alanı).
- **Uzun işler:** `post(job)` kopyalama ve açma gibi işleri modkit işçisinde sırayla çalıştırır. Sonucu kendi
  paylaşılan durumunuza yazın, `update()`/`draw()` içinde okuyun.
- ns dışındaki Horizon servisleri yalnızca gerçek konsolda (`sys::realHardware()`) çağrılır; başka yerde sonuç
  "bilinmiyor"dur. Ortak arayüz parçaları `source/apps/modding_ui.*`, mod kayıtları `source/apps/mod_store.*`
  içindedir. Türkçe Yamalar (`turkceyama`) ve Kayıt Yedekleme (`savebackup`) ayrı uygulamalardır; tasarımı
  [TURKISH_PATCHES.tr.md](TURKISH_PATCHES.tr.md) anlatır.

### Katkı kuralları

- Her şey gerçek olmalı: sahte veri ya da taklit özellik yok. Konsolun servisleri, gerçek dosya sistemi ve ağ
  kullanılır.
- Kullanıcıya görünen her metin çevrilir.
- Arayüzde başka şirketlerin ürün adları Nexvyn OS özelliği olarak kullanılmaz: "Arama", "Uygulamalar", "Pencere
  Görünümü", "Gece Modu", "Dock düzeni", "Görev çubuğu düzeni". Üçüncü taraf hizmetler yalnızca kendilerini tarif
  ederken anılır (Steam, CorkDeck, sağlayıcı adları).
- Lisans GPL-3.0-or-later'dır. Yalnızca GPLv3 ile uyumlu kod bağlanır; harici homebrew programları bağlanmaz, yalnızca
  başlatılır. Yeni bir bileşen ekliyorsanız [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) dosyasını güncelleyin.
- Bir dosyayı denetledikten sonra Ryujinx'te `autorun.txt` ile deneyin (bölüm 9).

---

## English summary

This guide takes a developer from zero to a published Nexvyn OS app. It links to the detailed references instead of
repeating them: [sdk/SDK.tr.md](../Reference/SDK.tr.md) (full API), [JS_APPS.tr.md](JS_APPS.tr.md), [PY_APPS.tr.md](PY_APPS.tr.md),
[GAME_ENGINE.tr.md](GAME_ENGINE.tr.md), [NXVAPP_FORMAT.tr.md](NXVAPP_FORMAT.tr.md) and [APP_GUIDE.tr.md](APP_GUIDE.tr.md).

1. **Studio:** *New Project* opens a gallery of ten templates (blank Lua, blank JS, utility, platformer, arena
   shooter, puzzle, 3D scene, network app, blank Python, Snake in Python). `.py` files open with Python
   highlighting; Python templates use `minSdk` 1.3. Studio has live error checking, completion, Run with a console, sprite,
   tilemap and scene editors, an *Ask AI* panel that never edits files, and *Export Package*.
2. **app.json:** `id`, `main`/`runtime`, `window`, `gamepad`, `fileTypes`, `minSdk` (1.0 Lua, 1.1 JS, 1.2 nexvyn.game and
   permissions, 1.3 Python) and `permissions` (`network` and `files` are enforced for apps installed on the SD card).
3. **Languages:** Lua 5.4, JavaScript (QuickJS-ng) and Python (pocketpy, SDK 1.3) share one API. `nexvyn.game` is
   Lua-only. Two-finger gestures arrive as `"pinch"` (`e.scale`, a factor since the last event) and `"rotate"`
   (`e.angle`, radians) events in all three languages.
4. **nexvyn.game:** a 2D engine in `romfs:/System/Lua/nexvyn/` (`require("nexvyn.game")`); samples Pixel Koşu and Uzay Arenası.
   Game Engine (`gamemaker`) projects are `project.json` files interpreted by `nexvyn.workshop` / `nexvyn.workshop3d`
   and exported as standalone `.nxvapp` bundles; see [GAME_ENGINE_PROJECTS.tr.md](GAME_ENGINE_PROJECTS.tr.md).
5. **g3d:** GPU 3D renderer with a CPU fallback. The `"glow"` flag draws additively (stars, sparks, light trails);
   native code also has `g3d::append` (merge transformed copies into one mesh, one draw call) and
   `g3d::lastDrawCalls()`.
6. **Packaging:** `python tools/nxvapp_pack.py <folder> [-o out.nxvapp] [--index]` writes a zip `.nxvapp` v2 with
   `manifest.sha256`. Check bundles with `tools/lua_check.py` and `tools/js_check.mjs`.
7. **Catalog:** the Uygulama Mağazası reads an `index.json` (default `sonerx7/Nexvyn-OS-NX/Store/catalog.json`, configurable in
   *Settings > Apps*) and verifies each download's SHA-256.
8. **Overlay:** files under `sdmc:/NexvynOS/System/Overlay/` replace the romfs file with the same relative path.
9. **Testing:** `./build.sh run`, `sdmc:/NexvynOS/autorun.txt` scripts (command list at the top of
   `source/wm/shell_autorun.cpp`) and `tools/ryu_test.sh <out.png> [wait] [keep]` for Ryujinx screenshots.
10. **Native apps:** C++17 classes registered with `REGISTER_APP`, strings in `lang/*.json` read with `TR()`, immediate
    mode `ui::` widgets, an entry in `tools/apps_manifest.json`, and `tools/check.sh` per file. Modding tools share
    `source/core/modkit.h`: Atmosphère paths, SD-only path checks (`safeSdPath`, `safeRel`), installed titles, build
    ids, the cheat parser and dmnt:cht client, system facts and a worker thread (`post`). No other vendors'
    product names in the UI; GPL-3.0-or-later.
