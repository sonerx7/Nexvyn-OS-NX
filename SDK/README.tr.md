# Nexvyn OS SDK

[English](README.md) · **Türkçe**

Nexvyn OS için uygulama, oyun, tema ve yazı tipi yapanlar için her şey: SDK başvurusu, her dil için hızlı başlangıç ve
şablon, rehberler ve tarifler, çalışan örnekler, AI asistanları için context pack'ler, yayımlama rehberi ve komut
satırı araçları. Her belge İngilizce ve Türkçe vardır.

**Güncel sürüm: SDK 1.12** (Nexvyn OS 1.2.2). SDK 1.0-1.11 için yapılmış uygulamalar değişmeden çalışır
([SDK sürümleri](Guides/SDK_VERSIONS.tr.md)).

## Bir bakışta SDK 1.9

<p align="center"><img src="../.github/assets/nexgfx-orbit.webp" width="100%" alt="NexGFX ile çizilmiş bir toplantı odasında dönen kamera: camdan giren güneş, gölgeler, kromda ve clearcoat zeminde yansımalar"></p>

### NexGFX pbr renderer

3B uygulama ve oyunlar için fiziksel tabanlı bir renderer; uygulama başına `g3d.renderer("pbr")` ile açılır.

| Özellik | API |
|---|---|
| Normal, occlusion ve emissive haritalı metallic-roughness materyaller; glTF ORM, FBX harita setleri, MetallicSmoothness | model dosyasından ya da `g3d.material(meshOrModel, {...}[, name])` |
| Gerçek zamanlı ışıklar: güneş ve 16'ya kadar nokta, spot ve yönlü ışık (nesne başına 8) | `g3d.light`, `g3d.addLight`, `g3d.updateLight`, `g3d.removeLight` |
| Gölgeler: güneş (görüşe oturtulmuş, filtreli) ve bir spot ışık | `g3d.shadows({quality, distance, bias})` |
| Cam: kırılmalı ince geçirgenlik, Fresnel yansıması; alfa karışımı ve alpha to coverage'lı kesik | `transmission`, `ior`, glTF alfa modları |
| Gök yarım küresinden ya da 6 yüzlü bir cube map'ten (yansıma probu) yansıma ve ortam ışığı | `g3d.environment({sky, ground, cubemap})` |
| HDR, ACES ya da filmic ton eşleme, bloom, MSAA 2x / 4x / 8x | `g3d.postfx({exposure, tonemap, bloom, msaa})` |
| GPU instancing, çağrı başına 128 kopyaya kadar | `g3d.drawInstanced(mesh, transforms)` |
| Konsolun sundukları ve kareleri neyin çizdiği | `g3d.caps()`, `g3d.rendererInfo()` |

Konsol OpenGL ES 3 sunmuyorsa `g3d.renderer("pbr")` `"basic"` döndürür ve aynı çağrılar yine çizer.

| | |
|:---:|:---:|
| <img src="../.github/assets/nexgfx-effects.webp" alt="Aynı oda gölgesiz ve bloom'suz, sonra gölge, bloom ve 4x MSAA ile"> | <img src="../.github/assets/sample-pbr3d.webp" alt="PBR, Işıklar ve Gölgeler örneği: emissive şeritli kasalar, pürüzlüden parlak metale küreler, sütunlar ve renkli ışıklar"> |
| **Son efektler:** gölge, bloom, MSAA | **[PBR, Işıklar ve Gölgeler](Samples/lua/pbr3d/)** örneği |

### Akış, medya ve ağ

