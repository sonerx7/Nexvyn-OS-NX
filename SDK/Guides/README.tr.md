# Rehberler

[English](README.md) · **Türkçe**

Nexvyn OS'un kullanım ve geliştirici rehberleri. Çoğu Türkçedir; İngilizce olanlar ve İngilizce özeti bulunanlar
tabloda belirtilmiştir. Tam API başvurusu her zaman [SDK/Reference/SDK.tr.md](../Reference/SDK.tr.md) belgesidir.

## Uygulama geliştirme

| Belge | Konu | Dil |
|---|---|---|
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.tr.md) | Geliştiricinin ana rehberi: Studio ve şablonlar, `app.json`, dil seçimi, 2D oyun, 3D, paketleme, topluluk kataloğu, Overlay, Ryujinx'te test (`autorun.txt`), yerleşik (C++) uygulamalar | TR, İngilizce özet |
| [NXVAPP_FORMAT.md](NXVAPP_FORMAT.tr.md) | `.nxvapp` v2 paket biçimi: `app.json` alanları, çalışma ortamları, izinler, `manifest.sha256`, imza (`manifest.sig`), kurulum, katalog biçimi, paketleme | TR, İngilizce özet |
| [JS_APPS.md](JS_APPS.tr.md) | JavaScript uygulamaları: Lua'dan farklar, Promise'ler, sınırlar, denetim | TR |
| [PY_APPS.md](PY_APPS.tr.md) | Python (pocketpy) uygulamaları: farklar, yorumlayıcı kısıtları, sistem kütüphanesi | TR |
| [SQUIRREL_APPS.md](SQUIRREL_APPS.tr.md) | Squirrel uygulamaları | TR |
| [C_APPS.md](C_APPS.tr.md) | Konsolda TinyCC ile derlenen C uygulamaları | TR |
| [JAVA_APPS.md](JAVA_APPS.tr.md) | miniJVM üzerinde Java uygulamaları ve PC'de derleme | TR |
| [LANGUAGE_SUPPORT.md](LANGUAGE_SUPPORT.tr.md) | Yeni diller için araştırma ve kararlar: neden Squirrel, TinyCC ve miniJVM, neden CPython değil | TR |
| [LUA_CAPABILITIES.md](LUA_CAPABILITIES.tr.md) | Lua ile gerçekçi olarak neler yapılabilir, sınırlar nerede | TR |
| [GAME_ENGINE.md](GAME_ENGINE.tr.md) | `nexvyn.game` 2D oyun motoru eğitimi: sahneler, sprite, harita, kamera, fizik, parçacık, tween | TR |
| [GAME_ENGINE_PROJECTS.md](GAME_ENGINE_PROJECTS.tr.md) | Oyun Motoru uygulaması (eski adıyla Oyun Atölyesi): kodsuz / az kodlu 2D ve 3D oyun yapımı, proje biçimi | TR |
| [APP_GUIDE.md](APP_GUIDE.tr.md) | Yerleşik C++ uygulaması yazma (Nexvyn OS kaynak deposuna katkı için) | EN |

## Kullanım ve sistem

| Belge | Konu | Dil |
|---|---|---|
| [USER_GUIDE.md](USER_GUIDE.tr.md) | Kullanıcı rehberi: kurulum, masaüstü, kısayollar, uygulamalar, Mağaza, Bilgisayara Bağlan (FTP) | TR |
| [FORWARDER.md](FORWARDER.tr.md) | Nexvyn OS'u ana menüden açan forwarder | TR + EN |
| [BROWSER.md](BROWSER.tr.md) | Tarayıcı: motor araştırması ve seçilen yol | TR |
| [TURKISH_PATCHES.md](TURKISH_PATCHES.tr.md) | Türkçe Yamalar uygulamasının araştırması ve tasarımı | TR |
| [NATIVE_MODULES.md](NATIVE_MODULES.tr.md) | Yerel modüller (`.nxvmod`): Nexvyn OS'un isteğe bağlı C++ uygulamalarının App Market'ten kurulması (iç mekanizma, SDK değil) | TR |

Nereden başlamalı: önce [../README.md](../README.tr.md) (SDK başlangıç sayfası), sonra seçtiğiniz dilin
[Languages](../Languages/README.tr.md) rehberi, ardından ayrıntı için yukarıdaki dil belgesi ve
[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.tr.md).
