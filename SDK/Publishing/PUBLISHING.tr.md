# Uygulama Mağazası'nda yayımlama

[English](PUBLISHING.en.md) · **Türkçe**

Nexvyn OS Uygulama Mağazası bu depodan beslenir. Her öğe `Store/` altında bir klasördür; `Tools/build_store.py`
paketleri ve `Store/catalog.json` dosyasını üretir, konsoldaki Uygulama Mağazası bu kataloğu
`https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json` adresinden okur.

**Yayımlamak = bakımcının onayladığı bir pull request.** Bu inceleme olmadan hiçbir şey Uygulama Mağazası'na girmez:
her yeni öğe ve her güncelleme birleştirilmeden önce [inceleme listesine](REVIEW.tr.md) göre elle denetlenir.

## Akışın özeti

```
fork  →  Store/<Apps|Games|Themes|Fonts>/<kategori>/<kısa-ad>/ ekle  →  denetimleri çalıştır  →  pull request (şablon)
      →  otomatik denetimler  →  bakımcının incelemesi (sonerx7)  →  merge = yayında  →  Uygulama Mağazası'nda "Yeni"
```

1. GitHub'da `sonerx7/Nexvyn-OS-NX` deposunu **fork** edin, kendi kopyanızı klonlayın ve `app/<kısa-ad>` adlı bir
   branch açın.
2. **Öğenizi** kendi klasörüne **ekleyin** (bölüm 1). Yalnızca kendi klasörünüzü: paket, katalog ve listeler üretilir.
3. **Denetimleri çalıştırın** (bölüm 7): `nxv check`, dil denetleyicisi, `Tools/build_store.py --check`.
4. `main`'e bir **pull request açın**. GitHub [pull request şablonunu](../../.github/PULL_REQUEST_TEMPLATE.md) doldurur:
   öğe nedir, her izin neden gerekli, hangi denetimleri çalıştırdınız, nerede denediniz.
5. Pull request üzerinde **otomatik denetimler** çalışır (katalog, paketler, `catalog_check.py`, Lua / JavaScript /
   Python denetleyicileri). Bildirdiklerini düzeltin; aynı branch'e push edince yeniden çalışırlar.
6. **İnceleme.** Bakımcı (`sonerx7`, bkz. [CODEOWNERS](../../.github/CODEOWNERS)) öğeyi kurup dener,
   [inceleme listesinden](REVIEW.tr.md) geçirir ve onaylar, değişiklik ister ya da gerekçesini yazarak pull request'i
   kapatır. İlk inceleme genellikle birkaç gün sürer.
7. **Merge = yayında.** Bakımcı `build_store.py`'yi çalıştırıp birleştirir. Uygulama Mağazası kataloğu açılışta ve 6
   saatte bir aldığı için öğe birkaç saat içinde her konsolda görünür; 14 gün boyunca **Yeni** etiketi taşır.

## 1. Klasör düzeni

```
Store/
├── Apps/<kategori>/<kısa-ad>/    uygulamalar: productivity, utilities, media, internet, developer, system, switch, other
├── Games/<tür>/<kısa-ad>/        oyunlar: action, arcade, board, cards, casual, puzzle, racing, sports, strategy, word
│   ├── source/                   paket: app.json, main.*, icon.png, lang/*.json, diğer dosyalar
│   ├── store.json                mağaza metinleri, tür, etiketler, ekran görüntüsü betiği
│   ├── README.md                 GitHub'da gezenler için açıklama (İngilizce ve Türkçe)
│   ├── screenshots/1.png ...     3-4 ekran görüntüsü (bakımcı da üretebilir, bölüm 6)
│   ├── icon.png                  build_store.py source/icon.png'den kopyalar
│   └── <kısa-ad>.nxvapp          build_store.py yazar, elle eklemeyin
├── Themes/<kısa-ad>/             source/ (theme.json, duvar kâğıdı [, sounds/]), store.json, icon.png → <kısa-ad>.nxvtheme
└── Fonts/<kısa-ad>/              yazı tipi dosyaları, LICENSE, font.json, store.json, icon.png, screenshots/ → <kısa-ad>.nxvfont
```

