# Görev: oyun yapmak

[English](make-game.en.md) · **Türkçe**

Aşağıdaki prompt'u kopyalayın, `<...>` kısımlarını doldurun ve context pack'ten (`system-prompt.tr.md` + language pack)
sonra gönderin. Lua'da `nexvyn.game` motoru (SDK.tr.md bölüm 8c) çok kod kazandırır: o bölümü de asistana verin.

```text
Eksiksiz bir Nexvyn OS oyunu yaz.

Oyun: <tür ve tek paragraflık fikir, ör. "düşen blokların arasından kaçtığın tek ekranlık bir arcade oyunu">
Dil: <nexvyn.game ile Lua | Lua | JavaScript | Python | Squirrel | C | Java>
Uygulama kimliği: com.<adiniz>.<oyun>   Ad: <İngilizce ad> / <Türkçe ad>

Gereksinimler:
- app.json: "category": "games", "gamepad": true, boyutlandırılabilir "window", doğru "runtime"/"main"/"minSdk",
  oyun gerçekten gerektirmiyorsa "permissions": [].
- Kontroller: kumandada D-pad / sol çubuk + A/B, klavyede ok tuşları / WASD + Boşluk/Enter ve dokunmatik (ekran
  düğmeleri ya da dokunma). Kontrolleri başlık ekranında göster.
- Ekranlar: başlık, oyun, duraklatma (+ / Escape / P ile ve suspend / focus(false) içinde), yeniden başlatmalı oyun
  bitti ekranı.
- Sabit adımlı güncelleme (dt'yi biriktir), çizim yalnızca draw içinde; karede allocation ya da resim yükleme yok.
- store ile (ya da nexvyn.game ile game.save) kaydedilen bir en yüksek puan.
- audio.tone ya da game.audio ile ses efektleri; çarpışmalarda sys.vibrate ile hafif titreşim.
- Görünen her metin lang/en.json ve lang/tr.json ile TR()'den geçsin (yapabilirsen de, fr, es de).
- Açık ve koyu modun doğru görünmesi için arayüz çerçevesinde theme renklerini kullan.

Her dosyayı eksiksiz ver (app.json, kaynak dosyalar, lang dosyaları), sonra kısa bir liste: doğru checkeryle PC'de
nasıl denetlenir, konsolda nasıl çalıştırılır ve neyden emin değilsin.
```

İyi çalışan devam istekleri: "ikinci bir bölüm ekle", "zorluk 2 dakika boyunca artsın", "App Market için bir
store.json ekle" (bkz. [store-listing.tr.md](store-listing.tr.md)).
