# Konsol olmadan app ya da sistem testi

[English](TEST_WORKFLOW.en.md) · **Türkçe**

Bir app'in büyük kısmını PC'de, tekrarlanabilir bir script ile sınayabilirsiniz. Son kontrol yine gerçek konsoldur,
ama bu döngü çökme, donma, bellek sızıntısı ve yerleşim hatalarını erken yakalar. Rehber app yapımcıları ve döngüyü
sizin yerinize çalıştıran AI kod asistanları içindir ([`AI/tasks/test-on-emulator.md`](../AI/tasks/test-on-emulator.md)).

## 1. PC emülatörünü kurun

1. Switch homebrew çalıştırabilen, seçtiğiniz bir PC emülatörünü indirin ve kendi anahtarlarınız ve firmware'inizle
   kurun. Nexvyn bu dosyaları sağlamaz, bağlantı vermez, desteklemez.
2. Elle bir kez açın ve bir homebrew `.nro` dosyasının açıldığını doğrulayın.
3. Kendi kayıtlarınıza dokunmamak için test için ayrı bir emülatör klasörü seçin. Sanal SD kart klasörünün yerini
   not edin: bu rehberde `<SD>` o kökür.

## 2. Dosyaları kopyalayın

- Sistem: `NexvynOS.nro` dosyasını (tek ve güncel dosya; açtığınız klasördeki eski kopyalar yanlışlıkla
  başlatılabilir) `<SD>/switch/` içine kopyalayın ya da emülatör menüsünden doğrudan açın.
- App'iniz: derleyip paketleyin, `.nxvapp` dosyasını `<SD>/NexvynOS/Applications/` içine kopyalayın (ya da
  `python SDK/Tools/nxv/nxv.py install <klasör> --sd <SD>`; native app'ler: kit klasöründen
  `python tools/nxv_native run <app> --sd <SD>`). İmzasız paket uyarıyla kurulur.
