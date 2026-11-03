# AI destekli çalışma: üretilmiş varlık ve koddan konsol oyununa (SDK 1.9)

[English](AI_WORKFLOW.en.md) · **Türkçe**

AI araçları kod yazabilir; 3B model, doku, ses ve key art üretebilir. Hiçbiri Nexvyn OS'u ya da konsolun sınırlarını
bilmez. Bu rehber, ürettiklerinden hızlı yüklenen, NexGFX pbr renderer'la doğru görünen ve denetimlerden geçen bir
oyuna giden yoldur. Her araç için geçerlidir: sohbet asistanları, editörde ya da terminalde çalışan kodlama
asistanları, yerel modeller, metinden ve resimden 3B üreticiler, doku ve materyal üreticiler ve sonuçları
temizlediğiniz alışılmış 3B programları (DCC araçları).

## İçindekiler

1. [AI araçlarından ne beklemeli](#1-ai-araçlarından-ne-beklemeli)
2. [AI asistanıyla kod](#2-ai-asistanıyla-kod)
3. [3B modeller: üreticiden konsola hazır dosyaya](#3-3b-modeller-üreticiden-konsola-hazır-dosyaya)
4. [Dokular ve PBR haritaları](#4-dokular-ve-pbr-haritaları)
5. [Cam, saydamlık ve ışıma](#5-cam-saydamlık-ve-ışıma)
6. [NexGFX'e: ışıklar, gölgeler, yansımalar](#6-nexgfxe-ışıklar-gölgeler-yansımalar)
7. [Ses, ikon ve mağaza görselleri](#7-ses-ikon-ve-mağaza-görselleri)
8. [Haklar ve atıflar](#8-haklar-ve-atıflar)
9. [Yayından önce kontrol listesi](#9-yayından-önce-kontrol-listesi)

## 1. AI araçlarından ne beklemeli

| Araç | İyi olduğu iş | Kullanmadan önce düzeltin |
|---|---|---|
| Kodlama asistanı | Açık bir prompt'tan bütün uygulama, diller arası taşıma, checker çıktısını düzeltme | Uydurma fonksiyonlar, yanlış indeks tabanı, `draw` içinde iş, eksik `TR()` anahtarları |
| 3B model üretici | Nesne, karakter ve set parçalarının ilk hâli | Fazla üçgen, rastgele ölçek ve pivot, birleşik mesh'ler, dokuya işlenmiş ışık, temiz olmayan UV ya da iskelet |
| Doku / materyal üretici | Döşenebilir yüzeyler, PBR setleri (renk, normal, roughness, yükseklik) | 2K-4K boyutlar, DirectX tarzı normal'ler, renk haritasına boyanmış gölgeler |
| Görsel üretici | Key art, başlık arka planı, konsept sayfaları | Size ait olmayan yazı ve logolar, başkasını kopyalayan stil |
| Ses üretici | Müzik yatağı, ortam sesi | Ses yüksekliği, tıkırdayan döngüler, lisans koşulları |

Bu rehberin kuralı: **araç ilk taslağı yapar; onu konsola siz hazırlar ve denetlersiniz.**

## 2. AI asistanıyla kod

SDK, [`SDK/AI`](../AI/README.tr.md) içinde context pack'ler ve görev prompt'ları getirir. Asistana gerçek API'yi,
kuralları (3 sn callback, 64 MB, 60 fps, `TR()`), oyunlar için kalite çıtasını ve mağaza biçimini anlatırlar.

1. **Bağlamı bir kez verin.** `SDK/AI/system-prompt.tr.md` (ya da `.en.md`) ve dil paketi
   (`SDK/AI/languages/lua.tr.md`, `javascript.tr.md`, `python.tr.md` ya da `c.tr.md`). Bağlam uzunsa
   [SDK başvurusunun](../Reference/SDK.tr.md) tamamını ekleyin.
   - Sohbet asistanları: dosyaları bir projeye ya da bilgi alanına ekleyin ya da ilk mesaja yapıştırın.
   - Editörde ya da terminalde çalışan kodlama asistanları: dosyaları deponuzda tutun ve asistanın talimat
     dosyasında (kurallar, hafıza ya da özel talimatlar) adlarını verin, örneğin:

     ```text
     This repository is a Nexvyn OS app. Before writing code, read SDK/AI/system-prompt.en.md and
     SDK/AI/languages/lua.en.md. Use only functions listed there or in SDK/Reference/SDK.en.md.
     After every change run: python SDK/Tools/nxv/nxv.py check MyGame.nxvapp
     Before answering, go through SDK/AI/checklist.en.md.
     ```

   - Yerel modeller (7-14B): yalnızca system prompt ve tek bir dil paketi, en az 8k bağlam; Lua ya da JavaScript
     seçin ve her yanıtı denetleyin.
   - Konsolda: Studio'nun **Yapay zekâya sor** paneli AI Sohbet'te ayarladığınız sağlayıcı ve anahtarı kullanır;
     sorduğunuz dosyayı ekleyin.
2. **Bir görev prompt'uyla isteyin:** `SDK/AI/tasks/` içinden `make-3d-game` (modeller ve pbr renderer),
   `make-game`, `make-social-app` (akış, fotoğraf, kısa video, sohbet), `make-utility`, `port-lua-to-js`,
   `add-language`, `store-listing`, `store-icon`. Her `<...>` yerini doldurun.
3. **Denetle, çalıştır, geri bildir.** `nxv check`'i (ve dil checker'ını) çalıştırın, sonra uygulamayı Studio'da
   açın. Checker çıktısını ya da hata mesajını `SDK/AI/tasks/fix-lua-check.tr.md` ile geri gönderin. Temiz olana
   kadar tekrarlayın.
4. **Görünüş sizin olsun.** Önce sanat yönünü isteyin (system prompt'un 11. kuralı) ve bir örneğin menülerini ya da
   renklerini kopyalayan oyunu kabul etmeyin.
5. **Dört dilde aynı API.** Lua, JavaScript, Python ve C aynı SDK adlarını kullanır; Lua'da işe yarayan bir prompt
   `port-lua-to-js` ya da dil notlarıyla taşınabilir. Squirrel ve Java SDK 1.8'de donduruldu.

Asistana API anahtarı, şifre ya da kişisel veri vermeyin ve böyle değerleri koda yazmasına izin vermeyin.

## 3. 3B modeller: üreticiden konsola hazır dosyaya

Üretilmiş modeller, satın alınmış ya da taranmış her varlık gibi temizlik ister. Bunu bir 3B programında yapın, sonra
dışa aktarın.

### Adım adım

| Adım | Ne yapılır | Neden |
|---|---|---|
| 1. Ölçek | 1 birim = 1 metre. Kapı yaklaşık 2 m, insan 1.7 m, kasa 0.6-1 m. Ölçeği ve dönüşü uygulayın | `g3d` ışıkları, gölge mesafeleri ve `range` değerleri metredir |
| 2. Eksenler | +Y yukarı, model **+Z**'ye bakar (glTF dışa aktarıcıları bunu varsayılan yapar; FBX dosyaları yüklenirken dönüştürülür) | Yan yatan ya da arkasını dönen model kod değil, dışa aktarma sorunudur |
| 3. Pivot | Tabanda, ortada (karakterlerde ayaklar, nesnelerde alt orta) | `g3d.draw(model, x, 0, z)` onu zemine oturtur |
| 4. Üçgenler | Bütçeye indirin: kahraman 3 000-8 000, nesneler 50-1 500, bütün bölüm 20 000-50 000 | 60 fps'de karede 30-60 bin üçgen |
| 5. Parçalar | Yalnızca kendi materyali ya da hareketi olan yerleri ayrı mesh yapın; sabit nesneleri birleştirin | Daha az çizim çağrısı |
| 6. UV'ler | Tek, temiz, üst üste binmeyen bir UV seti (üreticinin UV'leri dağınıksa yeniden açın) | Normal ve occlusion haritaları bunu ister |
| 7. LOD | g3d'de otomatik LOD yok. Büyük sahneler için daha hafif ikinci bir dosya (`tree_far.glb`) çıkarın ve kodda mesafeye göre seçin | Yoksa uzak nesneler yakındakiler kadar tutar |
| 8. Materyaller | Her yüzey türü için açık adlı tek materyal (`Glass`, `Wood_Oak`, `Metal_Frame`) | `g3d.material(model, {...}, "Glass")` tek materyali adıyla değiştirir |
| 9. Işık | Renk haritasına boyanmış ışık ve gölgeleri kaldırın; yalnızca albedo kalsın | Sahneyi pbr renderer aydınlatır; işlenmiş ışık hareket edince yanlış görünür |
| 10. Animasyon | Rig'leyin, klipleri adlandırın (`Idle`, `Run`, `Jump`), constraint ve IK'yi işleyin; karakter için 20-40 kemik | `model:play("Run")`; morph target desteklenmez |
| 11. Dışa aktarma | glTF binary (`.glb`): +Y yukarı, dokular gömülü, modifier'lar uygulanmış, animasyonlar ayrı action. Ya da texture klasörü yanında `.fbx` | En güvenilir biçim `.glb`'dir |

### Oyunda deneyin

Etrafına bir şey kurmadan önce dosyayı bir kez yükleyip gelenleri yazdırın:

```lua
g3d.loadModel("bundle:/models/hero.glb", function(m, err)
  if not m then print(err) return end
  local i = m:info()
  print(i.format, i.triangles, i.materials, i.textures, i.size.w, i.size.h, i.size.d, i.skinning)
  for _, a in ipairs(i.animations) do print(a.name, a.duration) end
end)
```

| Gördüğünüz | Düzeltme |
|---|---|
| Minik ya da dev | 3B programında ölçeği uygulayın, metre olarak dışa aktarın |
| Yan yatmış ya da arkası dönük | +Y yukarı, +Z'ye bakar; dışa aktarmadan önce dönüşü uygulayın |
| Siyah ya da ters yüzler | Normal'leri dışa doğru yeniden hesaplayın; ince yüzeyleri (yaprak, kumaş) çift yüzlü işaretleyin |
| Fazla parlak ya da plastik | Roughness haritası ters (aslında smoothness): dönüştürün (bölüm 4) |
| Kabartılar yanlış yerden aydınlanıyor | Normal haritası DirectX tarzı: yeşil kanalını çevirin (bölüm 4) |
| Soluk renkler | Renk haritası doğrusal veri olarak dışa aktarılmış; sRGB renk olarak aktarın |
| Geç yükleniyor | Doku boyutları: 1024 px ya da altına indirin (bölüm 4) |

## 4. Dokular ve PBR haritaları

pbr renderer metallic-roughness modelini kullanır: base color, normal, metallic, roughness, ambient occlusion ve
ışıma.

| Harita | İçerik | Konsoldaki boyut |
|---|---|---|
| Base color | sRGB renk, ışıksız | 1024 px (kahraman, büyük yüzeyler), 512 px (nesneler) |
| Normal | OpenGL tarzı (yeşil yukarı), tangent space | 1024 px |
| ORM (glTF) | R = occlusion, G = roughness, B = metallic | 512 px |
| MetallicSmoothness (bazı motorların çıktısı) | R = metallic, A = smoothness | 512 px |
| Ayrı AO / Metallic / Roughness | gri tonlama | 512 px |
| Emissive | ışımanın rengi | 512 px |

**glTF (`.glb`)** her haritayı dosyanın içinde taşır; ORM dokusunu dışa aktarıcınız yazar. **FBX** yalnızca bazı
haritaları bağlar; renderer kalanları base color haritasının yanında adıyla bulur: `T_Chair_BaseColor.png` →
`T_Chair_Normal.png`, `T_Chair_AO.png`, `T_Chair_Metallic.png`, `T_Chair_Roughness.png` ya da
`T_Chair_MetallicSmoothness.png`, `T_Chair_Emissive.png`. Düz mesh'ler haritaları `g3d.material` ile alır
(`normalMap`, `metalRoughMap`, `occlusionMap`, `metalSmoothMap`, `emissiveMap`).

SDK'nın doku aracı ([`SDK/Tools/textures`](../Tools/textures/README.tr.md), Pillow'lu Python) alışılmış dönüşümleri
yapar:

```
python SDK/Tools/textures/textures.py check  models/textures                 boyutlar, setler, eksikler
python SDK/Tools/textures/textures.py resize models/textures --max 1024      2K-4K haritaları küçült
python SDK/Tools/textures/textures.py orm  T_AO.png T_Roughness.png T_Metallic.png T_ORM.png
python SDK/Tools/textures/textures.py smoothness T_MetallicSmoothness.png T_Roughness.png --metallic T_Metallic.png
python SDK/Tools/textures/textures.py flipgreen T_Normal_DX.png T_Normal.png  DirectX -> OpenGL normal
```

Her harita belleğe tam boyutta yüklenir; 4096 px'lik bir harita mipmap'ler olmadan 64 MB tutar. Göndermeden önce
küçültün; 720p ekranda fark azdır.

Üretilmiş döşenebilir yüzeyler (taş, ahşap, metal) en iyi düz mesh'lerde çalışır: renk için `mesh:setTexture`, diğer
haritalar için `g3d.material`. Dokunun gerçek boyutunu akılda tutun: 1024 px'lik bir taş dokusu genelde 1-2 m'yi
kaplar.

## 5. Cam, saydamlık ve ışıma

| Etki | 3B programında / dosyada | Kodda |
|---|---|---|
| Kesik (yaprak, çit, ızgara) | glTF alpha mode `MASK` ve alpha cutoff | bir şey gerekmez; MSAA ile kenarlar yumuşar (alpha to coverage) |
| Yarı saydam (duman, hologram, kalın renkli cam) | alpha mode `BLEND` | bir şey gerekmez; opak nesnelerden sonra, arkadan öne sıralı çizilir |
| Kırılmalı ince cam (pencere, şişe, vizör) | glTF `KHR_materials_transmission` (+ `ior`) | ya da `g3d.material(model, {transmission = 0.9, roughness = 0.05, ior = 1.5}, "Glass")` |
| Vernik, ıslak zemin, araba boyası | glTF `KHR_materials_clearcoat` | ya da `{clearcoat = 0.6, clearcoatRoughness = 0.2}` |
| Lamba, ekran, tabela | emissive harita ya da renk; `KHR_materials_emissive_strength` | `{emissive = "#3CC8FF", emissiveStrength = 4}`: 1'in üstü bloom'a girer |

Cama açık adlı ayrı bir materyal verin; modelin geri kalanına dokunmadan kodda değiştirebilirsiniz.

## 6. NexGFX'e: ışıklar, gölgeler, yansımalar

```lua
function app.load()
  if g3d.renderer("pbr") ~= "pbr" then print("basic renderer: no lights or shadows") end
  g3d.shadows({quality = "medium", distance = 20})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.05})
  g3d.environment({cubemap = {"bundle:/sky/px.png", "bundle:/sky/nx.png", "bundle:/sky/py.png",
                              "bundle:/sky/ny.png", "bundle:/sky/pz.png", "bundle:/sky/nz.png"}})
  g3d.loadModel("bundle:/models/room.glb", function(m, err) room = m end)
  g3d.addLight({type = "spot", x = 0, y = 2.8, z = 0, dx = 0, dy = -1, dz = 0, color = "#FFE2B8",
                intensity = 20, range = 8, inner = 30, outer = 50, shadow = true})
end
```

- **Güneş ve gök.** `g3d.light` güneştir (ona doğru yön, ortam, renk); `g3d.environment` ortam ışığını ve
  yansımaları gök ve zemin renklerinden ya da 6 yüzlü bir cube map'ten verir.
- **Yansıma probu.** 3B programında bölümünüzün ortasından bir cube map'in 6 yüzünü çizin (+X, -X, +Y, -Y, +Z, -Z,
  her biri 256-512 px) ve `cubemap` olarak verin. Parlak zeminler, metal ve cam gerçek odayı yansıtır. Gerçek
  zamanlı yansımalar (ekran uzayı ya da düzlemsel) yoktur.
- **İç mekân ışıkları.** Oyuncunun baktığı yerde birkaç nokta ya da spot ışık; odalar için intensity 5-20, `range`
  odadan biraz büyük. Her nesne yakınındaki en güçlü 8 ışığı alır.
- **Gölgeler.** Güneş ve bir spot ışık (`shadow = true`). Yüzeylerde çizgiler görünürse `bias`'ı artırın, gölgeler
  havada duruyorsa azaltın.
- **Bütçe.** `msaa = 0`, `"medium"` gölge, en çok 1024 px dokularla başlayın; ölçün, sonra kaliteyi artırın.

Eksiksiz sahneler [PBR, Işıklar ve Gölgeler örneğinde](../Samples/lua/pbr3d/) ve [tariflerde](RECIPES.tr.md).

## 7. Ses, ikon ve mağaza görselleri

- **Ses.** `sfx` kiti katmanlı efektleri ve müziği tariflerden üretir, dosya gerekmez
  ([Ses tasarımı](SOUND_DESIGN.tr.md)). Üretilmiş ses dosyaları `audio.play` / `audio.music` ile çalışır;
  yüksekliklerini eşitleyin, döngüleri sıfır geçişlerinden kesin.
- **Mağaza ikonu.** Oyunun kendisini gösteren 256x256 key art. Kendi modelinizi ikon aracıyla çizin
  ([`SDK/Tools/icon`](../Tools/icon/README.tr.md)) ya da
  [`SDK/AI/tasks/store-icon.tr.md`](../AI/tasks/store-icon.tr.md) ile bir görsel üretici kullanın. Stil sizin
  seçiminiz; varsayılan clean'dir (yazısız, ölçülü efektler).
- **Ekran görüntüleri.** Beş önerilir; arayüz İngilizce, oynanışın en iyi anlarından
  ([yayımlama rehberi](../Publishing/PUBLISHING.tr.md), bölüm 6).

## 8. Haklar ve atıflar

- Ürettiklerini yayımlamanıza ve satmanıza izin veren üreticileri kullanın; aracı ve tarihi not edin.
- Başkalarının karakterlerini, markalarını, logolarını ya da yaşayan bir sanatçının stilini istemeyin.
- Üretilmiş ve üçüncü taraf varlıkları kaynağı ve lisansıyla mağaza `README.md`'nizde listeleyin. İnceleme listesi
  bunu ister.

## 9. Yayından önce kontrol listesi

- [ ] Modeller: metre, +Y yukarı, +Z'ye bakar, pivot tabanda, üçgen bütçesi içinde, adlı materyaller ve klipler.
- [ ] Dokular: 1024 px ya da altı, OpenGL normal'leri, roughness (smoothness değil), renk haritasında işlenmiş ışık yok.
- [ ] Cam ve ışıma: kendi materyalleri, transmission ya da alpha mode ayarlı, 1'in üstünde ışıma yalnızca parlaması
      gereken yerde.
- [ ] `g3d.renderer("pbr")` denetleniyor ve oyun `"basic"`te de çalışıyor.
- [ ] Kare hızı konsolda, gönderilecek gölge, bloom ve MSAA ayarlarıyla ölçüldü.
- [ ] Kod `nxv check`'ten ve dil checker'ından geçiyor; görünen her metin `TR()` üzerinden.
- [ ] Haklar ve atıflar mağaza README'sinde.

## Ayrıca bakın

[Tarifler](RECIPES.tr.md) · [Oyun yap](MAKE_A_GAME.tr.md) · [Sosyal uygulama yap](MAKE_A_SOCIAL_APP.tr.md) ·
[Grafik, arayüz ve oyun hissi](GAME_FEEL.tr.md) · [Ses tasarımı](SOUND_DESIGN.tr.md) ·
[SDK sürümleri](SDK_VERSIONS.tr.md) · [SDK başvurusu](../Reference/SDK.tr.md) (8b *Modern görüntü*)