| Özellik | API |
|---|---|
| JSON, form, multipart ve dosya gövdeli HTTP; yükleme ilerlemesi, çerezler, yeniden deneme, çevrimdışı önbellek | `net.request(options, callback[, progress])`, `net.cancel` |
| WebSocket istemcisi | `net.ws`, `net.wsSend`, `net.wsPoll`, `net.wsClose` |
| Konsolun tarayıcısıyla oturum açma (PKCE'li OAuth 2.0) | `net.oauth` |
| Disk ve bellek önbellekli web resimleri, küçük resimler | `gfx.imageUrl(url, maxSize)` |
| Uygulama içinde video ve ses oynatıcılar (dosya, MP4, HLS) | `media.open`, `media.draw`, `media.play` ... |
| Sanal listeler ve ızgaralar, çek-yenile, sonsuz kaydırma | `ui.beginFeed`, `ui.feedItem`, `ui.endFeed` |
| Tam ekran kaydırmalı sayfalayıcı | `ui.pager` |
| Kalın, bağlantı, bahsetme ve etiketli zengin metin; 8 dilde "5 dk" tarzı zamanlar | `ui.richText`, `sys.relativeTime` |

<p align="center"><img src="../.github/assets/sample-social-feed.webp" width="90%" alt="Sosyal Akış örneği: karanlık modda fotoğraf akışı, fotoğraf ızgarası ve dikey klip sayfalayıcı"></p>

### SDK 1.10 - 1.12'de ayrıca

- **Native SDK 1.1 (SDK 1.10):** Nexvyn OS içinde pencerede ya da tam ekranda çalışan C / C++ uygulamalar; [Native SDK kiti](Languages/c/native-kit/README.tr.md) ile yapılır (`nxv-native`, app, oyun, port ve SDL2 şablonları) -- [Native SDK rehberi](Guides/NATIVE_GUIDE.tr.md) ile başlayın. Nexvyn OS 1.2.2'den beri native app'ler varsayılan olarak çok daha hızlı çalışır ve sistemde Ayarlar > Performans vardır (resmi en yüksek saatler, isteğe bağlı hız aşırtma); kare ritmi, ses ve ayrılmış hata kodu notları [kit başvurusunda](Guides/NATIVE_KIT.tr.md) ("Performans, kare ritmi ve ayarlar").
- **Kalıcı klasörler ve kayıt yedekleri (SDK 1.11):** `ui.chooseFolder` (klasörü kullanıcı seçer, `remember` tutar), `fs.folderGrants` / `folderGranted` / `revokeFolder`, `fs.savePath`, `fs.saveBackup` / `saveRestore` / `saveBackups` / `saveDeleteBackup`; Lua, JavaScript, Python ve C'de aynı adlar, izin gerekmez.
- **Dil eşitliği (SDK 1.12):** `ui.tokens()` (sistem görünümü tek tablo olarak), `audio.stopAll()` ve C'de `input_action`; native SDK ile aynı adlar, Lua, JavaScript, Python ve C'de.

### SDK 1.9'da ayrıca

- **Runtime kütüphanesi:** Lua'da `net.request`; JavaScript'te `TextEncoder`, `TextDecoder`, `URL`,
  `URLSearchParams`, `structuredClone`; Python'da daha fazla `str` metodu, `urllib.parse`, `html`, `uuid`.
- **Lua, JavaScript, Python ve C'de aynı API.** Squirrel ve Java çalışmaya devam eder, SDK 1.8'de donduruldu.

## Kitler ve araçlar

| | |
|---|---|
| [Ses kiti](Languages/lua/kits/README.tr.md) (`sfx`) | Tariflerden katmanlı ses efektleri ve müzik: varyantlar, bus'lar, ducking, ortam sesi, müzik döngüleri. Rehber: [Ses tasarımı](Guides/SOUND_DESIGN.tr.md) |
| [His kiti](Languages/lua/kits/README.tr.md) (`juice`) | Easing ve tween, sarsıntı, hit-stop, parçacıklar, parlama, başlıklar, paneller, düğmeler, geçişler, 2B ve 3B kameralar, 3B ışık atmosferleri. Rehber: [Grafik, arayüz ve oyun hissi](Guides/GAME_FEEL.tr.md) |
| [İkon aracı](Tools/icon/README.tr.md) | Oyunun kendi modelini çizer ve her boyutta key-art mağaza ikonunu üretir; stil `clean` (varsayılan), `bold` ya da `loud` |
| [Doku aracı](Tools/textures/README.tr.md) | PBR doku setlerini denetler, haritaları küçültür, ORM paketler, MetallicSmoothness ve -Y (yeşil aşağı) normal haritalarını dönüştürür |
| [Tema aracı](Tools/theme/README.tr.md) | Tema paketini (`theme.json`, sınırlar, WCAG AA kontrastı) denetler ve `.nxvtheme` paketler; rehber: [Tema yapımı](Guides/THEMES.tr.md), şablon: `Samples/themes/template` |
| [nxv](Tools/nxv/README.tr.md) | Şablondan yeni proje, denetim, derleme (Java), paketleme, imzalama, kurma, konsola gönderme |

Kitler Lua ve JavaScript için vardır (`Languages/lua/kits`, `Languages/javascript/kits`).

<p align="center"><img src="Tools/icon/examples/ember-field/preview.png" width="32%" alt="İkon aracıyla Ember Field için yapılmış key-art ikon, clean stil"> <img src="Tools/icon/examples/orbit-rush/preview.png" width="32%" alt="İkon aracıyla Orbit Rush için yapılmış key-art ikon"> <img src="Tools/icon/examples/shard/preview.png" width="32%" alt="İkon aracıyla Shard için yapılmış key-art ikon"></p>

## Buradan başlayın

| Dil | 1. Hızlı başlangıç | 2. Şablon | 3. Rehber | 4. Örnekler |
|---|---|---|---|---|
| **Lua 5.4** (önerilen) | [Languages/lua](Languages/lua/README.tr.md) | [şablon](Languages/lua/template/) | [Geliştirici rehberi](Guides/DEVELOPER_GUIDE.tr.md), [oyun motoru](Guides/GAME_ENGINE.tr.md) | [Samples/lua](Samples/lua/) |
| **JavaScript** | [Languages/javascript](Languages/javascript/README.tr.md) | [şablon](Languages/javascript/template/) | [JavaScript ile uygulama](Guides/JS_APPS.tr.md) | [Samples/javascript](Samples/javascript/) |
| **Python** | [Languages/python](Languages/python/README.tr.md) | [şablon](Languages/python/template/) | [Python ile uygulama](Guides/PY_APPS.tr.md) | [Samples/python](Samples/python/) |
| **C** | [Languages/c](Languages/c/README.tr.md) | [şablon](Languages/c/template/) | [C ile uygulama](Guides/C_APPS.tr.md) | [Samples/c](Samples/c/) |
| **C / C++ (native)** | [Languages/c/native-kit](Languages/c/native-kit/README.tr.md) | kitteki şablonlar | [Native SDK rehberi](Guides/NATIVE_GUIDE.tr.md), [kit başvurusu](Guides/NATIVE_KIT.tr.md) | kitin `examples/` klasörü |
| Squirrel (1.8'de donduruldu) | [Languages/squirrel](Languages/squirrel/README.tr.md) | [şablon](Languages/squirrel/template/) | [Squirrel ile uygulama](Guides/SQUIRREL_APPS.tr.md) | [Samples/squirrel](Samples/squirrel/) |
| Java (1.8'de donduruldu) | [Languages/java](Languages/java/README.tr.md) | [şablon](Languages/java/template/) | [Java ile uygulama](Guides/JAVA_APPS.tr.md) | [Samples/java](Samples/java/) |

Emin değilseniz **Lua** ile başlayın: en çok örnek, kitler ve Studio'nun görsel düzenleyicileri onda.

## Tarifler ve rehberler

| İstediğiniz | Okuyun |
|---|---|
| pbr renderer'lı bir 3B oyunu adım adım kurmak | [PBR oyun tarifi](Guides/PBR_GAME_RECIPE.tr.md) (Lua, JavaScript, Python, C) · [Oyun yap](Guides/MAKE_A_GAME.tr.md) |
| Akış, fotoğraf, kısa video ya da sohbet uygulaması yapmak | [Sosyal uygulama tarifi](Guides/SOCIAL_APP_RECIPE.tr.md) · [Sosyal uygulama yap](Guides/MAKE_A_SOCIAL_APP.tr.md) |
| Kod, model ve doku için AI araçlarını kullanmak | [AI destekli çalışma](Guides/AI_WORKFLOW.tr.md) · [SDK/AI](AI/README.tr.md) |
| İyi ses ve his | [Ses tasarımı](Guides/SOUND_DESIGN.tr.md) · [Grafik, arayüz ve oyun hissi](Guides/GAME_FEEL.tr.md) |
| Hangi SDK sürümünde ne olduğunu bilmek | [SDK sürümleri](Guides/SDK_VERSIONS.tr.md) · [Uyumluluk](Guides/COMPATIBILITY.tr.md) |
| Bir fonksiyona bakmak | [SDK başvurusu](Reference/SDK.tr.md) |
| Uygulama Mağazası'nda yayımlamak | [Yayımlama](Publishing/README.tr.md) · [Katkı](../CONTRIBUTING.tr.md) |

Bütün rehberler: [Guides/](Guides/README.tr.md).

## Bir AI asistanıyla

1. Asistana [`AI/system-prompt.tr.md`](AI/system-prompt.tr.md) (ya da `.en.md`) ve dilinizin paketini
   ([`AI/languages/`](AI/languages/)) verin. Sohbet asistanları bunları proje dosyası olarak alır; editörde ya da
   terminalde çalışan kodlama asistanları talimat dosyaları üzerinden deponuzdan okur.
2. [`AI/tasks/`](AI/tasks/) içinden bir görev prompt'uyla isteyin: modelli ve pbr renderer'lı 3B oyun, oyun, sosyal
   uygulama, araç, taşıma, dil, mağaza kaydı, mağaza ikonu.
3. Her yanıtı denetleyin: `python SDK/Tools/nxv/nxv.py check <klasör>`; hataları
   [düzeltme prompt'uyla](AI/tasks/fix-lua-check.tr.md) geri gönderin. Asistanın doğrulaması gerekenler
   [kontrol listesinde](AI/checklist.tr.md).
4. Üretilmiş 3B model ve dokular için [AI destekli çalışma](Guides/AI_WORKFLOW.tr.md) rehberini izleyin: ölçek,
   pivot, doku boyutları, PBR harita paketleme, cam ve ışıma.

## 10 dakikada ilk uygulamanız

**Konsolda (PC gerekmez):**

1. **Nexvyn OS Studio**'yu açın, **Yeni Proje**'yi seçip bir şablon (örneğin *3B: PBR, ışıklar ve gölgeler*) seçin ya
   da **Örnekler**'i açın.
2. Uygulamaya ad verin. Proje `sdmc:/NexvynOS/Applications/` içine kurulur ve düzenleyicide açılır.
3. Kodu değiştirip **Çalıştır**'a basın (Ctrl+R). `print()` çıktısı ve hatalar Studio'nun konsolunda görünür.
4. Hazır olunca **Paketi Dışa Aktar**'ı seçin ya da **Uygulama Mağazası'nda Yayımla**'yı izleyin.

**PC'de:**

1. Bir şablon kopyalayın: `python SDK/Tools/nxv/nxv.py new lua "My App" --author adınız`.
2. `app.json`'da `id`, `name`, `description`, `minSdk` ve `permissions`'ı düzenleyin; kodu yazın.
3. Denetleyin: `python SDK/Tools/nxv/nxv.py check MyApp.nxvapp`.
4. Konsola gönderin: **PC Bağlantısı**'nda FTP sunucusunu başlatın, sonra
   `python SDK/Tools/nxv/nxv.py push MyApp.nxvapp --host <konsol-ip>`.
5. Başlatıcı'yı yeniden açın; uygulama oradadır. Hatalar pencerede satır numarasıyla görünür ve
   `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.

## İçindekiler

| Klasör | İçinde ne var |
|---|---|
| [Reference/](Reference/README.md) | SDK başvurusu (`SDK.en.md`, `SDK.tr.md`), Java SDK kaynakları, C başlığı |
| [Languages/](Languages/README.tr.md) | Her dil için hızlı başlangıç, denetlenmiş şablon ve (Lua, JavaScript) oyun kitleri |
| [Guides/](Guides/README.tr.md) | Tarifler, oyun ve sosyal uygulama rehberleri, dil rehberleri, biçimler, uyumluluk, kullanıcı rehberleri |
| [Samples/](Samples/README.tr.md) | Çalışan örnek projeler; [`samples.json`](samples.json) Studio'nun *Örnekler*'inin okuduğu dosyadır |
| [AI/](AI/README.tr.md) | AI asistanları için context pack'ler, görev prompt'ları ve kontrol listesi |
| [Publishing/](Publishing/README.tr.md) | Uygulama Mağazası'nda yayımlama: akış, inceleme listesi, bildirimler ve kaldırma |
| [Fonts/](Fonts/) | Sistem yazı tipleri (Inter, JetBrains Mono, `Icons.codepoints` ile simge yazı tipi) |
| [Tools/](Tools/README.tr.md) | `nxv`, ikon aracı ve doku aracı |
