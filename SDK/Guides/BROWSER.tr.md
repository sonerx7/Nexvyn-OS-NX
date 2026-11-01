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

Bu yüzden Nexvyn OS **karma (hibrit)** bir yol izliyor:

1. **Tam tarayıcı (WebKit)**: Konsolun kendi WebKit tabanlı web applet'i (NetFront NX). Nexvyn OS başlık modunda
   çalışırken, motoru zorlayan siteler tek dokunuşla bu applet'te açılır; kapatınca Nexvyn OS'a dönülür.
2. **Kendi motorumuz**: QuickJS üzerinde HTML/CSS/JS motoru (`source/web/`). Bu çalışmada CSS değişkenleri,
   gerçek flexbox, CSS grid, SVG, `<canvas>` 2D, özel sekme ve gamepad ile bağlantı gezintisi eklendi.

## 2. Araştırma

### 2.1 Switch'in yerleşik web applet'i (WebKit / NetFront NX)

- Switch'te kullanıcıya açık normal bir tarayıcı yoktur; web içeriği tarayıcı applet'leriyle gösterilir. Motor,
  WebKit tabanlı **NetFront NX**'tir. User-Agent'taki WebKit sürümü sistem sürümüne göre değişir:
  1.0.0-6.1.0'da `AppleWebKit/601.6`, 10.0.0'da `606.4`, 20.1.0 ve sonrasında (ve Switch 2'de) `613.0`.
  ([Switchbrew: Internet Browser](https://switchbrew.org/wiki/Internet_Browser))
- WebKit 613 kabaca Safari 15.4 dönemine denk gelir: ES2021 JavaScript, flexbox/grid, CSS değişkenleri, `<video>`
  (whitelist'li applet'lerde), Web Audio gibi özellikler vardır. WebGL ve JIT durumu Switchbrew'de belgelenmemiştir.
- Genel amaçlı applet `WebApplet` (010000000000100A). Whitelist yalnızca sayfa gezintisini sınırlar; `<video>` ve
  JS ağ istekleri etkilenmez. Applet'ler SD kartı bağlamaz. Applet yığını 0x15600000 bayttır (~342 MB).
  ([Switchbrew: Internet Browser](https://switchbrew.org/wiki/Internet_Browser))
- libnx API'si: `webPageCreate`, `webConfigSetWhitelist`, `webConfigSetPointer`, `webConfigSetTouchEnabledOnContents`,
  `webConfigSetPageCache`, `webConfigSetWebAudio`, `webConfigShow`, dönüşte `webReplyGetLastUrl` /
  `webReplyGetExitReason`. ([libnx web.h](https://switchbrew.github.io/libnx/web_8h.html), devkitPro
  `libnx/include/switch/applets/web.h`)
- Kısıtlar: applet yalnızca uygulama (başlık) olarak çalışan bir programdan açılabilir; Albüm'den açılan homebrew
  (applet modu) ve emülatörler (Ryujinx web applet'i uygulamaz) bunu yapamaz. BrowseNX gibi araçlar da aynı applet'i
  hbmenu üzerinden açar ve NRO sürümünde HTML5 video desteği olmadığını not eder.
  ([GameBrew: BrowseNX](https://gamebrew.org/wiki/BrowseNX_Switch))
- Applet açıkken Nexvyn OS bekler (çağrı engelleyicidir); çerezler/oturumlar applet ile paylaşılmaz.

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
  için tam bir motor şart. Switch'te bunun en iyi ve en ucuz kaynağı sistemin kendi WebKit'i.
- **Kendi motor**: Haber siteleri, Wikipedia, belgeler, forumlar, basit uygulamalar ve yerel HTML için hızlı,
  Nexvyn OS ile bütünleşik (şifre kasası, okuma modu, indirmeler, sekmeler). En çok fayda sağlayan eksikler
  kapatıldı: CSS değişkenleri (modern sitelerin neredeyse tamamı renkleri bunlarla verir), gerçek flexbox ve grid
  (menüler, kart ızgaraları), satır içi SVG (ikonlar), canvas 2D (grafikler, basit oyunlar).
- **Ayrıştırıcı/yerleşimi lexbor veya litehtml ile değiştirmek**: Lisans olarak mümkün; ancak DOM/JS bağlantıları,
  iş parçacığı anlık görüntüleri (snapshot) ve yazı tipi ölçüm önbelleği kendi veri yapılarımıza bağlı. Bu
  çalışmada değiştirmek, aynı sürede eklenen özelliklerden daha az kazanç ve daha çok risk getirirdi.

## 3. Yapılanlar

### 3.1 Hibrit tarama: "Tam tarayıcı (WebKit)"

- **Uyumluluk dedektörü** (`Page::compatibility()`): sayfada neredeyse hiç metin yokken çok sayıda betik (yalnızca
  JS ile kurulan uygulama), `<video>/<audio>`, WebGL/WebGPU, `<canvas>`, "JavaScript'i etkinleştirin" uyarıları,
  React/Next/Angular/Nuxt/Gatsby/Svelte işaretleri, tekrarlayan betik hataları ve sitede JS'nin kapalı olması
  puanlanır. Puan 3 ve üstüyse sayfanın üstünde nedeniyle birlikte öneri çubuğu çıkar.
- Çubukta **Tam Tarayıcı (WebKit)** ve **Hep Böyle Aç** düğmeleri. Site başına tercih: o siteye her gidişte sekme bir
  "Tam tarayıcıda açıldı" sayfası gösterir ve applet açılır; "Bu kez burada aç" ve "bu siteyi tam tarayıcıda açmayı
  bırak" seçenekleri vardır.
- Applet işaretçi, dokunmatik, sayfa önbelleği ve Web Audio açık başlatılır. Kapanınca applet'in son gösterdiği adres
  (`webReplyGetLastUrl`) geçmişe yazılır; farklı bir sayfaya gidildiyse "o sayfayı burada aç" bildirimi gelir.
- **Kullanılamadığında** (applet modu / emülatör) düğme yerine "WebKit neden yok?" çıkar ve nedenini açıklar.
- Ayarlar > Genel: "Tam tarayıcıyı öner", "<site> sitesini hep tam tarayıcıda aç".
- Paylaş menüsü ve sağ tık menüsü: "Tam Tarayıcıda Aç (WebKit)", "Bu Siteyi Hep Tam Tarayıcıda Aç".

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
- **Canvas 2D**: yollar, eğriler, yaylar, `roundRect`, `Path2D`, dönüşümler, `save/restore`, nonzero/evenodd
  dolgu, çizgi (eklem ve uçlar disklerle yaklaşık), `fillRect/strokeRect/clearRect`, `globalAlpha`,
  `destination-out`, `fillText/measureText` (sistem yazı tipiyle, bitmap'in üstünde katman), `getImageData`,
  `putImageData`, başka bir canvas'tan `drawImage`, `isPointInPath`. Kenar yumuşatmalı rasterleştirici C++'ta.
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
| WebGL | getContext('webgl') | FAIL (beklenen: yok → tam tarayıcı önerilir) |
| CSS | var() (5 kutu), @media, prefers-color-scheme, calc/clamp, hsl/rgb, :nth-child, :is/:not, [attr^=], !important, @supports | Yeşil |
| Düzen | flexbox 1-11, grid 12-15, değişkenli flex 16 | Açıklandığı gibi |
| SVG | satır içi, currentColor, `<use>` sprite, linearGradient, data-URI SVG, WebP | Görünür |

| Efektler | `effects.html` 1-15: hesaplanan transform / opacity / z-index / animation-name / transition-duration, animasyonlu değer değişimi, rAF ~60 Hz, transitionend, animationstart / iteration / end, `Element.animate` finished ve cancel, IntersectionObserver, CSS.supports, matchMedia reduced motion | PASS (beklenen; rAF testi sayfanın aldığı kare hızına bağlı) |
| Düzen 2 | `layout2.html` 1-6 | Açıklandığı gibi |

Yeni sayfalar: `effects.html` (15 otomatik test + görsel bölümler), `layout2.html` (grid alanları ve satırları,
yayılım, `order`, `align-content`, `calc` / `clamp` / `min`, `place-content`), `heavy.html` (2000 kartlık yapay ağır
sayfa, `?n=` ile büyütülür; kurulum ve ilk kare süreleri başlıkta).

### Desteklenmeyenler (bilinçli)

- `position: absolute/fixed` hâlâ normal akışta yerleşir (yalnızca ofsetleri animasyonlanır); 3D yok (perspektif,
  `rotateX/Y` düzleştirilir); resimler dışındaki içerikte yuvarlak kırpma, `filter` / `backdrop-filter`,
  `clip-path` şekilleri, `:hover` stilleri yok.
- Geçiş, yeniden stil düzenlendikten sonra başlar (masaüstü tarayıcılardan bir düzen sonra); `auto` boyutlara ve
  kutusu olmayan saydam arka plana / arka plandan geçişler atlar. Element.animate'te `currentTime` ile konumlama,
  `playbackRate` ve composite modları yok.
- `grid-auto-flow: dense`, `fr` satırlar, `subgrid`, `masonry`.
- Canvas: `clip()`, gradyanlar (ortalama renkle boyanır), desenler, gölgeler, `<img>` kaynaklı `drawImage`,
  `toDataURL`.
- SVG içinde `<text>`, CSS sınıflarıyla boyama, filtreler.
- Web yazı tipleri (`@font-face`), `<video>/<audio>`, WebGL, Service Worker, WebSocket, WebAssembly.
  Bunlara ihtiyaç duyan siteler için tam tarayıcı (WebKit) önerilir.
