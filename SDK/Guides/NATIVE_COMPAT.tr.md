# Nexvyn Native Uyum Katmanı

`libnexvyn_compat.a`, native kite eklenen isteğe bağlı bir bağlama katmanıdır. libnx / newlib ile tipik Linux ya da PC
C ve C++ kodu (emülatör, decomp port, glib tarzı kütüphane) arasındaki POSIX boşluklarını doldurur; böylece bu kod
az değişiklikle derlenir ve çalışır. Exclusive `.nro`'da da, pencerede ve Nexvyn içi tam ekranda da (süreç içi `.nxvmod`)
aynı çalışır; bkz. [Pencerede ve Nexvyn içi tam ekranda](#pencerede-ve-nexvyn-içi-tam-ekranda). Yalnızca Nexvyn ABI'sini ya da SDL2'yi kullanan app'ler buna
ihtiyaç duymaz. OS'u hiç değiştirmez: app'e bağlanır, bağlamayan app eskisi gibi davranır.

Ne değildir: ikinci bir işletim sistemi. Tek süreç, tek adres alanı ve FAT bir SD kart vardır. Çalışamayan çağrılar
(`fork`, `exec*`, ...) temiz biçimde hata verir ve app günlüğüne yazar; bkz. [Çalışamayanlar](#çalışamayanlar).

Kaynak: `sdk/native/compat/`. Testler: `sdk/native/compat/tests/`. Sürüm: `nxc_version()` (1.0, Native SDK 1.0 ile).

## Kullanım

Kütüphaneyi bir kez derle (devkitPro kabuğunda ya da `DEVKITPRO` tanımlıyken):

```
make -C sdk/native/compat   # -> lib/libnexvyn_compat.a (exclusive .nro) ve lib/libnexvyn_compat_pic.a (pencere / tam ekran)
```

CMake (kit toolchain'i):

```cmake
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)
add_executable(mygame main.c)
target_link_libraries(mygame PRIVATE SDL2 ...)   # önce kendi kütüphanelerin
nexvyn_use_compat(mygame)                        # katman (sıra fark etmez: bağlama satırının sonuna da eklenir)
nexvyn_compat_fsmap(mygame)                      # isteğe bağlı, bkz. Yollar
nexvyn_add_nro(mygame TITLE "My Game")
```

`nexvyn_use_compat(target [STRICT | STRICT_ERROR] [NO_FORCE_INCLUDE] [NO_WRAP])` iki modda da aynı çağrıdır:
`-DNEXVYN_WINDOWED=ON` ile (`nxv-native build` bunu verir) `-fPIC` arşivi ve wrap bayraklarını, `nexvyn_add_nro()`'nun aynı
kaynaklardan yaptığı `.nxvmod` için kaydeder. Exclusive modda include klasörünü ekler,
`nexvyn/compat_posix.h` dosyasını zorla dahil eder, `-lnexvyn_compat` ile `wrap_core.txt` içindeki `--wrap`
bayraklarını bağlar. Tek başına çalışır: `nexvyn_compat_fsmap()` yalnızca PC yol işlemesi içindir. Arşiv ayrıca çağıran
klasördeki her C / C++ çalıştırılabilirin bağlama komutunun en sonuna bir kez daha eklenir; CMake'in sonra koyduğu
kütüphaneler (SDL2 arkasındaki libEGL gibi) sarmalanmış çağrıları yine bulur (eskiden burada
`undefined reference to __wrap_fcntl` çıkardı).

Makefile (devkitPro tarzı): `include <kit>/compat/compat.mk`, sonra derleme bayraklarına `$(NXC_CFLAGS)`, bağlama
bayraklarına `$(NXC_LDFLAGS)` ekle, `LIBS` içinde `$(NXC_LIBS_END)` değerini **en sona** yaz (`-Wl,--start-group -lnexvyn_compat -lnx -Wl,--end-group`:
statik kütüphane bir kez taranır, bu yüzden sarmalanmış çağrıyı yapan her kütüphaneden sonra gelmeli). `$(NXC_LIBS)`
yalnızca `-lnexvyn_compat`'tir, kendi yerleştirenler için. `tests/compat_test/Makefile` tam bir örnektir.

Pencere (`.nxvmod`, `-fPIC`, `-shared`) yapan Makefile projeleri nesneleri `$(NXC_WIN_LDFLAGS) $(NXC_WIN_LIBS)` ile bağlar
(arşiv nesnelerden sonra, `-lnexvyn_window`'dan önce gelir); elle yazılmış `nexvyn_add_windowed()` için
`nexvyn_compat_window_args()` vardır (`examples/showcase/CMakeLists.txt`). Derleme bayrakları aynı `$(NXC_CFLAGS)`'tir.

Nasıl çalışır: libnx ya da newlib'in zaten tanımladığı çağrılar (`poll`, `select`, `fcntl`, `getpid`, `raise`, ...)
bağlayıcının `--wrap` seçeneğiyle devralınır; orijinal erişilebilir kalır, hiçbir şey iki kez tanımlanmaz. Hiç olmayan
çağrılar (`mmap`, `pipe`, `getcontext`, ...) düz tanımdır. newlib'de olmayan başlıklar (`<sys/mman.h>`, `<ucontext.h>`,
`<sys/eventfd.h>`, `<dlfcn.h>`, `<sys/utsname.h>`, `<sys/random.h>`) `compat/include/` içindedir; `<sys/signal.h>` ve
`<sys/resource.h>` newlib başlığını sarar ve eksiklerini ekler (`sa_sigaction` alanlı `struct sigaction`, `SA_RESTART`,
`getrlimit`).

`nxc_init()` isteğe bağlıdır. Çalışma dizinini app'in veri klasörüne taşır (Nexvyn ABI bağlıysa
`nxn_fs_path(NXN_DIR_DATA)`, değilse `sdmc:/switch`) ve tanımsızsa `HOME`, `PWD`, `TMPDIR`, `USER` değişkenlerini kurar.

## Pencerede ve Nexvyn içi tam ekranda

`.nxvmod` Nexvyn OS'un sürecinin içinde, pencerede ya da Nexvyn'in kendi tam ekranında çalışır (tek yükleyici, tek build;
kullanıcı çalışırken geçiş yapar). Katman **app'in modülüne bağlanır** (`libnexvyn_compat_pic.a`: aynı kaynaklar `-fPIC` ve
`NXC_WINDOWED=1` ile derlenir); gereken libnx ve C kütüphanesi işlevlerini Nexvyn OS'un host import kümesi sunar (`poll`,
`ioctl`, `svcGetProcessId`, `FindDevice` / `AddDevice` / `RemoveDevice`, aşağıdaki BSD soketler ...; liste yalnızca
eklenir, `NATIVE_SDK_DESIGN.md` 3.2.2). Yani aynı çağrılar aşağıdaki tablodaki gibi davranır; farklar şunlar:

