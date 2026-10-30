# Nexvyn OS Uygulama SDK'sı (.nxvapp)

[English](SDK.en.md) · **Türkçe**

> **Özet:** Nexvyn OS uygulamaları Lua 5.4 ile yazılır. Bir uygulama, içinde `app.json`, `main.lua` ve
> `icon.png` bulunan `Adı.nxvapp` klasörüdür. Klasörü (veya zip'lenmiş `.nxvapp` dosyasını) SD karttaki
> `sdmc:/NexvynOS/Applications/` içine koyun; uygulama Başlatıcı'da ve Hızlı Arama'da görünür ve çalışır.
> Hata olursa pencerede satır numaralı hata ekranı çıkar ve log `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.
> Aynı SDK JavaScript, Python, Squirrel, C ve Java ile de kullanılabilir (bölüm 11–15; `app.json` içinde `"runtime"`).
> Bu belge İngilizce asıl belgenin ([SDK.en.md](SDK.en.md)) tam Türkçe çevirisidir; bir yapay zekâya "Bu SDK ile Nexvyn OS
> için ... uygulaması yaz" demeniz yeterlidir.

Bu belge, üçüncü taraf Nexvyn OS uygulamalarının eksiksiz sözleşmesidir. Bir geliştiricinin **ya da bir yapay zekâ
asistanının** yalnızca bu belgeye bakarak çalışan bir uygulama üretebileceği şekilde yazılmıştır. Burada listelenen
her şey vardır; başka hiçbir şey yoktur.

## 1. Bundle yapısı

```
MyApp.nxvapp/              ← klasör adı .nxvapp ile biter (ya da klasörün içeriğini MyApp.nxvapp adıyla zip'leyin)
├── app.json              ← bildirim dosyası (zorunlu)
├── main.lua              ← giriş noktası (zorunlu)
├── icon.png              ← 128×128 ya da 256×256, saydamlıklı PNG (önerilir)
├── lang/en.json          ← çeviriler (isteğe bağlı): {"hello": "Hello"}
├── lang/tr.json          ←                          {"hello": "Merhaba"}
└── diğer her şey          (görseller, sesler, require("ad") ile yüklenen başka .lua modülleri)
```

Kurulum: klasörü ya da `.nxvapp` olarak yeniden adlandırılmış zip'ini **`sdmc:/NexvynOS/Applications/`** içine
kopyalayın ve Başlatıcı'yı yeniden açın (zip'ler açılışta ya da *Uygulama Mağazası → Dosyadan Yükle* ile otomatik olarak
açılır). Dosyalar'da bir `.nxvapp` dosyasını açmak, **Çalıştır** ve **Yükle** düğmeleriyle kurulum sayfasını (ayrıntılar,
izinler, dosya denetimi) gösterir. Yayımlamak için klasörü `python tools/nxvapp_pack.py MyApp.nxvapp` ile package haline getirin
(`manifest.sha256` ekler); `--sign key.pem` ekleyin (`python tools/nxvapp_keygen.py` ile üretilen bir anahtar), böylece
kurulum sayfası **<parmak izi> tarafından imzalandı** gösterir ve bir güncelleme başka bir anahtardan gelirse
kullanıcıyı uyarır. Package biçiminin tamamı, imzalama, izin kuralları ve depo dizini `docs/NXVAPP_FORMAT.tr.md` içindedir.

### app.json

```json
{
  "id": "com.yourname.myapp",
  "name": {"en": "My App", "tr": "Uygulamam"},
  "description": {"en": "What it does", "tr": "Ne yaptığı"},
  "version": "1.0",
  "author": "Your Name",
  "homepage": "https://github.com/yourname",
  "category": "utilities",
  "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 640, "height": 480, "minWidth": 320, "minHeight": 240, "resizable": true},
  "singleInstance": true,
  "gamepad": false,
  "fileTypes": [".txt"],
  "shareTargets": ["text", "url", ".txt"],
  "minSdk": "1.4",
  "targetSdk": "1.6",
  "permissions": ["network", "notifications"]
}
```

- `id` benzersiz olmalıdır (ters alan adı biçimi). `name`/`description` düz metin de olabilir.
- `runtime`, `main` belirlemediğinde dili seçer: `"lua"` (varsayılan), `"js"` (bölüm 11), `"python"` (12),
  `"python3"` (12, CPython), `"squirrel"` (13), `"c"` (14) ya da `"java"` (15, `"mainClass"` ile). `.js`, `.py`, `.nut`,
  `.c` ya da `.jar` uzantılı bir ana dosya da dili seçer (`.py`, `"python"` demektir).
- `author` ve `homepage` (isteğe bağlı; bir web ya da GitHub adresi) uygulamanın Hakkında penceresinde ve App
  Store'da gösterilir.
- `category`: `system`, `productivity`, `utilities`, `media`, `internet`, `games`, `developer`, `other`.
- `window.width/height` **içerik** boyutudur (başlık çubuğunu sistem ekler).
- `gamepad: true` → pencere odaktayken kumanda imleci hareket ettirmek yerine uygulamaya gider (oyunlar).
  Kullanıcı imleci geri almak için **L+R**'ye basar. Dokunmatik her zaman çalışır.
- `fileTypes` → uygulama "Birlikte Aç" listesinde görünür ve dosya yolunu `app.load(arg)` / `app.open(arg)` içinde alır.
- `minSdk` → uygulamanın çalıştığı en eski SDK sürümü (aşağıdaki *SDK sürümleri*ne bakın). Nexvyn OS daha yeni bir
  SDK isteyen uygulamayı kurmaz; uygulamanın daha yeni bir Nexvyn OS gerektirdiğini söyler. Yalnızca SDK 1.0 kullanan
  uygulamalarda yazmayın.
- `targetSdk` → uygulamayı derleyip test ettiğiniz SDK sürümü (varsayılanı `minSdk`, o da yoksa `"1.0"`). Sonraki
  sistemler uygulamanız için o SDK'daki gibi davranmayı sürdürür (aşağıdaki *Uyumluluk*a bakın). Studio yeni projelere
  güncel SDK'yı yazar. `runtimeVersion` (isteğe bağlı) test ettiğiniz motor sürümünü kaydeder, örneğin pocketpy için
  `"2.2"`.
- `shareTargets` → uygulamanın `sys.share` (bölüm 8a) ile neyi kabul ettiği: `"text"` (her metin), `"url"`
  (`http://`, `https://` ya da `nxv://` ile başlayan metin), `"file"` (her dosya), `"image"` (.png .jpg .jpeg .bmp .gif
  .webp) ya da `".txt"` gibi bir dosya uzantısı. Paylaşılan öğe, uygulamanın birlikte açıldığı bir dosya gibi gelir:
  uygulama çalışmıyorsa `app.load(arg)`, çalışıyorsa `app.open(arg)`.
- `permissions` → uygulamanın kendi klasörleri dışında neye ihtiyaç duyduğu. SD karta kurulan uygulamalarda **her izin
  zorunlu olarak uygulanır** (SDK 1.4; öncesinde yalnızca `network` ve `files` uygulanıyordu):

  | İzin | Neyi denetler | İzin yoksa |
  |---|---|---|
  | `"network"` | `net.*` | Callback'ler `error = "permission denied: network"` bildirir |
  | `"files"` | uygulamanın bundle, veri ve cache klasörleri dışındaki yollar | `fs.read` → nil, `fs.write` → false, mutlak `fs.path` → `""` |
  | `"launch"` | `sys.launch(otherId)`, `sys.open("nxv://...")` | nil, `"permission denied: launch"` döner (JS/Python: `false`) |
  | `"notifications"` | `sys.notify`, `sys.schedule` | nil, `"permission denied: notifications"` döner (JS/Python: `false`) |
  | `"games"` | `sys.games` (SDK 1.6) | çağrı başarısız olur (nil; JS `null`, Python `None`) |

  Uygulama başına tek bir karar vardır ve kurulumda verilir: izinler kurulum sayfasında listelenir, **Yükle** demek
  hepsine izin vermek demektir; **Özelleştir** ile tek tek kapatılabilir. Kayıtlı bir yanıt yoksa (ör. paket elle
  kopyalandıysa) ilk açılışta bir kez sorulur. Çalışırken çıkan tek soru `sys.requestPermission`'dır.
  Dizide olmayan bir izin asla verilmez ve her ret, nedeniyle birlikte ("app.json içinde bildirin" ya da "kullanıcı
  izin vermedi") uygulamanın günlüğüne yazılır. Kullanıcının `ui.openFile`/`ui.saveFile` ile seçtiği, uygulamayı
  birlikte açtığı ya da uygulamayla paylaştığı dosyalara her zaman izin verilir. Kullanıcının metin alanlarında kendi
  yaptığı kopyala/yapıştır ve `sys.clipboard` izin gerektirmez. `permissions` dizisi olmayan bir bundle için hepsi sorulur. Uygulamanın
  hiçbir şeye ihtiyacı yoksa diziyi boş bırakın. `sys.hasPermission(name)` ve `sys.requestPermission(name, fn)` bölüm
  8a'dadır.

### SDK sürümleri

`sys.sdkVersion()` bu sistemin sağladığı sürümü döndürür (`"1.6"`). Daha yeni bir şey kullandığınızda `minSdk`'yı
yükseltin.

| SDK | Nexvyn OS'un ekledikleri |
|-----|-------------|
| 1.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | Aynı modüller ve Promise'lerle JavaScript runtime (bölüm 11); GPU'da `g3d` texture'ları |
| 1.2 | `nexvyn.game` motoru (bölüm 8c), `sys.sdkVersion()`, app.json `minSdk` ve `permissions`, `manifest.sha256` ile tek dosyalık `.nxvapp` v2 |
| 1.3 | Aynı modüllerle Python runtime (bölüm 12, pocketpy); async çağrılar callback alır |
| 1.4 | her izin zorunlu; `sys.share`, `sys.schedule` / `unschedule` / `scheduled`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `sys.open` içinde `nxv://` bağlantıları; `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved` callback'leri; app.json `shareTargets`; imzalı package'lar; Lua uygulamaları için de 64 MB sınırı |
| 1.5 | Tek ortak uygulama üzerinde Squirrel (bölüm 13), konsolda derlenen C (bölüm 14) ve Java (bölüm 15) runtime'lar; app.json `"runtime"` değerleri `"squirrel"`, `"c"`, `"java"` ve `"mainClass"`; Python sistem kütüphanesi (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |
| 1.6 | `fs.unzip` (bir zip'i arka planda ilerlemeyle açar) ve yeni `"games"` izniyle `sys.games` (yüklü oyunlar), Lua, JavaScript, Python ve Squirrel'da; her runtime'da `sys.speak` / `sys.stopSpeaking` (metin okuma, izin gerekmez); `"python3"` runtime'ı (CPython 3.12, bölüm 12) |

### Uyumluluk: targetSdk ve deprecation

Sözleşmenin tamamı `docs/COMPATIBILITY.tr.md`'dedir. Kısaca:

- **Hiçbir şey kaldırılmaz.** Burada listelenen her fonksiyon sonraki her Nexvyn OS'ta çalışmayı sürdürür. Yerine
  yenisi gelen bir fonksiyon *deprecated* olur: yine çalışır ve bir çalıştırmadaki ilk çağrı uygulamanızın log'una
  `deprecated: <ad> still works; use <yenisi>` yazar (Studio'nun konsolu gösterir). Bugün deprecated olanlar:
  `require("snx.*")` → `require("nexvyn.*")`; `"clipboard"` izni kabul edilir ve yok sayılır.
- **Davranış değişiklikleri isteğe bağlıdır.** Sonraki bir SDK var olan bir fonksiyonun davranışını değiştirirse yeni
  davranışı yalnızca `targetSdk`'si o SDK olan uygulamalar alır; başvuru bunu "SDK x'i hedefleyen uygulamalar için"
  diye işaretler. Yeni sistemde test ettikten sonra `targetSdk`'yi yükseltin.
- **Eski sistemde daha yeni uygulamalar.** `minSdk`'si sistemin SDK'sının üstünde olan ya da `"runtime"`'ı sistemde
  bulunmayan bir uygulama daha yeni bir Nexvyn OS gerektiriyor diye gösterilir: kurulmaz, Uygulama Mağazası onu
  güncelleme olarak asla önermez ve SD kartta zaten olan bir kopya bunu söyleyen bir pencere açar. Bilinmeyen app.json
  alanları ve bilinmeyen izinler yok sayılır.
- **Runtime'lar kalır.** Bir dil runtime'ı uygulamalar onu kullandıkça asla kaldırılmaz; yeni bir motor sürümü
  yayımlanmadan önce uygulama uyumluluk suite'inden (`tools/compat_check.py`, her mağaza uygulaması, oyun ve örnek)
  geçmelidir.

### Temalar (.nxvtheme)

Temalar uygulama değildir: bir `.nxvtheme`, `theme.json` ve resimler (isteğe bağlı olarak arayüz sesleri) içeren,
kod içermeyen bir zip'tir. Görünümü (`"light"`/`"dark"`/`"auto"`), vurgu rengini (`"#RRGGBB"`), duvar kâğıdını
(1280×720, artı isteğe bağlı `wallpaperDark`) ve izin listesindeki birkaç ayarı (`dock.size`,
`appearance.reduceTransparency`, ...) belirler:

```json
{"id": "com.you.theme.dusk", "name": {"en": "Dusk", "tr": "Alacakaranlık"}, "version": "1.0", "author": "You",
 "appearance": "auto", "accent": "#FF7A59", "wallpaper": "wallpaper.jpg", "wallpaperDark": "wallpaper-dark.jpg"}
```

Dosyayı Dosyalar'da açmak **Yükle** / **Yükle ve Uygula** seçeneklerini sunar; kurulu temalar
`~/Library/Themes/<id>/` içinde durur ve *Sistem Ayarları > Görünüm > Temalar* bölümünden yönetilir. Biçimin tamamı,
sınırlar ve ayar anahtarları: `docs/NXVAPP_FORMAT.tr.md` bölüm 9.

## 2. Program yapısı

`main.lua` bir callback tablosu döndürür. Tüm callback'ler isteğe bağlıdır.

```lua
local app = {}

Function app.load(arg)            -- bir kez; arg = uygulamanın birlikte açıldığı dosya yolu / URL / ""
end

Function app.open(arg)            -- uygulama çalışırken başka bir şeyi açması istendi
end

Function app.update(dt)           -- her karede (~60 fps), dt saniye cinsinden
end

Function app.draw(w, h)           -- her karede: çiz VE widget'ları işle; w,h = piksel cinsinden içerik boyutu
  gfx.clear(theme.bg)
end

Function app.event(e)             -- ham girdi (bkz. §5)
end

Function app.menu()               -- isteğe bağlı menü çubuğu menüleri
  return { { title = TR("game"), items = { {label = TR("new"), id = 1, shortcut = "Ctrl+N"}, "-", {label = "...", id = 2} } } }
end

Function app.onmenu(id) end

Function app.close()              -- pencereyi açık tutmak için false döndürün (ör. önce kaydetmeyi sorun)
  return true
end

-- SDK 1.4 (hepsi isteğe bağlı)
Function app.search(query)        -- Hızlı Arama çalışan uygulamalara sorar; en fazla birkaç öğe döndürün
  return { {title = "Note: " .. query, subtitle = "My App", icon = "description", arg = "note:42"} }
end                               -- bir öğe seçmek app.open(arg)'ı çağırır (uygulama kapalıysa app.load(arg)'ı)
Function app.suspend() end        -- Nexvyn OS arka plana geçer (HOME menüsü, uyku): duraklat, kaydet
Function app.resume() end         -- yeniden ön planda / konsol uyandı (ağ kopmuş olabilir)
Function app.focus(focused) end   -- pencere klavye odağını aldı (true) / kaybetti (false)
Function app.autosave() end       -- düzenli kayıt noktası; çıkış / yeniden başlatma / kapatma öncesinde de: sessizce kaydet
Function app.unsaved()            -- iş kaybolacaksa true; kabuk çıkmadan önce bu tür uygulamaları listeler
  return false
end

return app
```

Koordinatlar pikseldir; (0,0) pencere içeriğinin sol üst köşesidir; y aşağı doğru artar. Açılar radyandır, 0 = sağı
gösterir, saat yönünde artar. Renkler `"#RRGGBB"` / `"#RRGGBBAA"` onaltılık metinleri, `{r,g,b[,a]}` tabloları
(0–255) ya da belirtilen yerlerde 3–4 sayıdır.

Hatalar: bir callback hata fırlatırsa pencere iletiyi bir stack trace ve **Yeniden Yükle** düğmesiyle gösterir;
`print()`/`sys.log()` çıktısı ve hatalar `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına gider. 3 saniyeden uzun
süren bir callback durdurulur (sonsuz döngü koruması). Her uygulama **64 MB**'a kadar betik belleği kullanabilir
(JavaScript ve Python gibi Lua da SDK 1.4'ten beri): bu aşılırsa uygulama `MemoryError: out of memory (the app used
more than 64 MB)` ile ve bir bellek yetersiz ekranıyla durur; sistemin geri kalanı çalışmaya devam eder.
`sys.memory()` sınıra ne kadar yakın olduğunuzu söyler. `store`, `app.suspend` / `app.autosave` sırasında da diske
yazılır; böylece uyuyan bir konsol onu kaybetmez.

Kullanılabilen standart Lua: `string`, `table`, `math`, `utf8`, `coroutine`, `os.time/os.clock/os.date/os.difftime`,
`pcall`, `select`, `ipairs`/`pairs`, `tostring`… (`io`, `debug`, `package`, `dofile`, `loadfile` yoktur — `fs`
kullanın). `require("name")` bundle'ınızdan `name.lua` dosyasını yükler; `require("a.b")` `a/b.lua` dosyasını yükler.
Bundle'da olmayan modüller `romfs:/System/Lua/` sistem Lua kütüphanesinden gelir (örneğin `require("nexvyn.game")`,
bkz. 8c).

## 3. Çizim — `gfx`

| Function | Açıklama |
|---|---|
| `gfx.color(c)` / `gfx.color(r,g,b[,a])` | sonraki çizim çağrıları için geçerli renk |
| `gfx.clear([c])` | tüm içerik alanını doldurur |
| `gfx.rect(x,y,w,h[,radius[,c]])` | dolu (yuvarlak köşeli) dikdörtgen |
| `gfx.rectLine(x,y,w,h[,radius[,thickness]])` | çerçeve |
| `gfx.circle(x,y,r[,c])`, `gfx.circleLine(x,y,r[,t])` | dolu / çerçeve daire |
| `gfx.line(x1,y1,x2,y2[,thickness])` | anti-aliased çizgi |
| `gfx.lines({x1,y1,x2,y2,...}[,thickness[,closed]])` | çoklu çizgi |
| `gfx.poly({x1,y1,...}[,c])` | dolu **dışbükey** çokgen |
| `gfx.arc(x,y,r,a0,a1[,thickness])`, `gfx.pie(x,y,r,a0,a1)` | yay / dolu dilim |
| `gfx.gradient(x,y,w,h,c1,c2[,horizontal[,radius]])` | renk geçişi (varsayılan dikey) |
| `gfx.shadow(x,y,w,h[,radius[,blur[,dy]]])` | yumuşak gölge (şekilden önce çizin) |
| `gfx.text(s,x,y[,size[,font[,align,width]]])` → genişlik | `y` satırın üstüdür. font: `"sans"`,`"medium"`,`"semibold"`,`"bold"`,`"italic"`,`"mono"`,`"monobold"`. `width` içinde hizalama `"left"`/`"center"`/`"right"` |
| `gfx.textWidth(s[,size[,font]])`, `gfx.textHeight([size[,font]])` | ölçme |
| `gfx.wrap(s,x,y,w[,size[,font[,align[,lineSpacing]]]])` → yükseklik | sözcük kaydırmalı paragraf |
| `gfx.measureWrap(s,w[,size[,font]])` → yükseklik | |
| `gfx.icon(name,cx,cy[,size[,c]])` | cx,cy merkezli Material Icons Round simgesi (ör. `"favorite"`, `"play_arrow"`, `"settings"`, `"delete"`, `"star"`, `"refresh"`) |
| `gfx.image(path)` → img ya da nil | PNG/JPG/WEBP/BMP/GIF yükler (cache'lenir). Göreli yollar veri klasörünüzdedir; uygulamayla gelen dosyalar için `"bundle:/img/x.png"` kullanın |
| `img.width`, `img.height` | |
| `gfx.draw(img,x,y[,w,h[,radius[,tint]]])` | (ölçekli) çizer |
| `gfx.drawRegion(img,sx,sy,sw,sh,x,y,w,h[,angleDeg])` | bir görselin bir bölümünü çizer (sprite sayfaları) |
| `gfx.push(dx,dy)` / `gfx.pop()` | sonraki çizimleri kaydırır |
| `gfx.clip(x,y,w,h)` / `gfx.unclip()` | çizimi sınırlar (iç içe kullanılabilir) |
| `gfx.alpha(a)` / `gfx.unalpha()` | opaklığı çarpar (iç içe kullanılabilir) |
| `gfx.size()` → w,h | içerik boyutu |

`theme`, sistem renklerini onaltılık metin olarak tutar ve açık/koyu moda göre canlı güncellenir:
`theme.dark` (bool), `theme.bg`, `theme.window`, `theme.sidebar`, `theme.text`, `theme.text2`, `theme.text3`,
`theme.separator`, `theme.control`, `theme.field`, `theme.selection`, `theme.hover`, `theme.accent` ve
`theme.red/orange/yellow/green/blue/purple/pink/gray`. Uygulamanın iki modda da doğru görünmesi için bunları kullanın.

## 4. Widget'lar — `ui`

Immediate mode: widget'ı her karede `app.draw` içinde çağırın; kendini çizer ve ne olduğunu döndürür.
Widget'lar etiketleri ya da `id` metinleriyle tanınır — id'leri pencere içinde benzersiz tutun (bir etiketi son eki
göstermeden benzersiz yapmak için sonuna `"##sonek"` ekleyin).

| Function | Döndürdüğü |
|---|---|
| `ui.button(label,x,y,w,h[,style[,icon[,enabled]]])` style: `"default"`,`"primary"`,`"destructive"`,`"plain"`,`"toolbar"`,`"link"` | tıklandığında `true` |
| `ui.iconButton(icon,x,y,w,h[,tint[,active[,idSuffix]]])` | tıklandı mı |
| `ui.toggle(id,value,x,y[,w,h])` | yeni boolean |
| `ui.checkbox(label,value,x,y)` | yeni boolean |
| `ui.radio(label,selected,x,y)` | tıklandı mı |
| `ui.slider(id,value,min,max,x,y,w[,step])` | yeni sayı |
| `ui.textfield(id,text,x,y,w[,h[,placeholder[,flags]]])` flags: `"search"`, `"password"`, `"numeric"`, `"readonly"` (boşlukla birleştirin) | `newText, submitted` (Enter) |
| `ui.segmented(id,{items},selected,x,y,w[,h])` (1 tabanlı) | yeni sıra numarası |
| `ui.dropdown(id,{items},selected,x,y,w[,h])` (1 tabanlı) | yeni sıra numarası |
| `ui.label(text,x,y[,size[,color[,font]]])` | |
| `ui.progress(value,x,y,w[,h])` (0..1 ya da -1 = belirsiz) | |
| `ui.spinner(x,y[,radius])` | |
| `ui.row(id,x,y,w,h,selected)` üzerine gelme/seçim vurgulu liste satırı | `clicked, doubleClicked` |
| `ui.group(x,y,w,h)` ayarlar tarzı yuvarlak bölüm, `ui.separator(x1,y,x2)` | |
| `ui.beginScroll(id,x,y,w,h,contentHeight[,contentWidth])` → scrollY, scrollX … `ui.endScroll()` | alt öğeler içerik koordinatlarında çizilir (0,0 = içeriğin üstü); sürükleme/dokunma/çubukla kaydırma yerleşiktir |
| `ui.hit(id,x,y,w,h)` özel tıklanabilir alan | `{hovered, held, pressed, clicked, rightClicked, doubleClicked, dx, dy}` tablosu |
| `ui.mouse()` | `x, y, down, hovering` (yerel koordinatlarda işaretçi) |
| `ui.focus(id)` | bir metin alanına odaklanır |
| `ui.contextMenu({ {label=..., id=1, icon="..."}, "-", ... }, function(id) end)` | işaretçinin olduğu yerde açılır |
| `ui.alert(title, message, {"OK","Cancel"}, function(buttonIndex) end)` (1 tabanlı) | sistem iletişim kutusu |
| `ui.prompt(title, message, default, function(textOrNil) end)` | metin girişi iletişim kutusu |
| `ui.openFile(function(pathOrNil) end, {".txt",".md"}[, title])` | sistem açma iletişim kutusu |
| `ui.saveFile(function(pathOrNil) end, "name.txt"[, title])` | sistem kaydetme iletişim kutusu |
| `ui.keyboard(initial, function(textOrNil) end[, guide])` | Nintendo sistem klavyesi |

Bir metin alanı odaklandığında ekran klavyesi kendiliğinden açılır.

## 5. Girdi — `app.event`, `input`

`app.event(e)`: `e.type` şunlardan biridir: `"mousedown"`, `"mouseup"`, `"mousemove"`, `"scroll"`, `"keydown"`,
`"keyup"`, `"text"`, `"paddown"`, `"padup"`. Alanlar: `e.x, e.y` (yerel), `e.button` (`"left"`/`"right"`), `e.clicks`,
`e.dx, e.dy` (kaydırma pikseli), `e.key` (`"a"`…`"z"`, `"0"`…`"9"`, `"left"`,`"right"`,`"up"`,`"down"`,`"enter"`,
`"escape"`,`"backspace"`,`"delete"`,`"tab"`,`"space"`,`"home"`,`"end"`,`"pageup"`,`"pagedown"`,`"f1"`…), `e.text`
(yazılan UTF-8), `e.pad` (`"a"`,`"b"`,`"x"`,`"y"`,`"l"`,`"r"`,`"zl"`,`"zr"`,`"plus"`,`"minus"`,`"up"`,`"down"`,`"left"`,
`"right"`,`"lstick"`,`"rstick"`), `e.touch`, `e.shift`, `e.ctrl`, `e.cancel` (tıklama sayılmaması gereken mouseup).

Dokunmatik ekrandaki iki parmak hareketleri ayrıca `"pinch"` ve `"rotate"` gönderir (`e.touch` true'dur, `e.x, e.y`
parmakların arasındaki noktadır):

- `"pinch"`: `e.scale`, önceki pinch event'inden bu yana parmaklar arası uzaklıktaki değişimdir (> 1 = açılma, < 1 =
  kapanma). Yakınlaştırmanızı bununla çarpın: `zoom = zoom * e.scale`.
- `"rotate"`: `e.angle`, önceki rotate event'inden bu yana açıdaki değişimdir, radyan cinsinden (pozitif = saat yönü).
- İkisi de parmaklar biraz hareket ettikten sonra başlar; böylece sıradan bir iki parmakla sürükleme `"scroll"` olarak
  kalır. Pinch ya da rotate sırasında iki parmak `"scroll"` event'leri gelmeye devam eder; böylece aynı anda kaydırıp
  yakınlaştırabilirsiniz.

```lua
Function app.event(e)
  if e.type == "pinch" then zoom = math.max(0.25, math.min(8, zoom * e.scale))
  elseif e.type == "rotate" then angle = angle + e.angle end
end
```

İşaretçi girdisi dokunmatikten, kumanda imlecinden (A = tıklama, X = sağ tıklama, sağ çubuk = kaydırma, D-pad = ok
tuşları, B = Escape) ve USB fare/klavyeden gelir. Kumanda event'leri (`paddown`/`padup`) yalnızca `"gamepad": true`
olduğunda gelir.

Yoklama: `input.down(button)`, `input.pressed(button)` / `input.released(button)` (bu karede),
`input.stick("left"|"right")` → -1..1 aralığında x, y (yukarı y = pozitif), `input.key(name)` (bu karede basıldı),
`input.touch()` (kullanıcı dokunmatik ekranda).

## 6. Dosyalar — `fs`

Göreli yollar uygulamanın özel veri klasöründedir (`~/Library/Application Support/<id>/`, sizin için oluşturulur).
`"bundle:/..."` bundle'ınızla gelen dosyaları okur. Mutlak yollar (`"sdmc:/..."`, `"romfs:/..."`) da çalışır.

`fs.read(path)` → metin ya da nil,err · `fs.write(path, data)` → ok · `fs.append(path, data)` ·
`fs.exists(path)` · `fs.isdir(path)` · `fs.list(path[, showHidden])` → `{ {name, path, dir, size, mtime}, ... }`
(önce klasörler) · `fs.mkdir(path)` · `fs.remove(path[, permanently])` (varsayılan: Çöp Kutusu'na) ·
`fs.rename(a, b)` · `fs.copy(a, b)` · `fs.path(relative)` → mutlak ·
`fs.dir(which)` → `"data"`, `"bundle"`, `"cache"`, `"home"`, `"documents"`, `"desktop"`, `"downloads"`, `"pictures"`,
`"music"` için mutlak klasör.

Basit kalıcılık: `store.get(key[, default])`, `store.set(key, value)` (JSON benzeri her değer; bir saniye içinde ve
kapanışta otomatik kaydedilir), `store.save()`.

JSON: `json.decode(text)` → değer ya da nil,err · `json.encode(value[, pretty])` → metin.

## 7. Ağ — `net`

Tüm istekler asyncdır; callback daha sonra ana thread'de çalışır. HTTPS desteklenir.

```lua
net.get("https://api.example.com/x", function(res)
  if res.ok then print(res.body) else print(res.status, res.error) end
end)
net.get(url, {["Accept"]="application/json"}, callback)          -- ek başlıklar
net.post(url, body[, contentType], callback)                      -- varsayılan x-www-form-urlencoded
net.json(url, function(data, err) end)                            -- GET + json.decode
net.download(url, "files/x.zip", function(ok, pathOrError) end, function(now, total) end)
net.encode("a b&c")                                               -- URL kodlama
```

`res`: `ok` (2xx/3xx), `status`, `body`, `error`, `url` (yönlendirmelerden sonra), `headers` (küçük harfli adlar).
Önce `sys.online()` ile denetleyin ve çevrimdışıyken anlaşılır bir ileti gösterin.

## 8. Sistem — `sys`, `audio`, `timer`, `TR`

`sys.time()` saniye (monoton, animasyon için) · `sys.epoch()` Unix zamanı · `sys.date([epoch])` → konsolun yerel
saatinde `{year, month, day, hour, min, sec, wday (0=Pazar), yday, epoch}` · `sys.battery()` → yüzde, şarj oluyor mu ·
`sys.online()` · `sys.lang()` (`"tr"`, `"en"`, …) · `sys.username()` · `sys.model()` · `sys.firmware()` ·
`sys.notify(title, body)` (bildirim şeridi) · `sys.open(path)` (doğru uygulamayla açar) · `sys.launch(appId[, arg])` ·
`sys.clipboard([text])` al/ayarla · `sys.log(...)` / `print(...)` · `sys.title(text)` pencere başlığı · `sys.exit()`
pencereyi kapatır · `sys.fps()` · `sys.vibrate([strength 0..1[, ms]])` (HD titreşim) · `sys.appid()` ·
`sys.sdkVersion()` → `"1.6"` (bkz. *SDK sürümleri*). `sys.notify`, (başka bir uygulama için) `sys.launch`,
`sys.games` ve `nxv://` bağlantıları kendi izinlerini gerektirir (bölüm 1).

`sys.speak(text[, lang])` (SDK 1.6, izin gerekmez) metni yerleşik sesle okur; o an söylenenin ardından sıraya girer ve
çağrı hemen döner. `lang`: `"en"`, `"tr"`, `"de"`, `"fr"`, `"es"`, `"ja"` ya da `"ko"` (varsayılan: Ayarlar >
Erişilebilirlik > Ekran Okuyucu'da seçilen ses, yoksa arayüz dili; başka diller İngilizce sesle okunur). Hız, perde ve
ses düzeyi de aynı ayarlardan gelir. `sys.stopSpeaking()` konuşmayı durdurur ve sıradakileri siler (Ekran Okuyucu'nun
cümlesini de). C: `sys_speak(text, lang)` (`lang` `NULL` olabilir), `sys_stopSpeaking()`; Java: `Sys.speak(text[, lang])`,
`Sys.stopSpeaking()`.

`audio.tone(freq, seconds[, volume[, wave]])` sentezlenmiş nota; wave `"sine"`,`"square"`,`"saw"`,`"triangle"`,
`"noise"` → kanal · `audio.play(nameOrPath[, volume[, loops]])` sistem sesleri `"click"`,`"pop"`,`"notify"`,
`"alarm"`,`"trash"`,`"shutter"`,`"error"`,`"key"`,`"volume"`,`"startup"` ya da bir `.wav/.ogg/.mp3` dosyası
(`loops = -1` tekrarlar) → kanal · `audio.stop(channel)` · `audio.music(path)` bir şarkıyı akışla çalar ·
`audio.musicPause(true|false)` · `audio.musicStop()`.

`timer.after(seconds, fn)` → id · `timer.every(seconds, fn)` → id · `timer.cancel(id)`.

`TR(key, ...)` → `lang/<kod>.json` dosyanızdan çevrilmiş metin (önce İngilizceye, sonra `TR("common.ok")` gibi sistem
metinlerine, sonra anahtarın kendisine düşer). `{0}`, `{1}` ek argument'larla değiştirilir: `TR("score", 42)`.

## 8a. Bağlantılar, paylaşım, zamanlanmış bildirimler, izinler (SDK 1.4)

**Bağlantılar.** `nxv://` adresleri uygulamaları ve sistem yerlerini açar. `sys.open(url)` bunları izler (`"launch"`
gerekir):

| Bağlantı | Açtığı |
|---|---|
| `nxv://app/<id>?arg=<metin>` | uygulamayı (çalışıyorsa öne getirilir) `app.load(arg)` / `app.open(arg)` içinde `<metin>` ile; kurulu olmayan bir uygulama için App Market sayfasını önerir |
| `nxv://store/<id>` | uygulamanın App Market'teki sayfası |
| `nxv://settings/<pane>` | Sistem Ayarları'nı bir bölmede |

`sys.appUrl(id[, arg])` → `"nxv://app/<id>?arg=<yüzde kodlanmış arg>"`; bir nota, QR koduna ya da paylaşıma
koyulacak bir bağlantı. Bir bağlantıdan gelen metin hiçbir zaman kullanıcının verdiği bir dosya olarak işlenmez
(dosya erişimi sağlamaz).
Yerleşik id'ler: dosya yöneticisi `files`, uygulama ızgarası `launcher`; önceki sürümlerin bunlar için kullandığı
id'ler `sys.launch`, `nxv://` bağlantıları ve kısayollarda çalışmaya devam eder.

**Paylaşım.** `sys.share(textOrPath)` → true · paylaşım sayfasını açar: bir önizleme, **Kopyala** ve app.json
`shareTargets` alanı öğeyi kabul eden her uygulama (dosyalarda ayrıca o türü açan yerleşik uygulamalar). `":/"`
içeren bir metin (`"sdmc:/..."`, `"data:/notes.txt"`, `"bundle:/a.png"`) dosya olarak paylaşılır (uygulamanın onu
okumaya izni olmalıdır; yoksa nil, `"permission denied: files"` / `"file not found"`), geri kalan her şey metin
olarak. Alan uygulama metni ya da yolu `arg` olarak alır (bölüm 1'deki `shareTargets`'a bakın).

**Zamanlanmış bildirimler** (`"notifications"` gerekir). SD kartta saklanır ve zamanı geldiğinde sistem tarafından
gönderilir; uygulama kapalıyken ve yeniden başlatmadan sonra da. Birine dokunmak uygulamayı `arg` ile başlatır.
`sys.schedule(epoch, title[, body[, arg]])` → id ya da nil + hata (`"time is in the past"`, 400 günden ileri,
uygulama başına 64'ten fazla bekleyen) · `sys.unschedule(id)` → bekliyorsa true · `sys.scheduled()` → zamana göre
sıralı `{ {id, at, title, body, arg}, ... }`. Örnek: `sys.schedule(sys.epoch() + 25 * 60, TR("break"), TR("time_for_a_break"))`.

**runtime'da izinler.** `sys.hasPermission(name)` → denetlediği çağrı şu anda çalışacaksa true ·
`sys.requestPermission(name[, fn(granted)])` uygulamanın bildirdiği ama kullanıcının reddettiği bir izni kullanıcıya
yeniden sorar; çalışırken izin soran tek çağrı budur (izin ve oturum başına en fazla bir kez; bildirim yoksa ya da bu oturumda zaten yanıtlandıysa
`fn(false)` hemen çalışır).

**Bellek.** `sys.memory()` → bu pencerenin script heap'inin kullanılan bayt sayısı, sınırı (64 MB).

**Arama.** Uygulama çalışırken aramalara yanıt vermek için `app.search(query)` tanımlayın (bölüm 2):
`{title, subtitle, icon, arg}` tablolarından oluşan bir liste döndürün (ya da düz metinler: title = arg). Hızlı tutun;
uygulama başına en fazla 5 öğe gösterilir.

## 8b. 3B — `g3d`

Küçük bir gerçek zamanlı 3B işleyici. GPU'da çalışır: gerçek bir depth buffer, piksel başına aydınlatma, sis ve
Texture'lar; 60 fps'de kare başına 30–60 bin üçgen. Mesh'ler GPU'ya bir kez yüklenir ve orada kalır; bu yüzden onları
`app.load` içinde oluşturun ve her karede yeniden kullanın. GPU yolu kullanılamıyorsa (ya da `g3d.gpu` sistem ayarı
`false` ise) aynı çağrılar eski CPU işleyicisine düşer: derinliğe göre sıralanmış renkli üçgenler, texture yok, kare
başına birkaç bin üçgen. `g3d.gpu()` hangisinin etkin olduğunu söyler. Sağ el koordinatları: x sağa, y yukarı, z
izleyiciye doğru; açılar radyan.

```lua
local cube, ball
Function app.load()
  cube = g3d.mesh("cube", 1)          -- ayrıca: "box",w,h,d  "sphere",r,seg,rings  "plane",w,d,div
  cube:setColor(theme.accent)         --         "cylinder",r,h,seg  "cone",r,h,seg  "torus",R,r,seg,sides
  ball = g3d.mesh("sphere", 0.5, 32, 20)
end
Function app.draw(w, h)
  gfx.clear("#101418")
  local t = sys.time()
  g3d.begin(0, 0, w, h, 60)                       -- görüntü alanı x,y,w,h [, fovDeg [, near [, far]]]
  g3d.camera(math.sin(t) * 4, 2, math.cos(t) * 4, 0, 0, 0)   -- göz xyz, hedef xyz [, yukarı xyz]
  g3d.light(0.5, 1, 0.3, 0.35)                    -- ışığa doğru yön [, ortam 0..1 [, renk]]
  g3d.fog("#101418", 6, 20)                       -- isteğe bağlı: renk, başlangıç, bitiş uzaklığı
  g3d.draw(cube, 0, 0, 0, t, t * 0.7, 0)          -- mesh, x,y,z [, rx,ry,rz [, sx[,sy,sz] [, renk tonu [, "wire unlit nocull glow"]]]]
  g3d.draw(ball, 1.6, 0, 0, 0, 0, 0, 1, 1, 1, theme.orange)
  g3d.line(0, -1, 0, 0, 2, 0, "#FFFFFF", 2)       -- 3B çizgi
  g3d.point(0, 2.2, 0, 6, theme.yellow)           -- 3B nokta (piksel cinsinden boyut)
  local tris = g3d.finish()                       -- her şeyi sıralar ve çizer; üçgen sayısını döndürür
  local sx, sy = g3d.project(0, 2.2, 0)           -- dünya -> ekran (kameranın arkasındaysa nil), finish'ten önce çağırın
end
```

| Function | Açıklama |
|---|---|
| `g3d.mesh(kind, ...)` | temel şekil mesh'i (yukarıya bakın); tüm temel şekiller texture koordinatlarıyla gelir |
| `g3d.load(path[, size])` → mesh ya da nil,err | bir `.obj` (v/vn/vt/f, isteğe bağlı köşe renkleri `v x y z r g b`) ya da `.stl` (ikili/ASCII) dosyası yükler; ortalanır ve `size` boyutuna ölçeklenir (varsayılan 2). `.obj` bir malzeme kütüphanesi (`mtllib`) adlandırıyorsa ve malzemesinin bir dağınık haritası (`map_Kd`) varsa o görsel mesh'in texture'ı olur |
| `g3d.custom({x,y,z,...}, {i1,i2,i3,...}[, {köşe başına renkler}[, flat[, {u1,v1,u2,v2,...}]]])` | kendi üçgenleriniz (1 tabanlı, dışarıdan bakıldığında saat yönünün tersine), isteğe bağlı olarak köşe başına texture koordinatlarıyla |
| `mesh:setColor(c)`, `mesh:flat(true)`, `mesh:triangles()` | |
| `mesh:setTexture(path)` → var mı | Mesh'in texture koordinatlarıyla eşlenen görsel (png/jpg/webp/bmp); `nil` kaldırır. Yollar `fs` yolları gibi çözülür (bundle'ınızdaki bir dosya için `"bundle:/wood.png"`). `mesh:texture()` geçerli yolu döndürür |
| `g3d.gpu()` → bool | 3B GPU'da çiziliyorsa `true` |
| `g3d.begin`, `g3d.camera`, `g3d.light`, `g3d.fog`, `g3d.draw`, `g3d.line`, `g3d.point`, `g3d.project`, `g3d.finish` | yukarıda gösterildiği gibi; çizim çağrıları `begin` ile `finish` arasında toplanır |

Texture'lar: `u, v` görsel boyunca 0'dan 1'e gider, `(0, 0)` sol üst köşesidir ve 0..1 dışındaki değerler görseli
tekrarlar. Texture'lı bir mesh `setColor` rengi yerine görseli gösterir; köşe renkleri ve çizim tonu yine onu çarpar,
aydınlatma ve sis her zamanki gibi uygulanır. Alfa değeri %50'nin altındaki texture pikselleri kesilir (yapraklar,
çitler); yarı saydam yüzeyler için alfalı bir ton ya da renkler kullanın. Texture'lar GPU yolunu gerektirir; CPU yedeği
bunun yerine mesh rengini çizer.

Notlar: yarı saydam mesh'ler (alfası 255'in altında ton, mesh ya da köşe renkleri) opak olanlardan sonra, mesh
başına arkadan öne sıralanarak çizilir. `far` ötesindeki geometri kırpılır; bu yüzden sahnenizi kapsayan bir `far`
verin. `"wire"` her üçgen kenarını 1 piksellik bir çizgi olarak çizer.

Parıltı: `"glow"` bayrağı mesh'in rengini arkasındakini örtmek yerine ona ekler (toplamalı karıştırma); böylece üst
üste binen kısımlar daha parlak olur: yıldızlar, kıvılcımlar, ışık izleri, lamba haleleri. Parıltılı mesh'ler her
şeyden sonra çizilir; önlerindeki katı geometri tarafından gizlenirler ama kendileri hiçbir şeyi gizlemezler ve sis
onları soldurur. Soluk ışık için koyu renkler kullanın ve `"unlit nocull"` ile birleştirin; kenarları siyaha doğru
solan bir texture yumuşak yuvarlak sprite'lar verir. CPU yedeği parıltılı mesh'leri normal mesh olarak çizer.

Yerel (C++) uygulamalar ayrıca bir mesh'in dönüştürülmüş kopyasını başka bir mesh'le birleştiren
`g3d::append(dst, src, matrix, color)` (ucuz örnekleme: yüzlerce nesne, tek çizim), `DrawOpts::additive` (`"glow"`
bayrağı) ve `g3d::lastTriangles()` yanında `g3d::lastDrawCalls()` alır.

Hareket kontrolleri: `input.motion()` → Joy-Con / Pro Controller / el modu jiroskopundan `ax, ay, az` (G cinsinden
ivme), `gx, gy, gz` (rad/s cinsinden açısal hız), `pitch, roll, yaw` (radyan cinsinden birikmiş dönüş).

## 8c. 2D oyun motoru (nexvyn.game)

`nexvyn.game`, `gfx`, `input`, `audio` ve `store` üzerinde Lua ile yazılmış küçük bir 2D motordur. Sistemle birlikte
`romfs:/System/Lua/nexvyn/` içinde gelir; bu yüzden her uygulama `require("nexvyn.game")` yapabilir (§2: `require`
önce bundle'a, sonra sistem kütüphanesine bakar). Türkçe öğretici: `docs/GAME_ENGINE.tr.md`. Örnekler:
`romfs/Applications/` içinde `pixelrun.nxvapp` (platform oyunu) ve `spacearena.nxvapp` (arena nişancı oyunu).

### İlk oyun (30 satır)

```lua
local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui

local Play = {controls = true}               -- controls: bir dokunuştan sonra ekranda çubuk/düğmeler
Function Play:enter()
  self.score = 0
  self.world = game.world{}
  self.hero = self.world:add(game.sprite{x = 240, y = 135, r = 10, body = true, damping = 4})
  function self.hero:render() G.circle(self.x, self.y, 10, "#FFCC00") end
  for i = 1, 8 do
    local c = self.world:add(game.sprite{x = math.random(20, 460), y = math.random(30, 250), r = 5}, "coins")
    function c:render() G.circle(self.x, self.y, 5, "#4CD964") end
  end
  self.world:collide(self.hero, "coins", function(h, c)
    c.dead = true
    self.score = self.score + 1
    game.audio.play("coin")
  end)
end
Function Play:update(dt)
  local mx, my = I.vector()                  -- çubuk, d-pad, oklar/WASD ya da dokunmatik çubuk
  self.hero.ax, self.hero.ay = mx * 900, my * 900
  self.world:update(dt)
end
Function Play:draw() self.world:draw() end
Function Play:ui() U.text(TR("score", self.score), 8, 6, 14) end
Function Play:restart() self:enter() end      -- duraklatma menüsüne "Yeniden başlat" ekler

return game.run{width = 480, height = 270, scene = Play, background = "#1B2A41"}
```

Oyunlar app.json içinde `"gamepad": true` ve `"resizable": true` ayarlamalıdır (boyutlandırılabilir oyunlar tam
ekran açılır).

### Motor döngüsü: `game.run(config)` uygulama tablosunu döndürür

`main.lua`, `return game.run{...}` ile biter. Alanlar: `width`, `height` (sanal ekranın tasarım boyutu), `scale`
(`"expand"` (varsayılan): tasarım boyutu her zaman sığar ve uzun kenar büyür, şerit yok; `"fit"`: şeritli sabit boyut;
`"pixel"`: fit gibi ama tam sayı ölçekle; `"none"`: 1 birim = 1 piksel), `scene`, `params`, `title` (duraklatma menüsü
"Ana menü" sunar), `background`, `border` (şerit rengi), `step` (sabit güncelleme adımı, varsayılan 1/60), `gamepad`
(app.json ile eşleştirin, varsayılan true), `debug`, `controls` (oyuncunun duraklatma menüsünden yeniden atayabileceği
eylemler: adlar ya da `{action, label}`), `load(arg)`, `update(realDt)`, `menu()`, `onmenu(id)`, `close()`.

Güncellemeler sabit adımlarla çalışır; çizim kare başına bir kez yapılır. Duraklatma menüsü **+**, **Esc**, **P**,
dokunmatik duraklatma düğmesiyle ya da pencere odakta değil gibi göründüğünde açılır (SDK'da odak sorgusu yoktur:
uygulamaya ulaşmayan bir kumanda basışı ya da çizilmeyi bırakan bir pencere odak dışı sayılır). Canlı değerler:
`game.width`, `game.height` (sanal boyut), `game.scale`, `game.time`, `game.realTime`, `game.dt`, `game.paused`,
`game.focused`, `game.debug` (F3). `game.toVirtual(px, py)` pencere piksellerini dönüştürür. `game.pause()`,
`game.resume()`. Yardımcılar: `game.class(parent)`, `game.clamp`, `game.lerp`, `game.approach`, `game.sign`,
`game.dist`, `game.angle`, `game.rand(a, b)`, `game.choose(t)`, `game.smooth(f, dt)`, `game.rgba(color)`,
`game.chance(percent)`, `game.randInt(a, b)`, `game.weighted({{value, weight}, ...})`,
`game.flash(color[, sec[, alpha]])` (solarak kaybolan tam ekran renk), `game.str(key)` (Türkçe ve İngilizce motor
metinleri; bir uygulama bunları lang dosyalarındaki `game.<anahtar>` girdileriyle geçersiz kılar: `paused`, `resume`,
`restart`, `sound`, `on`, `off`, `touch`, `auto`, `menu`, `quit`, `controls`, `press_key`, `reset_controls`,
`controls_reset`, `back`).

### Sahneler

| Çağrı / alan | |
|---|---|
| `game.switch(scene[, params[, {fade = 0.3, color}]])` | stack'i değiştirir (kararma, giriş, açılma) |
| `game.push(scene[, params[, opts]])`, `game.pop([result])` | üst katmanlar; `pop`, `result`'ı `resume`'a iletir |
| `game.current()` | en üstteki sahne |
| `opts.transition` | `"fade"` (varsayılan), `"slide"` (`opts.dir = "left"`, `"right"`, `"up"`, `"down"`), `"wipe"`, `"circle"` (iris), `"blinds"`, `"pixels"`; `opts.fade` her yarının süresidir; `game.scene.defaultTransition` varsayılanı değiştirir |
| Method'lar | `enter(params)`, `leave()`, `pause()`, `resume(result)`, `update(dt)`, `draw()`, `ui()` (HUD, draw'dan sonra), `event(e)` (ham SDK event'i artı sanal birimlerde `e.vx, e.vy`), `restart()` |
| alanlar | `transparent` (alttaki sahneleri çiz), `updateBelow`, `controls` (dokunmatik kontroller), `pausable = false` (başlık ekranları), `background`; motor `scene.tweens` ekler |

### Çizim: `game.gfx`

Geçerli dönüşüm (sanal ekran, sonra kamera) üzerinden oyun birimlerinde `gfx` çağrıları: `color`,
`rect(x, y, w, h[, r[, c]])`, `rectLine`, `circle`, `circleLine`, `line`, `gradient`, `poly(pts[, c])`,
`lines(pts[, t[, closed]])`, `polyT(pts, x, y, angle, sx, sy[, c])` ve `linesT(...)` (tablo oluşturmadan döndürülen,
ölçeklenen ve taşınan yerel bir şekil), `text(s, x, y[, size[, font[, align, width]]])`, `textWidth`, `icon`,
`image(img, x, y[, w, h[, tint]])`, `region(img, sx, sy, sw, sh, x, y, w, h[, deg])`, `alpha(a)`/`unalpha()`,
`clip`/`unclip`, `push(dx, dy[, s])`/`pop()`, `transform()`, `toScreen`, `fromScreen`, `visible(x, y, w, h)`.

### Sprite'lar ve animasyon

| Çağrı | |
|---|---|
| `game.sheet(path, frameW, frameH[, {margin, spacing, count, flipped, scale}])` | sprite sheet; `flipped` = `flipX` için görselin aynalanmış kopyası; `scale` = görsel pikseli başına dünya birimi (piksel sanatını 4x saklayın ve 0.25 kullanın) |
| `game.animations{name = {frames = "1-4,6" or {1, 2}, fps = 10, loop = true}}` | |
| `game.sprite{...}`, `game.Sprite` (sınıf) | `x, y` (köken = hitbox merkezi), `ox, oy` (0..1, varsayılan 0.5), `rotation`, `sx, sy`, `flipX`, `alpha`, `tint`, `z`, `visible`, `dx, dy` (çizim kayması), `sheet` ya da `image`, `frame`, `anims`; şekil sprite'ları: `shape = "rect"/"circle"`, `color` |
| `sprite:play(name[, restart])`, `sprite.onAnimEnd`, `sprite.animSpeed` | |
| `sprite:render()`'ı geçersiz kılın | `game.gfx` ile özel çizim (alfa zaten uygulanmış) |

Alt sınıf: `local Enemy = game.class(game.Sprite)`, `function Enemy:init(o) game.Sprite.init(self, o) ... end`,
`Enemy{x = 10, y = 20}`. SDK sınırları: görsel bölgeleri aynalanamaz ya da renklendirilemez; bu yüzden `flipX` için
`flipped` görsel gerekir ve `tint` yalnızca döndürülmeden çizilen tek görsellerde çalışır.

### Dünya, gruplar, fizik, çarpışma

| Çağrı | |
|---|---|
| `game.world{gravity = 900 or {x, y}, map = tilemap, camera = cam, cell = 64}` | |
| `world:add(e, "group", ...)`, `world:remove(e)` ya da `e.dead = true` | varlık kancaları `e:update(dt)`, `e:draw()`, `e:added(w)`, `e:removed()`; `e.active = false` onu dondurur |
| `world:group(name)` | `group.n`, `group[i]`, `:add`, `:remove`, `:has`, `:each(fn)`, `:count()`, `:nearest(x, y[, max])` |
| `world:collide(a, b, fn[, separate])` | a, b = varlık, grup ya da grup adı; örtüşmede `fn(ea, eb)`; gruplar spatial hash kullanır; `separate` kutuları birbirinden iter |
| `world:trigger{x, y, w, h or entity = e, filter, onEnter, onExit, onStay}` | bölgeler |
| `world:query(x, y, w, h[, group])` | örtüşen varlıklar (`.n` ile yeniden kullanılan liste) |
| `world:addEmitter(em)`, `world:update(dt)`, `world:draw()`, `world:clear()` | draw = harita, z'ye göre varlıklar (kamera dışındakiler atlanır), emitter'lar, `above` olarak işaretlenmiş harita katmanları, hata ayıklama çarpıştırıcıları |

Gövdeler (`body = true`): `vx, vy, ax, ay`, `gravity` (ölçek), `dragX, dragY`, `damping`, `maxVx, maxVy`, `bounce`,
`collideMap`, `dropThrough`, `immovable`, `static`; hitbox `w, h` ya da `r`. Her adımdan sonra: `onFloor`,
`onCeiling`, `onWall` (-1/0/1), `hitX`, `hitY`. `game.physics`: `aabb`, `circles`, `circleRect`, `pointIn`,
`overlap(a, b)`, `separate(a, b)`, `moveAndCollide(e, dx, dy, map)`, `integrate`, `:insert(e)`, `:clear()`,
`:query(x, y, w, h, out)` ile `hash(cell)`.

### Tilemap'ler: `game.tilemap`

| Çağrı | |
|---|---|
| `game.tilemap{tileSize, width, height, tileset = sheet, tiles = {[id] = {solid, oneway, color, draw, ...}}, layers = {{name, data, collide, above, parallax, alpha}}, objects, edges}` | id'ler 1 tabanlı tileset kareleridir, 0 = boş |
| `game.tilemap.fromStrings(rows, legend[, {tileSize, tileset, tiles, edges}])` | `legend["#"] = 1`, `legend.o = {object = "coin"[, tile = id]}` |
| `game.tilemap.fromJSON(textOrTableOrPath[, baseDir])` | basit JSON biçimi (bkz. `nexvyn/game/tilemap.lua`) |
| `game.tilemap.fromTiled(pathOrTable[, {baseDir, tiles, edges}])` | Tiled JSON dışa aktarımı: ortogonal, CSV katmanları, ilk tileset, nesne katmanları, `solid`, `oneway`, `collide`, `above` özellikleri |
| `map:path(x0, y0, x1, y1[, {diagonal, maxNodes, cost, avoid}])` | (x0, y0) tile'ından (x1, y1) tile'ına A*: `{x1, y1, ...}` dünya noktaları (tile merkezleri) ya da nil; katı tile'lar engeller, tek yönlüler engellemez; `avoid(tx, ty)` daha fazla döşemeyi engeller, `cost(tx, ty)` bir maliyet ekler, `maxNodes` (varsayılan 6000) aramayı sınırlar |
| `game.path.find(w, h, passable, sx, sy, gx, gy[, opts])` | herhangi bir ızgarada A*: `passable(tx, ty)` → bool; `{tx1, ty1, ...}` (0 tabanlı tile'lar, başlangıç hariç) ya da nil döndürür |
| `map:get/set(tx, ty[, layer])`, `map:solid(tx, ty)` (0 boş, 1 katı, 2 tek yönlü), `map:toTile`, `map:toWorld`, `map:tileAt(x, y)`, `map:findTile(x, y, w, h, flag)`, `map:objectsOf(type)`, `map:draw(cam[, "above"])`, `map:rebuild()` | `map.pixelWidth`, `map.pixelHeight`, `map.objects` |

Nexvyn OS Studio'daki görsel düzenleyiciler: sprite düzenleyicisi için bir `.png` açın (kareler, palet, soğan kabuğu,
önizleme; kare boyutu `<ad>.sprite.json` dosyasına gider ve varsa `<ad>_flip.png` kaydederken yeniden yazılır),
tilemap düzenleyicisi için bir `.map.json` (`fromJSON` biçimini yazar: tileset, `tiles` bayrakları,
katmanlar, nesneler) ve sahne düzenleyicisi için bir `.scene.json`. Bir sahneyi
`game.loadScene(path[, {world, types = {type = Class}, baseDir, groups}])` ile yükleyin → `width`, `height`, `grid`,
`background`, `entities`, `byName`, `level:ofType(type)` içeren `level`; her girdi `types[type](o)` ya da
`game.sprite(o)` olur (`x, y` merkez, `rotation` derece olarak saklanır, `props` alan olarak kopyalanır) ve türünün
adını taşıyan bir grupta `world`'e eklenir. Biçim: `romfs/System/Lua/nexvyn/game/loader.lua`.

### Kamera: `game.camera{x, y, zoom, lerp, deadzone = {w, h}, offsetX, offsetY, bounds, round}`

`cam:follow(target[, lerp[, dzW, dzH]])`, `cam:setBounds(x, y, w, h)`, `cam:clearBounds()`, `cam:shake(amount, sec)`,
`cam:lookAt(x, y)`, `cam:snap()`, `cam:update(dt)`, `cam:attach([parallax])` / `cam:detach()`, `cam:view()` (x, y, w, h),
`cam:toWorld(vx, vy)`, `cam:toView(wx, wy)`, `cam:screenToWorld(px, py)`, `cam:zoomTo(z, sec[, ease])`,
`cam:panTo(x, y, sec[, ease])` (kaydırma sırasında hedef izlenmez), `cam:animating()`, `cam:kick(dx, dy)` (geri
yaylanan bir itiş: geri tepme, yere inişler), `cam:visible(x, y, w, h[, margin])` (özel çizim için görünmeyeni atlama).

### Işıklar: `game.lights{ambient, color, cell, levels}`

Yumuşak ışık delikleri olan bir karanlık katmanı. `ambient` (0..1) ışığın ulaşmadığı yerdeki karanlık, `color` onun
rengi, `cell` sanal birimlerde hücre boyutu (varsayılan 8), `levels` karanlık basamakları (varsayılan 12).
`lights:add{x, y, radius, intensity, flicker, on}` → ışık (alanlarını istediğiniz zaman değiştirin),
`lights:remove(l)`, `lights:clear()`, `lights:setColor(c)`, `lights:draw([cam])` (dünyadan sonra, HUD'dan önce; bir
kamera verildiğinde konumlar dünya birimidir). Bir satırdaki eşit komşu hücreler tek dikdörtgen olarak çizilir.

### Girdi eylemleri: `game.input`

`bind(name, {pad = {...}, key = {...}, axis = {"lx-", "ly+", "rx+", ...}, touch = {"stick:up", "button:id"}}[, add])`,
`unbind`, `down(name)`, `pressed(name)`, `released(name)` (güncelleme adımı başına), `anyPressed()`, `axis(neg, pos)`,
`vector()` (hareket vektörü, y aşağı), `aim()` (sağ çubuk), `sticks()`, `reset()`, `pointer` (sanal birimlerde `x, y`,
`down`, `pressed`, `released`, `framePressed`, `frameReleased`, `downX, downY`, `touch`),
`touchControls{stick = true, pause = true, buttons = {{id, icon, label, action}}}`, `setTouchMode("auto"|"on"|"off")`,
`touchVisible()`. Yeniden atama: `setBinding(name, "key"|"pad", value)` (ilk tuşu / kumanda düğmesini değiştirir ve
eylemin sonraki bir `bind`'ından sonra da korunur), `binding(name, kind)`, `bindingLabel(name)` (`"Space / A"`),
`listen(fn[, sec])` (sonraki tuş ya da kumanda basışı oyuna ulaşmak yerine `fn(kind, value)` çağırır; Escape ya da
zaman aşımı `fn(nil)` çağırır), `listening()`, `cancelListen()`, `resetBindings()`, `saveBindings(slot)`,
`loadBindings(slot)` (motor bunları ayarlarıyla birlikte yükler ve kaydeder). Varsayılan eylemler: `left`, `right`,
`up`, `down`, `confirm`, `back`, `pause`. Dokunmatik kontroller ekrana dokunulduktan sonra görünür ve bir düğme ya da
tuş kullanıldığında gizlenir. SDK tek bir işaretçi bildirir; bu yüzden çubuk ve bir düğme birlikte basılı tutulamaz:
önemli eylemleri çubuk yönlerine de atayın (zıplama için `"stick:up"`).

### Ara geçişler ve timer'lar: `game.tween`

`game.tween.to(target, sec, {field = value}[, ease or {ease, delay, onComplete, onUpdate}])`; `:ease`, `:delay`,
`:oncomplete`, `:onupdate`, `:after(target, sec, props[, ease])` (zincir), `:call(fn)`, `:cancel()` içeren bir tween
döndürür. `game.tween.after(sec, fn)`, `game.tween.every(sec, fn[, count])`. `game.tween.ease` içindeki easing'ler:
`linear`, `inQuad`, `outQuad`, `inOutQuad`, `inCubic`, `outCubic`, `inOutCubic`, `inQuart`, `outQuart`, `inSine`,
`outSine`, `inOutSine`, `inExpo`, `outExpo`, `inOutExpo`, `inBack`, `outBack`, `inOutBack`, `inElastic`,
`outElastic`, `inOutElastic`, `inBounce`, `outBounce`, `inOutBounce`, `inOutQuart`, `inQuint`, `outQuint`,
`inOutQuint`, `inCirc`, `outCirc`, `inOutCirc`, `smoothstep`; `game.tween.steps(n)` merdiven biçimli bir
easing'dir. `tween:loop([count[, yoyo]])` tekrarlar (`count` kez daha; nil ya da 0 = sonsuza dek; `yoyo` her ikinci
geçişi geriye oynatır). `game.tween.from(target, sec, props[, ease])` `props`'a atlar ve geçerli değerlere geri
geçiş yapar. Tween'ler en üstteki sahneye aittir ve sahne duraklatıldığında durur.

### Parçacıklar: `game.emitter{...}`

Seçenekler: `x, y, max, rate, life = {min, max}, speed = {min, max}, angle, spread, gravity, gravityX, damping,
size = {start, end}, sizeVar, colors = {...}` (ömür boyunca ara değerlenir, `#RRGGBBAA`),
`shape = "circle"|"square"|"line"`, `lineScale`, `offset`. Method'lar: `emit(n[, x, y[, angle]])`, `start()`, `stop()`,
`moveTo(x, y)`, `setColors(list)`, `update(dt)`, `draw()`, `clear()`; `em.count`. `area = {w, h}` x, y merkezli bir
kutunun herhangi bir yerinde üretir. Hazır ayarlar: `game.particles.preset(name[, overrides])` → emitter; `name`
şunlardan biri: `"explosion"`, `"smoke"`, `"sparkle"`, `"rain"`, `"snow"`, `"fire"`, `"confetti"`, `"dust"`,
`"blood"`, `"magic"`; `game.particles.burst(world, name, x, y[, n[, angle]])` her hazır ayar ve dünya için ortak tek
bir emitter üzerinden üretir.

### Ses, arayüz, kayıt, hata ayıklama

- `game.audio`: `define(name, {notes = "E6:0.05 B6:0.12" or {{freq, sec}}, wave, volume})`, `play(nameOrFile[, vol])`
  (yerleşik efektler `jump`, `coin`, `hit`, `explode`, `shoot`, `power`, `select`, `confirm`, `lose`, `win`, sistem
  sesleri ya da dosyalar), `tone`, `music(path)`, `stopMusic`, `pauseMusic`, `song{notes, bass, bpm, div, wave, volume}`
  (döngüde çalan synth ezgisi), `stopSong`, `setMuted(b)`, `muted`, `freq("A4")`.
- `game.ui`: `text(s, x, y[, size[, color[, align, width[, font[, shadow]]]]])`, `panel`, `bar(x, y, w, h, value[, c])`,
  `pixelText(s, x, y[, px[, color[, align, width]]])` (3x5 piksel yazı tipi), `pixelWidth`,
  `score(n, x, y[, px[, color[, digits[, align]]]])`, `button(label, x, y, w, h)` (dokunulduğunda true),
  `:update()` (kumanda, tuşlar ve işaretçi) ve `:draw(cx, y)` ile
  `menu{items = {{label, action, enabled, left, right}}, width, itemHeight, size, title, onBack}`;
  `game.toast(text[, sec])`; `hearts(n, max, x, y[, size[, color[, icon]]])` (kesirler için kısmi simgeler),
  `slider(value, x, y, w, h[, color])` → 0..1, `toggle(on, x, y[, w, h[, color]])` → bool,
  `iconButton(icon, cx, cy[, size[, color]])` → dokunuldu mu, `dialog{title, text, buttons, onClose(index), width, color}`
  (kalıcı sahne; geri = 0 numara), `:update(dt)`, `:draw()`, `.done` ile
  `dialogue{lines = {"text" or {who, text}}, speed, onDone, height, color, blip}` (daktilo kutusu; onay ya da bir
  dokunuş satırı tamamlar, sonra ilerletir).
- `game.save`: `:get(k, default)`, `:set(k, v)`, `:inc(k[, n])`, `:best(k, v[, lower])` (yeni rekorda true),
  `:reset()`, `:exists()`, `:delete()`, `:stamp([summary])`, `:copyTo(slot)` ile `game.save.open(name)`;
  `game.save:get/set` varsayılan yuvayı kullanır. Numaralı yuvalar: `game.save.slot(i)`, `game.save.slots(n)` →
  `{index, used, summary, savedAt, when, save}` listesi. Veriler uygulamanın `store`'unda tutulur.
- Hata ayıklama katmanı: F3 ya da `game.debug = true`: FPS, adımlar, güncelleme ve çizim süresi, varlıklar, gövdeler,
  parçacıklar, çarpıştırıcılar, son 90 kare süresinin grafiği, sanal ve dünya birimlerinde işaretçi ve
  `game.watch(name, value)` girdileri (`game.unwatch(name)`).

## 9. Tasarım ilkeleri

- `theme` renklerini, yuvarlak köşeleri (6–12 px), `ui` bileşenlerini, başlıklar için `"semibold"`/`"bold"`'u ve
  13–15 px gövde metnini kullanın. 16–20 px kenar boşluğu bırakın.
- Her etkileşimli öğeyi en az 28 px yüksekliğinde yapın — konsol parmakla ve çubuk imleciyle kullanılır.
- Oyunlar: `"gamepad": true` ayarlayın, D-pad/çubuk + A/B'yi ve mümkünse dokunmatiği de destekleyin; kontrolleri
  ekranda gösterin.
- Kullanıcı verilerini değişir değişmez `store` ya da `fs` ile kaydedin.
- `app.draw`'ı hızlı tutun: her karede büyük tablolar oluşturmaktan kaçının; görselleri bir kez yükleyin.

## 10. Eksiksiz örnek

`Counter.nxvapp/app.json`
```json
{"id":"com.example.counter","name":{"en":"Counter","tr":"Sayaç"},"version":"1.0","author":"You",
 "category":"utilities","window":{"width":360,"height":260,"resizable":false}}
```
`Counter.nxvapp/lang/tr.json`: `{"title":"Sayaç","reset":"Sıfırla","times":"{0} kez tıklandı"}`
`Counter.nxvapp/lang/en.json`: `{"title":"Counter","reset":"Reset","times":"Clicked {0} times"}`
`Counter.nxvapp/main.lua`
```lua
local app = {}
local count = 0

Function app.load()
  count = store.get("count", 0)
end

Function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w)
  gfx.color(theme.accent)
  gfx.text(tostring(count), 0, 70, 64, "semibold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("times", count), 0, 150, 14, "sans", "center", w)
  if ui.button("+1", w/2 - 110, 190, 100, 34, "primary") then
    count = count + 1
    store.set("count", count)
    audio.play("click")
  end
  if ui.button(TR("reset"), w/2 + 10, 190, 100, 34) then
    count = 0
    store.set("count", count)
  end
end

Function app.event(e)
  if e.type == "keydown" and e.key == "space" then count = count + 1; store.set("count", count) end
end

return app
```

## 11. JavaScript

> **Özet:** Uygulamalar Lua yerine JavaScript ile de yazılabilir: `app.json` içinde `"main": "main.js"` yazın.
> API aynıdır (`gfx`, `ui`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `TR`, `g3d`); farklar
> aşağıdaki tablodadır: diziler 0'dan başlar, `nil` yerine `null`, çoklu dönüş değerleri dizi olarak gelir, geri
> çağırma (callback) vermezseniz async function'lar Promise döndürür (`await net.fetchJson(url)`), dosyalar
> arasında `import` kullanılır. Türkçe kısa rehber: `docs/JS_APPS.tr.md`. Örnek: `romfs/Applications/hellojs.nxvapp`.

Bölüm 1–10'daki her şey JavaScript uygulamaları için de geçerlidir; bu bölüm yalnızca farklı olanları listeler.

### JavaScript'i seçmek

`app.json` içinde `"main": "main.js"` yazın (herhangi bir `.js`/`.mjs` dosyası olur; ya da başka bir ad kullanıp
`"runtime": "js"` ekleyin). Bundle yapısı aynıdır: `app.json`, `icon.png`, `lang/*.json`, `.js` dosyalarınız ve
kaynaklarınız.

Motor QuickJS-ng'dir: modern JavaScript (ES2023: `let`/`const`, sınıflar, ok function'ları, destructuring, spread,
template string'ler, `async`/`await`, generator'lar, `Map`/`Set`, typed array'ler, `BigInt`, `RegExp`, `JSON`, `Math`, `Date`).
Her pencere **64 MB** heap sınırıyla kendi motorunu çalıştırır; **3 saniyeden** uzun süren bir callback
durdurulur ve hatalar Lua ile aynı hata ekranını açar (ileti, `file.js:line:column` içeren stack trace, **Yeniden
Yükle**). Tarayıcı ya da Node.js API'si yoktur: `window`, `document`, `fetch`, `XMLHttpRequest`, `localStorage`,
`require`, `process` ya da `Intl` yok — SDK modüllerini kullanın. `Date` çalışır; konsolun yerel saat dilimi için
`sys.date()` kullanın.

### Program yapısı

`main.js` bir **ES modülüdür** (strict mode). Callback'lerinizı genel `app` nesnesine atayın — ya da bunları içeren
bir nesneyi `export default` ile dışa aktarın. Callback'ler ve argument'ları bölüm 2'dekilerdir.

```js
import { formatScore } from "./util.js";   // bundle'ın diğer dosyaları; ayrıca "./data.json" (varsayılan dışa aktarım)

let count = 0;

app.load = (arg) => { count = store.get("count", 0); };
app.update = (dt) => {};
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(formatScore(count), 20, 20, 18, "bold");
};
app.event = (e) => { if (e.type === "keydown" && e.key === "space") count++; };
app.menu = () => [{ title: TR("game"), items: [{ label: TR("new"), id: 1, shortcut: "Ctrl+N" }, "-"] }];
app.onmenu = (id) => {};
app.close = () => true;                    // pencereyi açık tutmak için false döndürün
```

Modüller: `import` yolları içe aktaran dosyaya görelidir ve bundle'ın içinde kalır (`"./x.js"`, `"../lib/y.js"`; yalın
bir `"util"`, bundle kökündeki `util.js` demektir). `import data from "./levels.json"` parse edilmiş JSON'u verir.
Dinamik `import()` da çalışır. `main.js` içinde üst düzey `await` kullanılabilir; `app.load` o bittiğinde çalışır.
Promise işleri (`await`, `.then`) her karede çalışır.

### Lua'dan farklar

| Konu | Lua | JavaScript |
|---|---|---|
| İndeksler | 1 tabanlı | **0 tabanlı**: `ui.segmented` / `ui.dropdown` seçili indeksi, `ui.alert` düğme indeksi, `g3d.custom` köşe indeksleri, varsayılan `ui.contextMenu` id'leri |
| Değer yok | `nil` | `null`: `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` başarısızlıkta `null` döndürür; varsayılan verilmeden olmayan bir anahtar için `store.get(key)` `undefined` döndürür |
| Birden çok sonuç | `local w, h = gfx.size()` | bir dizi: `const [w, h] = gfx.size()`. Aynısı `ui.mouse()` → `[x, y, down, hovering]`, `ui.beginScroll(...)` → `[scrollY, scrollX]`, `sys.battery()` → `[percent, charging]`, `input.stick()` → `[x, y]`, `input.motion()` → `[ax, ay, az, gx, gy, gz, pitch, roll, yaw]`, `g3d.project(...)` → `[sx, sy, depth]` ya da `null` için de geçerli |
| `ui.textfield` | `text, submitted = ui.textfield(...)` | yalnızca yeni metni döndürür: `text = ui.textfield("name", text, x, y, w)`; o alanda Enter'a basıldığı karede `ui.submitted("name")` `true` olur |
| `ui.row` | `clicked, doubleClicked` | bir sayı: `0` bir şey yok, `1` tıklandı, `2` çift tıklandı (`if (ui.row(...))` çalışır) |
| Renkler | `"#hex"`, `{r,g,b[,a]}`, sayılar | `"#hex"`, `[r, g, b, a]`, `{r, g, b, a}` ya da belirtilen yerlerde 3–4 sayı |
| Tablolar | `{1, 2}`, `{key = v}` | diziler `[1, 2]` ve nesneler `{key: v}` (`gfx.poly([x1, y1, x2, y2, ...])`) |
| Mesh'ler | `mesh:setColor(c)` | `mesh.setColor(c)`, `mesh.flat(true)`, `mesh.triangles()`, `mesh.setTexture(path)`, `mesh.texture()` |
| Görseller | `img.width` | `img.width`, `img.height`, `img.path`; `gfx.draw` bir yol metni de kabul eder |
| Yazdırma | `print(...)` | `console.log/info/warn/error(...)`, `print(...)`, `sys.log(...)`: argument'lar boşlukla birleştirilir, nesneler JSON olarak yazılır |
| Zamanlayıcılar | `timer.after/every/cancel` (saniye) | aynısı, artı `setTimeout`/`setInterval`/`clearTimeout`/`clearInterval` (milisaniye) ve `await timer.sleep(seconds)` |
| JSON | `json.encode/decode` | aynısı (`json.decode` geçersiz metin için `null` döndürür); `JSON.parse`/`JSON.stringify` da çalışır |
| Modüller | `require("name")` | `import ... from "./name.js"` |
| Async hatalar | — | kimsenin işlemediği reddedilmiş bir Promise fırlatılmış bir hata gibi bildirilir (hata ekranı) — `await`'i `try`/`catch` içine alın |

### Promise'ler

Callback alan her SDK function'ı, callback'i vermezseniz bir **Promise** döndürür:

| Callback biçimi | Promise biçimi | Çözümlendiği değer |
|---|---|---|
| `net.get(url[, headers], cb)` | `await net.get(url[, headers])` | `res` (hiç reddetmez — `res.ok`'u denetleyin) |
| `net.post(url, body[, contentType][, headers], cb)` | `await net.post(url, body[, contentType][, headers])` | `res` |
| `net.json(url, (data, err) => {})` | `await net.json(url)` ya da `await net.fetchJson(url[, headers])` | parse edilmiş veri; bir `Error` ile **reddeder** (`e.message`: ağ hatası, `"HTTP 404"`, `"invalid JSON: ..."`) |
| `net.download(url, path, (ok, pathOrError) => {}[, progress])` | `await net.download(url, path[, null, progress])` | mutlak yol; başarısızlıkta reddeder |
| — | `await net.fetch(url, {method, headers, body, contentType})` | `res`; nesne olan bir `body` JSON olarak gönderilir |
| `ui.alert(title, msg, buttons, (i) => {})` | `await ui.alert(title, msg, buttons)` | düğme indeksi (0 tabanlı) |
| `ui.prompt(title, msg, initial, (text) => {})` | `await ui.prompt(title, msg, initial)` | metin ya da `null` |
| `ui.openFile(cb, exts[, title])` | `await ui.openFile(exts[, title])` | yol ya da `null` |
| `ui.saveFile(cb, name[, title])` | `await ui.saveFile(name[, title])` | yol ya da `null` |
| `ui.keyboard(initial, cb[, guide])` | `await ui.keyboard(initial, null[, guide])` | metin ya da `null` |
| `ui.contextMenu(items, (id) => {})` | `await ui.contextMenu(items)` | öğe id'si (menü kapatılırsa hiç sonuçlanmaz — callback'i tercih edin) |
| `timer.after(seconds, fn)` | `await timer.sleep(seconds)` | — |

`net.request({url, method, body, contentType, headers}[, cb])`, `net.fetch`'in arkasındaki genel biçimdir. `res`
içinde `ok`, `status`, `body`, `error`, `url`, `headers` ve `contentType` vardır.

```js
let weather = null, error = "";
Async function refresh() {
  try {
    const data = await net.fetchJson("https://api.open-meteo.com/v1/forecast?latitude=41&longitude=29&current=temperature_2m");
    weather = data.current;
  } catch (e) {
    error = e.message;          // çevrimdışı, HTTP hatası ya da geçersiz JSON
  }
}
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  if (ui.button(TR("refresh"), 20, 20, 140, 32, "primary")) refresh();   // arka planda çalışır
  gfx.color(error ? theme.red : theme.text);
  gfx.text(error || (weather ? `${weather.temperature_2m}°` : "…"), 20, 70, 24);
};
```

### JavaScript'te SDK 1.4

`app.search = (q) => [{ title, subtitle, icon, arg }]`, `app.suspend`, `app.resume`, `app.focus = (focused) => {}`,
`app.autosave`, `app.unsaved = () => dirty` Lua'daki gibi çalışır. `sys.memory()` → `[used, limit]`.
`sys.requestPermission(name)` callback olmadan bir `Promise<boolean>` döndürür
(`if (await sys.requestPermission("network")) ...`). İzni olmayan denetimli çağrılar `false` döndürür
`sys.schedule` id'yi döndürür ve geçmişteki, çok ilerideki ya da kotayı aşan bir
zaman için `RangeError` fırlatır. `sys.share`, `sys.unschedule`, `sys.scheduled()` (`{id, at, title, body, arg}`
dizisi), `sys.hasPermission`, `sys.appUrl` ve `sys.open("nxv://...")` bölüm 8a'daki gibidir.

### Yalnızca JavaScript'te olanlar

`fs.readBytes(path)` → `Uint8Array` ya da `null`; `fs.write`, `fs.append` ve `net.post` bir `Uint8Array` ya da
`ArrayBuffer` da kabul eder. `ui.submitted(id)`. `net.fetch`, `net.fetchJson`, `net.request`. `timer.sleep`.

### Eksiksiz örnek

`Counter.nxvapp/app.json`: bölüm 10'daki manifest artı `"main": "main.js"`. Aynı `lang/*.json`.
`Counter.nxvapp/main.js`
```js
let count = 0;

app.load = () => {
  count = store.get("count", 0);
};

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w);
  gfx.color(theme.accent);
  gfx.text(String(count), 0, 70, 64, "semibold", "center", w);
  gfx.color(theme.text2);
  gfx.text(TR("times", count), 0, 150, 14, "sans", "center", w);
  if (ui.button("+1", w / 2 - 110, 190, 100, 34, "primary")) {
    count++;
    store.set("count", count);
    audio.play("click");
  }
  if (ui.button(TR("reset"), w / 2 + 10, 190, 100, 34)) {
    count = 0;
    store.set("count", count);
  }
};

app.event = (e) => {
  if (e.type === "keydown" && e.key === "space") {
    count++;
    store.set("count", count);
  }
};
```

Daha büyük bir örnek (`store` ile yapılacaklar listesi, `gfx` ile çizilen bir saat, `await net.fetchJson`, ES
modülleri) `romfs/Applications/hellojs.nxvapp`'tır. Bir bundle'ı PC'de `node tools/js_check.mjs path/to/App.nxvapp` ile
denetleyin.

## 12. Python

> **Özet:** Uygulamalar Python ile de yazılabilir: `app.json` içinde `"main": "main.py"` ve `"minSdk": "1.3"`
> yazın. API aynıdır (`gfx`, `ui`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `json`, `TR`,
> `g3d`) ve `import` gerekmez. Farklar: indeksler JS gibi 0'dan başlar, boş değer `None`, çoklu dönüş değerleri
> tuple olur, isteğe bağlı argument'lar adıyla verilebilir (`gfx.text("Hi", 10, 10, size=20)`), async
> çağrılar callback (callback) alır. Türkçe kısa rehber: `docs/PY_APPS.tr.md`. Örnek:
> `romfs/Applications/hellopy.nxvapp`.

Bölüm 1–10'daki her şey Python uygulamaları için de geçerlidir; bu bölüm yalnızca farklı olanları listeler. Python
SDK 1.3 gerektirir: `app.json` içine `"minSdk": "1.3"` yazın.

### Python'u seçmek

`app.json` içinde `"main": "main.py"` yazın (herhangi bir `.py` dosyası olur; ya da başka bir ad kullanıp
`"runtime": "python"` ekleyin). Bundle yapısı aynıdır: `app.json`, `icon.png`, `lang/*.json`, `.py` dosyalarınız ve
kaynaklarınız.

Yorumlayıcı pocketpy 2'dir (Python 3 sözdizimi: sınıflar, list comprehension, f-string'ler, lambda'lar,
`*args`/`**kwargs`, dekoratörler, `yield` ile generator'lar, `with`, `match`, walrus operator). Standart modüller: `math`,
`random`, `time`, `json`, `collections`, `functools`, `heapq`, `bisect`, `dataclasses`, `datetime`, `operator`,
`typing`. `os`, `open()`, `socket` ya da `threading` yoktur — SDK modüllerini kullanın. Her pencere **64 MB** bellek
sınırıyla kendi yorumlayıcısını çalıştırır (aynı anda en fazla 16 Python penceresi); **3 saniyeden** uzun süren bir
Callback durdurulur. Hatalar Lua ve JavaScript ile aynı hata ekranını açar: önce istisna satırı, sonra stack trace
(`File "main.py", line 12, in draw`), **Yeniden Yükle** ve **Kopyala** ile.

Yorumlayıcının CPython'dan pratikte önemli farkları (`tools/py_check.py` bunları satır numaralarıyla bildirir):
generator expression yok (`sum(x for x in a)` → `sum([x for x in a])`), örtük metin birleştirme yok (`"a" "b"` →
`"a" + "b"`), `nonlocal` yok, `try ... finally` yok, `async`/`await` yok, liste gösteriminde `*x` yok
(`[*a, 1]` → `list(a) + [1]`) ve bazı yerleşikler anahtar sözcüklü argument almaz (`dict(a=1)` →
`{"a": 1}`).

### Program yapısı

SDK modülleri yerleşiktir (`import` yok). Bölüm 2'deki callback'leri ya modül düzeyindeki bir **`app`** nesnesinin
Method'ları olarak ya da `app` yoksa `main.py` içinde düz function'lar olarak verin:

```python
from util import format_score   # bundle'ın diğer dosyaları: util.py ya da `import pkg` için pkg/__init__.py


class Game:
    def load(self, arg):
        self.count = store.get("count", 0)

    def update(self, dt):          # update'i yalnızca animasyon için tanımlayın: pencere o zaman her karede yeniden çizilir
        pass

    def draw(self, w, h):
        gfx.clear(theme.bg)
        gfx.color(theme.text)
        gfx.text(format_score(self.count), 20, 20, 18, "bold")

    def event(self, e):
        if e.type == "keydown" and e.key == "space":
            self.count += 1

    def menu(self):
        return [{"title": TR("game"), "items": [{"label": TR("new"), "id": 1, "shortcut": "Ctrl+N"}, "-"]}]

    def onmenu(self, item_id):
        pass

    def close(self):
        return True                # pencereyi açık tutmak için False döndürün


app = Game()                       # `app = Game` da çalışır: sınıf örneklenir
```

`import` yalnızca bundle'daki `.py` dosyalarını yükler (derlenmiş `.pyc` dosyaları yüklenmez). `print(...)` ve
`sys.log(...)` uygulamanın günlüğüne yazar. `exit()` / `sys.exit()` uygulamanın penceresini kapatır; `input()` `""`
döndürür.

### Lua'dan farklar

| Konu | Lua | Python |
|---|---|---|
| İndeksler | 1 tabanlı | **0 tabanlı**: `ui.segmented` / `ui.dropdown` seçili indeksi, `ui.alert` düğme indeksi, `g3d.custom` köşe indeksleri, varsayılan `ui.contextMenu` id'leri |
| Değer yok | `nil` | `None`: `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` başarısızlıkta `None` döndürür; olmayan bir anahtar için `store.get(key)` varsayılanı (ya da `None`) döndürür |
| Birden çok sonuç | `local w, h = gfx.size()` | bir tuple: `w, h = gfx.size()`. Aynısı `ui.mouse()` → `(x, y, down, hovering)`, `ui.beginScroll(...)` → `(scroll_y, scroll_x)`, `sys.battery()` → `(percent, charging)`, `input.stick()` → `(x, y)`, `input.motion()` → 9 sayı, `g3d.project(...)` → `(sx, sy, depth)` ya da `None` için de geçerli |
| İsteğe bağlı argument'lar | konumsal | konumsal ya da aşağıdaki adlarla **adıyla**: `gfx.text("Hi", 10, 10, size=20, font="bold")`, `ui.button("OK", x, y, 90, 30, style="primary")`. `None` "varsayılanı kullan" demektir |
| Record'lar | tablolar (`e.type`) | event'ler, `sys.date()`, `ui.hit()`, ağ yanıtları, `fs.list()` girdileri ve `gfx.image()` record'dur: dict gibi de okunabilen öznitelikler (`e.type`, `d.hour`, `res.ok`) (`e["key"]`, `res.get("body")`) |
| `ui.textfield` | `text, submitted = ui.textfield(...)` | yalnızca yeni metni döndürür; o alanda Enter'a basıldığı karede `ui.submitted("name")` `True` olur |
| `ui.row` | `clicked, doubleClicked` | bir tamsayı: `0` bir şey yok, `1` tıklandı, `2` çift tıklandı |
| Renkler | `"#hex"`, `{r,g,b[,a]}`, sayılar | `"#hex"`, bir tuple/liste `(r, g, b[, a])`, bir dict `{"r": .., "g": .., "b": ..}`; `gfx.color(r, g, b[, a])` |
| Tablolar | `{1, 2}`, `{key = v}` | listeler `[1, 2]` ve dict'ler `{"key": v}`; `menu()` dict'lerden oluşan bir liste döndürür, `"-"` bir ayraçtır |
| Mesh'ler | `mesh:setColor(c)` | `mesh.setColor(c)`, `mesh.flat(True)`, `mesh.triangles()`, `mesh.setTexture(path)`, `mesh.texture()` |
| Baytlar | metinler | `fs.readBytes(path)` → `bytes`; `fs.write`, `fs.append` ve `net.post` `str` ya da `bytes` alır |
| `sys` | yalnızca SDK | Python'un `sys`'iyle birleştirilmiştir (`sys.platform`, `sys.argv` de vardır); `import sys` aynı modülü verir |
| JSON | `json.encode/decode` | aynısı (`json.encode(v, True)` girintili yazar, `json.decode` geçersiz metin için `None` döndürür); `json.dumps/loads` da çalışır |
| Modüller | `require("name")` | `import name` / `from name import f` |

Function adları SDK'nınkilerdir (`textWidth`, `beginScroll`, `iconButton`, `sdkVersion`...). Anahtar sözcükler için
kullanılan argument adları: `gfx.rect(x, y, w, h, r, color)`, `gfx.text(s, x, y, size, font, align, w)`,
`gfx.wrap(s, x, y, w, size, font, align, spacing)`, `gfx.draw(img, x, y, w, h, r, tint)`,
`ui.button(label, x, y, w, h, style, icon, enabled)`, `ui.iconButton(icon, x, y, w, h, tint, active, id)`,
`ui.textfield(id, text, x, y, w, h, placeholder, flags)`, `ui.slider(id, value, lo, hi, x, y, w, step)`,
`ui.segmented(id, items, selected, x, y, w, h)`, `ui.label(s, x, y, size, color, font)`,
`g3d.draw(mesh, x, y, z, rx, ry, rz, sx, sy, sz, tint, flags)`, `audio.tone(freq, sec, volume, wave)`,
`store.get(key, default)`. `python tools/py_check.py` her çağrıyı gerçek imzalara göre denetler.

### Promise'ler yerine callback'ler

Async function'lar bir callback alır; callback verilmezse çağrı yine çalışır ve sonucu atılır. Geri
çağırma sonraki bir karede, uygulamanın içinde çalışır (içindeki hatalar hata ekranını açar).

| Çağrı | Callback'in aldığı |
|---|---|
| `net.get(url, callback, headers)` | `res` (`ok`, `status`, `body`, `error`, `url`, `headers`, `contentType`) |
| `net.post(url, body, callback, contentType, headers)` | `res` |
| `net.request({"url", "method", "body", "contentType", "headers"}, callback)` | `res` |
| `net.json(url, callback, headers)` | `(data, error)`: parse edilmiş JSON ve `None` ya da `None` ve bir ileti (`"HTTP 404"`, `"invalid JSON"`, ağ hatası) |
| `net.download(url, path, callback, progress)` | `(ok, path_or_error)`; çalışırken `progress(now, total)` |
| `ui.alert(title, message, buttons, callback)` | düğme indeksi (0 tabanlı) |
| `ui.prompt(title, message, text, callback)` / `ui.keyboard(text, callback, guide)` | metin ya da `None` |
| `ui.openFile(callback, exts, title)` / `ui.saveFile(callback, name, title)` | yol ya da `None` |
| `ui.contextMenu(items, callback)` | öğe id'si |
| `timer.after(sec, fn)` / `timer.every(sec, fn)` | — (`timer.cancel(id)` için bir id döndürür) |

`net.get`, `net.post` ve `net.json` için zorunlu olanlardan sonraki isteğe bağlı argument'lar herhangi bir
sırada gelebilir: function callback'tir, dict başlıklardır, metin içerik türüdür. `network` ve `files` izinleri
Lua ve JavaScript'teki gibi aynen uygulanır (bölüm 1).

```python
class Weather:
    def __init__(self):
        self.temp = None
        self.error = ""

    def refresh(self):
        url = "https://api.open-meteo.com/v1/forecast?latitude=41&longitude=29&current=temperature_2m"
        net.json(url, self.on_data)          # arka planda çalışır

    def on_data(self, data, error):
        if error is not None:
            self.error = error               # çevrimdışı, HTTP hatası ya da geçersiz JSON
        else:
            self.temp = data["current"]["temperature_2m"]

    def draw(self, w, h):
        gfx.clear(theme.bg)
        if ui.button(TR("refresh"), 20, 20, 140, 32, "primary"):
            self.refresh()
        gfx.color(theme.red if self.error else theme.text)
        gfx.text(self.error or (f"{self.temp}°" if self.temp is not None else "..."), 20, 70, 24)


app = Weather()
```

### Python'da SDK 1.4

`search(query)`, `suspend()`, `resume()`, `focus(focused)`, `autosave()` ve `unsaved()`'ı diğer callback'ler gibi
tanımlayın (modül function'ları ya da `app` method'ları). `sys.memory()` → `(used, limit)`.
`sys.requestPermission(name, callback=None)` `callback(granted)` çağırır. İzni olmayan denetimli çağrılar `False`
döndürür; `sys.schedule(epoch, title, body=None, arg=None)` id'yi döndürür ve
geçmişteki, çok ilerideki ya da kotayı aşan bir zaman için `ValueError` fırlatır; `sys.scheduled()` bir kayıt
listesidir (`it.id`, `it.at`, `it.title`, `it.body`, `it.arg`). `sys.share(item)`, `sys.unschedule(id)`,
`sys.hasPermission(name)`, `sys.appUrl(id, arg=None)` ve `sys.open("nxv://...")` bölüm 8a'daki gibidir.

### Sistem kütüphanesi (SDK 1.5)

`import` önce bundle'a, sonra `romfs:/System/Python` sistem kütüphanesine bakar; bu kütüphane pocketpy'de olmayan
modüllerin CPython API'leriyle saf Python sürümlerini ekler: `itertools` (`count`, `cycle`, `chain`, `islice`,
`accumulate`, `groupby`, `product`, `permutations`, `combinations`, `zip_longest`, `pairwise`...), `string` (sabitler,
`capwords`, `Template`), `textwrap` (`wrap`, `fill`, `shorten`, `dedent`, `indent`), `copy` (`copy`, `deepcopy`),
`statistics` (`mean`, `median`, `mode`, `stdev`, `variance`, `quantiles`...), `base64` (standart ve URL güvenli) ve
`colorsys` (RGB ↔ HSV/HLS/YIQ, artı gfx renkleri için `to_hex` / `from_hex`). Bundle'daki aynı adlı bir modül önceliklidir.
`itertools.chain` iterabledir (`for`, `list()`), bir iterator değildir (`next()`).

### Sınırlar

| Sınır | Ne olur |
|---|---|
| Callback başına 3 saniye | `TimeoutError: script took too long (possible infinite loop)`; istisnayı yakalamak onu durdurmaz |
| Pencere başına 64 MB | `MemoryError: out of memory (the app used more than 64 MB)`; `sys.memory()` kullanımı gösterir |
| 16 Python penceresi | 17.'si "too many Python apps are open" gösterir |
| özyineleme | `RecursionError: maximum recursion depth exceeded` |

### CPython (`"runtime": "python3"`)

`"runtime": "python3"` uygulamayı pocketpy yerine **CPython 3.12** ile çalıştırır: dilin tamamı (generator
expression'lar, `try`/`finally`, `nonlocal`, `async`...) ve standart kütüphane, `romfs:/System/Python3/lib.zip` içinde
`.pyc` dosyaları olarak. Yalnızca `.py` ana dosyası hâlâ `"python"` (pocketpy) demektir; mevcut uygulamalar değişmez.
Callback'ler, `app` nesnesi ve SDK yukarıdakilerle aynıdır; farklar:

- SDK aynı zamanda `nexvyn` modülüdür: `from nexvyn import gfx, ui` ya da `import nexvyn`. Modüller builtin olarak
  kalır, SDK'nın `sys` fonksiyonları Python'un `sys` modülündedir, `json` ise `json.encode` / `json.decode` eklenmiş
  standart `json`'dur. İsteğe bağlı argümanlar SDK'nın parametre adlarıyla verilebilir (bölüm 3:
  `gfx.text("Merhaba", 20, 20, size=18)`, `fs.unzip(zipPath, destDir, ...)`). Kayıtlar, anahtarları attribute olarak
  da okunan `dict`'lerdir.
- `open()` ve `os` çalışır, `fs.*` ile aynı izinle: uygulamanın bundle'ı ve veri klasörü
  (`fs.path("notlar.txt")`) her zaman serbesttir, diğer yollar `"files"` ister; `romfs:/` salt okunurdur. Ham soketler
  (`socket`) `"network"` ister; HTTP(S) için `net.*` kullanın (`ssl` yok). Thread'ler, `subprocess`, `os.system`,
  `os.chdir` ve ortam değişkenleri kullanılamaz. Mutlak yol kullanın ("sdmc:/..." ya da `fs.path`).
- `sys.exit()` / `exit()` pencereyi kapatır (`SystemExit`); `print` uygulamanın log'una gider.
- Gömülü C modülleri: `math`, `cmath`, `_struct`, `_json`, `_datetime`, `array`, `select`, `_socket`, `_random`,
  `_bisect`, `_heapq`, `_statistics`, `_contextvars`, `_queue`, `_pickle`, `_csv`, `binascii`, `zlib`, `_md5`,
  `_sha1`, `_sha2`, `_sha3`, `_blake2` ve çekirdek modüller. Olmayanlar: `unicodedata`, `_decimal` (`decimal` saf
  Python `_pydecimal`'ı kullanır), `ctypes`, `ssl`, `sqlite3`, `bz2`, `lzma`, `asyncio`, `multiprocessing`, `tkinter`,
  `email`, `http`, `xml`. C kodu içeren `pip` paketleri yüklenemez (`dlopen` yok); saf Python paketleri bundle'a
  kopyalanıp import edilebilir.
- Her pencere kendi yorumlayıcısını (bir CPython subinterpreter'ı) alır: aynı anda en fazla **4** python3 uygulaması,
  yukarıdaki gibi 64 MB ve callback başına 3 saniye. Applet modunda kullanılamaz (bellek yetmez). `sys.platform`
  `"switch"`'tir.
- CPython'suz derlemeler (`tools/build_cpython.sh` çalıştırılmamış) bu uygulamalarda "Python 3 yok" hatası gösterir.
- Bilgisayarda `python tools/py_check.py <bundle>` ile kontrol edin (`"python3"` runtime'ı algılanır; `--cpython`
  zorlar). Örnek: `romfs/Applications/hellopy3.nxvapp`.

### Eksiksiz örnek

`Counter.nxvapp/app.json`: bölüm 10'daki manifest artı `"main": "main.py"` ve `"minSdk": "1.3"`. Aynı
`lang/*.json`.
`Counter.nxvapp/main.py`
```python
count = 0


def load(arg):
    global count
    count = store.get("count", 0)


def bump(n):
    global count
    count = n
    store.set("count", count)


def draw(w, h):
    gfx.clear(theme.bg)
    gfx.color(theme.text)
    gfx.text(TR("title"), 0, 24, 24, "bold", "center", w)
    gfx.color(theme.accent)
    gfx.text(str(count), 0, 70, 64, "semibold", "center", w)
    gfx.color(theme.text2)
    gfx.text(TR("times", count), 0, 150, 14, "sans", "center", w)
    if ui.button("+1", w / 2 - 110, 190, 100, 34, "primary"):
        bump(count + 1)
        audio.play("click")
    if ui.button(TR("reset"), w / 2 + 10, 190, 100, 34):
        bump(0)


def event(e):
    if e.type == "keydown" and e.key == "space":
        bump(count + 1)
```

Daha büyük bir örnek (`store` ile yapılacaklar listesi, `gfx` ile çizilen bir saat, callback'li `net.json`, birkaç
modül) `romfs/Applications/hellopy.nxvapp`'tır. Bir bundle'ı PC'de `python tools/py_check.py path/to/App.nxvapp` ile
denetleyin.

## 13. Squirrel

> **Özet:** Uygulamalar C++'a benzeyen küçük bir dil olan Squirrel 3.2 ile de yazılabilir: `app.json` içinde
> `"runtime": "squirrel"`, `"main": "main.nut"` ve `"minSdk": "1.5"`. API ve kurallar Python'unkiyle aynıdır (0 tabanlı
> indeksler, çoklu sonuçlar dizi, async çağrılar callback alır). Türkçe rehber: `docs/SQUIRREL_APPS.tr.md`, örnek:
> `romfs/Applications/hellosq.nxvapp`.

`"runtime": "squirrel"` (ya da `.nut` uzantılı bir ana dosya) ve `"minSdk": "1.5"` ayarlayın. Squirrel 3.2'nin
sözdizimi C++'a benzer: kalıtımlı sınıflar, kapanışlar, lambda'lar (`@(x) x * 2`), generator'lar, `foreach`, tamsayılar
ve ondalık sayılar (`5 / 2` `2`'dir, `5 / 2.0` `2.5`'tir), tablolar `{a = 1}` ve diziler `[1, 2]`. Standart kütüphane:
math (`sin`, `sqrt`, `floor`, `rand`, `PI`...) ve string (`format`, `split`, `strip`, `regexp`...); io/system yok
(`fs`, `sys` kullanın).

```squirrel
class Counter {
    count = 0;                       // varsayılan değer olarak tablolar/diziler her örnek tarafından paylaşılır: onları load() içinde oluşturun
    function load(arg) { count = store.get("count", 0); }
    function draw(w, h) {
        gfx.clear(theme.bg);
        gfx.color(theme.text);
        gfx.text(count.tostring(), 0, 60, 48, "bold", "center", w);
        if (ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) {
            count++;
            store.set("count", count);
        }
    }
    function menu() { return [{title = TR("app"), items = [{label = TR("reset"), id = 1}]}]; }
    function onmenu(id) { if (id == 1) count = 0; }
}
return Counter();                    // ya da load/draw/... Function'larını genel function olarak tanımlayıp hiçbir şey döndürmeyin
```

- **Program**: `main.nut` uygulamayı döndürür (method'ları bölüm 2'deki callback'ler olan bir tablo ya da sınıf
  örneği) ya da callback'leri genel function'lar olarak tanımlar. `import("util")` `util.nut` dosyasını bir kez
  çalıştırır ve sonucunu döndürür (`import("a.b")` `a/b.nut` dosyasını yükler). `print(x)` uygulamanın günlüğüne yazar.
- **SDK**: bölüm 3–8b'deki modüller genel tablolardır (`gfx.rect(...)`, `ui.button(...)`, `TR(...)`, `theme.bg`).
  Değerler ve sonuçlar bölüm 12'yi (Python) izler: 0 tabanlı indeksler, birden çok sonuç bir dizi olarak
  (`local s = gfx.size(); s[0], s[1]`), `ui.textfield` metni döndürür ve `ui.submitted(id)` Enter'ı bildirir,
  `ui.row` 0/1/2 döndürür, record'lar tablodur (`e.type`, `res.ok`), `null` değer yok demektir.
- **Callback'ler** (timer'lar, `net`, iletişim kutuları) fonksiyondur; `this` = uygulama olarak çalışırlar, bu
  yüzden alanlar ve method'lar içlerinde çalışır: `net.json(url, function(data, err) { weather = data; })`. Argument'lar
  bölüm 12'deki Python tablosundakilerdir.
- **Mesh'ler** `Mesh` örnekleridir: `m.setColor(c)`, `m.flat(true)`, `m.triangles()`, `m.setTexture(p)`, `m.free()`.
- **Sınırlar**: pencere başına 64 MB, callback başına 3 saniye (her döngüde denetlenir; hatayı yakalamak işe
  yaramaz). Hatalar stack trace ile (`draw() main.nut:12`) hata ekranını açar.
- Bir bundle'ı PC'de denetleyin: `python tools/rt_check.py path/to/App.nxvapp` (SDK adları, argument sayıları,
  parantezler, çeviriler).

## 14. C

> **Özet:** Uygulamalar düz C ile de yazılabilir; bundle'daki `.c` dosyaları uygulama açılırken konsolda TinyCC ile
> derlenir (PC'de derleme adımı yok). `app.json`: `"runtime": "c"`, `"main": "main.c"`, `"minSdk": "1.5"`. SDK
> `#include <nexvyn.h>` ile gelir: `gfx.rect` → `gfx_rect`. C kodu sandbox'ta çalışmaz; SD karttan kurulan C
> uygulamaları ilk açılışta bir kez sorulur. Rehber: `docs/C_APPS.tr.md`, örnek: `romfs/Applications/helloc.nxvapp`.

`"runtime": "c"` (ya da `.c` uzantılı bir ana dosya) ve `"minSdk": "1.5"` ayarlayın. Pencere açıldığında bundle'ın her
`.c` dosyası (alt klasörler dahil) TinyCC tarafından belleğe derlenir ve uygulamanın callback'leri doğrudan
çağrılır. SDK header `<nexvyn.h>`'dir (`romfs:/System/C/include`); yanında sistemin newlib'ine bağlı küçük
bir C kütüphanesi vardır: `stdio.h` (`printf`/`puts` uygulamanın günlüğüne yazar, `snprintf`, `sscanf`; `FILE` yok),
`stdlib.h` (sayılan `malloc`, `qsort`, `strtod`, `rand`...), `string.h`, `math.h`, `ctype.h`, `stdint.h`, `limits.h`,
`assert.h`, `stdbool.h`, `stdarg.h`.

```c
#include <nexvyn.h>

static int count;

void app_load(const char* arg) { count = (int)store_getNum("count", 0); }

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    gfx_color(theme_color("text"));
    gfx_text(nxv_fmt("%d", count), 0, 60, 48, "bold", "center", w);
    if (ui_button("+1", w / 2 - 50, 140, 100, 34, "primary", NULL, true)) store_setNum("count", ++count);
}

void app_menu(void) {
    menu_begin(TR("app"));
    menu_item(TR("reset"), 1, NULL, false, true);
}

void app_onmenu(int id) { if (id == 1) store_setNum("count", count = 0); }
```

- **Callback'ler** sabit adlı function'lardır, hepsi isteğe bağlıdır: `app_load(const char*)`, `app_open`,
  `app_update(float)`, `app_draw(float, float)`, `app_event(const nxv_event*)`, `app_menu(void)` (`menu_begin` /
  `menu_item` / `menu_separator` ile kurun), `app_onmenu(int)`, `bool app_close(void)`, `app_search(const char*)`
  (`search_result(title, subtitle, icon, arg)` ile yanıt verin), `app_suspend`, `app_resume`, `app_focus(bool)`,
  `app_autosave`, `bool app_unsaved(void)`.
- **SDK function'ları** SDK'nın adlarının alt çizgili hâlidir: `gfx_rect`, `ui_iconButton`, `sys_schedule`...
  "Varsayılan" için isteğe bağlı sayılar `0`, isteğe bağlı metinler `NULL`'dur. Renkler metindir (`"#RRGGBB"`,
  `theme_color("accent")`, `rgba(r, g, b, a)`). Birden çok sonuç pointer'larla gelir (`gfx_size(&w, &h)`,
  `ui_mouse(&x, &y, &down, &hover)`), record'lar struct olarak (`nxv_hit`, `nxv_date`, `nxv_entry`,
  `nxv_response`). `ui_textfield` bir `char` buffer'ıni yerinde düzenler. `fs_read` `malloc` ile ayrılmış bir
  buffer döndürür (serbest bırakın). Görseller yoluyla çizilir (`gfx_draw("bundle:/a.png", ...)`), mesh'ler `int`
  id'lerdir. Döndürülen metinler sonraki 15 SDK çağrısı boyunca geçerli kalır: saklamak için kopyalayın. `nxv_fmt` böyle
  bir metne biçimlendirir: `TR1("score", nxv_fmt("%d", n))`. Listenin tamamı `nexvyn.h` içindedir.
- **Async çağrıların callback'leri** `void* user` argument'ı olan function pointer'larıdır:
  `void on_data(const char* json, const char* error, void* user)` ile `net_json(url, NULL, on_data, NULL)`;
  `timer_after(1.0, on_tick, NULL)`; `ui_alert(title, msg, buttons, 2, on_button, NULL)`. `net_json` JSON metnini
  verir (`json_pretty` onu biçimlendirir; `store_getJson` / `store_setJson` JSON değerlerini saklar).
- **Bellek**: `malloc` 64 MB'a karşı sayılır (aşınca NULL); pencere kapanınca geriye kalan her şey serbest bırakılır.
- **Yerel kod**: C uygulamaları sandbox'ta çalışmaz ve sonsuz bir döngü ya da bir çökme durdurulamaz (3 saniye
  sınırı yok). SD karta kurulan bir C uygulaması yalnızca kullanıcı bir kez onay verdikten sonra çalışır. C
  uygulamaları JIT kod belleği gerektirir (Atmosphère'in homebrew yükleyicisi bunu sağlar); yoksa hata ekranı bunu
  söyler.
- Derleme hataları hata ekranında dosya ve satırla gösterilir. PC'de `python tools/rt_check.py` ile denetleyin (aynı
  header'larına karşı devkitA64'ün gcc'siyle derler).

## 15. Java

> **Özet:** Uygulamalar Java ile de yazılabilir: kaynaklar PC'de `python tools/java_build.py app Uygulama.nxvapp`
> ile `app.jar`'a derlenir (JDK gerekir), konsolda miniJVM çalıştırır. `app.json`: `"runtime": "java"`,
> `"main": "app.jar"`, `"mainClass": "paket.Sinif"`, `"minSdk": "1.5"`. SDK `nexvyn` package'ındadır (`Gfx.rect`,
> `Ui.button`, `Sys.date`...). Aynı anda bir Java uygulaması çalışır. Rehber: `docs/JAVA_APPS.tr.md`, örnek:
> `romfs/Applications/hellojava.nxvapp`.

