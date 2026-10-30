# Nexvyn OS — Yeni dil desteği: araştırma ve kararlar (SDK 1.5)

**Türkçe** · [English](LANGUAGE_SUPPORT.en.md)

Bu belge, Lua / JavaScript / Python (pocketpy) dışındaki dillerle `.nxvapp` uygulaması yazılabilmesi için yapılan
araştırmayı ve verilen kararları özetler. Önceki fizibilite kararları bir iç değerlendirmeden gelir (C3 TinyCC,
C4 Java ertelendi, MicroPython yerine pocketpy). Bu çalışmada o kararlar yeniden ele alındı ve üç yeni çalışma zamanı
eklendi: **Squirrel**, **C (TinyCC)** ve **Java (miniJVM)**. Python tarafında CPython yerine pocketpy'ye bir sistem
kütüphanesi eklendi.

## 1. Özet tablo

| Dil | Seçenek | Lisans | Durum | `app.json` `"runtime"` |
|---|---|---|---|---|
| Python | pocketpy 2 (mevcut) + `romfs:/System/Python` sistem kütüphanesi | MIT | **Var**, genişletildi | `"python"` |
| Python | CPython 3.12 statik derleme (`tools/build_cpython.sh`) | PSF | **1.0.0'da eklendi** (bölüm 3'teki plan uygulandı; konsol testi bekliyor) | `"python3"` |
| Python | MicroPython | MIT | Reddedildi (pocketpy daha uyumlu, Switch portu yok) | — |
| C | TinyCC 0.9.28rc (konsolda derleme, JIT bellek) | LGPL-2.1 | **Eklendi** | `"c"` |
| C++ | Tam derleyici | — | Gerçekçi değil (clang/gcc onlarca MB, saniyeler süren derleme) | — |
| C++ benzeri | Squirrel 3.2 | MIT | **Eklendi** (C++'a benzeyen sözdizimi, sınıflar) | `"squirrel"` |
| C++ benzeri | AngelScript / ChaiScript | zlib / BSD-3 | Değerlendirildi, Squirrel seçildi | — |
| Java | miniJVM 2.2.0 (yorumlayıcı, Java 8 sınıf dosyaları) | MIT (C), çalışma zamanı jar'ı GPLv2 + yazar istisnası | **Eklendi** | `"java"` |
| Java | JamVM, Avian, CACAO | GPLv2 / ISC / GPLv2 | Reddedildi (bakımsız, GNU Classpath ya da OpenJDK sınıf kütüphanesi gerekir) | — |
| Diğer | Wren, Berry, Janet, Fennel, Teal | MIT | Değerlendirildi; ortak katman sayesinde ileride eklemesi kolay | — |

## 2. Ortak mimari: tek SDK uygulaması, ince dil bağlayıcıları

Mevcut üç çalışma zamanı SDK'nın her fonksiyonunu ayrı ayrı bağlar (her biri ~2500 satır). Yeni diller için önce dile
bağımsız bir katman yazıldı: `source/runtimes/nxvrt.h/.cpp/_api.cpp`.

- `nxvrt::Value`: nil, bool, sayı, metin, liste, sözlük, geri çağırma (fonksiyon referansı), mesh.
- `nxvrt::api()`: SDK'nın tüm fonksiyonları (`gfx`, `ui`, `g3d`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`,
  `timer`, `TR`) bir kez, Python çalışma zamanıyla aynı davranışla yazıldı.
- `nxvrt::ScriptApp`: uygulama yaşam döngüsü (load/update/draw/event/menu/close, SDK 1.4 geri çağırmaları, zamanlayıcılar,
  asenkron sonuçlar, store, Hızlı Arama, hata ekranı, 3 saniye sınırı).

Bir dil eklemek artık yalnızca değer dönüşümü + birkaç sanal fonksiyon demek (Squirrel ~450, Java ~250 satır C++).
Kurallar Python'unkilerle aynı: 0 tabanlı indeksler, çoklu sonuçlar liste (`[w, h] = gfx.size()`), asenkron çağrılar
geri çağırma alır, `ui.textfield` metni döndürür ve `ui.submitted(id)` Enter'ı bildirir.

## 3. Python: CPython mı, pocketpy mi?

