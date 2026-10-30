# Görev: araç uygulaması yapmak

[English](make-utility.en.md) · **Türkçe**

Bağlam bundle'ından (`system-prompt.tr.md` + language pack) sonra gönderin.

```text
Eksiksiz bir Nexvyn OS araç uygulaması yaz.

Uygulama: <ne yaptığı, kimin kullandığı, 3-5 ana özellik>
Dil: <Lua | JavaScript | Python | Squirrel | C | Java>
Uygulama kimliği: com.<adiniz>.<uygulama>   Ad: <İngilizce ad> / <Türkçe ad>
Veri: <neyin kaydedilmesi gerektiği; ör. "tarih ve tutar içeren girdilerden oluşan bir liste">
Ağ: <yok | hangi herkese açık HTTPS API'si, API anahtarı olmadan>

Gereksinimler:
- Doğru "runtime"/"main"/"minSdk", uygun bir "category" ve YALNIZCA kodun kullandığı izinleri içeren app.json
  (net.* için network, sys.notify/sys.schedule için notifications, sys.games için games, sys.launch ya da
  nxv:// bağlantıları için launch, uygulamanın klasörleri dışındaki yollar için files).
- En küçük pencere boyutundan itibaren çalışan bir yerleşim ("minWidth"/"minHeight" ayarla), 16-20 px kenar boşluğu,
  en az 28 px yüksekliğinde denetimler, yalnızca theme renkleri; dokunmatik, kumanda imleci ve klavyeyle çalışsın.
- ui.beginScroll / ui.endScroll ile listeler; ui.group ve ui.separator ile ayarlar tarzı bölümler.
- Her değişikliği store ile (belgeler için fs ile) hemen kaydet; bir belge varsa autosave ve unsaved'i uygula.
- Ağ kullanıyorsa: önce sys.online()'ı denetle, yüklenirken bir dönen gösterge ve anlaşılır bir hata iletisi göster.
- Ana eylemleri ve klavye kısayollarını içeren bir menü (app.menu / app.onmenu).
- Görünen her metin lang/en.json ve lang/tr.json ile TR()'den geçsin (yapabilirsen de, fr, es de).
- app.draw'ı hafif tut: karede dosya okuma, resim yükleme ya da büyük allocation yok.

Her dosyayı eksiksiz ver, sonra PC'de nasıl denetlenip konsolda nasıl çalıştırılacağını ve yaptığın varsayımları yaz.
```
