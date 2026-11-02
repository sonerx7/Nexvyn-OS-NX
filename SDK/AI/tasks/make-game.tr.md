# Görev: oyun yapmak

[English](make-game.en.md) · **Türkçe**

Aşağıdaki prompt'u kopyalayın, `<...>` kısımlarını doldurun ve context pack'ten (`system-prompt.tr.md` + language pack)
sonra gönderin. Lua ile 2D oyunda `nexvyn.game` motoru (SDK.tr.md bölüm 8c) çok kod kazandırır: o bölümü de asistana
verin. Modelli bir 3B oyun için [make-3d-game.tr.md](make-3d-game.tr.md) kullanın. İnsanlar ve asistanlar için tarifin
tamamı `SDK/Guides/MAKE_A_GAME.tr.md` içindedir.

```text
Eksiksiz bir Nexvyn OS oyunu yaz.

Oyun: <tür ve tek paragraflık fikir, ör. "düşen blokların arasından kaçtığın tek ekranlık bir arcade oyunu">
Dil: <nexvyn.game ile Lua | Lua | JavaScript | Python>
Uygulama kimliği: com.<adiniz>.<oyun>   Ad: <ad>
Oyunun dilleri: İngilizce<, artı istediğin diğerleri, ör. Türkçe, İspanyolca>

Gereksinimler:
- app.json: "category": "games", "gamepad": true, boyutlandırılabilir "window", doğru "runtime"/"main", kullanılan
  en yeni özelliğe göre "minSdk", "targetSdk": "1.8", oyun gerçekten gerektirmiyorsa "permissions": [].
- Önce sanat yönü: koddan önce ana dosyanın başına yorum olarak kısa bir sanat yönü yaz (tek satırda his, 3-4
  renklik palet, tipografi, kamera ya da kadraj, hareket stili, ses paleti, arayüz biçim dili). Ekrandaki her şey ona
  uyar. Başlık ekranını, HUD'u ve duraklatma ekranını gfx (ve g3d) ile kendin çiz; oyun arayüzü için ui.* widget'larını
  ya da theme renklerini kullanma ve hiçbir örneğin ya da başka oyunun menü düzenini, renklerini ya da başlık
  kompozisyonunu kopyalama. Bu oyuna uyan bir menü biçimi seç (tek komut, sıra, kartlar, numaralı sütun, dünyadaki
  nesneler...).
- Kontroller: kumandada D-pad / sol çubuk + A/B, klavyede ok tuşları / WASD + Boşluk/Enter ve dokunmatik (dokununca
  beliren ekran kontrolleri ya da dokunma). Kontrolleri oyunda göster.
- Ekranlar: başlık, oyun, duraklatma (+ / Escape / P ile ve suspend / focus(false) içinde), yeniden başlatmalı oyun
  bitti ekranı.
- Sabit adımlı ya da sınırlanmış dt ile güncelleme, çizim yalnızca draw içinde; karede allocation ya da resim
  yükleme yok; hiçbir callback 3 saniyeye (app.load 10'a) yaklaşmaz.
- store ile (ya da nexvyn.game ile game.save) kaydedilen bir en yüksek puan.
- audio.tone, game.audio ya da ses dosyalarıyla, tutarlı tek bir ses ailesinden efektler; çarpışmalarda sys.vibrate
  ile hafif titreşim ve onu kapatan bir ayar.
- Görünen her metin TR()'den geçsin: lang/en.json, artı yukarıdaki her başka dil için bir lang/<kod>.json.
- Cila: yumuşak hareket, darbelerde kısa bir duraklama ya da kamera sarsıntısı, toplamalarda parçacık, başlık
  ekranında canlı bir şey.

Her dosyayı eksiksiz ver (app.json, kaynak dosyalar, lang dosyaları), sonra kısa bir liste: doğru checker'la PC'de
nasıl denetlenir, konsolda nasıl çalıştırılır, mağaza ikonu nasıl yapılır (bu oyunun key art'ı, bkz.
store-icon.tr.md) ve neyden emin değilsin.
```

İyi çalışan devam istekleri: "ikinci bir bölüm ekle", "zorluk 2 dakika boyunca artsın", "bir ayarlar ekranı ekle
(müzik, efekt sesi, titreşim)", "App Market için bir store.json ekle" (bkz. [store-listing.tr.md](store-listing.tr.md)),
"ikon için key art prompt'unu yaz" (bkz. [store-icon.tr.md](store-icon.tr.md)).
