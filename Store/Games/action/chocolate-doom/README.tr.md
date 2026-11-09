# Chocolate Doom

1993'ün klasik birinci şahıs nişancı oyun motorunun sadık bir kaynak portu; Nexvyn OS penceresinde çalışır (Native SDK 1.1).
Ayrı kurulan, ayrı bir programdır; Nexvyn OS'un parçası değildir.

## İçindekiler

| Parça | Lisans | Kaynak |
|---|---|---|
| Chocolate Doom 3.1.0 (motor) | GPL-2.0-or-later | https://github.com/chocolate-doom/chocolate-doom (etiket `chocolate-doom-3.1.0`) |
| Freedoom 0.13.0, `freedoom1.wad` (bölümler, görseller, müzik) | BSD-3-Clause | https://github.com/freedoom/freedoom (sürüm v0.13.0) |
| SDL2 ve SDL2_mixer (yalnızca bu uygulamaya bağlı) | zlib | Nexvyn OS Native Kit, devkitPro portlibs |

Paket, lisans metinlerini ve emeği geçenleri `data/licenses/` içinde taşır. Nexvyn OS'un motorda yaptığı değişiklikler
`data/licenses/patches/` içindeki yama dosyalarıdır (yukarıdaki etikete uygularsan bu build'in tam kaynağını elde edersin):
IWAD ayrıca uygulamanın veri klasöründe ve paketin içinde aranır, pencere kapatma düğmesi anında çıkar, oyun kolu varsayılan
olarak açıktır, müzik dosyası uygulama veri klasörüne yazılır.

## Kendi dosyanı getir

Freedoom özgür bir yedek oyundur; uygulama hemen açılır. **Pakette ticari oyun verisi yoktur.** Orijinal oyunu
oynamak için kendi IWAD dosyanı (`doom.wad`, `doom2.wad`, `plutonia.wad`, ...) uygulamanın veri klasörüne koy
(`Users/<kullanıcı>/Library/Application Support/com.nexvyn.port.chocolatedoom`); senin eklediğin IWAD önce kullanılır.

## Kontroller

Oyun kolu (varsayılan açık): sol çubuk yürür, sağ çubuk döner, `ZR` ateş eder, `A` kullanır, `+` menüyü açar. Klavye ve fare
Chocolate Doom'daki gibi çalışır (ayarlar oyunun kendi Setup menüsünde). Ağ oyunu yok.
