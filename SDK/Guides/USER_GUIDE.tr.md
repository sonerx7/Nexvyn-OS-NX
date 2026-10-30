# Nexvyn OS kullanım rehberi

**Türkçe** · [English](USER_GUIDE.en.md)

Bu rehber, Nexvyn OS'u konsoluna kuran ve günlük olarak kullanan kişi içindir. Uygulama yazmak istiyorsanız
[DEVELOPER_GUIDE.tr.md](DEVELOPER_GUIDE.tr.md) belgesine bakın.

Nexvyn OS, Nintendo Switch için bir homebrew masaüstü kabuğudur (`NexvynOS.nro`). Konsolun kendi sistemini değiştirmez:
Homebrew menüsünden açılır, kapatınca Homebrew menüsüne dönülür. Arayüz Türkçe ve İngilizcedir; yeni dil eklenebilir.

## İçindekiler

1. [Kurulum ve başlatma](#1-kurulum-ve-başlatma)
2. [Kurulum yardımcısı](#2-kurulum-yardımcısı)
3. [İki masaüstü düzeni](#3-iki-masaüstü-düzeni)
4. [Pencereler](#4-pencereler)
5. [Girdi: dokunmatik, kumanda, klavye](#5-girdi-dokunmatik-kumanda-klavye)
6. [Masaüstü, klasörler ve kısayollar](#6-masaüstü-klasörler-ve-kısayollar)
7. [Dosyalar, USB bellek ve bilgisayar bağlantısı](#7-dosyalar-usb-bellek-ve-bilgisayar-bağlantısı)
8. [Sistem Ayarları](#8-sistem-ayarları)
9. [Yerleşik uygulamalar](#9-yerleşik-uygulamalar)
10. [Sorun giderme ve SSS](#10-sorun-giderme-ve-sss)

---

## 1. Kurulum ve başlatma

### Gerekenler

- Atmosphère ile açılan bir Switch. Güncel bir Atmosphère sürümü ve emuMMC önerilir.
- SD kartta biraz boş yer. Video, PC oyunları ve Retro oyunları için daha fazlası gerekir.

### Kurulum

1. `NexvynOS.nro` dosyasını SD kartta `sdmc:/switch/NexvynOS.nro` konumuna kopyalayın.
2. Homebrew menüsünü açın ve **Nexvyn OS**'u seçin.
3. İlk açılışta kurulum yardımcısı başlar (bkz. [bölüm 2](#2-kurulum-yardımcısı)).

Nexvyn OS kendi dosyalarını `sdmc:/NexvynOS/` klasöründe tutar:

```
sdmc:/NexvynOS/
├── System/Config/       ayarlar (settings.json)
├── System/Logs/         sistem ve uygulama günlükleri
├── System/Library/      eklenebilir yazı tipleri, diller, duvar kâğıtları, sesler
├── System/Overlay/      sistem dosyalarının yerine geçen dosyalar (isteğe bağlı)
├── Applications/        sizin yüklediğiniz uygulamalar (.nxvapp)
├── Users/<ad>/          Desktop, Documents, Downloads, Pictures, Music, Movies, Library, .Trash
└── tmp/
```

### Üç başlatma biçimi

Nexvyn OS'un ne kadar bellek alacağı, nasıl açıldığına bağlıdır.

| Biçim | Nasıl açılır | Bellek | Not |
|---|---|---|---|
| **Başlık modu** (önerilen) | Bir oyunu açarken **R**'yi basılı tutun. Oyun yerine Homebrew menüsü açılır; Nexvyn OS'u oradan başlatın. | Tam | Ek kurulum gerekmez. Switch oyunlarını başlatma, sistem tarayıcısı ve PC oyunları bu modda çalışır. |
| **Applet modu** | Homebrew menüsünü Albüm'den açıp Nexvyn OS'u başlatın. | Sınırlı | Nexvyn OS bir kez uyarı gösterir. Büyük uygulamalar, sistem tarayıcısı ve oyun başlatma kısıtlıdır. |
| **Forwarder** | HOME menüsüne kurulan Nexvyn OS simgesine basın. | Tam | Ayrı bir kurulum ister. Ayrıntılar: [FORWARDER.tr.md](FORWARDER.tr.md). |

Hangi modda olduğunuzu **Sistem Ayarları > Hakkında > Başlatma modu** satırı gösterir: "Uygulama (tam bellek)" ya da
"Applet (Albüm, sınırlı bellek)". Applet modunda aynı ekranda gerçek bellek sınırı da yazar.

Forwarder kurulumu Nexvyn OS ekibi tarafından gerçek konsolda henüz denenmedi. Rehberdeki yasal ve güvenlik uyarılarını
okuyun.

### Nexvyn OS'tan çıkmak

Sistem menüsünde **Nexvyn OS'tan Çık…** seçeneği Nexvyn OS'u kapatır ve Homebrew menüsüne döner. Aynı menüde **Uyut**,
**Ekranı Kilitle**, **Konsolu Yeniden Başlat…** ve **Konsolu Kapat…** da vardır. Kaydedilmemiş belgeleri önce
kaydedin.

### Emülatörde (Ryujinx)

Nexvyn OS Ryujinx'te de açılır. Emülatörde bulunmayan donanım servisleri (parlaklık, USB, MTP, oyun başlatma, PC oyunları,
oyun kayıtları, build ID gibi) orada kapalı ya da "kullanılamıyor" olarak görünür.

---

## 2. Kurulum yardımcısı

İlk açılışta bir karşılama ekranı çıkar. A'ya basın ya da ekrana dokunun. Yardımcı sırasıyla şunları sorar:

| Adım | Ne seçilir |
|---|---|
| **Dil** | Menülerin ve uygulamaların dili. |
| **Klavye** | Ekran klavyesi ve USB klavye düzeni: Türkçe Q veya İngilizce (ABD). Aynı ekranda deneyebilirsiniz. |
| **Masaüstü düzeni** | Dock düzeni ya da Görev çubuğu düzeni (bkz. [bölüm 3](#3-iki-masaüstü-düzeni)). |
| **Ağ** | Nexvyn OS konsolun internet bağlantısını kullanır. Wi-Fi konsolun kendi ayarlarından kurulur. Bağlantı olmadan da devam edilebilir. |
| **Önerilen Programlar** | İsteğe bağlı. Aşağıya bakın. |
| **Hesap** | Adınız ve profil resminiz: konsol hesabınızın resmi, Nexvyn OS ile gelen bir resim ya da kendi resminiz. Ev klasörünüz bu adla oluşturulur. |
| **Hesabınızı koruyun** | "Parola yok" ya da 4–6 haneli bir PIN. PIN seçerseniz kilit ekranında sorulur. |
| **Görünüm** | Açık, Koyu veya Otomatik (19.00–07.00 arası koyu), vurgu rengi ve her akşam açılan Gece Modu. |
| **Duvar kâğıdı** | Seçtiğiniz anda arkadaki masaüstü değişir. |
| **Arayüz boyutu** | Küçük, Normal ya da Büyük (el modu ve TV için ayrı yüzdeler) ve büyük pencere düğmeleri (Otomatik, Her zaman, Kapalı). El modunda dokunmatik için Normal önerilir. |
| **Kumanda ve giriş** | Sol çubukla imleç hızı, ekran klavyesinin biçimi (alta sabit, yüzen, ikiye bölünmüş) ve dokunmatik titreşim. |
| **Ek seçenekler** | Güncellemeleri kendiliğinden denetleme, açılış sesi ve Nexvyn OS her açıldığında kendiliğinden açılacak uygulamalar. |
| **Kısa tur** | Dokunmatik hareketler, ekran kenarları, kumanda tuşları ve klavye kısayolları. "Turu Atla" ile geçilebilir. |
| **Özet** | "Her şey hazır mı?" ekranı bütün seçimleri listeler. Değiştirmek istediğinize dokunun (**Düzenle**), sonra **Özete Dön**. **Kurulumu Bitir** kurulumu tamamlar. |

Masaüstü düzeni, Önerilen Programlar ve Görünüm'den Ek seçenekler'e kadar olan adımlar isteğe bağlıdır: **Atla**
o adımın varsayılan ayarlarını olduğu gibi bırakır. Büyük bir arayüz boyutu seçerseniz yardımcı ekrana sığmak için
biraz küçük kalır; seçtiğiniz boyut kurulum biter bitmez uygulanır.

Son ekranda Nexvyn OS ev klasörünüzü, ayarlarınızı ve masaüstünüzü hazırlar. Masaüstüne "Nexvyn OS'a Hoş Geldiniz.txt"
adlı kısa bir not yazar. Bu adımların günlüğü `System/Logs/setup.log` dosyasına yazılır.

Bütün seçimler sonradan **Sistem Ayarları**'ndan değiştirilebilir.

### Önerilen Programlar adımı

Bu adımda Nexvyn OS, PC oyunları için bir program indirmeyi önerir: **Yok**, **CorkDeck (Steam kitaplığı)** veya
**Autorun**. Hiçbiri önceden seçili değildir. Bir seçim yaparsanız program, geliştiricisinin GitHub sürümünden indirilir
ve kurulumun son adımında kurulur. İndirme boyutu ekranda yazar.

Bu programlar Nexvyn OS'un parçası değildir; kendi geliştiricilerinin ayrı projeleridir. Nexvyn OS onları kurar ve başlatır.
Uyarıları için [PC Oyunları](#pc-oyunları) bölümünü okuyun. Daha sonra **Sistem Ayarları > Homebrew** bölümünden
kurabilir, güncelleyebilir veya kaldırabilirsiniz.

---

## 3. İki masaüstü düzeni

Nexvyn OS'ta iki masaüstü düzeni vardır. Yalnızca çubuklar değişir: pencereler, uygulamalar ve hareketler ikisinde de
aynı çalışır.

| | **Dock düzeni** | **Görev çubuğu düzeni** |
|---|---|---|
| Üstte | Menü çubuğu: sistem menüsü, uygulamanın menüleri, pil, Wi-Fi, saat, arama, Denetim Merkezi | Yok |
| Altta | Dock: sabitlenmiş ve çalışan uygulamalar | Görev çubuğu: Başlat menüsü, arama, Pencere Görünümü, sabitlenmiş ve çalışan uygulamalar, bildirim alanı |
| Uygulama menüleri | Menü çubuğunda | Pencerenin başlık çubuğunda; ayrıca başlığa ya da görev çubuğu düğmesine sağ tıklayınca (veya basılı tutunca) |
| Pencere düğmeleri | Sol üstte kapat / küçült / büyüt | Sağ üstte küçült / büyüt / kapat |

### Düzeni değiştirmek

- **Sistem Ayarları > Görünüm > Masaüstü düzeni**
- **Denetim Merkezi > Düzen** hızlı işlemi
- Ekranın sağ alt köşesindeki düzen düğmesi ("Dock düzenine geç" / "Görev çubuğu düzenine geç")
- **Otomasyon** uygulamasında "Masaüstü düzenini değiştir" eylemi

Değişiklik hemen uygulanır.

### Dock düzeni

- Dock'ta uygulamalar büyütme efektiyle gösterilir; çalışan uygulamanın altında bir nokta vardır.
- Bir uygulamaya sağ tıklayıp **Dock'ta Tut** ile sabitleyin.
- **Sistem Ayarları > Masaüstü ve Dock**: Dock boyutu, büyütme, otomatik gizleme ve Dock'taki uygulamalar.

### Görev çubuğu düzeni

- **Başlat** menüsünün üstünde arama alanı ve kategori sekmeleri var: **Tümü**, **Sabitlenmiş** ve uygulama
  kategorileri (Verimlilik, Araçlar, Medya, Oyunlar...). **Tümü** sekmesi sabitlenmiş uygulamaları, altında da
  **Önerilenler**'i (son açılan uygulamalar ve dosyalar) ve **Sizin için öneriler**'i (App Market'ten yeni gelen,
  sık açtığınız uygulamalar) gösterir.
- Yazdıkça o sekmedeki uygulamalar anında süzülür; **Dosya ve ayarlarda ara** satırı aramayı Quick Search'te sürdürür,
  son satır web'de arar. Enter ilk sonucu açar.
- Yan panel (arama alanının yanındaki düğme) **Tüm uygulamalar**'ı A–Z listeler; bir harfe dokunup o harfe
  atlayın. **Ayrıntılar** sekmesi işaretçinin altındaki uygulamayı ya da dosyayı **Aç**, **Başlat'a Sabitle**,
  **Görev Çubuğuna Sabitle**, **Masaüstüne Ekle**, **Uygulama Bilgisi** ve kurulu uygulamalar için **Kaldır**
  işlemleriyle gösterir. Küçük ekranlarda ayrı bir sayfa olarak açılır.
- Sağ tık (kumandada X, dokunmatikte basılı tutma) aynı işlemleri menü olarak açar. Sabitlenmiş uygulamalar buradan
  başa taşınabilir.
- Alt çubuk: adınız ve resminiz (Kullanıcılar ve Hesaplar), **Dosyalar**, **Ayarlar** ve **Güç** (Ekranı Kilitle, Uyut,
  Konsolu Yeniden Başlat, Konsolu Kapat, Nexvyn OS'u Yeniden Başlat, Nexvyn OS'tan Çık).
- Kumanda: D-pad öğeler arasında gezer, **L** / **R** sekme değiştirir, **A** açar, **X** menüyü açar, **B**
  kapatır. Klavye: yazınca arar, Aşağı ya da Tab arama alanından çıkar, oklar gezer, Enter açar, Ctrl+Tab sekme
  değiştirir.
- Görev çubuğu çalışan uygulamaları kısa bir çizgiyle, odaktaki uygulamayı kabarık bir zemin ve geniş vurgu
  çizgisiyle işaretler. Bir düğmenin üstüne gelince pencerelerin canlı küçük resimleri görünür. Saatin yanında
  okunmamış bildirim sayısı yazar.
- Bir düğmeye sağ tıklayınca **Son kullanılanlar**, **Yeni Pencere** ve **Tüm Pencereleri Kapat** çıkar. Aynı menüde
  **Görev Çubuğuna Sabitle** / **Görev Çubuğundan Kaldır** vardır.
- **Sistem Ayarları > Görünüm** (görev çubuğu düzeni seçiliyken): **Görev çubuğu boyutu** (küçük, orta, büyük),
  **Görev çubuğu düğmeleri** ("Her zaman birleştir": uygulama başına bir düğme, "Hiçbir zaman birleştirme": pencere
  başına bir düğme), **Görev çubuğu hizalaması** (ortada ya da solda), **Başlat'ta önerilenleri göster**,
  **Başlat'ta son dosyaları göster** ve **Başlat'ı yan panel açık olarak aç**.

---

## 4. Pencereler

### Temel işlemler

- **Taşı:** başlık çubuğundan sürükleyin.
- **Boyutlandır:** kenarından ya da köşesinden sürükleyin.
- **Büyüt / Önceki Boyut:** büyüt düğmesi ya da başlık çubuğuna çift tıklama.
- **Küçült:** küçült düğmesi ya da Ctrl+M.
- **Kapat:** kapat düğmesi ya da Ctrl+W. Ctrl+Q bir uygulamanın bütün pencerelerini kapatır.
- **Her Zaman Üstte** ve **Masaüstüne Taşı** pencere menüsündedir.

El modunda pencere düğmeleri dokunmaya uygun olarak büyür. Bunu **Sistem Ayarları > Ekran > Büyük pencere
düğmeleri** ile değiştirin: Otomatik (el modunda), Her zaman veya Kapalı.

### Yaslama ve yerleşimler

- Pencereyi ekranın sol ya da sağ kenarına sürükleyin: ekranın yarısını kaplar.
- Üst kenara sürükleyin: ekranı kaplar.
- Yerleşim menüsü: Dock düzeninde büyüt (yeşil) düğmesine, Görev çubuğu düzeninde büyüt düğmesinin üstüne gelin.
  Menüde **Büyüt**, **Sola yasla**, **Sağa yasla**, dört çeyrek ve **Tam Ekran** vardır.

### Tam ekran

- Ctrl+Alt+F ya da yerleşim menüsündeki **Tam Ekran**. Tam ekranda başlık çubuğu ve çubuklar gizlenir.
- Çıkmak için ekrandaki **Tam ekrandan çık** düğmesini kullanın ya da aynı kısayola basın.

### Açılış boyutu

Her uygulamanın penceresi, en son kapatıldığı konumda, boyutta ve durumda (normal, büyütülmüş ya da tam ekran)
yeniden açılır.

Bir uygulama ilk kez açıldığında normal boyutta açılır; kumanda kullanan oyunlar tam ekranda açılır. Bu ilk açılışı iki
ayar belirler (**Sistem Ayarları > Ekran**):

| Ayar | Varsayılan | Etkisi (yalnızca ilk açılışta) |
|---|---|---|
| **Pencereleri tam boyutta aç** | Kapalı | Yeni pencereler ekranın üstüyle Dock ya da görev çubuğu arasını kaplar. Küçük, sabit boyutlu pencereler kendi boyutunda açılır. |
| **Oyunları tam ekranda aç** | Açık | Kumanda kullanan oyunlar tüm ekranı kaplar. |

Sonraki açılışlarda bu ayarlar değil, pencerenin son durumu kullanılır. Pencere başka bir arayüz boyutunda
kaydedildiyse ya da artık ekrana sığmıyorsa, Dock'un veya görev çubuğunun altında kalmaması için çalışma alanına
sığdırılarak açılır.

### Masaüstleri ve Pencere Görünümü

- **Pencere Görünümü** açık bütün pencereleri yan yana gösterir. Açmak için: − tuşu, F3, Ctrl+Yukarı ok, üç parmakla
  yukarı kaydırma ya da sol kenardan içeri kaydırma.
- Pencere Görünümü'nün üstünde masaüstleri şeridi vardır. **+** ile yeni masaüstü ekleyin; bir masaüstüne sağ
  tıklayıp **Masaüstünü Kaldır** ile silin.
- Masaüstleri arasında geçiş: Ctrl+Sol/Sağ ok ya da üç parmakla sola/sağa kaydırma. Geçiş küp animasyonuyla yapılır.
- **Uygulama değiştirici:** L / R tuşları ya da Alt+Tab (geri için Alt+Shift+Tab).
- **Masaüstünü göster:** F11, Ctrl+Alt+D ya da üç parmakla aşağı kaydırma.

---

## 5. Girdi: dokunmatik, kumanda, klavye

### Dokunmatik ekran

| Hareket | İşlev |
|---|---|
| Dokunun | Tıklar |
| Basılı tutun | Sağ tık (bağlam menüsü) |
| İki parmakla kaydırın | Kaydırır |
| İki parmağı açın / kapatın | Yakınlaştırır / uzaklaştırır: Fotoğraflar (resim ve küçük resim boyutu), Dosyalar (simge boyutu), 3D Modelleme, Studio'nun sprite ve karo editörleri, Oyun Motoru |
| İki parmakla çevirin | 3D Modelleme'de görünümü hedef çevresinde döndürür |
| Üç parmakla sola / sağa | Masaüstleri arasında geçer |
| Üç parmakla aşağı | Masaüstünü gösterir |
| Üç parmakla yukarı | Pencere Görünümü'nü açar |
| Sol üstten aşağı | Bildirim Merkezi |
| Sağ üstten aşağı | Denetim Merkezi |
| Alttan yukarı | Uygulamalar ekranı |
| Sol kenardan içeri | Pencere Görünümü |

Dokunmatikle kullanırken:

- Menüler ve açılır listeler dokunmatik girdiden sonra daha büyük satırlarla açılır.
- Yalnızca simgesi olan bir düğmeye basılı tutunca ne işe yaradığı yazar.
- Listeler kenara gelince esner; kayan bir listeye dokunmak onu durdurur.
- Uzun basma, anahtar değiştirme, pencere yaslama ve sürükleme başlangıcı kumandada kısa ve hafif bir titreşim verir.
  Ayarı: **Sistem Ayarları > Erişilebilirlik > Dokunma > Dokunmatik titreşim** (Otomatik: el modunda açık; Her
  zaman; Kapalı).

Metin alanına dokununca ekran klavyesi açılır. Klavye yerleşik, yüzen (taşınabilir, boyutlandırılabilir) ya da
bölünmüş olabilir. Uzun basış aksanlı harfleri gösterir; dünya tuşu düzeni değiştirir.

**Dokunmatikle metin düzenleme** (metin alanlarında ve editörlerde):

| Hareket | İşlev |
|---|---|
| Dokunun | İmleci oraya koyar; birkaç saniye sürüklenebilir bir tutamak görünür |
| İki kez dokunun | Kelimeyi seçer |
| Basılı tutun | Kelimeyi seçer; seçim tutamakları ve Kes / Kopyala / Yapıştır balonu çıkar |
| İmlece dokunun | Balonu açar (Yapıştır, Seç, Tümünü Seç…) |
| Tutamağı sürükleyin | Seçimi büyütür ya da küçültür; parmağın altındaki metin büyüteçte görünür |

**Kelime önerileri:** ekran klavyesinin üstündeki çubuk yazdığınız kelimeyi tamamlar (yaklaşık 20.000 Türkçe ve
15.000 İngilizce kelime). Sık yazdığınız kelimeleri bu cihazda öğrenir. Kapatmak için: **Sistem Ayarları > Klavye ve
Giriş > Kelime önerileri** ya da klavyenin kendi menüsü.

### Kumanda

| Tuş | İşlev |
|---|---|
| Sol çubuk | İmleci hareket ettirir |
| A | Tıklar (iki kez basış çift tıklamadır) |
| X | Sağ tık |
| B | Geri / menüleri ve panelleri kapatır |
| Sağ çubuk | Kaydırır |
| Yön tuşları | Düğmeler arasında atlar (odak halkası) |
| + | Uygulamalar ekranı |
| − | Pencere Görünümü |
| ZR | Arama |
| ZL | Bildirim Merkezi |
| L / R | Uygulama değiştirici |
| Y | Ekran klavyesini açar / kapatır |
| Sol çubuğa basma | Denetim Merkezi |
| Sağ çubuğa basma | Ekran görüntüsü |

**Oyunlarda kumanda:** kumanda kullanan bir oyun (ya da Retro gibi bir uygulama) odaktayken kumanda oyuna gider ve
imleç hareket etmez. Ekranın sağ alt köşesinde bunu gösteren bir rozet vardır. Kumandayı imlece geri almak için
**L+R'yi bir saniye basılı tutun**. Bir saniyelik bekleme, L ile R'ye birlikte basan oyunlar yüzündendir. Dokunmatik
ekran her zaman çalışır.

İmleç ve kaydırma hızı: **Sistem Ayarları > Klavye ve Giriş > İmleç**.

### USB klavye ve fare

Konsola bir USB klavye ve fare takabilirsiniz. Farenin sağ düğmesi bağlam menüsünü açar. USB klavye kullanıldıktan
sonra ekran klavyesi gizli kalır.

| Kısayol | İşlev |
|---|---|
| Ctrl+Boşluk | Arama |
| F3 veya Ctrl+Yukarı ok | Pencere Görünümü |
| F4 | Uygulamalar ekranı |
| Alt+Tab / Alt+Shift+Tab | Uygulamalar arasında geçiş |
| Ctrl+Sol / Sağ ok | Önceki / sonraki masaüstü |
| F11 veya Ctrl+Alt+D | Masaüstünü göster |
| Ctrl+W | Pencereyi kapat |
| Ctrl+M | Pencereyi küçült |
| Ctrl+Q | Uygulamanın tüm pencerelerini kapat |
| Ctrl+Alt+F | Tam ekran |
| Ctrl+Shift+3 | Tam ekran görüntüsü |
| Ctrl+Shift+4 | Pencere görüntüsü |
| Ctrl+Alt+I | Renkleri ters çevir |
| Ctrl+Alt+8 | Yakınlaştırmayı aç / kapat |
| Ctrl+Alt+= / Ctrl+Alt+− | Yakınlaştır / uzaklaştır |
| Ctrl+/ | Kısayol listesi (Kod Düzenleyici ve Studio'da satırı yoruma çevirir) |
| Esc | Açık menüyü, aramayı ya da paneli kapatır |

Klavye düzeni (Türkçe Q veya İngilizce ABD): **Sistem Ayarları > Klavye ve Giriş**. Aynı yerden ekran klavyesi
yerine konsolun kendi klavyesini ("Nintendo sistem klavyesi") seçebilirsiniz.

---

## 6. Masaüstü, klasörler ve kısayollar

### Masaüstü

- Masaüstü, ev klasörünüzdeki `Desktop` klasörünü gösterir. Simgeler sol üstten ızgaraya dizilir; yerleri kaydedilir.
- Sürükleyerek taşıyın. Boş yerde sürükleyerek birden çok simge seçin. Ctrl ve Shift ile seçime ekleyin.
- Klavyeyle: oklar, Enter, Delete, F2 (yeniden adlandır), Ctrl+A/C/X/V.
- Sistem simgeleri: **Bu Konsol**, kullanıcı klasörünüz ve **Çöp Sepeti**. **Sistem Ayarları > Masaüstü ve Dock**
  bölümünden gizlenebilir.

Masaüstüne sağ tıklayınca:

- **Görünüm**: büyük, orta boy veya küçük simgeler; simgeleri otomatik düzenle; sistem simgelerini göster.
- **Sıralama ölçütü**: ad, boyut, öğe türü, değiştirilme tarihi.
- **Yeni**: Klasör, Metin belgesi, Markdown belgesi, Lua betiği.
- **Yapıştır**, **Terminalde Aç**, **Widget Ekle**, **Duvar Kâğıdını Değiştir…**, **Kişiselleştir**.

Bir simgeye sağ tıklayınca: **Aç**, **Birlikte Aç**, Kopyala, Kes, **Çoğalt**, **Kısayol Oluştur**, Yeniden
Adlandır, **Masaüstü Resmi Yap** (resimler için), **Çöp Sepetine Taşı**, **Bilgi Al**.

### Widget'lar

Saat, Takvim, Hava Durumu, Pil, Sistem, Notlar, Anımsatıcılar, Dünya Saati ve Radyo widget'ları masaüstüne eklenebilir.
Sürükleyerek taşıyın; sağ tık ile boyutunu değiştirin ya da kaldırın.

### Klasörler

İlk kurulumda masaüstünde **Oyunlar**, **Araçlar**, **Ofis**, **Medya** ve **Modlama** klasörleri vardır; içlerinde
ilgili uygulamaların kısayolları bulunur. Modlama klasörü eski bir kurulumda bir kez eklenir; silerseniz geri
gelmez. Bu klasörlerin kendi simgeleri vardır. Klasörleri silebilir, yeniden adlandırabilir
ya da yenilerini oluşturabilirsiniz.

### Kısayollar

- Kısayollar `.nxvlink` dosyalarıdır. Bir uygulamayı, dosyayı ya da klasörü gösterir.
- Oluşturmak için: bir öğeye sağ tık > **Kısayol Oluştur**. Uygulamalar ekranında bir uygulamaya sağ tık >
  **Masaüstüne Ekle**.
- Kısayol, hedefinin simgesini ok rozetiyle gösterir. Uzantı gösterilmez.
- Bir dosyayı bir uygulama kısayolunun üstüne bırakırsanız dosya o uygulamayla açılır.
- Hedef silinmiş ya da taşınmışsa "Kısayol çalışmıyor" uyarısı çıkar. **Hedef Konumunu Aç** ile hedefin klasörüne
  gidebilirsiniz.

### Arama ve Uygulamalar ekranı

- **Arama** (ZR, Ctrl+Boşluk): uygulama, dosya, ayar ve Otomasyon rutini bulur; basit hesapları yapar
  ("Hesap makinesi · kopyalamak için seç") ve web'de arama önerir.
- **Uygulamalar** ekranı (+, F4, alttan yukarı kaydırma): kategoriler, arama ve sayfalar. Izgara ekrana göre
  ayarlanır; büyük arayüz boyutlarında da simgeler ekrandan taşmaz. Bir uygulamaya sağ tıklayınca **Masaüstüne
  Ekle** ve (kurduğunuz uygulamalar için) **Kaldır** çıkar.

### Bildirim Merkezi ve Denetim Merkezi

- **Bildirim Merkezi**: tarih, widget'lar ve bildirimler. **Tümünü Temizle** ile boşaltın.
- **Denetim Merkezi**: Wi-Fi/IP, Rahatsız Etme, Karanlık Mod, ses, parlaklık, arayüz boyutu ve hızlı işlemler
  (Ekran Görüntüsü, Klavye, Pencere Görünümü, Düzen).
- Pil %20, %10 ve %5'e düşünce uyarı çıkar; şarja takınca bir bildirim görünür.

---

## 7. Dosyalar, USB bellek ve bilgisayar bağlantısı

### Dosyalar

**Dosyalar** uygulaması SD kartı ve ev klasörünüzü gösterir:

- Kenar çubuğunda Sık Kullanılanlar ve Konumlar; liste ve ızgara görünümü.
- Sürükle-bırak, kopyala/kes/yapıştır, zip ile sıkıştırma ve açma, Çöp Sepeti (geri koyma ile).
- Bir dosyaya çift tıklayınca uygun uygulama açılır. **Birlikte Aç** ile başka bir uygulama seçilebilir.
- `.nxvapp` dosyası yükleme sayfasını açar (bkz. [Uygulama Mağazası](#uygulama-mağazası-ve-uygulama-yükleme)).
- `.exe` dosyası PC Oyunları ile açılır.

### USB bellek

- Bir USB belleği dock'a ya da USB-C bağdaştırıcıyla konsola takın. "USB bellek takıldı" bildirimi çıkar; dokununca
  Dosyalar'da açılır.
- Desteklenen dosya sistemleri: FAT12/16/32 ve exFAT. NTFS desteklenmez.
- Çıkarmadan önce Dosyalar'da belleğin yanındaki **Güvenli Çıkar** düğmesine basın. "Artık çıkarabilirsiniz" yazınca
  çıkarın.
- USB bellek Ryujinx'te çalışmaz.

### Bilgisayara Bağlan

**Bilgisayara Bağlan** uygulaması SD karta bir bilgisayardan erişmenizi sağlar.

**Kablosuz (FTP):**

1. Konsolu ve bilgisayarı aynı ağa bağlayın.
2. Uygulamada sunucuyu açın. Ekranda bir adres (`ftp://…`) görünür.
3. Bilgisayardaki dosya yöneticisinin adres çubuğuna bu adresi yazın ya da herhangi bir FTP istemcisi kullanın.
   Uygulamadaki "Bilgisayardan nasıl bağlanılır" bölümünde dosya yöneticisi, FTP istemcisi ve telefon ya da tablet için
   adımlar vardır.

Ayarlarda kullanıcı adı ve parola, erişim alanı (tüm SD kart ya da yalnızca ana klasörünüz), salt okunur mod ve port
seçilir. Parola koymazsanız aynı ağdaki herkes bağlanabilir. FTP şifrelenmez; yalnızca güvendiğiniz ev ağında kullanın.

**USB kablosu (MTP):** konsolu dock dışında USB-C kablosuyla bilgisayara bağlayın; bilgisayar onu bir telefon gibi
görür. Bu özellik yalnızca gerçek konsolda çalışır.

Bilinen durum: FTP sunucusu Windows'tan Ryujinx'te denendi; listeleme, klasörler ve indirme çalıştı, yükleme
emülatörün ağ katmanı yüzünden orada denenemedi. MTP ve FTP yüklemesinin gerçek konsolda doğrulanması bekleniyor.

### FTP İstemcisi

**FTP İstemcisi** başka bir FTP/FTPS sunucusuna bağlanır: site yöneticisi, iki panelli görünüm ve aktarım kuyruğu.

---

## 8. Sistem Ayarları

Sistem Ayarları'nın bölmeleri: Wi-Fi ve Ağ, Kumandalar, Bildirimler ve Odak, Ses, Görünüm, Duvar Kâğıdı, Masaüstü ve
Dock, Ekran, Erişilebilirlik, Pil, Kilit Ekranı ve Güvenlik, Kullanıcılar ve Hesaplar, Dil ve Bölge, Tarih ve Saat,
Klavye ve Giriş, Depolama, Uygulamalar, Homebrew, Yazılım Güncelleme, Hakkında, Geliştirici. Üstteki arama alanı
ayarları adıyla bulur.

Öne çıkan ayarlar:

| Ayar | Yeri | Açıklama |
|---|---|---|
| **Arayüz Boyutu** | Ekran | %100, %110, %125, %140 veya %150. Pencereleri, yazıları ve düğmeleri birlikte büyütür. El modunda dokunmatik için %125 veya %140 önerilir. Denetim Merkezi'nden de değiştirilebilir. |
| **Moda göre otomatik** | Ekran | El modu ve Dock modu (TV) için ayrı arayüz boyutu kullanır. Konsolu dock'a taktığınızda boyut kendiliğinden değişir. |
| **Pencereleri tam boyutta aç**, **Oyunları tam ekranda aç** | Ekran | Bkz. [Açılış boyutu](#açılış-boyutu). |
| **Gece Modu** | Ekran | Ekran renklerini sıcak tonlara kaydırır. "Şimdi aç" ya da "Zamanla" (başlangıç ve bitiş saati), renk sıcaklığı. Ekran görüntülerini etkilemez. |
| **Donanımla video çözme (deneysel)** | Ekran > Video | Yüksek çözünürlüklü videolar daha akıcı oynar. Sorun olursa kapatın. |
| **Masaüstü düzeni**, açık/koyu/otomatik görünüm, vurgu rengi, **Saydamlığı azalt**, **Hareketi azalt** | Görünüm | |
| **Erişilebilirlik** | Erişilebilirlik | **Yakınlaştırma** (imleci takip eder), **Renkleri ters çevir** (Ctrl+Alt+I), **İmleç boyutu**. |
| **Etkin Köşeler** | Masaüstü ve Dock | Dört köşenin her birine bir işlem: Pencere Görünümü, Uygulamalar, Masaüstünü Göster, Bildirim Merkezi, Denetim Merkezi, Ekranı Kilitle, Ekran Koruyucu. İmleci köşeye itince çalışır. Dokunmatikte kenar hareketleri kullanılır. |
| **Ekran Koruyucu** | Masaüstü ve Dock | Başlatma süresi (ya da Asla) ve stil: **3B Şekiller** veya **Yıldız Yolculuğu**. Önizleme düğmesi vardır. |
| **PIN** | Kilit Ekranı ve Güvenlik | 4–6 haneli PIN ekleme, değiştirme, kaldırma. |
| **Oturum açılışında aç** | Kullanıcılar ve Hesaplar | Oturum açılınca sırayla açılan uygulamalar; her biri için "Simge durumunda" seçeneği. |
| **Dil ekleme** | Dil ve Bölge | SD karttan yeni dil eklenebilir (aşağıya bakın). |
| **Topluluk uygulama deposu** | Uygulamalar | Uygulama Mağazası'nın listelediği `index.json` adresi. Boş bırakılırsa varsayılan depo kullanılır. |
| **Homebrew Programları** | Homebrew | Önerilen homebrew programlarını indirme, güncelleme, kaldırma. |
| **Yazılım Güncelleme** | Yazılım Güncelleme | Yeni Nexvyn OS sürümünü GitHub'dan indirir; mevcut sürümün yedeğini tutar. Yalnızca herkese açık GitHub sürümleriyle çalışır. |
| **Sistem klasörü** | Hakkında | Overlay durumu ve **Sistem güncellemelerini sıfırla** (bkz. [SSS](#overlay-klasörünü-sıfırlamak)). |
| **Tanılama**, **Sistem günlükleri**, **Kabuğu Yeniden Başlat**, **Tüm ayarları sıfırla** | Geliştirici | |

### Yeni dil eklemek

`sdmc:/NexvynOS/System/Library/Languages/<kod>/` içine `_meta.json` ve modül `.json` dosyalarını (ya da tek bir
`key,en,tr,...` CSV dosyası) koyun. Dil, **Sistem Ayarları > Dil ve Bölge**'de görünür.

---

## 9. Yerleşik uygulamalar

Nexvyn OS 90'ı aşkın uygulamayla gelir. Hepsi Uygulamalar ekranında kategorilere ayrılmıştır. Aşağıda öne çıkanlar
anlatılır; tam liste [FEATURES.md](../../README.md) içindedir.

### Tarayıcı

Nexvyn OS'un kendi HTML/CSS motoruyla çalışan web tarayıcısı: sekmeler ve sekme görünümü, yer imleri, geçmiş, okuyucu
modu, indirmeler, formlar ve çerezler.

- **JavaScript:** sayfalar JavaScript çalıştırır (DOM, olaylar, fetch/XHR, localStorage). Her sayfanın zaman ve bellek
  sınırı vardır. Site başına kapatılabilir: menüde **Bu Sitede JavaScript**.
- **Parolalar:** giriş bilgileri kaydedilir ve otomatik doldurulur. Parola deposu cihazda şifreli tutulur; isteğe bağlı
  bir PIN ile korunabilir. **Parolalar…** menüsünden yönetilir.
- **Sınırlar:** çok büyük web uygulamaları (web postası, video siteleri, haritalar) tam bir tarayıcı ister. Bu
  sitelerde bir uyarı çıkar. **Sistem Tarayıcısında Aç** konsolun kendi tarayıcısını açar (applet modunda
  kısıtlıdır); video siteleri için Tube önerilir.

### AI Sohbet

Birden çok yapay zekâ sağlayıcısıyla çalışan sohbet uygulaması: Anthropic, Gemini, OpenAI, NVIDIA ve OpenAI uyumlu
özel sunucular. Yanıtlar akış hâlinde gelir; sohbetler kaydedilir; Markdown gösterilir.

- Kendi API anahtarınızı ekleyin: ayarlarda sağlayıcıyı seçin, **API anahtarı ekle**. Anahtar cihazda şifrelenerek
  saklanır ve **Sil** ile kaldırılır. Özel sunucuda anahtar isteğe bağlıdır.
- İstekler doğrudan sağlayıcıya gider; kullanım sağlayıcıdaki hesabınıza yazılır.
- İnternet bağlantısı gerekir.

### Medya

| Uygulama | Ne yapar |
|---|---|
| **Video Oynatıcı** | MP4, MKV, WebM, AVI, TS ve diğerleri; HTTPS ve HLS akışları; kaldığı yerden devam; tam ekran. |
| **Tube** | YouTube'da arama ve izleme, Shorts, yorumlar, isteğe bağlı oturum açma. Aşağıya bakın. |
| **Radyo** | Ülkelere ve türlere göre internet radyoları. Aşağıya bakın. |
| **Canlı TV** | M3U oynatma listeleriyle IPTV; iptv-org hazır listeleri. Kanallar ve yayınlar listeyi sağlayanlara aittir. |
| **Müzik** | Etiketler, kapak resimleri, çalma listeleri. m4a/aac, wma, ac3 de çalar. |
| **Fotoğraflar** | Resimler ve konsolun Albüm'ündeki ekran görüntüleri ve video klipleri. |

Bir akış yanıt vermezse oynatıcılar beklemede donup kalmaz: belli bir süre sonra ağ hatası gösterir. Videoda ileri
geri sarmak ya da kanal değiştirmek, arka planda Radyo çalarken de sesi dondurmaz.

### Tube

YouTube'da arama ve izleme uygulaması. Resmî bir istemci değildir; site değişirse bazı bölümler çalışmayabilir.

- **Gezinme:** Ana Sayfa bölümleri, arama önerileri ve filtreler (tür, süre, tarih, sıralama), kanal sayfaları
  (Videolar, Shorts, Canlı, Oynatma listeleri, Hakkında sekmeleri), oynatma listeleri, geçmiş. Listeyi yenilemek için
  aşağı çekin.
- **İzleme:** hız 0,5×–2× (ses perdesi değişmez), altyazı, bölümler (chapters), açıklamadaki zaman damgalarına ve
  bağlantılara dokunma, sıradaki videoya geri sayımla geçiş, arka planda ses. Tam ekranda iki kez dokunmak 10 saniye
  ileri ya da geri sarar. İzleme sayfasından çıkınca video küçük bir oynatıcıda sürer.
- **Kalite:** menü videonun gerçek çözünürlüklerini gösterir. 1080p ve üstü yalnızca video bir HLS akışı sunuyorsa
  seçilebilir; sunmuyorsa "Bu video için daha yüksek kalite sunulmuyor" yazar. Otomatik: donanımla çözme açıkken
  720p, kapalıyken 480p. Yüksek kalite takılırsa standart kaliteye düşülür.
- **Shorts:** dikey akış. Yukarı / aşağı kaydırarak geçin; dokunmak duraklatır, iki kez dokunmak beğenir (oturum
  açıkken). Kısa videolar döngüde oynar.
- **Yorumlar:** Popüler / En yeni sıralama ve yanıtlar oturum açmadan okunur. Yorum yazmak ve yanıtlamak için oturum
  açmak ve yorum iznini vermek gerekir.
- **Paylaş:** bağlantıyı kopyala, "bu andan itibaren" bağlantısı ya da telefonla okutmak için karekod.
- **Daha Sonra İzle:** bu cihazda tutulan yerel bir listedir. Google, hesaptaki Daha Sonra İzle listesini
  uygulamalarla paylaşmaz.
- **İndirme yoktur.** Tube videoları kaydetmez; yalnızca akış olarak oynatır.

**Oturum açma (isteğe bağlı).** Abonelik akışı, oynatma listeleriniz, beğendikleriniz, beğenme / abone olma /
listeye kaydetme, yorum yazma ve aboneliklerdeki yeni video bildirimleri için gerekir. Tube, Google'ın kendi
uygulamalarına ait kimlik bilgilerini kullanmaz; **kendi OAuth istemcinizi** oluşturmanız gerekir. Bir kez yapılır,
yaklaşık 5 dakika sürer ve ücretsizdir:

1. Bilgisayarda console.cloud.google.com adresinde yeni bir proje oluşturun.
2. **API'ler ve Hizmetler > Kitaplık** bölümünde "YouTube Data API v3"ü etkinleştirin.
3. OAuth izin ekranını (Google Auth Platform) yapılandırın: kitle olarak "Harici"yi seçin, kendi Google hesabınızı
   test kullanıcısı olarak ekleyin.
4. **İstemciler** bölümünde yeni bir OAuth istemci kimliği oluşturun; uygulama türü **"TV'ler ve Sınırlı Giriş
   cihazları"** olmalıdır.
5. İstemci kimliğini ve gizli anahtarını Tube'da **Oturum aç** sayfasına girin (ya da indirdiğiniz JSON dosyasını
   SD karta kopyalayıp **Dosyadan içe aktar**'ı kullanın).
6. **Google hesabıyla oturum aç**'a dokunun. Ekrandaki karekodu telefonla okutun ya da google.com/device adresini
   açın, kodu girip izin verin. Parolanız konsola hiç girilmez.

Proje "Test" durumundayken Google doğrulanmamış uygulama uyarısı gösterir ve oturumu 7 günde bir kapatır; projeyi
yayınlamak bu süreyi kaldırır. Günlük 10.000 birimlik API kotası sizin projenize aittir. İstemci bilgileri ve oturum
anahtarı cihazda şifreli saklanır, yalnızca Google'a gönderilir; oturumu kapatınca anahtar iptal edilir.

### Radyo

Radio Browser topluluk dizinindeki internet radyolarını çalar.

- Kenar çubuğunda **Favoriler**, **Son Dinlenenler**, **Popüler**, ülkeler (Türkiye ilk sırada) ve türler; üstte
  istasyon araması.
- Çalan şarkının adı (istasyon gönderiyorsa), favoriler (yıldız), uyku zamanlayıcısı (ay simgesi).
- Pencereyi kapatınca da çalmaya devam eder; yayın koparsa kendiliğinden yeniden bağlanır.
- **Radyo widget'ı** masaüstünde çalan istasyonu gösterir: oynat / duraklat, önceki ve sonraki favori.
- İstasyonlar ve yayınlar onları sağlayanlara aittir; bazı yayınlar kapanabilir ya da değişebilir. İnternet
  bağlantısı gerekir.

### Retro

NES, SNES, Game Boy, Game Boy Color, Game Boy Advance ve Mega Drive oyunlarını bir pencerede oynatan libretro
önyüzü: kitaplık, arama, favoriler, son oynananlar, resimli kayıt yuvaları, geri sarma, hızlı ileri, otomatik devam,
dokunmatik kumanda ve kumanda/klavye/dokunmatikle kullanılan duraklatma menüsü.

- **Çekirdekler derlenmelidir.** Emülatör çekirdekleri Nexvyn OS'a ancak kaynak koddan derlenirken eklenir
  (`tools/build_retro_cores.sh`). Çekirdeksiz bir sürümde Retro "Emülatör çekirdekleri yüklü değil" der ve derleme
  adımlarını gösterir.
- **Oyunlar gelmez.** Yalnızca sahip olduğunuz kartuşların yedeklerini oynayın. Nexvyn OS hiçbir oyun içermez ve
  indirmez. Dosyalarınızı `sdmc:/roms/<sistem>/` klasörlerine koyun; **ROM Klasörlerini Oluştur** bu klasörleri açar.

### Oyun Kitaplığı ve Homebrew

- **Oyun Kitaplığı:** yüklü Switch oyunlarını kapak, oynama süresi, boyut ve Albüm görüntüleriyle listeler ve başlatır.
  Oyun başlatma yalnızca tam bellekli modda (başlık modu ya da forwarder) çalışır. Steam ve PC sekmeleri PC
  Oyunları'nın kitaplığını gösterir.
- **Homebrew:** SD karttaki `.nro` programlarını listeler ve başlatır. Bunun için Nexvyn OS'un Homebrew menüsünden açılmış
  olması gerekir. Bir program açılınca Nexvyn OS kapanır.

### Modlama klasörü

Masaüstündeki **Modlama** klasörü oyun modlamak için altı uygulamayı toplar. Önce şunları bilin:

- **Atmosphère gerekir.** Modlar, hileler ve yamalar Atmosphère'in SD karttaki klasörlerinden
  (`sdmc:/atmosphere/contents/<Oyun ID>/…`) yüklenir. Nexvyn OS oyun dosyalarının kendisine dokunmaz.
- **Değişiklikler oyunun bir sonraki açılışında geçerli olur.** Açık olan oyunu kapatıp yeniden başlatın. (Tek
  istisna: Hile Yöneticisi'nin "Çalışan oyun" bölümü.)
- **Modlu oyunla ya da hilelerle çevrimiçi oynamak hesabınızın engellenmesine yol açabilir.**
- Bu uygulamalar yalnızca SD kart üzerinde çalışır; arşivlerdeki SD kartın dışını gösteren yollar yazılmaz.
- Konsol servisi gerektiren bölümler (build ID, çalışan oyun, sistem modüllerini başlatma/durdurma, kayıtlar) yalnızca
  gerçek konsolda çalışır; emülatörde "bilinmiyor" görünür. Bu uygulamalar Ryujinx'te denendi, gerçek konsolda henüz
  doğrulanmadı. Önemli kayıtlarınızı ve dosyalarınızı önce yedekleyin.

| Uygulama | Ne yapar |
|---|---|
| **Mod Yöneticisi** | Oyun başına modlar: `atmosphere/contents`, `sdmc:/mods` kitaplığı ve exefs (`.ips`) yamaları. Her modu açıp kapatır; hangi dosyayı kopyaladığını tam olarak kaydeder. Aynı dosyaları değiştiren modlar için çakışma uyarısı verir. `.zip` dosyasından ya da klasörden yükler, dosyaları gösterir, **Mod oluştur** ile boş bir mod klasörü (romfs, exefs, README) hazırlar. Türkçe Yamalar'a ait dosyalara dokunmaz. |
| **Hile Yöneticisi** | Hile dosyalarını (`.txt`) okur ve hatalı satırı gösterir, yüklü sürümün build ID'siyle eşleşip eşleşmediğini söyler. Her hileyi ayrı açıp kapatır (`toggles.txt`); oyun açıkken **Çalışan oyun** bölümünden hileleri hemen değiştirir (yalnızca gerçek konsolda). |
| **Sistem Modülleri** | `atmosphere/contents` içindeki arka plan modüllerini listeler. **Açılışta başlat** ayarı (bir sonraki açılışta geçerli) ve izin veren modüller için Başlat / Durdur. Tanımadığınız bir modülü kapatmayın. |
| **Oyun Bilgileri** | Yüklü oyunun sürümü, güncellemesi, DLC'leri, Oyun ID'si, build ID'si, hile dosyası adı, kayıt verisi ve boyutu; sistem yazılımı, Atmosphère sürümü, emuMMC / sysMMC ve SD kart doluluğu. Oradan Hileler'e ve Modlar'a geçilir. |
| **Türkçe Yamalar** | Kendi indirdiğiniz Türkçe yama zip'ini kurar, açar / kapatır, kaldırır. Aşağıya bakın. |
| **Kayıt Yedekleme** | Oyun kayıtlarını kullanıcı başına yedekler ve geri yükler. Aşağıya bakın. |

**Türkçe Yamalar.** Yamayı çeviri ekibinin sitesinden `.zip` olarak indirin (Tarayıcı, bilgisayar ya da kablo ile),
sonra **Zip'ten Kur** ile seçin. Uygulama oyunu ve klasör yapısını kendisi bulur; bulamazsa oyunu listeden seçersiniz
ya da başlık kimliğini girersiniz. Üzerine yazılacak her özgün dosya önce `sdmc:/NexvynOS/Backups/TurkcePatches`
altına yedeklenir; yedek alınamazsa kurulum yapılmaz. Kapatınca ya da kaldırınca özgün dosyalar geri konur. Yamanın
hazırlandığı oyun sürümü konsoldaki sürümle karşılaştırılır; uymuyorsa uyarı çıkar (oyun çökebilir ya da metinler
bozuk görünebilir). **Yama Siteleri** sekmesi ekiplerin sayfalarını Tarayıcı'da açar.

Uygulama yamaları kendisi indirmez. Yama arşivlerinin başka uygulamaların kullanmasına izin veren herkese açık bir
arayüzü yok ve yamalar onları hazırlayan çevirmenlerindir. YamaNX'in kodu ise ticari olmayan kullanımla sınırlı bir
lisansla yayımlandığı için Nexvyn OS'un GPL lisansına alınamaz. Ayrıntılar: [TURKISH_PATCHES.tr.md](TURKISH_PATCHES.tr.md). YamaNX ile
kurulmuş yamalar tanınır ve kaldırılabilir.

**Kayıt Yedekleme.** Üstten kullanıcıyı seçin, sonra bir oyunda **Şimdi Yedekle** ya da **Tümünü Yedekle**. Yedekler
`sdmc:/NexvynOS/Backups/Saves/<Oyun>/<Kullanıcı>/<tarih>/` altına klasör olarak ya da **Zip olarak sıkıştır** seçiliyse
zip olarak yazılır. Geri yüklerken dikkat:

- Geri yükleme, o kullanıcının şu anki kaydının **yerine geçer**. Nexvyn OS önce şu anki kaydı otomatik bir güvenlik
  yedeği olarak alır; bu yedek alınamazsa geri yükleme yapılmaz. Bir şey ters giderse listedeki güvenlik yedeğini
  geri yükleyin.
- Oyunu geri yüklemeden önce kapatın; açık bir oyunun kaydı açılamaz.
- Oyunun o kullanıcıda bir kaydı olmalı: oyunu bir kez açıp kaydedin, sonra geri yükleyin.
- Başka bir kullanıcıdan alınmış bir yedeği geri yüklerken uyarı çıkar.
- İşlem bitene kadar konsolu kapatmayın. Önemli kayıtlar için yedeği bilgisayara da kopyalayın.

### PC Oyunları

**PC Oyunları**, PC oyunlarını iki ayrı homebrew programıyla oynatır. Oyunlar Nexvyn OS penceresinde değil, o programın
içinde çalışır.

| Program | Ne sağlar |
|---|---|
| **CorkDeck** | Steam hesabınıza girer ve sahip olduğunuz oyunları konsola indirir. Steam kitaplığınız **Steam** sekmesinde görünür. |
| **Autorun** | PC (x86/x64) oyunlarını ve programlarını Wine, FEX ve DXVK ile çalıştırır. Oyun klasörlerini `switch/wine/drive_c` içine kopyalarsınız; **PC Kitaplığı** sekmesinde görünürler. |

İkisi de aynı klasörü (`switch/wine`) kullanır; aynı anda yalnızca biri kurulu olabilir. Hiçbiri kurulu değilse
uygulama kurulum kartları gösterir.

**Önce okuyun:**

- **Deneysel.** İki proje de deneyseldir; birçok oyun çalışmayabilir.
- **emuMMC kullanın.** CorkDeck'i yalnızca emuMMC ile kullanın; çevrim içi kullanım ban riski taşır.
- **Yedek alın.** İlk kurulum adımı önyükleme yamaları kurabilir. Önce SD karttaki `atmosphere` ve `bootloader`
  klasörlerini yedekleyin.
- **Nexvyn OS kapanır.** Oyna'ya basınca Nexvyn OS bir geçiş ekranı gösterir, kapanır ve programı başlatır. Açık
  belgelerinizi önce kaydedin.
- **Otomatik dönüş yok.** Oyundan çıkınca CorkDeck ya da Autorun kendi kitaplığını gösterir. Nexvyn OS'a dönmek için onu
  Homebrew menüsünden yeniden başlatın.
- **Tam bellek gerekir.** Applet modunda PC oyunları için uyarı çıkar; başlık modunu kullanın.
- **İlk açılış.** CorkDeck bir Steam oyununu ilk açılışta kendi menüsünde hazırlar. Bunu bir kez CorkDeck'in kendi
  menüsünden yapın; sonra Oyna düğmesi oyunu doğrudan açar.
- Bazı oyunlar yalnızca CorkDeck / Autorun'un HOME menüsü kısayolundan çalışır; uygulama bunu ayrıca belirtir.
- Emülatörde PC oyunları çalışmaz.

Steam kitaplığının tamamını ve oynama sürelerini görmek için menüden **SteamID…** ve isteğe bağlı **Steam Web API
Anahtarı…** girilebilir. Steam profilinizde oyun ayrıntıları herkese açık olmalıdır.

CorkDeck ve Autorun, kendi geliştiricilerinin ayrı açık kaynak projeleridir; Nexvyn OS onları kurar ve başlatır, kodlarını
içermez. **Sistem Ayarları > Homebrew** ve Uygulama Mağazası'ndaki Homebrew bölümü ayrıca Moonlight, JKSV ve NX
Activity Log'u da kurabilir.

### Otomasyon ve oturum açılışı

**Otomasyon** iki parçadan oluşur:

- **Rutin:** sırayla çalışan eylemler. Eylemler: uygulama aç, dosya veya klasör aç, web sayfası aç, bekle, bildirim
  göster, görünümü ayarla, ses düzeyini ayarla, parlaklığı ayarla, Gece Modu, masaüstü düzenini değiştir, arayüz
  boyutunu ayarla, duvar kâğıdını değiştir, masaüstünü göster, ekranı kilitle, tüm pencereleri kapat, başka bir rutini
  çalıştır. Rutinler renkli kutucuklar olarak görünür; masaüstüne konabilir ve Arama'da bulunur.
- **Otomasyon:** bir rutini bir tetikleyiciye bağlar: oturum açılışı, günün bir saati, pil düzeyi, şarj cihazı, dock /
  el modu, USB bellek takılması ya da bir uygulamanın açılması.

Yalnızca birkaç uygulamayı oturum açılışında açmak için Otomasyon gerekmez: **Sistem Ayarları > Kullanıcılar ve
Hesaplar > Oturum açılışında aç**.

### 3D Modelleme

Dokunmatik, kumanda ve klavyeyle low-poly modelleme: sahne hiyerarşisi, özellik paneli, ayarlanabilir temel şekiller,
yakalamalı taşı/döndür/ölçekle aracı ve köşe, kenar, yüz düzenleme (extrude, inset, birleştirme, subdivide, normaller).
64 adım geri alma. `.nxv3d` projeleri, OBJ/STL içe aktarma, OBJ+MTL/STL dışa aktarma ve PNG görüntü kaydı. Örnekler: ev,
ağaç, araba.

### Oyun Motoru

Çocukların da kullanabileceği 2D ve 3D oyun yapma uygulaması (eski adıyla Oyun Atölyesi). Uygulamalar'da ve Başlat
menüsünde Studio'nun yanında, **Geliştirici** grubundadır.

- **Oyun sihirbazı:** ana ekrandaki ilk kart. Bir tür (Platform, Macera, Uzay savaşı, Bulmaca, Yarış 3D, Koşucu 3D),
  bir dünya (Orman, Kar, Çöl, Mağara, Uzay, Şeker diyarı, Okyanus) ve bir ad seçin; **Oyunumu kur!** hemen
  oynanabilen bir oyun hazırlar.
- **Yeni oyun yap:** ya da bir resim kartı seçin (Platform, Orman Macerası, Labirent, Anahtar Bulmacası, Uzay, Yarış
  3D, Koşucu 3D, Top Toplama 3D, Boş 2D, Boş 3D ve diğerleri). **Örnek oyunlar** (Kedi Macerası, Penguen Macerası,
  Yıldız Avcısı, Altın Ada, Robot Koşusu) açılıp değiştirilebilir; ilk değişiklikte Oyunlarım'a kopyalanır. Oyunlarınız
  `Belgeler/Oyunlarım` klasöründe durur; kartlarındaki yeşil ▶ oyunu tek dokunuşla başlatır.
- **Rehberli tur:** ilk açılışta kısa bir tur ekranın parçalarını tanıtır; **Yardım** düğmesiyle yeniden izlenir.
- **Geçmiş:** araç çubuğundaki Geçmiş düğmesi son değişiklikleri saatleriyle listeler; birine dokununca o andan beri
  yapılan her şey geri alınır. Oyun kendiliğinden kaydedilir (başlığın altında "Kaydedildi").
- **Kolay mod:** soldaki büyük düğmelerden bir karakteri, düşmanı, toplanacak nesneyi ya da bloğu sahneye sürükleyin
  (ya da resme dokunup sahneye dokunun; kumandayla da çalışır). Bir nesneye dokununca davranış karoları açılır:
  oyuncu kontrolü, sağa sola gezme, rastgele gezme, zıplama, takip, toplanınca puan ya da sayma, dokununca can gider,
  canı var, bir şey söyler, trambolin, bitiş ve diğerleri. Her davranışın ne yaptığı tek cümleyle gösterilir.
  Büyük yeşil **▶ Oyna** oyunu hemen açar; kırmızı ■ düzenlemeye döner. Geri al / Yinele hep görünür.
- **Gelişmiş mod:** sayılarla denetçi, katmanlar, Scratch benzeri olay blokları (her bloğun altında kısa bir açıklama),
  piksel çizim ve karo editörleri, sesler ve bloklardan üretilen Lua kodu (**Koda dönüştür**).
- **Paylaş:** **Uygulama olarak paylaş** oyunu `Belgeler/<Oyun>.nxvapp` olarak kaydedip Uygulama Yükleyici'de açar;
  **Masaüstüne ekle** kurup masaüstüne bir kısayol koyar; **Studio'da aç** oyunu bir Lua uygulaması olarak kurup
  Studio'da açar, kodla devam edersiniz. Paket başka bir Nexvyn OS'ta da aynı çalışır.

Ayrıntı ve proje biçimi: [GAME_ENGINE_PROJECTS.tr.md](GAME_ENGINE_PROJECTS.tr.md).

### Gösteri

Nexvyn OS'un neler çizip çalabildiğini gösteren altı sahnelik bir tur: prosedürel ada, gece şehri, sarmal galaksi, fizik
oyun alanı, 2D efektler ve parçacıklardan oluşan logo. Bütün modeller, dokular ve müzik çalışırken koddan üretilir.

- A / sağ ok: sonraki sahne · B / sol ok: önceki · +: duraklat · X: istatistik paneli (FPS, üçgen, çizim çağrısı,
  çizim yolu) · Y: müzik · −: kalite (Otomatik, Düşük, Orta, Yüksek).
- Çubuklarla ya da sürükleyerek serbest kamera.
- Otomatik kalitede kare hızı düşerse kalite bir basamak iner. Ryujinx'te ekran kartı yolunda 58–60 FPS ölçüldü;
  gerçek konsolda değerler farklı olabilir.

### Ofis

| Uygulama | Ne yapar |
|---|---|
| **Kelime İşlemci** | Biçimlendirme ve şablonlarla belgeler. |
| **Hesap Tablosu** | Formüller, grafikler, CSV. |
| **Sunum** | Temalar, geçişler ve sunum modu. |

Notlar, Takvim, Anımsatıcılar, Kişiler, Yapışkanlar, Metin Düzenleyici ve Saat de verimlilik uygulamalarıdır.

### Nexvyn OS Studio

Konsolun içinde Lua, JavaScript ve Python uygulaması yazmak için geliştirme ortamı: şablon galerisi (Python için "Boş
Python uygulaması" ve "Yılan (Python)" dahil; `.py` dosyaları Python renklendirmesiyle açılır), canlı hata denetimi,
otomatik tamamlama, çalıştırma, konsol çıktısı, sprite, tilemap ve sahne editörleri ve paket dışa aktarma. Yan paneldeki
yapay zekâ yardımcısı (AI Sohbet'teki anahtarlarla çalışır) soruları yanıtlar; dosyaları kendisi değiştirmez.
Ayrıntılar: [DEVELOPER_GUIDE.tr.md](DEVELOPER_GUIDE.tr.md).

### Uygulama Mağazası ve uygulama yükleme

- **Uygulama Mağazası** topluluk deposundaki uygulamaları listeler, indirir ve günceller. İndirilen her paketin SHA-256
  değeri denetlenir. Homebrew bölümü önerilen homebrew programlarını gösterir.
- Bir `.nxvapp` dosyasını Dosyalar'da açınca yükleme sayfası çıkar: ad, yazar, sürüm, boyut, gereken SDK, doğrulama
  durumu ve **İzinler**.
  - **Çalıştır**: uygulamayı kurmadan bir kez açar.
  - **Yükle**: `sdmc:/NexvynOS/Applications` içine kurar. Aynı uygulamanın yeni sürümü yerine yazılır; verileri korunur.
- Kurulan uygulamalar ağ erişimi ve kendi klasörü dışındaki dosyalar için izin ister.
- Kaldırmak için: Uygulamalar ekranında sağ tık > **Kaldır**, Sistem Ayarları > Uygulamalar ya da Mağaza.

### Diğerleri

| Grup | Uygulamalar |
|---|---|
| Sistem | Dosyalar, Sistem Ayarları, Sistem İzleyici, Sistem Bilgisi, Disk Yöneticisi, Ağ Araçları, Uygulama Mağazası, Homebrew |
| Geliştirici | Terminal, Kod Düzenleyici, Konsol (sistem günlükleri), Nexvyn OS Studio, Merhaba SDK, Merhaba JS, Merhaba Python |
| İnternet | Hava Durumu, Haritalar (OpenStreetMap), Haberler (RSS), Döviz, Sözlük, FTP İstemcisi |
| Araçlar | Hesap Makinesi, Ekran Görüntüsü, Kontrolcü Testi, Arşiv Yöneticisi, Yazı Tipleri, Renk Ölçer, Birim Dönüştürücü, QR Kod, Şifre Üretici, Mors Kodu, Grafik Çizici, Periyodik Tablo, Finans Hesaplayıcı, Güneş Sistemi, Dünya Küresi, 3D Yüzey, Geri Sayım, Bilgisayara Bağlan, Otomasyon |
| Verimlilik | Pomodoro, Alışkanlıklar, Bütçe, Kelime Kartları, Klavye Ustası, Nefes, Günlük, Görev Panosu |
| Medya | Çizim, Piyano, Metronom, Ritim Makinesi, Melodi Stüdyosu, 3D Görüntüleyici (OBJ/STL) |
| Oyunlar | Satranç, Solitaire, Mayın Tarlası, Yarışçı (3D), Pixel Koşu, Uzay Arenası |

---

## 10. Sorun giderme ve SSS

### Nexvyn OS "sınırlı bellekle çalışıyor" diyor

Nexvyn OS'u Albüm'den (applet modu) açtınız. Bu modda sistem ona az bellek verir: büyük uygulamalar, sistem tarayıcısı
ve oyun başlatma kısıtlıdır, ağır sayfalar ya da videolar kapanabilir. Çözüm:

- Bir oyunu açarken **R**'yi basılı tutup Homebrew menüsünü oradan açın (başlık modu), ya da
- bir forwarder kurun: [FORWARDER.tr.md](FORWARDER.tr.md).

Gerçek bellek sınırı **Sistem Ayarları > Hakkında** ekranında yazar.

### Nexvyn OS çöktü

- Çökme olursa Nexvyn OS `sdmc:/NexvynOS/System/Logs/crash.txt` dosyasına bir not yazar. İlk satırda, çökme anında çalışan
  uygulama yazar.
- Bir sonraki oturumda o uygulama, oturum açılışında bir kez açılmaz. Böylece açılışta çöken bir uygulama Nexvyn OS'u her
  seferinde düşürmez. Not daha sonra `crash.prev.txt` adıyla saklanır.
- Bir hata bildirirken `crash.txt` (ya da `crash.prev.txt`) ve `system.prev.log` dosyalarını ekleyin.

### Bir uygulama hata verdi

Lua ya da JavaScript uygulamasında hata olursa pencerede satır numaralı bir hata ekranı çıkar. **Yeniden Yükle**
uygulamayı baştan başlatır. Hata ayrıca uygulamanın günlüğüne yazılır.

### Günlükler nerede?

| Dosya | İçerik |
|---|---|
| `sdmc:/NexvynOS/System/Logs/system.log` | Bu oturumun sistem günlüğü |
| `sdmc:/NexvynOS/System/Logs/system.prev.log` | Bir önceki oturumun günlüğü (çökmeden sonra buna bakın) |
| `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` | Lua / JavaScript uygulamalarının çıktısı ve hataları |
| `sdmc:/NexvynOS/System/Logs/setup.log` | Kurulum yardımcısının günlüğü |
| `sdmc:/NexvynOS/System/Logs/crash.txt` | Son çökmenin notu |

Günlükleri konsolda **Konsol** uygulamasıyla ya da **Sistem Ayarları > Geliştirici > Sistem günlükleri** ile
okuyabilirsiniz.

### Overlay klasörünü sıfırlamak

`sdmc:/NexvynOS/System/Overlay/` içindeki dosyalar, Nexvyn OS'un yerleşik sistem dosyalarının (dil dosyaları, duvar
kâğıtları, sistem uygulamaları…) yerine kullanılır. Bir sistem değişikliği sorun çıkarırsa:

- **Sistem Ayarları > Hakkında > Sistem klasörü > Sistem güncellemelerini sıfırla.** Klasör `Overlay.off` adıyla
  kenara alınır (silinmez). Nexvyn OS yeniden başlayınca yerleşik dosyalar kullanılır.
- Nexvyn OS açılmıyorsa SD kartı bilgisayara takın ve `NexvynOS/System/Overlay` klasörünün adını değiştirin.

### Ayarları sıfırlamak

**Sistem Ayarları > Geliştirici > Tüm ayarları sıfırla.** Görünüm, Dock, widget'lar, duvar kâğıdı, sesler, giriş, PIN
ve güncelleme seçenekleri varsayılana döner. Dosyalarınız, kullanıcı adınız ve diliniz korunur. Sıfırlamayı
tamamlamak için Nexvyn OS'u yeniden başlatın.

### Masaüstü boştayken daha yavaş görünüyor

Bu bilerek yapılır. Hiçbir şey hareket etmediğinde masaüstü saniyede 20 kareye iner ve daha az işlemci kullanır. İlk
dokunuşta ya da tuşta hemen tam hıza döner. Kapatmak için `System/Config/settings.json` içinde `perf.idleThrottle`
değerini `false` yapın.

### Kumanda oyunda kaldı, imleç hareket etmiyor

**L+R'yi bir saniye basılı tutun.** Ekrana dokunmak da imleci kullanmanızı sağlar.

### PC oyunundan sonra Nexvyn OS'a dönemiyorum

Bu beklenen bir durumdur: CorkDeck ve Autorun çıkışta kendi kitaplıklarını gösterir. Nexvyn OS'u Homebrew menüsünden
yeniden başlatın.

### Retro "Emülatör çekirdekleri yüklü değil" diyor

Kullandığınız `NexvynOS.nro` çekirdeksiz derlenmiş. Çekirdekler `tools/build_retro_cores.sh` ile derlenir ve Nexvyn OS
yeniden derlenir. Ayrıntılar uygulamanın kendi ekranında yazar.

### Bir web sitesi açılmıyor ya da bozuk görünüyor

Nexvyn OS'un tarayıcısı hafif bir motordur. Ağır siteler için **Sistem Tarayıcısında Aç**'ı kullanın (tam bellekli
modda) ya da sitenin hafif sürümünü açın. Videolar için Tube'u deneyin.

### Yazılım Güncelleme sürüm bulamıyor

Güncelleme denetimi, ayarlardaki GitHub deposunun **herkese açık** son sürümüne bakar. Depo gizliyse ya da henüz sürüm
yayımlanmamışsa güncelleme bulunamaz. Yeni `NexvynOS.nro` dosyasını elle de `sdmc:/switch/` içine kopyalayabilirsiniz.
