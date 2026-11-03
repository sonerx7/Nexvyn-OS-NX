# Asistan için denetim listesi (yanıt vermeden önce baştan sona geç)

[English](checklist.en.md) · **Türkçe**

Bu dosyayı asistana `system-prompt.tr.md` ile birlikte verin ya da bir isteğin sonuna yapıştırın:
"Yanıt vermeden önce checklist.tr.md listesinden geç ve tutmayan her şeyi düzelt."

## API

- [ ] Kullandığım her function, modül, alan, event türü, tuş adı ve app.json anahtarı SDK.tr.md / system-prompt.tr.md
      içinde var. Hiçbir şey uydurulmadı (`fetch`, `localStorage`, `io.open`, `os.listdir`, `ui.image`, `gfx.sprite`,
      `gfx.font`, özel shader... yok).
- [ ] Dil kuralları uygulandı: indeks tabanı (Lua 1, diğerleri 0), birden çok sonuç (Lua çoklu dönüş, JS dizi, Python
      tuple, Squirrel dizi, C pointer, Java `double[]`/`List`), `ui.textfield` / `ui.submitted`, `ui.row`.
- [ ] Async: Lua/Python/Squirrel callback; JS'de `try`/`catch` ile Promise; C'de `void* user` ile function pointer;
      Java'da `(Callback)` lambda.
- [ ] `minSdk` kullanılan en yeni özelliğe ve dile uyuyor (JS 1.1, Python 1.3, Squirrel/C/Java 1.5, `nexvyn.game`
      1.2, paylaşım/zamanlama/izin API'si/yaşam döngüsü callback'leri 1.4, `fs.unzip`/`sys.games`/`sys.speak` 1.6,
      `g3d.voxels` 1.7, `g3d.model`/`g3d.loadModel`/`g3d.drawMatrix` 1.8). Yeni app'ler `"targetSdk": "1.8"` yazar.
