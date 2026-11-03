# Sosyal uygulama yapmak

[English](MAKE_A_SOCIAL_APP.en.md) · **Türkçe**

Nexvyn OS'ta SDK 1.9 fonksiyonlarıyla fotoğraf akışı, kısa video uygulaması ya da sohbet nasıl yapılır (başvuru:
`sdk/SDK.tr.md` bölüm 8d). Buradaki her şey Lua, JavaScript, Python ve C'de çalışır; örnekler Lua, farklı olduğu yerde
JavaScript yazımıyla. Hepsini kullanan eksiksiz uygulama **Sosyal Akış** örneği (`SDK/Samples/lua/social-feed`).

## 1. Başlamadan önce

- **app.json:** `"minSdk": "1.9"`, `"permissions": ["network"]` (hatırlatmalar için `"notifications"`, başka
  uygulamaları ya da Tarayıcı'yı açacaksanız `"launch"` ekleyin). Başka bir şey istemeyin.
- **Sunucu sizin.** Konsol onunla her istemci gibi HTTPS üzerinden konuşur: JSON API'ler, imzalı yükleme adresleri,
  WebSocket'ler. Sırları (client secret, yazma yetkili API anahtarları) sunucuda tutun, asla pakette değil: herkes bir
  `.nxvapp`'ı açabilir.
- **Pencereye göre tasarlayın.** Uygulamalar büyütülmüş açılır ama kullanıcı boyutlandırabilir; düzeni `app.draw`'un
  `w, h`'sinden kurun ve geniş ekranda okunur bir sütun (yaklaşık 560 px) tutun.
- **Her çağrı asenkron.** Hiçbir şey kareyi bekletmez; sonuçlar callback'lerle gelir. 3 saniyeden uzun süren callback
  durdurulur; büyük JSON'u sunucuda sayfalayın.

## 2. Akış: veri

```lua
local posts, page, loading = {}, 0, false

local function loadPage(n, done)
  net.request({url = API .. "/feed?page=" .. n, headers = auth(), responseType = "json",
               cache = n == 1 and 300 or nil, retry = 2}, function(res)
    if res.ok then
      for _, p in ipairs(res.data.items) do posts[#posts + 1] = p end
      page = n
    else
      toast(res.error)
    end
    if res.stale then toast(TR("offline")) end  -- çevrimdışıyken önbellekteki ilk sayfa
    done()
  end)
end
```

- `responseType = "json"` bir worker thread'de çözer ve `res.data`'yı verir.
- `cache = 300` ilk sayfayı SD kartta tutar: uygulama anında açılır ve çevrimdışıyken de gönderi gösterir
  (`res.stale = true`). Önbellek `ETag` / `Last-Modified` ile doğrulanır; değişmeyen akış bir 304'e mal olur.
- `retry = 2` kopan Wi-Fi bağlantısını atlatır (0,5 sn, 1 sn bekleme ve rastgele pay; `Retry-After` uygulanır).
- JavaScript: `net.request({...}, (res) => {...})` id döndürür; callback'siz Promise döndürür.

## 3. Akış: çizim

```lua
local f = ui.beginFeed("home", 0, top, w, h - top, #posts,
                       {heights = heights, gap = 10, refreshing = refreshing, loadingMore = loading})
for i = f.first, f.last do
  local r = ui.feedItem(i)
  drawPost(posts[i], r.x, r.y, r.w, r.h)
end
local ev = ui.endFeed()
if ev.refresh then reload() end
if ev.more and not loading then loading = true; loadPage(page + 1, function() loading = false end) end
```

- Yalnızca `first..last` öğeleri çizilir: binlerce gönderilik akış bir ekran kadar tutar.
- **Yükseklikler.** Farklı boyutlu gönderiler `heights` ister (gönderi başına bir sayı). Gönderi gelince bir kez ölçün
  (genişlik değişince yeniden): başlık + fotoğraf yüksekliği + `ui.measureRichText(caption, w - 24, 15)` + eylemler.
- **Izgara.** `columns = 3, gap = 2` kare hücreli fotoğraf ızgarası yapar (başka oranlar için `aspect`).
- **Çek-yenile** kullanıcı bırakınca bir kez bildirilir; isteğiniz bitene kadar `refreshing = true` gösterin.
- **Sonsuz kaydırma:** `more` her liste uzunluğu için bir kez gelir; yüklerken `loadingMore` verin ki tekrarlanmasın.

## 4. Resimler

```lua
local img = gfx.imageUrl(post.photoUrl, 640)     -- yüklenirken nil
if img then gfx.draw(img, x, y, w, w, 10) else gfx.rect(x, y, w, w, 10, theme.control) end
```

- `gfx.image` gibi her kare çağırın. İndirme, çözme ve küçültme arka planda çalışır; gelmeden ekrandan çıkan resimler
  atlanır.
- **Çizdiğiniz boyutu isteyin.** Tam genişlik fotoğraf için `maxSize = 640`, ızgara hücresi için `256`, avatar için
  `96`: küçük resim SD karta yazılır, bir sonraki açılış 4000 px'lik orijinal yerine küçük bir dosya yükler.
- Uygulama başına 96 MB resim SD kartta kalır (en eski indirilen önce gider); `net.clearCache()` boşaltır.
- JavaScript / Python: `gfx.imageUrl` yüklenirken `null` / `None` döner; `gfx.imageState(url, size)` `"loading"`,
  `"ready"` ya da `"error: ..."` söyler (hatada yeniden dene simgesi gösterin).

## 5. Kısa videolar

```lua
local pg = ui.pager("reels", 0, 0, w, h, #clips)
for i = math.max(1, math.floor(pg.pos)), math.min(#clips, math.floor(pg.pos) + 1) do
  media.draw(player(i), 0, (i - pg.pos) * h, w, h, "cover")
end
if pg.changed then keepOnly(pg.page, pg.page + 1); media.play(player(pg.page)) end
```

- Kaydırmayı `ui.pager` yapar: fırlatma başına bir sayfa, uçlarda lastik etkisi, D-pad ve tekerlek de çalışır. `i`
  sayfasını `(i - pos) * h`'ye çizin.
- `media.open(url, {loop = true, autoplay = false})` MP4 ya da HLS (`.m3u8`) akıtır, konsolun video çözücüsüyle.
  Uygulama başına en çok 3 oynatıcı: şimdiki ve sonraki klibi açık tutun (sonraki hemen başlar), gerisini kapatın.
- `media.info(p).buffering` ya da `state == "opening"` iken çark gösterin; `"failed"` olunca `info.error` ve yeniden
  dene düğmesi.
- `app.suspend`'de ve kullanıcı sekmeden çıkınca duraklatın; `app.resume`'da sürdürün.
- Yalnızca ses (podcast, sesli not): `media.open(url, {audioOnly = true})`.

## 6. Açıklamalar ve yorumlar

```lua
local r = ui.richText("c" .. post.id, post.caption, x, y, w, 15)
if r.clicked and r.clicked.type == "hashtag" then openTag(r.clicked.value) end
gfx.text(sys.relativeTime(post.createdAt), x, y + r.height + 4, 12)
```

`**kalın**`, bağlantılar, `@bahsetmeler` ve `#etiketler` sizin için bulunur; dokunuş hangisi olduğunu söyler.
`maxLines = 3` uzun açıklamayı "…" ile keser (dokununca tamamını gösterin). `sys.relativeTime` kullanıcının dilinde
"5 dk", "3 sa", "2 g" yazar.

## 7. Paylaşım: yükleme

```lua
net.request({url = API .. "/posts", method = "POST", headers = auth(), responseType = "json",
  multipart = {{name = "caption", value = caption}, {name = "photo", file = path, type = "image/jpeg"}}},
  function(res) if res.ok then addPost(res.data) else toast(res.error) end end,
  function(now, total, phase) if phase == "upload" then progress = now / total end end)
```

- Dosyalar SD karttan akıtılır, asla bütünüyle yüklenmez: 200 MB'lık video yüklemesi neredeyse hiç bellek harcamaz.
- İmzalı yükleme adresi veren depolama servisleri için: `net.request({url = signedUrl, file = path,
  contentType = "video/mp4"}, ...)` (ham dosyanın `PUT`'u).
- Dosya uygulamanın okuyabildiği bir yerde olmalı: kendi veri klasörü, kullanıcının `ui.openFile` ile seçtiği dosya
  (seçici izin verir) ya da `"files"` izni.
- Sunucunuz tekrarı ayıklamıyorsa POST'u otomatik yeniden denemeyin (idempotency anahtarı başlığı gönderin).

## 8. Oturum açma

```lua
net.oauth({url = AUTH .. "/authorize?client_id=" .. CLIENT .. "&response_type=code&scope=basic",
           redirect = "http://localhost/callback", pkce = true}, function(r, err)
  if err then return showLoginError(err) end
  net.request({url = AUTH .. "/token", method = "POST", responseType = "json", form = {
    grant_type = "authorization_code", code = r.code, code_verifier = r.verifier, client_id = CLIENT,
    redirect_uri = "http://localhost/callback"}}, function(res)
    if res.ok then saveToken(res.data) end
  end)
end)
```

- Oturum açma sayfası konsolun web tarayıcısında açılır; şifreler uygulamanızdan geçmez. `state` sizin için denetlenir;
  `pkce = true` kullanın (public istemciler için zorunlu).
- Sağlayıcınızda yönlendirme adresi olarak `http://localhost/callback`'i (ya da `nxv://app/<id'niz>/callback`)
  kaydedin.
- Tarayıcı, Nexvyn OS'un uygulama olarak açıldığı gerçek bir konsol ister. Başka yerde `err` nedenini söyler; o zaman
  **cihaz kodu** ile girişi sunun: sunucunuz kısa bir kod gösterir, kullanıcı telefonda girer, uygulama birkaç saniyede
  bir `net.request` ile sunucunuza sorar.
- Erişim token'ını `store.set` ile saklayın (uygulamanın özel veri klasörü) ve süresi bitmeden yenileyin. Oturum
  çerezleri de çalışır: her istekte `cookies = true` uygulamanın kendi çerez kutusunu kullanır.

## 9. Gerçek zaman: sohbet ve canlı sayaçlar

```lua
sock = net.ws(WS_URL, {headers = auth()})
function app.update(dt)
  for _, ev in ipairs(net.wsPoll(sock)) do
    if ev.type == "message" then onMessage(json.decode(ev.data))
    elseif ev.type == "close" then timer.after(backoff(), connect) end
  end
end
```

- Her kare yoklayın: olaylar kareler arasında birikir (16 MB okunmadan kalırsa soket kendini kapatır).
- `close`'dan sonra artan beklemeyle (1, 2, 4 ... 30 sn) ve `app.resume`'dan sonra yeniden bağlanın (konsol uyurken
  soketler biter).
- Uygulama başına en çok 4 soket; genelde biri yeter (kanalları sunucunuzda çoğullayın).

## 10. Bildirimler ve bağlantılar

- **Hatırlatma ve özetler:** `sys.schedule(epoch, başlık, metin, "inbox")` uygulama kapalıyken bildirim gönderir;
  dokununca uygulama `arg = "inbox"` ile açılır. Arka plan kodu yok: yeni öğeleri uygulama açılınca ve `app.resume`'da
  çekin.
- **Paylaşma:** `sys.share(metin)` paylaşım sayfasını açar (kopyala, diğer uygulamalar). İçine gönderinin bağlantısını
  koyun: `sys.appUrl(sys.appid(), "post:" .. id)` uygulamanızı o gönderide açar (`app.load(arg)` / `app.open(arg)`).

## 11. Performans ve bellek listesi

- Listede çizilen boyutta küçük resimler (`maxSize`), asla tam orijinaller.
- Yükseklikler gönderi başına bir kez ölçülür, her kare değil.
- En çok iki video oynatıcı açık; gereksiz oynatıcı ve soketleri kapatın.
- 20–50 öğelik sayfalar; uzun JSON `responseType = "json"` ile çözülür (ana thread dışında).
- `sys.memory()` betikler için 64 MB'ın epey altında kalır; resimler ve video betik belleğinin dışında yaşar.
- Çevrimdışı deneyin (uçak modu): uygulama açılır, önbellekteki akışı gösterir ve çevrimdışı olduğunu söyler.

## 12. Başka platformlardan taşıma

| Başka yerdeki fikir | Nexvyn OS |
|---|---|
| hücre geri dönüşümlü liste görünümü | `ui.beginFeed` (yalnızca görünen öğeler çizilir; elle geri dönüştürülecek bir şey yok) |
| disk önbellekli resim yükleme kütüphanesi | `gfx.imageUrl(url, maxSize)` |
| video görünümü / oynatıcı | `media.open` + `media.draw` |
| sayfa görünümü, dikey sayfalama | `ui.pager` |
| dokunulabilir bağlantılı biçimli metin | `ui.richText` |
| interceptor'lı HTTP istemcisi | başlıkları ekleyip `net.request` çağıran küçük bir fonksiyon |
| callback'li WebSocket sınıfı | `app.update`'te `net.ws` + `net.wsPoll` |
| sistem tarayıcısı oturumuyla giriş | `net.oauth` |
| push bildirimleri | yok: yerel hatırlatmalar için `sys.schedule`, açılışta / sürdürmede yenileme |

## 13. Yayımlamadan önce

- Mağaza ekran görüntüleri İngilizce arayüzle (5 önerilir): `store.json`'a bir `"shots"` betiği ekleyin (Yayımlama
  rehberi, bölüm 6).
- `python SDK/Tools/nxv/nxv.py check <bundle> --sdk <kaynak kopyası>` geçmeli; dil checker'ları SDK 1.9
  fonksiyonlarını bilir.
- Uygulamanın sunucunuza ne gönderdiğini mağaza açıklamasında yazın. İzinsiz izleme yok.
