# Büyük bir PC oyununu ya da motorunu port etmek

[English](PORTING_LARGE_GAMES.en.md) · **Türkçe**

Büyük bir PC programını Nexvyn OS'a pencereli native app olarak getirmenin yolu (Native SDK, SDK 1.10 ve sonrası).
Örnek, 2000'lerin başından statik olarak yeniden derlenmiş bir Windows strateji oyunudur: özgün program C'ye çevrildi,
konsol için derlendi ve `nxn_*` API'si üzerinde Win32 ve DirectDraw çağrılarını taklit eden küçük bir *host katmanı*
ile çalışır. Aşağıdakilerin hepsi o portta ölçüldü; aynı kurallar her büyük port için geçerlidir.

Önce okuyun: [Native SDK rehberi](NATIVE_GUIDE.tr.md), [kit başvurusu](NATIVE_KIT.tr.md), [uyumluluk katmanı](NATIVE_COMPAT.tr.md).

## 1. Portun yapısı

```
özgün oyun kodu (yeniden derlenmiş C)  ->  host katmanı (Win32 / DirectDraw shim'leri)  ->  nxn_* API  ->  Nexvyn OS penceresi
```

- Oyun koduna elle dokunulmaz. Düzeltmeler host katmanına gider; böylece derleyicinin yeni çıktısı olduğu gibi girer.
- Host katmanı yalnızca oyunun gerçekten kullandığı import'ları yazar. Önce listesini çıkarın; sıcak olanları düzgün
  yazın, kalanları log satırı basan boş shim yapın, hangisinin çağrıldığını görürsünüz.
- Tek pencere, tek process: `fork` ve alt process yok. Yardımcı programları fonksiyona ya da thread'e çevirin.

## 2. Yüklerken canlı kalın

Büyük bir oyun ana thread'de 20 sn ya da daha uzun yüklenir ve olay döngüsü yoktur. Nexvyn OS pencerenin donduğunu
sanar ve 5 sn sonra "yanıt vermiyor" der. İki yoldan çözün:

- **Olayları okuyun.** Yüklerken en fazla 250 ms'de bir `nxn_should_quit()` çağırın (olayları işler ve "canlı" sayılır).
  Çağrıyı oyunun zaten beklediği yerlere koyun: `Sleep` shim'i, olay bekleme döngüsü, derleyicinin verdiği yield
  kancası. Her kilit işleminde çağırmayın: sıcak yol boşuna yavaşlar.
- **Bildirin.** SDK 1.13'ten (Nexvyn OS 1.2.4) itibaren `app.json`'a `"loadingHint": true` ekleyin. Yanıt vermiyor
  penceresi 5 sn yerine 120 sn bekler. Eski sistemler alanı yok sayar, olay okumayı yine de bırakmayın. Kullanıcı
  pencerede *Bekle* derse pencere 60 sn ve app bir kez yanıt verene kadar susar.

Yükleme sırasında pencereyi kapatan kullanıcı çıkabilmeli: `nxn_should_quit()` true olur ve girişiniz 5 sn içinde
dönmelidir. Bayrağı yükleme adımları arasında kontrol edin ve erken çıkın.

## 3. Bellek

- `malloc`, `free`, `realloc`, `memalign` app'in kendi heap'inden gelir (`"minNative": "1.1"` ve üstü). Sistemde boş
  bellek olduğu sürece heap büyür; yalnızca OS yedeği kalınca `malloc` `NULL` döner (varsayılan 64 MB,
  `native.memoryReserveMB` ayarı). App başına sabit sınır yoktur.
- Büyük oyunlar kendi C runtime heap'ini getirir (yeniden derlenmiş kodun içinde `malloc` / `free`). Bu fonksiyonları
  bir shim ile host'un `malloc` / `free`'sine yönlendirin. Oyunun heap'i app heap'inde yaşar, çıkışta tek adımda
  geri verilir ve kilit ile son-hata çağrıları sıcak yoldan çıkar.
- Gerçek ihtiyacı `app.json`'a `"memory"` (MB) olarak yazın. Başlangıçta o kadar boş değilse kullanıcı sonradan
  çökme yerine "X MB gerekli, Y MB boş; açık app'leri kapatın" mesajını görür.
- Her ayırma sonucunu kontrol edin. Başarısız ayırma null yazımı değil, net bir mesajla bitmeli.
- C kütüphanesinin kendi ayırdığı bellek (`fopen`, `asprintf`) app heap'inin dışındadır, sayılmaz.

## 4. Kare sunmak

Oyun bir yazılım yüzeyine (8 bit palet ya da 16 bit tampon) çizer ve shim'in "flip"ini çağırır. Frame hızını flip'in
maliyeti belirler:

- **Kaçınılabilir tam kare kopyası yok.** Host'un yükleyeceği tampona doğrudan çizin; yeniden çevirip kopyalamayın.
- **Bir kez çevirin, yavaş döngüde piksel piksel değil.** Palet -> RGB565 ya da RGBA için 256 girişli tablo, yalnızca
  palet değişince. 32 bitlik kelimelerle çalışın, döngü kolay vektörleşsin.
- **Kirli dikdörtgenler.** Shim oyunun hangi bölgelere dokunduğunu bilir (blit, fill, lock / unlock). Yalnızca onları
  çevirip yükleyin; strateji oyununda yan panel ve harita küçük parçalar halinde değişir.
- **Portta vsync kapalı.** Oyun thread'inde vsync beklemeyin (`SDL_RENDERER_PRESENTVSYNC` oyun mantığını her sunumda
  bekletir). Nexvyn OS pencerenin karelerini zaten düzenler. `SDL_GL_SetSwapInterval(0)` ve `SDL_RenderSetVSync(r, 0)`
  başarılı olur.
- **Fazladan geçiş yok.** Tam ekranda kenar bandını atlayın; 1x ölçekte ara hedef yerine kareden doğrudan pencereye
  lineer filtreyle ölçekleyin.
- Ses: oyun thread'inden kuyruğa atın; çağrılar OS ana thread'inde asla beklemez.

## 5. Thread'ler ve öncelikler

- OS kendine bir çekirdek boş bırakır. App'in aldığı çekirdeklere göre planlayın. Yeniden derlenmiş oyun mantığını
  genellikle tek thread'de çalıştırır: ses karıştırma, dosya akışı ve çözmeye ayrı thread verin, oyun mantığı tek kalsın.
- Thread önceliği sınırlıdır ve `SDL_SetThreadPriority` bir şey yapmaz. Doğruluğu önceliğe bağlamayın.
- **OS ana thread'inin de aldığı kilidi (SDL, GL, bellek, log) tutarken asla bloke olmayın.** Ortak kilidi tutup I/O
  bekleyen bir işçi masaüstünü dondurur. Kilidi birkaç komut tutun, dosya ya da ağ I/O'su boyunca asla.
- OS ana thread'i gerektiren çağrılar (seçici, izin isteği, kaydetme) thread'inizi bekletir ama app yine "canlı"
  sayılır. Oyun çizmeye devam etsin diye bunları işçi thread'e koyun.
- Thread ekledikten sonra aç-kapa testini çalıştırın ([Test akışı](TEST_WORKFLOW.tr.md)): art arda on aç-kapa, donma yok,
  bellek büyümüyor.

## 6. Dosya erişimi

- SD kart PC diskine göre yavaştır ve OS ile paylaşılır. Kare başına dosya okumayın. Varlıkları seviye ya da menü
  sınırında, olay okumaya devam eden bir ilerleme ekranının arkasında yükleyin.
- Büyük arşivleri büyük ardışık parçalarla okuyun (256 KB - 1 MB), 4 KB'lık değil. Yeniden derlenmiş oyunların çoğu
  küçük `fread` çağrıları yapar: shim'e tamponlu okuyucu koyun (`setvbuf` ile büyük tampon ya da ileri okuma önbelleği).
- Klasör listesini bir kez önbelleğe alın; kare döngüsünde klasör taramayın.
- Kayıt dosyaları küçük kalsın, işçi thread'de geçici dosya + yeniden adlandırma ile yazın.
- Log modül yüklemede okuma hızını gösterir (`module load ... MB/s`); kendi okuma döngünüzle karşılaştırın.

## 7. Giriş

Kullanıcının elindekine eşleyin: Joy-Con çifti, tek Joy-Con, kol ve dokunmatik ekran. Oyun fare ve klavye bekler;
host katmanı bunları sağlamalıdır:

- **Dokunma:** dokunuş sol tık, uzun basış sağ tık, iki parmakla sürükleme haritayı kaydırır. Önce imleci dokunma
  noktasına taşıyın, sonra basın; yoksa oyun yanlış yerde tık görür.
- **Çubuk:** yazılım imlecini ivmeyle oynatır; bir düğme sol, bir düğme sağ tık. Oyun sistem imlecini gizliyorsa
  imleci kendiniz çizin.
- **Yön tuşları ve omuz düğmeleri:** oyunun klavye kısayollarına (kamera grupları, kısayollar) eşlenir; eşlemeyi
  app'in menüsünde gösterin.
- Girişi kare başına bir kez `nxn_input_state` anlık görüntüsünden ya da olay kuyruğundan okuyun; aygıtları ikinci
  thread'de yoklamayın.

## 8. Doğru ölçün

- PC emülatöründe **konsol profili** ile test edin: dört çekirdeğe, CPU tavanına ve düşük önceliğe sınırlayın, GPU
  yükünü konsol seviyesinde tutun (1x çözünürlük), el ve dock modunu ayrı ölçün. Bkz. [Test akışı](TEST_WORKFLOW.tr.md).
  Emülatör sayıları aynı profille önce / sonra karşılaştırma içindir. Asla konsol sayısı değildir.
