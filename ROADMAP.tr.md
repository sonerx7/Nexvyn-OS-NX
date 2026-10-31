# Nexvyn OS yol haritası

[English](ROADMAP.md) · **Türkçe**

Nexvyn OS 1.0, 30 Ekim 2026'da çıktı. Bu sayfa bundan sonra nereye gittiğini anlatıyor: hedeflerimizi, onları hangi
sayılarla ölçeceğimizi ve nasıl yardım edebileceğinizi. Tarihler hedeftir, kayabilir. Sayılar ise sessizce
yumuşatılmaz: bir hedef gecikirse bu sayfa bunu ve nedenini yazar.

## Vizyon

**Elinizde tutabileceğiniz en iyi masaüstü.** Nintendo Switch'te, kumandayla ya da parmaklarınızla fare kadar doğal
kullanılan, uygulama ve oyunu konsolun kendisinde yapmanıza izin veren, işinizi ve güveninizi hiçbir zaman kaybetmeyen
eksiksiz bir masaüstü.

## İlkeler

1. **Önce konsol.** Kumanda ve dokunmatik ekran birinci sınıftır, sonradan eklenmiş değildir. Her özellik el modunda
   720p'de ve TV'de 1080p'de çalışmalı, her pencere işlemine kumandayla ulaşılabilmelidir.
2. **İşiniz güvende.** Belgeler kendiliğinden kaydedilir, çöken bir uygulama yalnızca kendi penceresini kapatır, bir
   sorun olduğunda Güvenli Mod vardır ve bir güncelleme her zaman geri alınabilir.
3. **Gizlilik.** Hiçbir yerde hesap gerekmez. Uygulamalar ihtiyaç duyduklarını bir kez sorar, Uygulama Mağazası her
   permission'ı yüklemeden önce listeler. Kullanım istatistikleri Nexvyn OS ilk açıldığında duyurulur, Ayarlar'da
   listelenir ve kapatılabilir; dosyalarınızı, parolalarınızı ya da anahtarlarınızı asla içermez ve konsol geriye hiçbir
   komut almaz. Bkz. [App Guard](SDK/Guides/APP_GUARD.tr.md).
4. **Uyumluluk sözü.** SDK fonksiyonları asla silinmez, davranış değişiklikleri yalnızca yeni SDK'yı hedefleyen
   uygulamalara uygulanır ve her release Uygulama Mağazası'ndaki her uygulamaya karşı test edilir. Bkz.
   [Uygulama uyumluluğu](SDK/Guides/COMPATIBILITY.tr.md).
5. **Açık bir Uygulama Mağazası.** Herkes uygulama, oyun, tema ya da yazı tipi gönderebilir. Her öğe yayımlanmadan önce
   incelenir, paketler denetlenir; hesap da ücret de yoktur. Bkz. [Yayımlama](SDK/Publishing/PUBLISHING.tr.md).
6. **İddia değil, ölçüm.** Aşağıdaki her hedefin bir sayısı, bir cihazı ve bir ölçüm yolu var. Ölçümler her release ile
   yayımlanır.

## Bugün neredeyiz: 1.0

- 79 yerleşik uygulama ve Uygulama Mağazası'nda 168 öğe (uygulama, oyun, tema ve yazı tipi paketi).
- Altı programlama dilinde tek bir SDK; konsolda Nexvyn OS Studio ve Oyun Motoru.
- Her biri %100 çevrilmiş 8 arayüz dili.
- Gerçek, üst üste binen pencereler, iki masaüstü düzeni, Hızlı Arama, kendi motoruyla bir tarayıcı, medya, ofis
  uygulamaları ve Switch Araçları.

## Nasıl ölçüyoruz

