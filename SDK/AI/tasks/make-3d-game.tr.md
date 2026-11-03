# Görev: modelli 3B oyun yapmak

[English](make-3d-game.en.md) · **Türkçe**

`.glb` / `.fbx` modeller (SDK 1.8) ve pbr renderer (SDK 1.9) kullanan bir 3B oyun için. Context pack'ten (`system-prompt.tr.md` + language pack)
sonra gönderin. Asistana SDK.tr.md bölüm 8b'yi (*3B*, *3B modeller* ve *Modern görüntü*) ve context yetiyorsa
`SDK/Guides/MAKE_A_GAME.tr.md` rehberini verin (tarifin tamamı: dışa aktarma kuralları, yükleme, çarpışma
yardımcıları, bütçeler, sanat yönü). Eksiksiz küçük bir oyun için `SDK/Samples/lua/ember-field` örneğine bakın ama
asistanın onun görünüşünü kopyalamasına izin vermeyin.

İstemeden önce her modeli bir kez oyunda ya da Studio'nun *3B modeller* şablonunda deneyin ve `model:info()`'nun
söylediklerini not edin (boyut, üçgen, kemik, klip adları).

```text
SDK 1.9 ile eksiksiz bir Nexvyn OS 3B oyunu yaz.

Oyun: <tür ve tek paragraflık fikir>
Dil: <Lua | JavaScript | Python>
Uygulama kimliği: com.<adiniz>.<oyun>   Ad: <ad>
Oyunun dilleri: İngilizce<, artı diğerleri>
Paketteki modeller (model:info()'dan):
- models/<kahraman>.glb: <boy> m, <üçgen> üçgen, klipler <Idle, Run, Jump, ...>, soketler <hand_R, ...>
- models/<düşman>.glb: ...
- models/<eşya>.glb: ...

Gereksinimler:
- app.json: "category": "games", "gamepad": true, boyutlandırılabilir "window", "minSdk": "1.9", "targetSdk": "1.9",
  gerekmedikçe "permissions": [].
- Her modeli app.load içinde g3d.loadModel ile yükle (büyük dosyalarda asla g3d.model değil) ve modeller gelene kadar
  oyunun stilinde çizilmiş bir yükleme ekranı göster; yükleme hatasını bir mesajla karşıla. Hiçbir callback 3
  saniyeye (app.load 10'a) yaklaşamaz: diğer uzun işleri (arazi, bölüm kurma) karede birkaç milisaniyelik dilimlere
  böl.
- Animasyon: klipleri adla oynat, yalnızca durum değişince değiştir, {fade = 0.1-0.3} ile geçiş yap, tek seferlik
  klipleri {loop = false} ile oynat ve model:playing() false olunca döngüye dön; her karede model:update(dt) çağır.
  Tutulan nesneleri ya da efektleri model:nodeMatrix + g3d.drawMatrix ile tak.
- Modern görünüm (SDK 1.9): app.load içinde g3d.renderer("pbr") çağır; "basic" dönerse de oyun doğru çalışsın.
  Sanat yönüne uygun ışığı seç: güneş (g3d.light yönü ve rengi), gök / zemin ya da cube map (g3d.environment), id'li
  1-4 renkli nokta ya da spot ışık (g3d.addLight, g3d.updateLight ile hareket). g3d.shadows({quality = "medium",
  distance = <görünen oyun alanı>}); g3d.postfx({exposure, tonemap = "aces" ya da "filmic", bloom = 0.03-0.1});
  1'in üstündeki emissive parçalar parlar. Modeller PBR haritalarını korur (glTF base color, normal, ORM, emissive;
  FBX texture klasörü yanında); düz mesh'lere g3d.material(mesh, {metallic, roughness, ...}); cama {transmission =
  0.9, roughness = 0.05}. Tekrarlanan nesneler (çimen, sütun, kasa) g3d.drawInstanced ile çizilir. Renderer'ı ve
  fps'i kapatılabilen bir hata ayıklama satırında göster.
- Kamera: <takip / yörünge / sabit / birinci şahıs>, yumuşak, darbelerde kısa sarsıntılı. Hareket kameraya göre;
  model yaw 0'da +Z'ye bakar (yaw = math.atan(vx, vz)).
- Çarpışma: küçük yardımcılar yaz (küre-küre, dışarı itmeli küre-kutu, ışın-kutu, basit bir çarpışma mesh'i için
  ışın-üçgen, yükseklik haritasından zemin yüksekliği); dt'yi sınırla; g3d sahneleri için fizik motoru yoktur.
- Konsolda 60 fps bütçesi (pbr: msaa 0, gölge "medium", en çok 1024 px dokularla başla): karede 30-60 bin üçgen, 8-16 skin'li karakter, 150 civarı çizim çağrısı, uzak düzlemi
  gizleyen sis, mümkünse sabit eşyalar tek bir g3d.custom mesh'inde. update/draw döngülerinde tablo üretme ya da
  resim yükleme yok.
- Önce sanat yönü (ana dosyanın başında yorum: his, palet, tipografi, kamera dili, hareket, ses paleti, arayüz biçim
  dili). Başlık ekranı, HUD ve duraklatma ekranı bu yönde gfx / g3d ile çizilir; ui.* widget'ı yok, theme renkleri
  yok, hiçbir örneğin ya da oyunun menü düzeni veya başlığı kopyalanmaz.
- Kontroller: sol çubuk / D-pad + düğmeler, kamera için sağ çubuk, klavye (WASD + oklar + Boşluk/Enter/Esc) ve
  dokunmatik (parmağın değdiği yerde bir çubuk, eylemler için dokunma). +'da, suspend'de ve focus(false)'da duraklat.
- store ile kayıt: ilerleme, en yüksek puan ve ayarlar (müzik, efekt ve ambiyans sesi, titreşim, kamera Y'sini ters
  çevir).
- Kalite çıtası (SDK/Guides/GAME_FEEL.tr.md bölüm 8 ve SOUND_DESIGN.tr.md; zorunlu):
  * Kitleri kullan: SDK/Languages/<lua|javascript>/kits içindeki sfx ve juice dosyalarını bundle'a kopyala; ses,
    parçacık, sarsıntı, hit-stop, flaş, geçiş, başlık, panel ve düğmeler için onları kullan (diğer dillerde aynı
    taşları SDK çağrılarından kur). Yalnızca kitlerde gerçekten olan fonksiyonları kullan (system prompt bölüm 7a).
  * Oyuncunun ve menünün her eyleminin aynı karede, olayla ölçekli bir sesi ve görsel tepkisi var.
  * Ses: 3-4 varyantlı katmanlı tarifler, tam seviyede ham, filtresiz square ya da saw yok, bir müzik döngüsü ve
    ambiyans zemini, müzik efektlerin altında ve ağır vuruşlarda kısılıyor, müzik / efekt / ambiyans ses ayarları.
  * Renk: rolleri olan 4-6 renklik palet; düz tek renk arka plan yok (gradyan, parlama, vinyet, ışık, paralaks); gri
    tonda okunuyor.
  * Yazı: tek tip ölçeğinden 3-4 boyut; başlık stilli bir logo (dış hat, gölge, iki ton ya da parlama), asla
    varsayılan boyutta varsayılan yazı değil.
  * Arayüz: tek şekil dili, derinliği olan paneller, hover / basılı / odak / devre dışı hâlli düğmeler, ekranlar
    arası geçiş, başlık ekranında canlı bir şey.
  * 3D: sahnenin arkasında gökyüzü gradyanı, gökyüzü renginde sis, renkli bir ana ışık (juice J.looks / J.sky /
    J.light3d ya da kendi ayarın), ışık saçan parçalarda parlama, karakterlerin altında yumuşak temas gölgesi,
    atılma ve vuruşlarda görüş açısı tekmeli yumuşak takip kamerası (J.cam3d).
- Görünen her metin TR()'den geçer: lang/en.json, artı yukarıdaki her başka dil için bir lang/<kod>.json.

Her dosyayı eksiksiz ver, sonra: PC'de nasıl denetlenir, konsolda nasıl çalıştırılır, modeller yanlışsa hangi dışa
aktarma ayarlarını kullanmam gerekir, mağaza ikonu bu modellerden nasıl yapılır (SDK/Tools/icon ile key art: kahramanım için hero_render.py ve
finish_icon.py komutları), kalite çıtasının hangi maddelerini karşılayamadın ve neyden emin değilsin.
```

Devam istekleri: "oyuncuyu basit bir durum makinesiyle kovalayan bir düşman ekle", "bölüm için bir çarpışma mesh'i
ekle ve zemin için ışın-üçgen kullan", "ölç: her saniye üçgen sayısını ve fps'yi yazdır", "store.json'u yaz"
([store-listing.tr.md](store-listing.tr.md)), "ikon prompt'u" ([store-icon.tr.md](store-icon.tr.md)).
