<p align="center"><img src=".github/assets/desktop-dock.webp" width="100%" alt="Nexvyn OS masaüstü, Dock düzeni; saat, takvim ve dünya saati araçlarıyla"></p>

<h1 align="center">Nexvyn OS</h1>

<p align="center"><b>Switch'te tam masaüstü, native 3B ve gerçek bir App Market.</b><br>
<i>Native 3B 10'dan 60 fps'e. Bir GBA oyunu tam hızda. Tarayıcıda WebGL. Konsolda ölçüldü.</i></p>

- Tek `.nro`, Homebrew Menüsü'nden açılır. Yeniden başlatma yok, bölümleme yok.
- Pencereli masaüstü (Dock ya da görev çubuğu düzeni), 70'ten fazla yerleşik app ve her öğesi incelenen bir App Market.
- Donmuş ABI v1'li native C/C++ SDK, ayrıca Lua, JavaScript ve Python: konsolda ya da PC'de app ve oyun yap.

### Onu farklı kılan 10 şey

1. **Tam hızda native app'ler.** C ve C++ app'leri masaüstünde kendi pencerelerinde çalışır. Konsolda ölçülen: 3D sahneler 10'dan 59 fps'e, OpenGL vitrini 10-16'dan 60 fps'e çıktı; kare aktarımı 15-24 ms'den 0.1 ms'ye, sahne yükleme ~30 sn'den 0.6 sn'ye indi. Klasik oyun portları (bir Doom motoru, bir Quake motoru, bir GBA emülatörü) pencerede ya da tam ekranda çalışır.

   <img src=".github/assets/hero-doom.webp" width="31%" alt="Freedoom'lu Doom motoru"> <img src=".github/assets/hero-showcase.webp" width="31%" alt="Native SDK Showcase">

2. **Tarayıcıda WebGL.** Yerleşik tarayıcı WebGL 1 çalıştırır, popüler açık kaynak 3D web kütüphaneleri çalışır: dönen bir 3D sahne konsolda ~48 fps. Varsayılan olarak açık.

   <img src=".github/assets/hero-webgl.webp" width="31%" alt="Tarayıcıda WebGL küpü">

3. **Tek SDK, dört dil.** Lua, JavaScript, Python ve C aynı API'yi aynı adlarla kullanır: pencere, arayüz, dosya, ağ, ses, girdi, 2D ve 3D. Her yeni özellik dördüne de gelir. Kitte rehberler, örnekler, denetleyiciler ve yapımcılar için AI prompt'ları var.
4. **Modern 3D renderer.** NexGFX'in fiziksel tabanlı renderer'ı: metal ve pürüzlülük malzemeleri, normal ve ışıyan haritalar, gerçek zamanlı ışıklar, güneş ve spot gölgeleri, HDR, ton eşleme, bloom, MSAA ve instancing. App'ler isteyerek açar, eski app'ler aynı görünür.

   <img src=".github/assets/nexgfx-materials.webp" width="31%" alt="PBR malzemeler">

5. **Gerçek 3D modeller.** `.glb`, `.gltf`, `.fbx`, `.obj` ve `.stl` dosyaları düğüm ağacı, malzeme, doku ve geçişli iskelet animasyonuyla yüklenir, GPU'da skinning yapılır.
6. **Voxel motoru.** Sonsuz blok dünyaları oyuncunun çevresinde arka plan thread'lerinde akar: güneş ve meşale ışığı, yumuşak aydınlatma, ambient occlusion, su, kayıt, ışınla seçme ve fizik. Bir blok inşa oyunu birkaç yüz satır.
7. **Tam tema paketleri.** Tema her şeyi değiştirir: renkler, pencere çerçeveleri, dock ya da görev çubuğu, tüm ikonlar (app, klasör, dosya türü, disk), sesler ve duvar kâğıtları. İlk açılışta seçilir: Glass, Classic, Terminal ve dahası, daha fazlası App Market'te. Temada olmayan ikon varsayılan paketten gelir; tema kitiyle herkes kendi temasını yapar.

   <img src=".github/assets/hero-theme-glass.webp" width="31%" alt="Glass stili"> <img src=".github/assets/anim-theme-switch.gif" width="31%" alt="Stil geçişi">

8. **Performans modu.** Resmi en yüksek saat hızları varsayılan olarak açık, daha hızlı yükleme ve önce uyaran isteğe bağlı overclock var. Kurulumlar arka planda yapılır; takılan bir app masaüstünü dondurmaz: çıkış bekçisi var, sistem bir şeyi kapatmadan önce sorar.

   <img src=".github/assets/settings-performance.webp" width="31%" alt="Performans ayarları">

9. **App Market.** ~170 app, oyun, tema ve font: sekmeler, kategoriler, tech demo Vitrini, ekran görüntülü tam sayfa detay, canlı kurulum ilerlemesi (MB, hız, kalan süre) ve tek dokunuşla güncelleme. Bazı yerleşik app'ler de buradan güncellenir.

   <img src=".github/assets/hero-market-discover.webp" width="31%" alt="App Market"> <img src=".github/assets/anim-market-browse.gif" width="31%" alt="App Market">

10. **Switch için gerçek bir masaüstü.** Taşınabilir pencereler, çok parmak hareketleri, Joy-Con, dokunmatik, el ve dock modu, 8 dil, ağsız da çalışan ilk açılış sihirbazı, güvenli mod, köklü sıfırlama ve birden çok sağlayıcıyla çalışan AI Sohbet app'i.

   <img src=".github/assets/anim-window-snap.gif" width="31%" alt="Pencere yerleştirme">



<p align="center"><img src=".github/assets/anim-window-snap.gif" width="80%" alt="Bir pencereyi ekran kenarına sürükleyince ekranın yarısına oturur"></p>

