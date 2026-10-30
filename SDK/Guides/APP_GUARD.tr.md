# Uygulama Koruması (App Guard)

Uygulama Koruması, SD karttaki uygulamaları özel verilerinizden uzak tutar ve bir uygulamayı yüklemeden önce kodu size
zarar verebilecek gibi görünüyorsa bunu söyler. Bilerek küçük tutuldu: her zaman geçerli olan bir sandbox kuralı,
yalnızca bir şey yüklerken ya da siz istediğinizde çalışan bir statik tarama ve sistem dosyalarına bir kilit. Hiçbir
zaman arka planda zamanlanmış olarak çalışmaz; konsolu kullanırken hiçbir yük getirmez.

> English: [APP_GUARD.en.md](APP_GUARD.en.md)

## 1. Korunan klasörler (her zaman açık)

SD karta yüklenen uygulamalar (`sdmc:/NexvynOS/Applications`) bir dosya sandbox'ında çalışır. `files` izniyle
belgelerinizi ve SD kartın geri kalanını kullanabilirler; ama bazı klasörler **bu izin olsa bile** onlara kapalıdır:

| Klasör | İçinde ne var |
|---|---|
| `sdmc:/NexvynOS/System` (`System/Library` ve `System/Fonts` hariç) | ayarlar, kullanıcılar ve PIN, izinler, imzalayanlar, günlükler, Overlay |
| `sdmc:/NexvynOS/Applications/<başka uygulama>` | başka uygulamaların kodu |
| Uygulamanın kendi `Application Support/<id>` ve `Caches/<id>` klasörleri dışında `~/Library` | başka uygulamaların verileri: Tarayıcı'nın çerezleri, geçmişi ve kayıtlı parolaları, AI Chat anahtarları, FTP parolaları, Tube hesabı, klavyenin öğrendiği sözcükler |
| `sdmc:/NexvynOS/Users/<başka kullanıcı>/Library` | başka bir kullanıcının uygulama verileri |
| `sdmc:/NexvynOS/Users/<başka kullanıcı>` | başka bir kullanıcının dosyaları: yalnızca bir dosya penceresinde sizin seçtiğiniz dosya |

