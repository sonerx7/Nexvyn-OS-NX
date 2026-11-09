# Ironwail

1996'nın klasik birinci şahıs nişancı oyunu için hızlı ve modern bir motor; Nexvyn OS penceresinde çalışır (Native SDK 1.1).
Ayrı kurulan, ayrı bir programdır; Nexvyn OS'un parçası değildir.

## İçindekiler

| Parça | Lisans | Kaynak |
|---|---|---|
| Ironwail 0.8.0 (motor, commit `08d578136ff4`) | GPL-2.0-or-later | https://github.com/andrei-drexler/ironwail |
| LibreQuake v0.09-beta lite (bölümler, canavarlar, görsel, ses, müzik) | BSD-3-Clause (`progs.dat`, `pop.lmp`: GPL-2.0) | https://github.com/lavenderdotpet/LibreQuake |
| Tremor ve libogg (Ogg Vorbis müzik, yalnızca bu uygulamaya bağlı) | BSD-3-Clause | https://gitlab.xiph.org/xiph/tremor , https://gitlab.xiph.org/xiph/ogg |
| SDL2 (yalnızca bu uygulamaya bağlı) | zlib | Nexvyn OS Native Kit, devkitPro portlibs |

Paket lisans metinlerini ve emeği geçenleri `data/licenses/` içinde taşır (`SOURCES.txt` tam sürümleri listeler). Nexvyn OS'un
motorda yaptığı değişiklikler pencere için küçük yamalardır (veri ve kayıt klasörleri, `dlopen` yok, ağ soketi yok, bir sürücü
geçici çözümü); yukarıdaki commit'e uygularsan bu build'in tam kaynağını elde edersin.

## Kendi dosyanı getir

LibreQuake özgür bir yedek oyundur. **Pakette ticari oyun verisi yoktur**, oynamak için de gerekmez.

## Notlar

Oyun kolu ve klavye çalışır; ağ oyunu yok. Motor, compute shader'lı OpenGL 4.3 ister (konsolda var); compute desteği olmayan bir
grafik sürücüsü menüyü ve HUD'u gösterir ama 3B dünyayı göstermez.