`"runtime": "java"`, `"main": "app.jar"`, `"mainClass"` (`nexvyn.App`'i genişleten bir sınıf; jar'ın manifest
dosyasında `Main-Class` varsa isteğe bağlı) ve `"minSdk": "1.5"` ayarlayın. Kaynakları `src/` içine koyun ve jar'ı
JDK'lı bir PC'de derleyin: `python tools/java_build.py app MyApp.nxvapp` (Java 8 sınıf dosyaları; konsolda bulunan
class library `romfs/System/Java/minijvm_rt.jar` ve SDK `nexvyn.jar`'a karşı derlenir). Konsol onu miniJVM'de (bir
yorumlayıcı) çalıştırır: `java.lang`, `java.util` (koleksiyonlar, `Random`, `Calendar`...), `java.util.function`,
lambda'lar, `String.format`, reflection ve thread'ler vardır; Swing/AWT, `java.net` soketleri ve `Runtime.exec`
yoktur.

```java
package counter;

import java.util.List;
import nexvyn.*;

public class CounterApp extends App {
    private int count;

    @Override public void load(String arg) {
        Object v = Store.get("count", 0);
        count = v instanceof Number ? ((Number) v).intValue() : 0;
    }

    @Override public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        Gfx.color(Theme.text());
        Gfx.text(String.valueOf(count), 0, 60, 48, "bold", "center", w);
        if (Ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) Store.set("count", ++count);
    }

    @Override public List<Menu> menu() { return Menu.bar(new Menu(TR("app")).item(TR("reset"), 1)); }

    @Override public void onmenu(int id) { if (id == 1) Store.set("count", count = 0); }
}
```

- **Callback'ler** `nexvyn.App`'in geçersiz kılınabilen method'larıdır: `load`, `open`, `update(double dt)` (yalnızca
  animasyon için geçersiz kılın), `draw(double w, double h)`, `event(Event e)` (`e.type`, `e.x`, `e.key`,
  `e.is("keydown")`...), `menu()` (`Menu.bar(new Menu(title).item(label, id, shortcut).separator())`), `onmenu`,
  `close`, `search` (`SearchResult` listesi), `suspend`, `resume`, `focus`, `autosave`, `unsaved`.