- `System/Logs/system.log` dosyasını okuyun:
  - `nxwin: <id>: <n> fps, ...` birkaç saniyelik pencerede kare hızıdır; yüklerken 0 app'in hiç çizmediği demektir.
  - `nxwin: <id> is not responding (x s silent)` o kadar süre olay okuma ya da kare olmadığı demektir:
    `nxn_should_quit()` olmayan döngüyü bulun.
  - `stall` satırları yavaş karenin en uzun parçalarını listeler (eşik 150 ms, `perf.stallMs` ayarı).
  - `nxwin: <id>: module load ...` modülün okuma hızını ve link süresini verir.
  - `stats` satırları (autorun `stats` komutu) bellek, pencere ve kaynakları verir; sızıntı kontrolü içindir.
- Sıcak fonksiyonu örnekleyerek bulun: host'ta ucuz bir heartbeat (her 2^19 ya da 2^20 döngüde mevcut fonksiyon
  adresini yaz) histogram verir. Örnek portta 90 örnek yükün çoğunu oyunun kendi heap ve kilit fonksiyonlarına
  koydu: yüklemenin gerçek maliyeti disk değil heap'ti. Heartbeat'i yayın build'inde kapatın.
- Her ölçümü yazın: profil, çekirdek sayısı, çözünürlük, el ya da dock, sürüm.

## 9. Paketleme

- `app.json`: `"main": "<ad>.nxvmod"`, `"minNative": "1.1"`, `"minSdk": "1.10"` (`loadingHint` kullanıyorsanız
  `"1.13"`), `"targetSdk"`, `"memory"`, portun gerçekten istediği izinler ve uzun yüklemeler için
  `"loadingHint": true`. Tam liste [Paket biçimi](NXVAPP_FORMAT.tr.md) içinde.
- Modül, derlendiği **ABI nesli**ni taşır. Nesil yalnızca modül arayüzü gerçekten bozulunca elle yükseltilir; N nesli
  için derlenmiş modül N nesli olan her sistemde yüklenir. Hedeflediğiniz sisteme uyan kit ile yeniden derleyin ve önceki
  kit ile derlenmiş bir modülün hâlâ açıldığını denetleyin.
- Paket modülü, ikonu, `lang/*.json` dosyalarını, lisans dosyalarını ve kaynak bağlantısını taşır. Oyunun verisini
  asla taşımaz. Büyük paketler yavaş kurulur (55 MB'lık paketin açılması yaklaşık 3,5 sn sürdü): ilk açılış kurulumun
  bitmesini beklesin.
- Paketi küçük tutun: sıkışanı sıkıştırın, debug bilgisini atın, kullanılmayan araç koymayın.
- Pull request'ten önce modülde `nxv-native check`, bundle'da `python SDK/Tools/nxv/nxv.py check <klasör>` çalıştırın.

## 10. Lisans ve oyun verisi

- Oyun verisini kullanıcı getirir. Port paketi oyunun dosyalarını, BIOS, firmware ya da sistem dosyalarını asla
  içermez. App ilk açılışta oyun klasörünü sorar (seçici), hatırlar ve dosyalar eksikse net mesaj gösterir.
- Lisansı dağıtıma izin veriyorsa serbest lisanslı bir yedek veri seti, lisansıyla birlikte pakete girebilir.
- Her port kendi lisans dosyasını ve kaynağına (varsa özgün projeye) bağlantıyı pakette ve Store metninde taşır.
  Bağladığınız her kütüphanenin lisansını `licenses/` içine koyun.
- Host katmanınız ayrı bir iştir: kaynağını uyumlu bir lisansla portla birlikte yayınlayın.
- Hakkınız yoksa özgün oyunun adını, görselini ya da sesini ikonda ve ekran görüntülerinde kullanmayın. "Yeniden
  derlenmiş bir strateji oyunu" gibi tarafsız bir tanım ve kendi anahtar sanatınızı kullanın.

## Kontrol listesi

- [ ] Her uzun döngüde en fazla 250 ms'de bir `nxn_should_quit()`; `loadingHint` ayarlı
- [ ] oyun heap'i host `malloc` / `free`'ye yönlendirildi; `memory` alanı ayarlı
- [ ] portta vsync kapalı; kirli dikdörtgenler; fazladan geçiş yok
- [ ] I/O boyunca tutulan kilit yok; aç-kapa testi on kez
- [ ] büyük parçalarla okuma, kare başına hiçbir şey
- [ ] dokunma, kol ve Joy-Con eşlendi; eşleme menüde gösteriliyor
- [ ] konsol profiliyle ölçüldü; sayılar profille birlikte yazıldı
- [ ] lisans dosyaları, kaynak bağlantısı, pakette oyun verisi yok
