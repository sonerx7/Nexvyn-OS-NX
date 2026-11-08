# Native SDK rehberi: temiz makineden çalışan app'e

Bu kısa yoldur. Başvuru belgesi `docs/NATIVE_KIT.en.md` (her komut ve başlık), kurallar `docs/NATIVE_COMPAT.en.md` ve
`docs/COMPATIBILITY.tr.md` (*Native SDK*) içinde. İngilizce sürüm: `NATIVE_GUIDE.en.md`.

## 1. Kurulum (bir kez)

1. Switch paketleriyle devkitPro (`switch-dev`, `switch-sdl2`, `switch-mesa`, `switch-glad`, ...). Denenen sürümler
   `tools/toolchain.json` içinde.
2. Python 3. CMake ve Ninja devkitPro'nun kabuğuyla gelir. Windows'ta CLI o kabuğu kendisi açar.
3. `python tools/nxv_native doctor` hepsini denetler. Devam etmeden önce `MISSING` yazan her satırı düzeltin.
4. Pencerede SDL2 kullanan app'ler kitin SDL2'sine de ihtiyaç duyar: `python sdk/native/sysroot/build.py sdl2-nexvyn` (bir
   kez; sonucu `--sysroot` ile verin).

## 2. Yeni proje, derle, paketle

```
python tools/nxv_native new notes --template app      # app | game | port | sdl2 | gl | ...
python tools/nxv_native build notes --sysroot <sysroot>
python tools/nxv_native package notes                 # -> notes/build/notes.nxvapp
```

| Şablon | Ne verir | Ne vermez |
|---|---|---|
| `app` | Küçük, gerçek bir UI app'i: dosya seçici (`nxn_pick`), çalıştırmalar arasında saklanan bir ayar, `lang/en.json` + `lang/tr.json` metinleri (`nxn_tr`), sistem token'larından renk, ölçü ve font (`nxn_ui_tokens_get`); tema, vurgu rengi ve yazı boyutunu izler | Kendi teması: app Nexvyn OS gibi görünür |
| `game` | Sabit adımlı güncelleme döngüsü, yeniden boyutlama / odak / uyku, GL quad batch, action map (kol, klavye), OS mikserinden ses, kayıt dosyası | Menü ya da herhangi bir görünüm: her oyun kendi sanat yönünü seçer |
| `port` | Mevcut bir CMake projesi için yapıştırıcı: `fetch.py` (sabitlenmiş tag + commit, yamalar), `CMakeLists.txt` (toolchain, SDL2, uyum katmanı, Nexvyn hedefi), `patches/`, hiçbir şey indirmeden derlenebilsin diye `example-upstream/` | Upstream kodu, BIOS, firmware, oyun verisi |

Her şablonda `"minNative": "1.1"` vardır ve yukarıdaki iki komutla derlenip paketlenir. Yayınlamadan önce `app.json`'u
(id, ad, yapımcı, kategori, izinler) düzenleyin. Release build'ler `-O2` ve LTO kullanır (`-DNEXVYN_LTO=OFF` LTO'yu kapatır);
toolchain zaten `-march=armv8-a+crc+crypto -mtune=cortex-a57` hedefler (NEON dahil). `--debug` ayrı bir `-O0 -g` build
yapar. `app` şablonundaki ImGui, derlemeye kattığınız bir kaynaktır, sistem kabuğu değildir: kabuk yardımcıları (`fork`,
`execvp`) `IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS` ile kapalıdır.

## 3. Çalıştır

- Emülatör: `python tools/nxv_native run notes --sd <SD kart kökü>` paketi `<sd>/NexvynOS/Applications` içine kopyalar.
  Hiçbir şey başlatmaz; Nexvyn OS'u kendiniz açıp app'i başlatın.
- Konsol: `run --sd <SD kart kökü>` ile konsolun SD kartına, ya da `.nxvapp`'i Nexvyn OS'un paket kurduğu yoldan kurun.
  İmzasız paket uyarıyla kurulur; Store paketleri imzalı olmalı (`package --sign key.pem`).

## 4. Çalışmazsa

Bu sırayla bakın:

1. **App'in log'u** (SD kartta `System/Logs/Apps/<app id>.log`). Başlangıç satırı, app'in `nxn_log` ile yazdıkları, **stdout /
   stderr** (`printf` satırları, `O` / `E` işaretli, sınırlı) ve başlamayan app için tam sebep burada.
2. **Crash raporu**: app'in herhangi bir thread'indeki hata pencereyi kapatır ("<app> durdu"), crash satırını log'a, raporu
   `System/Logs/Crashes` altına yazar. Nexvyn OS çalışmaya devam eder. Art arda üç çökme Nexvyn OS'a "Kapat / Açık bırak"
   sorduruyor.
