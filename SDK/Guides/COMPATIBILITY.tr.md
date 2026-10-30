# Uygulama uyumluluğu: sürümler, targetSdk, deprecation

**Türkçe** · [English](COMPATIBILITY.en.md)

> **Söz.** Bugün Nexvyn OS'ta çalışan bir uygulama sonraki her Nexvyn OS'ta da çalışır: sistem güncellemesinden, yeni
> bir SDK'dan, eklenen ya da değiştirilen bir dil runtime'ından veya bir API değişikliğinden sonra da. Bu sayfa o sözün
> arkasındaki sözleşmedir; sistemi değiştirenler ve uygulama yazanlar için.

## 1. Üç sürüm numarası

| Numara | Nerede | Örnek | Anlamı |
|---|---|---|---|
| **Nexvyn OS** | Makefile'daki `APP_VERSION`, Ayarlar > Hakkında | `1.0.0` | sistem sürümü (semver: major.minor.patch) |
| **SDK** | `NEXVYN_SDK_VERSION` (`source/core/sdk_version.h`), `sys.sdkVersion()` | `1.6` | uygulamaların üzerine kurulduğu API yüzeyi (major.minor) |
| **Runtime motoru** | `nxvruntime::kRuntimes` (`source/runtimes/runtime_kind.h`) | pocketpy `2.2.0` | bir uygulama dilinin arkasındaki yorumlayıcı ya da derleyici |

Hangi değişiklik neyi artırır:

