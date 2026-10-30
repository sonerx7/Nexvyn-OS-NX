# Nexvyn OS forwarder rehberi

[English](FORWARDER.en.md) · **Türkçe**

Nexvyn OS applet modunda açıldığında Sistem Ayarları > Hakkında ekranındaki **Daha fazla bilgi** düğmesi bu belgeyi açar.

## Kısaca

Nexvyn OS'u Albüm üzerinden açarsanız sistem ona az bellek verir. Tam bellek için iki yol var:

1. **Başlık modu:** Bir oyunu açarken **R** tuşunu basılı tutun. Oyun yerine Homebrew menüsü açılır; Nexvyn OS'u oradan
   başlatın. Ek kurulum gerekmez ve çoğu kullanıcı için önerilen yol budur.
2. **Forwarder:** HOME menüsüne kendi simgesiyle bir "Nexvyn OS" kısayolu kurulur. Simgeye bastığınızda Nexvyn OS doğrudan
   uygulama modunda, tam bellekle açılır.

## Forwarder nedir?

Forwarder, içinde Nexvyn OS'un kendisi olmayan küçük bir NSP'dir. İçinde yalnızca bir yükleyici (nx-hbloader'ın forwarder
sürümü) ve SD karttaki `.nro` dosyasının yolu bulunur. HOME menüsünden açıldığında yükleyici `sdmc:/switch/NexvynOS.nro`
dosyasını uygulama olarak başlatır. Nexvyn OS'u güncellediğinizde forwarder kendiliğinden yeni sürümü açar.

## Üç çalışma biçimi

| | Albüm (applet modu) | Başlık modu (R ile) | Forwarder |
|---|---|---|---|
| Nasıl açılır | Albüm > Homebrew menüsü | Oyunu açarken R basılı | HOME menüsündeki Nexvyn OS simgesi |
| Bellek | Az (bellenime göre birkaç yüz MB) | Tam (yaklaşık 3,2 GB) | Tam (yaklaşık 3,2 GB) |
| Konsolun web applet'i, oyun başlatma | Yok | Var | Var |
| Ek kurulum | Yok | Yok (Atmosphère varsayılanı) | NSP kurulumu ve imzasız içeriği kabul eden yamalar |
| Kurulu bir oyun gerekir mi | Hayır | Evet | Hayır |

Nexvyn OS hangi modda çalıştığını Sistem Ayarları > Hakkında > **Başlatma modu** satırında gösterir. Applet modunda aynı
ekranda o oturumda kullanılabilen bellek de yazar.

## Önce okuyun: güvenlik ve yasal uyarılar

- **Forwarder kurmak risklidir.** Konsol, üreticisinin imzalamadığı NSP'leri normalde çalıştırmaz. Kendi yaptığınız bir
  forwarder'ı açmak için imza denetimini atlayan üçüncü taraf yamalar (genelde "sigpatch" denir) gerekir. Atmosphère
  bunları içermez. Nexvyn OS bu yamaları sağlamaz ve bağlantısını vermez. Bu depodaki araçlar onlara da bellenime
  (firmware) de dokunmaz. Bu yamaları kullanmak sizin kararınız ve sorumluluğunuzdur.
- **Yasaklanma (ban) riski.** İmzasız içerik kurulan bir konsol çevrimiçi hizmetlerden yasaklanabilir. Mümkünse emuMMC
  kullanın ve CFW tarafını çevrimdışı tutun.
- **Anahtarlar.** PC'de NSP yapan araçlar bir `prod.keys` dosyası ister. Bu dosyayı yalnızca kendi konsolunuzdan alın
  (ör. Lockpick_RCM ile). Kimseyle paylaşmayın, internetten indirmeyin, hiçbir siteye yüklemeyin. Nexvyn OS anahtar
  dağıtmaz. `tools/make_forwarder.py` anahtar indirmez, kopyalamaz, NSP'ye koymaz ve değerlerini ekrana yazmaz.
  Yöntem A (sphaira) anahtar dosyası hiç istemez.
- **Korsanlık için değil.** Bu rehber yalnızca Nexvyn OS'u kendi konsolunuzda açmak içindir.
- **İçiniz rahat değilse başlık modunu kullanın.** Başlık modu yama, anahtar ya da NSP gerektirmez ve aynı belleği verir.

## Gerekenler (Atmosphère tarafı)

