# Nexvyn OS Tarayıcı: "Chrome gibi tam HTML/JS" hedefi

**Türkçe** · [English](BROWSER.en.md)

Bu belge, Switch üzerinde Chrome düzeyinde bir tarayıcının ne kadar mümkün olduğunu, araştırılan motorları
(kaynaklarıyla), Nexvyn OS'ta seçilen yolu ve `tests/web/` test sayfalarının sonuçlarını anlatır.

## 1. Kısa cevap

Konsolda, tek bir `NexvynOS.nro` içinde ve GPL-3.0-or-later lisansıyla **güncel Chrome'un tamamını** (Blink + V8 JIT
+ GPU hızlandırmalı çizim + medya yığını) çalıştırmak bu donanım ve lisans koşullarında gerçekçi değil:

- Blink/Chromium onlarca milyon satırdır, POSIX/GL/ses/ağ katmanlarına derin bağlıdır; devkitA64 + newlib + libnx
  üzerine taşınmış bir sürümü yoktur.
- Homebrew uygulamalarında belleğin büyük kısmı başlık (title) modunda kullanılabilir; applet modunda çok daha azdır.
  Modern bir site sekmesi tek başına yüzlerce MB isteyebilir.
- JIT'li bir JS motoru (V8) çalıştırılabilir bellek ister; bu ancak özel çalışma ortamlarında mümkün (bkz. Brewser).

