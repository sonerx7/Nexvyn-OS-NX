# Nexvyn OS PC araçları

[English](README.md) · **Türkçe**

Nexvyn OS için uygulama yapanların bilgisayarda kullanacağı araçlar. İlki hazır: [`nxv`](nxv/README.tr.md) komut satırı.
Aşağıdaki liste, sonraki araçlar için öncelik sırasına konmuş bir öneridir; her birinin neye dayanacağı (Nexvyn OS
kaynak deposundaki `SnxOS/tools/` dosyaları) ve kabaca ne kadar iş olduğu yazılıdır.

## Hazır

### 1. `nxv` komut satırı (v0.1, bu klasörde)

Tek dosyalık Python 3 aracı, ek paket gerektirmez: [nxv/README.md](nxv/README.tr.md).

| Komut | Ne yapar |
|---|---|
| `nxv new <dil> <ad>` | `SDK/Languages/<dil>/template` şablonundan yeni uygulama (`--store` ile Mağaza klasör düzeni) |
| `nxv check <paket>` | `app.json`, dosyalar, ikon, çeviriler, izinler (kullanılan ama bildirilmeyen), `store.json` ve `shots` betiği; `--sdk` ile dilin resmî denetleyicisi de çalışır |
| `nxv build <paket>` | Java: `src/` → `app.jar` (`java_build.py`) |
| `nxv pack <paket>` | `build_store.py` ile aynı, belirlenimci `.nxvapp` (+ `manifest.sha256`); `--sign` ile imza |
| `nxv icon ...` | Yerleşik stilde ikon (`make_icon.py`) |
| `nxv install <paket>` | Ryujinx'in (ya da verilen) SD kart klasörüne kopyala, istersen `autorun.txt` ile aç |
| `nxv push <paket> --host <ip>` | Konsoldaki **Bilgisayara Bağlan** FTP sunucusuna yükle (klasör ya da tek `.nxvapp`) |

## Öneriler (öncelik sırasıyla)

| # | Araç | Ne kazandırır | Dayanacağı | Emek |
|---|---|---|---|---|
| 2 | **`nxv watch` ve `nxv run`** | `watch`: klasördeki değişen dosyaları FTP ile konsola anında gönderir (yalnızca değişenleri), isterse uygulamayı yeniden açar. `run`: Ryujinx'i `NexvynOS.nro` ve `launch <id>` yazan bir `autorun.txt` ile başlatır, uygulamanın günlüğünü (`System/Logs/Apps/<id>.log`) terminale akıtır. | `nxv push` / `install`, `ryu_test.sh`, `ui_smoke.py` (Ryujinx yolu ve autorun) | 2-3 gün |
| 3 | **Mağaza başvuru doğrulayıcısı (CI)** | Çekme isteğinde `Store/` altındaki değişen her öğe için `nxv check --sdk` + dil denetleyicisi + `build_store.py --check` + `catalog_check.py`; sonucu PR'a yorum olarak yazar. İncelemecinin listesinin yarısı otomatik olur. | `nxv check`, `tools/ci/store.yml`, `catalog_check.py` | 1-2 gün |
| 4 | **SDK tip dosyaları** | Lua (LuaLS `---@meta`), JavaScript (`nexvyn.d.ts`), Python (`nexvyn.pyi`), Squirrel (anahtar sözcük listesi) için tam SDK imzaları: her editörde otomatik tamamlama ve tür denetimi. Tek kaynaktan üretilir, SDK değişince yeniden üretilir. | `source/runtimes/nxvrt_api.cpp` fonksiyon tablosu (`gen_java_sdk.py` ve `rt_check.py` zaten okuyor), `py_check.py` SIGS listesi | 2-3 gün |
| 5 | **VS Code eklentisi** | 4'teki tip dosyalarıyla tamamlama, `app.json` / `store.json` için JSON şeması, kod parçacıkları (yeni uygulama, sahne, menü, `net.json`...), denetleyici çıktısını "Sorunlar" paneline satır numarasıyla düşürme, "Konsola gönder" ve "Ryujinx'te çalıştır" komutları. | 2, 4, `nxv check` çıktısı | 1-2 hafta |
| 6 | **Çeviri yardımcısı** | Uygulamadaki `TR()` anahtarlarını çıkarır, `lang/*.json` dosyalarını `en.json` ile karşılaştırır (eksik, fazla, `{0}` uyuşmazlığı, çok uzun metin), çevirmenler için CSV/XLIFF dışa ve içe aktarır; sistemin dil paketlerindeki ortak terimleri (`common.ok`...) önerir. Makine çevirisi yalnızca kullanıcının kendi anahtarıyla ve isteğe bağlı. | `lang_check.py` (`--csv`), `romfs/System/Languages`, `nxv check` çeviri denetimi | 2-3 gün |
| 7 | **İkon ve ekran görüntüsü stüdyosu** | Masaüstü/web arayüzü: Material Icons glif seçici, renk ön ayarları, canlı ikon önizlemesi; `store.json` `shots` betiğini görsel olarak kaydetme (pencere üzerinde tıklayarak `wclick` oranları) ve Ryujinx'te oynatma; temas sayfası. | `make_icon.py`, `Icons.codepoints`, `store_shots.py` | 4-6 gün |
| 8 | **Web SDK simülatörü** | Tarayıcıda hızlı arayüz denemesi: `gfx`/`ui`/`store`/`timer`'ın canvas üzerinde bir uygulaması; JS uygulamaları doğrudan, Lua uygulamaları wasmoon/fengari ile çalışır. Konsolun yerini tutmaz (yazı tipi ölçüleri, performans, `g3d`), ama düzen ve akış için saniyeler içinde geri bildirim verir. | `js_check.mjs` ve `lua_check.py` içindeki sahte SDK'lar | 2-4 hafta |
| 9 | **Tema düzenleyici** | `Store/Themes/<slug>/source/theme.json` (görünüm, vurgu rengi, duvar kâğıdı, ayarlar) için önizlemeli düzenleyici ve `.nxvtheme` paketleyici. | Tema biçimi, `build_store.py` | 3-5 gün |

Öneri: önce 2 ve 3 (günlük iş akışını ve incelemeyi hızlandırır), sonra 4 (5'in ve tüm editörlerin temelidir).
`nxlink` ile gönderim şimdilik yoktur: `nxlink` hbmenu'ye `.nro` gönderir; Nexvyn OS'ta uygulama paketi alan bir
dinleyici olmadığı için FTP (`nxv push`) kullanılır. Böyle bir dinleyici sistem tarafında eklenirse `nxv push --nxlink`
eklenebilir.
