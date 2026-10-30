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
   veri erişimi yazılabilir belleğe düşer.
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
- Farklı ABI'li bir modül: yükleme reddedilir ("… Nexvyn OS x.y için yeniden derlenmesi gerekiyor"), Uygulama Mağazası yalnızca
  çalışan sistemin ABI'sine uyan modül kayıtlarını listeler, kurulu bir modülün ABI'si katalogdakinden farklıysa
  "Güncelle" çıkar.

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

`tools/modules.json` modül olacak uygulamaları ve kaynak dosyalarını listeler:

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

## 7. Bilinen sınırlar

- Güncellemeden önce gömülü olan ve şimdi modül olan uygulamalar (örneğin Haberler) güncellemeden sonra Mağaza'dan bir
  kez indirilmelidir; verileri (`Application Support/<id>`) korunur.
- Modülün servisleri (`REGISTER_SERVICE`) uygulama ilk açıldıktan sonra çalışmaya başlar.
- NRO'nun her derlemesi yeni bir ABI üretebilir: modüller sürümle birlikte yeniden yayımlanmalıdır
  (`build/modules/catalog.json`).

## 8. Sonuç (1.0.0)

- Modül olan uygulamalar: Renk Ölçer (`colorpicker`), Denetleyici Testi (`gamepad`), Yazı Tipleri
  (`fontbook`), Sözlük (`dictionary`), Döviz (`currency`), Haberler (`news` + `news_xml.cpp`), Yapışkan Notlar
  (`stickies`), Ağ (`network`). `sysinfo` "Bu Konsol Hakkında" tarafından açıldığı için gömülü kaldı.
- `NexvynOS.nro`: 53 563 001 bayt (modülsüz) → 52 854 061 bayt (modüllü), 709 KB küçük; kod+salt okunur veri
  (`.text` sütunu) 38 983 202 → 38 388 624 bayt. NRO 336 sembol dışa aktarır (birkaç KB). Paketler 51–131 KB.
- Kapatmak için: `tools/modules.json`'daki listeyi boşaltmak; uygulamalar yeniden NRO'ya gömülür (isteğe bağlı
  uygulama olarak).
- Emülatörde deneme: `build/modules/<id>.nxvapp` dosyasını `sdmc:/NexvynOS/Applications/` içine koyun (ya da
  Dosyalar'dan açıp kurun), uygulamayı açın ve güven sorusunu onaylayın (otomatik çalıştırmada:
  `set apps.trustedNative ["colorpicker"]`). Günlük: `nxvmod` etiketi ("loaded ... at ...", ya da hatanın nedeni).