3. Derleme sırasında `nxv-native check-win build/<ad>.nxvmod`: kimlik, TLS yok, text relocation yok, her import sunuluyor.
   `build` bunu kendisi çalıştırır ve yüklenemeyecek bir modülü paketlemeden önce durdurur.

### Crash raporunu okumak

`System/Logs/Crashes` altındaki rapor ve app'in log'undaki crash satırı modülü ve bir **backtrace** verir: hata veren
thread'in frame pointer zincirinden (x29) en çok 16 dönüş adresi. App'inin içindeki adresler `app+0x4b488` (modül
içindeki ofset), Nexvyn OS kodu `os+0x...` yazılır. Rapor modülün **build-id**'sini de söyler. OS yalnızca okunabilir belleği
gezer ve ilk bozuk frame'de durur; yaprak fonksiyonun çağıranı `lr` satırında görünür.

```
backtrace: os+0xd49f08 app+0x4b488 app+0x4b49c app+0x4b4cc app+0x5759c
```

Nexvyn OS'ta sembol tablosu yok (boyut); isimleri PC'n çözer: `nxv-native symbolize <rapor> [--elf <modül>.nxvmod.debug]`
addr2line çalıştırır ve her `app+0x...` adresi için `fonksiyon at dosya:satır` yazar. Her build bir build-id bağlar ve
debug bilgisini `build/<ad>.nxvmod.debug` dosyasında tutar (paketlenen modülde yoktur); `symbolize` raporla build-id'si eşleşen
dosyayı seçer, bu yüzden yayınladığın her sürümün build klasörünü sakla. `package` build-id'yi yazdırır.
Kit `-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer` ile derler (`-DNEXVYN_FRAME_POINTER=OFF` kapatır).

### Yükleme anındaki mesajlar

Kullanıcı mesajı kendi dilinde görür; log'da teknik satır (`load failed: ...`) ve `what to do: ...` vardır.

| Kullanıcının gördüğü (İngilizce) | Sebep | Çözüm |
|---|---|---|
| "This file is not a windowed native app" | modülde pencere kimliği yok (tek başına `.nro` olarak derlenmiş) | `nxv-native build` / `nexvyn_add_windowed` ile derleyin |
| "built for module interface generation N, but this system uses M" | ABI nesli uyuşmuyor (modülün `.nxnwin` bölümündeki `abi=`) | uyan kitle yeniden derleyin ya da app'i güncelleyin. Nesil yalnızca arayüz bozulduğunda elle yükseltilir |
| "needs a newer Nexvyn OS (host interface N, this system has M)" | modül bu sistemin sunduğundan fazlasını import ediyor | Nexvyn OS'u güncelleyin ya da daha eski bir `minNative` için derleyin |
| "The app needs the function X ..." | sistemin pencere app'lerine sunmadığı bir import (log'da `missing symbol X`) | çağrıyı kaldırın, kitteki karşılığı kullanın ya da uyum katmanını ekleyin (`nexvyn_use_compat`); `check-win` hepsini listeler |
| "The app uses thread_local variables ..." | `native.windowedTls` ayarı kapalıyken (ya da eski Nexvyn OS'ta) modülde ya da bir kütüphanede `PT_TLS` | ayarı açın (`NXN_CAP_TLS`'e bakın) ya da düz static'lerle / kendi thread verinizle değiştirin |
| "thread_local code built for another TLS model" (log) | kitin `-mtls-dialect=trad -ftls-model=global-dynamic` bayrakları olmadan derlenmiş bir nesne (devkitA64'ün varsayılan TLS kodu modüllerde yanlış) | `nxv-native` / `nexvyn_add_windowed` ile derleyin; Makefile nesnelerine aynı bayrakları verin |
| "not built as position-independent code" | text relocation | `nxv-native` ile derleyin; yalnızca `-fPIC` static kütüphaneler bağlayın |
| "no code memory for native apps in this mode" | Nexvyn OS applet olarak çalışıyor (Albüm'den açılmış) | Nexvyn OS'u title kipinde başlatın (oyun açarken R'ye basılı tutun) |
| "not enough free memory" | app'in kodu ve verisi şu an sığmıyor | diğer app'leri kapatın; modülün boyutuna bakın |
| "damaged or built with an unsupported toolchain" | kesik dosya, yanlış mimari, bilinmeyen relocation | yeniden kurun; `nxv-native build` ile yeniden derleyin |

C++ exception `native.windowedEh` ayarı ve bu kitle derlenmiş modül ister (aşağıda). Bunlar yoksa ya da kimse yakalamazsa
`throw` `std::terminate` ile biter: bu bir crash raporudur, yükleme hatası değil. JIT pencerede yok.

## 5. Platform sınırları

| Alan | Pencerede (ve Nexvyn OS içinde tam ekranda) |
|---|---|
| Dosya, zaman, pipe, poll, ortam | kitin uyum katmanı destekler; çağrı listesi `NATIVE_COMPAT.en.md` içinde |
| Thread (`pthread`, `std::thread`) | var; öncelik sınırlı, bir çekirdek Nexvyn OS için boş kalır |
| TLS (`thread_local`) | `native.windowedTls` ayarıyla (`NXN_CAP_TLS`), `"minNative": "1.1"` ve üstü app'lerde varsayılan açık (1.0 app'lerinde kapalı; açıkça verilen ayar kazanır); konsolda henüz doğrulanmadı; kapalıyken yükleyici `PT_TLS`'yi reddeder |
| C++ exception | `native.windowedEh` ayarıyla (`NXN_CAP_CXX_EXCEPTIONS`), `"minNative": "1.1"` ve üstü app'lerde varsayılan açık (1.0 app'lerinde kapalı; açıkça verilen ayar kazanır); konsolda henüz doğrulanmadı; kapalıyken `throw` `std::terminate` ile biter |
| JIT (`PROT_EXEC`) | pencerede **yok** |
| Dinamik yükleme | yalnızca `.nxvlib` (`nxn_lib_open` / `dlopen`), `native.windowedLibs` ayarıyla (`NXN_CAP_SHARED_LIBS`), `"minNative": "1.1"` ve üstü app'lerde varsayılan açık (1.0 app'lerinde kapalı; açıkça verilen ayar kazanır); konsolda henüz doğrulanmadı; Linux `.so` yok |
| Soket | app'in ağ izniyle |
| `fork`, `exec`, `system`, `popen`, pty | hiçbir zaman |
| Bellek yalıtımı | **yok**: app Nexvyn OS'un süreciyle aynı süreci paylaşır (aşağıya bakın) |