- **SDK sınıfları** modüllerin karşılığıdır: `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`,
  `Timer`, `Tr` (`App.TR(key, args...)`), `Theme` (`Theme.bg()`, `Theme.get("accent")`, `Theme.dark()`) ve `Json`
  (`Json.encode(v)`, `Json.decode(text)`). Her function `Object...` alır; bu yüzden isteğe bağlı argument'lar
  yazılmayabilir (`Gfx.rect(x, y, w, h)`, `Gfx.rect(x, y, w, h, 8, Theme.accent())`). Sonuçlar tiplidir (`boolean`,
  `double`, `int`, `String`, `Record`, `List<Object>`, birden çok sayı için `double[]`, `Mesh`). Değerler bölüm 12'yi
  izler: 0 tabanlı indeksler, sayılar `Double` olarak gelir, eşlemeler `Record` olarak (`str/num/integer/bool`
  alıcıları olan bir `LinkedHashMap`), listeler `List` olarak. SDK'nın liste aldığı yerlerde diziler
  (`new String[]{...}`, `double[]`) kabul edilir.
- **Async callback'ler** `Object... args` alan `nexvyn.Callback` lambda'larıdır; geçirirken lambda'yı tür
  dönüştürün: `Net.json(url, (Callback) a -> show((Record) a[0], a[1]))`, `Timer.after(1.5, (Callback) a -> hide())`.