### Mevcut portlar
- **PyNX / nx-python**: CPython 3.5 portu, hbmenu'den `main.py` çalıştırır; son sürüm 0.6.0-alpha (Ağustos 2019),
  iş parçacıkları ve `signal` modülü eksikti, proje bakımsız. Kaynak: <https://github.com/nx-python/PyNX>,
  <https://gamebrew.org/wiki/PyNX_Switch>, <https://nx-python.readthedocs.io/>.
- **Ren'Py Switch portu** (Python 2.7 tabanlı, statik bağlı): arşivlenmiş. Kaynak:
  <https://lemmasoft.renai.us/forums/viewtopic.php?p=530030>.
- **MicroPython**: devkitPro için bir Switch portu bulunamadı. pocketpy daha geniş Python 3 sözdizimi sunuyor (f-string,
  `match`, sınıflar, dekoratörler), bu yüzden önceki karar geçerli.

### CPython 3.x'i devkitA64'e taşımak ne gerektirir
1. **Çapraz derleme**: `configure --host=aarch64-none-elf` newlib'i tanımaz; `pyconfig.h` elle yazılmalı
   (`HAVE_FORK`, `HAVE_DLOPEN`, `HAVE_MMAP`, sinyaller, `getpwnam`, alt süreçler kapalı). PyNX bunu 3.5 için yamalarla yaptı;
   3.12+ için `Modules/Setup.local` ile tüm uzantı modülleri statik listelenmeli, `_posixsubprocess`, `_socket`'in bir
   kısmı, `mmap`, `_ctypes` (libffi aarch64 bare-metal), `_ssl` (OpenSSL yerine mbedtls olmaz) çıkarılmalı.
2. **Boyut** (tahmin, aarch64 `-Os` ve strip ile): `libpython3.x.a` ~4–6 MB kod; saf Python standart kütüphanesi
   sıkıştırılmış zip olarak ~8–12 MB (test paketleri hariç), asgari bir alt küme ~3 MB. NRO'ya gömülürse romfs büyür;
   bu yüzden paket yöneticisiyle (`nxvpkg`) ayrı indirilebilir bir paket olarak dağıtılması önerilir.
3. **Bellek**: boş bir yorumlayıcı ~8–15 MB, `import` edilen her modülle artar. Pencere başına 64 MB sınırı ile aynı anda
   birden fazla CPython uygulaması zor; alt yorumlayıcılar (PEP 684, 3.12+) her pencereye ayrı durum verebilir.
4. **Zaman sınırı**: `PyErr_SetInterrupt` / `Py_AddPendingCall` ile her geri çağırmaya 3 saniye uygulanabilir.
5. **Süre**: tek bir oturumda güvenilir şekilde tamamlanamayacak kadar büyük (yama + test, cihazda deneme); bu yüzden
   bu sürümde yapılmadı.

### Yapılan: pocketpy uyumluluğunu genişletmek
`import x`, paket içinde bulunamayan modülleri artık `romfs:/System/Python/x.py` içinde arar. Eklenen modüller CPython
API'lerini pocketpy'nin desteklediği alt kümede uygular ve sonuçları CPython ile karşılaştırılarak test edildi:
`itertools`, `string` (sabitler, `capwords`, `Template`), `textwrap`, `copy`, `statistics`, `base64`, `colorsys`.
`python tools/py_check.py` bu dosyaları da konsol uyumluluğu için denetler.

## 4. C: TinyCC ile konsolda derleme

