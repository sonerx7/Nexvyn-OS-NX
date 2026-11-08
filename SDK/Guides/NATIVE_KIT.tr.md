# Nexvyn Native Kit

Kit, Nexvyn OS'un içinde çalışan C ve C++ app'lerini derler: app, Nexvyn OS'un kendi sürecine yüklediği bir `.nxvmod`'dur;
pencerede ya da tam ekranda açılır (`app.json` `"mode": "window"` veya `"fullscreen"`; "Nexvyn OS içindeki app'ler"
bölümü). Oyun, emülatör, motor ve port için kullanılır. Script app'ler (Lua, JavaScript, Python, TinyCC ile C) kite
ihtiyaç duymaz.

Durum: toolchain, sysroot script'leri, şablonlar ve CLI bugün çalışır. Nexvyn ABI'si (`#include <nexvyn/nexvyn_native.h>`,
`-lnexvyn_native`) varsayılan olarak bağlanır. SDL2, kitin kendi SDL2 sürücüsüyle Nexvyn OS pencerelerinde (ve tam ekranda) çalışır: "Pencerede SDL2" bölümü. SDL
kullanmayan `nxn_*` API'sini doğrudan kullanır (`examples/hello_gl`, `examples/showcase`).

## Kurulum

1. devkitPro'yu Switch paketleriyle kur (`switch-dev`, `switch-sdl2`, `switch-mesa`, ...). Denenen sürümler
   `tools/toolchain.json` içindedir; `python tools/nxv_native doctor` karşılaştırır.
2. Python 3 (başka paket yok). CMake ve Ninja devkitPro kabuğuyla gelir.
3. Windows: CLI derlemeyi devkitPro'nun msys2 kabuğunda kendisi çalıştırır (`DKP_BASH` yolu değiştirir). Linux ve
   macOS: `DEVKITPRO` tanımlı bir ortamda çalıştır.

## New, build, package, run

```
python tools/nxv_native new mygame --template game      # app | game | port | sdl2 | gl | emu-skeleton | decomp-skeleton | shared-lib
python tools/nxv_native build mygame                    # -> mygame/build/mygame.nxvmod (denetlenmiş)
python tools/nxv_native lib mylib                       # yalnızca kütüphane projesi -> mylib/build/<ad>.nxvlib
python tools/nxv_native package mygame                  # -> mygame/build/mygame.nxvapp
python tools/nxv_native run mygame --sd <SD kart kökü>  # paketi <sd>/NexvynOS/Applications altına kopyalar
```