`<kısa-ad>` küçük harf, rakam ve `-` olur (`su-takibi`). Bir uygulama klasörünü başlatmak için:
`python SDK/Tools/nxv/nxv.py new lua "Su Takibi" --store --dir Store/Apps/productivity`.

- **Temalar** tema biçimine uyar (`.nxvtheme`, [paket biçiminin](../Guides/NXVAPP_FORMAT.tr.md) 9. bölümü);
  `Store/Themes/tools/gen_themes.py` resmî temaların nasıl yapıldığını gösterir.
- **Yazı tipi paketleri** [paket biçiminin](../Guides/NXVAPP_FORMAT.tr.md) 10. bölümüne uyar: `font.json`
  (`id`, `name`, `family`, `version`, `license`, `styles`, `scripts`, `languages`), `.ttf` / `.otf` dosyaları ve
  lisans metni. Yalnızca lisansı yeniden dağıtıma izin veren yazı tipleri (SIL OFL, Apache 2.0, ...).
- Nexvyn OS'un içinde gelen uygulamaların da mağaza sayfası vardır: `app.json` içeren, `source/` içermeyen bir klasör.
  Bunları yalnızca Nexvyn OS projesi yönetir.

## 2. app.json

| Alan | Kural |
|---|---|
| `id` | Benzersiz, ters alan adı: `com.adiniz.uygulama` (harf, rakam, `.`, `-`, `_`; en çok 128). Güncellemeler bununla eşleşir: **asla değiştirmeyin**. |
| `name`, `description` | `{"en", "tr", "de", "fr", "es"}` dil tabloları (en az İngilizce). `description` kısa bir cümledir; uzun metin `store.json`'a. |
| `version` | `"1.0"`, `"1.2.3"`: noktalı sayılar (`1.10` > `1.9`). Her güncellemede artırın. |
| `author`, `homepage` | Hakkında penceresinde ve Uygulama Mağazası'nda görünür. |
| `category` | `productivity`, `utilities`, `media`, `internet`, `developer`, `system`, `switch`, `other`, `games`. |
| `runtime`, `main`, `mainClass` | Dil (bkz. [Languages](../Languages/README.tr.md)). |
| `minSdk` | Kullandığınız en yeni SDK özelliğinin sürümü. |
| `window`, `gamepad` | Oyunlar: `"gamepad": true`, `"resizable": true`. |
| `permissions` | Aşağıya bakın. Hiçbir şey gerekmiyorsa `[]`. |
| `license` | İsteğe bağlı, kodunuzun SPDX kimliği (`MIT`, `GPL-3.0-or-later` ...); mağaza sayfasında görünür. |

## 3. İzinler (zorunludur)

SD karttan kurulan uygulamalarda her izin **uygulanır**: `app.json`'da olmayan izin hiç verilmez ve çağrı başarısız
olur. `build_store.py`, kodda izin gerektiren bir çağrı bulup bildirimini göremezse durur.

| İzin | Gerektiren |
|---|---|
| `network` | `net.*` (JS `net.fetch`, C `net_*`, Java `Net.*`) |
| `files` | uygulamanın kendi klasörleri dışındaki yollar |
| `launch` | `sys.launch(başkaId)`, `sys.open("nxv://...")` |
| `notifications` | `sys.notify`, `sys.schedule` |
| `games` | `sys.games` (SDK 1.6) |

Yalnızca kullandığınızı isteyin ve nedenini pull request'te yazın: kullanıcı izinleri kurulumda onaylar, inceleme de
açıklanmayan izinleri geri çevirir. `ui.openFile` / `ui.saveFile` ile seçilen dosyalar izin istemez. C ve Java
uygulamaları korumalı alanda çalışmadığı için kullanıcıya ayrıca sorulur.

## 4. Simge ve README

- `source/icon.png`: 128×128 ya da 256×256, saydam PNG. Yerleşik stilde:
  `python SDK/Tools/nxv/nxv.py icon water_drop "#5AC8FA" "#0A6CFF" <klasör>/source/icon.png --sdk <kaynak deposu>`.