Yollar SD kartın karşılaştırdığı gibi karşılaştırılır (büyük/küçük harf, `..`, `\`, sondaki noktalar); aynı klasörün
başka bir yazımı da reddedilir. Reddedilen yol uygulamaya boş döner ve günlüğüne (`System/Logs/Apps/<id>.log`,
Dosyalar'da okunabilir) bir kez `protected path: ...` yazılır. Yerleşik uygulamalar etkilenmez.

## 2. Yüklemeden önce denetim

**Uygulama Yükleyici** (bir `.nxvapp` dosyası açıldığında): sayfa açıkken Uygulama Koruması paketin metin
kaynaklarını (`.lua`, `.js`, `.py`, `.nut`, `.c`, `.java`, `.json`) arka planda okur ve bir kart gösterir:

- **Sorun bulunmadı**: şüpheli bir şey yok (*Ayrıntıları Göster*'in arkasında notlar olabilir).
- **Gözden geçirin**: bakmaya değer bir şey var; örneğin `.nro` dosyası yazan ya da çalışırken kod oluşturan bir
  uygulama.
- **Tehlikeli**: size ya da verilerinize zarar verebilecek kod. *Yükle* düğmesi **Yine de Yükle** (*Çalıştır* da
  **Yine de Çalıştır**) olur; bu düğme nedenleri listeleyip bir kez daha sorar.

**Uygulama Mağazası**: izin sayfası, mağazanın kendi kataloğundaki uygulamalar için **Nexvyn OS tarafından incelendi**
der. Her indirme yüklenmeden önce aynı şekilde taranır; Tehlikeli olan **Yine de Yükle** onayını bekler.

Bunu *Sistem Ayarları > Gizlilik ve İzinler > Uygulama Koruması > Yüklemeden önce uygulamaları tara* ile
kapatabilirsiniz.

### Tarama neye bakar

| Bulgu | Düzey |
|---|---|
| Nexvyn OS'un özel verilerine ya da başka uygulamaların verilerine giden yollar, network izniyle ("verilerinizi gönderebilir") | Tehlikeli |
| Aynısı network izni olmadan | Gözden geçirin |
| Konsolun anahtar dosyaları (`prod.keys`, `title.keys`), network izniyle / izinsiz | Tehlikeli / Gözden geçirin |
| Custom firmware, bootloader ya da `.nro` dosyaları, Overlay, başka uygulamaların klasörleri | Gözden geçirin |
| İndirilip çalıştırılan kod (`net.*`, `fetch`, `urlopen` sonucunun `load`, `eval`, `Function`, `exec`'e verilmesi) | Tehlikeli |
| `load` / `eval` / `exec` içinde kodlanmış bir bloktan (base64, hex, escape dizileri) çözülen kod | Tehlikeli |
| Dinamik kodun yanında uzun kodlanmış bir blok; Lua `string.dump` | Gözden geçirin |
| Ağı kullanan bir uygulamada yazılanların (`e.text`, `e.key`) toplanması | Gözden geçirin |
| Web hizmetlerinin kullanmadığı bir port'a raw socket (CPython uygulamaları) | Gözden geçirin |
| Network izni olan bir uygulamada dinamik kod | Gözden geçirin |
| Ağ olmadan dinamik kod, kodun hiç kullanmadığı bir izin, izin listesi olmayan paket, Uygulama Koruması'nın okuyamadığı kod (jar, native module, `.pyc`), okunamayacak kadar büyük dosyalar | Not |
| Paketin karması Uygulama Mağazası'nın engel listesinde | Tehlikeli |

Statik denetim davranışı değil niyeti okur: bazı şeyleri kaçırabilir; "Sorun bulunmadı" bir söz değildir. Verilerinizi
asıl koruyan, yukarıdaki korunan klasörlerdir.

### Engel listesi (blocklist)

Uygulama Mağazası kataloğu, zararlı olduğu bilinen paketleri SHA-256 değerleriyle bildirebilir (`security.blocklist`,
[NXVAPP_FORMAT.tr.md](NXVAPP_FORMAT.tr.md) bölüm 6). Uygulama Koruması bu listeyi Uygulama Mağazası'nın en son
önbelleğe aldığı katalogdan okur ve listedeki paketi, yüklemeden önce de yüklü uygulamalar arasında da Tehlikeli
gösterir (Nexvyn OS her uygulamanın yüklendiği paketin karmasını hatırlar).

**Uygulama Koruması yalnızca uyarır.** Bir uygulamayı asla kapatmaz, kaldırmaz ya da engellemez; internetten gelen
hiçbir şey de bunu yaptıramaz. Karar sizindir.

## 3. Yüklü uygulamaları denetleme

*Sistem Ayarları > Gizlilik ve İzinler > Uygulama Koruması > Yüklü uygulamaları tara*, SD karttaki her uygulamayı
denetler ve her birini düzeyiyle listeler. *Ayrıntıları Göster* bulguları (dosya ve satır) listeler, *İzinler*
aşağıdaki izin anahtarlarına götürür, *Kaldır* uygulamayı kaldırır. **Tara**'ya basmadıkça hiçbir şey taranmaz.

## 4. Sistem dosyaları salt okunur

Nexvyn OS'un yönettiği dosyalar, yani eklenti klasörleri `Library` (yazı tipleri, diller, duvar kâğıtları, sesler) ve
`Fonts` dışında `sdmc:/NexvynOS/System`, açılıp kopyalanabilir ama değiştirilemez:

- **Dosyalar** bir kilit ve "Sistem dosyası — Nexvyn OS tarafından yönetilir" gösterir; yeniden adlandırma, taşıma,
  silme, yapıştırma ve yeni öğe kapalıdır.
- **Terminal** içine `touch`, `mkdir`, `rm`, `rmdir`, `cp`, içine ya da dışına `mv`, `>` yönlendirmeleri ve indirmeleri
  reddeder (dışına `cp` çalışır).
- Dosya pencereleri oraya kaydetmez; **Metin Düzenleyici** ve **Kod Düzenleyici** bu dosyaları salt okunur açar
  (Farklı Kaydet çalışır).

Geliştiriciler kilidi *Sistem Ayarları > Geliştirici > Sistem düzenlemelerine izin ver* ile kaldırabilir (varsayılan
kapalı). Nexvyn OS kendi ayarlarını ve günlüklerini her durumda yazar.

## 5. Ayar anahtarları

| Anahtar | Varsayılan | Anlamı |
|---|---|---|
| `appguard.scanBeforeInstall` | `true` | yükleme sayfalarında ve Uygulama Mağazası indirmelerinde paketleri tara |
| `developer.allowSystemEdits` | `false` | Dosyalar, Terminal ve düzenleyiciler `sdmc:/NexvynOS/System` klasörünü değiştirebilir |

Yüklü paketlerin karmaları `sdmc:/NexvynOS/System/Config/appguard.json` içinde tutulur.