### İki masaüstü, seçim senin

İlk kurulumda Dock ya da görev çubuğu düzenini seç, istediğin zaman değiştir. Pencereler, yerleştirme, sanal masaüstleri, Hızlı Arama, Denetim Merkezi ve araçlar ikisinde de aynı çalışır.

| Dock | Görev çubuğu |
|---|---|
| <img src=".github/assets/desktop-dock.webp" alt="Araçlı Dock düzeni"> | <img src=".github/assets/desktop-taskbar.webp" alt="Aurora duvar kağıdı ve araçlarla görev çubuğu düzeni"> |

### Stilini seç

İlk kurulum bir görünüm sorar. Renkler, çubuklar, ikonlar ve sesler birlikte değişir; daha fazla stil App Market'te Temalar bölümünde.

<p align="center"><img src=".github/assets/hero-pick-your-style.webp" width="80%" alt="İlk kurulumun Stilini seç adımı, dört stil kartıyla"></p>

| Classic 95 | Glass | Terminal Blue |
|---|---|---|
| <img src=".github/assets/hero-theme-classic95.webp" alt="Classic 95 stili: eğik kenarlı düğmelerle bej masaüstü"> | <img src=".github/assets/hero-theme-glass.webp" alt="Glass stili: yarı saydam pencerelerle koyu masaüstü"> | <img src=".github/assets/hero-theme-terminalblue.webp" alt="Terminal Blue stili: görev çubuklu koyu mavi masaüstü"> |

<p align="center"><img src=".github/assets/anim-theme-switch.gif" width="80%" alt="Stiller arasında geçiş: renkler, pencere çerçeveleri ve duvar kağıdı birlikte değişir"></p>

### Yeniden tasarlanan App Market

Keşfet, App'ler, Oyunlar, Vitrin, Temalar ve Güncellemeler. Ekran görüntüsü galerili tam sayfa app ayrıntıları ve kurulum sırasında canlı indirme hızı ve MB. Kurulumlar arka planda çalışır; yavaş SD kart artık masaüstünü dondurmaz.

| Keşfet | App ayrıntıları | Temalar |
|---|---|---|
| <img src=".github/assets/hero-market-discover.webp" alt="App Market, öne çıkan oyunlu Keşfet sekmesi"> | <img src=".github/assets/hero-market-detail.webp" alt="App Market, Native SDK Showcase ayrıntı sayfası"> | <img src=".github/assets/hero-market-themes.webp" alt="App Market, büyük önizleme kartlı Temalar bölümü"> |

<p align="center"><img src=".github/assets/anim-market-browse.gif" width="80%" alt="App Market'te gezinme: Keşfet, sonra Temalar bölümü"></p>

### Vay be

| | |
|---|---|
| **Native SDK Showcase**<br>Pencerede çalışan, kendi 3B görünümü, testleri ve canlı durumu olan bir C++ app. <img src=".github/assets/hero-showcase.webp" alt="Pencerede Native SDK Showcase app'i"> | **Freedoom'lu Doom motoru**<br>Ücretsiz oyun verisi, temiz ses, dokunma ve Joy-Con. <img src=".github/assets/hero-doom.webp" alt="Ücretsiz Freedoom verisiyle çalışan Doom motoru"> |
| **GBA tam hızda**<br>Ücretsiz bir homebrew GBA oyunu (MIT lisanslı); ilk konsol testinde 59.2 fps, ilk sürümde 4-5. <img src=".github/assets/hero-gba.webp" alt="Pencerede çalışan ücretsiz homebrew GBA oyunu"> | **Tarayıcıda WebGL**<br>Testte three.js küpü yaklaşık 57-58 fps (deneysel, varsayılan kapalı). <img src=".github/assets/hero-webgl.webp" alt="Tarayıcıda dönen WebGL küpü"> |
| **1.2.2'de yenilikler**<br>Sürümün kısa turu; ilk açılışta ve istediğin zaman Ayarlar'dan. <img src=".github/assets/hero-whatsnew.webp" alt="Yenilikler ekranı: Yepyeni bir App Market"> | **Resmi en yüksek saatler**<br>Varsayılan açık; ayrıca uyarı arkasında isteğe bağlı hız aşırtma. <img src=".github/assets/settings-performance.webp" alt="Ayarlar, Performans bölmesi, resmi en yüksek saatlerle"> |

<p align="center"><img src=".github/assets/anim-doom-play.gif" width="80%" alt="Ücretsiz Freedoom verisiyle Doom motoru oynanışı"></p>

### Sayılar

Switch OLED üzerinde ölçüldü; ilk test ile son tur (varsayılan ayarlar) karşılaştırması.

| Test | Önce | Şimdi |
|---|---|---|
| Native 3B sahne | 10 / 15 fps | 59.5 / 59.6 fps |
| OpenGL vitrini | 10-16 fps | varsayılanda 51.4 fps, ayarlı 59.9 fps |
| GBA emülasyonu (gerçek bir oyun) | 4-5 fps | 59.2 fps, tam hız |
| App karesi ekrana | 15-24 ms | 0.10-0.22 ms |
| Sahne yükleme | ~30 s | 0.58 s |
| El konsolu GPU saati, resmi en yüksek | 307 MHz | 460 MHz (kıyaslama 69.0'dan 84.5 fps'e) |

60 fps ekranın sınırıdır; bu yüzden bazı testler "60'ta kilitli".

### Geliştiriciler için

Donmuş ABI v1'li native C ve C++ (bundan sonra yalnızca ekleme): 1.0 kitiyle derlenmiş bir modül güncel sistemde hâlâ yüklenir. Her yeni API Lua, JavaScript, Python ve C'ye aynı adlarla gelir. Port kiti portları ayrı app olarak paketler. Bkz. [SDK](SDK/README.md).