- `README.md`: başlık `# English Name / Türkçe Ad`, iki dilde bir iki cümle, kimlik / dil / SDK / izinler tablosu,
  kontroller, sürüm tablosu ve sizin yapmadığınız her şeyin lisansı.

## 5. store.json

```json
{
  "kind": "app",
  "tags": ["water", "health", "reminders"],
  "subtitle": {"en": "Drink enough every day", "tr": "...", "de": "...", "fr": "...", "es": "..."},
  "description": {"en": "Two or three sentences.\n\n• Bullet\n• Bullet", "tr": "...", "de": "...", "fr": "...", "es": "..."},
  "age": "everyone",
  "shots": [["wait 3"], ["wclick 0.5 0.3", "wait 1.5"], ["key right", "wait 1"], ["dark 1", "wait 1.5"]]
}
```

- `subtitle` (en çok 45 karakter) ve `description`: **İngilizce zorunludur**, Türkçe şiddetle önerilir; Almanca,
  Fransızca ve İspanyolca (ve Japonca, Çince, Korece) yazabiliyorsanız ekleyin. Eksik diller İngilizceye düşer.
- `kind`: `app`, `game`, `demo` ya da `template`. `tags`: küçük harfli arama sözcükleri. `featured`'ı bakımcı açar.
- `age`: içerik notu. `everyone` (varsayılan) ya da `teen` (hafif şiddet, korkutucu temalar, kullanıcıların ürettiği
  web içeriği). Yalnızca yetişkinlere yönelik içerik kabul edilmez.
- `shots`: 3-4 çekim; her çekim o görüntüden önce çalışan adımların listesidir (`wait <sn>`, `wclick <fx> <fy>`,
  `wmove <fx> <fy>`, `key <ad>`, `dpad <yön>`, `text <metin>`, `dark 0|1`).

## 6. Ekran görüntüleri

`screenshots/1.png` ... uygulamanın penceresinden kırpılır. Kendiniz alın (konsol ya da Ryujinx) ya da bakımcı Nexvyn
OS kaynak deposunda `python tools/store_shots.py --only <kısa-ad>` ile `shots` betiğinizi çalıştırıp üretsin. Kişisel
veri, gerçek ad ya da API anahtarı göstermeyin.

## 7. Denetimler

```
python SDK/Tools/nxv/nxv.py check Store/Apps/productivity/su --sdk <kaynak deposu>   # app.json, izinler, çeviriler, store.json + dil denetleyicisi
python Tools/build_store.py            # paketler, katalog ve listeler (sizin için isteğe bağlı; bakımcı çalıştırır)
python Tools/build_store.py --check    # her şey güncel mi (CI bunu çalıştırır)
```

Dil denetleyicileri kaynak deposundadır: `tools/lua_check.py`, `tools/js_check.mjs`, `tools/py_check.py`,
`tools/rt_check.py` (Squirrel, C, Java) ve katalog için `tools/catalog_check.py`. Java için `app.jar`'ı yeniden
derleyin (`nxv build`).

## 8. İçerik ve kalite kuralları

Listenin tamamı [inceleme listesidir](REVIEW.tr.md). Kısacası şu öğeler **kabul edilmez**:

- çalışmayan, çöken ya da var olan bir öğenin yeni adla kopyası olanlar;
- kötü amaçlı yazılım içeren, ne yaptığını gizleyen, incelenmemiş kodu indirip çalıştıran ya da sistem dosyalarına
  dokunanlar;
- kullanıcıyı izleyen, kişisel veri, API anahtarı ya da parola toplayan, kullanıcıya söylemeden bir şey gönderenler;
- deneyimi bozan reklam gösterenler (tam ekran, aldatıcı ya da dolandırıcılık, kumar, yetişkin içerik reklamları);
- açıklamadığı bir izni isteyenler;
- hakkına sahip olmadığınız kod, görsel, müzik, yazı tipi ya da marka kullananlar: **öğenin sahibi olmalı ya da onu
  yayımlamaya izin veren bir lisansa sahip olmalısınız**; üçüncü taraf parçalar lisanslarıyla README'de listelenir
  (Türkçe yamalardaki YamaNX notları gibi: kim yaptı, nereden geliyor, hangi lisansla);
