# Görev: modelli 3B oyun yapmak

[English](make-3d-game.en.md) · **Türkçe**

`.glb` / `.fbx` modeller kullanan bir 3B oyun için (SDK 1.8). Context pack'ten (`system-prompt.tr.md` + language pack)
sonra gönderin. Asistana SDK.tr.md bölüm 8b'yi (*3B* ve *3B modeller*) ve context yetiyorsa
`SDK/Guides/MAKE_A_GAME.tr.md` rehberini verin (tarifin tamamı: dışa aktarma kuralları, yükleme, çarpışma
yardımcıları, bütçeler, sanat yönü). Eksiksiz küçük bir oyun için `SDK/Samples/lua/ember-field` örneğine bakın ama
asistanın onun görünüşünü kopyalamasına izin vermeyin.

İstemeden önce her modeli bir kez oyunda ya da Studio'nun *3B modeller* şablonunda deneyin ve `model:info()`'nun
söylediklerini not edin (boyut, üçgen, kemik, klip adları).

```text
SDK 1.8 ile eksiksiz bir Nexvyn OS 3B oyunu yaz.

Oyun: <tür ve tek paragraflık fikir>
Dil: <Lua | JavaScript | Python>
Uygulama kimliği: com.<adiniz>.<oyun>   Ad: <ad>
Oyunun dilleri: İngilizce<, artı diğerleri>
Paketteki modeller (model:info()'dan):
- models/<kahraman>.glb: <boy> m, <üçgen> üçgen, klipler <Idle, Run, Jump, ...>, soketler <hand_R, ...>
- models/<düşman>.glb: ...
- models/<eşya>.glb: ...

Gereksinimler:
- app.json: "category": "games", "gamepad": true, boyutlandırılabilir "window", "minSdk": "1.8", "targetSdk": "1.8",
  gerekmedikçe "permissions": [].
- Her modeli app.load içinde g3d.loadModel ile yükle (büyük dosyalarda asla g3d.model değil) ve modeller gelene kadar
  oyunun stilinde çizilmiş bir yükleme ekranı göster; yükleme hatasını bir mesajla karşıla. Hiçbir callback 3
  saniyeye (app.load 10'a) yaklaşamaz: diğer uzun işleri (arazi, bölüm kurma) karede birkaç milisaniyelik dilimlere
  böl.
- Animasyon: klipleri adla oynat, yalnızca durum değişince değiştir, {fade = 0.1-0.3} ile geçiş yap, tek seferlik
  klipleri {loop = false} ile oynat ve model:playing() false olunca döngüye dön; her karede model:update(dt) çağır.
  Tutulan nesneleri ya da efektleri model:nodeMatrix + g3d.drawMatrix ile tak.
- Kamera: <takip / yörünge / sabit / birinci şahıs>, yumuşak, darbelerde kısa sarsıntılı. Hareket kameraya göre;
  model yaw 0'da +Z'ye bakar (yaw = math.atan(vx, vz)).
- Çarpışma: küçük yardımcılar yaz (küre-küre, dışarı itmeli küre-kutu, ışın-kutu, basit bir çarpışma mesh'i için
  ışın-üçgen, yükseklik haritasından zemin yüksekliği); dt'yi sınırla; g3d sahneleri için fizik motoru yoktur.
- Switch'te 60 fps bütçesi: karede 30-60 bin üçgen, 8-16 skin'li karakter, 150 civarı çizim çağrısı, uzak düzlemi
  gizleyen sis, mümkünse sabit eşyalar tek bir g3d.custom mesh'inde. update/draw döngülerinde tablo üretme ya da
  resim yükleme yok.
- Önce sanat yönü (ana dosyanın başında yorum: his, palet, tipografi, kamera dili, hareket, ses paleti, arayüz biçim
  dili). Başlık ekranı, HUD ve duraklatma ekranı bu yönde gfx / g3d ile çizilir; ui.* widget'ı yok, theme renkleri
  yok, hiçbir örneğin ya da oyunun menü düzeni veya başlığı kopyalanmaz.
- Kontroller: sol çubuk / D-pad + düğmeler, kamera için sağ çubuk, klavye (WASD + oklar + Boşluk/Enter/Esc) ve
  dokunmatik (parmağın değdiği yerde bir çubuk, eylemler için dokunma). +'da, suspend'de ve focus(false)'da duraklat.
- store ile kayıt: ilerleme, en yüksek puan ve ayarlar (müzik açık/kapalı, efekt sesi, titreşim, kamera Y'sini ters
  çevir).
- Görünen her metin TR()'den geçer: lang/en.json, artı yukarıdaki her başka dil için bir lang/<kod>.json.

Her dosyayı eksiksiz ver, sonra: PC'de nasıl denetlenir, konsolda nasıl çalıştırılır, modeller yanlışsa hangi dışa
aktarma ayarlarını kullanmam gerekir, mağaza ikonu bu modellerden nasıl yapılır (key art) ve neyden emin değilsin.
```

Devam istekleri: "oyuncuyu basit bir durum makinesiyle kovalayan bir düşman ekle", "bölüm için bir çarpışma mesh'i
ekle ve zemin için ışın-üçgen kullan", "ölç: her saniye üçgen sayısını ve fps'yi yazdır", "store.json'u yaz"
([store-listing.tr.md](store-listing.tr.md)), "ikon prompt'u" ([store-icon.tr.md](store-icon.tr.md)).
