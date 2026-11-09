# Nexvyn'e uyum: giriş, oyun modları, pencere ve tam ekran, ses

SDK ile yapılan her app, oyun ve port kullanıcının konsolu tuttuğu şekilde çalışmalı: dokunmatik, kumanda (takılı ya da
ayrı Joy-Con çifti, mantıklıysa tek Joy-Con, Pro Controller), portatif ya da dock'ta. Bu sayfa neyin desteklenmesi
gerektiğini ve hangi mevcut API'nin karşılık geldiğini listeler. Yeni API eklemez. İngilizce: `INPUT_AND_PLAY_MODES.en.md`.

## 1. Giriş: hepsini destekle

| Giriş | Script app'ler (Lua, JavaScript, Python) | C (`nexvyn.h`) | Native (`nxn_*`) ve SDL2 |
|---|---|---|---|
| İmleç ve dokunma | `"mousedown"`, `"mouseup"`, `"mousemove"` event'leri; parmakta `e.touch` true; `input.touch()` kullanıcının dokunmatikte olduğunu söyler | aynı event'ler ve `input_touch()` | `nxn_input_touch(i, &t)`, `i < nxn_input_state.touch_count` (16 parmağa kadar); SDL2'de `SDL_FINGERDOWN` / `MOTION` / `UP` |
| Parmak kimliği | tek parmak sürüklemesi tek imleçtir; iki parmak jesttir | aynı | her parmağın kararlı `t.id`'si vardır (0, 1, 2 ...; tek parmak hep 0), SDL2'de `SDL_FingerID` |
| Jestler | `"scroll"` (iki parmak kaydırma dahil), `"pinch"` (`e.scale`), `"rotate"` (`e.angle`) event'leri | aynı event'ler | iki `nxn_touch` noktasını oku, uzaklık / açıyı kendin hesapla (id'ler kararlı) |
| Tuşlar ve çubuklar | `"paddown"` / `"padup"` (`e.pad`), `input.stick("left"\|"right")`, kullanıcının eşlemesi için `input.action(ad)` | `input_*` | `nxn_input_poll` (`buttons`, `pressed`, `lx, ly, rx, ry`, `NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL`); SDL2 joystick ya da game controller |
| Klavye, fare | `"keydown"`, `"text"`, fare event'leri | aynı | `nxn_input_key_held`, `nxn_input_mouse` |
| Portatif ya da dock | script'lerde henüz sorgu ya da event yok (parity açığı, aşağıda): her karede `gfx.size()` oku, gelen boyuta göre yerleştir | henüz sorgu yok (aynı açık) | `NXN_EVENT_DOCK` (`docked` 1 ya da 0, `NXN_CAP_POWER_EVENTS`), `NXN_EVENT_RESIZE` (`width`, `height`, `docked`) |

Ne yapmalı:

- **Dokunma.** Her kontrole parmakla ulaşılsın: hedefler en az 44 px, yalnız hover ile çalışan eylem yok, sürükleme ve
  dokunma iki tuş gerektirmesin. Çok dokunuşlu oyunlar "ilk dokunuşu" değil her parmağı id ile okur.
- **Kumanda.** Her eyleme kumandayla da ulaşılsın. Yana tutulan tek Joy-Con'un ikinci çubuğu yoktur: oyunun çekirdeğini
  tek çubuk ve dört tuşla kur, gerisini menüye koy. Onay ve geri için `input.action("select")` / `NXN_ACT_CONFIRM` /
  `NXN_ACT_CANCEL` kullan, kullanıcının eşlemesi çalışsın. Kumanda var sayma: konsol kumandasız dock'ta ya da Joy-Con
  takılı portatifte olabilir.
- **Dock'ta dokunma yok.** TV'de dokunmatik yoktur: hiçbir şey dokunma gerektirmesin ("başlamak için dokun" yok,
  yalnız dokunmayla çalışan kapat ya da geri tuşu yok), kumanda ilk ekrandan itibaren çalışsın. `input.touch()` false
  iken tuş simgelerini (`A`, `B`), true iken dokunma ipuçlarını göster.
- **Portatif ve dock.** Çıkış portatifte 1280x720, dock'ta 1920x1080'dir. Native app `NXN_EVENT_DOCK` /
  `NXN_EVENT_RESIZE` alır; `nxn_display_resize` ile uy ya da boyutunu koru, sistem ölçeklesin. Göreli birimle yerleştir
  (`gfx.size()` ya da yüzey boyutunun oranı), yazıyı OS yazı ölçeğiyle ölçekle (`ui.tokens().textScale`,
  `nxn_ui_tokens_get`), önemli şeyleri TV'de %5 güvenli kenar içinde tut, 1280x720'yi koda gömme.

## 2. Pencere ve tam ekran

- Oyunlar tam ekran, app'ler büyütülmüş açılır. İkisini de destekle: app her an yeniden boyutlanabilir
  (`NXN_EVENT_RESIZE`; script'te `gfx.size()` değişir). En-boy oranını koru, bant ya da uyarlanmış yerleşim kullan,
  resmi asla gerdirme. Kenar sürüklenirken canlı yeniden boyutlama isteğe bağlıdır (`native.liveResize`, eski native
  app'lerde `app.json`'da `"liveResize": true`).
- Girişi asla hapsetme. Tam ekranda kullanıcı − tuşunu bir saniye basılı tutarak çıkar (`wm.fullscreenExitHold`);
  kısa − basışı yine app'e ulaşır, bu yüzden basılı − hiçbir iş için kullanılmaz. HOME'u, menü çubuğu kenar
  kaydırmasını ve L + R (basılı) tuşunu yutma: bunlar Nexvyn OS'ta kalır.
- Üst kenardan dokunma **Tam ekrandan çık** düğmesini gösterir: üst kenarın altına, yukarıdan kaydırma isteyen kendi
  kontrollerini çizme.

## 3. Ses

- Sistem mikserini kullan: script'te `audio.play`, `audio.tone`, `audio.music`; native app'te `nxn_audio_*` / SDL2
  ses. Sistem sesi geçerlidir; varsayılan olarak tam seviyede ikinci bir ana ses ekleme.
- SDL2 kitinde her örnek biçimi ve 11 025 - 48 000 Hz arası her hız çalışır (eski derleme çıtırdadıysa güncel kitle
  yeniden derle).
- Yüksek varsayılan yok: müziği ve efektleri ılımlı sesle başlat, kullanıcının son ayarını geçme, kendi ayarlarında ses
  ya da sessiz kontrolü ver.
- Odak kaybında ve uykuda duraklat. Native: `NXN_EVENT_FOCUS` (`focused` 0) ve `NXN_EVENT_SUSPEND`'de müziği durdur;
  `SUSPEND`'den sonra sistem `RESUME`'a kadar app'in sesini çalmaz ve kuyruktakini atar. Script'lerde: `app.focus(false)` ve `app.suspend()` içinde duraklat
  (`audio.musicPause(true)`), `app.focus(true)` / `app.resume()` içinde sürdür.

## 4. Sistem gezinmesi ve temiz çıkış

- HOME, menü çubuğu ya da görev çubuğu, App Switcher ve uyku Nexvyn OS'a aittir. App yalnızca tepki verir.
- Çıkış: native app `NXN_EVENT_QUIT` alır (kapat düğmesi ya da sistemden çıkış): kaydet ve giriş fonksiyonundan çabuk
  dön. Script'lerde: `app.close()` (pencere açık kalsın diye `false` döndür, ör. kaydetmeyi sormak için) ve `app.suspend()`;
  ayrıca ilerlemeyi olduğu anda yaz (bölüm sonu, duraklatma).
- Uyku ve devam: native app `NXN_EVENT_SUSPEND` ve `NXN_EVENT_RESUME`, script `app.suspend()` ve `app.resume()` alır:
  suspend'de kaydet, devamdan sonra ağ bağlantısının ayakta kalmadığını varsay.
- Ana döngüyü bloke etme: sistemi 12 saniye tutan callback "Zorla kapat / Bekle" sorusunu getirir (eski app'ler yalnız
  sorulur, asla kapatılmaz). Yüklemeyi arka planda yap, çizmeye devam et.

## 5. Performans

- Kare süresini 16,6 ms altında tut, kareyi sistem hızlandırsın: zamanlama için meşgul bekleme ya da sleep döngüsü yok.
- `native.frameAhead` oyunlarda, kazanç ölçmedikçe 0 kalır (bir kareye kadar gecikme getirir). `gfx.dynamicRes`
  (`auto`, `on`, `off`) render boyutunu 60 fps'e doğru düşürür; `auto` yalnız SDK 1.12'den yeni hedefleyen app'lerde
  açıktır. Kendi çözünürlük ölçekleyicinle onunla savaşma.
- Benchmark'lar sınırsız (vsync beklemesiz, kare sınırlayıcısız) koşar, ortalama ve en kötü kareyi raporlar; çıkan
  oyunda sınır açık kalır.

## Parity açıkları (burada hiçbir şey uydurulmadı)

| Eksik | Nerede | Geçici çözüm |
|---|---|---|
| Lua, JavaScript, Python, C script'leri | portatif / dock sorgusu ya da event'i | her karede `gfx.size()` oku |
| Lua, JavaScript, Python, C script'leri | id'li ham parmak listesi | `"pinch"`, `"rotate"`, `"scroll"` event'lerini kullan |

## Kontrol listesi

- [ ] Yalnız dokunmayla (portatif, Joy-Con takılı) ve yalnız kumandayla (dock, dokunma yok) çalışıyor.
- [ ] Ayrı Joy-Con'larla (ikisi) ve mantıklıysa tek Joy-Con'la çalışıyor; onay / geri kullanıcının eşlemesini izliyor.
- [ ] Gömülü çözünürlük yok: portatif 1280x720, dock 1920x1080, pencere ve tam ekran temiz boyutlanıyor.
- [ ] Yazı OS yazı ölçeğiyle ölçekleniyor; dokunma hedefleri en az 44 px; TV güvenli kenarı.
- [ ] Basılı − tam ekrandan çıkarıyor; app hiçbir sistem jestini yutmuyor.
- [ ] Ses ılımlı başlıyor, sistem sesini izliyor, odak kaybında ve uykuda duruyor.
- [ ] Çıkışta ve uykuda kaydediyor (`NXN_EVENT_QUIT` / `SUSPEND`, `app.close` / `app.suspend`).
- [ ] Normal oyunda 16,6 ms'yi aşan kare yok; benchmark sınırsız, çıkan sürüm sınırlı.

## Test ipuçları

- App'i pencerede, tam ekranda çalıştır, sonra pencereyi küçük ve büyük boyuta getir.
- Portatif ve dock'u sırayla dene: app çalışırken dock'tan çıkar (native: `NXN_EVENT_DOCK` görmelisin).
- Bir turu yalnız dokunmatikle, bir turu yalnız kumandayla (dokunmatiğe dokunmadan) oyna.
- Native app'ler her parmağı id'siyle yalnızca `app.json` `"minNative": "1.1"` ya da üstünü söylüyorsa alır; 1.0 app'in
  dokunması eskisi gibi tek imleç kalır.
- İki parmak aynı anda: otomatik test komutu `finger <n> down|move|up <x> <y>` enjekte eder (iki id pinch, rotate ve
  iki parmak kaydırma yapar); SDL2 check örneği aynı anda basılı en çok parmağı yazar.
- Oynarken konsolu uyut ve uyandır: ses ve kayıtlı durum doğru olmalı.