- [ ] Kullanıcı istemedikçe yeni app Squirrel ya da Java ile yazılmadı (SDK 1.8'de donduruldular).

## app.json

- [ ] Geçerli JSON; `id` ters alan adı (`com.ad.app`); `name` ve `description` en az `en` ile (başka diller yalnızca
      kullanıcı isterse).
- [ ] `runtime` / `main` (Java için `mainClass`) verdiğim dosyalarla uyuşuyor.
- [ ] `permissions` kodun kullandığını tam olarak listeliyor (`network`, `files`, `launch`, `notifications`, `games`);
      hiçbiri yoksa `[]`.
- [ ] `category` system, productivity, utilities, media, internet, games, developer, other'dan biri. Oyunlarda
      `"gamepad": true` ve yeniden boyutlanabilen pencere var.

## Davranış

- [ ] Hiçbir callback 3 saniyeye yaklaşamaz (`app.load` ve üst seviye 10 saniyeye): sınırsız döngü yok; modeller
      `g3d.loadModel` ile yükleniyor; uzun işler karelere, timer'lara ya da bir coroutine'e bölünmüş. C kodunda
      döngüler sınırlı (sistem onu durdurmaz).
- [ ] `draw` ucuz: her karede resim ya da model yükleme, dosya okuma, ağ çağrısı ya da büyük bellek ayırma yok;
      mesh'ler, modeller ve resimler bir kez oluşturuluyor.
- [ ] Veri değişince `store` / `fs` ile kaydediliyor; `suspend` ya da kapatmada hiçbir şey kaybolmuyor.
- [ ] Ağ: `sys.online()` denetleniyor, yükleniyor ve hata durumları gösteriliyor, kodda API anahtarı ya da sır yok.
- [ ] Dokunmatik, kumanda imleci ve klavyeyle çalışıyor; oyunlar kumandayla da, + ile ve `suspend` /
      `focus(false)` içinde duraklıyor.
- [ ] Görünen her metin `TR()` üzerinden geçiyor; her anahtar `lang/en.json` içinde (ve verdiğim her başka lang
      dosyasında, yoksa İngilizceye düşer); `{0}` yer tutucuları argument'larla uyuşuyor.
- [ ] Uygulamalar: `theme` renkleri (açık ve koyu mod); kontroller ≥ 28 px; yerleşim en küçük pencere boyutuna sığıyor.
- [ ] Widget id'leri pencerede benzersiz (listelerde `"Delete##" + i`).

## Oyunlar: görünüş ve kimlik

- [ ] Sanat yönünü yazdım (his, palet, tipografi, kamera, hareket, ses, arayüz biçimleri); başlık ekranı, HUD ve
      duraklatma ekranı ona uyuyor.
- [ ] Oyun arayüzü `ui.*` widget'larıyla ya da `theme` renkleriyle değil, `gfx` / `g3d` ile çizildi ve bir örneğin
      ya da başka bir oyunun menü düzenini, renklerini ya da başlık kompozisyonunu kopyalamıyor.
- [ ] 3B modeller: `.glb` (ya da `.fbx`), metre, +Y yukarı, +Z'ye bakıyor, pivot ayaklarda, klipler adlı; üçgen
      bütçesi korunuyor (kahraman 3-8 bin, karede 30-60 bin).
- [ ] Mağaza ikonu oyunun 256x256 key art'ı (kahraman, dünya, ışık, ad), abartılı ve gösterişli (dramatik ışık,
      güçlü rim ışığı, doygun renkler, parlama, sıkı kadraj, kalın logo), gradyan üstünde sembol değil; nasıl
      yapılacağını anlattım (`SDK/Tools/icon` ya da görsel üretici prompt'u).

## Oyunlar: kalite çıtası (SDK/Guides/GAME_FEEL.tr.md bölüm 8)

- [ ] Oyuncunun ve menünün her eyleminin aynı karede, olayla ölçekli bir sesi ve görsel tepkisi var (toplama küçük;
      ağır vuruşta parçacık, flaş, sarsıntı ve kısa hit-stop).
- [ ] Ses: varyantlı katmanlı efektler (`sfx` kiti ya da kendi tariflerim), tam seviyede ham, filtresiz square / saw
      yok, müzik ve ambiyans zemini, müzik efektlerin altında ve büyük anlarda kısılıyor, ses ayarları var.
- [ ] Renk: rolleri olan 4-6 renklik palet; düz tek renk arka plan yok (gradyan, parlama, vinyet, ışık, doku ya da
      paralaks); oyuncu ve tehlikeler gri tonda öne çıkıyor.
- [ ] Yazı: tek ölçekten 3-4 boyut; başlık stilli bir logo, varsayılan boyutta varsayılan yazı değil.
- [ ] Arayüz: tek şekil dili; derinliği olan paneller; hover, basılı, odak ve devre dışı hâlleri olan düğmeler; her
      iki ekran arasında geçiş; başlık ekranında canlı bir şey.
- [ ] Kamera: yumuşak; 3D'de gökyüzü renginde sis ve renkli ana ışık.
- [ ] Kitlerin uyduğu yerde onları kullandım (`sfx`, `juice` bundle'a kopyalandı), daha zayıf kopyalarını uydurmadım
      ve yalnızca gerçekten var olan fonksiyonlarını kullandım.

## Yanıt

- [ ] Her dosya eksiksiz ("..." ya da "gerisi aynı" yok) ve bundle içindeki yoluyla verildi.
- [ ] Kullanıcının dilinde yanıt verdim; app'in metinleri İngilizce artı kullanıcının istediği diller.
- [ ] Nasıl denetleneceğini (`lua_check.py` / `js_check.mjs` / `py_check.py` / `rt_check.py` ya da `nxv check`) ve
      nasıl çalıştırılacağını (`sdmc:/NexvynOS/Applications/<Ad>.nxvapp/` içine kopyala ya da Studio → Çalıştır)
      söyledim.
- [ ] Sessizce tahmin etmek yerine emin olmadığım şeyleri listeledim.
- [ ] Mağaza başvurusu için: en az İngilizce `subtitle` / `description` (istenirse başka diller), `kind`, `tags` ve
      yalnızca `wait`, `wclick`, `wmove`, `key`, `dpad`, `text`, `dark` kullanan `shots` içeren `store.json`.
