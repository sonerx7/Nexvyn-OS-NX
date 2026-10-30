# Depo araçları

[English](README.md) · **Türkçe**

Bu deponun bakımı: Uygulama Mağazası kataloğunu üretmek ve denetlemek. Uygulama yapanlar için araçlar (`nxv` komut
satırı) [SDK/Tools](../SDK/Tools/README.tr.md) içindedir.

| Yol | Ne yapar |
|---|---|
| [`build_store.py`](build_store.py) | `Store/` altındaki her öğeyi (`.nxvapp`, `.nxvtheme`, `.nxvfont`; belirlenimci, `manifest.sha256` ile) ve `SDK/Samples/` altındaki her örneği (`.zip`) paketler; `Store/catalog.json`, `SDK/samples.json`, `Store/dates.json` (kimlik başına ilk yayın, son değişiklik ve sürüm geçmişi) ve listeleri (`Store/README.md` ve her kategori klasörü için bir README) yazar. Kimliği bozuk, simgesi ya da lisansı eksik veya `app.json`'da bildirilmeyen bir izni kullanan öğeleri geri çevirir. `--check` hiçbir şeyi değiştirmez, bir şey güncel değilse 1 ile çıkar (CI). |
| [`ci/store.yml`](ci/store.yml) | Pull request'ler için GitHub Actions iş akışı: `build_store.py --check`, ardından değişen öğelerde kaynak deposunun `catalog_check.py` ve dil denetleyicileri. |

## Ne nerede

| Yol | İçerik | Kim yapar |
|---|---|---|
| `Store/Apps/<kategori>/<kısa-ad>/`, `Store/Games/<tür>/<kısa-ad>/` | uygulamalar ve oyunlar: `source/`, `store.json`, `README.md`, `screenshots/` | geliştiriciler (pull request) |
| aynısı, `app.json` olup `source/` olmadan | Nexvyn OS ile gelen uygulamaların mağaza sayfaları | Nexvyn OS projesi |
| `Store/Themes/<kısa-ad>/`, `Store/Fonts/<kısa-ad>/` | temalar, yazı tipi paketleri | geliştiriciler; resmî temalar için `Store/Themes/tools/gen_themes.py` |
| `Store/catalog.json`, `*.nxvapp`, `*.nxvtheme`, `*.nxvfont`, listeler | konsolun indirdikleri | `build_store.py` |
| `Store/packages.json` | homebrew paket kataloğu | kaynak deposunun `tools/release.py` aracı |
| `SDK/Reference/`, `SDK/Guides/`, `SDK/Fonts/` | SDK başvurusu, rehberler, sistem yazı tipleri | `tools/release.py` (kaynak deposundan kopyalanır) |
| `SDK/Languages/`, `SDK/Samples/`, `SDK/AI/`, `SDK/Publishing/` | şablonlar, örnekler, istemler, yayımlama rehberi | burada düzenlenir |
| `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md` | sürüm notları ve lisanslar | `tools/release.py` |

Belge sitesi buradan değil, kaynak deposundan (`site/`) üretilir.

## Denetimleri GitHub'da açmak

1. `Tools/ci/store.yml` dosyasını GitHub web arayüzünde `.github/workflows/store.yml` olarak kopyalayın (**Add file >
   Create new file**, içeriği yapıştırın). İş akışı dosyalarını bir klondan push etmek `workflow` yetkili bir token ister.
2. İsteğe bağlı, kaynak deposu özelken: `sonerx7/Nexvyn-OS-NX-Source` için salt okunur, ayrıntılı (fine-grained) bir
   token oluşturup `SOURCE_REPO_TOKEN` adlı depo gizlisi olarak ekleyin; böylece dil denetleyicileri de çalışır.
3. `main` için **Settings > Branches > Add rule**: pull request zorunlu, **Require review from Code Owners**
   (`.github/CODEOWNERS`) ve `store` durum denetimi. Böylece `Store/` ya da `SDK/` altına onaysız hiçbir şey girmez.
