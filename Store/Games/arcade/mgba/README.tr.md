# mGBA

Nexvyn OS penceresinde çalışan hızlı ve doğru bir GBA öykünücüsü (Native SDK 1.1). Ayrı kurulan, ayrı bir programdır;
Nexvyn OS'un parçası değildir.

## İçindekiler

| Parça | Lisans | Kaynak |
|---|---|---|
| mGBA 0.10.5 (öykünme çekirdeği, değiştirilmemiş) | MPL-2.0 | https://github.com/mgba-emu/mgba (etiket `0.10.5`, commit `26b7884bc25a`) |
| blip_buf (ses yeniden örnekleyici, mGBA'nın parçası) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (ayar okuyucu, mGBA'nın parçası) | BSD-3-Clause | https://github.com/benhoyt/inih |
| Pencere arayüzü (`main.c`) ve build dosyaları | MPL-2.0 | Bu portun Nexvyn OS Native Kit kaynakları |

mGBA'nın kendi kaynak dosyaları değiştirilmemiştir (0 yama satırı). Paket lisans metinlerini `data/licenses/` içinde taşır.

## Kendi dosyanı getir

**Pakette oyun ve BIOS yoktur, gerekmez de.** İlk açılışta uygulama bir dosya seçici açar: kendi oyun dosyanı (`.gba`) seç.
Bir kopyası uygulamanın veri klasöründe `rom.gba` olarak durur
(`Users/<kullanıcı>/Library/Application Support/com.nexvyn.port.mgba`); pil kaydı `rom.sav` ve durum kaydı `state.ss0` de
orada. Başka oyun için bu klasörden `rom.gba` ve `rom.sav` dosyalarını sil; seçici sonraki açılışta yeniden çıkar. Yalnızca
yasal olarak sahip olduğun oyunları oyna.

## Kontroller

`A` ve `B`, `+` = Start, `-` = Select, yön tuşları, `L` ve `R`; `X` durum kaydeder, `Y` yükler; `ZL` basılı tutulunca 4 kat
hızlı ileri sarar.
