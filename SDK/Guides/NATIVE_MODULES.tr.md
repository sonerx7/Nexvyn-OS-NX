# Yerel modüller (.nxvmod): Uygulama Mağazası'ndan kurulan C++ uygulamaları

**Türkçe** · [English](NATIVE_MODULES.en.md)

> **İç mekanizma.** Yerel modüller yalnızca Nexvyn OS'un kendi isteğe bağlı C++ uygulamaları içindir ve her NRO
> sürümüyle birlikte yayın hattında yeniden derlenir. Üçüncü taraf geliştiricilerin platformu Lua, JavaScript ve
> Python'dur (korumalı alan, zorunlu izinler, kararlı API, Studio'da düzenlenebilir); C++ API'si her derlemede
> değişir ve bir SDK değildir.

Nexvyn OS'un C++ uygulamaları iki biçimde gelir:

1. **Sistemle gelen** (`NexvynOS.nro` içinde). Bunların bir kısmı *isteğe bağlıdır* (`app.json`'da `"optional": true`):
   kodları NRO'dadır ama kullanıcı Uygulama Mağazası'ndan (ya da Ayarlar > Uygulamalar'dan) "Al" diyene kadar hiçbir listede
   görünmezler. Bkz. bölüm 6.
2. **Yerel modül** (`.nxvmod`). Uygulama NRO'dan tamamen çıkar; derlenmiş kodu bir `.nxvapp` paketinin içinde
   Uygulama Mağazası'ndan indirilir ve Nexvyn OS onu çalışırken belleğe yükler. NRO gerçekten küçülür.

Bu belge ikinci biçimi anlatır.

## 1. Nasıl çalışır

Modül, uygulamanın kaynak dosyalarının Nexvyn OS ile **aynı derleyici ve bayraklarla** (yalnızca `-fPIE` yerine
`-fPIC`) derlenip bir AArch64 paylaşımlı nesneye (`-shared`) bağlanmasıdır. Tanımsız semboller (`ui::button`,
`theme::p`, `std::string` üyeleri, `malloc`...) açık bırakılır; bunları NRO sağlar.

Yükleyici (`source/runtimes/nxvmod.cpp`), uygulama ilk açıldığında:

1. Dosyayı okur, ELF başlığını ve `.nxvabi` bölümünü denetler (bölüm 3).
2. Salt okunur segmentleri (kod, `.rodata`, sembol tabloları) bir **CodeMemory** nesnesine koyar: RX görünümü modülün
   0 adresi olur, RW görünümü kodu yazmak için başka bir adrestedir. C uygulamalarındaki (TinyCC) JIT yaklaşımının
   aynısıdır ve Ryujinx'te de çalışır.
3. Yazılabilir segmentleri (`.data`, `.got`, `.init_array`, `.bss`) **ikinci bir CodeMemory** nesnesine koyar ve onu
   tam modülün beklediği adrese (RX görünümünün hemen arkasına) RW olarak eşler. Böylece kodun PC-göreli (`adrp`)
   veri erişimi yazılabilir belleğe düşer. `svcCreateCodeMemory` iki nesneyi de `0xFF` ile doldurur (konsolun çekirdeği
   böyle yapar, Ryujinx de aynısını), bu yüzden yükleyici iki görünümü **eşledikten sonra** temizler ve segmentleri
   ancak ondan sonra kopyalar: `.bss` ve aradaki boşluklar sıfır okunmalıdır. (1.2'ye kadar yükleyici kaynak sayfaları
   bu çağrıdan önce temizliyordu; `.bss` `0xFF` olarak geliyor, her fonksiyon içi statik değişkenin koruma baytı "zaten
   kuruldu" okunuyor ve uygulamalar `0xFF` baytlarından oluşan string ve mutex'lerde çöküyordu. 1.0.0'ın modülsüz
   çıkmasının sebebi buydu.)
4. Yeniden konumlandırmaları uygular: `R_AARCH64_RELATIVE`, `GLOB_DAT`, `JUMP_SLOT`, `ABS64` (ve varsa `RELR`).
   Bir sembol önce **NRO'nun kendi `.dynsym` tablosunda** aranır (NRO `_DYNAMIC` üzerinden kendi tablosunu okur),
   sonra modülün kendi tanımlarında: bir dinamik bağlayıcının "önce yürütülebilir dosya" kuralı. Böylece satır içi
   fonksiyonların statik değişkenleri gibi paylaşılan nesnelerin tek kopyası (NRO'nunki) kullanılır.
5. `.init_array`'i çalıştırır (çökme korumasının içinde): `REGISTER_APP` ve `REGISTER_SERVICE` uygulamayı sanki
   sistemle gelmiş gibi kaydeder. `.fini_array` Nexvyn OS kapanırken çalışır.

Modüller oturum boyunca bellekte kalır (kodlarına bağlı geri çağırmalar olabilir). Güncellenen bir modül dosyası
bir sonraki açılışta yeniden yüklenir; eski kod kapanışa kadar eşli kalır.

Yerel kod korumalı alanda çalışmaz: ilk açılışta kullanıcıya bir kez sorulur (Ayarlar anahtarı
`apps.trustedNative`, uygulama kimliklerinin dizisi). İzin sistemi (`permissions`) yerel koda uygulanamaz; bu yüzden
izin sorusu sorulmaz, `app.json`'daki liste yalnızca bilgi içindir.

Desteklenmeyenler: `thread_local` değişkenler (`PT_TLS`; modül reddedilir), metin yeniden konumlandırmaları
(`-fPIC` şart), C++ istisnaları ve RTTI (Nexvyn OS zaten `-fno-exceptions -fno-rtti` ile derlenir).

## 2. NRO tarafı: dışa aktarılan semboller

`-Wl,--export-dynamic` NRO'daki ~23.000 küresel sembolün hepsini dışa aktarır ve NRO'yu yaklaşık 2 MB büyütür
(modüllerin kazandırdığından fazla). Bu yüzden derleme yalnızca **modüllerin içe aktardıklarını** dışa aktarır:

- `build/modules/exports.list` (`-Wl,--export-dynamic-symbol-list`): modüllerin tanımsız sembolleri + modüllerin de
  tanımladığı zayıf/tekil nesneler (satır içi fonksiyon statikleri, şablon statikleri).
- `build/modules/exports.ld` (`EXTERN(...)`): NRO'nun kendisinin hiç kullanmadığı ama bir modülün istediği kütüphane
  üyelerini (libstdc++, newlib) bağlamaya zorlar.

Sonuç: birkaç yüz sembol, birkaç KB. Bunun bedeli, yeni bir modülün yeni bir sembole ihtiyacı olursa NRO'nun yeniden
derlenmesidir; ABI kimliği zaten her derlemede değiştiği için modüller her zaman NRO ile birlikte derlenir.

## 3. ABI kimliği

`ABI = FNV-1a 64( sıralı dışa aktarılan sembol adları, her biri "\n" ile + NEXVYN_VERSION )`, 16 onaltılık karakter.

- NRO bunu çalışırken kendi `.dynsym` tablosundan hesaplar (`nxvmod::abiId()`; dışa aktarılan sembol yoksa boştur ve
  hiçbir modül yüklenmez).
- `tools/build_modules.py` aynı değeri `NexvynOS.elf`'ten hesaplar ve her modüle `.nxvabi` bölümü olarak, paketin
  `app.json`'ına da `"abi"` olarak yazar.
- Farklı ABI'li bir modül hiçbir zaman yüklenmez. Açılınca bunu söyler ("… Nexvyn OS'un başka bir sürümü için
  hazırlanmış") ve aynı anda bu sistemin derlemesini otomatik kurulum kuyruğuna ekler (bölüm 7); derleme gelince
  uygulama yeniden açılır.
- Uygulama Mağazası **her Nexvyn OS sürümü için ayrı bir derleme** tutar: katalogdaki yerel girişin `"builds"` dizisi
  vardır (`{"nexvyn", "abi", "version", "download", "sha256", "size"}`) ve her konsol `abi`'si kendisininki olan
  derlemeyi alır. Eski bir konsol, yenileri yayımlandıktan sonra da kendi derlemesini bulmaya devam eder; uyan derlemesi
  olmayan konsol uygulamayı listelemez, uygulama kendisine gömülü olan konsol `"builds"`'i yok sayar. Girişin üst düzeyi
  1.2 öncesi konsolların anladığı biçimde kalır (onların isteğe bağlı uygulama olarak taşıdığı uygulamalar için
  `"builtin": true`), böylece mağaza sayfaları orada çalışmaya devam eder; üst düzeyde asla `"runtime": "native"`
  yazmaz, eski bir konsol onu gizlerdi.
- Sistem güncellemesinden sonra eski ABI'li her kurulu modül ilk açılışta kuyruğa eklenir (`osupdate`); kullanıcının
  güncelleme araması gerekmez. Uygulama Mağazası'ndaki "Güncelle" aynısını elle yapar.

## 4. Paket biçimi

```
colorpicker.nxvapp
├── app.json            "native": "colorpicker.nxvmod", "abi": "<16 hex>", "permissions": [...]
├── colorpicker.nxvmod  hata ayıklama bilgisi atılmış paylaşımlı nesne + .nxvabi bölümü
├── icon.png
├── lang/en.json, tr.json, de.json, fr.json, es.json
└── manifest.sha256
```

`app.json`'un geri kalanı (`id`, `name`, `window`, `fileTypes`...) sistemle gelen uygulamanınkiyle aynıdır;
`"native": true` ve `"optional"` yoktur. `tools/nxvapp_pack.py` bu biçimi kabul eder (`"native"` bir `.nxvmod`
dosyasını göstermeli ve `"abi"` olmalıdır). Kurulum, güncelleme ve kaldırma diğer paketlerle aynıdır.

## 5. Derleme

`tools/modules.json` (ya da `NXVMOD_LIST` ortam değişkeninin adını verdiği dosya:
`NXVMOD_LIST=tools/modules.full.json ./build.sh`) modül olacak uygulamaları ve kaynak dosyalarını listeler:

```json
{"modules": [{"id": "news", "sources": ["source/apps/app_news.cpp", "source/apps/news_xml.cpp"], "permissions": ["network", "launch"]}]}
```

`./build.sh` gerisini yapar:

| Adım | Ne yapar |
|---|---|
| `python tools/build_modules.py prepare` | `build/modules/modules.mk` (kimlikler, kaynaklar, make kuralları) |
| `make modules` | `-fPIC` nesneler ve `build/modules/<id>.so` |
| `python tools/build_modules.py exports` | `exports.list` ve `exports.ld` |
| `python tools/build_modules.py romfs` | `build/romfs`: modül uygulamalarının paketleri olmadan romfs (sabit bağlantılar) + `System/Modules.json` ve `System/Modules/<id>.png` |
| `make ROMFS=build/romfs` | modül kaynakları hariç `NexvynOS.nro` |
| `python tools/build_modules.py package` | her içe aktarımı denetler, ABI'yi yazar, `build/modules/<id>.nxvapp` ve `build/modules/catalog.json` |

Uygulamanın paketi kaynakta `romfs/Applications/<id>.app` olarak kalır (simge, `lang/`, `app.json`); yalnızca NRO'nun
romfs'una girmez. Bir uygulamayı yeniden sisteme gömmek için `tools/modules.json`'dan çıkarmak yeterlidir.

Liste `"bundles"` da verebilir: `romfs/Applications`'taki script uygulamaları (örnek uygulamalar) NRO'nun romfs'undan
çıkar ve sıradan Uygulama Mağazası paketleri olur (`build/modules/<id>.nxvapp`, ABI'siz). Modüller gibi
`System/Modules.json`'da listelenirler; aynı yer tutucular ve güncellemeden sonra aynı otomatik geri dönüş onlar için de
geçerlidir.

Ayrım kademelidir ve yalnızca listeyle açılıp kapanır. `tools/modules.json` **1.2.0'da boştur** (yalnızca NRO'yu
çıkaran, Mağaza değişikliği olmayan bir beta): her uygulama gömülü kalır, `System/Modules.json` oluşmaz; bu yüzden
Önerilen Paketler adımı, Başlatıcı yer tutucuları ve güncelleme taşıması devreye girmez. Mağaza derlemeleriyle birlikte
açılmaya hazır olanlar (`tools/store_pending/README.md`):

- `tools/modules.lowrisk.json`: küçük ve kendi içinde kapalı uygulamalar (Renk Ölçer, Denetleyici Testi, Yazı Tipleri,
  Sözlük, Döviz, Yapışkan Notlar, Gösteri), ilk adım.
- `tools/modules.full.json`: görev planının tam ayrımı (32 C++ uygulaması ve 9 örnek uygulama), konsol testinden sonra.
  `_kept_in_nro` notu neyin gömülü kaldığını ve nedenini listeler.

İkisi de derlenir, Ryujinx'te yüklenir ve çalışır (bölüm 10).

`romfs:/System/Modules.json` modül uygulamalarının adını, kategorisini ve simgesini taşır: kurulu olmayan bir modül
uygulaması kayıtta "yalnızca mağaza" yer tutucusu olur; Hızlı Arama "… Uygulama Mağazası'ndan al" der, masaüstü kısayolları soluk
ve indirme rozetli görünür, `os::launch` ve `nxv://app/` bağlantıları Uygulama Mağazası sayfasını açar.

Modül adayı seçerken: `REGISTER_SERVICE` kullanan (açılmadan çalışması gereken) uygulamalar, başka sistem kodunun
çağırdığı fonksiyonları tanımlayan dosyalar, Studio'nun bağımlılıkları (`code`, `console`, `aichat` ve yardımcıları) ve
"Bu Konsol Hakkında" gibi sistem işlevlerinin açtığı uygulamalar (`sysinfo`) gömülü kalmalıdır.

## 6. İsteğe bağlı gömülü uygulamalar ve katalog

`app.json`'da `"optional": true` olan gömülü uygulamalar ayarlar dizisi `apps.optionalEnabled`'da kimlikleri olana
kadar "kurulu değil" sayılır (`registry::installed`, `registry::listed`, `registry::enableOptional`,
`registry::disableOptional`). Önceki sürümden güncelleyen sistemlerde hepsi bir kez açılır (`apps.optionalV1`).

Katalog kayıtları:

```json
{"id": "paint", "builtin": true, "name": {...}, "subtitle": {"en": "...", "tr": "...", "de": "...", "fr": "...", "es": "..."},
 "description": {...}, "category": "media", "icon": "https://.../paint.png", "screenshots": ["...", "...", "..."]}

{"id": "news", "runtime": "native", "abi": "<16 hex>", "version": "1.0", "download": "https://.../news.nxvapp",
 "sha256": "...", "size": 134144, "name": {...}, "subtitle": {...}, "description": {...}, "category": "internet",
 "icon": "https://.../news.png", "screenshots": [...]}
```

`builtin` kayıtlarda indirme, `sha256` ve boyut yoktur; çalışan sistemde o kimlikte bir uygulama yoksa kayıt gizlenir.
Katalogda olmayan isteğe bağlı uygulamalar için Mağaza `app.json`'dan yerel bir sayfa üretir (çevrimdışı da açılır).
`subtitle` en çok 45 karakterlik tek satırlık tanıtımdır.

## 7. Otomatik kurulum, güncelleme ve hatalar

**Kurulum kuyruğu** (`source/apps/appstore_auto.h`, ayar dizisi `apps.autoInstall`): sistem Uygulama Mağazası
uygulamalarını pencere açmadan ve soru sormadan kendisi kurar. Bir arka plan servisi açılıştan 8 sn sonra başlar,
konsol çevrimdışıyken bekler (30 sn'de bir bakar), kataloğu yükler, bu sistemin derlemesini seçer, indirir, her Uygulama
Mağazası indirmesi gibi denetler (SHA-256, imza, App Guard) ve kurar. Hata günlüğe yazılır ve 1, 2, 4 … en çok 30 dakika
sonra yeniden denenir; katalogda henüz olmayan bir uygulama bir sonraki katalog alımında aranır. Bir kayıt ancak uygulama
kurulduğunda ve modülse bu ABI için derlenmişse kuyruktan çıkar. Değişmiş imza anahtarı ya da App Guard'ın tehlikeli
dediği bir paket bu yolla asla kurulmaz. Kuyruk boşalınca tek bir bildirim kaç uygulamanın geldiğini söyler. Nexvyn
OS'un kendi modülleri (`System/Modules.json`'daki kimlikler) Uygulama Mağazası'ndan kurulunca hemen güvenilir sayılır
(`apps.trustedNative`); başka yerden gelen bir modül ilk açılışta yine sorar.

**Uygulamayı gömülü taşıyan bir sürümden güncelleme** (`registry.cpp`, `migrateModules`): yeni sürümün ilk
açılışında `System/Modules.json`'daki ve kullanıcının kullandığı her uygulama kuyruğa eklenir (`upgrade`). Kullanılmış
= Dock'a, görev çubuğuna ya da Başlat'a sabitlenmiş, son uygulamalarda ya da açılış sayılarında olan, isteğe bağlı
uygulama olarak eklenmiş ya da herhangi bir kullanıcının `Library/Application Support/<id>` klasöründe verisi olan.
Gelene kadar uygulama Başlatıcı'da "İndiriliyor…" yer tutucusu olarak bekler (soluk simge, ilerleme halkası,
çevrimdışıyken bulut); açılınca indirildiğini söyleyen bir pencere çıkar. Hiçbir şey silinmez ya da yeniden yazılmaz:
sabitlemeler, ayarlar ve veriler olduğu gibi kalır ve modül kurulduğu anda yeniden çalışır. Her kimliğe bir kez bakılır
(`apps.modulesHandled`), böylece daha fazla uygulamayı taşıyan sonraki bir sürüm yalnızca onları ele alır. Yeni bir
konsol aynı uygulamaları kurulum yardımcısının **Önerilen Paketler** adımından alır (Ofis, Medya, Modlama, Araçlar,
Retro ve Demolar; yalnızca bu derlemenin modüllerini içeren paketler görünür, başta hepsi seçilidir, Atla hiçbirini
seçmez). Seçilen uygulamalar kurulumun sonunda kuyruğa eklenir; çevrimdışıysa bir bildirim konsol çevrimiçi olunca
geleceklerini söyler.

**Bir modül çalışamadığında** uygulama bir pencere gösterir ve masaüstü devam eder: başka ABI (doğru derleme indirilir,
bölüm 3), yükleme hatası (Tekrar Dene / Yeniden Yükle / Vazgeç) ya da 3 çökmeden sonra kapatılmış. Çökmeler modül
dosyası başına sayılır (ayar `apps.moduleCrashes`): penceresinde yalıtılan bir hata, kurucularında bir çökme ya da onun
içinde biten bir oturum. Üçüncüsü uygulamayı Yeniden Yükle düğmesiyle kapatır; yeni bir dosya (yeniden yükleme ya da
güncelleme) sayımı sıfırlar. Yeniden Yükle uygulamayı `force` ile kuyruğa ekler, verilerini korur ve Uygulama Mağazası
sayfasını açar. Bu yolda açılışta çalışan tek şey kuyruğun servisidir ve hiçbir şeyi bekletmez: ağın ya da kataloğun
olmaması yalnızca indirmeleri geciktirir.

## 8. Bilinen sınırlar

- Modülün servisleri (`REGISTER_SERVICE`) uygulama ilk açıldıktan sonra çalışmaya başlar. Açılmadan çalışması gereken
  servisleri olan uygulamalar (alarmlar, anımsatıcılar, takvim uyarıları, PC sunucusu) gömülü kalır.
- NRO'nun her derlemesi yeni bir ABI üretebilir: modüller sürümle birlikte yeniden yayımlanmalıdır
  (`build/modules/catalog.json`, her modülün `"builds"` dizisine bir kayıt daha).
- Modüller bellekten atılmaz; güncellenen bir modül bir sonraki açılışta eski kodun yanına yüklenir.

## 9. Sonuç (1.0.0)

- Modül olan uygulamalar: Renk Ölçer (`colorpicker`), Denetleyici Testi (`gamepad`), Yazı Tipleri
  (`fontbook`), Sözlük (`dictionary`), Döviz (`currency`), Haberler (`news` + `news_xml.cpp`), Yapışkan Notlar
  (`stickies`), Ağ (`network`). `sysinfo` "Bu Konsol Hakkında" tarafından açıldığı için gömülü kaldı.
- `NexvynOS.nro`: 53 563 001 bayt (modülsüz) → 52 854 061 bayt (modüllü), 709 KB küçük; kod+salt okunur veri
  (`.text` sütunu) 38 983 202 → 38 388 624 bayt. NRO 336 sembol dışa aktarır (birkaç KB). Paketler 51–131 KB.
- Kapatmak için: `tools/modules.json`'daki listeyi boşaltmak; uygulamalar yeniden NRO'ya gömülür (isteğe bağlı
  uygulama olarak).
- Emülatörde deneme: `build/modules/<id>.nxvapp` dosyasını `sdmc:/NexvynOS/Applications/<id>.nxvapp/` klasörüne açın
  (ya da Dosyalar'dan açıp kurun; Applications'a bırakılan `<id>.nxvapp` adlı zip açılmaz), uygulamayı açın ve güven
  sorusunu onaylayın (otomatik çalıştırmada: `set apps.trustedNative ["colorpicker"]`). Günlük: `nxvmod` etiketi
  ("loaded ... at ...", ya da hatanın nedeni).

## 10. Sonuç (1.2)

- Yükleyici düzeltildi (bölüm 1): 1.0.0'ın 8 uygulaması Ryujinx'te yüklenip çalışıyor, `tools/modules.lowrisk.json`'daki her
  modül 3 aç/kapa turunu ve aynı anda açılan 5 modülün başka sırayla kapatılıp yeniden açılmasını geçiyor,
  `tools/modules.full.json`'daki 41 paketin her biri ikişer kez açılıp kapanıyor.
- CPython ve retro çekirdekleri olmadan ölçüldü (`NexvynOS.nro`, bayt):

| | NRO | kod bölümü | romfs | paketler |
|---|---|---|---|---|
| önce (her uygulama gömülü) | 63 488 321 | 42 958 848 | 20 494 444 | – |
| `tools/modules.lowrisk.json` (7 modül) | 62 900 625 (−574 KB) | 42 549 248 | 20 316 348 | 7, 519 KB |
| `tools/modules.full.json` (32 modül, 9 paket) | 58 898 793 (−4,4 MB) | 39 727 104 | 19 136 660 | 41, 3,3 MB |

- Çıkan 1.2.0 (`tools/modules.json` boş): 63 552 661 bayt, her uygulama eskisi gibi gömülü; fazladan 64 KB yeni
  yükleyici, kuyruk, kurulum adımı ve metinlerdir. 1.1.2'deki 69 C++ uygulamasının aynısı kaydolur.
- NRO düşük riskli listeyle 306, tam ayrımla 751 sembol dışa aktarır. Temiz `JOBS=8 ./build.sh` önce 230 sn, düşük riskli listeyle
  204 sn sürdü (aynı makine, başka işler de çalışıyordu: gürültü içinde). Ryujinx'te ilk masaüstü karesine açılış: önce
  8,5–8,7 sn, sonra 7,3–9,1 sn (ölçülebilir fark yok).
