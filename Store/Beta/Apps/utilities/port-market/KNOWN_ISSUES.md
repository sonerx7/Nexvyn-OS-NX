# Port Market bilinen sorunlar

## 0.2.1

- Internet Archive öğelerinde ilk 500 dosya kaydı okunur. Cihazdaki canlı indirme ve kurulum kabul testi bekliyor.

## 0.2.0

- Seçilen Internet Archive öğelerinde ilk 500 dosya kaydı okunur. Yükleme işlenirken dosya hemen görünmeyebilir.
- İndirilen dosyanın byte sayısı kontrol edilir. Internet Archive SHA-1 değeri önbellek kimliğinde kullanılır. Nexvyn OS, paketi açarken iç manifesti denetler.
- SDK ve masaüstü denetimi cihazda gerçek ağ/kurulum akışının kanıtı değildir.

## 0.1.0

- Paketin yolu veya indirme adresi panoya aktarılır. İnceleme ve kurulum için Nexvyn OS Dosyalar uygulaması kullanılır.
- Uygulama yerel dosyanın boyutunu kontrol eder. SHA-256 değeri de katalogda gösterilebilir; tam dosya doğrulaması katalog üretilirken masaüstünde yapılır.
- SDK derlemesi ve statik denetimler cihazdaki ekran düzeni veya kurulum akışı için kanıt sayılmaz.