| Alan | Exclusive `.nro` | Pencere / Nexvyn içi tam ekran |
|---|---|---|
| Durum kimin | tüm süreç app'tir | katmanın her tablosu app'in modülünde yaşar: tanımlayıcılar, eşlemeler, sinyaller ve timer thread'i, ortam, çalışma dizini o app'indir; başka app'le ya da Nexvyn OS'la karışmaz |
| Tanımlayıcılar (`pipe`, `eventfd`, `/dev/*`) | devoptab `nxcfd:` | her pencerenin kendi devoptab'ı (modülün adresinden adlanır); app bitince kapatılır ve kaldırılır |
| Çalışma dizini | sürecin | app'in kendisinin: `chdir`, `getcwd`, `realpath` ve sarmalanmış çağrıların (`open`, `fopen`, `stat`, `access`, `mkdir`, `opendir`, `rename`, `unlink` ... `wrap_fsmap.txt` dosya ailesi, burada her zaman sarmalanır) göreli yolları bunu kullanır. Sürecin dizini Nexvyn OS'undur ve hiç değiştirilmez. Bu ailenin dışındaki çağrılar (`creat`, `utime` ...) mutlak yol ister |
| Ortam | newlib'in tablosu | app'in kendi tablosu ve `environ`: `setenv`, `putenv`, `getenv`, `clearenv` Nexvyn OS'un ortamını hiç değiştirmez; `putenv` metni kopyalar, içine asla yazmaz (salt okunur bellekteki literal sorun değil) |
| `getpid` | süreç kimliği | aynı (süreç Nexvyn OS'undur, paylaşılır) |
| Runtime bağlantıları | `libnexvyn_native` katmanı çağırır | aynı etki, `nxn_init`, `nxn_event_poll`, `nxn_should_quit`, `nxn_sleep_ns`, `nxn_shutdown`, `nxn_run` import'ları üzerinde `--wrap` ile yapılır (`nxn_*`'i Nexvyn OS gerçekler, modülün içine çağıramaz). `nxn_thread_join` normal bekler: sinyal join'den sonra iletilir, sırasında değil |
| App sonu | süreç çıkışı | `nxc_shutdown`, sonra tanımlayıcılar, eşlemeler (`MAP_SHARED` geri yazılır), ortam, soketler ve TLS yuvaları `atexit` ile, app'in thread'inde, kodu hâlâ yüklüyken bırakılır. Geri alınmayanlar (her pencere gibi, `NATIVE_SDK_DESIGN.md` 3.2.7): `open` / `fopen` ile açılmış dosyalar ve app'in kendi heap'i |
| `thread_local` | serbest | `native.windowedTls` ayarıyla (`NXN_CAP_TLS`; nesneler kitin `-mtls-dialect=trad` bayrağıyla, `NATIVE_SDK_DESIGN.tr.md` 3.2.10); kapalıyken yüklemede reddedilir. Katmanın kendisi libnx TLS yuvalarını kullanır |
| Soketler | libnx | izin denetiminin arkasında libnx, bkz. [Pencerede soketler](#pencerede-soketler) |
| `dlopen`, `PROT_EXEC` | `.nxvlib` / sonra JIT servisi | `dlopen` `native.windowedLibs` ayarıyla (`NXN_CAP_SHARED_LIBS`) `.nxvlib` yükler, yoksa nedeniyle `NULL` döner; `PROT_EXEC` `ENOTSUP` (çalıştırılabilir bellek: `nxn_jit_*`, `native.windowedJit` ayarı, `NXN_CAP_JIT`); ikisi de temiz hata verir |
| `romfs:/` | NRO'nun romfs'i | yok: dosyaları pakete koy (`nxn_fs_path`) |

Pencere ve Nexvyn içi tam ekran aynı modül ve aynı katmandır: katman görüntü modunu bilmez. Pencere ve exclusive app aynı
programla sınanır (bkz. Testler).

### Pencerede soketler

BSD soketler (`socket`, `bind`, `listen`, `accept`, `connect`, `send*`, `recv*`, `shutdown`, `get/setsockopt`,
`getsockname`, `getpeername`) ve ad çözümleme (`getaddrinfo`, `gethostbyname`, `gethostbyaddr`, `getnameinfo`) app başına
Nexvyn OS tarafından sunulur:

- app'in `app.json` `"permissions"` listesinde `"network"` olmalıdır (harf büyüklüğü fark etmez). Yoksa her çağrı `EACCES`
  ile başarısız olur (ad çözümleme `EAI_FAIL` döner) ve app günlüğüne `permission denied: network (<çağrı>)` satırı yazılır.
  Kullanıcı kurulum sayfasında ya da Ayarlar > Gizlilik ve Güvenlik'te de kapatabilir (saklı yanıt manifestten önce gelir).
  `"permissions"` dizisi olmayan paketin ağı yoktur. Yanıt pencere açılırken bir kez okunur.
- izin varsa çağrı libnx soketlerine gider. Soket servisi Nexvyn OS'undur: app'te `socketInitialize()` / `socketExit()` boştur
  (`socketInitializeDefault()` izinle başarılı, izinsiz başarısız olur); app servisi hiç başlatmaz ya da durdurmaz.
- başlıklar: `<sys/socket.h>`, `<netinet/in.h>`, `<netinet/tcp.h>`, `<arpa/inet.h>`, `<netdb.h>`, `<net/if.h>`, `<poll.h>`,
  `<sys/select.h>` libnx'in include klasöründen gelir (her kit derlemesinde include yolundadır); `<sys/un.h>` (yalnızca tip:
  UNIX alan soketleri yoktur, `socket(AF_UNIX, ...)` temiz hatayla başarısız olur) ve `<ifaddrs.h>` kitin `compat/include`
  klasöründendir. Port için soket shim'i gerekmez: `nexvyn_use_compat()` ile derleyin, izinlere `"network"` ekleyin. `fork`,
  `execvp` ve benzerleri `ENOSYS` ve bir günlük satırıyla başarısız olur ("Çalışamayanlar" başlığı), `dlopen` `.nxvlib`
  dosyalarını yükler (ayar `native.windowedLibs`).