| Değişiklik | Nexvyn OS | SDK |
|---|---|---|
| hata düzeltmesi, çeviri, yeni yerleşik uygulama, görünüm | patch (`1.0.1`) | — |
| yeni SDK fonksiyonu, modül, isteğe bağlı parametre, izin, app.json alanı veya runtime (ekleme) | minor (`1.1.0`) | minor (`1.7`) |
| var olan bir fonksiyonun **davranışı değişir** (yalnızca yeni SDK'yı hedefleyen uygulamalar için, kural 2) | minor ya da major | major (`2.0`) |
| uygulamaların fark edebileceği bir runtime motoru yükseltmesi (kural 5) | minor | — (compat suite karar verir) |
| bir fonksiyonu ya da runtime'ı kaldırmak | asla (kural 1 ve 5) | asla |

### SDK sürümleri

Şimdiye kadarki her SDK sürümü, ilk herkese açık sürüm olan Nexvyn OS 1.0.0'ın geliştirilmesi sırasında geldi;
1.0.0'da SDK 1.6 vardır.

| SDK | İlk Nexvyn OS | Ekledikleri |
|---|---|---|
| 1.0 | 1.0.0 | Lua runtime'ı: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | 1.0.0 | JavaScript runtime'ı (QuickJS-ng), Promise'ler; `g3d` dokuları GPU'da |
| 1.2 | 1.0.0 | `nexvyn.game` motoru, `sys.sdkVersion()`, app.json `minSdk` ve `permissions`, `.nxvapp` v2 |
| 1.3 | 1.0.0 | Python runtime'ı (pocketpy) |
| 1.4 | 1.0.0 | bütün izinler zorunlu, paylaşma, zamanlanmış bildirimler, `nxv://` bağlantıları, yaşam döngüsü callback'leri |
| 1.5 | 1.0.0 | Squirrel, C (TinyCC) ve Java (miniJVM) runtime'ları; Python sistem kütüphanesi |
| 1.6 | 1.0.0 | `fs.unzip`, `sys.games` ve `"games"` izni, metin okuma; `"python3"` runtime'ı (CPython 3.12) |

Sürüm sürüm bütün fonksiyonlar SDK başvurusundadır (`sdk/SDK.tr.md`, "SDK sürümleri").

### Runtime'lar

| `"runtime"` | Nexvyn OS 1.0.0'daki motor | SDK'dan beri |
|---|---|---|
| `"lua"` (varsayılan) | Lua 5.4.7 | 1.0 |
| `"js"` | QuickJS-ng 0.17.0 | 1.1 |
| `"python"` | pocketpy 2.2.0 | 1.3 |
| `"python3"` | CPython 3.12.16 | 1.6 |
| `"squirrel"` | Squirrel 3.2 | 1.5 |
| `"c"` | TinyCC 0.9.28rc | 1.5 |
| `"java"` | miniJVM 2.2.0 | 1.5 |

## 2. Uygulamanın app.json'da bildirdikleri

```json
{
  "minSdk": "1.4",
  "targetSdk": "1.6",
  "runtime": "python",
  "runtimeVersion": "2.2"
}
```

- **`minSdk`**: uygulamanın çalıştığı en eski SDK. Daha eski SDK'lı bir sistem onu kurmaz.
- **`targetSdk`**: uygulamanın derlenip test edildiği SDK. Sistem bu uygulama için o SDK'daki gibi davranmayı sürdürür.
  Varsayılanı `minSdk`, ikisi de yoksa `"1.0"` (`minSdk`'den düşük bir `targetSdk`, `minSdk` sayılır). Studio her yeni
  projeye `minSdk` ve `targetSdk` olarak güncel SDK'yı yazar.
- **`runtime`**: dil (varsayılanı ana dosyanın uzantısından; `"python3"` yalnızca adıyla).
- **`runtimeVersion`** (isteğe bağlı): uygulamanın test edildiği motor sürümü. Yoksa `targetSdk` ile gelen motor
  (yukarıdaki tablo). Kurulumda kaydedilir; yalnızca bir motor uygulamaların fark edeceği biçimde değiştiğinde önem
  kazanır (kural 5).

## 3. Kurallar

1. **Her SDK fonksiyonu sonsuza dek kalır.** Hiçbir şey kaldırılmaz. Yerine yenisi gelen bir fonksiyon *deprecated*
   olur: eskisi gibi çalışmayı sürdürür, binding'i `sdkcompat::deprecated(desc, "<api>", "use <yeni api>")` çağırır
   (uygulamanın log'una her çalıştırmada bir kez `deprecated: <api> still works; use ...` yazılır) ve 4. bölümde
   listelenir. Denetleyicilerin mock'ları da onu tutar (compat suite bunu denetler).
2. **Davranış eski bir uygulamanın altında asla değişmez.** Var olan bir fonksiyonun farklı çalışması gerektiğinde yeni
   davranış yalnızca `targetSdk`'si bu davranışı getiren SDK olan uygulamalara uygulanır; diğer bütün uygulamalar eski
   yolda kalır:

   ```cpp
   if (sdkcompat::atLeast(desc, 2, 0)) newBehaviour(); else oldBehaviour();   // ya da sdkcompat::behaves(desc, "2.0")
   ```

   Yerleşik uygulamalar sistemle birlikte gelir ve her zaman güncel davranışı alır. Değişiklik SDK başvurusunda
   "SDK x'i hedefleyen uygulamalar için" diye belgelenir.
3. **Daha yeni uygulamalar sessizce idare edilir; bu sistemin bilmediği bir şey yüzünden reddedilmez.** Bilinmeyen
   app.json alanları yok sayılır. Bilinmeyen bir izin manifest'te kabul edilir ve hiçbir şey vermez
   (`permrules::decide`). Emekliye ayrılmış izin (`"clipboard"`) kabul edilir ve yok sayılır.
4. **Daha yeni bir sistem için yazılmış uygulama bunu söyler.** `minSdk`'si bu SDK'nın üstündeyse ya da `runtime`'ı bu
   derlemenin runtime tablosunda yoksa (`sdkcompat::runnable`):
   - Uygulama Mağazası Al yerine *Bu uygulama Nexvyn OS'un daha yeni bir sürümünü gerektiriyor* gösterir, onu Yeni
     rafına koymaz ve daha yeni sistem isteyen bir **güncellemeyi asla önermez** (kurulu sürüm çalışmayı sürdürür;
     sayfasında *x sürümü daha yeni bir Nexvyn OS gerektiriyor* yazar);
   - kurulum ekranı Kur ve Çalıştır'ı nedeniyle birlikte engeller (*Gereken SDK 1.8, bu sistemde 1.6* ya da *Bu
     uygulama X ile yazılmış; Nexvyn OS'un bu sürümünde bu dil yok*);
   - SD kartta zaten olan bir kopya (elle konmuş ya da sürüm düşürmeden kalmış) Başlatıcı'da kalır ve aynı mesajı ve
     Yazılım Güncelleme düğmesini gösteren bir pencere açar. Asla yanlış yorumlayıcıyla çalıştırılmaz.
5. **Runtime'lar, mağaza uygulamaları onları kullandıkça NRO'dan asla kaldırılmaz.** Yerine gelecek bir motor (ya da
   uygulamaların fark edebileceği bir yükseltme, örneğin yeni bir pocketpy) önce compat suite'ten geçmelidir; bir
   uygulamayı bozarsa eski davranış, `runtimeVersion`'ı (yoksa `targetSdk`'si) değişiklikten eski olan uygulamalar için
   bir shim ile ya da eski motor tutularak sürer. Yeni bir runtime `nxvruntime::kRuntimes`, `tools/sdkinfo.py`, bir
   denetleyici ve bu sayfaya eklenir.
6. **Eski adlar çalışmayı sürdürür** (4. bölüm).

## 4. Deprecated ve adı değişenler (sonsuza dek tutulur)

| Eski | Yerine | Ne zamandan beri | Ne olur |
|---|---|---|---|
| `require("snx.*")` (Lua) | `require("nexvyn.*")` | Nexvyn OS 1.0.0 | aynı modülü yükler; uygulama log'una deprecation notu |
| `"clipboard"` izni | hiçbir şey (`sys.clipboard` izin istemez) | 1.0.0 | kabul edilir, yok sayılır |
| `finder`, `launchpad` uygulama kimlikleri | `files`, `launcher` | 1.0.0 | `sys.launch`, `nxv://` bağlantıları ve kısayollar çözer |
| `sdmc:/SnxOS` ve eski dosya uzantıları | `sdmc:/NexvynOS`, `.nxv*` | 1.0.0 | açılışta bir kez taşınır ve yeniden adlandırılır |
| `"snx-workshop"` projeleri | `"nexvyn-workshop"` | 1.0.0 | Oyun Motoru onları hâlâ açar |

## 5. Compat suite

`tools/compat_check.py`, kullanıcıların sahip olabileceği her uygulamayı runtime'ının denetleyicisinden güncel SDK
mock'larıyla geçirir: yayın deposundaki mağaza uygulamaları, oyunlar ve SDK örnekleri (`Store/Apps`, `Store/Games`,
`SDK/Samples`), yerleşik betik uygulamaları (`romfs/Applications/*.nxvapp`) ve Studio şablonları. Ayrıca runtime'ların
kaydettiği her fonksiyonun denetleyicilerin mock'larında olduğunu (deprecated olanlar dahil) ve `tools/sdkinfo.py`'nin
`sdk_version.h` ve `runtime_kind.h` ile aynı olduğunu denetler.

```
python tools/compat_check.py                     # tools/compat_baseline.json ile karşılaştırır
python tools/compat_check.py --update-baseline   # güncel sonuçları kaydeder (bilinçli bir değişiklikten sonra)
```

Her uygulamanın sonucu `tools/compat_baseline.json`'da tutulur (uygulama başına bir satır). Orada geçen ve şimdi
kalan bir uygulama bir **uyumluluk kırılmasıdır**: çalıştırma başarısız olur. `tools/release.py` yayın deposunu
eşitlemeden önce suite'i çalıştırır ve `--allow-compat-break` verilmedikçe kırılmada durur; CI
(`.github/workflows/ci.yml`) onu yerleşik uygulamalarda çalıştırır, çünkü yayın deposu kaynak deposunun parçası
değildir. Nexvyn OS 1.0.0 baseline'ı: 159 uygulama, 159'u geçiyor.

## 6. Sistem değişiklikleri için kontrol listesi

- **Yeni fonksiyon / modül / izin / app.json alanı**: ait olduğu her runtime'da yazın, denetleyicilerin mock'larına
  ekleyin (eksik olanı suite bildirir), `sdk/SDK.*.md`'de belgeleyin, `NEXVYN_SDK_VERSION`'ı, `tools/sdkinfo.py`'yi ve
  mock'ların `sys.sdkVersion()`'ını artırın, yukarıdaki tablolara bir satır ekleyin.
- **Davranış değişikliği**: `sdkcompat::atLeast` ile koşula bağlayın (kural 2) ve SDK major'ını artırın.
- **Bir fonksiyonun yerine yenisi**: eskisini tutun, binding'inden `sdkcompat::deprecated` çağırın, 4. bölüme ekleyin.
- **Motor yükseltmesi ya da yeni runtime**: `nxvruntime::kRuntimes` ve `tools/sdkinfo.py`'yi güncelleyin, suite'i
  çalıştırın (kural 5).
- **Her yayından önce**: `python tools/compat_check.py` (release.py yapar), katalogda `python tools/catalog_check.py`
  (SDK'nın üstündeki bir `minSdk` / `targetSdk` ve kaydın `minSdk`'sinden yeni bir runtime için uyarır).

## 7. Uygulama geliştiriciler için

- `minSdk`'yi fonksiyonlarını kullandığınız en eski SDK'ya, `targetSdk`'yi test ettiğiniz SDK'ya ayarlayın
  (`sys.sdkVersion()` konsolda hangisinin olduğunu söyler). `targetSdk` yoksa `python tools/nxvapp_pack.py` uyarır.
- Daha yeni bir şeyi yalnızca olduğu yerde kullanmak için `sys.sdkVersion()`'ı ya da fonksiyonun kendisini denetleyin
  (`if g3d.free then`).
- `targetSdk`'yi yükselttiğinizde SDK başvurusundaki "SDK x'i hedefleyen uygulamalar için" notlarını okuyun: kabul
  ettiğiniz davranış değişiklikleri yalnızca onlardır.
- Uygulamanızın log'undaki deprecation notları (Studio'nun konsolu gösterir) neye geçeceğinizi söyler; eski çağrı
  çalışmayı sürdürür.