İki konsolda: bir ilk model Nintendo Switch ve bir OLED model; başlık modunda açılmış, 64 GB A1 microSD kartlı ve
yaklaşık 5.000 dosyalık bir profille. Applet modundaki (Albüm'den açılan, belleği daha az olan) sonuçlar ayrıca
yayımlanır. Nexvyn OS açılış aşamalarını, kare hızını ve sürelerini kendi günlüğüne yazar; böylece herkes bir ölçümü
kendi konsolunda tekrarlayabilir.

## Release hedefleri

### 1.1: Ölçülmüş ve güvenli (hedef: Aralık 2026)

| Hedef | Ölçüt |
|---|---|
| Ölçümler | İki konsol için açılış, uygulama açılışı, sürükleme, arama, bellek ve pil sayıları yayımlanır |
| Soğuk açılış | Homebrew menüsünden yanıt veren bir masaüstüne **4 saniyenin altında** |
| Uygulama açılışı | Yerleşik uygulamalar **300 ms'nin altında** açılır (medyan) |
| Hızlı Arama | 15.000 dosyayla, her tuşta sonuçlar **50 ms'nin altında** |
| Akıcı pencereler | El modunda dört pencere açıkken pencere sürükleme **60 fps** |
| İş kaybı yok | İçeriğinizi düzenleyen her yerleşik uygulama kendini kaydeder; elektrik kesilirse en fazla **son 10 saniyelik** değişiklik kaybolur |
| Ekran Okuyucu | **8 arayüz dilinin hepsinde** konuşur; masaüstündeki ve en çok kullanılan 20 uygulamadaki denetimlerin **%90'ı** etiketli |
| Tarayıcı | `position: absolute` ve `fixed`; konsolda **70 otomatik testten 63'ü** geçer; üzerinde test edilecek 40 günlük sitenin listesi yayımlanır |
| Güvenli güncelleme | Yeni bir sürüm iki kez açılamazsa Nexvyn OS bir öncekine dönmeyi önerir |
| Kararlılık | Oturumların **%98'i** çökmeden biter; hâlâ "konsolda doğrulanmadı" diye işaretli her özellik doğrulanır ya da deneysel olarak etiketlenir |
| Gizlilik | Kullanım istatistiklerinde ad ya da hesap bilgisi yok; Ayarlar gönderilen her alanı listeler |
| Uygulama Mağazası | **190 öğe**, dış geliştiricilerden **ilk 5 öğe**, her gönderi 7 gün içinde incelenir |

### 1.2: Üretken (hedef: 2027 başı)

| Hedef | Ölçüt |
|---|---|
| Hız | Soğuk açılış **3 saniyenin altında**; uykudan dönüp hazır olma **1 saniyenin altında** |
| Akıcı pencereler | **TV'de 1080p'de 60 fps** pencere sürükleme |
| Belgelerin içinde arama | Hızlı Arama notlarınızın ve belgelerinizin (2.000'e kadar) içindeki metni **100 ms'nin altında** bulur |
| Erişilebilirlik | Ekran Okuyucu yerleşik uygulamalardaki denetimlerin **%100'ünü** kapsar; her yerleşik uygulama yalnızca yön tuşlarıyla kullanılabilir |
| Diller | **12 arayüz dili** (İtalyanca, Portekizce (Brezilya), Rusça ve Lehçe eklenir) ve onlara uygun klavye düzenleri |
| Tarayıcı | **120 testten 108'i** geçer; web yazı tipleri, hover stilleri ve WebSocket; 40 sitenin 20'si yerleşik tarayıcıdan çıkmadan çalışır |
| Ofis ve dosyalar | Sunum dosyalarını açma, belge, hesap tablosu ve sunumları PDF olarak dışa aktarma; Dosyalar'da ağ klasörleri (SMB ve WebDAV) |
| Konsolda üretmek | Nexvyn OS Studio'da Lua için debugger; konsoldan doğrudan Uygulama Mağazası'na yayımlama |
| Eve dönüş | İsteğe bağlı: Nexvyn OS'u Homebrew menüsü olarak kullanmak; başka bir homebrew programı kapanınca Nexvyn OS'a dönülür |
| Medya | Donanımla video çözme varsayılan olarak açık; her video için resim içinde resim |
| SDK 1.7 | Uygulama Mağazası uygulamalarından masaüstü widget'ları; her mağaza sayfasında gizlilik etiketleri |
| Uygulama Mağazası | **240 öğe, 25'i dış geliştiricilerden**, inceleme **72 saat** içinde |
| Kararlılık | Oturumların **%99'u** çökmeden biter |

### 2.0: Konsolun masaüstü (hedef: 2027'nin ilerleyen aylarında)

| Hedef | Ölçüt |
|---|---|
| Hız | Soğuk açılış **2,5 saniyenin altında**; yerleşik uygulamalar **200 ms'nin altında** açılır |
| Akıcı pencereler | **Sekiz pencere açıkken 1080p'de 60 fps** |
| Arama | Oyunlarınız, ekran görüntüleriniz, kayıtlarınız ve modlarınız dahil 50.000 öğe 50 ms'nin altında |
| Diller | **16 arayüz dili** |
| Erişilebilirlik | Tek bir anahtar ya da düğme kullananlar için tek düğmeyle tarama |
| Tarayıcı | **160 testten 150'si** geçer; web sayfalarında video ve ses; 40 sitenin 30'u yerleşik tarayıcıdan çıkmadan çalışır |
| Belgeler | Sürüm geçmişi: her belgenin son 20 sürümü, tek adımda geri yüklenir |
| Uygulama Mağazası | **300'den fazla öğe, 75'ten fazla dış geliştirici**, Oyun Motoru ile yapılmış 25'ten fazla oyun |
| Konsolda üretmek | JavaScript ve Python'da da debugger; Studio'da basit bir Git istemcisi |
| Kapalıyken | Nexvyn OS kapalıyken alarmlar, anımsatıcılar ve dosya aktarımı (deneysel) |
| Yardımcı sayfa | Aynı ağdaki bir telefonun ya da bilgisayarın tarayıcısından konsola dosya, metin ve bağlantı gönderme; hiçbir şey yüklemeden |
| Güncellemeler | Yalnızca değişeni indiren daha küçük güncellemeler |
| Kararlılık | Oturumların **%99,5'i** çökmeden biter |

Yeni Switch modellerine destek homebrew topluluğuna bağlıdır ve bir söz değildir.

## Nexvyn OS'u farklı kılan

- **Elinizdeki bir konsol.** Dock'a takıldığını ve çıkarıldığını bilir, ikisi için ayrı düzen tutar; pili, hareket
  sensörlerini, titreşimi ve IR kamerayı kullanır.
- **Önce kumanda ve dokunmatik.** Tamamen kumandayla ya da parmaklarınızla yönetebileceğiniz bir masaüstü.
- **Uygulamayı cihazda yapın.** Bilgisayar olmadan bir uygulamayı yazın, çalıştırın, düzeltin ve yayımlayın.
- **Oyun yapın.** Oyun Motoru, çocuklar dahil herkese birkaç adımda oynanabilir bir oyun verir.
- **Switch'iniz için araçlar.** Oyun kitaplığınız, modlar, hileler, saat profilleri, katmanlar ve kayıt yedekleri tek
  yerde.

## Nasıl yardım edebilirsiniz

- **Uygulama, oyun, tema ya da yazı tipi yayımlayın.** [SDK](SDK/README.tr.md) ile başlayın ve
  [yayımlama rehberini](SDK/Publishing/PUBLISHING.tr.md) izleyin. Sorular için
  [gönderim sorusu formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=submission-question.yml).
- **Hata bildirin.** [Hata bildirim formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=bug-report.yml)
  kullanın. Hatanın konsolda mı emülatörde mi olduğunu yazın, varsa `System/Logs/Crashes` içindeki çökme raporunu
  ekleyin. Gerçek konsoldan gelen bildirimler özellikle değerli: "doğrulanmadı" maddeleri bu sayede doğrulanıyor.
- **Çeviri yapın.** Yeni bir dil SD karttan hemen denenebilir ([nasıl](SDK/Guides/USER_GUIDE.tr.md#yeni-dil-eklemek)).
  Yeni bir dil ya da bir düzeltme için [çeviri formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=translation.yml)
  kullanın.
- **Bir fikir önerin:** [fikir formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=idea.yml).
- **Kurallara uymayan bir uygulamayı bildirin:**
  [bildirim formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml) ya da mağaza
  sayfasındaki **Bu Uygulamayı Bildir**.
- **SDK ve belgelerdeki hatalar** için
  [SDK ve belge formu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=sdk-docs-bug.yml).

## İlerleme nasıl izleniyor

- Her release'in bir GitHub milestone'u var: [milestone'lar](https://github.com/sonerx7/Nexvyn-OS-NX/milestones) (1.1,
  1.2, 2.0).
- Yol haritası işleri [`roadmap` label'ını](https://github.com/sonerx7/Nexvyn-OS-NX/issues?q=label%3Aroadmap) taşır.
- Her release'te bu sayfa ve [sürüm notları](CHANGELOG.md) ölçülen sayıları hedeflerin yanında gösterir.
- Sonraki bir release'e kayan hedef, nedeniyle birlikte burada işaretlenir.