- Atmosphère ile açılan bir konsol. Güncel sürüm ve emuMMC önerilir.
- Başlık modu için: Atmosphère paketindeki `atmosphere/hbl.nsp`, SD kartın kökünde `hbmenu.nro` ve
  `atmosphere/config/override_config.ini` içindeki varsayılan ayar (`override_any_app=true`, tuş **R**). Bu ayarı
  değiştirmediyseniz hepsi hazırdır.
- Forwarder için ayrıca:
  - NSP kurabilen bir homebrew: [sphaira](https://github.com/ITotalJustice/sphaira) (GPL-3.0) ya da
    [Goldleaf](https://github.com/XorTroll/Goldleaf) (GPL-3.0).
  - İmzasız içeriği çalıştırabilen bir sistem (yukarıdaki uyarıya bakın). Bu olmadan forwarder açılır açılmaz
    "The software was closed because an error occurred." hatasıyla kapanır.
  - Bellenim 12.0.0 veya üstü.
- Nexvyn OS'un SD karttaki yeri README'ye göre `sdmc:/switch/NexvynOS.nro`. Forwarder bu dosyayı açar. Dosyayı başka bir
  yere koyduysanız (ör. `sdmc:/switch/NexvynOS/NexvynOS.nro`) forwarder'ı o yolla yapın.

## Nexvyn OS forwarder kimliği (Title ID)

**`054E5856594E0000`**

- "NXVYN" harflerinin onaltılık (hex) karşılığıdır. Baştaki `05`, forwarder'lar için yaygın kullanılan önektir ve
  resmî yazılımların kimlikleriyle çakışmaz.
- `tools/make_forwarder.py` her zaman bu kimliği kullanır. Aynı kimlikle yeniden kurulan forwarder eskisinin yerine
  geçer; HOME menüsünde ikinci bir simge oluşmaz.
- NTON ile yaparsanız `--id 054E5856594E0000` verin.
- sphaira kendi kimliğini `.nro` yolundan hesaplar (o da `05` ile başlar). Yol aynı kaldıkça kimlik de aynı kalır, yani
  sphaira ile yeniden kurmak da eskisinin üstüne yazar. sphaira'nın forwarder'ını ve bu deponun forwarder'ını birlikte
  kurarsanız iki simge olur; birini silin.

## Yöntem A: konsolda sphaira ile (en kolay)

PC ve anahtar dosyası gerekmez; sphaira gereken anahtarı konsolun kendisinden türetir.

1. sphaira'nın son sürümünü [Releases](https://github.com/ITotalJustice/sphaira/releases) sayfasından indirip SD
   karttaki `switch` klasörüne kopyalayın.
2. sphaira'yı Homebrew menüsünden açın.
3. Homebrew listesinde Nexvyn OS'u seçin, **X** (Options) ile seçenekleri açın ve **Install Forwarder**'ı seçin. Kurulum
   ayarlarda kapalıysa sphaira önce açmanızı ister.
4. Açılan formda adı (Nexvyn OS), yazarı ve simgeyi kontrol edin. Simge `.nro` dosyasından alınır. **Profile Selection**
   kapalı kalabilir. **Create Forwarder**'a basın.
5. HOME menüsünde Nexvyn OS simgesi belirir.

Menü adları sphaira sürümüne göre değişebilir. Bu adımlar sphaira 1.0.8'in kaynak koduna bakılarak yazıldı; Nexvyn OS
ekibi tarafından gerçek konsolda denenmedi.

## Yöntem B: PC'de `tools/make_forwarder.py` ile (sabit kimlik)

Depodaki betik, hacBrewPack ve nx-hbloader tabanlı bir forwarder yükleyicisiyle NSP üretir. Ad "Nexvyn OS"; yazar ve
sürüm Makefile'dan (`APP_AUTHOR`, `APP_VERSION`), simge `docs/forwarder/icon.jpg` dosyasından gelir.

Gerekenler:

- Python 3.8 veya üstü. Pillow yalnızca 256×256 JPEG olmayan bir simge verirseniz gerekir.
- Kendi konsolunuzdan alınmış `prod.keys` (içinde `header_key` ve `key_area_key_application_00` olmalı).
- hacBrewPack. Özgün depo (The-4n/hacBrewPack) artık yayında değil. Kaynak kodu GPL-2.0 lisansıyla
  [rlaphoenix/hacBrewPack](https://github.com/rlaphoenix/hacBrewPack) aynasında duruyor. Windows için hazır
  `hacbrewpack.exe` NTON paketinin içinde (`nton/bin/`) geliyor; NTON'u `pip install nton` ile kurduysanız betik bu
  dosyayı kendisi bulur.
- Forwarder yükleyicisi (stub): `main` ve `main.npdm`. Betik bunları varsayılan olarak NTON deposunun sabit bir
  sürümünden (commit `8e764dc`, Horizon 21 desteği) indirir ve SHA-256 ile doğrular. Kaynağı nx-hbloader ve
  Forwarder-Mod'dur (ikisi de ISC lisanslı). İsterseniz `--stub` ile kendi derlediğiniz bir klasörü ya da başka bir
  adresi verin.

Komut (PowerShell veya Git Bash, deponun kökünde):

```
python tools/make_forwarder.py --keys "C:\Users\<siz>\.switch\prod.keys" --hacbrewpack "C:\araclar\hacbrewpack.exe"
```

Sonuç: `dist/forwarder/Nexvyn OS v<sürüm> [054E5856594E0000].nsp`.

| Seçenek | Ne yapar |
|---|---|
| `--nro-path` | `.nro` başka bir yerdeyse, ör. `sdmc:/switch/NexvynOS/NexvynOS.nro` |
| `--stub` | Yükleyici klasörü ya da adresi (içinde `main`, `main.npdm`) |
| `--icon` | Başka bir simge (256×256 JPEG; Pillow kuruluysa başka biçimler de olur) |
| `--profile-select` | Açılışta kullanıcı seçimi sorulsun |
| `--out` | Çıktı klasörü (varsayılan `dist/forwarder`) |
| `--dry-run` | Yalnızca dosyaları hazırlar, hacBrewPack'i çalıştırmaz, anahtar istemez |

Betiğin yaptıkları:

- `control.nacp` dosyasını baştan yazar: 16 dilin hepsinde ad "Nexvyn OS", kayıt verisi alanı ayrılmaz (Nexvyn OS verisini SD
  kartta tutar), ekran görüntüsü açık, video kaydı kapalı.
- Simgeyi temizler. EXIF gibi ek bilgiler silinir; yoksa HOME menüsünde "?" görünebilir. Simge 16 dilin her biri için
  yazılır.
- `romfs/nextNroPath` ve `romfs/nextArgv` dosyalarına `.nro` yolunu yazar.
- `main.npdm` içindeki kimliği (ACI0 ve ACID aralığı) forwarder kimliğine ayarlar.
- hacBrewPack'i `--nologo` ile çalıştırır. Konsol üreticisinin açılış logosu dağıtılamadığı için açılışta logo yerine
  kısa bir siyah ekran görünür.

## Yöntem C: NTON ile (PC, arayüzlü)

[NTON](https://github.com/rlaphoenix/NTON) (GPL-3.0; Windows kurulum dosyası ya da `pip install nton`) aynı işi bir
arayüzle yapar. Nexvyn OS için sabit kimliği kullanın (D: SD kartın sürücü harfi):

```
nton build "D:\switch\NexvynOS.nro" --id 054E5856594E0000 --name Nexvyn OS --publisher sonerx7 --version 0.2.0 --icon docs\forwarder\icon.jpg
```

`.nro` PC'deyse `--sdmc /switch/NexvynOS.nro` ekleyin. NTON'un istediği `prod.keys` için yukarıdaki anahtar uyarısı aynen
geçerlidir.

## NSP'yi kurmak

1. NSP'yi SD karta kopyalayın.
2. sphaira'nın dosya gezgininde ya da Goldleaf'te NSP'yi seçip kurun.
3. HOME menüsünde Nexvyn OS simgesine basın. Açarken **R**'ye basılı tutmayın; Atmosphère başlık modunu devreye sokup
   Homebrew menüsünü açabilir.
4. Sistem Ayarları > Hakkında > Başlatma modu satırında "Uygulama (tam bellek)" yazmalı.

## Güncelleme

- **Nexvyn OS'u güncellemek için forwarder'a dokunmanız gerekmez.** Forwarder yalnızca `sdmc:/switch/NexvynOS.nro`
  dosyasını açar. Sistem Ayarları > Yazılım Güncelleme bu dosyanın üstüne yazar; elle güncellerken de aynı yere
  kopyalayın.
- HOME menüsündeki sürüm yazısı forwarder'ı yaptığınız andaki sürümdür ve kendiliğinden değişmez. İsterseniz
  forwarder'ı yeni sürümle yeniden yapıp kurun; kimlik aynı olduğu için eskisinin üstüne yazılır.
- Forwarder'ı şu durumlarda yeniden yapın: `.nro` dosyasının yerini değiştirdiyseniz, simgeyi ya da adı değiştirmek
  istiyorsanız, bir bellenim güncellemesinden sonra forwarder açılmıyorsa. Son durumda yükleyicinin yeni bir sürümü
  gerekebilir (bellenim 19 ve 21'de bu oldu).

## Kaldırma

1. HOME menüsünde Nexvyn OS simgesini seçin, **+** ile seçenekleri açın ve yazılımı silin (menü adı bellenime göre
   "Manage Software > Delete Software" ya da "Data Management" olabilir). sphaira ya da Goldleaf'te
   `054E5856594E0000` kimlikli başlığı silmek de olur.
2. Bu yalnızca forwarder'ı siler. Nexvyn OS'un kendisi (`sdmc:/switch/NexvynOS.nro`) ve verileriniz (`sdmc:/NexvynOS/`) yerinde
   kalır; onları da kaldırmak isterseniz elle silin.

## Sorun giderme

| Belirti | Neden ve çözüm |
|---|---|
| Açılır açılmaz "The software was closed because an error occurred." | Sistem imzasız içeriği kabul etmiyor (uyarılara bakın) ya da `prod.keys` konsoldaki bellenimden eski. |
| Siyah ekrandan sonra çöküyor | `.nro` yolu yanlış ya da dosya yok. Forwarder'ı doğru `--nro-path` ile yeniden yapın. |
| Simge "?" görünüyor | Simge JPEG değil ya da içinde EXIF var. Betik bunu temizler; başka araçta `docs/forwarder/icon.jpg` dosyasını verin. |
| Homebrew menüsü açılıyor | Simgeye basarken R basılıydı. |
| Nexvyn OS yine applet modunda | Forwarder yerine Albüm'den açtınız. Hakkında ekranındaki "Başlatma modu" satırına bakın. |

## Neler doğrulandı, neler denenmedi

- **Doğrulandı (PC'de):** betiğin `--dry-run` çıktısı (NACP düzeni, NPDM kimlik yaması, simge, `nextNroPath`) ve
  varsayılan yükleyicinin SHA-256 değerleri. Nexvyn OS'un applet modunu algılaması ve uyarısı derleyici denetiminden geçti.
- **Nexvyn OS ekibi tarafından gerçek konsolda denenmedi:** hacBrewPack ile NSP'nin üretilmesi (gerçek anahtar ister),
  NSP'nin kurulup açılması, `--nologo` ile açılış, simgenin her sistem dilinde görünmesi, sphaira menü adımları,
  forwarder'dan oyun başlatma ve çıkış. Deneyen olursa sonucu GitHub'da bir issue ile bildirin.

## Neden bu araçlar?

- **sphaira:** etkin olarak geliştiriliyor (1.0.8, Ekim 2026), GPL-3.0, konsolda çalışır, anahtar dosyası istemez.
- **NTON:** etkin olarak geliştiriliyor (v3.0.1, Eylül 2026), GPL-3.0; yükleyicisi bellenim 21 için yeniden derlendi.
- **hacBrewPack + nx-hbloader forwarder:** bilinen, açık kaynaklı (GPL-2.0 / ISC) klasik yöntem. Nexvyn OS'a özel sabit
  kimlik ve tekrarlanabilir bir derleme için betikte kullanılıyor. hacBrewPack 2019'dan beri güncellenmiyor ama bu iş
  için yeterli. Betik hacBrewPack'i ayrı bir program olarak çalıştırır; Nexvyn OS deposuna üçüncü taraf ikili dosya
  eklenmedi.
- **Önerilmeyenler:** Switch Army Knife (SAK) kapalı kaynaklıdır ve 2023'te arşivlendi. TooTallNate/switch-nsp-forwarder
  kaynağı görünür ama lisans dosyası yok. Anahtarlarınızı isteyen web tabanlı üreticileri kullanmayın.
