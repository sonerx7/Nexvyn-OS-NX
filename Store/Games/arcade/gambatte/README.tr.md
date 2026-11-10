# Oyun kütüphaneli Game Boy (Gambatte)

Nexvyn OS penceresinde çalışan Game Boy / Game Boy Color öykünücüsü (Gambatte, Native SDK 1.1); Nexvyn öykünücülerinin ortak oyun kütüphanesi var: oyunların
kapak, ayrıntı, favori, arama, ayarlar, durum kaydı ve dokunmatik tuşlarla ızgara ya da liste olarak görünür. Ayrı kurulan, ayrı bir
programdır; Nexvyn OS'un parçası değildir.

## Kendi oyunlarını getir

**Pakette oyun ve BIOS yoktur.** Kendi oyun dosyalarını (.gb, .gbc) `sdmc:/NexvynOS/Roms/gb/` klasörüne kopyala (bilgisayardan ya da
bir dosya yöneticisiyle), ya da Ayarlar > Kütüphane'den başka bir klasör seç, ya da boş kütüphane ekranından tek bir dosya seç. Yalnızca
yasal olarak sahip olduğun oyunları oyna. Zip ve 7z arşivleri açılmaz: önce oyunu çıkar. Oyunların kopyalanmaz, değiştirilmez.

- **Kapaklar:** önce üretilmiş bir başlık kartı; oyunu oynadıktan sonra oyunun kendi ilk karesi. İnternetten kutu resmi (herkese açık
  libretro küçük resim sunucusu) **ilk açılışta sorulur (Evet / Hayır / Sonra), Ayarlar > Kütüphane'den değiştirilir**; açıkken uygulama o sunucudan her
  oyunun kutu resmini, oyun içi görüntüsünü ve başlık görüntüsünü ister (dosyanın CRC32'siyle yerleşik listeden, yoksa dosya adıyla eşleşir) (2 saniyede bir istek, arka planda; sunucu oyunun adını görür), resimleri SD kartta saklar, hesap ya da anahtar
  kullanmaz, ağ yoksa mesaj gösterir.
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
- **Kayıtlar:** oyunun kendi kaydı (pil RAM'i) uygulamanın veri klasörüne yazılır ve oyundan çıkınca korunur; durum kayıtlarının menüde
  yuvaları vardır.

## Lisans ve emeği geçenler

- **Çekirdek:** Gambatte, kaynak `https://github.com/libretro/gambatte-libretro`, commit `77f2567d718b`, lisans **GPL-2.0-only**; telif sahipleri ve lisans metninin tamamı uygulamada
  (Ayarlar > Hakkında > Lisans metni) ve `data/licenses/` içinde.
- **Arayüz ve port:** sonerx7 (https://github.com/sonerx7), GPL-3.0-or-later.
- **Simge:** bu paket için Nexvyn OS projesi çizdi (sade bir kumanda silüeti, hiçbir şirketin logosu yok); bu projenin yeniden dağıtılabilir kendi logosu yoktur.
- **BIOS, sistem yazılımı ya da ticari oyun dahil değildir; yasal yoldan edindiğin kendi dosyalarını ekle.**

## İçindekiler

| Parça | Lisans | Kaynak |
|---|---|---|
| Gambatte (öykünme çekirdeği, değiştirilmemiş) | GPL-2.0-only | https://github.com/libretro/gambatte-libretro (commit `77f2567d718b`) |
| Dear ImGui (arayüz) | MIT | https://github.com/ocornut/imgui |
| stb_image (isteğe bağlı kutu resmi için PNG çözücü) | MIT / kamu malı | https://github.com/nothings/stb |
| Arayüz, çekirdek arayüzü ve build dosyaları | MPL-2.0 | Bu portun Nexvyn OS Native Kit kaynakları |

Çekirdeğin kaynak dosyaları değiştirilmemiştir (0 yama satırı). Paket lisans metinlerini `data/licenses/` içinde taşır. Kapak resmi pakete
konmaz ve dağıtılmaz.