- `System.out` ve `System.err` uygulamanın günlüğüne gider.
- **Sınırlar**: 64 MB Java heap; ana thread'deki callback'ler 3 saniye sonra durdurulur (`VMStopException`,
  her döngüde denetlenir). Aynı anda yalnızca bir Java uygulaması çalışır. Java'nın kendi class library (`java.io`
  dosyaları, `sun.misc.Unsafe`) uygulamanın izinleriyle sınırlanmaz; bu yüzden SD karta kurulan bir Java uygulaması
  yalnızca kullanıcı bir kez onay verdikten sonra çalışır.
- PC'de denetleme: `python tools/rt_check.py MyApp.nxvapp` (kaynakları derler, jar'ı ve ana sınıfı denetler). Java SDK
  kaynakları `sdk/java` içindedir; `python tools/gen_java_sdk.py` SDK sınıflarını sistemin function tablosundan
  yeniden üretir.

## 16. `"native"` içeren package'lar (iç kullanım, üçüncü taraf uygulamalar için değil)

> **Özet:** Nexvyn OS'un kendi C++ uygulamalarından bazıları NRO'ya gömülmek yerine Uygulama Mağazası'ndan yerel modül
> (`.nxvmod`) olarak kurulur. Bu yalnızca bir iç mekanizmadır: modül Nexvyn OS kaynaklarıyla aynı derleyici ve
> bayraklarla, her sürümle birlikte derlenir ve yalnızca aynı yapının ABI kimliğiyle çalışır. Üçüncü taraf uygulamalar
> Lua, JavaScript veya Python ile yazılır. Ayrıntılar: `docs/NATIVE_MODULES.tr.md`.

