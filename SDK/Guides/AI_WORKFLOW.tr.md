# AI destekli iş akışı: SDK 1.9 için modeller, dokular ve kod

[English](AI_WORKFLOW.en.md) · **Türkçe**

Nexvyn OS için 3B model, doku ve kod yaparken AI araçları kullanan geliştiriciler için. İlk yarı, bir AI üreticisinden
ya da bir DCC aracından gelen bir varlığı PBR map'leriyle konsola hazır bir `.glb`'ye (ya da `.fbx`'e) ve pbr
renderer'a taşır. İkinci yarı, [SDK/AI](../AI/README.tr.md)'deki AI kitini kodlama asistanlarıyla kullanır: ne
gönderilir, checker'larla nasıl ilerlenir ve gelen kod nasıl gözden geçirilir. Sayfa haklar ve bir kontrol listesiyle
biter.

Buradaki her şey SDK'yı [SDK başvurusundaki](../Reference/SDK.tr.md) (8b *3B modeller* ve *Modern görüntü*) hâliyle anlatır.
AI araçları fonksiyon, seçenek ve dosya kuralı uydurur; sözleşme başvurudur ve orada olmayan şey yoktur.

## İçindekiler

1. [Akış](#1-akış)
2. [Model dosyaları](#2-model-dosyaları)
3. [Geometri: ölçek, eksenler, pivot, bütçeler](#3-geometri-ölçek-eksenler-pivot-bütçeler)
4. [Dokular ve PBR map'leri](#4-dokular-ve-pbr-mapleri)
5. [Adlar](#5-adlar)
6. [pbr renderer'a](#6-pbr-renderera)
7. [AI asistanıyla kod](#7-ai-asistanıyla-kod)
8. [Ses, ikon ve mağaza görselleri](#8-ses-ikon-ve-mağaza-görselleri)
9. [Haklar ve lisanslar](#9-haklar-ve-lisanslar)
10. [Kontrol listesi](#10-kontrol-listesi)

## 1. Akış

| Adım | Nerede | Sonuç | Denetim |
|---|---|---|---|
| Varlığı yapın ya da üretin | bir AI model ya da doku üreticisi, bir DCC aracı | UV'li bir mesh, belki rig ve klipler | üreticinin koşulları yayına izin veriyor (bölüm 9) |
| Temizleyin | DCC aracınız | gerçek ölçek, +Y yukarı, pivot tabanda, transform'lar uygulanmış, üçgen bütçesi | bölüm 3 |
| Dokulayın | DCC aracı, doku aracı, AI doku üreticisi | base colour, normal, ORM (ya da metallic + roughness), emissive | bölüm 4 |
| Export edin | DCC aracınız | gömülü dokulu `.glb` (ya da `.fbx` + doku klasörü) | bölüm 2 |
| Konsolda bakın | aşağıdaki Model Bench programı | `model:info()`: boyut, üçgenler, materyaller, klipler | bölüm 6 |
| Oyunu ya da uygulamayı yazın | siz, ya da AI kitiyle bir asistan | checker'lardan geçen bir paket | bölüm 7 |

### AI araçlarından ne beklemeli

| Araç | İyi olduğu iş | Kullanmadan önce düzeltin |
|---|---|---|
| Kodlama asistanı | Açık bir prompt'tan bütün uygulama, diller arası taşıma, checker çıktısını düzeltme | Uydurma fonksiyonlar, yanlış indeks tabanı, `draw` içinde iş, eksik `TR()` anahtarları |
| 3B model üretici | Nesne, karakter ve set parçalarının ilk hâli | Fazla üçgen, rastgele ölçek ve pivot, birleşik mesh'ler, dokuya işlenmiş ışık, temiz olmayan UV ya da iskelet |
| Doku / materyal üretici | Döşenebilir yüzeyler, PBR setleri (renk, normal, roughness, yükseklik) | 2K-4K boyutlar, yeşili aşağı (-Y) normal'ler, renk haritasına boyanmış gölgeler |
| Görsel üretici | Key art, başlık arka planı, konsept sayfaları | Size ait olmayan yazı ve logolar, başkasını kopyalayan stil |
| Ses üretici | Müzik yatağı, ortam sesi | Ses yüksekliği, tıkırdayan döngüler, lisans koşulları |

Bu rehberin kuralı: **araç ilk taslağı yapar; onu konsola siz hazırlar ve denetlersiniz.**

## 2. Model dosyaları

| Biçim | Ne için | Notlar |
|---|---|---|
| **`.glb`** (binary glTF 2.0) | her şey; en iyi seçim | mesh'ler, düğüm hiyerarşisi, materyaller, gömülü dokular, iskelet ve klipler tek dosyada |
| `.gltf` + dosyalar | aynısı, açılmış hâlde | resimler `.gltf`'in yanında, dosyanın verdiği adlarla |
| `.fbx` (binary ya da metin, 6.x / 7.x) | yalnızca FBX olarak gelen varlıklar | eksenler ve birimler yüklenirken dönüştürülür; dokular gömülü ya da yanındaki dosyalarda (bölüm 4) |
| `.obj` / `.stl` | durağan mesh'ler | animasyon yok, PBR map'i yok |

Dosya başına sınırlar: 96 MB, 1 000 000 köşe, 1 500 000 üçgen, 20 000 düğüm, iskelet başına 1024 kemik, 4 000 000
animasyon anahtar değeri. Bozuk ya da desteklenmeyen bir dosya yalnızca yüklemenin bir mesajla başarısız olmasına yol
açar; uygulamayı hiçbir zaman çökertmez. Dosyadaki morph target'lar (blend shape), kameralar ve ışıklar yok sayılır,
cubic spline anahtarlar doğrusal oynatılır: şekil animasyonunu, constraint'leri ve IK'yı iskelet kliplerine bake edin,
sahneyi kodda aydınlatın.

## 3. Geometri: ölçek, eksenler, pivot, bütçeler

**Ölçek ve eksenler.** 1 birim = 1 metre (bir insan yaklaşık 1,7 m). glTF +Y yukarıdır; model oyunda **+Z**'ye bakar.
Export'tan önce ölçek ve dönüşü uygulayın; dosyada artık transform kalmasın. `g3d.model(path)` yazıldığı boyutu
korur; `g3d.model(path, size)` en uzun kenarı `size`'a ölçekler, x ve z'de ortalar ve y = 0'a oturtur. Dev, minicik ya
da yatan bir modeli kodda değil export'ta düzeltin.

**Pivot.** Tabanda, ortada: modelin orijini durduğu yerdir. Bir kapı için menteşeye koyun.

**AI ile üretilmiş mesh'ler** kullanılabilir olmadan önce genellikle iş ister: çok fazla üçgen, dağınık ya da olmayan
pivot, renge bake edilmiş ışık, temiz olmayan iskelet, üst üste binen UV'ler. Bütçeye kadar decimate ya da retopoloji
yapın, pivotu ayarlayın, DCC aracınızda rig'leyip klipleri adlandırın ve base colour'daki bake edilmiş gölgeleri
temizleyin (pbr renderer modeli gerçek zamanlı aydınlatır; ambient occlusion kendi map'ine aittir).

**Bütçeler** (60 fps için yol gösterici değerler; konsolda ölçün):

| | |
|---|---|
| Ana karakter | 3 000 - 8 000 üçgen, 20 - 40 kemik, köşe başına 4 ağırlık |
| Düşmanlar, NPC'ler | 1 000 - 4 000 üçgen |
| Prop'lar | 50 - 1 500 üçgen |
| Bütün kare | 30 000 - 60 000 üçgen, yaklaşık 150 draw call (her mesh, materyal ve iskeletin her 32 kemiklik parçası bir tane) |
| Ekrandaki skin'li karakterler | 8 - 16 (GPU'da çizim başına 32 kemiğe kadar skin'lenir) |

**Ayrıntı düzeyi (LOD).** SDK'da otomatik LOD yok. Bir prop hem ayrıntılıysa hem de çoğu zaman uzaktaysa, onu iki kez
export edin (tam ayrıntı ve üçgenlerin yaklaşık dörtte biri), ikisini de yükleyin ve kodunuzda uzaklığa göre birini
seçin; bölüm 6'daki Model Bench bunu yapar. Bir dosyanın iki yüklemesi veriyi paylaşır; bir prop'un çok sayıda kopyası
için her ayrıntı düzeyini tek bir `g3d.drawInstanced` çağrısıyla çizin. Uzak düzlemi gizleyen sis ve sahnenin izin
verdiği kadar küçük bir `far` değeri de çizilen şeyi azaltır.

## 4. Dokular ve PBR map'leri

**Boyutlar.** İkinin kuvvetleri. Konsolda: base colour ve normal 1024 px, diğer map'ler 512 px, en fazla 2048 px
(`g3d.caps().maxTextureSize` sınırı bildirir). Konsol her map'i belleğe tam boyutuyla yükler; 4K setleri yayından önce
küçültün. Map'ler çabuk birikir: bir oyunun modellerini ve dokularını onlarca MB'de tutun.

**pbr renderer'ın okuduğu map'ler:**

| Map | İçerik | Renk uzayı | glTF yuvası | FBX |
|---|---|---|---|---|
| Base colour | albedo, içine ışık bake edilmemiş; alpha, kesik yüzeyler ve cam için | sRGB | `baseColorTexture` | bağlı base colour / diffuse map |
| Normal | tangent space, **OpenGL tarzı (yeşil yukarı)** | veri | `normalTexture` (`scale` ile) | bağlı normal map |
| Metallic-roughness | roughness **G**'de, metallic **B**'de | veri | `metallicRoughnessTexture` | ayrı metallic ve roughness map'leri |
| Occlusion | ambient occlusion **R**'de | veri | `occlusionTexture` (`strength` ile) | exporter yazıyorsa oradan, ya da dosya adından |
| MetallicSmoothness | metallic **R**'de, smoothness **A**'da (smoothness = 1 - roughness) | veri | (glTF yuvası değil) | dosya adından |
| Emissive | parlayan kısımlar | sRGB | `emissiveTexture` × `emissiveFactor` | bağlı emission map |

- Yeşil aşağı kuralıyla (Y-) bake edilmiş **normal map'ler** ışığı ters taraftan alıyormuş gibi görünür: export'tan önce
  yeşil kanalı çevirin (birçok baker ve doku aracında bunun için bir seçenek vardır). Tangent'lar doku koordinatlarından
  hesaplanır, bu yüzden normal map temiz UV ister.
- **ORM paketleme.** glTF, roughness'ı bir resmin G'sinden, metallic'i B'sinden okur; ambient occlusion'ı aynı resmin
  R'sine koyun ve onu occlusion map olarak da bağlayın: üç map için tek doku.
- **Oyun motoru doku setlerinin map'leri** olduğu gibi çalışır: materyali bir map'i bağlamayan bir FBX, onu base colour
  map'inin yanındaki, ona benzer adlı bir resim dosyasından alır. `T_Chair_BaseColor.png`; `T_Chair_AO.png`,
  `T_Chair_Metallic.png`, `T_Chair_Roughness.png` ya da `T_Chair_MetallicSmoothness.png` çiftini (metallic R'de,
  smoothness A'da) bulur. Bu, base colour map bir resim dosyası olduğunda çalışır (FBX'e gömülü değilse); diğer
  dosyalar onun yanında ve modelin yanında aranır. Normal ve emissive map'ler adla bulunmaz: onları FBX materyalinde
  bağlayın.
- **Gömmek ya da yanına koymak.** Gömülü dokulu bir `.glb`, map'lerini kaybedemeyen tek bir dosyadır; onu tercih edin.
  Doku klasörlü bir `.gltf` ya da `.fbx`, klasör yanına, dosyanın kullandığı adlarla kopyalandığında çalışır.
- **Resim dosyaları:** kesin değerli map'ler (normal, ORM, alpha) için PNG; alpha'sız base colour için JPEG de olur.
- **AI ile üretilmiş dokular** çoğu zaman gölgeleri ve parlamaları boyanmış tek bir resim olarak gelir. Base colour'daki
  ışığı temizleyin, tekrarlanan dokuları dikişsiz yapın, normal ve roughness map'lerini bir doku aracında türetin;
  sonucu konsolda hareket eden bir ışık altında kontrol edin.

**Emissive ve bloom.** Parlama gücü emissive renk × `emissiveStrength`'tir (glTF: `KHR_materials_emissive_strength`).
1'in üstünde bloom eşiğinden (`g3d.postfx` `threshold`, varsayılan 1) parlaktır ve bloom'a taşar: ekranlar, lambalar,
vizörler, çekirdekler.

**Saydamlık ve cam** (glTF materyalleri):

| Ne | Nasıl |
|---|---|
| Opak | alpha mode `OPAQUE`: dokunun alpha'sı yok sayılır |
| Kesik (yapraklar, çitler, ızgaralar) | alpha cutoff'lu `MASK` alpha mode; MSAA ile kenarlar alpha to coverage kullanır ve yumuşak görünür |
| Saydam (plastik, duman, hologram) | `BLEND` alpha mode: opak sahneden sonra, nesne başına arkadan öne sıralanarak, premultiplied çizilir; yansıma gücünü korur, yüzey sıyırma açılarında daha opak olur |
| Kıran ince cam | `KHR_materials_transmission` (factor) ve `KHR_materials_ior`, ya da `g3d.material(model, {transmission = 0.9, roughness = 0.05, ior = 1.5}, "Glass")`; arkadaki sahne görünür, base colour ile renklenir ve normal map ile bükülür |
| Vernik, araba boyası | `KHR_materials_clearcoat` (factor'lar) ya da `g3d.material`'da `clearcoat` / `clearcoatRoughness` |
| Çift yüzlü | materyalin double-sided bayrağı; blend'li çift yüzlü materyaller önce uzak yüzlerini çizer |

**Yansımalar** `g3d.environment`'tan gelir: gökyüzü yarım küresi, ya da seviyenizin bir noktasından DCC aracınızda
reflection probe olarak render ettiğiniz 6 yüzlü bir cube map (`+X −X +Y −Y +Z −Z`). Ekran uzayı yansımalar, düzlemsel
aynalar ve çalışma anında yakalanan probe'lar yoktur.

## 5. Adlar

| Ad | Neden önemli |
|---|---|
| Klipler: `Idle`, `Run`, `Jump`, `Attack` | `model:play("Run")` klibi adıyla, büyük-küçük harfe bakmadan ve FBX export'larının eklediği armature önekini atlayarak bulur (`"Rig|Run"`, `"run"` ile eşleşir) |
| Kemikler ve soketler: `hand_R`, `head`, `Muzzle` | `model:node(name)` ve `model:nodeMatrix(name)` oraya bir şey takar ve efekt doğurur; köşesi olmayan bir kemik soket olarak çalışır |
| Materyaller: `Glass`, `Trim_Metal`, `Screen` | `g3d.material(model, options, name)` tek bir materyali adıyla değiştirir; açık adlar kodun onları ayarlamasını ya da değiştirmesini sağlar |
| Dosyalar: `prop_crate.glb`, `T_Crate_BaseColor.png` | dosya başına bir varlık, base colour adını izleyen doku adları (bölüm 4) |

## 6. pbr renderer'a

Çevresine bir şey kurmadan önce her modele konsolda bakın. Aşağıdaki **Model Bench** eksiksiz bir programdır (Lua
checker'ından geçti): dosyalarınızı `models/`'a koyun, iki yolu değiştirin, çalıştırın ve `model:info()`'nun
bildirdiklerini okuyun. İki ayrıntı düzeyi için uzaklık geçişini de gösterir.

`app.json`:

```json
{
  "id": "com.yourname.modelbench",
  "name": {"en": "Model Bench"},
  "description": {"en": "Checks exported models under the pbr renderer"},
  "version": "1.0",
  "author": "Your Name",
  "category": "developer",
  "main": "main.lua",
  "window": {"width": 960, "height": 600, "resizable": true},
  "gamepad": true,
  "minSdk": "1.9",
  "targetSdk": "1.9",
  "permissions": []
}
```

`lang/en.json`:

```json
{
  "loading": "Loading {0}",
  "failed": "Could not load the model: {0}",
  "info": "{0} · {1} triangles · {2} materials · {3} textures · skinning: {4}",
  "size": "Size {0} x {1} x {2} m",
  "lod": "Distance {0} m · drawing {1} · renderer {2}",
  "near": "near",
  "far": "far"
}
```

`main.lua`:

```lua
-- Model Bench: look at an exported model under the pbr renderer before you build a game around it.
-- Copy your files into models/ and change the two paths. Left stick or arrow keys: orbit and zoom.
local app = {}

local MODEL = "bundle:/models/prop_lod0.glb"       -- full detail
local MODEL_FAR = "bundle:/models/prop_lod1.glb"   -- optional: the same prop with about a quarter of the triangles
local LOD_DISTANCE = 12                            -- metres: draw the far version beyond this

local near, far, info, err
local ground
local yaw, dist, active = 0.6, 6, "basic"
local held = {}

local function fmt(v) return string.format("%.2f", v) end

function app.load(arg)
  active = g3d.renderer("pbr")
  g3d.shadows({quality = "medium", distance = 20})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.05, threshold = 1.0})
  g3d.environment({sky = "#9DB8E8", ground = "#4A4038", intensity = 1.0, sun = 2.5})
  ground = g3d.mesh("plane", 20, 20, 4)
  ground:setColor("#7A7F86")
  g3d.material(ground, {roughness = 0.8})
  g3d.loadModel(MODEL, function(m, e)                -- no size: the model keeps its authored metres
    if not m then
      err = tostring(e)
      return
    end
    near, info = m, m:info()
    for _, a in ipairs(info.animations) do print("clip", a.name, a.duration) end
    if #info.animations > 0 then near:play(1) end
  end)
  g3d.loadModel(MODEL_FAR, function(m) far = m end)  -- stays nil when there is no far version
end

function app.update(dt)
  local x, y = input.stick("left")
  if held.left then x = -1 elseif held.right then x = 1 end
  if held.up then y = 1 elseif held.down then y = -1 end
  yaw = yaw + x * 1.5 * dt
  dist = math.max(1.5, math.min(40, dist - y * 8 * dt))
  if near then near:update(dt) end
end

function app.draw(w, h)
  gfx.clear("#20242C")
  local m = near
  if far and dist > LOD_DISTANCE then m = far end      -- a distance switch: the SDK has no automatic LOD
  g3d.begin(0, 0, w, h, 50, 0.05, 200)
  g3d.camera(math.sin(yaw) * dist, dist * 0.45, math.cos(yaw) * dist, 0, 0.8, 0)
  g3d.light(0.5, 0.8, 0.3, 0.35, "#FFF1DD")
  g3d.draw(ground, 0, 0, 0)
  if m then g3d.draw(m, 0, 0, 0) end
  g3d.finish()

  gfx.color("#FFFFFF")
  if err then
    gfx.wrap(TR("failed", err), 16, 16, w - 32, 14)
  elseif not info then
    gfx.text(TR("loading", MODEL), 16, 16, 14, "mono")
  else
    gfx.text(TR("info", info.format, info.triangles, info.materials, info.textures, info.skinning), 16, 16, 14, "mono")
    gfx.text(TR("size", fmt(info.size.w), fmt(info.size.h), fmt(info.size.d)), 16, 36, 14, "mono")
    local which = m == far and TR("far") or TR("near")
    gfx.text(TR("lod", fmt(dist), which, active), 16, 56, 14, "mono")
  end
end

function app.event(e)
  if e.type == "keydown" and e.key then held[e.key] = true
  elseif e.type == "keyup" and e.key then held[e.key] = nil end
end

return app
```

Neye bakılır: metre cinsinden boyut (bir insan yaklaşık 1,7 m), bütçeye göre üçgen sayısı, bir karakter için
`skinning`'in `"gpu"` olması, klip adları ve çevresinde dönen ışık altındaki görünüm (orbit). Renderer satırı `basic`
diyorsa konsolda pbr yolu yoktur (ya da sistem ayarı kapalıdır); model yine base colour'ıyla çizilir.

**Renderer ayarları** uygulamaya aittir; onları `app.load`'da verin ve sahne değişince değiştirin:

| Çağrı | Başlangıç | Notlar |
|---|---|---|
| `g3d.renderer("pbr")` | `app.load`'da | `"pbr"` ya da `"basic"` döndürür; oyun ikisinde de doğru çalışmalı |
| `g3d.light(dx, dy, dz, ambient, color)` | her karede, `begin` ile `finish` arasında | güneş: ona doğru yön, ambient, renk |
| `g3d.shadows({quality, distance, bias})` | `"medium"`, distance = görünen oyun alanı | `"high"` daha pahalı; bir spot ışık da gölge verebilir |
| `g3d.postfx({exposure, tonemap, bloom, threshold, msaa, hdr})` | `tonemap = "aces"` ya da `"filmic"`, `bloom` 0.03 - 0.1, `msaa = 0` | `msaa`'yı ancak ölçtükten sonra yükseltin; basit sahnelerde `hdr = false` |
| `g3d.environment({sky, ground, intensity, sun, cubemap})` | sanat yönünüzün yarım küre renkleri | bir cube map gökyüzünüzden yansıma ve ambient verir |
| `g3d.addLight({type, x, y, z, color, intensity, range, ...})` → id | hareketin yakınında 2 - 6 nokta ya da spot ışık | `g3d.updateLight(id, {...})` ile taşıyın; en fazla 16, nesne başına en güçlü 8'i |
| `g3d.material(meshOrModel, options[, name])` | düz mesh'ler: `{metallic, roughness}` | bir modelde yalnızca verilen alanları değiştirir; `nil` dosyanın değerlerine döner |
| `g3d.drawInstanced(mesh, transforms)` | tekrarlanan prop'lar | kopya başına 7 sayı; GPU çağrısı başına en fazla 128 kopya |

Hepsini kullanan eksiksiz bir oyun: [PBR_GAME_RECIPE.tr.md](PBR_GAME_RECIPE.tr.md). Bütçeler ve sanat yönü yöntemi:
[MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md), bölüm 10 ve 11.

## 7. AI asistanıyla kod

Asistanlar bu SDK'yı bilmez. [SDK/AI](../AI/README.tr.md)'deki kit olmadan başka platformların çağrılarını yazarlar
(`fetch`, `localStorage`, `io.open`, özel shader'lar); bunlar burada yoktur.

**Ne gönderilir.**

| Dosya | Ne zaman |
|---|---|
| [system-prompt.tr.md](../AI/system-prompt.tr.md) | her zaman: paket yapısı, `app.json`, izinler, program yapısı, kurallar, API'nin özeti |
| [languages/](../AI/languages/) `<dil>.tr.md` | her zaman: dilinizin paketi (yeni uygulamalar için Lua, JavaScript, Python ya da C) |
| [tasks/](../AI/tasks/) | görev prompt'u: [3B oyun yapmak](../AI/tasks/make-3d-game.tr.md), [sosyal uygulama yapmak](../AI/tasks/make-social-app.tr.md), [oyun yapmak](../AI/tasks/make-game.tr.md), [araç yapmak](../AI/tasks/make-utility.tr.md), [mağaza ikonu](../AI/tasks/store-icon.tr.md), ... |
| [checklist.tr.md](../AI/checklist.tr.md) | her isteğin sonunda: "Cevaplamadan önce checklist.tr.md'yi uygula" |
| [SDK.tr.md](../Reference/SDK.tr.md) ve bir rehber | bağlam yeterince büyükse: başvurunun tamamı, artı görevin rehberi (bu sayfa, bir tarif, [MAKE_A_GAME.tr.md](MAKE_A_GAME.tr.md)) |

Hepsi için tek dil kullanın (`.en.md` ya da `.tr.md` dosyaları). Görev prompt'unu isteklerle değil gerçeklerle doldurun:
uygulama id'si, dil, bir oyun için yedi sanat yönü kararınız ve her model için Model Bench'in yazdıkları (boyut,
üçgenler, klip adları, soketler). Sunucu kullanan bir uygulama için gerçek endpoint'leri ve JSON'u verin.

**Checker'larla ilerleyin.**

1. Cevabı bir pakete koyun ve `python SDK/Tools/nxv/nxv.py check <paket>` çalıştırın: manifest, kullanılıp bildirilmeyen
   izinler, çeviriler (`lang/en.json`'daki `TR()` anahtarları), ikon, dosya sınırları ([Tools/nxv](../Tools/nxv/README.tr.md)).
2. `--sdk <Nexvyn OS kaynak checkout'u>` ile aynı komut dilin resmî checker'ını da çalıştırır (`lua_check.py`,
   `js_check.mjs`, `py_check.py`, `rt_check.py`); o da her dosyayı derler ve uygulamayı sahte bir SDK'ya karşı rastgele
   girdiyle yüzlerce kare oynatır. Mağaza bakımcısı her başvuruda bu checker'ları çalıştırır.
3. Bir denetim başarısız olursa, çıktının tamamını ve adı geçen dosyaları
   [tasks/fix-lua-check.tr.md](../AI/tasks/fix-lua-check.tr.md) ile geri gönderin. Asistandan bir denetimi atlamasını
   istemeyin.
4. Konsolda çalıştırın. Checker'lar sahte bir SDK kullanır; asıl deneme konsoldur (`nxv push`).

**Geleni gözden geçirin.** Çalıştırmadan önce kodu başvuruyla karşılaştırarak okuyun:

- Her fonksiyon, seçenek ve alan [SDK.tr.md](../Reference/SDK.tr.md)'de var; seçenekler oradaki gibi yazılmış
  (`emissive_strength` değil `emissiveStrength`; `"reinhard"` değil `"filmic"`).
- Dil kuralları tutuyor: indeksler (Lua 1'den, diğerleri 0'dan başlar), çoklu sonuçlar (Lua dönüşleri, JavaScript
  dizileri, Python tuple'ları, C işaretçileri), JavaScript'te `try` / `catch` ile Promise'ler, Python'da callback'ler,
  C'de JSON seçenek metni.
- `minSdk` / `targetSdk` kodun kullandığına uyuyor (pbr renderer ve bölüm 8d için `"1.9"`) ve `permissions` tam olarak
  kodun ihtiyacını listeliyor.
- Hiçbir callback 3 saniyeye yaklaşamaz: modeller `g3d.loadModel` ile yüklenir, uzun iş karelere bölünür.
- Bir oyun kendi menülerini ve HUD'unu kendi tarzında çizer (`ui.*` widget'ı yok, `theme` rengi yok, kopyalanmış örnek
  düzeni yok); bir uygulama `theme` ve `ui` kullanır.
- Görünen her metin İngilizcesi `lang/en.json`'da olan `TR()`'den geçer.

**Bir uygulamaya asla API anahtarı koymayın.** Herkes bir `.nxvapp`'ı açabilir. Anahtarlar, client secret'lar ve
şifreler sunucunuzda kalır; uygulama oturum açar (`net.oauth`) ya da anahtarları tutan sunucunuzla konuşur.
Anahtarları prompt'lara da yapıştırmayın ve bir asistanın onları "deneme için" koda yazmasına izin vermeyin. Mağaza,
API anahtarı ya da şifre toplayan uygulamaları kabul etmez. Studio'nun **Ask AI** paneli, kullanıcının konsoldaki AI
Sohbet'e girdiği anahtarları kullanır; anahtarlar orada kalır.

## 8. Ses, ikon ve mağaza görselleri

- **Ses.** `sfx` kiti katmanlı efektleri ve müziği tariflerden üretir, dosya gerekmez
  ([Ses tasarımı](SOUND_DESIGN.tr.md)). Üretilmiş ses dosyaları `audio.play` / `audio.music` ile çalışır;
  yüksekliklerini eşitleyin, döngüleri sıfır geçişlerinden kesin.
- **Mağaza ikonu.** Oyunun kendisini gösteren 256x256 key art. Kendi modelinizi ikon aracıyla çizin
  ([`SDK/Tools/icon`](../Tools/icon/README.tr.md)) ya da
  [`SDK/AI/tasks/store-icon.tr.md`](../AI/tasks/store-icon.tr.md) ile bir görsel üretici kullanın. Stil sizin
  seçiminiz; varsayılan clean'dir (yazısız, ölçülü efektler).
- **Ekran görüntüleri.** Beş önerilir; arayüz İngilizce, oynanışın en iyi anlarından
  ([yayımlama rehberi](../Publishing/PUBLISHING.tr.md), bölüm 6).

## 9. Haklar ve lisanslar

Yayınladığınız her varlıktan ve her kod satırından, bir AI aracının yaptıkları dahil, siz sorumlusunuz.

- Çıktısını yayınlamanıza (satıyorsanız ya da satabilecekseniz ticari olarak) izin veren üreticiler kullanın ve her
  varlık için aracı, tarihi ve koşullarını not edin.
- Başka oyunların ya da markaların karakterlerini, logolarını veya ticari markalarını üretmeyin; bir üreticiye hakkına
  sahip olmadığınız malzeme vermeyin.
- AI'nın yazdığı kodu denetlemek size düşer: lisanslı kodu yeniden üretebilir. Kefil olamadığınız şeyi dışarıda tutun.
- App Market bir öğeyi ancak ona sahipseniz ya da yayına izin veren bir lisansınız varsa kabul eder ve üçüncü taraf
  parçaları lisanslarıyla README'de listeler ([Publishing/PUBLISHING.tr.md](../Publishing/PUBLISHING.tr.md), bölüm 8;
  [inceleme listesi](../Publishing/REVIEW.tr.md), bölüm 4). Üretici koşullarını da oraya yazın.

## 10. Kontrol listesi

**Varlıklar**

- [ ] Gömülü dokulu `.glb` (ya da doku klasörü yanında `.fbx`); dosya sınırları içinde
- [ ] Metre, +Y yukarı, +Z'ye bakıyor, pivot tabanda, transform'lar uygulanmış
- [ ] Üçgenler ve kemikler bütçe içinde; ikinci ayrıntı düzeyi yalnızca karşılığını verdiği yerde
- [ ] Base colour'a ışık bake edilmemiş; AO kendi map'inde (ya da ORM resminin R'sinde)
- [ ] Normal map'ler +Y (yeşil yukarı); ORM = occlusion R, roughness G, metallic B; MetallicSmoothness = metallic R, smoothness A
- [ ] Dokular ikinin kuvveti, base colour ve normal için 1024 px, geri kalanı için 512 px, en fazla 2048 px
- [ ] Emissive yalnızca bloom yapması gereken yerde 1'in üstünde; cam transmission ile, kesik yüzeyler `MASK` ile
- [ ] Klipler, soketler ve materyaller adlandırılmış; morph target'lar, kameralar ve ışıklar bake edilmiş ya da kaldırılmış
- [ ] Konsolda Model Bench ile bakılmış: boyut, üçgenler, `skinning`, klipler, hareket eden ışık altındaki görünüm

**Kod**

- [ ] AI kiti gönderilmiş: system prompt, dil paketi, görev prompt'u, kontrol listesi (sığıyorsa başvuru da)
- [ ] `nxv check` geçiyor (checkout varsa `--sdk` ile); her çağrı başvuruyla karşılaştırılmış
- [ ] `app.load`'da `g3d.renderer("pbr")` ve oyun `"basic"`ta da doğru
- [ ] `minSdk` / `targetSdk` ve `permissions` doğru; `lang/en.json`'da İngilizce metin eksiksiz
- [ ] Pakette API anahtarı, sır ya da şifre yok
- [ ] Konsolda denenmiş

**Haklar**

- [ ] Her üreticinin koşulları yayına izin veriyor; araç, tarih ve koşullar not edilmiş
- [ ] Üçüncü taraf ve üretilmiş parçalar lisanslarıyla mağaza README'sinde listelenmiş

## Ayrıca bakın

[AI kiti](../AI/README.tr.md) · [SDK başvurusu](../Reference/SDK.tr.md) · [PBR oyun tarifi](PBR_GAME_RECIPE.tr.md) ·
[Sosyal uygulama tarifi](SOCIAL_APP_RECIPE.tr.md) · [Oyun yapmak](MAKE_A_GAME.tr.md) · [SDK sürümleri](SDK_VERSIONS.tr.md) ·
[Tools/nxv](../Tools/nxv/README.tr.md) · [Yayın](../Publishing/PUBLISHING.tr.md)