- yalnızca yetişkinlere yönelik, nefret içeren ya da korsan dahil yasa dışı bir şeyi özendirenler;
- İngilizce metni olmayanlar.

## 9. Güncellemeler

Güncelleme de bir pull request'tir: aynı `id`, daha büyük `version`, README'deki sürüm tablosunda bir satır ve
mümkünse `store.json`'da bir `changelog` (`{"en": "Ne değişti", "tr": "..."}`, "Yenilikler" olarak görünür). Yeni bir
öğe gibi incelenir. Uygulama Mağazası katalogdaki sürüm kurulu sürümden büyükse **Güncelle** gösterir; kurulum yerinde
yapılır ve uygulamanın verileri korunur. Yeni izin ekleyen bir güncellemede kullanıcıya yalnızca yeni izin sorulur.
Daha yeni bir SDK özelliği kullandıysanız `minSdk`'yı yükseltin. `Tools/build_store.py` yayımlanan her sürümü
tarihiyle kaydeder (`Store/dates.json`) ve mağaza sayfası bu sürüm geçmişini gösterir.

## 10. Bildirimler ve kaldırma

- Herkes bir öğeyi mağaza sayfasındaki **Bu Uygulamayı Bildir** ile ya da
  [bildirim formuyla](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml) bildirebilir.
- Bakımcı her bildirime bakar. Kuralları çiğneyen öğe katalogdan kaldırılır (ya da hatalı sürüm bir öncekiyle
  değiştirilir); kötü amaçlı yazılımda ya da hukuki bir sorunda hemen, diğer durumlarda geliştiriciye düzeltme fırsatı
  verildikten sonra (genellikle 14 gün).
- Geliştiriciler kendi öğelerini istedikleri an, klasörü silen bir pull request'le ya da bir issue'da isteyerek
  kaldırabilir.
- Bir öğenin haklarını çiğnediğini düşünen hak sahibi ayrıntılarla bir bildirim açabilir; öğe incelenirken gizlenir.

## 11. İmzalama (isteğe bağlı)

Uygulama Mağazası her indirmeyi katalogdaki `sha256` ile karşılaştırır ve mağaza paketleri `build_store.py` ile
kaynaktan yeniden üretilir; bu yüzden imza gerekmez. Paketi ayrıca kendiniz de dağıtıyorsanız (web sitesi, kendi
kataloğunuz) kaynak deposundaki araçlarla nxvapp anahtarınızla imzalayın:

```
python tools/nxvapp_keygen.py anahtarim.pem                            # bir kez; anahtarı gizli tutun ve yedekleyin
python tools/nxvapp_pack.py Uygulamam.nxvapp --sign anahtarim.pem      # manifest.sha256 + manifest.sig
python tools/nxvapp_pack.py --verify Uygulamam.nxvapp                  # Nexvyn OS'un yaptığı denetim
```

(ya da `python SDK/Tools/nxv/nxv.py pack <klasör> --sign anahtarim.pem --sdk <kaynak deposu>`). Kurulum sayfası
"İmzalayan: AB12:CD34:EF56:7890" gösterir ve sonraki bir güncelleme başka bir anahtarla imzalanmışsa uyarır: her
güncellemeyi aynı anahtarla imzalayın. Anahtarınızın parmak izi katalog kaydında olursa (`signer`, pull request'te
isteyin) Uygulama Mağazası yalnızca o anahtarla imzalı paketleri kurar.

## Ayrıca bakın

- [İnceleme listesi](REVIEW.tr.md): bakımcının onaydan önce denetledikleri
- [Pull request şablonu](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Paket biçimi](../Guides/NXVAPP_FORMAT.tr.md) · [Geliştirici rehberi](../Guides/DEVELOPER_GUIDE.tr.md) ·
  [SDK başvurusu](../Reference/SDK.tr.md)