- Büyük bir paketin kurulumu bitmeden başlatmayın (55 MB'lık paket birkaç saniye sürer).

### SD kart klasörü

```
<SD>/NexvynOS/
├── autorun.txt             script; dosya durdukça her açılışta çalışır (aşağıya bakın)
├── autoshots/<ad>.png      script'in aldığı ekran görüntüleri
├── System/Config/          settings.json
├── System/Logs/            system.log, Apps/<app id>.log, Crashes/
├── Applications/           kurulu app'ler (.nxvapp)
└── Users/<ad>/             kullanıcının dosyaları
```

İşiniz bitince `autorun.txt` dosyasını silin; yoksa sonraki açılış yine çalıştırır.

## 3. Autorun script'i

`<SD>/NexvynOS/autorun.txt` varsa Nexvyn OS açılıştan sonra komutları sırayla çalıştırır. Satır başına bir komut;
`#` ile başlayan satırlar yorumdur. Tipik script:

```text
setup en
wait 4
launch com.example.myapp
wait 6
shot myapp_start
click 640 360
wait 2
shot myapp_after_click
stats after_click
close
log done
exit
```

### Komutlar

| Komut | Ne yapar |
|---|---|
| `wait <saniye>` | script'i bekletir |
| `setup <dil>` | ilk açılış sihirbazını varsayılanlarla bir dilde çalıştırır (`setup <dil> tour` karşılama turunu da başlatır) |
| `setupstep <dil> <adım>` | sihirbazın bir adımında durur (`intro`, `language`, ... `summary`) |
| `unlock` | kilit ekranını geçer |
| `launch <appId> [arg]` | app açar |
| `close` / `closeall` | odaktaki pencereyi / bütün pencereleri kapatır |
| `minimize` | odaktaki pencereyi küçültür |
| `launcher`, `search <metin>`, `overview` | başlatıcıyı, aramayı, pencere genel görünümünü açar |
| `shot <ad>` | ekran görüntüsünü `autoshots/<ad>.png` olarak kaydeder |
| `click <x> <y>`, `rclick <x> <y>`, `mclick <x> <y>`, `move <x> <y>` | piksel olarak fare girişi |
| `wclick <fx> <fy>`, `wmove <fx> <fy>` | odaktaki pencere içeriğinin bir oranına (0..1) tıklar ya da gider |
| `drag`, `scroll` | sürükleme ve tekerlek girişi |
| `finger <n> down\|move\|up <x> <y>` | bir dokunma teması; iki tanesi birlikte yakınlaştırma, döndürme ya da iki parmak kaydırma yapar |
| `key [ctrl+\|shift+\|alt+]<ad>` | tuşa basar ve bırakır |
| `hold <tuş> <saniye>` | tuşu basılı tutar |
| `text <metin>` | metin yazar |
| `dpad <düğme>` | kol düğmesine basar ve bırakır |
| `padhold <düğme> [saniye]` | kol düğmesini basılı tutar (tam ekrandan çıkış: `minus`, 1,2 sn) |
| `dark <0\|1\|2>`, `lang <kod>`, `langreq <kod>` | görünümü ya da dili değiştirir (`langreq` Ayarlar app'i gibi çalışır) |
| `sleep` / `wake` | sistem gerçekten askıya geçmeden askıya alma ve uyanma adımları |
| `trust <appId>` / `untrust <appId>` | native app'in "Çalıştırılsın mı?" sorusunu sorulmadan yanıtlar ve geri alır |
| `enableall` | her isteğe bağlı app'i birden ekler |
| `tour [start\|end]`, `tourwait <mod>` | karşılama turunu sürer ve bir duruma kadar bekler |
| `winframe` | odaktaki pencerenin çerçevesini loglar |
| `stats [etiket]` | `system.log` içine tek bir `stats` satırı: bellek, pencere, GL nesneleri, mixer, stall, kare süresi |
| `log <mesaj>` | log'a kendi satırınızı yazar; adımları işaretlemek için |
| `exit` | koşuyu bitirir |

Notlar:

- `launchpad`, `spotlight` ya da `mission` kullanan eski script'ler çalışmaya devam eder.
- Script geliştirme içindir. Tıklamadan ya da görüntü almadan önce pencere oluşsun diye `launch` sonrasına kısa `wait` koyun.
- `trust` yalnızca kendi test app'leriniz içindir; test ayarları bulduğu gibi bıraksın diye sonda `untrust` çalıştırın.

## 4. Ekran görüntüleri ve loglar

- Ekran görüntüsü: `shot <ad>` `<SD>/NexvynOS/autoshots/<ad>.png` yazar. Her önemli adımda bir tane alın. Bir iki
  anahtar görüntüye kendiniz bakın; onlarca görüntüyü taramaya çalışmayın.
- Store ekran görüntülerini sistem dili İngilizce iken alın (`lang en`).
- Loglar: `<SD>/NexvynOS/System/Logs/system.log` (sistem ve runtime satırları, `stats`, `stall`, `perf`),
  `System/Logs/Apps/<app id>.log` (app'in yazdıkları) ve `System/Logs/Crashes/` (adresli çökme raporları).
- Aranacak satırlar: `not responding`, `stopped` (çökme pencereyi kapattı), `stall`, `fps`, `heap free`, `module load`,
  `FAIL`, `error`. Dosyayı adıma göre kesebilmek için kendi `log` işaretlerinizi ekleyin.
- Log'u baştan sona değil, arama (`grep`) ile okuyun.

## 5. Konsol profili (yalnızca göreli sayılar)

Modern bir PC konsoldan birkaç kat hızlıdır; CPU sorunu PC'de saklanabilir. **Konsol profili** emülatörü konsola
yaklaştırır:

- emülatörü dört CPU çekirdeğine (farklı fiziksel çekirdekler) sınırlayın, onlara CPU tavanı koyun (örneğin yüzde 60)
  ve düşük öncelikle çalıştırın;
- GPU yükünü konsol seviyesinde tutun: 1x çözünürlük, ek anti-aliasing yok;
- el modunu ve dock modunu ayrı ölçün.

Windows'ta bir job object emülatörün CPU sınırını ve çekirdek ataması tutabilir; diğer sistemlerde `taskset` ve
`nice` karşılığı kullanılır. Sayı kuralları:

- Bir değişikliğin **önce ve sonrasını** aynı profille karşılaştırın: oran ya da ms cinsinden kare süresi.
- **Emülatör fps'ini asla konsol fps'i diye yazmayın.** Konsol sayısı yalnızca konsoldan gelir.
- Taklit edilen donanım, app'in çalıştığı konsoldur. Daha yeni donanım emüle edilemez; o sonuçlar orada geçerli değildir.
- Her ölçümü yazın: profil (tavan, çekirdek, çözünürlük, el ya da dock), sürüm ve ne değişti.

## 6. Uzaktan test kiti (fikir)

Konsol uzaktaysa küçük bir test programı konsolda sabit bir script çalıştırıp sonuçları size gönderebilir:

- Özel bir test build'i ilk satırı `#remote_test` olan script'i çalıştırır. Yalnızca güvenli bir komut alt kümesine
  izin verilir (launch, close, click, key, `stats` ve sonuç komutları) ve dosya okunurken silinir; çökme onu asla
  döngüye sokamaz.
- Script her adımdan önce ilerlemeyi işaretler, her app için kare hızı, stall, çekirdek başına CPU ve belleği ölçer,
  pencerelerin açık ya da kapalı olduğunu denetler ve bir sonuç tablosu (PASS / FAIL / INFO) ile birkaç küçük ekran
  görüntüsü yazar.
- Test programı sonuçları ve logları test sahibinin denetlediği özel bir yere yükler; konsol kullanıcısının hesabını
  istemez ve kişisel veri göndermez.
- Anahtar ve token script'e, dokümana ya da repoya asla yazılmaz.

Aynı fikri kendi app'iniz için kurabilirsiniz: onu çalıştıran bir script, bir sonuç dosyası ve konsolda tek düğmeye
basan bir kişi.

## 7. İki kullanıcı yolu

Her değişiklikte ikisini de deneyin:

1. **Güncelleyen kullanıcı.** Ayarları, kurulu app'leri, teması ve verisi olan bir SD profilinden başlayın; önceki
   kararlı ve önceki beta sürümden. Güncellemeden sonra ayarlar, app'ler, temalar ve veriler yerinde olmalı; yeni
   varsayılan eski seçimi ezmemeli; bir kerelik ekranlar bir kez çıkmalı.
2. **Sıfırdan kurulum.** Temiz profil: ilk açılış sihirbazı, ağ yokken kurulum, varsayılan tema ve ayarlar, önerilen
   app'ler.

App için: önceki sürümün üstüne kurun (veri korunur, veri sürümü işlenir) ve sıfırdan kurun.

## 8. Aç-kapa testi

Thread, zamanlayıcı, bellek ayırma ya da pencere özelliği ekledikten sonra app'i art arda on kez açıp kapatın:

```text
launch com.example.myapp
wait 3
close
wait 1
```

(on kez tekrarlayın, sonra `stats after_10`). `stats` satırını önceden alınanla karşılaştırın: kullanılan bellek,
pencere ve kaynaklar büyümemeli. Donma ya da büyüyen sayı bir hatadır. Şüpheniz sürerse onarlık gruplarla tekrarlayın.

## 9. Temizlik ve görgü

- **SD'yi geri alın.** `<SD>` içinde değiştirdiğiniz her şey geri gider: `autorun.txt` silinir, test app'leri ve test
  verileri kaldırılır, değişen ayarlar eski haline döner, gerekenleri taşıdıktan sonra `autoshots/` boşaltılır. Test
  profili bulduğu gibi bırakmalıdır.
- **Oturumları kısa tutun** (her biri yaklaşık 60 sn altında). Uzun oturumlarda emülatör belleği şişer ve gerçek
  sayıları gizler.
- **Emülatörü küçültülmüş başlatın**, pencere odağını almasın; yaptığınız işin önüne çıkmasın.
- **Aynı anda tek emülatör, tek script.** Bir makineyi birkaç kişi ya da ajan paylaşıyorsa önce kilit alın (SD
  klasörünün yanında sahibi ve zamanı yazan bir kilit dosyası), beklerken emek harcamayın, `finally` içinde bırakın.
  Takılmış bir emülatörü yalnızca kendinizinse kapatın.
- Test profilinde gerçek hesaplarınızı, anahtarlarınızı ya da kayıtlarınızı asla kullanmayın.

## 10. Herkese açık araçlar

| Araç | Döngüdeki işi |
|---|---|
| [`SDK/Tools/nxv`](../Tools/nxv/README.tr.md) | `new`, `check` (manifest, dosyalar, ikon, çeviriler, izinler), `pack`, SD klasörüne `install`, konsola `push` |
| [`SDK/Languages/c/native-kit`](../Languages/c/native-kit/README.tr.md) (`nxv-native`) | native build, `check`, `package`, `run --sd <SD>` |
| [`SDK/Tools/theme`](../Tools/theme/README.tr.md) | tema paketleri için `themecheck.py` |
| [`SDK/Tools/textures`](../Tools/textures/README.tr.md) | PBR doku setlerini denetler ve hazırlar |
| [`SDK/Tools/icon`](../Tools/icon/README.tr.md) | anahtar sanat Store ikonları |

Önce `nxv check`, sonra emülatör döngüsü, sonra konsol.
