# .nxvapp paket biçimi (v2)

**Türkçe** · [English](NXVAPP_FORMAT.en.md)

> **English summary.** A `.nxvapp` v2 package is a zip file with `app.json` at its root (a single top-level folder
> holding `app.json` is accepted too). An optional `manifest.sha256` lists the SHA-256 of every other file
> (`sha256sum` format); Nexvyn OS shows *Intact* when every file matches and nothing is unlisted, *Modified* when not,
> *Unsigned* when there is no manifest. An optional `manifest.sig` (SDK 1.4) is the developer's ECDSA P-256
> signature of `manifest.sha256`: the install sheet then shows *Signed by AB12:CD34:EF56:7890*, refuses a broken
> signature and warns when an update is signed with a different key than the installed version (trust on first use).
> `app.json` may declare `minSdk` (Nexvyn OS refuses apps that need a newer SDK; `sys.sdkVersion()` reports the
> current one), `permissions` (all four - `network`, `files`, `launch`, `notifications` - are enforced for apps
> installed on the SD card; the user decides once, on the install sheet where installing allows them and *Customize*
> turns some off, or at the first start of an app installed without a sheet; an update asks only about permissions it
> adds; `"clipboard"` is retired since 1.0.0: `sys.clipboard` works for every app and the name is ignored) and
> `shareTargets` (what `sys.share` may hand the app). Packages over 20000 files or 1 GiB unpacked are refused. Opening a package in
> Files shows an install sheet with **Run** (unpacked into `Library/Caches/nxvinstall/<id>`, nothing installed) and
> **Install** (atomic install into `sdmc:/NexvynOS/Applications`; same id = update in place, app data kept).
> The Uygulama Mağazası lists a JSON repository index (URL in *System Settings > Apps*) and checks each download's
> `sha256` (and `signer`, when given). Pack a folder with `python tools/nxvapp_pack.py <folder> [-o out.nxvapp]
> [--sign key.pem] [--index]`; create a key with `tools/nxvapp_keygen.py`; check a package with `--verify`;
> validate a catalog with `tools/catalog_check.py`.
> Updatable system files: anything under `sdmc:/NexvynOS/System/Overlay/` replaces the romfs file with the same
> relative path (`Overlay/Languages/tr/shell.json`, `Overlay/Applications/notes.nxvapp/`).

Bu belge hem geliştiriciler hem de yapay zekâ araçları için `.nxvapp` paketinin tam tarifidir. API'nin kendisi
`sdk/SDK.tr.md` içindedir.

## 1. Paket

Bir uygulama iki biçimde dağıtılabilir:

- **Klasör:** `Adı.nxvapp/` (geliştirme sırasında, Studio projeleri).
- **Tek dosya (v2):** aynı klasörün içeriğinin zip'lenmiş hâli, uzantısı `.nxvapp`.

```
Adı.nxvapp  (zip)
├── app.json            zorunlu, zip'in kökünde
├── main.lua | main.js | main.py | main.nut | main.c | app.jar   giriş dosyası ("main" alanı)
├── icon.png            128×128 veya 256×256, saydam PNG
├── lang/tr.json        çeviriler (isteğe bağlı)
├── lang/en.json
├── ...                 resimler, sesler, modüller
├── manifest.sha256     dosya listesi ve SHA-256 değerleri (isteğe bağlı, önerilir)
└── manifest.sig        geliştirici imzası (isteğe bağlı, SDK 1.4; bölüm 4b)
```

Kurallar:

- `app.json` kökte olmalı. Eski paketler için tek bir üst klasörün içinde olması da kabul edilir (`Adı/app.json`).
- Gizli dosyalar (adı `.` ile başlayan: `.git`, `.DS_Store`) pakete konmaz; paketleyici bunları atlar.
- `..` içeren, mutlak, `:` ya da `\` içeren yollar açılırken yok sayılır (zip-slip koruması).
- En çok 20000 dosya ve 1 GiB açılmış boyut: daha büyük paketler hiçbir şey açılmadan reddedilir (zip bombası koruması).
- `"native": true` yalnızca sistemle gelen C++ uygulamaları içindir. C++ uygulaması paketi derlenmiş bir yerel modül
  taşır: `"native": "<id>.nxvmod"` ve `"abi"` (bölüm 2, `docs/NATIVE_MODULES.tr.md`). Bu, yalnızca Nexvyn OS'un kendi
  uygulamaları için bir iç mekanizmadır; üçüncü taraf uygulamalar Lua, JavaScript veya Python ile yazılır.

## 2. app.json

| Alan | Tür | Açıklama |
|------|-----|----------|
| `id` | metin, zorunlu | Benzersiz kimlik, ters alan adı biçiminde: `com.adiniz.uygulama`. Harf, rakam, `.`, `-`, `_`; en çok 128 karakter. Güncellemeler bu kimlikle eşleşir. |
| `name` | metin veya `{"en","tr",...}` | Görünen ad. |
| `description` | metin veya dil tablosu | Kısa açıklama (yükleme sayfasında ve Mağaza'da). |
| `version` | metin | `"1.4.2"` gibi; noktalı sayılar olarak karşılaştırılır (`1.10` > `1.9`). |
| `author` | metin | Geliştirici adı. |
| `category` | metin | `system`, `productivity`, `utilities`, `media`, `internet`, `games`, `developer`, `other`. |
| `icon` | metin | Varsayılan `icon.png`. |
| `main` | metin | Giriş dosyası; yoksa çalışma ortamının varsayılanı (aşağıdaki tablo). Uzantısı çalışma ortamını da seçer. |
| `runtime` | `"lua"`, `"js"`, `"python"`, `"squirrel"`, `"c"`, `"java"` | Çalışma ortamını açıkça seçer (uzantıdan önce gelir). |
| `mainClass` | metin | Yalnızca Java: `nexvyn.App`'ten türeyen sınıf (`"hello.HelloApp"`); yoksa jar'ın manifest'indeki `Main-Class`. |
| `window` | nesne | `width`, `height`, `minWidth`, `minHeight`, `resizable`. |
| `singleInstance`, `gamepad`, `dpadArrows`, `hidden` | mantıksal | Bkz. `sdk/SDK.tr.md`. |
| `fileTypes` | metin dizisi | Açabildiği uzantılar (`[".txt"]`). |
| `minSdk` | metin | Gereken en düşük SDK sürümü (`"1.2"`). Yoksa her sürümde çalışır. |
| `permissions` | metin dizisi | İstenen izinler (bölüm 3). Yoksa eski paket sayılır. |
| `native` | metin | Yalnızca C++ uygulamaları: paketteki yerel modül dosyası (`"news.nxvmod"`); `main` yerine geçer. `tools/build_modules.py` üretir. |
| `abi` | metin | Yalnızca C++ uygulamaları: modülün derlendiği Nexvyn OS yapısının ABI kimliği (16 onaltılık karakter). Farklıysa kurulmaz. |
| `shareTargets` | metin dizisi | `sys.share` ile alabildikleri (SDK 1.4): `"text"`, `"url"`, `"file"`, `"image"` ya da uzantı (`".txt"`). Paylaşılan öğe `app.load(arg)` / `app.open(arg)` ile gelir. |

Çalışma ortamları (`runtimes/runtime_kind.h`):

| `runtime` | Uzantı | Varsayılan `main` | Dil | En düşük SDK |
|---|---|---|---|---|
| `"lua"` (varsayılan) | `.lua` | `main.lua` | Lua 5.4 | 1.0 |
| `"js"` | `.js`, `.mjs` | `main.js` | JavaScript (QuickJS-ng) | 1.1 |
| `"python"` | `.py` | `main.py` | Python (pocketpy 2) | 1.3 |
| `"squirrel"` | `.nut` | `main.nut` | Squirrel 3.2 | 1.5 |
| `"c"` | `.c` | `main.c` | C, konsolda TinyCC ile derlenir; paketteki tüm `.c` dosyaları | 1.5 |
| `"java"` | `.jar` | `app.jar` | Java 8 sınıf dosyaları (miniJVM); jar PC'de `tools/java_build.py` ile derlenir | 1.5 |
| `"native"` | `.nxvmod` | `"native"` alanı | C++ yerel modül, NRO ile aynı derleyiciyle derlenir; yalnızca aynı ABI'li sistemde çalışır (`docs/NATIVE_MODULES.tr.md`) | SDK yerine ABI kimliği |

`"c"`, `"java"` ve `"native"` uygulamaları korumalı alanda çalışmadığı için SD karttan kurulanlar ilk açılışta
kullanıcıya bir kez sorulur (`apps.trustedC`, `apps.trustedJava`, `apps.trustedNative`).

### SDK sürümleri

Sistem `NEXVYN_SDK_VERSION` değerini (`source/core/sdk_version.h`) taşır; uygulamalar `sys.sdkVersion()` ile okur.
`minSdk` bu değerden büyükse:

- Kayıt (registry) uygulamayı listelemez, yükleme reddedilir;
- yükleme sayfası ve Mağaza "Bu uygulama Nexvyn OS'un daha yeni bir sürümünü gerektiriyor" der.

| SDK | Eklenenler |
|-----|------------|
| 1.0 | Lua çalışma ortamı: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | JavaScript çalışma ortamı (aynı modüller, Promise'ler); `g3d` dokuları GPU'da |
| 1.2 | `nexvyn.game` motoru, `sys.sdkVersion()`, `minSdk`, `permissions`, tek dosya `.nxvapp` v2 ve `manifest.sha256` |
| 1.3 | Python çalışma ortamı (pocketpy) |
| 1.4 | tüm izinler zorunlu, `sys.share`, `sys.schedule`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `nxv://` bağlantıları, `app.search` ve yaşam döngüsü geri çağırmaları, `shareTargets`, `manifest.sig` |
| 1.5 | Squirrel (`"squirrel"`), C (`"c"`, TinyCC) ve Java (`"java"`, miniJVM) çalışma ortamları, `mainClass`; Python sistem kütüphanesi (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |

Küçük sürüm (1.x) yalnızca ekleme yapar; bir şey kaldırılır ya da anlamı değişirse büyük sürüm artar.

## 3. İzinler

| İzin | Kapsadığı API | İzin yoksa |
|------|---------------|------------|
| `network` | `net.get/post/json/download/request`, JS `fetch` | istek `"permission denied: network"` hatasıyla döner |
| `files` | Uygulamanın kendi klasörleri (paket, `Application Support/<id>`, `Caches/<id>`) dışındaki yollar | yol boş olur |
| `launch` | `sys.launch` (başka bir uygulama), `sys.open("nxv://...")` | `nil, "permission denied: launch"` (JS/Python: `false`) |
| `notifications` | `sys.notify`, `sys.schedule` (zamanlanmış bildirimler de gönderilmez) | `nil, "permission denied: notifications"` |

SDK 1.4'ten beri **dört iznin hepsi zorunludur**. **Pano artık izin değildir** (1.0.0): `sys.clipboard` her uygulamada
çalışır. Eski bir `app.json` hâlâ `"clipboard"` listeliyorsa uygulama aynen çalışır; ad sessizce yok sayılır
(`nxvapp_pack.py`, `catalog_check.py` ve denetleyiciler yalnızca uyarır).

Nasıl işler:

- Sistemle gelen uygulamalar (Uygulama Mağazası'ndan eklenen isteğe bağlı sistem uygulamaları da) denetlenmez. SD karttaki
  (`sdmc:/NexvynOS/Applications`) her uygulama denetlenir.
- **Uygulama başına tek karar, asla çağrı anında değil.** Uygulama Mağazası'nda *Al* ya da dosyadan açılan yükleme sayfası
  istenen izinleri simgeleriyle listeler; "Yükle" (ya da "Çalıştır") demek bu izinleri vermek demektir. Küçük
  **Özelleştir** bağlantısı bazılarını önceden kapatmaya yarar. Yanıt
  `sdmc:/NexvynOS/System/Config/permissions.json` dosyasında saklanır.
- **Güncellemeler** yalnızca yeni eklenen izinleri güncelleme onayında gösterir ("Yeni" etiketiyle); daha önce
  yanıtlanmış izinler yeniden sorulmaz. Yeni izin eklemeyen güncelleme doğrudan başlar.
- Yükleme sayfası görmeden gelen uygulama (SD karta elle kopyalanmış, eski paket, Kitaplık'tan çalıştırılan) ilk
  açılışta **bir kez**, tek bir pencerede sorulur. Studio ya da Kod'dan geliştiricisinin çalıştırdığı uygulama
  bildirdiği izinleri soru sorulmadan alır.
- Yanıtlar sonradan *Sistem Ayarları > Gizlilik ve İzinler*'de uygulama başına anahtarlarla değiştirilir
  ("Yeniden Sor" bir sonraki açılışta yeniden sorar).
- `permissions` içinde **olmayan** bir izin hiç verilmez. `permissions` alanı olmayan eski paketlere ilk açılışta
  dört iznin hepsi sorulur.
- `sys.hasPermission(ad)` iznin şu an verili olup olmadığını söyler; `sys.requestPermission(ad, fn)` kullanıcının
  kapattığı, bildirilmiş bir izni oturum başına bir kez yeniden sorar. Uygulama çalışırken çıkabilecek tek soru
  budur ve yalnızca uygulama onu açıkça çağırdığında çıkar; izinsiz çağrılar soru sormaz, başarısız olur.
- Reddedilen ağ isteği bir sonraki karede hata olarak döner: `res.ok == false`,
  `res.error == "permission denied: network"`.
- Reddedilen dosya yolu boş yol olur: `fs.read` → `nil`, `fs.list` → boş, `fs.path("sdmc:/...")` → `""`,
  `net.download` hata verir.
- Kullanıcının `ui.openFile` / `ui.saveFile` ile seçtiği dosyalar, uygulamanın açıldığı dosya ("Birlikte Aç") ve
  uygulamayla paylaşılan dosyalar izin olmadan da kullanılabilir. `romfs:/` okunabilir. Paylaşılan **metin** ya da
  `nxv://` bağlantısından gelen argüman ise hiçbir dosya iznini açmaz.
- **Korunan klasörler.** Bazı klasörler, `files` izni olsa bile SD karttaki uygulamalara kapalıdır: Nexvyn OS'un kendi
  verileri (`sdmc:/NexvynOS/System`; eklenti klasörleri `System/Library` ve `System/Fonts` hariç), başka uygulamaların
  `sdmc:/NexvynOS/Applications` içindeki paketleri, kullanıcının `~/Library` klasörü (uygulamanın kendi
  `Application Support/<id>` ve `Caches/<id>` klasörleri dışında: başka uygulamaların verileri, Tarayıcı'nın çerezleri
  ve parolaları, AI Chat, FTP ve Tube anahtarları, klavyenin öğrendiği sözcükler) ve diğer her kullanıcının `Library`
  klasörü. Başka bir kullanıcının ev klasörü yalnızca kullanıcının seçtiği dosya için açılır. Yollar SD kartın
  karşılaştırdığı gibi karşılaştırılır (büyük/küçük harf, `..`, `\`); başka bir yazımla dolanılamaz. Uygulamanın
  günlüğüne bir kez `protected path: <yol>` yazılır. Ayrıntılar: [APP_GUARD.tr.md](APP_GUARD.tr.md).
- Reddedilen her izin uygulamanın günlüğüne bir kez, nedeniyle yazılır: `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`
  ("declare it in app.json" = bildirilmemiş, "the user did not allow it" = kullanıcı reddetmiş).
- Uygulama kaldırılınca kayıtlı yanıtlar silinir.

## 4. Doğrulama dosyası (manifest.sha256)

`sha256sum` çıktısıyla aynı biçimde düz metin; her satırda 64 haneli küçük harf onaltılık değer, iki boşluk ve
pakete göre yol (`/` ile):

```
3f2a...9c1e  app.json
b81d...04aa  icon.png
77c0...1f3b  lang/tr.json
e4a9...5d20  main.lua
```

- `manifest.sha256` kendisini listelemez. Gizli dosyalar listelenmez ve pakete konmaz.
- Nexvyn OS paketi açarken her dosyanın değerini hesaplar:
  - hepsi eşleşir ve listede olmayan dosya yoksa → **Doğrulandı**;
  - bir değer farklıysa, listedeki bir dosya eksikse ya da listede olmayan bir dosya varsa → **Değiştirilmiş**
    (yükleme sayfası hangi dosya olduğunu gösterir);
  - dosya yoksa → **İmzasız**.
- Tek başına bu bir bütünlük denetimidir: paketi değiştiren biri listeyi de yeniden üretebilir. Kimin yaptığını
  kanıtlamak için listeyi imzalayın (bölüm 4b); Mağaza ayrıca her indirmeyi `sha256` değeriyle karşılaştırır (bölüm 6).
- `manifest.sha256` ve `manifest.sig` listede yer almaz.

## 4b. Geliştirici imzası (manifest.sig, SDK 1.4)

`manifest.sig`, `manifest.sha256` dosyasının baytları üzerinde ECDSA (NIST P-256, SHA-256) imzasıdır:

```json
{"alg": "ECDSA-P256-SHA256",
 "key": "<65 baytlık sıkıştırılmamış açık anahtarın (04||X||Y) base64 hâli>",
 "sig": "<DER imzanın base64 hâli>"}
```

- **Parmak izi** açık anahtarın SHA-256 değerinin ilk 8 baytıdır: `AB12:CD34:EF56:7890`. Yükleme sayfası
  "İmzalayan: AB12:CD34:EF56:7890" gösterir.
- İmza doğrulanmazsa ya da dosyalar imzadan sonra değişmişse paket **Geçersiz imza** olarak işaretlenir ve
  yüklenemez/çalıştırılamaz.
- **İlk kullanımda güven (TOFU):** bir uygulama imzalı kurulunca anahtarın parmak izi
  `sdmc:/NexvynOS/System/Config/signers.json` dosyasına yazılır. Sonraki bir güncelleme başka bir anahtarla
  imzalanmış (ya da imzasız) ise yükleme sayfası ve Mağaza "Farklı bir geliştirici tarafından imzalanmış" uyarısı
  gösterir ve onay ister.
- Anahtar oluşturma: `python tools/nxvapp_keygen.py anahtarim.pem` (parmak izini yazar; `--show` mevcut anahtarı
  gösterir). OpenSSL anahtarları da çalışır (`openssl ecparam -name prime256v1 -genkey -noout -out k.pem`).
  Anahtarı gizli tutun ve yedekleyin: güncellemeler aynı anahtarla imzalanmalıdır.

## 5. Yükleme, güncelleme, kaldırma

- **Dosyalar'da açmak:** `.nxvapp` dosyası yükleme sayfasını açar: ikon, ad, yazar, sürüm, boyut, çalışma ortamı,
  gereken SDK, doğrulama durumu ve izinler.
  - **Çalıştır:** paket `~/Library/Caches/nxvinstall/<id>` içine açılır ve bir kez çalıştırılır; Başlatıcı'ya
    eklenmez. (Lua/JS çalışma ortamları dosyaları doğrudan zip'ten okumadığı için paket önce açılır.)
  - **Yükle / Güncelle / Yeniden yükle:** paket `sdmc:/NexvynOS/Applications` içine kurulur.
- **Atomik kurulum:** paket önce gizli bir geçici klasöre (`Applications/.staging-<id>`) açılır ve denetlenir; sonra
  eski kopya `.old-<id>` adıyla kenara alınır, yenisi yerine taşınır, en son eskisi silinir. Bir adım başarısız
  olursa eski kopya geri konur.
- **Güncelleme:** aynı `id` ile yüklenen paket, kurulu kopyanın klasörüne yazılır. Uygulama verileri
  (`~/Library/Application Support/<id>`) hiç değişmez.
- **Kaldırma:** Başlatıcı'da ikona sağ tık → Kaldır, Sistem Ayarları > Uygulamalar ya da Mağaza. "Verileriyle
  kaldır" `Application Support/<id>` ve `Caches/<id>` klasörlerini de siler.
- Sistemle gelen bir uygulamayla aynı kimliği taşıyan paket `ext.<id>` kimliğiyle yan yana kurulur.

## 6. Topluluk deposu (index.json)

Mağaza, adresi Sistem Ayarları > Uygulamalar'daki "Topluluk uygulama deposu" alanında olan bir JSON dosyası
listeler (boşsa varsayılan: `https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json`; bu
adres 404 döndükçe sırayla eski `AppStore/catalog.json` ve `store/catalog.json` denenir). Dosyaya ulaşılamazsa Mağaza son kopyayı gösterir ya da
"çevrimdışı" der. Mağaza açılınca ve arka planda en çok 6 saatte bir (çevrimiçiyken) katalog yenilenir.

```json
{
  "apps": [
    {
      "id": "com.ornek.notlar",
      "name": {"en": "Notes Plus", "tr": "Notlar Plus"},
      "description": {"en": "...", "tr": "..."},
      "version": "1.3",
      "author": "Örnek",
      "category": "productivity",
      "icon": "https://.../icon.png",
      "download": "https://.../NotlarPlus.nxvapp",
      "size": 48213,
      "sha256": "9b1c...e0",
      "minSdk": "1.2",
      "permissions": ["network"],
      "screenshots": ["https://.../1.png"],
      "featured": false,
      "added": "2026-09-20",
      "updated": "2026-10-01",
      "changelog": {"en": "Faster search.", "tr": "Daha hızlı arama."},
      "signer": "AB12:CD34:EF56:7890",
      "runtime": "lua",
      "tags": ["not", "metin"],
      "subtitle": {"en": "Notes with tags and search", "tr": "Etiketli, aranabilir notlar"}
    }
  ]
}
```

- `download` (eski adıyla da kabul edilen `url`) `.nxvapp` dosyasının adresidir.
- `sha256` indirilen **paket dosyasının** değeridir; eşleşmezse kurulum yapılmaz.
- `minSdk` sistemden yeniyse uygulama listede görünür ama "Al" düğmesi kapalıdır.
- `version` kurulu sürümden büyükse "Güncelle" çıkar. Kurulum Dosyalar'daki yükleyiciyle aynıdır.
- `added` (`YYYY-AA-GG`, ilk yayın) son 14 gün içindeyse kayıt "Yeni" rozeti alır ve Keşfet'in en üstündeki "Yeni"
  rafında görünür; kullanıcının henüz görmediği yeni kayıtlar Keşfet sekmesinde sayılır ve günde en çok bir kez
  bildirilir (Rahatsız Etmeyin açıkken bildirilmez; okunmamış bildirim Dock rozetidir). Son 14 günde `updated` olan
  (yeni olmayan) kayıtlar "Güncellendi" rozeti alır.
- `updated` (`YYYY-AA-GG`, verilmezse `added`) "En yeni" sıralamasında ve ayrıntı sayfasında, `changelog` "Yenilikler" bölümünde,
  `tags` aramada, `runtime` (`lua`, `js`, `python`, `squirrel`, `c`, `java`) ayrıntı sayfasında kullanılır.
- `signer` verilirse indirilen paket bu anahtarla imzalanmış olmalıdır; değilse kurulmaz.
- `subtitle` (en çok 45 karakter, dil tablosu) adın altında tek satır olarak kartlarda, listelerde ve ayrıntı
  sayfasında gösterilir; `name`, `subtitle` ve `description` arayüz dilinde, yoksa İngilizce gösterilir.
- `"builtin": true`: sistemle gelen isteğe bağlı bir uygulama (`download`, `sha256`, `size` yok). "Al" onu listelere
  ekler, "Kaldır" verisine dokunmadan çıkarır; ayrıca güncellenmez. Çalışan sistemde o kimlikte uygulama yoksa kayıt
  gizlenir. Katalogda olmayan isteğe bağlı uygulamalara Mağaza `app.json`'dan yerel bir sayfa yapar.
- `"runtime": "native"` + `"abi"`: C++ yerel modül paketi. Yalnızca çalışan sistemin ABI'sine uyan kayıtlar listelenir;
  kurulu modülün ABI'si farklıysa "Güncelle" çıkar.
- `"kind": "theme"` + `"category": "themes"`: `.nxvtheme` tema paketi (`download` + `sha256` zorunlu, bölüm 9).
  "Al" indirir, SHA-256'yı denetler ve `~/Library/Themes/<id>` altına kurar; ardından "Uygula" / "Kaldır". Kaydın
  `id`'si temanın `theme.json` kimliğiyle aynı olmalıdır. Kenar çubuğunda her zaman bir Temalar kategorisi vardır
  (`os::launch("appstore", "themes")` onu açar).
- `"kind": "font"` + `"category": "fonts"`: `styles` ve `license` bilgisiyle bir `.nxvfont` yazı tipi paketi (bölüm 10).
  "Al" onu `System/Fonts/User/<id>` altına kurar; ardından "Yüklü" / "Kaldır". Kenar çubuğunda her zaman bir Yazı
  Tipleri kategorisi vardır (`os::launch("appstore", "fonts")`).
- `license` (`MIT`, `OFL-1.1` gibi SPDX kimliği), `source` (koda https bağlantısı) ve `history` (yayımlanan her sürüm,
  `[{"version", "date"}]`, en yenisi önce) ayrıntı sayfasını doldurur: lisans, "Kaynak kod" bağlantısı ve sürüm
  geçmişi. Her sayfada ayrıca "Bu Uygulamayı Bildir" vardır (yayın deposunun bildirim formu).
- İndirme sayıları ve yıldız puanları Nexvyn OS mağaza istatistik hizmetinden (proje sunucusundaki `/NexvynOS/api/store`) gelir (ayar
  `store.statsUrl`): `GET /stats` → `{"updated", "apps": {id: {"downloads", "ratings", "rating"}}}`, ilk kurulumdan
  sonra `POST /download {"app","client"}`, puanlayınca `POST /rate {"app","client","stars"}`. `client` yalnızca bu iş
  için bir kez üretilen rastgele kimliktir (`store.clientId`, telemetri kimliği değil). Gönderim `store.shareStats`
  ile kapatılabilir; hizmete ulaşılamazsa sayılar ve yıldızlar gösterilmez.
- Aynı `id` iki kez geçerse yalnızca ilki kullanılır. `games` kategorisi kenar çubuğunda ilk sırada gösterilir.
- Mağaza bağlantıları: `nxv://store/<id>` uygulamanın sayfasını açar; `os::launch("appstore", "<id>")` da aynı işi görür.
- Katalog denetimi: `python tools/catalog_check.py Store/catalog.json` (şema, benzersiz kimlikler, https adresleri,
  `sha256`, `minSdk`, `signer`, tarih biçimi, `security.blocklist`; `--strict` uyarıları da hata sayar).

### security: Uygulama Koruması'nın engel listesi

```json
{
  "apps": [ ... ],
  "security": {
    "blocklist": [
      {"sha256": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
       "reason": "Sends saved passwords to a remote server"}
    ]
  }
}
```

- İsteğe bağlıdır. Her kayıt, zararlı olduğu bilinen bir paketi `.nxvapp` dosyasının SHA-256 değeriyle (uygulamaların
  `sha256` alanıyla aynı türden) belirtir; nedeni `reason` içindedir (kullanıcıya yazıldığı gibi gösterilir).
- Uygulama Koruması listeyi Uygulama Mağazası'nın en son önbelleğe aldığı katalogdan okur. Karması listede olan paket,
  yükleme sayfalarında ve *Sistem Ayarları > Gizlilik ve İzinler > Uygulama Koruması*'nda **Tehlikeli** görünür;
  yüklü uygulamalar, yüklendikleri paketin karmasıyla eşleştirilir.
- Yalnızca uyarır. Nexvyn OS bu liste yüzünden hiçbir uygulamayı kapatmaz, kaldırmaz ya da engellemez: karar
  kullanıcınındır.
- `tools/catalog_check.py` biçimi denetler (64 onaltılık basamak değilse hata; `reason` yoksa ya da aynı karma iki kez
  geçiyorsa uyarı). Yayın deposundaki `Tools/build_store.py` listeyi `Store/catalog.json` içine taşıyabilir.

## 7. Paketleme

```
python tools/nxvapp_pack.py Uygulamam.nxvapp              # Uygulamam.nxvapp (zip) klasörün yanında
python tools/nxvapp_pack.py Uygulamam.nxvapp -o dist/x.nxvapp
python tools/nxvapp_pack.py Uygulamam.nxvapp --index      # depo kaydını (size, sha256, signer ...) da yazdırır
python tools/nxvapp_keygen.py anahtarim.pem                 # imza anahtarı (bir kez)
python tools/nxvapp_pack.py Uygulamam.nxvapp --sign anahtarim.pem
python tools/nxvapp_pack.py --verify Uygulamam.nxvapp       # Nexvyn OS'un yapacağı denetim: liste, değerler, imza
```

Paketleyici `app.json`'u denetler (kimlik, ad, giriş dosyası, `minSdk` biçimi, bilinmeyen izinler ve paylaşım
hedefleri, boyut sınırları) ve `manifest.sha256` (`--sign` ile `manifest.sig`) ekler. Nexvyn OS Studio'daki **Dışa aktar** komutu da aynı biçimi üretir (`~/Documents/<ad>.nxvapp`).

## 8. Güncellenebilir sistem klasörü (Overlay)

`sdmc:/NexvynOS/System/Overlay/` içindeki bir dosya, `romfs` içinde aynı göreli yoldaki dosyanın yerine kullanılır:

| Overlay yolu | Yerine geçtiği |
|--------------|----------------|
| `Overlay/Languages/tr/shell.json` | `romfs:/System/Languages/tr/shell.json` |
| `Overlay/Wallpapers/x.jpg` | `romfs:/System/Wallpapers/x.jpg` |
| `Overlay/Applications/notes.nxvapp/` (içinde `app.json`) | `romfs:/Applications/notes.nxvapp/` (bütün paket) |
| `Overlay/Applications/notes.nxvapp/lang/tr.json` (tek dosya) | yalnızca o dosya |

- Dosya okuma (`fsx::readFile`), resimler, yazı tipleri, sesler, dil dosyaları ve uygulama taraması bu kuralı izler.
- Her yolun varlığı oturum başına bir kez denetlenir; Overlay klasörü yoksa maliyet yalnızca bir önek
  karşılaştırmasıdır. Değişiklikler Nexvyn OS yeniden başlayınca tam olarak geçerli olur.
- Sistem Ayarları > Hakkında'da durum görünür. "Sistem güncellemelerini sıfırla" klasörü `Overlay.off` adıyla
  kenara alır (silmez).

## 9. Temalar (.nxvtheme)

> **English summary.** A `.nxvtheme` is a zip with `theme.json` at its root (or in one top-level folder) plus the
> pictures it names and, optionally, UI sounds. `theme.json`: `id` (reverse-domain, must contain a dot), `name` and
> `description` (string or `{"en","tr","de","fr","es"}` map), `version`, `author`, `appearance` (`light` | `dark` |
> `auto`), `accent` (`#RRGGBB`), `wallpaper` (required, `.jpg`/`.png`/`.webp`, 1280×720), optional `wallpaperDark`
> (shown while the dark appearance is on), optional `sounds` (a folder of `<name>.wav` files replacing the system
> sounds) and optional `settings` with only these keys: `appearance.reduceTransparency`, `appearance.darkFrom`,
> `appearance.darkTo`, `dock.size`, `dock.magnify`, `dock.magnification`, `desktop.iconSize`, `screensaver.style`
> (other keys are ignored, values are clamped). Limits: 64 files, 32 MB, 12 MB per file; only `.json .jpg .jpeg .png
> .webp .wav .md .txt` (+ `manifest.sha256`/`.sig`); unsafe paths refuse the package. Themes install into
> `~/Library/Themes/<id>/` (same id = update in place). Opening one in Files shows a sheet with **Install** and
> **Install and Apply**; *System Settings > Appearance > Themes* applies, removes and restores the default look.

Tema; görünümü (açık/koyu/otomatik), vurgu rengini, duvar kâğıdını (isteğe bağlı koyu sürümüyle), isteğe bağlı arayüz
seslerini ve birkaç masaüstü ayarını tek pakette toplar. Kod içermez; yalnızca `theme.json` ve resim/ses dosyalarıdır.

```
Aurora.nxvtheme  (zip)
├── theme.json          zorunlu, zip'in kökünde (ya da tek bir üst klasörün içinde)
├── wallpaper.jpg       zorunlu, 1280×720 JPG/PNG/WebP
├── wallpaper-dark.jpg  isteğe bağlı: koyu görünümdeyken gösterilir
├── sounds/click.wav    isteğe bağlı: sistem seslerinin yerine (click, pop, notify, alarm, trash, shutter, error,
│                       key, volume, startup; olmayanlar sistemdekiyle çalar)
└── README.md           isteğe bağlı
```

```json
{
  "id": "com.sonerx7.theme.aurora",
  "name": {"en": "Aurora", "tr": "Kutup Işıkları", "de": "Polarlicht", "fr": "Aurore", "es": "Aurora"},
  "description": {"en": "Northern lights over a dark sky.", "tr": "Koyu gökyüzünde kuzey ışıkları."},
  "version": "1.0",
  "author": "Soner Çakır (sonerx7)",
  "appearance": "dark",
  "accent": "#3DDC97",
  "wallpaper": "wallpaper.jpg",
  "wallpaperDark": "wallpaper-dark.jpg",
  "sounds": "sounds",
  "settings": {"appearance.reduceTransparency": false, "dock.size": 56, "desktop.iconSize": 1}
}
```

| Alan | Tür | Açıklama |
|------|-----|----------|
| `id` | metin, zorunlu | Ters alan adı (`com.adiniz.tema`), en az bir nokta; `app.json` kimliğiyle aynı karakter kuralları. Güncellemeler bu kimlikle eşleşir. |
| `name`, `description` | metin veya dil tablosu | `en`, `tr`, `de`, `fr`, `es` önerilir; eksik dil İngilizceye düşer. |
| `version`, `author` | metin | Sürüm noktalı sayı olarak karşılaştırılır (Güncelle / Yeniden Yükle). |
| `appearance` | `"light"` \| `"dark"` \| `"auto"` | `appearance.mode` (0/1/2). Yoksa kullanıcınınki değişmez. |
| `accent` | `"#RRGGBB"` | Sekiz sistem renginden biriyse onun sırası, değilse özel renk (`appearance.accent` = 8, `appearance.accentCustom`). |
| `wallpaper` | dosya, zorunlu | Paketteki resim; `wallpaper` ayarı doğrudan bu dosyayı gösterir (kopyalanmaz). |
| `wallpaperDark` | dosya | Koyu görünüm açıkken gösterilir (`wallpaperDark` ayarı). Kullanıcı başka bir duvar kâğıdı seçince unutulur. |
| `sounds` | klasör | `<ad>.wav` dosyaları; `sound.theme` ayarı bu klasörü gösterir. |
| `settings` | nesne | Yalnızca aşağıdaki anahtarlar; diğerleri yok sayılır, sayılar aralığa sıkıştırılır. |

| `settings` anahtarı | Tür | Aralık (varsayılan) |
|---------------------|-----|----------------------|
| `appearance.reduceTransparency` | bool | Dock, menü çubuğu ve menüler opak (`false`) |
| `appearance.darkFrom`, `appearance.darkTo` | tamsayı | 0–23; `auto` görünümün koyu saatleri (19, 7) |
| `dock.size` | tamsayı | 40–80 piksel (54) |
| `dock.magnify` | bool | Dock büyütme (`true`) |
| `dock.magnification` | sayı | 1.0–2.0 (1.6) |
| `desktop.iconSize` | tamsayı | 0 küçük, 1 orta, 2 büyük (1) |
| `screensaver.style` | tamsayı | 0 şekiller, 1 yıldız yolculuğu, 2 saat (0) |

Kurallar ve davranış:

- En çok 64 dosya, toplam 32 MB, dosya başına 12 MB; izin verilen uzantılar `.json .jpg .jpeg .png .webp .wav .md
  .txt` (ve `manifest.sha256`, `manifest.sig`). `__MACOSX/` ve gizli dosyalar yok sayılır. Mutlak, `..`, `:` ya da
  `\` içeren bir yol paketi reddettirir (zip-slip koruması). Sınırlar hiçbir şey açılmadan denetlenir.
- Kurulum yeri `~/Library/Themes/<id>/` (`sdmc:/NexvynOS/Users/<ad>/Library/Themes/`). Önce gizli bir geçici klasöre
  açılır, orada yeniden doğrulanır, sonra yerine taşınır. Aynı kimlik = yerinde güncelleme; uygulanmış bir tema
  güncellenirse hemen yeniden uygulanır.
- Dosyalar'da bir `.nxvtheme` açılınca küçük bir sayfa (Tema Yükleyici) önizlemeyi, görünümü, vurgu rengini ve boyutu
  gösterir: **Yükle** ya da **Yükle ve Uygula**.
- *Sistem Ayarları > Görünüm > Temalar*: kartlara tıklamak uygular, sağ tık (X) kaldırır; **Varsayılanlara Dön**
  görünümü, vurgu rengini, duvar kâğıdını, sesleri ve yukarıdaki ayarları varsayılana döndürür (temalar silinmez).
  Temaların resimleri *Duvar Kâğıdı* bölmesinde de ayrı bir başlık altında listelenir.
- Kaldırılan tema kullanılıyorsa duvar kâğıdı ve sesler varsayılana döner; renkler olduğu gibi kalır.
- Uygulama Mağazası temaları aynı yoldan kurar (`themes::installPackage`, `themes::apply`).

## 10. Yazı tipi paketleri (.nxvfont)

> **Özet.** Bir `.nxvfont`; `font.json`, yazı tipi dosyalarını ve lisansı taşıyan bir zip'tir (`.nxvapp` ile aynı
> belirlenimci paket, `manifest.sha256` ile). Uygulama Mağazası onu `sdmc:/NexvynOS/System/Fonts/User/<id>/` altına
> kurar; Yazı Tipleri uygulaması ve uygulamaların yazı tipi menüleri onu hemen listeler.

```
Nunito.nxvfont  (zip)
├── font.json
├── Nunito-Regular.ttf
├── Nunito-Bold.ttf
├── Nunito-Italic.ttf
├── LICENSE            (zorunlu: OFL, Apache 2.0 ya da yeniden dağıtıma izin veren başka bir lisans)
└── manifest.sha256
```

```json
{
  "id": "nunito",
  "name": {"en": "Nunito"},
  "family": "Nunito",
  "version": "3.600",
  "license": "OFL-1.1",
  "styles": {"regular": "Nunito-Regular.ttf", "bold": "Nunito-Bold.ttf", "italic": "Nunito-Italic.ttf"},
  "scripts": ["Latn", "Cyrl"],
  "languages": ["en", "tr", "de", "fr", "es"],
  "cjk": "ja"
}
```

- `styles`; `regular` (zorunlu), `bold`, `italic` ve `semibold` stillerini `font.json`'un yanındaki dosyalara
  (`.ttf`, `.otf`, `.ttc`, `.otc`) bağlar. Pakette yalnızca yazı tipleri, `font.json`, `LICENSE*` / `OFL.txt` ve bir
  readme olur: çalışan hiçbir şey yoktur. En çok 40 dosya, dosya başına 40 MB, toplam 64 MB.
- `cjk` (`ja`, `ko`, `zh`) bir CJK paketini işaretler: regular yazı tipi, sistem yazı tiplerinde olmayan karakterleri
  çizer (`text::setPackFallbacks`); bu, sistemin paylaşılan yazı tipleri olmayan konsollarda ve emülatörlerde önemlidir.
- Katalog kaydı: `"kind": "font"`, `"category": "fonts"`, `download` (`.nxvfont`), `sha256`, `size`, `license` ve
  `styles` (stil adları, örneğin `["regular", "bold"]`). "Al" indirir, SHA-256'yı denetler ve kurar; ardından "Yüklü"
  (Yazı Tipleri uygulamasını onda açar) ve "Kaldır".
- Uygulamalar kurulu bir aileyi adıyla seçer: `fontpacks::font("Nunito", fontpacks::BOLD)` bir `text::` yazı tipi
  kimliği verir (`source/core/fontpacks.h`). Metin Düzenleyici kurulu aileleri yazı tipi menüsünde listeler.
- Yayın deposunda bir paket `Store/Fonts/<kısa-ad>/` altında durur (yazı tipi dosyaları, `LICENSE`, `font.json`,
  `store.json`, `icon.png`, `screenshots/`); `Tools/build_store.py` `<kısa-ad>.nxvfont` dosyasını ve katalog kaydını
  yazar.