**Grafik.** Ekran, konsolun GPU sürücüsünde OpenGL 4.x core ya da ES 3.2'dir (`nxn_display`, glad ya da SDL2 pencereleri).
Masaüstü GL için yazılmış programlar genelde küçük değişiklik ister. **deko3d, mevcut GL portları için bir yol değildir**:
farklı bir API'dir ve kit GL'yi ona çevirmez. Port, GL'yi ekran üzerinden (ya da NexGFX native ile) kullanmaya devam eder.

Tam ekranda kullanıcı kumandayla her zaman − tuşunu bir saniye basılı tutarak çıkabilir (ayar `wm.fullscreenExitHold`); − tuşuna kısa basış uygulamaya her zamanki gibi gider.

**İmza ve izinler bellek yalıtımı değildir.** İmzalı paket, kimin yaptığını ve değişmediğini kanıtlar. `app.json`'daki
`"permissions"`, Nexvyn OS'un app'e neyi sunacağını (dosya, ağ, ...) ve kullanıcıya neyin söyleneceğini belirler. İkisi de
native kodun Nexvyn OS'un belleğine yazmasını engellemez: kontrolsüz bir yazma sistemi bozabilir. Bu yüzden native kod
çalışmadan önce kullanıcıya bir kez sorulur ve Store native paketleri inceler. Konsoldan önce emülatörde deneyin, verinizi
`nxn_fs_*` klasörlerinde tutun.

### Metin ve fontlar

Dear ImGui glyph aralığı almazsa yalnızca Latin-1 çizer; Türkçe `ı ğ ş İ`, Kiril ya da Yunanca harfler `?` görünür. Sistem fontunu `<nexvyn/nxn_imgui.h>` içindeki `nxn_imgui_add_font()` ile yükle (`app` şablonu böyle yapar): app'in dilinin aralıklarını ekler, atlası küçük tutar. Japonca, Korece ve Çince metin sistemin CJK fontunu ister; pencere app'leri bunu henüz alamaz (bkz. `NATIVE_KIT.tr.md`, *Metin ve fontlar*). App'ini birden çok dilde dene: `lang/*.json` ve Ayarlar > Dil.

## 6. Yayından önce

- Temiz bir checkout'ta `python tools/nxv_native build <app> --clean`, sonra `package`. Kendi kodunuzda uyarı kalmasın.
- App'i açın, bir süre kullanın, pencere düğmesiyle ve app'in kendi çıkışıyla kapatın: log `ended` ile biter. On kez açıp
  kapatın: bellek sabit kalır.
- Metinler `lang/*.json` içinde (İngilizce şart, diğerleri isteğe bağlı), Store metni İngilizce, ekran görüntüleri İngilizce
  arayüzle.
