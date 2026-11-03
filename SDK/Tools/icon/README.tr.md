# Mağaza ikonu aracı (key art)

[English](README.md) · **Türkçe**

SDK ile yapılan bir oyunun ya da uygulamanın App Market ikonu gerçek bir mağaza key art'ı gibi durmalı: iri bir
kahraman, dramatik ışık, güçlü bir kenar (rim) ışığı, doygun bir palet, derinlik, parlama ve parçacıklar, sıkı bir
kadraj, logo olarak ad. Düz bir gradyan üstünde düz bir sembol asla olmaz. Bu iki betik, oyununuzun kendi modelinden
birkaç dakikada bir tane yapar.

| Adım | Betik | Gereken | Ürettiği |
|---|---|---|---|
| 1. Kahraman | [`hero_render.py`](hero_render.py) | Blender 4.4 ya da daha yenisi (ücretsiz) | `hero.png`: modeliniz poz verilmiş, bir ana ışık, iki renkli rim ışığı ve bir dolgu ışığıyla aydınlatılmış, saydam arka planlı |
| 2. Key art | [`finish_icon.py`](finish_icon.py) | Python 3 + Pillow (`pip install pillow`) | `keyart_1024.png`, `icon_512.png`, `icon.png` (256 x 256) ve `preview.png` |

`finish_icon.py` arka planı (ışıklı gradyan, ışık huzmeleri, bokeh), kahramanın arkasındaki parlamayı, kenarlarındaki
rim vurgusunu, yer ışığını, kıvılcımları, bloom'u, renk ayarını, vinyeti ve başlığı (kalın, dış hatlı, gradyan
dolgulu, bevel çizgili, parlayan, hafif eğik) kurar. `preview.png` ikonu 256, 128 ve 64 px'te köşeleri yuvarlatılmış
olarak koyu ve açık zeminde, bir de gri tonlu gösterir: gri olanda kahraman öne çıkmıyorsa değerler birbirine çok
yakındır.

## Hızlı başlangıç

```sh
# 1. kahraman, oyunun yüklediği modelden (bir aksiyon pozu seçin: bir klip ve bir kare)
blender -b --factory-startup -P SDK/Tools/icon/hero_render.py -- \
    --model MyGame.nxvapp/models/hero.glb --clip Run --frame 6 --look ember --out hero.png

# 2. key art ve bütün boyutlar
python SDK/Tools/icon/finish_icon.py hero.png --title "SKY HOP" --look ember --out art/

# 3. paketin ikonu
copy art/icon.png MyGame.nxvapp/icon.png
```

Model yok mu (bir araç ya da uygulama)? `--hero crystal`, `--hero rocket` ya da `--hero orb` yerleşik bir nesne
çizer; daha iyisi, bir 3D araçta uygulamanızın işini anlatan tek bir nesne yapıp onu çizdirin.

## Görünümler

`--look` iki betiğin renklerini birlikte seçer: `ember` (mor alacakaranlıkta turuncu kahraman), `frost` (koyu mavide
camgöbeği buz), `toxic` (siyahta asit yeşili), `synth` (pembe ve camgöbeği), `gold` (altın huzmeler, sıcak ışık),
`royal` (mor ve altın), `jungle` (koyu yeşilde kehribar), `noir` (siyahta kırmızı). Oyununuzun paletine en yakın
olanı seçin, sonra iki betikteki `LOOKS` tablolarında renkleri değiştirerek ikonun oyununuzun gerçek renklerini
kullanmasını sağlayın.

## Kompozisyon seçenekleri (finish_icon.py)

| Seçenek | Kullanım |
|---|---|
| `--fill 1.05` | kahraman kareden büyük: sıkı kadraj 64 px'te küçük bir bütün figürden iyi okunur |
| `--x 0.55 --y 0.8` | kahramanın durduğu yer (orta x, alt kenar), karenin payı olarak |
| `--frame` | içte bir rozet çerçevesi; büyük `--fill` ve 1'in üstünde `--y` ile baş çerçevenin dışına taşar |
| `--rays 0`, `--sparks 80` | daha sakin ya da daha hareketli arka plan |
| `--tilt -6` | başlık açısı; `--title "ORBIT RUSH"`; yazı istemiyorsanız `--title` vermeyin |
| `--seed 3` | huzme ve kıvılcımların başka bir rastgele dizilişi |

## Örnekler

Tam olarak bu betiklerle yapıldı (komutlar aşağıda), [examples/](examples/) içinde:

| | |
|---|---|
| ![Ember Field](examples/ember-field/icon.png) | **Ember Field** (`SDK/Samples/lua/ember-field` örneği): kendi `pip.glb`'si, *Run* klibinin 5. karesi, `--look ember --frame --fill 1.02 --y 1.04 --title EMBER`. Anten çerçeveden taşar. |
| ![Shard](examples/shard/icon.png) | **Shard** (modeli olmayan bir uygulama): `--hero crystal --look frost --yaw -20`, sonra `--fill 0.9 --y 0.9 --seed 3 --title SHARD`. |
| ![Orbit Rush](examples/orbit-rush/icon.png) | **Orbit Rush**: `--hero rocket --look synth --yaw 30 --camera eye --exposure -0.4`, sonra `--fill 0.95 --y 0.8 --x 0.55 --tilt -6 --title "ORBIT RUSH"`. Burun karenin dışına çıkar: hareket. |

Her klasörde `icon.png` (256), `icon_512.png` ve `preview.png` var.

## Sonucun uyması gereken kurallar

- `source/icon.png` olarak 256 x 256 PNG, kenardan kenara dolu (ikonun gösterildiği yerde köşeler yuvarlanabilir ya da
  kesilebilir; `--mask` yalnızca önizleme içindir).
- Tek kahraman, iri, ortadaki %80'lik alanda (yüz, siluet, logo); en fazla bir iki kelime.
- Açıkça bu oyun: ekran görüntüleriyle aynı kahraman ve renkler. Mağaza kategorisindeki diğer ikonlara benzemez.
- Kendi modelinizden çizilmiş ya da çıktısını yayımlamanıza izin veren bir araçla yapılmış (README'de adını yazın).

Daha fazlası: [AI asistanları için mağaza ikonu görevi](../../AI/tasks/store-icon.tr.md) (görsel üreticiler için
prompt'la) ve [Oyun yap, bölüm 12](../../Guides/MAKE_A_GAME.tr.md).
