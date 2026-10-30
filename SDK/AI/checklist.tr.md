# Asistan için denetim listesi (yanıt vermeden önce baştan sona geç)

[English](checklist.en.md) · **Türkçe**

Bu dosyayı asistana `system-prompt.tr.md` ile birlikte verin ya da bir isteğin sonuna yapıştırın:
"Yanıt vermeden önce checklist.tr.md listesinden geç ve tutmayan her şeyi düzelt."

## API

- [ ] Kullandığım her function, modül, alan, event türü, tuş adı ve app.json anahtarı SDK.tr.md / system-prompt.tr.md
      içinde var. Hiçbir şey uydurulmadı (`fetch`, `localStorage`, `io.open`, `os.listdir`, `ui.image`, `gfx.sprite`...
      yok).
- [ ] Dil kuralları uygulandı: indeks tabanı (Lua 1, diğerleri 0), birden çok sonuç (Lua çoklu dönüş, JS dizileri,
      Python tuple'ları, Squirrel dizileri, C işaretçileri, Java `double[]`/`List`), `ui.textfield` / `ui.submitted`,
      `ui.row`.
- [ ] async: Lua/Python/Squirrel callback'leri; JS Promise'leri `try`/`catch` ile; C function işaretçileri
      `void* user` ile; Java `(Callback)` lambda'ları.
- [ ] `minSdk` kullanılan en yeni özelliğe ve dile uyuyor (JS 1.1, Python 1.3, Squirrel/C/Java 1.5, `nexvyn.game` 1.2,
      paylaşım/zamanlama/izin API'si/yaşam döngüsü callback'leri 1.4).

## app.json

- [ ] Geçerli JSON; `id` ters alan adı biçiminde (`com.ad.uygulama`); `name` ve `description` en az `en` ve `tr` ile.
- [ ] `runtime` / `main` (ve Java için `mainClass`) verdiğim dosyalarla eşleşiyor.
- [ ] `permissions` kodun kullandığını tam olarak listeliyor (`network`, `files`, `launch`, `notifications`,
      `games`); hiçbir şey yoksa `[]`.
- [ ] `category` şunlardan biri: system, productivity, utilities, media, internet, games, developer, other. Oyunlarda
      `"gamepad": true` ve boyutlandırılabilir bir pencere var.

## Davranış

- [ ] Hiçbir callback 3 saniyeye yaklaşamaz (sınırsız döngü yok; uzun işler karelere ya da timer'lara
      bölündü). C kodundaki döngüler sınırlı (sistem onu durdurmaz).
- [ ] `draw` hafif: karede bir resim yükleme, dosya okuma, ağ çağrısı ya da büyük allocation yok; mesh'ler ve
      resimler bir kez oluşturuluyor.
- [ ] Veriler değişince `store` / `fs` ile kaydediliyor; `suspend` ya da kapanışta hiçbir şey kaybolmuyor.
- [ ] Ağ: `sys.online()` denetleniyor, yükleniyor ve hata durumları gösteriliyor, kodda API anahtarı ya da gizli bilgi
      yok.
- [ ] Dokunmatik, kumanda imleci ve klavyeyle çalışıyor; oyunlar ayrıca kumandayla da (ve duraklatma ile).
- [ ] Görünen her metin `TR()`'den geçiyor; her anahtar `lang/en.json` ve `lang/tr.json` içinde var; `{0}` yer
      tutucuları argument'larle eşleşiyor. Yorumlarda var olmayan anahtarlar için `TR("...")` örnekleri yok.
- [ ] Arayüzde `theme` renkleri (açık ve koyu mod); denetimler ≥ 28 px; yerleşim en küçük pencere boyutuna sığıyor.
- [ ] Widget id'leri pencerede benzersiz (listelerde `"Delete##" + i`).

## Yanıt

- [ ] Her dosya eksiksiz ("..." ya da "geri kalanı aynı" yok), bundle içindeki yoluyla birlikte.
- [ ] Nasıl denetleneceğini (`lua_check.py` / `js_check.mjs` / `py_check.py` / `rt_check.py` ya da `nxv check`) ve nasıl
      çalıştırılacağını (`sdmc:/NexvynOS/Applications/<Ad>.nxvapp/` içine kopyala ya da Studio → Çalıştır) söyledim.
- [ ] Sessizce tahmin etmek yerine emin olmadığım şeyleri listeledim.
- [ ] Açıklamalar kullanıcının dilinde; kod adları, app.json anahtarları ve dosya adları değiştirilmedi.
- [ ] Mağaza başvurusu için: en, tr, de, fr, es dillerinde `subtitle` / `description`, `kind`, `tags` ve yalnızca
      `wait`, `wclick`, `wmove`, `key`, `dpad`, `text`, `dark` kullanan `shots` içeren `store.json`.
