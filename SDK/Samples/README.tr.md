# Örnekler

[English](README.md) · **Türkçe**

**24** örnek.

Altı dilde çalışan örnek projeler. Her klasörde `source/` (eksiksiz bir `.nxvapp` paketi), `README.md` (ne öğrettiği, kontroller, çalıştırma), `icon.png`, `store.json` (beş dilde başlık ve açıklama, tür, etiketler, ekran görüntüsü betiği) ve varsa `screenshots/` vardır. `Tools/build_store.py` her örnek için `<slug>.zip` ve Nexvyn OS Studio'nun *Örnekler* bölümünün okuduğu `SDK/samples.json` dosyasını üretir.

Bir örneği denemek için `source/` klasörünü `sdmc:/NexvynOS/Applications/<ad>.nxvapp` olarak kopyalayın ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/<dil>/<ad> --host <konsol-ip>`.

## Lua

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="lua/beatbox/icon.png" width="32"> | [Ritim Kutusu Demosu](lua/beatbox/) | demo | 1.0 | 16 adımlı davul makinesi |
| <img src="lua/effects/icon.png" width="32"> | [Efekt Demosu](lua/effects/) | demo | 1.0 | Plazma, tünel ve yıldız alanı |
| <img src="lua/gestures/icon.png" width="32"> | [Hareketler Demosu](lua/gestures/) | demo | 1.0 | Yakınlaştır, döndür, kaydır, eğ ve titret |
| <img src="lua/hello/icon.png" width="32"> | [Merhaba SDK](lua/hello/) | demo | 1.0 | Lua SDK turu |
| <img src="lua/particles/icon.png" width="32"> | [Parçacık Demosu](lua/particles/) | demo | 1.2 | Yayıcılar, patlamalar ve çekim kuyuları |
| <img src="lua/physics/icon.png" width="32"> | [Verlet Fizik Demosu](lua/physics/) | demo | 1.2 | Halatlar, köprü ve yırtılan kumaş |
| <img src="lua/platformer/icon.png" width="32"> | [Platform Demosu](lua/platformer/) | oyun | 1.2 | nexvyn.game ile eksiksiz bir platform bölümü |
| <img src="lua/scene3d/icon.png" width="32"> | [3B Sahne Demosu](lua/scene3d/) | demo | 1.0 | Dokulu 3D modeller, güneş, sis ve parıltı |
| <img src="lua/synth/icon.png" width="32"> | [Synth Demosu](lua/synth/) | demo | 1.0 | Piyano, dalga biçimleri ve ADSR zarfı |
| <img src="lua/terrain/icon.png" width="32"> | [Arazi Demosu](lua/terrain/) | demo | 1.0 | Üzerinde uçulan, kodla üretilmiş bir ada |
| <img src="lua/ui-gallery/icon.png" width="32"> | [Arayüz Galerisi](lua/ui-gallery/) | demo | 1.0 | Tüm ui bileşenleri ve kodları |

## JavaScript

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="javascript/hello/icon.png" width="32"> | [Merhaba JS](javascript/hello/) | demo | 1.1 | JavaScript SDK turu |
| <img src="javascript/shapes-js/icon.png" width="32"> | [Şekiller JS Demosu](javascript/shapes-js/) | demo | 1.1 | JavaScript ile tüm g3d temel şekilleri |

## Python

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="python/audio-py/icon.png" width="32"> | [Melodi Çalar (Python)](python/audio-py/) | demo | 1.3 | Nota nota melodi çalar |
| <img src="python/hello/icon.png" width="32"> | [Merhaba Python](python/hello/) | demo | 1.3 | Python SDK turu |

## Squirrel

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="squirrel/hello/icon.png" width="32"> | [Merhaba Squirrel](squirrel/hello/) | demo | 1.5 | Squirrel SDK turu |
| <img src="squirrel/snake/icon.png" width="32"> | [Yılan (Squirrel)](squirrel/snake/) | oyun | 1.5 | Klasik oyun: kumanda, klavye ve dokunmatik |
| <img src="squirrel/stopwatch/icon.png" width="32"> | [Kronometre](squirrel/stopwatch/) | uygulama | 1.5 | Turlar, en iyi ve en kötü; kapatınca da korunur |

## C

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="c/hello/icon.png" width="32"> | [Merhaba C](c/hello/) | demo | 1.5 | C SDK turu |
| <img src="c/life/icon.png" width="32"> | [Hayat Oyunu (C)](c/life/) | demo | 1.5 | C ile Conway'in hücresel otomatı |
| <img src="c/tipcalc/icon.png" width="32"> | [Bahşiş Bölüşücü (C)](c/tipcalc/) | uygulama | 1.5 | Hesabı ve bahşişi adilce bölüştür |

## Java

|  | Örnek | Tür | SDK | Özet |
|---|---|---|---|---|
| <img src="java/dice/icon.png" width="32"> | [Zar Atıcı (Java)](java/dice/) | uygulama | 1.5 | d4'ten d20'ye, zar tut, geçmişi sakla |
| <img src="java/hello/icon.png" width="32"> | [Merhaba Java](java/hello/) | demo | 1.5 | Java SDK turu |
| <img src="java/pong/icon.png" width="32"> | [Pong (Java)](java/pong/) | oyun | 1.5 | Konsola karşı, 7 sayıyı alan kazanır |
