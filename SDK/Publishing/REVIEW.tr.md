# İnceleme listesi

[English](REVIEW.en.md) · **Türkçe**

Bakımcının, `Store/` altına öğe ekleyen ya da bir öğeyi güncelleyen bir pull request'i onaylamadan önce denetledikleri.
Geçerli olan her satır işaretlenmeden hiçbir şey birleştirilmez (= yayımlanmaz). Gönderenler: önce kendiniz geçin;
[yayımlama rehberi](PUBLISHING.tr.md) her maddeyi açıklar.

Kararlar: **onayla ve birleştir**, **değişiklik iste** (geçmeyen satırlarla) ya da **kapat** (kuralların hiç izin
vermediği öğelerde gerekçesiyle).

## 1. Otomatik denetimler (CI)

- [ ] `python Tools/build_store.py --check` geçiyor (bakımcının `build_store.py` çalıştırmasından sonra)
- [ ] `tools/catalog_check.py Store/catalog.json --strict` hatasız
- [ ] Dil denetleyicisi geçiyor: `lua_check.py` · `js_check.mjs` · `py_check.py` · `rt_check.py`
- [ ] `nxv check <klasör> --sdk <kaynak deposu>` temiz
- [ ] Pull request yalnızca öğenin klasörüne dokunuyor (gönderen `build_store.py` çalıştırdıysa üretilen dosyalar da)

## 2. Kimlik ve sürümler

- [ ] `id` benzersiz, ters alan adı biçiminde ve güncellemede değişmemiş
- [ ] Güncellemede `version` yayımlanandan büyük; README'deki sürüm tablosunda yeni satır var
- [ ] `minSdk` kullanılan en yeni SDK özelliğine uyuyor
- [ ] Klasör doğru yerde: `Store/Apps/<kategori>/`, `Store/Games/<tür>/`, `Store/Themes/`, `Store/Fonts/`

## 3. Güvenlik ve gizlilik

- [ ] Kötü amaçlı yazılım, karartılmış kod ya da çalışırken indirilip yürütülen kod yok (indirilen metnin `load` ile
      çalıştırılması ...)
- [ ] Kullanıcının istemediği izleme, analiz ya da veri toplama yok; kişisel veri, API anahtarı ya da parola
      toplanmıyor ve gönderilmiyor; ağ kullanımı açıklamaya uyuyor
- [ ] Deneyimi bozan reklam yok (tam ekran, aldatıcı, dolandırıcılık, kumar, yetişkin)
- [ ] Her izin kullanılıyor ve pull request'te açıklanmış; bildirilmemiş kullanım yok (build_store.py zorlar)
- [ ] C ve Java: README neden yerel kod / Java gerektiğini söylüyor; sistem dosyalarına, başka uygulamaların verisine
      ya da konsolun ayarlarına dokunan kod yok
- [ ] Ağ: çevrimdışıyken dostça mesaj; kaynakta gömülü gizli bilgi yok

## 4. Haklar ve lisanslar

- [ ] Gönderen öğenin sahibi ya da onu yayımlamaya izin veren bir lisansa sahip
- [ ] Her üçüncü taraf parça (kod, görsel, ses, müzik, yazı tipi, veri) README'de yapanı, kaynağı ve lisansıyla
      YamaNX notlarındaki gibi listelenmiş; lisanslar yeniden dağıtıma izin veriyor
- [ ] Marka ya da adlar resmî bir ürünmüş gibi kullanılmıyor
- [ ] Yazı tipi paketleri: `LICENSE` var ve yeniden dağıtılabilir (OFL, Apache 2.0 ...); `font.json` `license` uyuyor

## 5. İçerik

- [ ] Herkese uygun ya da hafif şiddet veya korkutucu temalar için `store.json`'da `"age": "teen"` var; yalnızca
      yetişkinlere yönelik, nefret içeren ya da korsan dahil yasa dışı bir şeyi özendiren içerik yok
- [ ] Açıklama dürüst: söylediğini yapıyor, ekran görüntüleri bu öğeye ait
- [ ] Var olan bir öğenin kopyası değil

## 6. Kalite

- [ ] Konsolda ya da Ryujinx'te kurulup açılıyor; birkaç dakikalık kullanımda çökmüyor
- [ ] Açık ve koyu modda okunuyor; en küçük pencere boyutunda, el modunda ve TV'de taşma yok
- [ ] Dokunmatik, imleç ve (oyunlarda) kumandayla kullanılabiliyor; hedefler en az 28 px
- [ ] Akıcı: `app.draw` içinde ağır iş yok, hiçbir geri çağırma 3 saniyeye yaklaşmıyor
- [ ] Veriler hemen kaydediliyor, `suspend` / `autosave` sonrası kaybolmuyor
- [ ] Ekrandaki her metin `TR()` ile; `lang/en.json` tam (Türkçe şiddetle önerilir)

## 7. Mağaza kaydı

- [ ] `store.json`: en az İngilizce `subtitle` (≤ 45 karakter) ve `description`; `kind`, `tags`; `shots` geçerli
- [ ] `icon.png` kare 128 ya da 256 px; kişisel veri içermeyen 3-4 ekran görüntüsü
- [ ] `README.md` İngilizce ve Türkçe
- [ ] Güncellemede bir `changelog` (Yenilikler) var

## 8. Birleştirdikten sonra

- [ ] `python Tools/build_store.py` çalıştırıldı ve commit edildi (katalog, paketler, listeler, `dates.json` geçmişi)
- [ ] Öğe yenilemeden sonra Uygulama Mağazası'nda (Keşfet > Yeni) görünüyor
- [ ] Kaldırmada: klasör silindi (ya da önceki sürüm geri getirildi), bildirim issue'su cevaplanıp kapatıldı
