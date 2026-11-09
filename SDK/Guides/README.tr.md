# Rehberler

[English](README.md) · **Türkçe**

Her rehber İngilizce (`NAME.en.md`) ve Türkçe (`NAME.tr.md`) vardır. API'nin tamamı
[SDK başvurusundadır](../Reference/SDK.tr.md); orada olmayan fonksiyon yoktur.

## SDK 1.9 ile başlayın

| Rehber | Konusu |
|---|---|
| [PBR oyun tarifi](PBR_GAME_RECIPE.tr.md) | pbr renderer üzerinde adım adım eksiksiz küçük bir 3B oyun (materyal, ışık, gölge, bloom, instancing, yüklenen model), Lua ve JavaScript'te, Python ve C sürümleriyle |
| [Sosyal uygulama tarifi](SOCIAL_APP_RECIPE.tr.md) | Adım adım eksiksiz bir akış uygulaması (çevrimdışı önbellekli ağ, web resimleri, sanal akış, zengin metin, klip oynatıcı), Lua ve JavaScript'te, Python ve C sürümleriyle |
| [AI destekli çalışma](AI_WORKFLOW.tr.md) | AI ile üretilmiş kod, model ve dokulardan konsola hazır oyuna: context pack'ler, ölçek, pivot, LOD, doku boyutları, ORM ve MetallicSmoothness haritaları, normal haritaları, cam ve ışıma, yansımalar, haklar |
| [SDK sürümleri](SDK_VERSIONS.tr.md) | 1.0'dan 1.11'e her SDK sürümünün ekledikleri, hangi Nexvyn OS'la geldiği, hangi dillerin yeni API aldığı, `minSdk` ve `targetSdk` seçimi |
| [Oyun yap](MAKE_A_GAME.tr.md) | Eksiksiz oyun tarifi: proje, 3B modeller (`.glb` / `.fbx`), yükleme, girdi, çarpışma, konsolda hız, pbr renderer bütçesi, sanat yönü, mağaza ikonu, yayımlama |
| [Sosyal uygulama yap](MAKE_A_SOCIAL_APP.tr.md) | Akış, fotoğraf, kısa video ve sohbet uygulamaları: önbellekli ve yeniden denemeli istekler, yükleme, WebSocket, oturum açma, web resimleri, video oynatıcılar, akış ve sayfalayıcılar |
| [Ses tasarımı](SOUND_DESIGN.tr.md) | Ses kiti: katmanlı tarifler, varyantlar, bus'lar, ducking, ortam sesi, müzik döngüleri, seviyeler |
| [Giriş ve oyun modları](INPUT_AND_PLAY_MODES.tr.md) | Nexvyn'e uyum: dokunma, kumanda (Joy-Con çifti ya da tek), portatif ve dock, pencere ve tam ekran, ses, sistem gezinmesi, performans ve kontrol listesi |
| [Grafik, arayüz ve oyun hissi](GAME_FEEL.tr.md) | His kiti: hareket, darbe, ışık, yazı, arayüz biçimleri, kameralar, 3B atmosferler ve mağaza kalite çıtası |

## Diller

| Rehber | Konusu |
|---|---|
| [Geliştirici rehberi](DEVELOPER_GUIDE.tr.md) | Studio ve şablonlar, `app.json`, dil seçimi, 2B ve 3B, paketleme, test |
| [JavaScript ile uygulama](JS_APPS.tr.md) | Lua'dan farklar, Promise'ler, sınırlar, denetim |
| [Python ile uygulama](PY_APPS.tr.md) | Hafif runtime ve CPython 3.12, yorumlayıcı sınırları, sistem kütüphanesi |
| [C ile uygulama](C_APPS.tr.md) | Konsolda derlenen C, `nexvyn.h`, bellek ve güvenlik kuralları |
| [Squirrel ile uygulama](SQUIRREL_APPS.tr.md) | Squirrel uygulamaları (SDK 1.8'de donduruldu) |
| [Java ile uygulama](JAVA_APPS.tr.md) | Java uygulamaları ve PC'de derleme (SDK 1.8'de donduruldu) |
| [Lua ile neler yapılabilir](LUA_CAPABILITIES.tr.md) | Lua ile gerçekçi olarak neler yapılır, sınırlar nerede |
| [Dil desteği](LANGUAGE_SUPPORT.tr.md) | Neden bu runtime'lar ve yeni API politikası |

## Biçimler, motor ve sistem

| Rehber | Konusu |
|---|---|
| [Paket biçimi](NXVAPP_FORMAT.tr.md) | `.nxvapp`, `.nxvtheme`, `.nxvfont`: `app.json` alanları, runtime'lar, izinler, `manifest.sha256`, imzalama |
| [Uyumluluk](COMPATIBILITY.tr.md) | Uyumluluk sözleşmesi: hiçbir şey kaldırılmaz, `targetSdk`'ya bağlı değişiklikler, dondurulan runtime'lar, sürüm denetimleri |
| [App Guard](APP_GUARD.tr.md) | Paketlerin kurulmadan önce nasıl tarandığı ve bir uygulamayı neyin *İncele* ya da *Tehlikeli* yaptığı |
| [Oyun motoru](GAME_ENGINE.tr.md) | `nexvyn.game` 2B motoru: sahneler, sprite'lar, haritalar, kamera, fizik, parçacıklar, tween'ler |
| [Oyun Motoru projeleri](GAME_ENGINE_PROJECTS.tr.md) | Oyun Motoru uygulaması: az kodla ya da kodsuz oyunlar, Hızlı Oyun, proje biçimi |
| [Native SDK rehberi](NATIVE_GUIDE.tr.md) | Nexvyn OS içinde C / C++ uygulamalar: kurulum, new, build, package, crash raporu (Native SDK 1.1) |
| [Native SDK kiti](NATIVE_KIT.tr.md) | Kitin her `nxv-native` komutu, başlığı ve CMake fonksiyonu |
| [Native uyumluluk katmanı](NATIVE_COMPAT.tr.md) | Port'ların değişmeden çalışmasını sağlayan POSIX / libc katmanı ve sınırları |
| [Native modüller](NATIVE_MODULES.tr.md) | İsteğe bağlı yerleşik uygulamaların App Market'ten nasıl kurulduğu (iç mekanizma, SDK değil) |
| [C++ ile yerleşik uygulama](APP_GUIDE.tr.md) | Sistemin kendi uygulamalarının nasıl yazıldığı |

## Kullanıcılar için

| Rehber | Konusu |
|---|---|
| [Kullanım rehberi](USER_GUIDE.tr.md) | Kurulum, masaüstü, kısayollar, uygulamalar, App Market, PC'ye Bağlan |
| [Forwarder](FORWARDER.tr.md) | HOME menüsünde Nexvyn OS'u açan bir simge |
| [Tarayıcı](BROWSER.tr.md) | Dahili tarayıcı ve tam tarayıcı |
| [Türkçe yamalar](TURKISH_PATCHES.tr.md) | Türkçe Yamalar uygulaması |

Nereden başlamalı: [SDK başlangıç sayfası](../README.tr.md), sonra [dilinizin hızlı başlangıcı](../Languages/README.tr.md),
sonra [PBR oyun tarifi](PBR_GAME_RECIPE.tr.md) ya da [sosyal uygulama tarifi](SOCIAL_APP_RECIPE.tr.md).