1.2.4'ten beri Nexvyn OS'un tek bir tarayıcısı var: kendi motoru (konsolun sistem web applet'i artık kullanılmıyor).

- **Kendi motor**: QuickJS üzerinde HTML/CSS/JS motoru (`source/web/`). Bu çalışmada CSS değişkenleri, gerçek flexbox,
  CSS grid, SVG, `<canvas>` 2D, gizli sekmeler ve oyun kolu ile bağlantı gezintisi eklendi.
- Uygulamaların giriş sayfaları (`net.oauth`) bu tarayıcının bir sekmesinde açılır; sayfa uygulamanın yönlendirme
  adresine ulaşınca sekme kapanır.

## 2. Araştırma

### 2.1 Switch'in yerleşik web applet'i (geçmiş)

1.2.3'e kadar Nexvyn OS bir sayfayı konsolun web applet'ine (WebKit tabanlı NetFront NX) verebiliyordu. 1.2.4'te
kaldırıldı: kullanıcı tek tarayıcı istiyor; applet başlık modu gerektiriyordu, test edilmemiş sistem sürümlerinde
konsolu durduruyordu ve çerezleri OS ile paylaşmıyordu. Araştırma notları burada tutulmuyor.

### 2.2 Homebrew motorlar ve kütüphaneler

| Proje | Ne | Lisans | Nexvyn OS için durum |
|---|---|---|---|
| **NetSurf for NX** (etonedemid, 0.2.0) | NetSurf'ün Switch portu; QuickJS ile JS, flexbox, grid, `calc()`, CSS değişkenleri; sticky ve WebGL yok | NetSurf: **GPL-2.0**; kütüphaneleri (LibCSS, Hubbub, libdom) **MIT** | Ayrı .nro olarak kullanılabilir. NetSurf çekirdeği GPLv2 olduğundan GPL-3.0-or-later koda gömmek için "or later" ibaresi gerekir; doğrulanmadan gömülmedi. MIT lisanslı LibCSS/libdom/Hubbub ise lisans açısından uyumlu. |
| **Brewser** (natureglass) | V8 + JIT, Skia, Mesa üzerinden WebGL1/2; Web MIDI/USB/Serial; geliştiricisine göre web özelliklerinin ~%70-75'i | **MPL-2.0** | Atmosphère gerektiren ayrı bir çalışma ortamı. V8+Skia+Mesa tek NRO'ya gömülemeyecek kadar büyük; MPL-2.0 GPLv3 ile uyumlu olsa da entegrasyon bu projenin kapsamı dışında. |
| **nx.js** (TooTallNate) | QuickJS + cairo ile Switch için JS çalışma ortamı; Canvas 2D, fetch, URL, crypto | **MIT** | Bir tarayıcı değil, uygulama çalışma ortamı. Canvas/fetch fikirleri örnek alındı; kod kopyalanmadı. |
| **litehtml** | HTML/CSS yerleşim motoru; çizimi uygulamaya bırakır; kendi README'sine göre tam bir tarayıcı motoru olarak önerilmez | **BSD-3-Clause**, HTML ayrıştırıcısı gumbo **Apache-2.0** | Lisans uyumlu. Ama JS/DOM yok; mevcut QuickJS DOM bağlantılarımız kendi `Node` yapımıza bağlı. Değiştirmek büyük bir yeniden yazım, kazanç sınırlı. |
| **lexbor** | C ile HTML5 ayrıştırıcı, CSS ayrıştırıcı/seçici motoru, bağımlılık yok | **Apache-2.0** | Lisans uyumlu (Apache-2.0 GPLv3 ile uyumlu). Ayrıştırıcımız zaten hoşgörülü çalışıyor ve SVG ham metnini koruyor; ileride CSS ayrıştırıcısını değiştirmek için en iyi aday. |

Kaynaklar: [GameBrew: NetSurf for NX](https://www.gamebrew.org/wiki/NetSurf_for_NX_Switch),
[netsurf-switch](https://github.com/etonedemid/netsurf-switch),
[NetSurf lisans sayfası (ayna)](https://plan9.io/sources/contrib/yk/9front/sys/lib/netsurf/licence.html),
[Debian netsurf copyright](https://sources.debian.org/src/netsurf/3.11-3/debian/copyright),
[GameBrew: Brewser](https://www.gamebrew.org/wiki/Brewser_Switch),
[GBAtemp: Brewser duyurusu](https://gbatemp.net/posts/10903033/),
[nx.js](https://github.com/TooTallNate/nx.js), [GameBrew: nx.js](https://www.gamebrew.org/wiki/Nx.js_Switch),
[litehtml](https://github.com/litehtml/litehtml), [lexbor](https://github.com/lexbor/lexbor),
[FSF lisans uyumluluk listesi](https://www.gnu.org/licenses/license-list.html).

### 2.3 Değerlendirme

- **Uyumluluk tavanı**: Modern sitelerin (Gmail, YouTube, X, Discord, React/Next uygulamaları) gerçekten çalışması
  için tam bir motor şart. Nexvyn OS bu motoru adım adım kendisi kuruyor.
- **Kendi motor**: Haber siteleri, Wikipedia, belgeler, forumlar, basit uygulamalar ve yerel HTML için hızlı,
  Nexvyn OS ile bütünleşik (şifre kasası, okuma modu, indirmeler, sekmeler). En çok fayda sağlayan eksikler
  kapatıldı: CSS değişkenleri (modern sitelerin neredeyse tamamı renkleri bunlarla verir), gerçek flexbox ve grid
  (menüler, kart ızgaraları), satır içi SVG (ikonlar), canvas 2D (grafikler, basit oyunlar).
- **Ayrıştırıcı/yerleşimi lexbor veya litehtml ile değiştirmek**: Lisans olarak mümkün; ancak DOM/JS bağlantıları,
  iş parçacığı anlık görüntüleri (snapshot) ve yazı tipi ölçüm önbelleği kendi veri yapılarımıza bağlı. Bu
  çalışmada değiştirmek, aynı sürede eklenen özelliklerden daha az kazanç ve daha çok risk getirirdi.

## 3. Yapılanlar

### 3.1 Uyumluluk ipuçları

- **Uyumluluk dedektörü** (`Page::compatibility()`): sayfada neredeyse hiç metin yokken çok sayıda betik (yalnızca
  JS ile kurulan uygulama), `<video>/<audio>`, WebGL/WebGPU, `<canvas>`, "JavaScript'i etkinleştirin" uyarıları,
  React/Next/Angular/Nuxt/Gatsby/Svelte işaretleri, tekrarlayan betik hataları ve sitede JS'nin kapalı olması
  puanlanır. Puan tanılama için tutulur.
- Birkaç ağır site için üstteki çubuk sitenin hafif sürümünü (`Hafif Sürüm`) ya da YouTube videoları için Tube'u önerir.
- Yer imleri çubuğu: yeni kurulumda kapalı; tarayıcıyı zaten kullananlarda açık kalır (Tarayıcı > Görünüm).

### 3.2 Motor (source/web)

- **CSS değişkenleri**: `--ad: değer` tanımları elemana göre katmanlanır (değişmeyen elemanlar ebeveynin katmanını
  paylaşır, Tailwind'in evrensel sıfırlamaları ucuz kalır); `var()` kullanan bildirimler kaskadda, değişkenler
  bilindikten sonra yeniden ayrıştırılır. İç içe `var()`, geri dönüş değerleri, döngü koruması var.
- **prefers-color-scheme**: "Sitelerden koyu tema iste" ayarına bağlı (CSS ve `matchMedia`).
- **Flexbox (satır)**: `flex-grow/shrink/basis`, `flex` kısaltması, `flex-wrap`, `row-reverse`, `gap`,
  `justify-content` (start/end/center/space-between/around/evenly), `margin: auto`, `align-items` ve `align-self`
  (stretch/start/end/center), sabit yükseklikli kapsayıcıda dikey ortalama, metin düğümleri anonim öğe olarak.
  Sütun flexbox: `gap` ve `align-items: center/end`.
- **CSS grid**: `grid-template-columns` (px/%/em, `fr`, `auto`, `minmax()`, `repeat(n, …)`,
  `repeat(auto-fill|auto-fit, …)`), `gap`, `grid-column` (`span n`, `a / b`, `1 / -1`), satır satır otomatik yerleşim.
- **SVG**: `<img src=*.svg>` ve `data:image/svg+xml` SDL_image'in nanosvg'si ile CSS boyutunun 4 katına kadar
  keskin çizilir; satır içi `<svg>` artık gizlenmiyor, resim olarak çizilir (`currentColor`, varsayılan dolgu = metin
  rengi, `<use href="#id">` ikon sprite'ları diğer satır içi SVG'lerden de çözülür).
- **WebP**: SDL_image 2.0.4 libwebp ile derlendiği için durağan WebP zaten çözülüyor (animasyonlu WebP yok).
- **Canvas 2D**: yollar, eğriler, yaylar, `ellipse`, `roundRect` (yarıçap dizileri ve noktalar), `Path2D`, dönüşümler,
  `save/restore`, nonzero/evenodd dolgu, gerçek çizgi (`lineJoin` miter / round / bevel, `miterLimit`, `lineCap`,
  `lineDashOffset` ile `setLineDash`), `fillRect/strokeRect/clearRect`, `globalAlpha`, `getImageData` / `putImageData`
  (dirty rect) / `ImageData`, `isPointInPath` (iki dolgu kuralı) ve `isPointInStroke`. Doğrusal, dairesel ve conic gradyanlar,
  desenler (canvas veya `<img>`), `save/restore` yığınlı `clip()`, 26 composite işleminin hepsi (Porter-Duff ve blend modları),
  gerçek `shadowBlur` (gaussian yaklaşımı, sınırlı maliyet), `filter` özelliği (`blur`, `brightness`, `contrast`, `grayscale`,
  `sepia`, `saturate`, `invert`, `opacity`, `hue-rotate`, `drop-shadow`), `imageSmoothingEnabled` / `imageSmoothingQuality`.
  Metin (`fillText`, `strokeText` kontur, `textAlign`, `textBaseline`, `direction`, `maxWidth`, gerçek mürekkep kutulu
  `measureText`) sistem yazı tipiyle bitmap'in içine çizilir; `getImageData`, `drawImage` ve `toDataURL` metni görür.
  `drawImage` / `createPattern` / `createImageBitmap` `<img>` (`onload` ile `new Image()`, data, http ve blob URL'leri),
  canvas, `ImageBitmap` ve `Blob` kabul eder; başka kaynaklı resimler kirlenmez, uygulamalar çalışmaya devam eder.
  `toDataURL` / `toBlob` / `OffscreenCanvas.convertToBlob` PNG veya JPEG (kalite parametresi) yazar; başka türler PNG verir.
  `getContext('2d', {alpha:false})` opak bitmap yapar. `width` / `height` atamak (aynı değer de olsa) canvas'ı siler ve bağlamı
  sıfırlar. Rasterleştirici, çizgi üretici, bulanıklık, filtreler ve PNG / JPEG kodlayıcıları C++'ta (`web_canvas.cpp`),
  host birim testleriyle.
  Sınırlar: video kareleri çizilemez, metin sans yazı tiplerini kullanır (kalın veya normal), canvas bir kenarda en çok
  4096 px ve 16 MB'tır (OS belleği azsa daha küçük), `isPointInStroke` eklem ve uçları yuvarlak sayar.
- **ES modülleri** (1.3.0): `<script type="module">` (ertelenir, belge sırasıyla), statik `import` / `export`, dinamik
  `import()` (klasik betiklerden de), `import.meta.url`, üst düzey `await`, `nomodule`, `<script type="importmap">`
  (`imports`, `scopes`) ve JSON modülleri. QuickJS import'ları eşzamanlı çözdüğü için modülün tüm grafiği önce indirilip
  önbelleğe alınır (göreli, mutlak ve `data:` adresleri; en çok 48 MB / 2000 modül); eksik modül ya da eşlenmemiş çıplak ad
  promise'i reddeder, sayfa çalışmaya devam eder.
- **Web Workers** (1.3.0): `new Worker(url, {type, name})`; `http(s):`, yerel, `blob:` ve `data:` betikleri ve modül
  worker'ları. Her worker ana thread'in altında bir thread'dir; kendi QuickJS çalışma zamanı ve kendi kilidi vardır:
  beklediği hiçbir şeyi ana thread tutmaz. `postMessage` yapılandırılmış klondur (nesneler, diziler, Map, Set, Date,
  RegExp, typed array'ler, BigInt, döngüler) ve aktarılabilir `ArrayBuffer`'ları taşır; `onmessage` / `onerror`,
  `terminate()`, `close()`, `importScripts`, `fetch` (sayfa yapar: çerezler, `blob:` ve `data:` çalışır), zamanlayıcılar,
  `performance.now`, `TextEncoder` / `TextDecoder`, `URL`, `crypto.getRandomValues`, `atob` / `btoa` içeride var.
  Sınırlar: aynı anda 4 worker (beşinci `new Worker` `QuotaExceededError` fırlatır), her biri 24 MB betik belleği, 4 sn
  süren bir çağrı worker'ı hata olayıyla sonlandırır (sayfa onu hiç beklemez), worker'lar sayfalarıyla biter. Yok:
  `SharedWorker`, `SharedArrayBuffer`, worker içinde `import()` ve IndexedDB, `Error` nesnesi ya da fonksiyon göndermek.
- **IndexedDB** (1.3.0): `indexedDB.open` / `deleteDatabase` / `databases` / `cmp`, `upgradeneeded` ile sürümler,
  nesne depoları (anahtar yolları, anahtar üreteçleri), indeksler (unique, `multiEntry`, bileşik anahtar yolları),
  işlemler (`readonly`, `readwrite`, abort geri alır), `get` / `getKey` / `getAll` / `getAllKeys` / `count` / `put` /
  `add` / `delete` / `clear`, dört yönde imleçler (`continue`, `advance`, `continuePrimaryKey`, `update`, `delete`),
  `IDBKeyRange`. Değerler yapılandırılmış klondur. Her kaynağın Browser'ın depolama klasöründe kendi dosyaları var
  (özel sekmelerde bellekte); açarken dosya arka plan thread'inde okunur, değişiklikler son commit'ten biraz sonra yine
  orada yazılır, ana thread'de asla. Veritabanı başına en çok 32 MB; "gezinti verilerini temizle" onları siler. Bir
  sayfanın işlemleri sırayla çalışır.
- **WebAudio** (`AudioContext`, `webkitAudioContext`, `OfflineAudioContext`): `GainNode`, `OscillatorNode` (sine, square,
  sawtooth, triangle), `AudioBufferSourceNode` (döngü, çalma hızı, başlangıç ofseti, `onended`), `AudioBuffer`,
  `decodeAudioData` (wav, ogg, mp3, flac; bir worker'da çözülür), `BiquadFilterNode` (lowpass, highpass, bandpass, shelf'ler,
  peaking, notch, allpass), `DelayNode`, `StereoPannerNode`, `AnalyserNode`, `DynamicsCompressorNode` ve `AudioParam`
  otomasyonu (`setValueAtTime`, doğrusal ve üstel rampalar, `setTargetAtTime`, `setValueCurveAtTime`, iptal). Graf her
  context için tek bir düşük öncelikli thread'de çizilir ve OS mixer'ının okuduğu ring buffer'a yazılır; sayfanın
  thread'i yalnızca komut gönderir (ortak kilit yok). Sınırlar: sayfa başına 4 context, 4096 node, 96 ses. Desteklenmeyen:
  uzamsal `PannerNode` (geçiren yedek), `ScriptProcessorNode`, `AudioWorklet`, `MediaStream` node'ları; `<audio>`
  öğeleri kendi çıkışında kalır (`createMediaElementSource` sessiz bir yedek döner). Otomatik oynatma kuralı etkisizdir:
  context çalışır başlar, `resume()` her zaman çalışır.
- **WebGL 2** (`getContext('webgl2')`, `WebGL2RenderingContext`): vertex array object'leri, instancing (`drawArraysInstanced`, `drawElementsInstanced`, `vertexAttribDivisor`, `drawRangeElements`), tamsayı attribute'lar, uniform buffer object'leri (`getUniformBlockIndex`, `uniformBlockBinding`, `bindBufferBase/Range`, blok sorguları), `copyBufferSubData` / `getBufferSubData`, 3B ve 2B-dizi dokular (`texImage3D`, `texStorage2D/3D`), sampler object'leri, çoklu render hedefi (`drawBuffers`, `framebufferTextureLayer`, `blitFramebuffer`, `readBuffer`, `invalidateFramebuffer`), float ve tamsayı renk biçimleri (`EXT_color_buffer_float`), occlusion query'ler, sync object'leri (taklit: `clientWaitSync` `glFinish` ile bekler) ve transform feedback. GLSL ES 3.00 ve 1.00 shader'ları OpenGL ES 3 sürücüsüne olduğu gibi gider (`web_glsl3.cpp` yalnızca masaüstü GL sunan bir ana makine için GLSL 430'a da çevirebilir); derleme hataları `getShaderInfoLog` ile döner. Eklentiler ana makinenin sunduğuna göre açılır (`EXT_color_buffer_float`, `OES_texture_float_linear`, `EXT_texture_filter_anisotropic`, `WEBGL_compressed_texture_s3tc`). Sınırlar: bir bağlam 256 MB buffer ve 3B / dizi doku tutabilir; query ya da transform feedback tek bir script görevi (kare callback'i) içinde başlayıp bitmeli; WebGL 1 bağlamları bunların hiçbirini görmez. Bilinen eksikler (emülatör test ortamında geçmiyor; bağlam asla çökmez, çağrılar yalnızca yanlış piksel döner): 2B-dizi dokunun tek katmanına çizim (`framebufferTextureLayer` + clear), 3B doku örnekleme (`sampler3D`) ve vertex array object ya da instance sayısı değişince `drawArraysInstanced`; `ANY_SAMPLES_PASSED_CONSERVATIVE` geçmemiş örnekleri de bildirebilir (spesifikasyon buna izin verir). `MAX_TEXTURE_MAX_ANISOTROPY_EXT` ana makinenin sınırını bildirir (en çok 16). Bu özellikler gerçek konsolda denenene kadar doğrulanmamış sayılır.
- **Gamepad API**: `navigator.getGamepads()`, `gamepadconnected`, standart eşleme (17 düğme, 4 eksen; standart yerleşim
  konuma göredir, yani Switch B düğmesi 0. düğmedir), 0.1 ölü bölge, `vibrationActuator.playEffect` (konsolun titreşimi,
  iki şiddetin büyüğü). Kumanda, diğer tarayıcılardaki gibi ilk girişten sonra görünür. Bir sayfa kumandayı okurken kumanda
  onundur (kumanda imleci oynatmaz); dokunma çalışır. Sayfa arka plan sekmesindeyken ya da pencere odakta değilken hiçbir
  şey bildirilmez.
- **Fullscreen API**: `element.requestFullscreen()`, `document.exitFullscreen()`, `fullscreenElement`,
  `fullscreenEnabled`, `fullscreenchange` (ve `webkit` adları). Pencere tam ekran olur, araç çubuğu ve sekmeler gizlenir,
  öğe sayfayı kaplar. Esc çıkarır; kumandayla sayfa kumandayı okurken B'ye bir an basılı tutulur.
- **Özel çerez kutusu ve depolama**: özel sekmeler için ayrı, diske yazılmayan çerezler ve Web Storage.
- `CSS.supports()` motorun gerçekten yerleştirdiği özellikleri bildirir.

### 3.3 Tarayıcı uygulaması

- **Özel sekme** (Ctrl+Shift+N, bağlantı menüsü): geçmiş, oturum ve kapatılan sekme kaydı tutulmaz; ayrı çerez ve
  depolama; son özel sekme kapanınca silinir. Sekme şeridinde ve adres çubuğunda mor işaret.
- **Gamepad ile bağlantı gezintisi**: D-pad yön tuşları en yakın bağlantıya odak halkası taşır, işaretçi bağlantının
  üstüne gelir (A ile açılır); yakında bağlantı yoksa sayfa kayar. Klavye okları eskisi gibi kaydırır.
- **Ctrl+W**: kabuk Ctrl+W'yi pencere kapatma isteğine çevirdiği için tarayıcı, birden fazla sekme varken isteği
  reddedip etkin sekmeyi kapatır; tek sekmede pencere kapanır (diğer tarayıcılar gibi). Menü etiketi doğru.
- Hata düzeltmesi: oluşturulan sayfalardan yer imi / okuma listesi öğesi silmek her zaman ilk öğeyi siliyordu.
- Önceden var olanlar (değişmeden): sekme önizlemeleri, adres çubuğu önerileri, yer imi çubuğu ve yöneticisi,
  geçmiş araması, indirme yöneticisi, sayfada bul, yakınlaştırma, okuma modu, site başına JS ve masaüstü kimliği,
  hata sayfaları, şifre kasası.

### 3.4 Açılış hızı ve akıcılık

Sahibin bildirdiği sorun: Tarayıcı açılırken uzun süre takılıyor ve "Yükleniyor" yazıyordu. Kodda bulunan nedenler
(çalışma sırasında konsol kullanılamadı; aşağıdaki süreler Cortex-A57 ve SD kart için tahmindir; günlükte artık
konsolda ölçmek için bir `browser` zaman çizelgesi var):

| Neden | Önce | Sonra |
|---|---|---|
| `onStart` bütün kabuk beklerken çalışıyordu: geçmiş, yer imleri, okuma listesi, oturum ve çerez kavanozu ana iş parçacığında ayrıştırılıyordu; çerez yükleyici kopyaları ikişer ikişer karşılaştırıyordu (3000 çerez: ~4,5 milyon karşılaştırma) | Kullanılmış bir profilde pencere görünmeden ~150-400 ms | yalnızca `prefs.json` (~5-10 ms); gerisi web worker'larda paralel ayrıştırılır, ilk sekme veriler ve çerezler gelince açılır (bu arada spinner); kopyalar hash set ile |
| Parola kasası anahtarını açılışta türetiyordu (PBKDF2-HMAC-SHA256, 2 x 20000 tur) | ana iş parçacığında ~30-80 ms | worker'da |
| JavaScript prelude'u (148 KB) betikli ilk sayfada ana iş parçacığında derleniyordu; her harici betik ana iş parçacığında ayrıştırılıyordu (kesilemez) | prelude ~100-250 ms, büyük her bundle için ~0,3-1 s donma | prelude açılışta worker'da derlenir; 8 KB ve üzeri betikler kendi QuickJS runtime'ı olan bir worker'da derlenir, sayfa yalnızca bytecode'u yükler; tekrar kullanılan bundle'lar için 12 MB bytecode önbelleği |
| Düzen her yazı boyutu için bütün ASCII aralığının ölçülerini istiyordu (boyut başına ~97 glyph rasterize) ve kare başına 4 ms ölçüyordu; 1,5 s girdi olmayınca kabuk saniyede 20 kareye düştüğünden kesin yeniden düzen saniyelerce bekliyordu | başlangıç sayfasında ~700-900 glyph, kesin düzene kadar ~3-6 s | yalnızca metnin kullandığı karakterler (%40-60 daha az), kare başına 7 ms ve sayfa çalışırken pencere tam kare hızında kalır |
| İlk çizim ayrıştırıcı betikleri için 4 s'ye kadar bekliyordu; resimler paylaşılan üç ağ bağlantısının hepsini stil sayfaları ve betiklerden önce alabiliyordu | 4 s'ye kadar "Yükleniyor" | en çok 2 s; stil sayfaları ve ayrıştırıcı betikleri gelene kadar resimler tek bağlantı kullanır |
| Ziyaret edilen her sayfa `history.json`'u (1500 kayda kadar) ana iş parçacığında yeniden yazıyordu; betikli sayfaların DOM kopyaları her yeniden düzende betik kaynaklarını da kopyalıyordu | sayfa başına 30-80 ms takılma; büyük kopyalar | toplu, worker'da yazılır; betik / stil metni kopyalanmaz ve yeniden düzenler kopyalama maliyetine göre aralanır |

Oturum geri yükleme zaten yalnızca etkin sekmeyi yüklüyordu (diğerleri gösterilince yüklenir). Ana iş parçacığında ağ
veya DNS çağrısı yoktur (`net` kendi worker iş parçacıklarını kullanır).

### 3.5 Efektler ve hareket

- **2D transform** (`translate`, `scale`, `rotate`, `skew`, `matrix`, X / Y / 3d biçimleri, `transform-origin`, % ve px
  içeren `calc()`): efektli öğeler *paint group* olur. Öteleme ofset olarak çizilir; döndürme, ölçekleme veya eğme
  grubu bir kez bir dokuya (2 kata kadar keskin) çizer, sonra dönüştürülmüş bir dörtgen olarak gösterir. Tıklamalar ve
  form öğeleri transform'u izler; dönüştürülmüş içerik dönüşmüş sınırlarına göre ayıklanır. Perspektifsiz
  `rotateX/Y` ölçeklemeye indirgenir.
- **Geçişler (transition)**: `transition` ve uzun biçimleri (property, duration, timing: `ease*`, `linear`,
  `cubic-bezier`, `steps`, delay); `opacity`, `transform`, `color`, `background-color`, `border-color`, `width`,
  `height`, `top/left/right/bottom` için. Yeniden stil sonrası hesaplanan değer değişince başlar (betikten sınıf veya
  stil değişikliği); `transitionrun/start/end` betiklere ulaşır.
- **Animasyonlar**: `@keyframes` ve bütün `animation-*` özellikleri (name, duration, keyframe aralığı başına timing,
  delay, iteration count, direction, fill mode, play state); `animationstart/iteration/end` olayları. Yalnızca
  width / height sayfayı yeniden düzenler; diğerleri çizerken uygulanır. Kareler yalnızca bir şey hareket ederken
  istenir.
- **prefers-reduced-motion**, Ayarlar > Görünüm > Hareketi Azalt'ı izler (CSS ve `matchMedia`).
- **Çizim**: gerçek `opacity` (bütün grup), `box-shadow` (yumuşak dış gölgeler, inset kenar çizgisi olarak),
  `linear-gradient`, `radial-gradient` ve tekrarlayan gradyanlar (`background` içinde de), `overflow: hidden` kırpma
  (dikdörtgen), `position: relative` ofsetleri, `position: sticky` (top), `z-index` ve stacking sırası.
- **Düzen**: `grid-template-rows`, `grid-template-areas`, `grid-area`, `grid-row` (yayılım), açık çizgi yerleşimi,
  flex `order`, sarılan satırlar için `align-content` / `place-content`, `inset/right/bottom`; `@supports`
  koşulları değerlendirilir (`not`, `and`, `or`, `selector()`).
- **JS**: motorun animator'u üzerinde `Element.animate()` (`finished`, `cancel`, `pause`, `play`, `reverse`,
  `finish`, `onfinish`), 60 Hz `requestAnimationFrame`, `transform` (animasyonlu matris de), `opacity`, `z-index`,
  `transition-*`, `animation-*` için `getComputedStyle`, gerçek `IntersectionObserver` (thresholds, `rootMargin`;
  her düzenden sonra, kaydırmada ve boyut değişiminde denetlenir).

### 3.6 1.0.2: gerçek sitelerle uyumluluk

Gerçek sitelerin ne kadar sık dayandığına göre sıralandı.

| Alan | Önce (1.0.0) | Şimdi (1.0.2) |
|---|---|---|
| `position: absolute` | normal akışta yerleşirdi | akış dışında, en yakın konumlu ya da transform'lu atanın padding kutusuna göre: `top/right/bottom/left` (px, %, `calc`), `inset`, left ile right arasında germe, auto margin ile ortalama, `translate(-50%,-50%)`, ofsetler `auto` iken statik konum, iç içe kapsayan bloklar, `%` yükseklikler |
| `position: fixed` | akışta | görünüm alanına göre: sayfa kayarken yerinde kalır (başlıklar, çerez çubukları, bildirimler, modallar); CSS'teki gibi transform'lu bir ata onu tutar |
| Katman sırası | akıştaki grupların z-index'i | konumlu kutular akışın üstüne ağaç sırasıyla / z-index'e göre çizilir; `elementFromPoint` ve tıklamalar en üstteki katmana gider (tıklamayı alttaki içerik değil kaplama alır) |
| `calc()` | iki terim, `100% - 20px` `100%` sayılırdı | tam ifade: `+ - * /`, parantez, iç içe `calc()`, yüzde artı uzunluk tam tutulur (`calc(100% - 2rem - 10px)`), `min()/max()/clamp()` cascade'de, `env()` yedeği |
| Birimler | `vw/vh/vmin/vmax/rem/em` | aynı, artık her yerde `calc` içinde de |
| `:hover` `:focus` `:focus-within` `:focus-visible` `:active` `:target` | hiç eşleşmezdi | eşleşir (işaretçi, form odağı, kumandayla bağlantı odağı `:focus-visible` olarak); değişiklik, ancak bir seçici o pseudo-class'ı durumu değişen öğeye koyuyorsa sayfayı yeniden stillendirir; `:has()` (torunlar / çocuklar), `:placeholder-shown` |
| `overflow: auto / scroll` | en iyi ihtimalle `hidden` gibi | kaydırılan kutu: sürükleme, tekerlek ve sağ çubuk önce kutuyu kaydırır; eksen başına (`overflow-x`, `overflow-y`); içeriği artık sayfayı uzatmaz |
| `text-overflow: ellipsis`, `line-clamp` | metin sarardı | tek satır "…" ile kesilir; `-webkit-line-clamp` / `line-clamp` satırları sınırlar, sonuncuyu "…" ile bitirir |
| `object-fit`, `object-position` | gerilirdi | `fill / contain / cover / none / scale-down` ve konum (yuvarlak köşelerle de) |
| `filter` | yok | `brightness / contrast / grayscale / sepia / invert / saturate / opacity` çizilen her şeye (resimlerde yalnızca parlaklık); `blur()` ve `drop-shadow()` çizilmez |
| `backdrop-filter` | yok | bulanıklık çizilmez; arkasındaki yarı saydam arka plan metin okunsun diye neredeyse opak yapılır |
| `width / height: fit-content` (max-/min-content) | `auto` | içeriğe göre daralır |
| `<video>` / `<audio>` | gizliydi | sistem medya oynatıcısıyla sayfa içinde oynatma (FFmpeg: mp4/webm/mkv, mp3/aac/ogg, progressive http(s) ve HLS): poster, oynat düğmesi, denetim çubuğu (oynat/duraklat, süre, sarma, ses, "Video Oynatıcı'da aç"); aynı anda biri oynar, ilk oynatmadan önce hiçbir şey oluşturulmaz, gizlenen sekme kod çözücüsünü bırakır. `HTMLMediaElement`: `play()/pause()/load()/canPlayType()`, `currentTime`, `duration`, `paused`, `ended`, `volume`, `muted`, `loop`, `playbackRate`, `videoWidth/Height`, `readyState`, `error` ve `loadstart`, `loadedmetadata`, `canplay`, `play`, `playing`, `pause`, `timeupdate`, `ended`, `error`, `volumechange` olayları. `seeking`, `buffered`, `seekable`, `networkState` ve `seeking`/`seeked`/`waiting` olayları gerçek durumu yansıtır. MediaSource / SourceBuffer (YouTube'daki gibi `blob:` akışları) H.264 + AAC parçalı MP4 ve WebM için çalışır (aşağıdaki "Video" bölümü) |
| `<picture>` / `srcset` | srcset'i olan ilk `<source>`, ~600 px aday | `type`'ı burada çözülen ve `media`'sı tutan ilk `<source>`; `srcset` `sizes`'a ve resmin aldığı genişliğe göre (bellek için en çok 1280 px) |
| `<dialog>` | yalnızca `open` özniteliği | `show()`, `showModal()` (karartılmış sayfanın ortasında, odak `[autofocus]`'a), `close(value)`, `returnValue`, `requestClose()`, `cancel` / `close` olayları, Escape, `<form method=dialog>` |
| Formlar | text, password, checkbox, radio, select, düğmeler | ek olarak `range` (kaydırıcı), `color` (renk kutusu), `number` (dar alan), tarih / saat türleri (yazılacak biçimi gösteren alan), `<progress>`, `<meter>` (low / high / optimum renkleri) |
| `ResizeObserver` | tek çağrı | her düzenden sonra denetlenir; boyut her değiştiğinde bir kayıt |
| `matchMedia` | yalnızca `matches` | boyut / yakınlaştırma değişince `change` olayları (`addEventListener`, `addListener`, `onchange`) |
| `structuredClone` | JSON kopyası | klonlama algoritması: döngüler, `Map`, `Set`, `Date`, `RegExp`, typed array'ler, hatalar; fonksiyon ve node'lar `DataCloneError` atar |
| `getBoundingClientRect` | içeriğin birleşimi | bloğun kendi kenarlık kutusu, relative ofsetler / translate'lerle; sabit kutular görünümde kalır |

Zaten vardı, testlerle denetlendi: `Response.json/text/blob/arrayBuffer/formData/clone` ile `fetch`, `URL` /
`URLSearchParams`, `localStorage` / `sessionStorage`, Promise / async sırası, `MutationObserver`,
`requestIdleCallback`, `history.pushState` / `popstate`, `CustomEvent`, `dataset`, `classList`, `closest` / `matches`,
`TextEncoder` / `TextDecoder`, `crypto.getRandomValues` / `randomUUID`, `<details>`, `<template>.content`, satır içi
`<svg>` ve `<img src=*.svg>`, canvas 2D.

### 3.7 Bellek, boyut ve "ayrı bir uygulama mı?"

**Tarayıcı penceresi yokken motorun hiçbir parçası çalışmaz.** Motor sayfalar arasında birkaç şey tutar: iki worker
thread (her biri 1 MB stack), worker başına bir QuickJS derleme runtime'ı, derlenmiş prelude, bytecode önbelleği (en
çok 12 MB), çerez kavanozları, Web Storage ve font ölçü önbelleği. 1.0.2'den önce bunlar Tarayıcı kapandıktan sonra
bellekte kalıyordu. Artık pencere kapanınca (`~BrowserApp`) `web::releaseEngine()` çalışır: çerezleri ve Web
Storage'ı kaydeder, hepsini serbest bırakır; worker'lar kuyruktaki işleri bitirir, QuickJS runtime'larını bırakıp
çıkar (`web::stopWorkers()`; sonraki iş onları yeniden başlatır). Sayfalar, düzenler, resimler, canvas'lar ve medya
oynatıcıları sekmeleriyle gider. Günlükte görünür: `engine released: heap A -> B MB`, `workers stopped (2)` ve 3 sn
sonra `3 s after the Browser closed: heap X MB in use`; her sayfa için `page ready: ... (heap, MB above the Browser's
start, JS KB)`.

| Ölçüm | Değer |
|---|---|
| Motor + Tarayıcı kodu (`web_*.o`, `app_browser.o`, text) | önce 1,14 MB, şimdi 1,23 MB (+85 KB), 44 MB'lık NRO text'inin içinde; prelude romfs'te 163 KB |
| PC test ortamı, boş Tarayıcı penceresi + hata sayfası | açıldığı ana göre yaklaşık 5,5 MB heap |
| Boşta, Tarayıcı penceresi yok | 0 thread, 0 QuickJS runtime, önbellekler boş (ölçüm: yukarıdaki günlük satırları; konsol sayıları bu tabloya girmeli) |

**App Market'ten ayrı bir uygulama mı?** Native modüller (`.nxvmod`) 1.0.x'te kapalı: stickies, fontbook ve network
modül belleğindeki bir kilitte `mutexLock` içinde çöktü (yazılabilir segment `svcControlCodeMemory` ile eşleniyor ve
o bellekte çekirdek kilitlemesi başarısız oluyor). Tarayıcı tam olarak buna takılırdı: `web_jobs.cpp`,
`web_layout.cpp` ve `app_browser.cpp` `static Mutex` / `CondVar` tutuyor, `web_js.cpp` ise yükleyicinin reddettiği
(`PT_TLS`) bir `thread_local` derleme runtime'ı kullanıyor. Modül yapmak için (1) yükleyicinin yazılabilir segmenti
sıradan bellek olarak eşlemesi (ya da modülün kilitlerinin heap'e taşınması), (2) TLS desteği ya da `thread_local`'ın
kaldırılması, (3) modül testlerinin PC test ortamında ve konsolda yeniden açılması gerekir. Kazanç 66 MB'lık NRO'da yaklaşık
1,4 MB (kod + prelude) olur, RAM'de hiç olmaz: yerleşik bir uygulamanın kod sayfaları kapalıyken bir şey tutmaz ve
motor artık heap'ini bırakıyor. Öneri: Tarayıcı yerleşik kalsın (diğer uygulamalar da bağlantıları onunla açıyor);
sahibi listelerden kaldırılabilir olmasını isterse mevcut opsiyonel uygulama mekanizması (`"optional": true`, App
Market'te "Al", Ayarlar > Uygulamalar) kodu taşımadan gizleyebilir, ama bu NRO boyutunu değil yalnızca listeleri
değiştirir.

## 4. Test sayfaları ve sonuçlar

`tests/web/` altındaki sayfalar (bilgisayarda `python -m http.server 8000`, konsoldan
`http://<ip>:8000/`):

| Sayfa | İçerik |
|---|---|
| `js_dom.html` | 34 otomatik test, PASS/FAIL tablosu |
| `css.html` | Yeşil/kırmızı kutularla CSS özellikleri |
| `layout.html` | 16 flexbox/grid düzeni, beklenen görünüm açıklamalı |
| `canvas.html` | Çizimler, 7 piksel testi, `requestAnimationFrame` animasyonu |
| `svg.html` | Satır içi SVG, `currentColor`, `<use>`, gradyan, data-URI SVG, WebP |
| `compat.html` | Dört grupta 64 otomatik denetim (konumlandırma ve birimler, CSS, HTML5 öğeleri, JS API'leri), PASS/FAIL tablosu; başlıkta "Compat x/y", her sonuç günlüğe de yazılır (`webjs` satırları) |
| `html5.html` | Görsel: `:hover` menülü yarı saydam sabit başlık, absolute rozetler ve ortalama, `object-fit`, ellipsis, line-clamp ve filtreli kart ızgarası, yatay ve dikey kaydırılan kutular, video / ses denetimleri, form denetimleri, `<details>`, modal `<dialog>` |

**Önemli not:** Bu çalışma sırasında konsol ya da emülatör kullanılamadı (emülatör koordinatörde). Aşağıdaki
"Beklenen" sütunu, kodun incelenmesine ve canvas bağlamının Node.js'te sahte (mock) yerel fonksiyonlarla
çalıştırılmasına dayanır. Konsolda `js_dom.html` açılınca başlıkta "JS x/34" yazar; gerçek sonuçlar bu tabloya
işlenmelidir.

| Alan | Test | Beklenen |
|---|---|---|
| DOM | querySelector(All), matches/closest, classList, dataset, create/append/insertBefore/remove, innerHTML/outerHTML | PASS |
| Olaylar | yakalama → hedef → kabarcıklanma sırası, stopPropagation/preventDefault, CustomEvent | PASS |
| Zamanlayıcılar | setTimeout, setInterval/clearInterval, requestAnimationFrame, mikro görev sırası, async/await | PASS |
| Depolama | localStorage, sessionStorage (özel sekmede yalnızca bellekte) | PASS |
| Gezinti | history.pushState/replaceState, URL/URLSearchParams | PASS |
| Ağ | fetch (aynı köken JSON), XMLHttpRequest, AbortController | PASS (http üzerinden; sdmc: ile ATLANDI) |
| Diğer | TextEncoder/Decoder, MutationObserver, FormData, matchMedia, CSS.supports, structuredClone, crypto | PASS |
| JS dili | ES2020/ES2022 (QuickJS-ng) | PASS |
| Canvas | getContext('2d') + getImageData | PASS |
| WebGL | getContext('webgl') | FAIL (beklenen: yok) |
| CSS | var() (5 kutu), @media, prefers-color-scheme, calc/clamp, hsl/rgb, :nth-child, :is/:not, [attr^=], !important, @supports | Yeşil |
| Düzen | flexbox 1-11, grid 12-15, değişkenli flex 16 | Açıklandığı gibi |
| SVG | satır içi, currentColor, `<use>` sprite, linearGradient, data-URI SVG, WebP | Görünür |

| Efektler | `effects.html` 1-15: hesaplanan transform / opacity / z-index / animation-name / transition-duration, animasyonlu değer değişimi, rAF ~60 Hz, transitionend, animationstart / iteration / end, `Element.animate` finished ve cancel, IntersectionObserver, CSS.supports, matchMedia reduced motion | PASS (beklenen; rAF testi sayfanın aldığı kare hızına bağlı) |
| Düzen 2 | `layout2.html` 1-6 | Açıklandığı gibi |

Yeni sayfalar: `effects.html` (15 otomatik test + görsel bölümler), `layout2.html` (grid alanları ve satırları,
yayılım, `order`, `align-content`, `calc` / `clamp` / `min`, `place-content`), `heavy.html` (2000 kartlık yapay ağır
sayfa, `?n=` ile büyütülür; kurulum ve ilk kare süreleri başlıkta).

### Desteklenmeyenler (bilinçli)

- 3D (perspektif, `rotateX/Y` düzleştirilir); resimler dışındaki içerikte yuvarlak kırpma (`overflow: hidden`
  dikdörtgene kırpar); `filter: blur()` / `drop-shadow()` ve arka plan bulanıklığı; `clip-path` şekilleri; öğesi
  düzenden çıkan özelliğin `transitionend`'i; `::before` / `::after` üretilen içerik.
- Geçiş, yeniden stil düzenlendikten sonra başlar (masaüstü tarayıcılardan bir düzen sonra); `auto` boyutlara ve
  kutusu olmayan saydam arka plana / arka plandan geçişler atlar. Element.animate'te `currentTime` ile konumlama,
  `playbackRate` ve composite modları yok.
- `grid-auto-flow: dense`, `fr` satırlar, `subgrid`, `masonry`.
- Canvas: `<video>` karesi `drawImage`, canvas metninde yazı tipi ailesi (yalnızca sans normal / kalın), SVG yol metninden `Path2D`.
- SVG içinde `<text>`, CSS sınıflarıyla boyama, filtreler.
- Web yazı tipleri (`@font-face`), Service Worker, WebSocket. DRM'li video (Widevine, FairPlay, PlayReady) hiçbir zaman
  oynamaz: konsolda CDM yok ve `navigator.requestMediaKeySystemAccess` reddeder. Bunlara ihtiyaç duyan siteler bu tarayıcıda çalışmaz.

## WebGL örnekleri

Gerçek WebGL sayfaları emülatörde konsol profiliyle (`NEXVYN_CONSOLE_PROFILE=1`, aynı PC'de iki emülatör) Tarayıcı'da
çalıştırıldı. Kare sayıları **göreli**dir (emülatör, konsol değil): yalnızca sürümleri karşılaştırmak için, asla konsol
fps'i olarak kullanılmaz. webglsamples.org demoları BSD-3-Clause (Google); yerel bir kopyadan sunuldu, bu depoda yoktur.

| Örnek | Sonuç | Not (ekran görüntüsü) |
| --- | --- | --- |
| webglsamples.org dynamic-cubemap | GEÇTİ | Her karede yeniden çizilen cube map'i (6 yüz) yansıtan krom küre, dönen kamera, JS hatası yok, sayfa sayacında yaklaşık 6 fps (0309, 0310) |
| webglsamples.org field | GEÇTİ | Çimen alanı, sayfa sayacında yaklaşık 18 fps (0312) |
| webglsamples.org aquarium | çiziyor, çok yavaş | Balık sahnesi çiziliyor, yaklaşık 1 fps; kare sürerken "Yanıt vermiyor" görünüyor (0313) |
| three.js webgl_materials_cubemap_dynamic | KALDI (hız) | Sayfa ve kontroller açılıyor, canvas siyah kalıyor: `raf` kareleri zaman bütçesini aşıyor (0314) |
| three.js webgl_geometry_cube | KALDI (yükleme) | 1,2 MB'lık modül profilde yaklaşık 60 sn'de yükleniyor; çekimde siyah |
| three.js webgl_postprocessing_unreal_bloom | KALDI (hız) | `raf` kareleri zaman bütçesini aşıyor |
| webgl_loader_gltf, webgl_shadowmap, webgl_instancing_performance, Babylon.js playground | çalıştırılmadı | sonraki tur |

Bu turdaki motor düzeltmeleri (hepsi genel): cube map yüzlerine çizim (2B gölge doku üzerinden çizilip yüze kopyalanır,
çünkü emülatör her çizimi 0. katmana gönderiyor), `copyTexImage2D` / `copyTexSubImage2D`, `<img>` ve `ImageBitmap`
kaynaklı `texImage2D` / `texSubImage2D` (eskiden gri tek piksel yüklüyordu), CPU'da üretilen cube map mip zinciri
(host alt seviyeleri boş bırakıyordu), canvas okumasının bantlar halinde yapılması (tek büyük okuma yalnızca ilk 256
sütunu döndürüyordu), WebGL sayfalarında kare callback'i, modül çalıştırma ve fetch tamamlanması için daha uzun bütçe,
yavaş sürücü çağrıları için kredi. Testler: `tests/html5/webgl-cubemap-fbo.html`, `webgl-cube-image.html`.

## Video

Neyi oynatır (konsol CPU'sunda yazılım çözme, `media::Player` / FFmpeg; donanım çözme kapalı kalır: `media.hwdec` varsayılan kapalıdır, hiçbir şey ona güvenmez):
- Progressive `<video>` / `<audio>`: http(s) ya da yerel dosyadan mp4, webm, mkv, mp3, aac, ogg. Olaylar, `currentTime`, `seeking`, `buffered`.
- HLS (`.m3u8`, VOD): FFmpeg'in HLS demuxer'ı ile. Hedef yaklaşık 480p'ye kadar H.264.
- MediaSource (`new MediaSource()` nesnesinin `blob:` adresi): `video/mp4` (avc1 seviye 3.0'a kadar, mp4a.40.x) ve `video/webm` (VP8, Vorbis) için
  `addSourceBuffer`; `appendBuffer` (asenkron, `updating`, `updateend`), `remove`, `abort`, `timestampOffset`, `appendWindowStart/End`, `buffered`,
  `endOfStream`, `duration`. Veri ayrı thread'de çözümlenir ve sıkıştırılmış tutulur (MediaSource başına 32 MiB, sonra `QuotaExceededError`); bozuk
  akış yalnızca kendi MediaSource'unu düşürür. `MediaSource.isTypeSupported`, `canPlayType` ve `navigator.mediaCapabilities.decodingInfo` aynı cevabı
  verir; uyarlamalı oynatıcılar konsolun çözebileceği basamağı seçer (VP9, Opus, AV1 ve seviye 3.0 üstü H.264, `media.mse.vp9`, `media.mse.opus` ya da
  gerçek donanımda `media.hwdec` açılmadıkça desteklenmiyor görünür).

Sınırlar:
- DRM / EME imkansız: CDM yok; `requestMediaKeySystemAccess` reddeder. Kiralık ya da korumalı yayınlar oynamaz.
- 720p ve üstü yazılım çözmede akıcı değil; 1080p konsolda doğrulanmamış donanım çözme ister.
- Yapılmadı: `requestVideoFrameCallback`, metin izleri (WebVTT), Picture-in-Picture, `ManagedMediaSource`, gerçek YouTube sitesi uçtan uca (oynatıcı betiği JS
  motoru için ağır). MSE dışında uyarlamalı HLS bit hızı seçimi FFmpeg varsayılanıdır (ilk varyant).
- Testler: `tests/html5/video-play.html`, `video-hls.html`, `video-mse.html`, kendi ürettiğimiz kliplerle (`tools/gen_html5_video.py`, üçüncü taraf medya yok).
- **Özel öğeler ve Shadow DOM (temel)**: `customElements.define/get/whenDefined/upgrade/getName` var olan ve yeni öğeleri yükseltir (constructor, `connectedCallback`, `disconnectedCallback`, `observedAttributes` ile `attributeChangedCallback`). `attachShadow()` düzleştirilmiş bir shadow root döner (host'un ilk çocuğu olan `display:contents` kutusu; `host`, `mode`, `shadowRoot` çalışır, `<slot>` yansıtması ve stil kapsamı yok).
- **EME (yalnızca ClearKey)**: `navigator.requestMediaKeySystemAccess('org.w3.clearkey')`, `MediaKeys`, `MediaKeySession` (`generateRequest`, ClearKey JSON lisansıyla `update`, `keystatuseschange`), `video.setMediaKeys()` ve MSE'deki CENC fMP4 için `encrypted` olayı. Demuxer, sayfanın lisansındaki anahtarla cenc-aes-ctr çözer (MediaSource başına tek anahtar). Widevine, PlayReady ve FairPlay `NotSupportedError` ile reddedilir: burada olmayan ve taklit edilmeyen bir içerik çözme modülü ister. Test: `tests/html5/eme-clearkey.html`.

## Sitelere giriş

Çerez kuralları RFC 6265bis'i izler (`source/web/web_cookies.cpp`, host testleri `tests/test_cookies.cpp`):

- Her yönlendirme adımının (301, 302, 303, 307, 308) `Set-Cookie`'si sonraki istekten önce saklanır; oturum çerezini
  yönlendirmede koyan girişler çalışır. `303` ya da `POST` sonrası `301` / `302` `GET` olur; `307` / `308` yöntemi ve
  gövdeyi korur.
- `SameSite` Lax / Strict / None, `Secure` (yalnızca https, `SameSite=None` için şart), `__Secure-` / `__Host-` önekleri,
  public-suffix listesiyle `Domain` ve `Path` eşleşmesi, `Expires`'tan önce `Max-Age`, 400 gün sınırı, `HttpOnly`
  (`document.cookie`'den gizli, script koyamaz ya da ezemez), çerez başına 4096 bayt, alan adı başına 180, toplam 3000
  sınırı. `SameSite`'sız çerez Lax gibi davranır; siteler arası üst düzey `POST`'ta 2 dakika yine gider (siteye geri
  POST eden tek oturum açma için).
- **Üçüncü taraf çerezleri** (Ayarlar > Gizlilik, "Üçüncü taraf çerezlerini engelle", varsayılan açık): sayfadan başka bir
  siteye giden resim, stil ve script istekleri çerez göndermez, saklamaz. Siteler arası bir giriş yönlendirmesinin
  geçtiği site, oturumun geri kalanında muaftır.
- Süresi olan çerezler ve `localStorage` yeniden başlatmada ve OS güncellemesinde kalır (eski çerez dosyaları aynen
  yüklenir). Site başına "Site verilerini temizle" o sitenin ve alt alan adlarının çerezlerini ve Web Storage'ını siler;
  "Tarama verilerini temizle" hepsini siler.
- HSTS: `Strict-Transport-Security` gönderen siteye oturumun geri kalanında yalnızca https ile gidilir.
- Formlar: `GET` ve `POST`; `application/x-www-form-urlencoded`, `multipart/form-data`, `text/plain` (`enctype`,
  `formenctype`), gizli alanlar, `required` (boş zorunlu alan gönderimi engeller; `novalidate` / `formnovalidate`
  kapatır), Enter ve `requestSubmit()`. Parola alanında göster / gizle düğmesi vardır; `type=number` sayısal klavyeyi
  açar.
- Şifre yöneticisi: kaydetme teklifi yalnızca giriş işe yaradıktan sonra çıkar (sekme formdan ayrıldı ya da form
  gitti); yanlış parolada ve özel sekmede asla çıkmaz. Parolalar yalnızca tam origin için dolar. Şifreler sayfasında
  "Siteyi aç ve giriş yap" düğmesi vardır. Parolalar ve çerezler asla loglanmaz.
- Hatalar: sertifika sorunu aşılamayan bir "Güvenli bağlantı kurulamadı" sayfası gösterir; zaman aşımı Yeniden dene
  sayfası gösterir.

Yerel test: `python tests/html5/login_server.py` CSRF belirteçli giriş formu, çerez bayrakları, yönlendirme zinciri, 2FA
sayfası ve OAuth yönlendirmesi sunar; `python tests/html5/run_login_ryu.py` sayfaları emülatörde koşar. Tek kimlik bilgisi
yalnızca o sunucuda geçerli sahte bir çifttir.

**SD kartta bytecode önbelleği.** Büyük betikler (8 KB ve üstü) derlenmiş bytecode olarak `jscache/` içinde de tutulur (48 MB, en eskiler silinir); aynı siteye dönüşte ya da yeniden açılışta ayrıştırma atlanır. Ayar `web.jsBytecodeCache` (varsayılan açık); gizli sekmeler kullanmaz. Bozuk ya da eski kayıt yok sayılır ve yeniden derlenir.

**Sayfa hataları ve düzen düzeltmeleri.** Betik hataları ve `console.error` satırları tarayıcı günlüğüne artık kaynak URL ve satır:sütun ile yazılır; zaman bütçesini aşan betik URL'siyle günlüğe düşer. CSS: data: ya da http(s) resimli `mask-image` / `-webkit-mask-image` (resmin şekli arka plan rengiyle boyanır, bir kez rasterlenir ve önbelleğe alınır), katman sırası (`@layer`: katmansız kurallar katmanlıları, sonraki katman öncekini yener, `!important` tersine çevirir), `min-width: max-content` (flex öğeleri doğal genişliğinin altına inmez) ve `grid-template-columns: minmax(0, auto)` sıfıra çökmek yerine içeriğe göre boyutlanır (düğme yazıları harf harf alt satıra düşüyordu). Test sayfası: `tests/web/flex-mincontent.html`.

**Varsayılan masaüstü siteleri.** Tarayıcı artık masaüstü sitelerini ister (Chrome benzeri masaüstü kimliği, `(hover: hover)` / `(pointer: fine)` medya özellikleri, `navigator.platform` `Win32`, dokunma noktası yok). Ayarlarda "Mobil siteleri iste" (varsayılan kapalı) ve adres çubuğu menüsünde site başına anahtar var (eski "varsayılan masaüstü" değeri okunmaz, güncelleyen kullanıcı masaüstü alır; kayıtlı yakınlaştırma korunur). Yakınlaştırma ve cihaz piksel oranı değişmedi. Bilinen eksikler (konsol profilinde bakıldı): github.com hâlâ siyah üst bant ve sıkışık düzen gösteriyor (container query ve bazı özel özellikler henüz yok); en.wikipedia.org yükleyici betiği 1 sn bütçede kesildiği için yaklaşık 40 sn stilsiz kalıyor; old.reddit.com oturumsuz ziyaretçiyi giriş sayfasına yönlendiriyor ve `CSSStyleSheet` istiyor.

## Performans ve bellek

- Arka plan sekmeleri hiçbir şey çalıştırmaz (JS timer, rAF, medya yok); sekme arka plana geçince texture, canvas ve oynatıcılar serbest kalır, JS çöpü bir kez toplanır.
- Eski sekmelerin belleğini boşalt (Tarayıcı ayarları, `browser.discardTabs`, varsayılan açık): 3'ten (applet modu) ya da 6'dan fazla canlı arka plan sekmesi varsa en eski kullanılanlar bellekte kapatılır. OS düşük bellek bildirince tüm arka plan sekmeleri ve boştaki görsellerin çoğu bırakılır. Atılan sekme adresini, geçmişini ve kaydırma konumunu korur, gösterilince yeniden yüklenir. Özel sekmeler, yüklenen sekmeler, POST sayfaları ve `about:` sayfaları atılmaz.
- Takılmalar: `perf.stallMs`'den (varsayılan 150 ms) uzun bir kare sistem logunda tek `stall` satırı yazar: evre (`web page parsed`, `web js start`, `web js tick`, `web layout start`, `web job done` = ağ/görsel tamamlanması, `web paint`) ve sayfa adresi. Sonda: `python tools/browser_stall.py`.
- Ölçümler yalnızca konsol profiliyle yapılır (`NEXVYN_CONSOLE_PROFILE=1`); bkz. `qa/PERFORMANS.md`.

## Güvenlik

- WebGL tampon ve çizim aralıkları (`bufferSubData`, `getBufferSubData`, `drawElements`, `drawRangeElements`) offset ile boyut toplanmadan denetlenir; çok büyük offset sınır kontrolünü artık aşamaz. Script sayıları 64 bit tamsayıya çevrilmeden önce sınırlanır.
- `new Worker(url)` yalnızca aynı kökenli betikleri, sayfanın kendi `blob:` adreslerini ve `data:` adreslerini kabul eder (yerel sayfa yerel dosya kullanabilir); gerisi `SecurityError` verir.
- Başka köken'e yönlenen istek `Authorization`, `Cookie`, `Proxy-Authorization` ve CSRF-token başlıklarını bırakır. Üçüncü taraf çerez için giriş yönlendirme izni özel sekmelerde ayrı tutulur ve onlarla birlikte silinir.
- Özel sekmeler bellekteki bytecode önbelleğini ne okur ne yazar (disk önbelleği zaten kapalıydı). Önbellek kaydı yalnızca anahtar, bağımsız kaynak özeti ve kaynak uzunluğu üçü birden eşleşince kullanılır (önbellek kuşağı `kBytecodeGen` 2; eski `bc1_*` dosyaları yok sayılır ve temizlenir).
- Arka plan dosya yazımı yazarken ana thread'in aldığı kilidi tutmaz; son özel sekme kapanınca özel IndexedDB veritabanları da bırakılır; başarısız `WebAssembly.Instance` bağlaması kaydettiği import'ları serbest bırakır.