- **TinyCC** (<https://repo.or.cz/tinycc.git>, mob dalı 0.9.28rc, LGPL-2.1): arm64 kod üreticisi var, `libtcc` ile
  bellekte derleme yapar. Bir uygulamanın tüm `.c` dosyaları pencere açılırken birkaç yüz milisaniyede derlenir.
- **JIT belleği**: libnx `jitCreate` iki yol sunar: `svcSetProcessMemoryPermission` ve [4.0.0+] `svcCreateCodeMemory` /
  `svcControlCodeMemory` (bir görünüm RW, diğeri R-X). Kaynak: <https://switchbrew.github.io/libnx/jit_8h.html>,
  SVC tablosu <https://switchbrew.org/w/index.php?diff=4091>. 5.0.0'dan sonra `svcControlCodeMemory` aynı süreçte
  çağrılınca hata verir; Atmosphère çekirdek yamasıyla bunu homebrew için gevşetir ("kernel patches for JIT support",
  Atmosphère changelog: <https://git.nold.in/nold/Atmosphere/raw/commit/be772b40e1f12680597c4ad27548c9c08d7d877a/docs/changelog.md>).
  Homebrew yükleyicisi kullanılabilir sistem çağrılarını `envIsSyscallHinted(0x4B/0x4C)` ile bildirir; Nexvyn OS bu
  ipucu yoksa anlaşılır bir hata gösterir.
- **Neden kendi eşleme kodumuz**: TinyCC global verilere PC'ye göreli (`adrp`, ±4 GB) erişir. libnx `jitCreate` RW ve RX
  görünümlerini birbirinden bağımsız rastgele adreslere koyar; aradaki mesafe 4 GB'ı aşabilir. Nexvyn OS tek bir
  CodeMemory nesnesini RW ve RX olarak **yan yana** eşler ve TinyCC'nin SELinux için yazılmış "iki görünüm" yolunu
  (`tcc_relocate_ex(rx, rw - rx)`) kullanır.
- **TinyCC'ye yapılan değişiklikler** (işaretli, 4 adet): `sys/mman.h` yok; `protect_pages` Switch'te iş yapmaz (önbellek
  bakımı JIT tarafında); RW–RX mesafesi 64 bit; yol listeleri `;` ile ayrılır (`romfs:/` cihaz adları `:` içerir).
- **SDK**: `romfs:/System/C/include/nexvyn.h` (Lua/Python SDK'sının alt çizgili hali: `gfx_rect`, `ui_button`...) ve
  newlib'e bağlanan küçük bir libc (`stdio.h`, `stdlib.h`, `string.h`, `math.h`, `ctype.h`...). `malloc` sayılır (64 MB),
  `printf` uygulama günlüğüne yazar. arm64 `long double` aritmetiği libgcc'den bağlanır.
- **Sınırlar**: yerel kod korumalı alanda değildir ve sonsuz döngü durdurulamaz; bu yüzden üçüncü taraf C uygulamaları
  ilk açılışta kullanıcıya bir kez sorulur (`apps.trustedC`). Emülatörde (Ryujinx) çalışması CodeMemory desteğine bağlıdır.
- **Lisans**: LGPL-2.1 statik bağlamada kullanıcının kütüphaneyi değiştirip yeniden bağlayabilmesini ister. Kaynak kod
  açık olduğundan (proje herkese açıldığında) bu koşul sağlanır; kapalı kaynak bir dağıtımda nesne dosyaları da
  verilmelidir (`THIRD_PARTY_NOTICES.md`).

## 5. C++ seçenekleri

Konsolda gerçek bir C++ derleyicisi (clang/gcc) çalıştırmak, boyut (onlarca MB), bellek ve derleme süresi nedeniyle
gerçekçi değil. C++'a yakın betik dilleri incelendi:

| Dil | Lisans | Artı | Eksi |
|---|---|---|---|
| **Squirrel 3.2** | MIT | C++/JS'e benzeyen sözdizimi, sınıflar, kalıtım, üreteçler, tamsayı/kayan nokta ayrımı, küçük (~240 KB kod), oyun motorlarında yaygın | Gömülü kullanımı biraz eski API |
| AngelScript | zlib | C++'a en yakın (statik tipler) | Her SDK fonksiyonu için tip imzası gerekir, daha büyük |
| ChaiScript | BSD-3 | Başlık dosyası olarak gömülür | Ağır şablon kodu, istisna (exception) ister, derleme süresi uzun; proje `-fno-exceptions` |

**Squirrel** seçildi. `sqvm.cpp`'ye tek işaretli bir değişiklik yapıldı: her geri dallanmada (yani her döngüde) ana
sistem 3 saniye ya da 64 MB aşıldı mı diye sorulur ve aşıldıysa hata fırlatılır.

## 6. Java

| Seçenek | Durum | Not |
|---|---|---|
| **miniJVM** (<https://github.com/digitalgust/miniJVM>) | **Seçildi** | C VM'i MIT; Java 8 sınıf dosyaları, lambda, yansıma, iş parçacıkları; sınıf kütüphanesi `minijvm_rt.jar` (GPLv2, yazarın "sürümdeki jar ikilisini kullanmak bulaşıcı GPL'den kaçınmayı sağlar" istisnası) |
| JamVM | Reddedildi | GPLv2, GNU Classpath ya da OpenJDK sınıf kütüphanesi gerektirir (yüzlerce MB) |
| Avian | Reddedildi | Arşivlenmiş, OpenJDK kütüphanesiyle büyük |
| CACAO, Kaffe | Reddedildi | Bakımsız, GPL |

Switch için yapılanlar (`lib/minijvm`, işaretli `__SWITCH__` değişiklikleri): Linux kod yolları, mimalloc yerine düz
malloc, yalnızca yorumlayıcı (sljit JIT kapalı), `dlopen` yok, Java soketleri ve TLS yok (uygulamalar `network` iznine
uyan `nexvyn.Net`'i kullanır), yığın parçaları `mmap` yerine malloc'tan, tinycthread'in fonksiyonları newlib'in C11
thread fonksiyonlarıyla çakışmasın diye yeniden adlandırıldı, ve yorumlayıcıdaki her geri dallanmada 3 saniye sınırı
kontrolü (`NEXVYN_JVM_INTERRUPT`). Release 2.2.0'ın `minijvm_rt.jar`'ı olduğu gibi kullanıldı.

**Java SDK**: `sdk/java/nexvyn` (App, Gfx, Ui, Sys, Net, Store...); SDK sınıfları `tools/gen_java_sdk.py` ile ortak
fonksiyon tablosundan üretilir, yani Java her zaman SDK'nın tamamına sahiptir. Değerler JSON metni olarak sınırı geçer.
**PC tarafı**: `python tools/java_build.py app MyApp.nxvapp` kaynakları miniJVM'in sınıf kütüphanesine karşı derler
(konsolda olmayan bir API PC'de hata verir) ve `app.jar` üretir.

**Sınırlar**: miniJVM süreç başına tek VM tutar, bu yüzden aynı anda bir Java uygulaması çalışır. Java'nın kendi sınıf
kütüphanesi (`java.io` dosyaları, `sun.misc.Unsafe`) izinlerin dışına çıkabildiği için Java uygulamaları da ilk açılışta
bir kez sorulur (`apps.trustedJava`). Yorumlayıcı Lua/JS'ten yavaştır; çizim yoğun oyunlar için Lua önerilir.

## 7. Diğer küçük diller

| Dil | Lisans | Değerlendirme |
|---|---|---|
| Wren | MIT | Çok küçük, sınıf tabanlı; ancak foreign metotlar Wren tarafında imzayla bildirilmeli (üretici betikle çözülebilir) |
| Berry | MIT | Python benzeri, gömülü sistemler için; pocketpy zaten bu boşluğu dolduruyor |
| Janet | MIT | Lisp ailesi, güçlü; kitle küçük |
| Fennel | MIT | Lua'ya derlenen Lisp; mevcut Lua çalışma zamanı üzerinde `fennel.lua` ile eklenebilir (C++ gerekmez) |
| Teal | MIT | Tipli Lua; PC'de Lua'ya derlenir, ek çalışma zamanı gerektirmez |

Ortak `nxvrt` katmanı sayesinde bunlardan biri, değer dönüşümü ve yaşam döngüsü kancalarıyla birkaç yüz satırda
eklenebilir.

## 8. Ölçümler (bu derleme)

| Bileşen | Kod (`.text`) | romfs |
|---|---|---|
| Squirrel çekirdek + std (sqvm_build) | ~238 KB | — |
| TinyCC (tcc_build) | ~281 KB | C başlıkları ~65 KB |
| miniJVM (jvm_build) | ~446 KB | `minijvm_rt.jar` 1,4 MB + `nexvyn.jar` 27 KB |
| Ortak katman + bağlayıcılar (nxvrt, sqapp, capp, javaapp) | ~330 KB | — |
| Python sistem kütüphanesi | — | ~84 KB |

## 9. Arayüz dilleri: Japonca, Çince ve Korece

Nexvyn OS 1.0, programlama dillerinin yanında üç arayüz dili ekler: **ja** (日本語), **zh** (简体中文, Basitleştirilmiş
Çince) ve **ko** (한국어). Bunlar `romfs/System/Languages/<code>/` (`_meta.json` + modül dosyaları) ve uygulama
paketlerinin `lang/<code>.json` dosyalarında kısmi paketlerdir; eksik bir metin İngilizceye fallback yapar.
`zh-Hans` / `zh-CN` diline ayarlı bir konsol `zh` ile, `ja` olan `ja` ile, `ko` olan `ko` ile açılır (`main.cpp`
pickLanguage).

- **Yazı tipleri.** NRO'da da repoda da CJK yazı tipi yok. `text.cpp`, Inter / JetBrains Mono'da olmayan karakterleri
  konsolun **shared font**'larıyla (pl:u) çizer: Standard (Japonca), ChineseSimplified + ExtChineseSimplified,
  ChineseTraditional, KO ve NintendoExt (tuş sembolleri). Han karakterleri arayüz dilinin bölgesel biçimini alır
  (ja → Standard, zh → ChineseSimplified, ko → KO), arayüz CJK değilse konsol dilininkini. Glyph'ler Latin yazı
  tipinin baseline'ına hizalanır. Emülatörler shared font'ları kurulu firmware'den verir.
- **Shared font yoksa** (firmware yazı tipleri olmayan bir emülatör) SD karttaki bir **font pack** kullanılır:
  `sdmc:/NexvynOS/System/Fonts/` (ayrıca `System/Library/Fonts/`). Bölgeyi dosya adı söyler:
  `NotoSansCJK-Regular.ttc` (koleksiyon: JP, KR, SC, TC yüzleri), `NotoSansJP-Regular.ttf`, `NotoSansKR-…`,
  `NotoSansSC-…`, `NotoSansTC-…`, `SourceHanSans…`. Dosya belleğe okunmaz, FreeType onu karttan stream eder. İkisi
  de yoksa CJK karakterler `?` görünür. Ayarlar > Dil ve Bölge, kaynağı gösterir ("CJK yazı tipi").
- **Satır kırma.** `text::wrapLines` ve web layout iki ideogram / kana arasında satır kırabilir; kapanış
  noktalamasından (、。」） küçük kana, ー) önce ve açılış noktalamasından (「（) sonra asla kırmaz (kinsoku).
  Hangul arayüzde kelimeleri bölmez (Korece boşlukla yazılır); web sayfaları onu CSS `word-break: normal` gibi her
  yerden kırar.
- **Giriş.** Ekran klavyesinde **Korece 2-set** (jamo'lar yazarken heceye birleşir, Backspace son jamo'yu geri alır)
  ve **Japonca romaji** (romaji → hiragana; Shift / caps lock → katakana) düzenleri var. Kanji, hanzi ve Çince pinyin
  **Nintendo sistem klavyesinden** (swkbd) gelir; dilin gerektirdiği klavye türüyle (Korece, Basitleştirilmiş Çince,
  Japonca için tüm diller) IME tuşu (CJK arayüzde ya da düzende görünür), klavye menüsü ya da metin düzenleme
  balonu açar. swkbd applet modunda açılamaz: bir bildirim bunu açıklar.
- **Biçimler.** Tarihler `date.json`'dan gelir (`format_long`, `format_short`, `menubar`, ay ve gün adları); 12 saatlik
  saatler `date.am`, `date.pm` ve `date.time_12h`'dan (`"{ap}{t}"` → 午後9:05).
- **Uygulama Mağazası.** Katalog metin haritaları (`name`, `subtitle`, `description`, `changelog`) `ja`, `zh` /
  `zh-Hans`, `ko` / `ko-KR` anahtarlarını kullanır; `tools/catalog_check.py` 45 karakterlik subtitle sınırında bir CJK
  karakteri iki sayar.

## 10. Kaynaklar

- PyNX / nx-python: <https://github.com/nx-python/PyNX>, <https://nx-python.readthedocs.io/>, <https://gamebrew.org/wiki/PyNX_Switch>
- Ren'Py Switch portu: <https://lemmasoft.renai.us/forums/viewtopic.php?p=530030>
- libnx JIT API: <https://switchbrew.github.io/libnx/jit_8h.html>; libnx `jit.c`: <https://github.com/switchbrew/libnx/blob/master/nx/source/kernel/jit.c>
- SVC tablosu (CodeMemory): <https://switchbrew.org/w/index.php?diff=4091>, JIT servisleri: <https://switchbrew.org/w/index.php?diff=9212>
- Atmosphère changelog (JIT çekirdek yamaları): <https://git.nold.in/nold/Atmosphere/raw/commit/be772b40e1f12680597c4ad27548c9c08d7d877a/docs/changelog.md>
- devkitPro geliştirme ortamı: <https://switchbrew.org/w/index.php?diff=4672>
- TinyCC: <https://repo.or.cz/tinycc.git>
- Squirrel: <https://github.com/albertodemichelis/squirrel>
- miniJVM: <https://github.com/digitalgust/miniJVM> (release 2.2.0)
- pocketpy: <https://github.com/pocketpy/pocketpy>
