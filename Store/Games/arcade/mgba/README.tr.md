# Oyun kütüphaneli mGBA

Nexvyn OS penceresinde çalışan hızlı ve doğru bir Game Boy Advance öykünücüsü (Native SDK 1.1); kendi oyun kütüphanesi var:
oyunların kapak, ayrıntı, favori, arama, ayarlar, durum kaydı ve dokunmatik tuşlarla ızgara ya da liste olarak görünür. Ayrı
kurulan, ayrı bir programdır; Nexvyn OS'un parçası değildir.

## Kendi oyunlarını getir

**Pakette oyun ve BIOS yoktur, gerekmez de.** Kendi `.gba` dosyalarını `sdmc:/NexvynOS/Roms/gba/` klasörüne kopyala (bilgisayardan
ya da bir dosya yöneticisiyle), ya da Ayarlar > Kütüphane'den başka bir klasör seç, ya da boş kütüphane ekranından tek bir dosya
seç. Yalnızca yasal olarak sahip olduğun oyunları oyna. Yeni kurulumda bu yardımla birlikte boş kütüphane görünür. Oyunların
kopyalanmaz, değiştirilmez.

- **Kapaklar:** önce üretilmiş bir başlık kartı; oyunu oynadıktan sonra oyunun kendi ilk karesi. İnternetten kutu resmi
  (herkese açık libretro küçük resim sunucusu) **varsayılan olarak kapalıdır**; Ayarlar > Kütüphane'den açarsan uygulama o
  sunucudan tanıdığı her oyunun resmini ister (2 saniyede bir istek, arka planda; sunucu oyunun adını görür), resimleri SD kartta
  saklar, hesap ya da anahtar kullanmaz, ağ yoksa mesaj gösterir.
- **Ad ve ayrıntılar:** oyunlar CRC32 ile libretro-database'den üretilmiş küçük paketli indeksle tanınır (ad, yıl, yayıncı, tür);
  tanınmayanlar temizlenmiş dosya adını kullanır. Oyunun adını ve açıklamasını düzenleyebilirsin.
- **Ana sayfa:** solda bir şerit (Tümü, Favoriler, Son oynanan, ardından oyun sayılarıyla sistemler), arama ve sıralamalı (ad, son oynanma,
  oynama süresi) daha büyük kapaklı ızgara ya da liste, seçili oyun için ayrıntı bölmesi: kapak, ad, sistem, oynama süresi, son oynanma,
  dosya boyutu, açıklama, büyük Oyna düğmesi, favori, oyun ayarları, bilgi düzenleme ve oyunun ekran görüntüleri (birine tıklayınca
  büyür; silebilir ya da kapak yapabilirsin).
- **Kontroller:** yön tuşları gezer, `A` oynar, `Y` favori, `X` oyun ayarları, `L` / `R` kitaplık görünümü, `ZL` / `ZR` ekran görüntüleri
  arasında gezer, `-` sırala, `R3` yeniden tara, `+` ayarlar. Oyunda (tüm kombinasyonlar Ayarlar > Kontroller'den, her oyun ya da tek oyun
  için değiştirilebilir): `+` ve `-` birlikte menüyü açar (devam, durum kaydet, durum yükle, ekran görüntüsü, yeniden başlat, listeye dön);
  `ZL` + `-` hızlı kayıt, `ZR` + `-` hızlı yükleme, `L3` + `-` ekran görüntüsü, sağ çubuğa basmak hızlı ileri sarmayı açıp kapar.
  Ekrana dokununca dokunmatik tuşlar çıkar.
- **Ekran görüntüleri:** kısayol ya da duraklatma menüsü, oyunun gösterdiği görüntüyü küçük bir PNG olarak kaydeder
  (`.library/shots/<oyun>/NN.png`, oyun başına en çok 12; izin verirsen en eskisi değiştirilir); SD kartta kalır, hiçbir yere gönderilmez.
- **Ayarlar:** Görüntü (boyut, filtre, şekil, ekran efekti, kenar kırpma, kare atlama, el konsolu / dock hazır ayarları), Ses, Kontroller
  (yerleşim, ölü bölge, turbo, tuş eşleme, kısayollar), Kayıtlar (yuvalar, otomatik durum, ekran görüntüsü sınırı), Öykünme (BIOS, hızlı
  ileri sarma hızı, çekirdekte varsa bölge) ve Kütüphane. Her oyun bunların her birini kendisi için değiştirebilir (Oyun ayarları).

## Önceki mGBA paketinden güncelleme

Daha önce seçtiğin oyun (`rom.gba`) kütüphanede "Önceki sürümden oyun" olarak, pil kaydı `rom.sav` ile görünür. Kayıtların korunur.

## Lisans ve emeği geçenler

- **Çekirdek:** mGBA 0.10.5, kaynak https://github.com/mgba-emu/mgba, commit `26b7884bc25a`, lisans **MPL-2.0**; telif sahipleri ve lisans
  metninin tamamı uygulamada (Ayarlar > Hakkında > Lisans metni) ve `data/licenses/` içinde.
- **Arayüz ve port:** sonerx7 (https://github.com/sonerx7), GPL-3.0-or-later.
- **Simge:** mGBA projesinin özgün simgesi (mGBA kaynağındaki `res/mgba-1024.png`, MPL-2.0; yalnızca ölçeklendi ve arka plan ışıltısı eklendi).
- **BIOS, sistem yazılımı ya da ticari oyun dahil değildir; yasal yoldan edindiğin kendi dosyalarını ekle.**

## İçindekiler

| Parça | Lisans | Kaynak |
|---|---|---|
| mGBA 0.10.5 (öykünme çekirdeği, değiştirilmemiş) | MPL-2.0 | https://github.com/mgba-emu/mgba (etiket `0.10.5`, commit `26b7884bc25a`) |
| blip_buf (ses yeniden örnekleyici, mGBA'nın parçası) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (ayar okuyucu, mGBA'nın parçası) | BSD-3-Clause | https://github.com/benhoyt/inih |
| Dear ImGui (arayüz) | MIT | https://github.com/ocornut/imgui |
| stb_image (isteğe bağlı kutu resmi için PNG çözücü) | MIT / kamu malı | https://github.com/nothings/stb |
| Arayüz, çekirdek arayüzü ve build dosyaları | MPL-2.0 | Bu portun Nexvyn OS Native Kit kaynakları |

mGBA'nın kendi kaynak dosyaları değiştirilmemiştir (0 yama satırı). Paket lisans metinlerini `data/licenses/` içinde taşır. Ad
indeksi libretro-database'den ad, yıl, yayıncı ve tür listeler; kapak resmi pakete konmaz ve dağıtılmaz.