- konsolda ağ yoksa (bağlantı yok, servis yok): Nexvyn OS eskisi gibi açılır, app'in çağrıları libnx'in `errno`'suyla
  başarısız olur; başka hiçbir şey etkilenmez.
- `poll`, `select` ve `ioctl` soketlerde, pipe ve eventfd ile karışık, yukarıdaki gibi çalışır. Bloklayan `recv`, `accept` ya da
  `connect` yalnızca app'in kendi thread'ini bloklar: Nexvyn OS'un ana thread'i bunun için soket çağrısı yapmaz.
- katman app'in açtığı soketleri not eder ve app bitince hâlâ açık olanları kapatır.

## POSIX çağrıları

| Alan | Çağrılar | Davranış |
|---|---|---|
| Bellek | `mmap`, `munmap`, `mprotect`, `msync`, `madvise`, `mremap`, `mlock*` | 4 KiB hizalı heap blokları. Anonim bellek sıfırlıdır. Dosya eşlemesi bloğa okunur; `MAP_SHARED` + `PROT_WRITE` `msync` ve `munmap`'ta geri yazılır. Kısmi `munmap` tüm sayfalar bırakılana kadar bloğu tutar. `MAP_FIXED`, `mmap`'in daha önce verdiği blok içinde çalışır. Korumalar kaydedilir, uygulanmaz (guard page yok). `PROT_EXEC` `ENOTSUP` ile ve tek günlük satırıyla reddedilir: çalıştırılabilir bellek JIT servisini bekler. Konsolda SD kart dosya sistemi yazmaya açık dosyayı kilitler. Böyle bir dosyada `stat`, `lstat` ve `access` çalışır: katman bu süreçte yazmaya açılan her dosyanın yolunu hatırlar (`open`, `fopen`; `close` / `fclose` ile silinir) ve cevabı o tanımlayıcının `fstat`ına verir (`dup`, `fdopen` ya da `freopen` ile yapılan tanımlayıcı izlenmez). Dosya sisteminin hâlâ reddettiği: yazmaya açık dosyanın ikinci kez `open` / `fopen` edilmesi; bu yüzden `MAP_SHARED` tanımlayıcısı açıkken dosyayı yeniden açmayın, o tanımlayıcıdan okuyun. |
| Bilgi | `sysconf`, `getpagesize`, `getrlimit`, `uname`, `getrandom`, `getentropy` | Sayfa boyutu 4096; CPU sayısı süreç çekirdek maskesinden (app'lerde 3); bellek sayfaları süreçten ve libnx heap'inden. |
| Kimlik | `getpid`, `getppid`, `getuid`..., `umask` | `getpid` gerçek süreç numarasıdır ve değişmez; diğerleri sabittir. |
| Tek kullanıcı | `getuid`, `geteuid`, `getgid`, `getegid`, `getpwuid`, `getpwuid_r`, `getpwnam`, `getpwnam_r`, `getlogin` | Tek bir kullanıcı vardır: ad `nexvyn`, uid ve gid 1000, ev klasörü `$HOME` ya da `sdmc:/`, boş shell. Başka uid ya da ad "bulunamadı" olur (`NULL`, `errno` 0; `_r` biçimleri 0 döner, `*result == NULL`). Sabittir, konsolun kullanıcısı değildir. (Kit 1.1, yalnızca ekleme.) |
| Metin girişi | `getline`, `getdelim` | Gerçek; newlib'in `__getdelim`'inin üstünde (newlib'de herkese açık ad yok). `nexvyn/compat_posix.h` içinde bildirilir (`nexvyn_use_compat()` zorla ekler). (Kit 1.1, yalnızca ekleme.) |
| Arayüzler | `getifaddrs`, `freeifaddrs` (`<ifaddrs.h>`) | Arayüz listesi yoktur: `getifaddrs` `ENOSYS` ile başarısız olur (bir günlük satırı), listeyi `NULL` yapar; doğrudan ad ya da adrese bağlanın. |
| Pipe | `pipe`, `pipe2`, `eventfd`, `eventfd_read/write` | Süreç içi: normal bir tanımlayıcının arkasında 64 KiB halka tampon (pipe) ya da sayaç (eventfd). `read`, `write`, `close`, `dup`, `fstat`, `fcntl(F_GETFL/F_SETFL/F_GETFD/F_SETFD/F_DUPFD)`, `ioctl(FIONBIO/FIONREAD)`. Bloklayan ve bloklamayan, EOF, `EPIPE`, 4096 bayta kadar atomik yazma. |
| Hazırlık | `poll`, `ppoll`, `select`, `pselect` | Pipe, eventfd, socket ve normal dosyalarda tek kümede çalışır (normal dosya her zaman hazırdır). Başka bir thread yazınca bekleyen anında uyanır; socket'ler beklerken 2 ms'de bir bakılır. `select(0, ...)` ve `poll(NULL, 0, ms)` uyur. |
| Ortam | `getenv`, `setenv`, `putenv`, `unsetenv`, `clearenv`, `secure_getenv` | newlib'in tablosu, argüman denetimi (`EINVAL`) ve bir `clearenv` ile. |
| Dizin | `getcwd`, `chdir`, `realpath` | `sdmc:/...` yollarında çalışır; `realpath` `.` ve `..` çözer, dosyanın varlığını denetler, bağ izlemez (bağ yoktur). `NXC_FS_VROOT` ile `/` app klasörünü gösterir. `chdir` `$PWD`'yi doğru tutar. |
| Dosya tanıtıcıları | stdio ve SD kartı / romfs dosyalarında `fcntl` | libnx'in `fcntl`'ı bunlarda başarısız olur (`ENOTSOCK`, `EBADF`), GLib gibi kütüphaneler takılır. `F_GETFL` cevap verir (stdin `O_RDONLY`, stdout ve stderr `O_WRONLY`, dosyalar `O_RDWR`: çekirdek açılış bayraklarını tutmaz, erişim kipi tahmindir), `F_SETFL` kabul edilir ve bir şey değiştirmez (dosyada non-blocking kip yok), `F_GETFD` / `F_SETFD` 0 döner, `F_DUPFD` çoğaltır. Kapalı ya da geçersiz tanıtıcı `EBADF`. Socket'ler libnx'e gider; pipe ve eventfd kendi bayraklarını korur. |
| Aygıtlar | `/dev/null`, `/dev/zero`, `/dev/random`, `/dev/urandom` | `open`, `fopen`, `stat`, `lstat`, `access` ile (tanıtıcıda `fstat`, `read`, `write`, `lseek`, `dup`, `fcntl`, `poll` da). `null` yazılanı yutar, okunca EOF verir; `zero` sıfır okutur; `random` ve `urandom` konsolun rastgele üretecinden okur, hiç bloklamaz; `stat` karakter aygıtı der; `/dev` bir klasördür. PC yol çevirisinden önce bakılır, `NXC_FS_VROOT` bunları kaydırmaz. Kapsam dışı: `freopen` ve `opendir("/dev")`. |
| C11 zaman | `timespec_get(ts, TIME_UTC)` | Duvar saati; başka taban 0 döner. `nexvyn/compat_posix.h` içinde bildirilir (newlib'de yok). |
| Zaman | `clock_gettime`, `clock_getres`, `clock_nanosleep`, `nanosleep`, `sleep`, `usleep`, `sched_yield` | Tüm saat numaraları çalışır; CPU zamanı saatleri ilk çağrıdan beri geçen süreyi verir (çekirdek CPU zamanı vermez). Uykular PC'deki gibi sinyalle kesilir. |
| Kütüphane | `dlopen`, `dlsym`, `dlclose`, `dlerror`, `dladdr` | `dlopen(dosya)` bir Nexvyn paylaşılan kütüphanesini (`.nxvlib`) `nxn_lib_open` ile yükler ("Paylaşılan kütüphaneler (dlopen)" bölümü). `dlopen(NULL)` ve `dlsym(RTLD_DEFAULT, ad)` önce `nxc_dl_register(ad, adres)` tablosuna, sonra app'in export'larına ve açık her kütüphaneye bakar; isteğe bağlı fonksiyonları yoklayan portlar temiz yanıt alır. `dladdr` bir şey bulmaz. |

## Coroutine

`<ucontext.h>` AArch64 için `getcontext`, `setcontext`, `swapcontext`, `makecontext` içerir. Bir bağlam `x19`-`x30`, `sp`,
`d8`-`d15`, `fpcr`, `fpsr` (AAPCS64'ün callee-saved kümesi) ile `makecontext` argümanları için `x0`-`x7` tutar (en çok 8
`int` argüman). Sinyal maskesi saklanır ama değiştirilmez. Bir geçiş emülatörde 0,2 mikrosaniye ölçüldü (4 ms'de 20000
geçiş). Bağlamı onu yapan thread'de sürdür; bir bağlamın çalıştırdığı fonksiyondan C++ exception çıkmasına izin verme.

Üstünde küçük bir API vardır:

```c
nxc_coro* c = nxc_coro_create(fn, arg, 0);   // 0 = 64 KiB stack (heap), alt uçta guard deseni
while (nxc_coro_resume(c) == 1) { }          // 1 yield etti, 0 bitti, -1 hata (bitmiş, taşma, çalışıyor)
nxc_coro_yield();                            // fn içinde
nxc_coro_destroy(c);
```

Coroutine'ler iç içe çalışır (biri diğerini resume edebilir). `nxc_coro_stack_free()` stack'in hiç dokunulmamış kısmını
söyler; guard'a ulaşan taşma bir sonraki geçişte yakalanır ve günlüğe bir kez yazılır.

## Sinyaller (benzetim)

Burada çekirdek sinyal teslimi yoktur. Sinyal bir bekleyen bittir; handler'ı bu katmanın içindeki bir thread'de güvenli bir
noktada çalışır:

- `raise`, `kill(getpid(), sig)`, `pthread_kill`: handler çağrı dönmeden önce çalışır (sinyal engelli değilse).
- `alarm`, `ualarm`, `setitimer(ITIMER_REAL)`: küçük bir zamanlayıcı thread'i yalnızca bekleyen biti kurar ve bekleyenleri
  uyandırır. Handler zamanlayıcıyı kuran thread'de çalışır: `sleep`, `poll`, `select`, pipe ya da eventfd okuması,
  `sigsuspend`, `sigwait` içinde ya da `nxc_signal_poll()` içinde. Bu çağrılarda bloklamayan bir programda **her karede ya
  da döngü turunda bir kez `nxc_signal_poll()` çağır**.
- `sigaction` (`SA_SIGINFO`, `SA_RESTART`, `SA_NODEFER`, `SA_RESETHAND` bayrakları, handler maskeleri), `signal`,
  `sigprocmask`, `pthread_sigmask`, `sigpending`, `sigsuspend`, `sigwait`.
- Kesilen bloklayan çağrı `-1` ve `EINTR` döner; `sleep` kalan saniyeyi döner. Pipe `read` / `write` handler'da `SA_RESTART`
  varsa yeniden başlar; `poll`, `select` ve uykular hiç yeniden başlamaz (Linux'taki gibi).
- Süreç genelinde tek sinyal maskesi. Yalnızca standart sinyaller, birleşir (kuyruk yok, gerçek zamanlı sinyal yok).
- "Sonlandır" varsayılan eylemi app'i bir günlük satırıyla 128 + sinyal çıkış koduyla bitirir; "yoksay" sinyalleri
  (`SIGCHLD`, `SIGPIPE`, `SIGWINCH`, ...) düşürülür. Bu yüzden program handler kurmadıkça `SIGPIPE` zararsızdır.
- `SIGSEGV`, `SIGBUS`, `SIGILL`, `SIGFPE` handler'ları kabul edilir ve hiç çağrılmaz (Native v2). Gerçek bir çökme Nexvyn
  çökme işleyicisine gider.

## Yollar (isteğe bağlı)

PC yolları için yazılmış portlar her dosya çağrısında çeviri isteyebilir: CMake'te `nexvyn_compat_fsmap(target [FLAGS ...])`,
Makefile'da `compat/fsmap_on.c` dosyasını ve `$(NXC_FSMAP_LDFLAGS)` değerini ekle. Çalışma anında `nxc_fs_enable(bayraklar)`
kümeyi değiştirir (0 = kapalı). Bayraklar:

| Bayrak | Etki |
|---|---|
| `NXC_FS_CASEFOLD` | `open`, `fopen`, `freopen`, `stat`, `lstat`, `access`, `opendir`, `mkdir`, `rmdir`, `unlink`, `remove`, `rename`, `truncate`, `chmod` büyük/küçük harfi farklı dosyayı bulur. Yalnızca tam ad yoksa denenir, bu yüzden SD kartta maliyeti sıfırdır (FAT zaten harf duyarsız); büyük/küçük harfe duyarlı `romfs:/` ve bundle için gereklidir. Hiçbir yerde olmayan ad verildiği gibi bırakılır, dosya yaratırken yazımın korunur. |
| `NXC_FS_BACKSLASH` | `\` ayraçtır. |
| `NXC_FS_DRIVES` | `C:` ... `Z:` kök klasöre eşlenir (ya da `nxc_fs_map_drive('D', "romfs:/Data")`). |
| `NXC_FS_VROOT` | `/x` = `<kök>/x`; `getcwd`, `realpath` `/...` gösterir. Kök: `nxc_fs_set_root()`, varsayılan veri klasörü. |

Aygıt taşıyan yollara (`sdmc:/`, `romfs:/`) sürücü ve kök kuralları dokunmaz. `nxc_fs_translate()` çeviriyi tek başına
verir. Bayrakları thread başlatmadan önce kur.

## PC tipleri

decomp portları için `#include <nexvyn/nxc_pc_types.h>` (yalnızca başlık): `BOOL`, `BYTE`, `WORD`, `DWORD`, `LONG`, `UINT`,
`QWORD`, opak `HANDLE` ve `INVALID_HANDLE_VALUE`, `MAX_PATH`, `_countof`, `LOBYTE` / `HIWORD` / `MAKEWORD` ..., `ZeroMemory`
..., `stricmp`, `strnicmp`, `_strdup`, `_snprintf`, `strcpy_s`, `Sleep`, `GetTickCount`, `QueryPerformanceCounter`,
`GetLastError`. İsim köprüsüdür: hiçbir şey çekirdek nesnesi açmaz. `min` / `max` makroları yalnızca `NXC_PC_MINMAX` ile.

## Çalışamayanlar

Bunlar `ENOSYS` (ya da doğal hata) ile başarısız olur ve çağrı adı başına bir günlük satırı yazar:

| Çağrı | Sonuç | Olağan çözüm |
|---|---|---|
| `fork`, `vfork` | `ENOSYS` | Thread'e çevir ya da kodu süreç içinde çağır (programın tek süreç modu). |
| `exec*`, `posix_spawn*`, `system(komut)`, `popen` | `ENOSYS` (`system(NULL)` `0`: kabuk yok) | Fonksiyonu çağır; aracı kütüphane olarak bağla. |
| `wait`, `waitpid` | `ECHILD` | Beklenecek bir şey yok. |
| `openpty`, `forkpty`, `posix_openpt` | `ENOSYS` | `pipe()` ya da süreç içi tampon. |
| `symlink`, `link` | `ENOSYS` | SD kart FAT: dosyayı kopyala ya da yol tablosu tut. `readlink` `EINVAL` (hiçbir şey bağ değildir). |
| `mkfifo`, `mknod` | `ENOSYS` | Süreç içinde `pipe()`. |
| `kill(başka pid, ...)` | `ESRCH` | Başka süreç yok. |
| `chown` ve benzerleri | başarılı | FAT'ta sahip yok. |
| `mmap(PROT_EXEC)`, `mprotect(PROT_EXEC)` | `ENOTSUP` | `nxn_jit_*` kullanın (`nxn_jit.h`, `NXN_CAP_JIT`): rw + rx görünüm, cache bakımı. |
| Linux `.so` dosyasının `dlopen`'ı | `NULL`, nedeni `dlerror()` içinde | Eklentiyi `.nxvlib` olarak yeniden derle (`NATIVE_KIT.tr.md`) ya da statik bağla. |

`-DNXC_STRICT=1` (CMake: `nexvyn_use_compat(target STRICT)`) süreç ve bağ fonksiyonlarına yapılan çağrıları, yerine ne
kullanılacağını söyleyen derleme uyarısına çevirir; `STRICT_ERROR` (`NXC_STRICT=2`) hataya çevirir. Port ederken hepsini
bulmak için kullan.

## Sınırlar

- Fastmem: gerçek bir data abort `nxn_fault_handler_set` ile önce app'e gidebilir (`nxn_jit.h`, `native.windowedFaultHandler` ayarı, `NXN_CAP_FAULT_HANDLER`); handler register'ları düzeltir, thread devam eder. Koruma sayfaları: `nxn_mem_guard` (`native.windowedGuardPages`). İkisi de varsayılan kapalı; bkz. `NATIVE_SDK_DESIGN.tr.md` 3.2.11.
- Pipe ve eventfd tek sürecin thread'leri içindir. `socketpair`, `epoll`, `timerfd`, `signalfd`, `inotify` yok.
- Bellek eşlemeleri heap kopyasıdır: çok büyük seyrek rezervasyon (4 GiB `PROT_NONE` adres alanı) `ENOMEM` ile başarısız
  olur, dosya eşlemesi dosya boyutu kadar RAM tutar.
- Sinyaller işbirlikçidir (yukarı bak); benzetim, katmana hiç girmeyen kodu kesmez.
- Katman tanımlayıcılar ve sinyaller için tek kilit tutar. Kilitliyken dosya ya da socket G/Ç'si yapmaz, sinyal
  handler'larını kilitsiz çalıştırır ve kilit altında SDL, GL ya da kullanıcı kodunu çağırmaz; bu yüzden onlarla kilit
  döngüsüne giremez.
- Kit toolchain'i gerekir (devkitA64 15.2, newlib, libnx 4.10).
- Pencerede: `thread_local`, C++ exception ve `dlopen` yalnızca ayarlarıyla (`native.windowedTls`, `native.windowedEh`,
  `native.windowedLibs`, varsayılan kapalı), göreli yollar yalnızca sarmalanmış dosya çağrılarından geçer, `nxn_thread_join`
  beklerken sinyal iletmez, `romfs:/` yok (hepsi pencere bölümünün tablosunda).

## Native runtime ile bağlantılar (`libnexvyn_native`)

Runtime kütüphanesi katmana **weak** referansla bağlanır. `libnexvyn_compat`'ı link etmeyen app eskisi gibi derlenir ve
çalışır (weak tanımsız sembol arşivi çekmez). İkisi de link edilince:

Pencerede aynı bağlantılar `nxn_*` import'ları üzerinde `--wrap` ile yapılır (pencere bölümü). Exclusive mod:

| Runtime çağrısı | Bağlantı |
|---|---|
| `nxn_init` | sandbox yolları belli olunca `nxc_init()` |
| `nxn_event_poll`, `nxn_should_quit` | `nxc_signal_poll()`: `alarm()` / `setitimer()` sinyalleri her karede iletilir |
| `nxn_shutdown` | `nxc_shutdown()`: timer'ları kapatır, sinyal timer thread'ini durdurur |
| `nxn_sleep_ns` | `nxc_sleep_interruptible()`: uyurken handler'lar çalışır, uyku yine tam süre sürer |
| `nxn_thread_join` | 10 ms'lik dilimlerle bekler, aralarda `nxc_signal_poll()` çalıştırır (yalnızca exclusive) |

`nxc_shutdown()` ve `nxc_sleep_interruptible(ns)` (tam süreden sonra 0, handler çalışırsa -1 ve `EINTR`) `nexvyn/compat.h`
içinde herkese açıktır; runtime olmadan da kullanılır.

Planlı, 1.0'da yok: `PROT_EXEC`'in `nxn_jit_*`'a bağlanması (bugün JIT için doğrudan `nxn_jit_*`).

## Paylaşılan kütüphaneler (dlopen)

`dlopen`, `dlsym`, `dlclose` ve `dlerror` Native SDK'nın paylaşılan kütüphanelerine gider (`nxn_lib_*`; derleme ve
dağıtım `.nxvlib` olarak: `NATIVE_KIT.tr.md`, "Paylaşılan kütüphaneler"). Eklenti yükleyen portlar, eklenti `.nxvlib`
olarak yeniden derlenince değişmeden çalışır.

- Adlar: bir yol (`"plugins/foo.so"`, `"sdmc:/x/foo.nxvlib"`) ya da yalın ad (`"libfoo.so"`, `"libfoo.so.2"`); yalın ad
  önce `libfoo.nxvlib`, sonra `foo.nxvlib` olarak app'in `.nro`'sunun yanında ve `<data>/lib/` içinde aranır. Var olmayan
  bir yol aynı klasörde `.nxvlib` adıyla da denenir.
- Bayraklar: `RTLD_LAZY`, `RTLD_NOW`, `RTLD_GLOBAL`, `RTLD_LOCAL` ve `RTLD_NODELETE` kabul edilir, bir şey değiştirmez
  (her kütüphane hemen bağlanır, sembolleri `dlsym(RTLD_DEFAULT, ...)` ile görünür, app bitene kadar yüklü kalır).
  `RTLD_NOLOAD` yalnızca `dlopen`'ın daha önce açtığı kütüphaneyi döndürür, yoksa `NULL`.
- `dlsym(handle, ad)` yalnızca kütüphanenin kendi export'larını döndürür; `dlsym(RTLD_DEFAULT, ad)` sırasıyla
  `nxc_dl_register` tablosuna, app'in export'larına ve açık her kütüphaneye bakar. Açık bir kütüphane olmayan handle
  okunmadan reddedilir.
- `dlerror()` yükleyicinin mesajını verir ("libfoo.so: not found ...", "foo: missing symbol bar (...)", "foo: version
  2.0.0 is installed, this app needs 1.x", applet modunda JIT notu).
- Link: katman `libnexvyn_native`'e zayıf referansla bağlıdır. CMake'te (`NEXVYN_ABI` açık) `nexvyn_use_compat`
  yükleyiciyi link'e çeker; Makefile projeleri `LDFLAGS`'a `$(NXC_DL_LDFLAGS)` ekler. `libnexvyn_native` yoksa `dlopen`
  bunu söyleyen bir mesajla başarısız olur.
- Pencerede (`native.windowedLibs` ayarı): `nxn_lib_*`'ı Nexvyn OS sunar, aynı çağrılar `libnexvyn_native` olmadan
  çalışır. `.nro` klasörünün yerini app klasörü alır; kütüphanenin import'ları önce modülün export'larına, sonra önce
  açılan kütüphanelere, sonra host import kümesine çözülür; ayarlar açıkken kütüphaneler `thread_local` ve exception
  kullanabilir (`NATIVE_SDK_DESIGN.tr.md` 3.2.10).

## Testler

| Ne | Nasıl |
|---|---|
| Düz C kısımları (yol kuralları, halka tampon) | `python sdk/native/compat/tests/host/run_host.py` (PC'de gcc, clang ya da MSVC) |
| Public başlıklar C ve C++ olarak, wrap listeleri | `python sdk/native/compat/tests/header_check.py` |
| Bağlama davranışı (düz `nexvyn_use_compat()`, katmandan sonra gelen kütüphaneler) | `python sdk/native/compat/tests/link_check.py` (`tests/link_test` derler: `link_test` çekirdeği başka yardımcı olmadan kullanır, `link_order` katmana yalnızca CMake'in arkaya koyduğu bir kütüphane üzerinden ulaşır) |
| `NXC_STRICT` uyarı ve hataları | `python sdk/native/compat/tests/strict_check.py` |
| Geri kalan her şey konsolda ya da emülatörde | `python tools/nxv_native build sdk/native/compat/tests/compat_test` pencere / tam ekran modülünü derler (`--exclusive`: `.nro`), çalıştır, `sdmc:/switch/compat_test/results.txt` dosyasını oku (takılan test bekçi ile kesilir; `.nro` hepsi geçince 0 ile de çıkar). `make` ile de derlenir (`tests/compat_test/Makefile`, `compat.mk` kullanır). |
| Aynı test emülatörde: pencere, tam ekran, exclusive | `python sdk/native/compat/tests/window_run.py --mode window\|fullscreen --net allow\|deny` (ve `--exclusive <nro>`): tek emülatör kilidine uyar, simge durumunda başlar, SD kartı geri alır. `--net deny` yanıtlardan `"network"`'ü çıkarır ve `EACCES` bekler |

Cihaz testinde yaklaşık 390 denetim var (pencerede 385: `romfs:/` yok; soket kısmı `net=allowed` ya da `net=denied` yazar): bellek eşlemeleri, pipe (thread'ler arası 1,5 MiB aktarım), eventfd, poll ve select
(uyanma gecikmesi, pipe ile karışık loopback socket'ler), ortam, dizinler, `dl*`, saatler, kimlik, PC tipleri, desteklenmeyen
çağrılar, `ucontext` (ping-pong, `uc_link`), coroutine'ler (iç içe, 500 tanesi birden, 500 KiB derin stack, kayan nokta
yazmaçları ve `fpcr`, guard denetimi), sinyaller (maskeler, `SA_SIGINFO`, `sigwait`, `sigsuspend`, `sleep` ve `poll`'u kesen
alarm), runtime bağlantıları (app yalnızca `nxn_event_poll()` çağırırken `alarm()` iletilir; `nxn_sleep_ns`) ve yollar (sürücüler, ters eğik çizgi, harf duyarsız `romfs:/`).