- `build` seçenekleri: `--abi` (eski script'ler için duruyor; ABI zaten bağlanır), `--debug`, `--clean`, `--sysroot DIR` (ek kütüphaneler, aşağıda).
- `package`, `"runtime": "native"`, `"mode": "window"` (senin `"fullscreen"` seçimin korunur), `"main": "<name>.nxvmod"`,
  `"minNative": "1.0"` ve `"minSdk": "1.10"` içeren `app.json` ile paketi `tools/nxvapp_pack.py` ile üretir (imzalamak
  için `--sign key.pem`). Önce projenin `app.json` dosyasını düzenle: id, ad, yazar, kategori, izinler. `minSdk` 1.10,
  Native 1.0'ı getiren script SDK'sıdır: eski Nexvyn OS sürümleri paketi script gibi okumak yerine "daha yeni Nexvyn OS
  gerekli" diye gösterir; bu yüzden paketleyici bu alanı olmayan native paketi reddeder.
- `python tools/nxv.py pack --delta eski.nxvapp yeni.nxvapp` App Market'in isteğe bağlı delta güncellemeleri için delta paketi
  üretir (yalnızca değişen dosyalar; yeni paket `--stamp` ile paketlenmiş olmalı; `NXVAPP_FORMAT.tr.md` 5c).
- `run` yalnızca dosya kopyalar. Emülatörü ya da Nexvyn'i kendisi açmaz; sen açarsın. Varsayılan SD kökü:
  `%APPDATA%/emülatör/sdcard`.
- Proje yapısı: `CMakeLists.txt`, `src/`, `app.json`, `icon.png`. İsteğe bağlı `data/` ve `romfs/` klasörleri
  modülün yanına paketlenir.

CLI'siz: devkitPro kabuğunda `cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=<kit>/toolchain/nexvyn-switch.cmake -DNEXVYN_KIT=<kit>`.
Meson için `toolchain/nexvyn-switch.meson.ini` (ELF üretir; `.nro` için `elf2nro` ve `nacptool` kullan).

## Nexvyn OS içindeki app'ler (.nxvmod)

Native app, Nexvyn OS'un içinde, diğer app'lerin yanında çalışır; Nexvyn OS çalışmaya devam eder. `"mode": "window"`
normal bir pencere açar, `"mode": "fullscreen"` tüm ekranı kaplayarak açar (Nexvyn OS'un kendi tam ekranı: menü çubuğu ve
Dock gizlenir; çubuk yalnızca işaretçi üst kenarda dururken içeriğin üstüne iner, işaretçi üstteyken tam ekrana girilirse işaretçi ayrılıp dönene kadar gizli kalır, bu yüzden app güvenli alana ihtiyaç duymaz). Tek derlemedir: kullanıcı app çalışırken ikisi arasında geçer (Ctrl+Alt+F, pencere menüsü ya da tam ekran
pencerenin üstündeki çıkış düğmesi) ve app `NXN_EVENT_RESIZE` alır. İkisinde de `nxn_caps_get()` `NXN_CAP_WINDOWED`
bitini verir. `"windowed"`, `"window"`un eski yazımıdır ve çalışmaya devam eder.

```
python tools/nxv_native build mygame                 # -> mygame/build/mygame.nxvmod (denetlenmiş)
python tools/nxv_native package mygame               # app.json "mode": "window", "main": "mygame.nxvmod"
python tools/nxv_native check-win dosya.nxvmod       # kimlik, -fPIC, her import Nexvyn OS'ta var mı
```

CMake: `-DNEXVYN_WINDOWED=ON` (CLI bunu geçer) her `nexvyn_add_nro()` hedefini aynı kaynaktan pencere modülü
olarak derler; ya da `nexvyn_add_windowed(mygame SOURCES src/main.c)` doğrudan çağrılır. Makefile projeleri:
`examples/hello_gl` (`make windowed`, `make package-windowed`): `-fPIC` nesneler, sonra
`-shared -nostartfiles -nostdlib -Wl,-Bsymbolic -Wl,-z,now -Wl,-z,text -Wl,--hash-style=sysv
-Wl,--undefined=nxnwin_identity ... -lnexvyn_window -lgcc` (`make -C sdk/native/lib` `libnexvyn_window.a`'yı derler).

```json
{ "id": "com.you.game", "name": "Game", "version": "1.0.0", "runtime": "native", "mode": "window",
  "main": "game.nxvmod", "window": {"width": 960, "height": 540, "resizable": true},
  "minNative": "1.0", "minSdk": "1.10", "targetSdk": "1.10" }
```

App için değişenler (ayrıntı: `NATIVE_SDK_DESIGN.tr.md` 3.2):

| Alan | Pencerede |
|---|---|
| Import'lar | yalnızca Nexvyn OS'un host import kümesi: `nxn_*`, C kütüphanesi (newlib libc / libm, libsysbase'in POSIX ve pthread'i) ve küçük bir libnx alt kümesi (thread, mutex, uyku). Gerisi (SDL, EGL, libnx servisleri) açılışta "missing symbol" ile reddedilir. C++ (libstdc++, exception, RTTI) modüle link edilir; `thread_local` desteklenmez. |
| GL | GL'i `nxn_display_proc` ile yükleyin (glad: `gladLoadGLLoader((GLADloadproc)nxn_display_proc)`; `eglGetProcAddress` de aynısını verir). Framebuffer 0 pencerenin karesidir. `libGLESv2` / `libEGL`'e doğrudan link etmeyin. |
| Ekran | `nxn_display_open(NULL, ...)` = pencerenin içerik boyutu; pencere değişince `NXN_EVENT_RESIZE`, `nxn_display_resize` ile izleyin. `nxn_display_swap` Nexvyn OS'un karelerine göre bekler (küçültülmüş pencere app'i yavaşlatır). |
| Girdi | yalnızca pencere odaktayken (`NXN_EVENT_FOCUS`); dokunma yüzey pikseliyle. HOME, L + R (basılı) ve + ile - Nexvyn OS'ta kalır. |
| Kapatma | kapat düğmesi `NXN_EVENT_QUIT` gönderir, `nxn_should_quit()` true olur; 5 saniye içinde girişten dönün, yoksa app durdurulur. |
| POSIX ve soketler | uyum katmanını bağla (`nexvyn_use_compat()`, `NATIVE_COMPAT.tr.md` "Pencerede"): pipe, `poll`, `mmap`, sinyaller, kendi ortamı ve çalışma dizini; hepsi app bitince bırakılır. BSD soketler için `app.json` `"permissions"` içinde `"network"` gerekir; yoksa her çağrı `EACCES` ile başarısız olur. |
| Süreç çağrıları | `exit` / `abort` / tutmayan `assert` yalnızca app'i bitirir; `atexit` handler'ları app bitince çalışır; `chdir` reddedilir. |
| Paylaşılan kütüphaneler | `nxn_lib_open` / `dlopen` paketteki `.nxvlib` dosyalarını `native.windowedLibs` ayarıyla yükler (`NXN_CAP_SHARED_LIBS`; kapalı: `NXN_ERR_UNSUPPORTED`). Bu ayarlar açıkken `thread_local` (`native.windowedTls`, `NXN_CAP_TLS`) ve C++ exception (`native.windowedEh`, `NXN_CAP_CXX_EXCEPTIONS`) modülde ve kütüphanelerinde çalışır (`"minNative": "1.1"` ve üstü app'lerde varsayılan açık, 1.0 app'lerinde kapalı; açıkça verilen ayar her app için geçerli; yalnızca emülatörde doğrulandı, konsolda henüz değil); kit her nesneyi `-mtls-dialect=trad -ftls-model=global-dynamic` ile derler ve en sona `crtend.o` bağlar (Makefile projeleri de aynısını yapar). `NATIVE_SDK_DESIGN.tr.md` 3.2.10. |
| JIT ve fastmem | `nxn_jit_*` (kod belleği, rw + rx görünüm; `native.windowedJit` ayarı, `NXN_CAP_JIT`), `nxn_fault_handler_set` (data abort önce app'e; `native.windowedFaultHandler`, `NXN_CAP_FAULT_HANDLER`), `nxn_mem_guard` (app heap'inde koruma sayfası; `native.windowedGuardPages`, `NXN_CAP_GUARD_PAGES`). Hepsi konsolda doğrulanana kadar varsayılan kapalı kalır (`NXN_ERR_UNSUPPORTED`); yorumlayıcı / yavaş yol yedeği kalsın. İşlenen fault sonrası x17 geri yüklenmez. `NATIVE_SDK_DESIGN.tr.md` 3.2.11. |
| Bellek | app'in `malloc` / `free` / `realloc` / `memalign` / `strdup` çağrıları Nexvyn OS'un değil, app'in kendi heap'inden gelir: app temiz kapanınca heap'in tamamı tek adımda geri verilir, yani bir sızıntı app'ten uzun yaşamaz. Sabit limit yoktur: sistemde bellek olduğu sürece heap büyür; geriye yalnızca Nexvyn OS'un çalışmaya devam etmesi için gereken pay kalınca `malloc` `NULL` döner (`errno` = `ENOMEM`; `nxn_*` çağrıları `NXN_ERR_NO_MEMORY` yanıtlar). `app.json`'daki isteğe bağlı `"memory"` (MB, 1 ile 16384 arası) app'in istediği heap'tir: açılışta o kadar boş bellek yoksa Nexvyn OS bunu söyler ("X MB gerekiyor, Y MB boş; açık app'leri kapatın") ve app'i açmaz; varsa o bellek app için ayrılır. C kütüphanesinin kendi ayırdığı bellek (`fopen`, `asprintf` ...) app'in heap'inin parçası değildir. |
| Çökmeler | app'in herhangi bir thread'indeki hata yalnızca penceresini kapatır ("<app> durdu"), çökme satırını log'una, raporu `System/Logs/Crashes`'e yazar; Nexvyn OS çalışmaya devam eder. App yine de Nexvyn OS'un sürecini paylaşır: başıboş bir yazma ona zarar verebilir. Bellek yalıtımı yoktur (`NATIVE_SDK_DESIGN.tr.md` 3.2.7). |

`native.windowed` ayarı (varsayılan açık) pencere native app'lerini kapatır; `native.enabled` iki modu da kapatır;
`native.windowedArena` (ayarlı değilse: `app.json`'da `"minNative"` 1.1 ya da üstü olan app kendi heap'ini alır, eski (1.0) app eskisi gibi Nexvyn OS'un malloc'unu kullanır; `true` / `false` her app için geçerlidir);
`native.memoryReserveMB` (varsayılan 64) app heap'lerinin Nexvyn OS için boş bıraktığı bellektir.

## Örnekler

- `examples/hello_gl`: en küçük uygulama (GL, giriş, ses, dosya, çökme testleri).
- `examples/showcase`: tüm Native SDK özellikleri, canlı self-test ve `showcase_report.txt` (windowed, Dear ImGui). `python sdk/native/examples/showcase/package.py`.
- `examples/scenes`: baked FBX sahneleri için windowed 3B sahne görüntüleyici (worker thread ile yükleme, PBR, shadow map, culling); FBX dosyalarını siz verirsiniz. `python sdk/native/examples/scenes/package.py`.

## Asset'ler: `nxv-asset`

`python tools/nxv_asset bake GİRDİ.fbx|GİRDİ.glb|GİRDİ.gltf -o ÇIKTI --name AD`, bir 3B dosyayı runtime'ın hızlı yüklediği iki
dosyaya çevirir: `AD.nxsc` (malzemeler, malzemeye göre ayrılmış 16 m'lik chunk'lar, tangent'li vertex'ler, index'ler, dosyada
varsa kamera ve güneş) ve `AD.nxtx` (her doku 2'nin kuvvetine boyutlanır, mip zinciri alır, blok sıkıştırılır: BC1 renk, BC3
alfalı, BC5 normal; Tegra X1 bunları donanımda açar). `python tools/nxv_asset check DOSYA.nxsc|DOSYA.nxtx...` baked dosyaları
doğrular. Python 3 + numpy, Pillow, etcpak ister; FBX için ayrıca bilgisayarda bir C derleyicisi (gcc, clang ya da MSVC) gerekir,
GLB / glTF için gerekmez. Araç bozuk dosyada çökmez: tek satır `nxv-asset: error:` yazar, 1 ile çıkar, yarım çıktı bırakmaz
(`tools/tests/nxv_asset_test.py` kesik, bit'i bozulmuş ve çöp dosyalar verir). Dosya düzeni `tools/nxv_asset/__main__.py`
başındaki yorumda; BC doku yolunun kendisi sonra konsolda doğrulanır (emülatör yalnızca yüklendiğini gösterir).

## Native app'te NexGFX (`nexgfx_native.h`)

Native app'ler baked 3B sahneleri (`nxv-asset`, yukarıda) Nexvyn'in PBR renderer'ı ile küçük, sürümlü bir C API üzerinden çizer,
`ngfx_*`: `ngfx_device_create` (app'in kendi GL context'inde), `ngfx_device_prepare` (shader program'larını çağrı başına birer
tane, sizin ilerleme çubuğunuzun arkasında kurar), `ngfx_scene_load` / `ngfx_scene_step` (worker thread dosyaları okuyup doğrular,
`step` kare başına biraz yükler: takılma yok), `ngfx_scene_info_get`, `ngfx_render` (gökyüzü, normal / emissive haritalı
metallic-roughness PBR, oturtulmuş PCF shadow map'li tek güneş, hemisphere ambient, sis, alpha test ve blend, ACES tone mapping,
isteğe bağlı FXAA, render ölçeği; pencereye ya da herhangi bir FBO'ya), `ngfx_scene_free`, `ngfx_device_destroy`. Handle'lar opak,
her struct `size` ile başlar, fonksiyonlar yalnızca eklenir.
- **Nerede durur.** `sdk/native/nexgfx/nexgfx_native.cpp` SOURCES'a eklenir, `sdk/native/nexgfx` ve glad include yoluna konur
  (bkz. `examples/scenes/CMakeLists.txt`). Bu dosya ince bir kabuk ve renderer'ın bir kopyasıdır: `ngfx_device_create` önce Nexvyn
  OS'un renderer'ını ister (`nxn_ngfx_backend`, sürümlü bir tablo, `nexgfx_backend.h`); sistemde yoksa, kapatılmışsa
  (`native.ngfxHost`) ya da başka nesil dönerse app'inizdeki kopyayı kullanır. İki durumda da aynı `ngfx_*` fonksiyonlarını
  çağırırsınız; hangisinin çizdiğini log'unuz yazar (`ngfx backend: host gen 1 (gl)` ya da `ngfx backend: static`). İkisi de sizin
  GL context'inize (`nxn_display_open`) sizin giriş noktalarınızdan (`nxn_display_proc`) çizer; ortak komut akışını koruyan GPU
  kilidi her app GL'inde olduğu gibi işler, masaüstünün context'ine bağlı Nexvyn OS NexGFX'ine hiç dokunulmaz. Nexvyn OS'a daha
  hızlı bir grafik backend'i gelince bu kabukla derlenmiş app'ler onu yeniden derlenmeden alır; doğrudan GL çağıranlar Mesa GL'de
  kalır. Kendi GL yükleyicinizi verirseniz (`ngfx_device_desc.get_proc`) app'inizdeki kopya kullanılır.
- **Özellik biti.** `NXN_CAP_NEXGFX` (bit 23): pencerenin GL context'i device'ın istediğini sunar (OpenGL 4.3 core). Yoksa
  `ngfx_device_create` anlaşılır bir mesajla hata verir.
- **Bozuk dosya.** Loader, bir `.nxsc` / `.nxtx` dosyasının her sayısını, offset'ini ve index'ini kopyalamadan ya da yüklemeden önce
  denetler: bozuk dosya `ngfx_scene_step`'te `NGFX_ERR_FORMAT` olur; çökme ya da hatalı GPU okuması olmaz.
- **Oyunlar şablon değildir.** NexGFX verdiğinizi çizer; gökyüzü, ışık ve ton varsayılandır, sanat yönü değildir. Menü ya da HUD
  gelmez: onları kendi font, layout ve shader'larınızla yapın.
- **Kanıt.** `examples/scenes` sahnelerini `ngfx_*` ile çizer (elinde kalan tek GL, Dear ImGui katmanıdır); showcase'teki "NexGFX
  native" satırı bir üçgen çizip piksel değerlerini denetler. Script SDK'da henüz yok (script yüzü `g3d.*` kalır): native C API'nin
  Lua / JavaScript / Python karşılığı yok, dil eşitliği borcu olarak izlenir.

## OS ses mikseri ve tuş eşleme (`nxn_audio.h`, `nxn_input.h`)

Nexvyn OS'ta zaten olan şeylere iki ince çağrı, windowed app'ler için (cap yoksa `NXN_ERR_UNSUPPORTED` döner):
- **`nxn_sfx_play` / `nxn_tone` / `nxn_sfx_stop_all` (`NXN_CAP_MIXER`).** OS mikserinde kısa efektler ve sentezlenmiş tonlar: kendi
  stream'iniz gerekmez, kullanıcının ses seviyesi geçerlidir, pencere kapanınca sesler durur. `nxn_sfx_play` bir sistem sesi adı
  ("click", "notify") ya da dosya yolu (wav, ogg, mp3) alır. Çağrılar sesi yalnızca OS ana thread'ine kuyruğa koyar, mikseri ya da
  dosyayı hiç beklemez; çalınamayan ses loglanır, hata olarak dönmez. Müzik, kendi PCM'inizi karıştırma ve 3B ses `nxn_audio`
  (kendi stream'iniz) ya da kendi mikserinizle kalır.
- **`nxn_input_action_buttons` (`NXN_CAP_INPUT_ACTIONS`).** Kullanıcının Ayarlar > Kontrolcüler'de bir işleve ("select", "back",
  "context", ...; adlar `nxn_input.h`'de) eşlediği fiziksel tuşların `NXN_BTN_*` maskesi. Kullanıcının kendi tuşlarında "onay" ve
  "iptal" isteyen app, maskeyi `nxn_input_state` ile sınar. Eşleme değişince OS ana thread'inin yenilediği pencere başına bir
  görüntüdür, bu yüzden ucuzdur ve her app thread'inden güvenlidir. Oyununuz için tuş atama sistemi değildir: oyun kendi eylem
  haritasını tutar (isterse bundan başlar).

## Pencerede SDL2

Port ve oyunların çoğu SDL2 programıdır. Nexvyn OS içinde SDL2 programı değişmeden çalışır: kit, pencereyle libnx, EGL ve
audren yerine `nxn_*` üzerinden konuşan bir SDL2 getirir (SDL 2.28'in devkitPro Switch fork'u, Nexvyn OS sürücüleri eklenmiş,
`sdk/native/sdl2/`). App'e statik girer; modül host import kümesinin dışında hiçbir şey import etmez. `nxv-native build`,
SDL içeren her projede onu seçer (`pkg_check_modules(SDL2 ... sdl2)`); bir kez `python sdk/native/sysroot/build.py
sdl2-nexvyn` ile derlenir (`<sysroot>/windowed` altına gider, yalnızca pencere derlemeleri oraya bakar: `--exclusive`
derleme portlibs SDL2'sini kullanmaya devam eder). Aynı kaynak iki yolla da derlenir; `sdl2` ve `gl` şablonları ve `imgui`
kanaryası (`python tools/canary.py build-win imgui`) böyledir. `examples/sdl2_check` öz sınamadır: aşağıdaki her parçayı dener
ve `sdl2_check_report.txt` yazar.

| SDL2 parçası | Nexvyn OS penceresinde ne olur |
| --- | --- |
| Video | tek pencere = Nexvyn OS penceresinin içerik alanı (ya da tam ekran: aynı derleme ikisine de hizmet eder, kullanıcı geçebilir). `SDL_WINDOW_FULLSCREEN` / `RESIZABLE` pencereler içerik boyutunu izler (değişince `SDL_WINDOWEVENT_SIZE_CHANGED`); sabit boyutlu pencere boyutunu korur, Nexvyn OS ölçekler. Sürücü adı `nexvyn`. |
| GL | `SDL_GL_CreateContext`, app'in `nxn_display` bağlamını yapar: OpenGL ES (varsayılan 2.0; 3.0 / 3.1 / 3.2 istenebilir) ya da core profil 4.3. Uyumluluk profili yok, tek bağlam. `SDL_GL_SetSwapInterval(0)` / `(-1)` / `(1)` başarılı olur; pencere OS karesine göre ilerler (vsync), yalnızca geliştirici ayarı `perf.uncapped` açıksa beklemez; bu yüzden `SDL_GL_GetSwapInterval()` 1 döner (app beklemeyi kendi başına kapatamaz). `SDL_GL_GetAttribute(SDL_GL_DEPTH_SIZE / STENCIL_SIZE)` gerçek arabelleği söyler: 24 ve 8. `SDL_GetCPUCount()` süreç maskesindeki çekirdek sayısıdır (konsolda 3). `SDL_Renderer` (OpenGL ES 2) çalışır. `glDrawArrays` gibi doğrudan çağrılar da bağlanır: `libnexvyn_window.a` ES 3.2'nin her giriş noktasını ve ES'te olmayan her OpenGL core 1.0 - 4.3 giriş noktasını taşır (`glPolygonMode`, `glClearDepth`, `glDepthRange`, `glGetTexImage` ...; 184 tane, `nxwin_glcore.c`, `tools/gen_gles_shim.py` üretir): masaüstü GL portu sarmalayıcı olmadan bağlanır. Geri kalanlar gibi `nxn_display_proc` ile çözülürler; sürücüde olmayan çağrı bir şey yapmaz (PC'deki gibi `glGetString(GL_VERSION)` ve uzantıları denetleyin). |
| Ses | her biçim ve hız (SDL çevirir); Nexvyn OS karıştırıcısında push akışı, kuyrukta en çok iki SDL tamponu (`SDL_AudioSpec.samples`); 48 kHz'de 1024 örnek için ölçülen 42,7 ms. Kayıt yok. |
| Kol | tek pad, adı `Switch Controller`, 16 düğme (`NXN_BTN_*` sırası) ve 4 eksen; game controller eşlemesi gömülü. Pencerede odak yokken boş. |
| Dokunma, fare, klavye | dokunma parmakları (`SDL_FINGERDOWN` ...; SDL bunlardan fare olayı da üretir), USB fare / Nexvyn OS imleci (konum, düğmeler, tekerlek, göreli mod), USB klavye (HID kullanımı = SDL scancode, değiştirici tuşlar, `SDL_StartTextInput` sonrası `SDL_TEXTINPUT`). |
| Yaşam döngüsü | pencere kapanınca `SDL_QUIT`; uyku / HOME menüsünde `SDL_APP_WILLENTERBACKGROUND` ... `SDL_APP_DIDENTERFOREGROUND`. |
| Dosyalar | `SDL_GetBasePath` = paket klasörü (salt okunur), `SDL_GetPrefPath` = app'in veri klasörü. |
| Yok | güç bilgisi, haptic, sensör, `SDL_LoadObject`, Vulkan, ikinci pencere. SDL thread'leri Nexvyn OS'un verdiği önceliği korur (`SDL_SetThreadPriority` bir şey yapmaz). |

SDL2 kaynağı zlib lisanslıdır; eklenen sürücüler değiştirilmiş kaynak olarak işaretlidir (`sdk/native/sdl2/overlay`).

## Girdi ve dock

Nexvyn OS içinde girdiyi ve boyut değişimini host verir (yukarıdaki bölüm). Bu bölüm `nxn_*` kütüphanesinin kendi girdi
sahibini ve dock olaylarını anlatır; Nexvyn OS pencereleri için SDL2 sürücüsü aynı çağrılar üstüne kuruludur, yani SDL
app'i kendi girdi sahibidir ve `nxn_input_poll`'u kendisi çağırmaz.

**Native SDK 1.1 eklemeleri** (her biri bir `nxn_caps.features` biti ile bildirilir; biti olmayan sistem
`NXN_ERR_UNSUPPORTED` döner, eski app'ler için başka hiçbir şey değişmez):

- `nxn_audio_clear` (`NXN_CAP_AUDIO_CLEAR`): push akışının kuyruğundakini atar, sonraki `nxn_audio_queue` taze başlar.
- `nxn_input_key_poll`, `nxn_input_text`, `nxn_input_mouse` (`NXN_CAP_USB_INPUT`): sıralı USB tuş olayları (bir kare içindeki
  kısa basış kaybolmaz), yazılan metin (UTF-8) ve imleç fare olarak. `nxn_input_mouse` bir kez çağrılınca app fare
  kullanıcısı olur: imleç artık `nxn_input_touch`'ta parmak 0 sayılmaz. `nxn_input_key_held` değiştirici tuşları bilir
  (kullanım 224..231).
- `NXN_EVENT_DOCK`, `NXN_EVENT_SUSPEND`, `NXN_EVENT_RESUME` (`NXN_CAP_POWER_EVENTS`): dock / el modu ve uyku ya da HOME menüsü.
  `SUSPEND` sonrası Nexvyn OS app'in sesini çalmaz, `nxn_display_swap` hiçbir şey geri okumaz; `RESUME`, suspend öncesi
  kuyruktaki sesi atar.
- Sistem servisleri (`nxn_sys.h`, pencere modu; tek başına kütüphane `NXN_ERR_UNSUPPORTED` döner): `nxn_notify`
  (`NXN_CAP_NOTIFY`, app.json'da `"notifications"` ister), `nxn_clipboard_get` / `nxn_clipboard_set` (`NXN_CAP_CLIPBOARD`, izin
  yok), `nxn_rumble` (`NXN_CAP_RUMBLE`: yalnızca pencere odaktayken, kendiliğinden durur, çağrı başına en çok 2 sn),
  `nxn_pick` (`NXN_CAP_PICKER`: Nexvyn OS'un aç / kaydet / klasör penceresi; kapatılırsa `NXN_ERR_CANCELLED`) ile
  `nxn_grant_get` / `nxn_grant_check` / `nxn_grant_revoke` (`NXN_PICK_REMEMBER` ile seçilen klasör sonraki çalışmalarda da
  erişilebilir kalır, kullanıcı geri alabilir), `nxn_save_path` / `nxn_save_backup` / `nxn_save_restore` /
  `nxn_save_backup_get` / `nxn_save_backup_delete` (`NXN_CAP_SAVEDATA`: kullanıcının kendi kayıt klasörü `<data>/save` ve
  `Library/Backups/<app id>` içinde adlı yedekler; geri yükleme kopya yerine oturana kadar mevcut kaydı korur) ve
  `nxn_perm_query` / `nxn_perm_request` (`NXN_CAP_PERMISSIONS`, `"network"` ve `"notifications"` için; soru izin ve oturum
  başına en çok bir kez sorulur). Nexvyn OS arayüzü gereken çağrılar onun ana thread'inde çalışır, app thread'i bekler
  (yanıt vermiyor denetimi için "canlı" sayılır); kare döngüsü durmasın istiyorsan `nxn_pick`, `nxn_perm_request` ve
  kayıt çağrılarını worker thread'e koy. `examples/showcase`'te her biri için bir satır ve self-test var.

**Kumandanın sahibi.** Varsayılan girdi sahibi `nxn_input`'tur: `nxn_input_poll` pad'leri libnx üzerinden okur, tuşları
Nexvyn'in bit sırasına çevirir ve kullanıcının onay / geri tuşlarını ekler (`NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL`,
ayrıca `nxn_info_get`). Kütüphane, ilk `nxn_input_poll` ya da `nxn_input_key_held` çağrısına kadar HID durumuna dokunmaz.

SDL'in joystick ya da game controller API'sini isteyen uygulama (SDL2 portlarının çoğu) bu yüzden girdi sahibi olarak
SDL'i seçer:

- programın hiçbir yerinde `nxn_input_poll`, `nxn_input_touch` ya da `nxn_input_key_held` çağrılmaz;
- `SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER)` çağrılır ve pad'ler SDL'den okunur;
- `nxn_*`'in geri kalanı (ekran, ses, dosyalar, günlük, dönüş) kullanılmaya devam eder. Uygulama kullanıcının eşlemesini
  isterse `nxn_info_get().confirm_buttons` / `cancel_buttons` okunur (maskeler `NXN_BTN_*` bitlerini kullanır; SDL joystick
  tuş numaraları başka bir numaralandırmadır, uygulama çevirir).

İki katmanı karıştırmak mümkündür ama desteklenmez: her biri kendi "bu karede basıldı" durumunu tutar.

**Dock.** `nxn_event_poll` (başlık `nxn_event.h`, yetenek `NXN_CAP_EVENTS`), konsol dock'a takılıp çıkarıldığında
`NXN_EVENT_RESIZE` verir: yeni çıkış boyutu (dock'ta 1920x1080, elde 1280x720) ve `docked`. Kütüphane yüzeyi kendiliğinden
değiştirmez. Yeni boyutu isteyen uygulama `nxn_display_resize` çağırır (EGL yüzeyi yeniden oluşturulur, bağlam kalır) ve
`glViewport`'u ayarlar; olayı yok sayan uygulama boyutunu korur, sistem onu ölçekler. Olaylar uygulama
`nxn_should_quit()` çağırırken (ya da SDL olayları işlerken) toplanır; bu yüzden her karede çağırın. `examples/hello_gl`
döngüyü gösterir. Yüzey değişimi, güvenilmeden önce konsolda kanıtlanmalıdır.

**Applet modu.** Albüm'den başlatılan Nexvyn OS (applet modu) çok daha az belleğe sahiptir; app `nxn_caps_get` içinde
`NXN_CAP_APPLET_MODE` görür. Nexvyn OS'u başlık modunda açın (oyun açarken R'ye basılı tutun).

**Çökmeler.** Art arda üç kez çöken uygulama için Nexvyn OS "Kapat / Açık bırak" diye sorar; normal bir çıkış sayacı
sıfırlar.

## OS görünümü ve app'in kendi metinleri (Native 1.1, `nxn_ui.h`)

Nexvyn OS'un parçası gibi görünmesi gereken app'ler için (araçlar, editörler, ön yüzler). **Oyunlar bunu kullanmaz**: oyun kendi görünümünü kurar, OS menüsünü kopyalamaz; hazır menü şablonu yoktur.

- `nxn_ui_tokens_get`: tek size'lı struct; renkler (arka plan, yüzey, metin, ikincil metin, vurgu, hata, uyarı, başarı, kenarlık...), ölçüler (köşe yarıçapı, boşluk adımları, satır / kontrol yüksekliği, yazı boyutları, yazı ölçeği) ve `revision`. Değerler OS'un kendi paletinden gelir, kopya değildir; açık / koyu, vurgu rengi ve yüksek kontrastı izler.
- `NXN_EVENT_MENU` (`nxn_menu.h`, `NXN_CAP_MENU`, ayar `native.windowMenu`, `"minNative": "1.1"` ve üstü app'lerde varsayılan açık, `false` kapatır; konsolda doğrulanmadı): kullanıcı app'in pencere menüsünden (`nxn_menu_set`) bir öğe seçti; `item_id` öğenin id'si. Yalnızca `"minNative": "1.1"` app'leri alır. Oyunlar için değil. `NATIVE_SDK_DESIGN.md` 3.2.12.
- Canlı yeniden boyutlandırma (ayar `native.liveResize`, varsayılan kapalı; konsolda doğrulanmadı): kullanıcı pencere kenarını sürüklerken app, bırakmayı beklemeden yaklaşık her 0,12 sn yeni içerik boyutuyla `NXN_EVENT_RESIZE` alır. Ayar açıkken `"minNative": "1.1"` ve üstü app'ler alır; eski app yalnızca `app.json`'da `"liveResize": true` ile (`false` bırakınca-boyutlanır davranışını korur). Diğer yeniden boyutlandırmalar gibi işlenir: `nxn_display_resize`.
- `NXN_EVENT_THEME`: görünüm değişti, token'ları yeniden oku. Yalnızca `"minNative": "1.1"` olan app'lere gelir; eskiler karede bir `revision` karşılaştırabilir.
- `nxn_ui_font_get` sistem fontunun baytlarını verir (ör. ImGui `AddFontFromMemoryTTF`, `FontDataOwnedByAtlas = false`), `nxn_ui_icon_code("folder")` `NXN_UI_FONT_ICONS` fontundaki kod noktasını.
- **Metin ve fontlar.** ImGui glyph aralığı verilmezse yalnızca Latin-1 yükler; Türkçe `ı ğ ş İ`, Kiril, Yunanca ya da Japonca metin `?` görünür. `<nexvyn/nxn_imgui.h>` dosyasını ekle (yalnızca başlık, `imgui.h`'den sonra) ve `nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, px, 0, icon_ranges)` çağır: sistem fontunu app'in diline gereken aralıklarla yükler (`nxn_info_string(NXN_INFO_LANGUAGE)`): Latin-1 ve Latin Extended-A her zaman (en, tr, de, es, fr), `vi` için Latin Extended-B, `el` için Yunanca, `ru uk bg sr` için Kiril; `NXN_IMGUI_ALL_SCRIPTS` bayrağı app'in kendi çevirmediği metinler (dosya adları) için hepsini ekler. Yalnızca bu aralıklar yüklendiği için atlas küçük kalır. `icon_ranges` verilirse ikonlar aynı fonta eklenir. Sistem fontu Inter'dir (Latin, Yunanca, Kiril); Han / Kana / Hangul fontu `NXN_UI_FONT_CJK` olarak gelir (`NXN_CAP_UI_FONT_CJK`, bit 32; konsolun ortak fontu, yoksa SD karttaki font paketi, app'in dilinin yüzüne kesilmiş) ve aynı yardımcı onu `ja`, `ko`, `zh` için app'te değişiklik olmadan ekler: fontun tamamı değil, yaygın karakterlerden oluşan küçük bir küme (yaklaşık 2400-3000: ImGui'nin Japonca ve Basitleştirilmiş Çince tabloları, Korece için KS X 1001'in 2350 hecesi). Onu alan her font atlası 20 px başına yaklaşık 1 MB büyütür; rakam / monospace fontlar için `NXN_IMGUI_NO_CJK` ver; 30 px üstü fontlar `NXN_IMGUI_CJK_LARGE` olmadıkça atlar. Fontu olmayan sistem (eski Nexvyn OS, kurulu font yok) yalnızca Latin çizer, hiçbir şey bozulmaz. `app` şablonu, Showcase ve Tour yardımcıyı kullanır; kendi ImGui app'lerinde de kullan, metinleri `lang/*.json` içinde tut.
- **ImGui'de kumanda ve dokunma.** ImGui odağı kumandayla yalnız app `ImGuiConfigFlags_NavEnableGamepad` verir ve backend `ImGuiBackendFlags_HasGamepad` verirse taşır; OpenGL3 backend'i bunu hiç vermez, bu yüzden Joy-Con hiçbir şey yapmıyordu. `ImGui::CreateContext()` sonrası `nxn_imgui_enable_gamepad(io)` çağır (`nxn_imgui.h`, `nxn_imgui_add_font` da yapar) ve kumandayı `io.AddKeyEvent(ImGuiKey_Gamepad...)` ile besle. Pencerede `nxn_input_touch` zaten app yüzeyinin piksellerini verir (`DisplaySize` ile aynı uzay): `io.AddMousePosEvent`'e değiştirmeden ver. Yalnız tam ekran derlemede 1280x720 uzayı vardır ve ölçeklenir (`#ifndef NEXVYN_WINDOWED`).
- `nxn_tr(key)` / `nxn_tr_format(key, out, cap, args, argc)`: paketin `lang/<kod>.json` metinleri (paket aracı `lang` klasörünü kopyalar). Script SDK'daki `TR()` ile aynı kural: iç içe anahtarlar noktayla birleşir, `{0}` yer tutucuları, geri düşüş dil -> taban dil -> `en` -> anahtar. Dil başlangıçtaki dildir; sistemin kendi metinleri yoktur.
- Caps: `NXN_CAP_UI_TOKENS`, `NXN_CAP_TEXT`. Bağımsız .nro'da çağrılar `NXN_ERR_UNSUPPORTED` döner, `nxn_tr` anahtarı verir.
- Showcase'te "UI tokens" sayfası ve hepsi için self-test satırları var.

## Performans, kare ritmi ve ayarlar (Nexvyn OS 1.2.2)

Native app'ler için neler değişti, konsolda ölçüldü (hiçbiri kod değişikliği istemez; eski app'ler eskisi gibi çalışır):

- **Varsayılan olarak daha hızlı.** GPU kilidi yalnızca çizim sırasında tutulur, shader'lar kilitsiz derlenir, tek tam ekran pencere doğrudan ekrana çizer, değişmeyen kare yeniden sunulmaz. Ölçülen: 3B sahne demosu 10 → 59 fps, OpenGL showcase 10-16 → 60 fps, bir GBA emülatörü tam hızda, app'ten sisteme kare devri 15-24 ms → 0.1 ms, sahne yüklemesi yaklaşık 30 sn → 0.6 sn. Hepsi kendi ayarıyla kapatılabilir (`native.gpuLazyLock`, `native.gpuUnlockedCompile`, `native.fullscreenDirect`, `compose.idleSkip`, `gfx.ngfxOpaqueNoDiscard`: `false`).
- **Ayarlar > Performans.** Resmi en yüksek saatler (`perf.official`, varsayılan açık) ve app yüklenirken CPU hızlandırma (`perf.loadBoost`) konsolun resmi sınırları içinde kalır. İsteğe bağlı hız aşırtma (`perf.mode`, varsayılan kapalı) bir kez sorar ve açık onay ister (`perf.consent`). App bunların hiçbirini çağırmaz; yalnızca sonucu görür.
- **Kare ritmi.** `native.frameAhead` (0 varsayılan, 1, 2) bir önceki kare alınmışsa swap'in hemen dönmesini sağlar; en çok bir kare gecikmeye mal olur, ölçülmüş kazanç yoksa oyunlarda 0 bırakın. `gfx.dynamicRes` (`auto`, `on`, `off`) çizim boyutunu `gfx.dynamicResMin` (0.6) ile view'in kendi `render_scale` değeri arasında `gfx.dynamicResFps` (60) hedefine göre ölçekler; `auto` yalnızca SDK 1.12'den yeni hedefleyen app'lerde açıktır. Kare sürenizi 16.6 ms altında tutun ve ritmi sisteme bırakın: meşgul bekleme yapmayın.
- **Ses.** Kitin SDL2'si artık her örnek biçimini (U8, S8, S16, S32, F32; 11 025 - 48 000 Hz) dönüştürüyor ve ikiden çok kanalı stereoya doğru indiriyor. Oyununuz cızırdadıysa güncel kitle yeniden derleyin (`python sdk/native/sysroot/build.py sdl2-nexvyn`, sonra kendi derlemeniz).
- **Hatalar.** `NXN_ERR_TIMEOUT`, `NXN_ERR_BUSY`, `NXN_ERR_EXISTS` ve `NXN_ERR_LIMIT` gelecek çağrılar için ayrılmış adlardır. Henüz hiçbir çağrı bunları döndürmez; sayıları onları getiren başlıkla birlikte belirlenir: bilinmeyen her negatif sonucu sade bir hata sayın.
- **Store görselleri.** Oyunlar için Store'a, en iyi kamera açılarından, sistem dili İngilizce iken çekilmiş beş ekran görüntüsü öneriyoruz. Bu bir öneridir, kural değil.

## Toolchain

C11 ve C++17 (GNU lehçesi), Release'te `-O2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer` (crash backtrace'i; `-DNEXVYN_FRAME_POINTER=OFF` kapatır; aarch64 yaprak olmayan her fonksiyonda zaten frame record tutar, bu yüzden ilk bayrak tek başına bir şey değiştirmez: ikincisi yaprak fonksiyonlara da kayıt ekler, çöken yaprağın çağıranı zincirde kalır; şablon app'te ölçüm: .text 713332 -> 725500 bayt, +%1,7), exception ve RTTI açık, `-march=armv8-a+crc+crypto -mtp=soft`, devkitPro
portlib'leri arama yolunda. Her modül bağlaması bir build-id ekler ve debug bilgisini build klasöründe `<ad>.nxvmod.debug` (kütüphanede `.nxvlib.debug`) dosyasına taşır; paketlenmez (`nxv-native symbolize`, rehber bölüm 4). `nexvyn_add_nro(target TITLE AUTHOR VERSION ICON ROMFS)` `.nro`'yu üretir.

## Şablonlar

Kurulum, derleme, paketleme, çalıştırma ve hata teşhisi rehberi: `docs/NATIVE_GUIDE.tr.md`.

| Şablon | İçeriği |
| --- | --- |
| `app` | Küçük, gerçek bir UI app'i: dosya seçici, çalıştırmalar arasında saklanan ayar, `lang/en.json` + `lang/tr.json`, `nxn_ui` token'larından Nexvyn OS görünümü (GL üzerinde ImGui; pencere). Varsayılan. |
| `game` | Yapı taşları, menü yok: sabit adımlı döngü, yeniden boyutlama / odak / uyku, GL quad batch, action map, OS mikser sesi, kayıt dosyası. Varsayılan tam ekran. |
| `port` | Mevcut bir CMake projesi için yapıştırıcı: `fetch.py` (sabit tag ve commit, yamalar), toolchain, SDL2, isteğe bağlı uyum katmanı; fetch edene kadar `example-upstream/` yerini tutar. |
| `sdl2` | SDL2 penceresi, kol girdisi, delta time'lı döngü, renderer (Nexvyn OS'ta pencere / tam ekran, `--exclusive` ile `.nro`). |
| `gl` | SDL2 + EGL OpenGL ES 2 bağlamı, tek shader, dönen üçgen. |
| `emu-skeleton` | Emülatör yapısı: register, bellek ve kare başına cycle bütçeli fetch/decode/execute döngüsüyle `Cpu`; `JitMemory` (libnx `jitCreate`, işaretli yedek ve TODO ile). |
| `decomp-skeleton` | PC tarzı `main(argc, argv)`, SD kartta veri klasörü, büyük/küçük harf duyarsız dosya erişimi için `fopen_ci()`. |
| `shared-lib` | Küçük bir paylaşılan kütüphane (`greet.nxvlib`) ve onu `nxn_lib_open` ile yükleyen app (Nexvyn ABI'sini kullanır). |

`shared-lib` dışındakilerin hepsi Nexvyn ABI'si olmadan `.nro`'ya derlenir. `src/` içindeki `#ifdef NEXVYN_ABI` blokları ABI çağrılarının yeridir.

## Kütüphaneler (sysroot)

`python sdk/native/sysroot/assemble.py` devkitPro'nun zaten verdiklerini ve overlay'in eklediklerini listeler:

- devkitPro'dan (portlibs): SDL2 (+ image, mixer, ttf, gfx), mesa (EGL, GLES), glad, zlib, libpng, libjpeg-turbo,
  freetype, curl, mbedtls, ffmpeg, bzip2, harfbuzz, libwebp, opus, ogg, flac, mpg123.
- Nexvyn sysroot'tan (statik kütüphaneler, `sysroot/build.py` derler):

| Kütüphane | Sürüm | Lisans | Ne derleniyor |
| --- | --- | --- | --- |
| zstd | 1.5.6 | BSD-3-Clause | kütüphane, çok thread'li |
| lz4 | 1.10.0 | BSD-2-Clause | kütüphane |
| SQLite | 3.47.2 | kamu malı | amalgamation, FTS5 var, WAL yok, özel kilit |
| libarchive | 3.7.7 | BSD-2-Clause | zip, tar, gzip, bzip2, zstd, lz4; ACL, xattr ve harici program filtresi yok |
| OpenAL Soft | 1.23.1 | LGPL-2.0-or-later | yalnızca SDL2 backend (ses SDL2 üzerinden gider) |
| GNU libiconv | 1.17 | LGPL-2.1-or-later | tam kodlama seti; sysroot'un `iconv.h`'si newlib'inkinin yerine geçer |
| pixman | 0.43.4 | MIT | AArch64 NEON ile |
| GLib | 2.78.6 | LGPL-2.1-or-later | glib, gobject, gthread, gmodule; gio yok (aşağıya bak) |
| PCRE2, libffi | 10.44, 3.4.6 | BSD-3-Clause, MIT | GLib'in bağımlılıkları |

- Dear ImGui 1.91.5 (MIT), SDL2 ve OpenGL ES 3 backend'iyle `sysroot/vendor/imgui` içindedir:
  `add_subdirectory(${NEXVYN_KIT}/sysroot/vendor/imgui imgui)` ve `imgui`'yi bağla.

### Derle, paketle, kullan

```
python sdk/native/sysroot/build.py --setup-venv      # bir kez: cache klasöründe yerel meson (pixman, glib)
python sdk/native/sysroot/build.py                   # bütün kütüphaneler build/native-sysroot/ içine
python sdk/native/sysroot/build.py glib              # tek kütüphane (önce bağımlılıkları)
python sdk/native/sysroot/build.py package           # build/nexvyn-native-sysroot-<sürüm>.tar.zst + .manifest.json
python sdk/native/sysroot/build.py test              # tests/sysroot_test'i derler (kanıt .nro'su)
python sdk/native/sysroot/assemble.py --prefix DIR --archive nexvyn-native-sysroot-1.0.0.tar.zst
```

Derleyici nasıl çalışır: kaynaklar bir kez `build/native-sysroot-cache/dl` içine iner, `recipes.json`'daki sha256 ile
doğrulanır, aynı cache klasöründe açılıp derlenir (`src/`, `bld/`, kütüphane başına bir log: `logs/`). Yeniden başlatma ya
da ikinci çalıştırma biten işi atlar (prefix içinde kütüphane başına bir damga); bir tarifi, yamayı ya da shim'i değiştirince
yalnızca o kütüphane yeniden derlenir (`--force` birini zorla derler). Prefix'te `include/`, `lib/`, `lib/pkgconfig/`
(taşınabilir: `.pc` dosyaları `${pcfiledir}` kullanır) ve kütüphanelerin getirdiği CMake config dosyaları bulunur. Arşivde
normalize edilmiş tar bilgisi, `manifest.json` (kütüphane, sürüm, lisans, kaynak adresi ve sha256, dosya boyutları) ve
`licenses/<kütüphane>/` vardır. Bunların hiçbiri commit edilmez; arşiv (yaklaşık 4,5 MB, debug bölümleri atılmış) bir indirmedir, istenince derlenir ya da indirilir.

Derleyici için gerekenler: msys2'siyle devkitPro (cmake, ninja, make, zstd, pkg-config), Python 3.9+ ve `patch` (Windows'ta
Git for Windows ile gelir). `--setup-venv` meson'u cache klasörüne kurar; makinede başka bir şeye dokunulmaz. Prefix'i
`NEXVYN_SYSROOT=DIR` (CMake kiti) ya da `-I DIR/include -L DIR/lib` (düz make) ile kullan.

### Kanıt: `sysroot/tests/sysroot_test`

Tek bir `.nro` her kütüphaneyi bir kez çağırır: zstd ve lz4 gidiş-dönüş, bellekte SQLite sorgusu, libarchive ile yazılıp
geri okunan zip ve tar.zst, SDL2 backend'inde OpenAL cihazı ve bağlamı (`ALSOFT_DRIVERS=sdl2`: null backend'e sessiz
dönüş testi düşürür), UTF-8'den UTF-16LE'ye ve latin1'den UTF-8'e iconv dönüşümü, pixman dikdörtgen doldurma ve GLib hash
tablosu, string ile ana döngü adımı. `sdmc:/sysroot_test_results.txt` dosyasına yazar (kütüphane başına bir satır, sonra
`RESULT pass=N fail=M`) ve M döndürür. Emülatörde son çalıştırma: pass=8, fail=0.

### Bilinmesi gerekenler

- GLib'de gio yok: soket, D-Bus, alt süreç ve inotify Switch'te çalışamaz; gio'nun configure adımı da newlib'de olmayan
  başlıklar ister. GLib ana döngüsü newlib'de olmayan `pipe()` ve benzerlerine ihtiyaç duyar: uyum katmanını bağla
  (`nexvyn_use_compat()`), yoksa link `undefined reference to pipe` ile düşer. gettext geçiş yapan bir stub'dır (yalnızca
  başlık); çeviriyi kendi dosyalarınla yap.
- libarchive arşivleri bellekte ve dosyalarla okur/yazar. Dizin ağacı gezemez (`fchdir`), harici program filtresi yoktur
  (`fork`, `exec`). FAT'a açarken symlink girdileri yine atlanmalıdır.
- SQLite: WAL yok (FAT'ta paylaşımlı bellek yok), varsayılan özel kilit, eklenti yükleme yok.
- OpenAL Soft cihazını SDL2'den alır: app zaten yapmıyorsa önce `SDL_Init(SDL_INIT_AUDIO)` çağır.
- Kütüphanelerin başvurduğu birkaç eksik POSIX çağrısı `sysroot/shims/` içinde weak sembollerdir: uyum katmanı ya da app
  gerçeğini tanımlarsa o geçerli olur.
- LGPL kütüphaneler (OpenAL Soft, libiconv, GLib) statik arşivdir: bunları bağlayan app LGPL'ye uymalıdır, yani kullanıcıya
  yeniden bağlama yolu (app'in object dosyaları ya da bağlanabilir arşivi) ile kütüphane kaynağı ve lisansı verilir. Kit
  arşivinde her lisans dosyası `licenses/` içindedir; manifest her kütüphanenin kaynak adresini ve hash'ini listeler.

`assemble.py --prefix DIR` kendi derlediğin kütüphaneler için hâlâ boş bir overlay prefix'i oluşturur; `build --sysroot DIR`
ile ver.

POSIX / PC uyum katmanı (`libnexvyn_compat`, isteğe bağlı, runtime ile bağlanır): `NATIVE_COMPAT.tr.md`.

## Paylaşılan kütüphaneler (.nxvlib)

Varsayılan statik link olarak kalır. Birçok portun kullandığı bir kütüphane (SDL2, büyük bir runtime, codec) ya da bir
eklenti bunun yerine bir kez `.nxvlib` olarak derlenip çalışma anında `nxn_lib_open` (`<nexvyn/nxn_lib.h>`) ya da
`dlopen` (uyum katmanı) ile yüklenebilir. Şablondan başla: `python tools/nxv_native new mytool --template shared-lib`.

```cmake
nexvyn_add_lib(greet NAME greet VERSION 1.2.0 SOURCES lib/greet.c)   # -> build/greet.nxvlib
add_executable(mytool src/main.c)
nexvyn_export_symbols(mytool LIBS greet)                              # app ona libc / libnx verir
nexvyn_add_nro(mytool ...)                                            # NEXVYN_ABI açık (libnexvyn_native)
```

```c
nxn_lib* lib;
if (nxn_lib_open("greet", "1.2", &lib) != NXN_OK) { nxn_log(NXN_LOG_ERROR, "%s", nxn_lib_error()); return; }
const char* (*hello)(void) = (const char* (*)(void))nxn_lib_sym(lib, "greet_hello");
```

- Derleme: `nexvyn_add_lib` `-fPIC` ile derler ve import'ları açık bırakılmış bir AArch64 shared object bağlar
  (`-nostdlib`, `-z text`: text relocation link hatasıdır, SysV hash). `nxv-native build` / `lib` ardından her
  `build/*.nxvlib` dosyasını denetler (`nxv-native check-lib DOSYA [--host app.elf]`): text relocation yok,
  `thread_local` yalnızca kitin TLS modeliyle, kimlik bölümü var ve her import app tarafından export ediliyor.
- Kurulu kütüphaneler: `"type": "lib"` paketi `Libraries/` içine gider; `libs.sideBySide` ayarıyla bir kütüphanenin birkaç major
  sürümü yan yana kurulur (`Libraries/<id>/<major>/`), app'in `needs` girdisi (`"id@6.1"`) o major'ın en yüksek kurulu
  sürümünü seçer ve kurulu bir app'in ihtiyaç duyduğu sürüm asla kaldırılmaz. Ayarlar > Depolama > Kütüphaneler neyin kurulu
  olduğunu, kimin kullandığını gösterir ve kullanılmayan sürümleri kaldırır (`NXVAPP_FORMAT.tr.md` 5b).
- Tek C kütüphanesi, tek heap: kütüphane `malloc`, `printf`, libstdc++ ve libnx'i onu yükleyen app'ten alır.
  `nexvyn_export_symbols` app'i `--export-dynamic` ile bağlar (sembol tablosu `.nro`'ya girer, global sembol sayısıyla
  büyür) ve listelenen kütüphanelerin import ettiği her fonksiyonu link'e çeker. Derleme anında bilinmeyen eklentiler
  yalnızca app'in export ettiklerini kullanabilir; eksik olan, adını veren temiz bir hatadır. Makefile projeleri:
  `nxv-native exports a.nxvlib -o imports.ld`, ardından app'i `imports.ld -Wl,--export-dynamic -Wl,--hash-style=sysv`
  ile bağla.
- Sınır yalnızca C: `extern "C"` fonksiyonlar ve düz veri. C++ sınıfı ya da `thread_local` sınırdan geçmez. Kütüphanenin
  içinde C++ çalışır; pencerede `native.windowedEh` açıkken exception app'e geçebilir (kütüphane app'in C++ çalışma
  zamanını kullanır), başka yerde kütüphaneyi `-fno-exceptions` ile derleyin.
- Kimlik: `NXN_LIB_ABI_GEN` (elle yükseltilir, `nxn_lib.h` içinde) ve kütüphanenin semver'i; ikisi de `.nxvlib`
  bölümüne yazılır. `min_version "1.2"` 1.2.0'dan itibaren her 1.x'i kabul eder; başka major, daha eski sürüm ya da başka
  ABI nesli mesajla reddedilir. OS sürümü ve build buna hiç karışmaz.
- Arama yeri: açık bir yol ya da yalın ad (`greet`, `libgreet.so`): önce app'in `.nro`'sunun yanında, sonra
  `<data>/lib/` içinde `<ad>.nxvlib`. `nxv-native package` `build/*.nxvlib` dosyalarını `.nro`'nun yanına koyar.
- Kütüphane app bitene kadar bellekte kalır (`nxn_lib_close` yalnızca bir referans düşürür); içine işaret eden
  fonksiyon pointer'ları geçerli kalır, yıkıcıları çıkışta çalışır.
- Yükleme, OS'un kendi modülleri gibi JIT kod belleği ister: `nxn_caps_get` içinde `NXN_CAP_SHARED_LIBS`. Applet
  modunda hata, Nexvyn OS'u Atmosphère'in homebrew yükleyicisiyle başlatmayı (oyun açarken R'ye basılı tutarak) söyler.
- Yükleyici, Nexvyn OS'un modülleri için kullandığı koddur (`sdk/native/loader/nxelf.c`); `libnexvyn_native`'e
  derlenir, bu yüzden Nexvyn OS bellekte yokken de çalışır.
- Paketler: Store'da `"type": "lib"` paketleri ve `app.json` içinde `"needs"` var (her kütüphanenin tek sürümü; Uygulama
  Mağazası uygulamanın ihtiyaç duyduğu kütüphaneleri tek onayla önce kurar; kullanılan kütüphane asla kaldırılmaz).
  Paketleme ve denetim: `python tools/nxv.py pack` / `check` (script, native ve kütüphane paketleri için tek araç, modül
  ABI'sini de denetler). Güncelleme önceki sürümü saklar (Sistem Ayarları > Uygulamalar) ve `dataVersion` yükseliyorsa önce
  kullanıcının verisini kopyalar (`docs/NXVAPP_FORMAT.tr.md` bölüm 2, 5). Yan yana major'lar ve Kütüphaneler ekranı planlı
  (`NATIVE_SDK_DESIGN.tr.md`); alan biçimleri sabit.

## Kanarya projeler

Kit'in yazmadığı dört gerçek açık kaynak program: kit ile derlenir ve açılır, dağıtılmaz, port edilmez. Kit'in genel
C/C++ kodunu derlediğini kanıtlarlar; biri kırılırsa yayın yok. Bu yerel bir yayın öncesi kapıdır: CI çalıştırmaz,
çünkü sysroot (sıfırdan derlemesi yaklaşık 15 dakika) ve emülatör gerekir.

| Kanarya | Upstream | Neyi kanıtlar | Emülatörde son çalışma |
| --- | --- | --- | --- |
| `glib` | GLib 2.78.6 unit testleri (veri yapıları, string, thread, main loop) | sysroot GLib, compat `pipe`/`poll`, thread | 333 vaka geçti, 8 vaka adıyla atlandı, 19 sn |
| `imgui` | Dear ImGui 1.91.5 SDL2 + OpenGL3 örneği (tek küçük yama) | C++ derleme, SDL2 penceresi, GLES3 bağlamı, vendored ImGui; Nexvyn OS penceresi olarak da (`build-win`, pencere ve tam ekran) | 120 kare, 1440 vertex, 12 sn (pencere: 120 kare, 1432 vertex) |
| `minicoro` | minicoro 0.1.3 test programları, ucontext arka ucunda | `makecontext`/`swapcontext`, `thread_local`, pthread | 4 program geçti, 7 sn |
| `qemu` | QEMU 9.2.0, `aarch64-softmmu` | yalnızca fizibilite notu: sysroot'a karşı configure, engeller listelenir | kapı değil |

```
python tools/canary.py --list                  # tarifler ve derleme durumu
python tools/canary.py build [ad ...]          # indir (sha256 kontrolü), yamala, derle -> build/canary/<ad>.nro
python tools/canary.py run [ad ...]            # isteğe bağlı: emülatör, tek seferde bir kanarya, sdmc:/canary/<ad>.txt okunur
python tools/canary.py check                   # yalnızca tarif denetimi, toolchain gerekmez
```

Her program `sdmc:/canary/<ad>.txt` dosyasına tek satır yazar: `PASS <ayrıntı>` ya da `FAIL <ayrıntı>` (çıktısı
`<ad>.log` dosyasına gider); dosya `FAIL did not finish` olarak başlar, yani çöken program geçemez. Kaynaklar
`build/canary-cache` altına indirilir (sürüm kontrolü dışı, depoya asla kopyalanmaz). Yama yalnızca upstream'de başsız
mod yoksa tutulur (`imgui`); `sdk/native/canary/` altındaki her kanarya klasörünün `README.md` dosyası her değişikliği
ve atlanan her vakayı kanıtıyla listeler. `build` sysroot ister (`build/native-sysroot`, yoksa arşivden açılır), kit
kütüphaneleri yoksa onları da derler. Yeniden başlatma bir şey kaybettirmez: biten kanaryalar atlanır.

## Switch'te yapılamayanlar

| Yok | Çözüm |
| --- | --- |
| `fork`, `exec`, `system`, `popen` | Kodu süreç içinde çağır (yardımcıyı fonksiyona çevir) ya da thread'de çalıştır. |
| Birden çok süreç | Tek süreç, çok thread (`pthread` / `std::thread` çalışır). Süreç havuzunu thread havuzuna çevir. |
| `pty`, `openpty` | Konsolu app içinde kur (libnx `consoleInit` ya da SDL2 ile yazı çiz). |
| Gerçek symlink (FAT) | Dosyayı kopyala ya da app içinde yol tablosu tut. Arşiv açıcılar symlink girdilerini atlamalı. |
| Dosya `mmap` | Dosyayı belleğe oku. |
| Linux `.so` dosyasının `dlopen`'ı | Eklentiyi `.nxvlib` olarak yeniden derle (yukarıda "Paylaşılan kütüphaneler"); `dlopen` onu yükler. |
| `ucontext` (`makecontext`) | Uyum katmanı gelince kitin coroutine katmanı, o zamana kadar küçük bir assembly bağlam değiştirici. |
| `SIGSEGV` işleyicileri | Bu kit sürümünde yok; sınır kontrollerini yazılımda yap. |
| Büyük/küçük harfe duyarlı dosya adı | PC verisi için `fopen_ci()` (`decomp-skeleton` şablonunda). |
| Program yanına yazma | `sdmc:/` altına yaz (örn. `sdmc:/switch/<app>/`). |
| Tam ekran modu değiştirme | Ekran elde 1280x720, dock'ta 1920x1080; açılışta sorgula. |

Derleme anında henüz zorlanmayan kontroller native platform planında (aşama 3.5) listelidir.

## Lisanslar

Kitteki üçüncü taraf kod: Dear ImGui (MIT, `sysroot/vendor/imgui/LICENSE.txt`). Tarif kütüphaneleri kendi lisanslarını
taşır; LGPL olanlar (OpenAL, libiconv, glib) statik bağlanırken olağan dikkati ister.