Üçüncü taraf uygulamalar Lua, JavaScript ya da Python ile yazılır (bölüm 1-13); uygulama platformu budur. App
Store'da Nexvyn OS'un kendi isteğe bağlı C++ uygulamalarının package'larıyla karşılaşabilirsiniz; bu bölüm yalnızca
onların ne olduğunu açıklar.

Bir `.nxvapp` betik yerine bir C++ uygulaması taşıyabilir: `"native": "<id>.nxvmod"` (bir AArch64 paylaşımlı nesnesi)
ve `"abi"` (derlendiği Nexvyn OS yapısının 16 onaltılık basamaklı ABI kimliği). Modül, Nexvyn OS kaynak ağacından
`tools/build_modules.py` ile derlenir (`tools/modules.json` içinde listelenir; `./build.sh` modülleri derler, o
uygulamaları `NexvynOS.nro` dışında bırakır ve `build/modules/<id>.nxvapp` yazar). Bu, uygulamanın sıradan C++
kaynağıdır: `App`'ten türetilmiş bir sınıf ve `REGISTER_APP("<id>", Class)`. Nexvyn OS modülü ilk açılışta JIT kod
belleğine eşler, NRO'nun dışa aktardığı simgelere bağlar ve yapıcılarını çalıştırır. Başka bir yapı için yapılmış bir
modül reddedilir ("rebuilt for Nexvyn OS x.y needed"); Uygulama Mağazası yalnızca çalışan yapıyla eşleşen modülleri sunar.
Yerel kod sandbox'ta çalışmaz; bu yüzden çalışmadan önce kullanıcıya bir kez sorulur (`apps.trustedNative`);
`"permissions"` yalnızca bilgi amaçlıdır. Bu bir üçüncü taraf SDK'sı değildir: C++ API'si Nexvyn OS'un iç API'sidir ve
her yapıyla değişir; modüller release pipeline tarafından her NexvynOS.nro ile birlikte yeniden derlenir.
