# Katkı

[English](CONTRIBUTING.md) · **Türkçe**

Bu depo Nexvyn OS'un Uygulama Mağazası'nı (`Store/`), SDK'sını (`SDK/`) ve sürüm dosyalarını barındırır. Nexvyn OS'un
kendi kaynak kodu burada değildir. Dört yolla katkıda bulunabilirsiniz: bir uygulama yayımlamak, hata bildirmek,
çeviri yapmak ya da SDK'yı ve belgelerini iyileştirmek. Her yerde İngilizce ya da Türkçe yazabilirsiniz.

## 1. Uygulama, oyun, tema ya da yazı tipi yayımlama

Her gönderim bir pull request'tir ve Uygulama Mağazası'nda görünmeden önce bakımcı tarafından incelenir
([CODEOWNERS](.github/CODEOWNERS)).

1. **Yapın:** [SDK](SDK/README.tr.md) ile, bilgisayarınızda ya da konsolda Nexvyn OS Studio'da. Uygulamalar İngilizce
   yazılır; başka diller için `lang/<kod>.json` dosyaları ekleyin (Türkçe zorunlu değildir).
2. **Fork'layın** ve öğenizi kendi klasörüne ekleyin: `Store/Apps/<kategori>/<kısa-ad>/`,
   `Store/Games/<tür>/<kısa-ad>/`, `Store/Themes/<kısa-ad>/` ya da `Store/Fonts/<kısa-ad>/`; içinde `source/` (paket),
   `README.md`, `store.json` ve varsa `screenshots/`. Düzen ve her alan [yayımlama rehberinde](SDK/Publishing/PUBLISHING.tr.md).
3. **Denetleyin:** `python SDK/Tools/nxv/nxv.py check Store/<...>/<kısa-ad>/source` geçmeli. Konsolda (ya da bir
   emülatörde), açık ve karanlık modda, el modunda ve TV'de, dokunmatik ve kumandayla deneyin.
4. **Mağaza sayfası:** oyununuzu ya da uygulamanızı gösteren 256x256 key-art ikon ([ikon aracı](SDK/Tools/icon/README.tr.md)),
   İngilizce arayüzle beş ekran görüntüsü (ya da bir `shots` betiği; görüntüleri bakımcı üretir), `store.json`'da
   İngilizce `subtitle` ve `description`.
5. **Pull request'i** şablonla açın. Yalnızca kendi öğenizin dosyalarını değiştirin.
6. Bakımcı onu [inceleme listesiyle](SDK/Publishing/REVIEW.tr.md) inceler, paketi ve kataloğu üretir ve birleştirir.
   Sonra Uygulama Mağazası'nda Yeni olarak görünür.

Öğenizin güncellemeleri de aynı yoldan gelir: `app.json`'daki `version`'ı artırın ve pull request'te neyin
değiştiğini yazın.

**Kabul edilmez:** zararlı yazılım, izleme ya da gizli veri toplama, kullanıcıya zarar veren reklamlar, yalnızca
yetişkinlere yönelik içerik, yayımlama hakkı olmadan başkalarının eserleri, başka ürün ya da markaları taklit eden
uygulamalar, kodda API anahtarı ya da parola. İçerik kurallarının tamamı [yayımlama rehberinde](SDK/Publishing/PUBLISHING.tr.md).

Göndermeden önce sorular: [gönderim sorusu formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=submission-question.yml).
Kendiniz pull request açamıyorsanız [uygulama gönderim formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=app-submission.yml)
kullanın.

## 2. Hata bildirme

[Hata bildirim formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=bug-report.yml) kullanın. Form
Nexvyn OS, sistem ve Atmosphère sürümlerini, açılış modunu, yeniden üretme adımlarını ve bir şey donduğunda ya da
çöktüğünde `sdmc:/NexvynOS/System/Logs/system.log` günlük dosyasını (yeniden başlattıysanız `system.prev.log`'u da)
ister. Önce günlüklerden kişisel verileri çıkarın.

- Bir Uygulama Mağazası öğesindeki sorun: mağaza sayfasındaki **Bu Uygulamayı Bildir** ya da
  [bildirim formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml).
- SDK'da ya da belgelerde bir hata: [SDK ve belge formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=sdk-docs-bug.yml).
- Bir güvenlik sorunu: asla konu olarak değil; [güvenlik politikasını](SECURITY.tr.md) izleyin.

## 3. Çeviri

Nexvyn OS 8 dilde kullanılabilir. Bir çeviriyi düzeltmek ya da yeni bir dil önermek için
[çeviri formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=translation.yml) kullanın.

## 4. SDK'yı ve belgeleri iyileştirme

`SDK/` altındaki örnekleri, rehberleri ya da SDK araçlarını düzelten pull request'ler memnuniyetle karşılanır. İki dil
sürümünü (`NAME.en.md` ve `NAME.tr.md`) birlikte güncel tutun ya da hangisinin çeviri istediğini pull request'te
yazın. Kod örnekleri yalnızca [SDK başvurusundaki](SDK/Reference/SDK.tr.md) fonksiyonları kullanmalı. Rehberler ve
başvuru Nexvyn OS kaynağından üretilir; kabul edilen değişiklikleri bakımcı oraya taşır.

## Davranış

Saygılı olun ve konuda kalın. Konularda, pull request'lerde ya da mağaza içeriğinde taciz, ayrımcılık ve kişisel
saldırı kabul edilmez. Bakımcı bunlara uymayan katkıları kapatabilir, düzenleyebilir ya da kaldırabilir.
