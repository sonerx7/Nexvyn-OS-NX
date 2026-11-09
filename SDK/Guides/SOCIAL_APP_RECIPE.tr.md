# Sosyal uygulama tarifi: tek dosyada fotoğraf ve klip akışı (SDK 1.9)

[English](SOCIAL_APP_RECIPE.en.md) · **Türkçe**

`app.json`'dan son callback'e kadar eksiksiz küçük bir akış uygulaması: **Moments**, gönderileri bir JSON adresinden
yükler, onları pull to refresh ve "daha fazla yükle" olan sanal bir listede gösterir, avatarları ve fotoğrafları
küçük resim (thumbnail) olarak indirir, açıklamaları bağlantı, mention ve hashtag'lerle biçimler, "5m" tarzı zamanlar
yazar, bir klibi tam pencere bir görüntüleyicide oynatır ve çevrimdışıyken cache'ten çalışmaya devam eder. Program
burada Lua ve JavaScript ile eksiksiz; Python ve C, farklı olan çağrılarla daha kısa programlar olarak gelir.

Bu sayfa kısa tariftir. Yükleme (upload), oturum açma, WebSocket'ler, kısa videolar için kaydırmalı sayfalayıcı,
bildirimler ve performans kontrol listesiyle derin rehber [MAKE_A_SOCIAL_APP.tr.md](MAKE_A_SOCIAL_APP.tr.md); ızgara ve
video sayfalayıcı içeren daha büyük örnek [social-feed](../Samples/lua/social-feed/). Bu sayfadaki her program,
basıldığı hâliyle SDK checker'larından (`lua_check.py`, `js_check.mjs`, `py_check.py`, `rt_check.py`) geçti; her
fonksiyon [SDK başvurusunda](../Reference/SDK.tr.md), bölüm 8d'de var.

## İçindekiler

1. [Ne yapıyorsunuz](#1-ne-yapıyorsunuz)
2. [Sunucunuzun gönderdiği akış](#2-sunucunuzun-gönderdiği-akış)
3. [Paket](#3-paket)
4. [main.lua](#4-mainlua)
5. [Nasıl çalışıyor](#5-nasıl-çalışıyor)
6. [JavaScript](#6-javascript)
7. [Python ve C](#7-python-ve-c)
8. [Daha ileri](#8-daha-ileri)
9. [Denetleme ve yayın](#9-denetleme-ve-yayın)

## 1. Ne yapıyorsunuz

| Uygulamanın parçası | SDK 1.9 çağrısı |
|---|---|
| Ana thread dışında çözülen, yeniden denenen, 10 dakika cache'lenen ve çevrimdışı kullanım için saklanan JSON akış | `net.request{responseType = "json", retry, cache}` |
| Yalnızca görünen gönderileri çizen, pull to refresh ve sonda "daha fazla yükle" olan liste | `ui.beginFeed` / `ui.feedItem` / `ui.endFeed` |
| Avatarlar (96 px) ve fotoğraflar (640 px) thumbnail olarak, yüklenirken yer tutucu | `gfx.imageUrl(url, maxSize)` |
| `**kalın**`, bağlantı, `@mention` ve `#hashtag` içeren, gönderi başına bir kez ölçülen açıklamalar | `ui.richText`, `ui.measureRichText` |
| Kullanıcının dilinde "now", "5m", "3h", "2d" | `sys.relativeTime` |
| Sessize alma, buffering spinner'ı ve ilerleme çizgisiyle tam pencere klip görüntüleyici | `media.open` / `media.draw` / `media.info` / `media.set` / `media.close` |
| Çalıştırmalar arasında saklanan beğeniler | `store` |

Tek izin `"network"`. Uygulama OS tarzı bir uygulamadır: `theme` renklerini ve `ui` widget'larını kullanır, bu yüzden
açık ve koyu modda doğru görünür.

## 2. Sunucunuzun gönderdiği akış

```json
{
  "posts": [
    {"id": "p1", "user": "mira", "avatar": "https://.../mira.jpg", "time": 1762160400, "likes": 12,
     "photo": "https://.../p1.jpg", "clip": "https://.../p1.mp4", "caption": "Text with **bold**, @names and #tags"}
  ],
  "next": "https://.../feed.json?page=2"
}
```

`time` saniye cinsinden Unix zamanıdır, `next` sonraki sayfanın adresi ya da sonda `null`; `avatar` ve `clip` isteğe
bağlıdır. Sayfaları 20-50 gönderide tutun. Klipler MP4, WebM, MKV ya da HLS (`.m3u8`) olabilir. `FEED_URL`'i kendi
sunucunuza yöneltin. Bunu yapana kadar (ya da ilk yükleme cache'te hiçbir şey yokken başarısız olursa) uygulama
paketindeki `sample-feed.json`'u gösterir; böylece hiçbir zaman boş bir ekran olmaz.

## 3. Paket

```
Moments.nxvapp/
├── app.json
├── main.lua
├── icon.png              256 x 256, uygulamanızın bir resmi
├── sample-feed.json      FEED_URL cevap verene kadar gösterilir
└── lang/en.json          İngilizce zorunlu; başka diller için lang/<kod>.json ekleyin
```

`app.json`:

```json
{
  "id": "com.yourname.moments",
  "name": {"en": "Moments"},
  "description": {"en": "Photos and short clips from people you follow"},
  "version": "1.0",
  "author": "Your Name",
  "category": "internet",
  "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 720, "height": 640, "minWidth": 360, "minHeight": 480, "resizable": true},
  "singleInstance": true,
  "minSdk": "1.9",
  "targetSdk": "1.9",
  "permissions": ["network"]
}
```

`lang/en.json`:

```json
{
  "title": "Moments",
  "likes": "{0} likes",
  "offline": "You are offline: showing saved posts",
  "sample": "Sample posts: point FEED_URL at your server",
  "failed": "Could not load more posts",
  "empty": "Nothing here yet. Pull down to refresh."
}
```

`sample-feed.json` (resimler ve klip, herkese açık Social Feed örneğinin CC0 medyasıdır):

```json
{
  "posts": [
    {"id": "s1", "user": "mira", "time": 1762160400, "likes": 12,
     "photo": "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/photo01.jpg",
     "caption": "First light over the harbour. **Worth the early start.** #sunrise"},
    {"id": "s2", "user": "deniz", "time": 1762153200, "likes": 31,
     "photo": "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/photo02.jpg",
     "clip": "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/clip1.mp4",
     "caption": "Ten seconds of rain on the window, with @mira #slowtv"},
    {"id": "s3", "user": "kai", "time": 1762070400, "likes": 7,
     "photo": "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/photo03.jpg",
     "caption": "Notes from the workshop: https://example.com/notes"}
  ],
  "next": null
}
```

## 4. main.lua

```lua
-- Moments: a small photo and clip feed (SDK 1.9). The deep guide is MAKE_A_SOCIAL_APP.en.md.
--   net.request   the feed as JSON, cached for 10 minutes, retried; the cached copy when offline
--   gfx.imageUrl  avatars and photos as thumbnails of the drawn size
--   ui.beginFeed  virtualized list with pull-to-refresh and "load more"
--   ui.richText   captions with **bold**, links, @mentions and #hashtags; sys.relativeTime for "5m"
--   media.*       a clip in a full-window viewer
local app = {}

local FEED_URL = "https://example.com/moments/feed.json"   -- your server: {"posts": [...], "next": url or null}
local TOP, PAD = 56, 12

local posts, nextUrl = {}, nil
local heights, heightsW = {}, 0   -- measured post heights for the column width heightsW
local refreshing, loadingMore = false, false
local offline, sample = false, false
local liked = {}                  -- post id (string) -> true
local toast, toastT = "", 0
local viewer = nil                -- {post, player} while a clip is open

local function say(text) toast, toastT = text, 2.5 end

-- ------------------------------------------------------------------ data
local function addPosts(list)
  for _, p in ipairs(list or {}) do posts[#posts + 1] = p end
end

local function load(url, first)
  net.request({url = url, responseType = "json", cache = 600, retry = 2, timeout = 15}, function(res)
    local data = res.ok and res.data or nil
    if first then posts, heights = {}, {} end
    if type(data) == "table" and type(data.posts) == "table" then
      addPosts(data.posts)
      nextUrl, sample = data.next, false
      offline = res.stale == true          -- the last good answer from the cache: the network failed
      if offline then say(TR("offline")) end
    elseif first then
      -- no server yet, or offline with nothing cached: the bundled sample keeps the app from being empty
      local s = json.decode(fs.read("bundle:/sample-feed.json") or "{}") or {}
      addPosts(s.posts)
      nextUrl, sample = nil, true
    else
      say(res.error ~= "" and res.error or TR("failed"))
    end
    refreshing, loadingMore = false, false
  end)
end

local function refresh()
  refreshing = true
  load(FEED_URL, true)
end

local function loadMore()
  if nextUrl and not loadingMore then
    loadingMore = true
    load(nextUrl, false)
  end
end

-- ------------------------------------------------------------------ clip viewer
local function openClip(post)
  if viewer then media.close(viewer.player) end
  viewer = {post = post, player = media.open(post.clip, {loop = true, autoplay = true})}
end

local function closeClip()
  if viewer then
    media.close(viewer.player)
    viewer = nil
  end
end

local function drawViewer(w, h)
  gfx.rect(0, 0, w, h, 0, "#000000")
  media.draw(viewer.player, 0, TOP, w, h - TOP - 64, "contain")
  local i = media.info(viewer.player)
  if i.state == "opening" or i.buffering then ui.spinner(w / 2, h / 2, 18) end
  if i.state == "failed" then
    gfx.color("#FFFFFF")
    gfx.text(i.error or "", 0, h / 2, 14, "sans", "center", w)
  end
  if (i.duration or 0) > 0 then gfx.rect(0, h - 64, w * (i.position or 0) / i.duration, 3, 0, theme.accent) end
  gfx.color("#FFFFFF")
  gfx.text(viewer.post.user or "", 16, h - 48, 15, "semibold")
  if ui.iconButton(i.muted and "volume_off" or "volume_up", w - 104, 8, 44, 44, "#FFFFFF", false, "mute") then
    media.set(viewer.player, {muted = not i.muted})
  end
  if ui.iconButton("close", w - 56, 8, 44, 44, "#FFFFFF", false, "closeClip") then closeClip() end
end

-- ------------------------------------------------------------------ feed
local function photoSize(w) return math.min(w - PAD * 2, 520) end

local function postHeight(p, w)
  return 60 + photoSize(w) + 44 + ui.measureRichText(p.caption or "", w - PAD * 2 - 8, 15) + 16
end

local function onTap(c)
  if c.type == "mention" then say("@" .. c.value)
  elseif c.type == "hashtag" then say("#" .. c.value)
  else say(c.value) end                    -- a link: show it (opening the Browser needs "launch")
end

local function drawPost(p, x, y, w, h)
  local key = tostring(p.id)
  gfx.rect(x, y, w, h, 14, theme.window)
  -- header: avatar, name, time
  local av = p.avatar and gfx.imageUrl(p.avatar, 96)
  if av then gfx.draw(av, x + PAD, y + 12, 36, 36, 18) else gfx.circle(x + PAD + 18, y + 30, 18, theme.control) end
  gfx.color(theme.text)
  gfx.text(p.user or "?", x + PAD + 46, y + 12, 15, "semibold")
  gfx.color(theme.text2)
  gfx.text(sys.relativeTime(p.time or sys.epoch()), x + PAD + 46, y + 31, 12)
  -- photo: a thumbnail of the drawn size, a placeholder while it loads
  local ps = photoSize(w)
  local px, py = x + (w - ps) / 2, y + 60
  local img = p.photo and gfx.imageUrl(p.photo, 640)
  if img then gfx.draw(img, px, py, ps, ps, 10) else gfx.rect(px, py, ps, ps, 10, theme.control) end
  if p.clip then
    gfx.circle(px + ps / 2, py + ps / 2, 30, "#00000080")
    gfx.icon("play_arrow", px + ps / 2, py + ps / 2, 36, "#FFFFFF")
    if ui.hit("clip" .. key, px, py, ps, ps).clicked then openClip(p) end
  end
  -- actions
  local ay = py + ps + 4
  local on = liked[key] == true
  if ui.iconButton(on and "favorite" or "favorite_border", x + PAD - 4, ay, 36, 36, on and theme.red or theme.text,
                   false, "like" .. key) then
    liked[key] = (not on) or nil
    store.set("liked", liked)
  end
  gfx.color(theme.text2)
  gfx.text(TR("likes", (p.likes or 0) + (on and 1 or 0)), x + PAD + 40, ay + 10, 13)
  -- caption
  gfx.color(theme.text)
  local r = ui.richText("cap" .. key, p.caption or "", x + PAD + 4, ay + 42, w - PAD * 2 - 8, 15)
  if r.clicked then onTap(r.clicked) end
end

local function drawFeed(x, y, w, h)
  local cw = math.min(w - 16, 600)         -- a readable column on wide windows
  if heightsW ~= cw then heights, heightsW = {}, cw end
  for i = #heights + 1, #posts do heights[i] = postHeight(posts[i], cw) end   -- measured once per post
  local f = ui.beginFeed("feed", x, y, w, h, #posts, {heights = heights, gap = 12, padTop = 4, padBottom = 12,
                                                      refreshing = refreshing, loadingMore = loadingMore})
  for i = f.first, f.last do
    local r = ui.feedItem(i)
    drawPost(posts[i], r.x + (r.w - cw) / 2, r.y, cw, r.h)
  end
  local ev = ui.endFeed()
  if ev.refresh then refresh() end
  if ev.more then loadMore() end
end

-- ------------------------------------------------------------------ callbacks
function app.load(arg)
  liked = store.get("liked", {})
  refresh()
end

function app.update(dt)
  if toastT > 0 then toastT = toastT - dt end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if viewer then
    drawViewer(w, h)
  else
    gfx.color(theme.text)
    gfx.text(TR("title"), 16, 14, 22, "bold")
    if sample or offline then
      gfx.color(theme.text2)
      gfx.text(sample and TR("sample") or TR("offline"), 16, 40, 12)
    end
    if ui.iconButton("refresh", w - 52, 8, 40, 40, theme.text, false, "reload") then refresh() end
    drawFeed(0, TOP, w, h - TOP)
    if #posts == 0 and not refreshing then
      gfx.color(theme.text2)
      gfx.text(TR("empty"), 0, h / 2, 15, "sans", "center", w)
    end
  end
  if toastT > 0 and toast ~= "" then
    local tw = math.min(w - 40, gfx.textWidth(toast, 14) + 32)
    gfx.rect((w - tw) / 2, h - 56, tw, 36, 18, "#000000C0")
    gfx.color("#FFFFFF")
    gfx.text(toast, (w - tw) / 2, h - 47, 14, "sans", "center", tw)
  end
end

function app.event(e)
  if viewer and e.type == "keydown" and e.key == "escape" then closeClip() end   -- B on the controller is Escape
end

function app.suspend() if viewer then media.pause(viewer.player) end end

function app.resume()
  if viewer then media.play(viewer.player) end
  refresh()                                -- no background code runs while the app sleeps: catch up now
end

function app.close()
  closeClip()
  return true
end

return app
```

## 5. Nasıl çalışıyor

**Ağ işini tek istek yapar.** `responseType = "json"` cevabı bir worker thread'de çözer (`res.data`). `retry = 2`;
cevap yoksa, 408, 429 ya da 5xx'te bekleyerek yeniden dener. `cache = 600` 10 dakika boyunca diskteki cache'ten cevap
verir, sonra `ETag` / `Last-Modified` ile yeniden doğrular, ağ başarısız olunca da son iyi cevabı `res.stale = true` ile
döndürür: uygulama o zaman çevrimdışı olduğunu söyler ve gönderileri göstermeye devam eder.

**Daha fazla yükle.** Son gönderiler ekrandayken `ev.more` her liste uzunluğu için bir kez gelir. Uygulama `next`'i
yükler ve bu arada `loadingMore`'u ayarlar; bu, sonda spinner'ı gösterir ve yeni `more` olaylarını durdurur.

**Yükseklikler bir kez ölçülür.** Açıklamalar farklı olduğu için gönderilerin yükseklikleri farklıdır, bu yüzden akış
bir `heights` listesi alır. Her gönderi geldiğinde `ui.measureRichText` ile bir kez ölçülür; liste yalnızca sütun
genişliği değişince yeniden ölçülür.

**Çizilen boyutta resimler.** Avatarlar için `gfx.imageUrl(url, 96)`, fotoğraflar için `640`, SD karta orijinalleri
değil thumbnail'ları kaydeder; gelmeden önce kaydırılıp giden resim atlanır. Hazır olana kadar çağrı `nil` döndürür ve
uygulama bir yer tutucu çizer.

**Açıklamalardaki dokunuşlar.** `ui.richText`, bir bağlantıya, mention'a ya da hashtag'e dokunulan karede `clicked`
döndürür. Moments bunu bir toast'ta gösterir; gerçek bir uygulama profil ya da arama açar. Bir bağlantıyı
`sys.launch("browser", url)` ile Tarayıcı'da açmak `"launch"` izni ister.

**Klip görüntüleyici.** `media.open(url, {loop = true, autoplay = true})` bir oynatıcı başlatır; `media.draw` her karede
onun o anki görüntüsünü çizer. Görüntüleyici açıkken akış çizilmez; böylece widget'ları dokunuşları alamaz.
`media.info` spinner için durumu (`"opening"`, `buffering`), hata metnini (`"failed"`) ve ilerleme çizgisini verir.
Görüntüleyiciyi kapatmak oynatıcıyı kapatır: uygulama başına en fazla 3 oynatıcı.

**Yaşam döngüsü.** `app.suspend` klibi duraklatır (HOME menüsü, uyku), `app.resume` onu yeniden oynatır ve akışı
yeniler (arka planda akış denetimi yoktur, bu yüzden uygulama döndüğünde eksiğini kapatır), `app.close` oynatıcıyı
kapatır.

## 6. JavaScript

Aynı uygulama `main.js` olarak. `app.json`'da `"main": "main.js"` yazın; `lang/en.json` ve `sample-feed.json` aynı
dosyalardır.

```js
// Moments: a small photo and clip feed (SDK 1.9), JavaScript version. The deep guide is MAKE_A_SOCIAL_APP.en.md.
import sampleFeed from "./sample-feed.json";   // the bundled sample, parsed

const FEED_URL = "https://example.com/moments/feed.json";   // your server: {"posts": [...], "next": url or null}
const TOP = 56, PAD = 12;

let posts = [], nextUrl = null;
let heights = [], heightsW = 0;   // measured post heights for the column width heightsW
let refreshing = false, loadingMore = false;
let offline = false, sample = false;
let liked = {};                   // post id (string) -> true
let toast = "", toastT = 0;
let viewer = null;                // {post, player} while a clip is open

const say = (text) => { toast = text; toastT = 2.5; };

// ------------------------------------------------------------------ data
function load(url, first) {
  net.request({ url, responseType: "json", cache: 600, retry: 2, timeout: 15 }, (res) => {
    const data = res.ok ? res.data : null;
    if (first) { posts = []; heights = []; }
    if (data && Array.isArray(data.posts)) {
      posts.push(...data.posts);
      nextUrl = data.next ?? null;
      sample = false;
      offline = res.stale === true;        // the last good answer from the cache: the network failed
      if (offline) say(TR("offline"));
    } else if (first) {
      // no server yet, or offline with nothing cached: the bundled sample keeps the app from being empty
      posts.push(...(sampleFeed.posts || []));
      nextUrl = null;
      sample = true;
    } else {
      say(res.error || TR("failed"));
    }
    refreshing = false;
    loadingMore = false;
  });
}

function refresh() {
  refreshing = true;
  load(FEED_URL, true);
}

function loadMore() {
  if (nextUrl && !loadingMore) {
    loadingMore = true;
    load(nextUrl, false);
  }
}

// ------------------------------------------------------------------ clip viewer
function openClip(post) {
  if (viewer) media.close(viewer.player);
  viewer = { post, player: media.open(post.clip, { loop: true, autoplay: true }) };
}

function closeClip() {
  if (viewer) {
    media.close(viewer.player);
    viewer = null;
  }
}

function drawViewer(w, h) {
  gfx.rect(0, 0, w, h, 0, "#000000");
  media.draw(viewer.player, 0, TOP, w, h - TOP - 64, "contain");
  const i = media.info(viewer.player);
  if (i.state === "opening" || i.buffering) ui.spinner(w / 2, h / 2, 18);
  if (i.state === "failed") {
    gfx.color("#FFFFFF");
    gfx.text(i.error || "", 0, h / 2, 14, "sans", "center", w);
  }
  if ((i.duration || 0) > 0) gfx.rect(0, h - 64, w * (i.position || 0) / i.duration, 3, 0, theme.accent);
  gfx.color("#FFFFFF");
  gfx.text(viewer.post.user || "", 16, h - 48, 15, "semibold");
  if (ui.iconButton(i.muted ? "volume_off" : "volume_up", w - 104, 8, 44, 44, "#FFFFFF", false, "mute")) {
    media.set(viewer.player, { muted: !i.muted });
  }
  if (ui.iconButton("close", w - 56, 8, 44, 44, "#FFFFFF", false, "closeClip")) closeClip();
}

// ------------------------------------------------------------------ feed
const photoSize = (w) => Math.min(w - PAD * 2, 520);

const postHeight = (p, w) => 60 + photoSize(w) + 44 + ui.measureRichText(p.caption || "", w - PAD * 2 - 8, 15) + 16;

function onTap(c) {
  if (c.type === "mention") say("@" + c.value);
  else if (c.type === "hashtag") say("#" + c.value);
  else say(c.value);                       // a link: show it (opening the Browser needs "launch")
}

function drawPost(p, x, y, w, h) {
  const key = String(p.id);
  gfx.rect(x, y, w, h, 14, theme.window);
  // header: avatar, name, time
  const av = p.avatar ? gfx.imageUrl(p.avatar, 96) : null;
  if (av) gfx.draw(av, x + PAD, y + 12, 36, 36, 18);
  else gfx.circle(x + PAD + 18, y + 30, 18, theme.control);
  gfx.color(theme.text);
  gfx.text(p.user || "?", x + PAD + 46, y + 12, 15, "semibold");
  gfx.color(theme.text2);
  gfx.text(sys.relativeTime(p.time || sys.epoch()), x + PAD + 46, y + 31, 12);
  // photo: a thumbnail of the drawn size, a placeholder while it loads
  const ps = photoSize(w);
  const px = x + (w - ps) / 2, py = y + 60;
  const img = p.photo ? gfx.imageUrl(p.photo, 640) : null;
  if (img) gfx.draw(img, px, py, ps, ps, 10);
  else gfx.rect(px, py, ps, ps, 10, theme.control);
  if (p.clip) {
    gfx.circle(px + ps / 2, py + ps / 2, 30, "#00000080");
    gfx.icon("play_arrow", px + ps / 2, py + ps / 2, 36, "#FFFFFF");
    if (ui.hit("clip" + key, px, py, ps, ps).clicked) openClip(p);
  }
  // actions
  const ay = py + ps + 4;
  const on = liked[key] === true;
  if (ui.iconButton(on ? "favorite" : "favorite_border", x + PAD - 4, ay, 36, 36, on ? theme.red : theme.text,
                    false, "like" + key)) {
    if (on) delete liked[key]; else liked[key] = true;
    store.set("liked", liked);
  }
  gfx.color(theme.text2);
  gfx.text(TR("likes", (p.likes || 0) + (on ? 1 : 0)), x + PAD + 40, ay + 10, 13);
  // caption
  gfx.color(theme.text);
  const r = ui.richText("cap" + key, p.caption || "", x + PAD + 4, ay + 42, w - PAD * 2 - 8, 15);
  if (r.clicked) onTap(r.clicked);
}

function drawFeed(x, y, w, h) {
  const cw = Math.min(w - 16, 600);        // a readable column on wide windows
  if (heightsW !== cw) { heights = []; heightsW = cw; }
  for (let i = heights.length; i < posts.length; i++) heights.push(postHeight(posts[i], cw));   // once per post
  const f = ui.beginFeed("feed", x, y, w, h, posts.length, { heights, gap: 12, padTop: 4, padBottom: 12,
                                                              refreshing, loadingMore });
  for (let i = f.first; i <= f.last; i++) {   // 0-based in JavaScript
    const r = ui.feedItem(i);
    drawPost(posts[i], r.x + (r.w - cw) / 2, r.y, cw, r.h);
  }
  const ev = ui.endFeed();
  if (ev.refresh) refresh();
  if (ev.more) loadMore();
}

// ------------------------------------------------------------------ callbacks
app.load = () => {
  liked = store.get("liked", {});
  refresh();
};

app.update = (dt) => {
  if (toastT > 0) toastT -= dt;
};

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  if (viewer) {
    drawViewer(w, h);
  } else {
    gfx.color(theme.text);
    gfx.text(TR("title"), 16, 14, 22, "bold");
    if (sample || offline) {
      gfx.color(theme.text2);
      gfx.text(sample ? TR("sample") : TR("offline"), 16, 40, 12);
    }
    if (ui.iconButton("refresh", w - 52, 8, 40, 40, theme.text, false, "reload")) refresh();
    drawFeed(0, TOP, w, h - TOP);
    if (posts.length === 0 && !refreshing) {
      gfx.color(theme.text2);
      gfx.text(TR("empty"), 0, h / 2, 15, "sans", "center", w);
    }
  }
  if (toastT > 0 && toast) {
    const tw = Math.min(w - 40, gfx.textWidth(toast, 14) + 32);
    gfx.rect((w - tw) / 2, h - 56, tw, 36, 18, "#000000C0");
    gfx.color("#FFFFFF");
    gfx.text(toast, (w - tw) / 2, h - 47, 14, "sans", "center", tw);
  }
};

app.event = (e) => {
  if (viewer && e.type === "keydown" && e.key === "escape") closeClip();   // B on the controller is Escape
};

app.suspend = () => { if (viewer) media.pause(viewer.player); };

app.resume = () => {
  if (viewer) media.play(viewer.player);
  refresh();                               // no background code runs while the app sleeps: catch up now
};

app.close = () => {
  closeClip();
  return true;
};
```

Lua'dan farklar:

- Akış indeksleri **0'dan başlar**: `for (let i = f.first; i <= f.last; i++)`.
- `gfx.imageUrl` yüklenirken `null` döndürür (`gfx.imageState(url, size)`; `"loading"`, `"ready"` ya da `"error: ..."`
  der).
- `import sampleFeed from "./sample-feed.json"` çözülmüş JSON'u verir; dosya okumaya gerek yok.
- `net.request(options, callback)` isteğin id'sini döndürür; callback olmadan cevabın Promise'ini döndürür (o istek
  iptal edilemez).

## 7. Python ve C

İkisi de aynı fonksiyonları çağırır. Aşağıdaki programlar eksiksizdir (`py_check.py` ve `rt_check.py`'den geçer) ama
küçüktür: tek istek, akış, resimler, zengin metin, göreli zaman ve klip.

**Python** (`main.py`, `"main": "main.py"`). Seçenekler dict'tir; `net.request(options, callback)` `callback(res)`'i
çağırır; cevaplar kayıttır (`res.ok`, `res.get("data")`); akış indeksleri 0'dan başlar (`range(f.first, f.last + 1)`);
`gfx.imageUrl` yüklenirken `None` döndürür.

```python
FEED_URL = "https://example.com/moments/feed.json"


class Moments:
    def load(self, arg):
        self.posts = []
        self.refreshing = False
        self.player = None
        self.refresh()

    def refresh(self):
        self.refreshing = True
        net.request({"url": FEED_URL, "responseType": "json", "cache": 600, "retry": 2}, self.on_feed)

    def on_feed(self, res):
        data = res.get("data") if res.ok else None          # records read as attributes or keys
        if not isinstance(data, dict) or not isinstance(data.get("posts"), list):
            data = json.decode(fs.read("bundle:/sample-feed.json") or "{}") or {}
        self.posts = data.get("posts") or []
        self.refreshing = False

    def draw_post(self, p, x, y, w, h):
        key = str(p.get("id"))
        gfx.rect(x + 8, y, w - 16, h, 14, theme.window)
        gfx.color(theme.text)
        gfx.text(p.get("user", "?"), x + 20, y + 12, 15, "semibold")
        gfx.color(theme.text2)
        gfx.text(sys.relativeTime(p.get("time", sys.epoch())), x + 20, y + 31, 12)
        size = min(w - 40, 320)
        img = gfx.imageUrl(p["photo"], 640) if p.get("photo") else None   # None while it loads
        if img is not None:
            gfx.draw(img, x + 20, y + 56, size, size, 10)
        else:
            gfx.rect(x + 20, y + 56, size, size, 10, theme.control)
        if p.get("clip") and ui.hit("clip" + key, x + 20, y + 56, size, size).clicked:
            self.player = media.open(p["clip"], {"loop": True, "autoplay": True})
        gfx.color(theme.text)
        r = ui.richText("cap" + key, p.get("caption", ""), x + 20, y + 64 + size, w - 40, 15)
        if r.clicked is not None:
            print(r.clicked.type, r.clicked.value)

    def draw(self, w, h):
        gfx.clear(theme.bg)
        if self.player is not None:
            media.draw(self.player, 0, 0, w, h, "contain")
            if ui.iconButton("close", w - 56, 8, 44, 44, "#FFFFFF", False, "close"):
                media.close(self.player)
                self.player = None
            return
        f = ui.beginFeed("feed", 0, 0, w, h, len(self.posts),
                         {"itemHeight": 440, "gap": 12, "refreshing": self.refreshing})
        for i in range(f.first, f.last + 1):                  # 0-based
            r = ui.feedItem(i)
            self.draw_post(self.posts[i], r.x, r.y, r.w, r.h)
        ev = ui.endFeed()
        if ev.refresh:
            self.refresh()

    def suspend(self):
        if self.player is not None:
            media.pause(self.player)

    def close(self):
        if self.player is not None:
            media.close(self.player)
        return True


app = Moments()
```

**C** (`main.c`, `"runtime": "c"`). Seçenekler **JSON metnidir**; `net_fetch(options, fn, progress, user)`, gövdeyi
metin olarak (`res->body`, `res->bodyLen`) `fn(const nxv_response*, user)`'a verir; `nexvyn.h`'de JSON parser'ı yoktur,
cevabı gönderilere çevirmek sizin kodunuzdur (aşağıdaki program iki gönderiyi bir dizide tutar). Ağ başarısız
olduğu için cevap çevrimdışı önbellekten geldiyse `res->stale` true olur (önbellekten gelen her cevapta `res->fromCache`). `gfx_imageUrl(url,
size, &w, &h)` `gfx_draw` için bir yol ya da `NULL` döndürür; `ui_beginFeed` bir `nxv_feed` döndürür,
`ui_feedItem(i, &x, &y, &w, &h)` dikdörtgeni verir, `ui_endFeed()` yenileme için 1, "daha fazla yükle" için 2 döndürür
(ikisi birden olabilir); `ui_richText(..., &clicked)`, `clicked`'i `"link:..."`, `"mention:..."` ya da
`"hashtag:..."` yapar.

```c
#include <stdio.h>
#include <nexvyn.h>

#define MEDIA "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/SDK/Samples/lua/social-feed/source/media/"

typedef struct { const char *user, *photo, *clip, *caption; double time; } post;

/* nexvyn.h has no JSON parser: on_feed gets the answer as JSON text, turning it into posts is the app's code */
static post posts[] = {
    {"mira", MEDIA "photo01.jpg", NULL, "First light over the harbour. **Worth the early start.** #sunrise", 1762160400},
    {"deniz", MEDIA "photo02.jpg", MEDIA "clip1.mp4", "Ten seconds of rain on the window, with @mira #slowtv", 1762153200},
};
static int count = 2, player = 0;
static bool refreshing;

static void on_feed(const nxv_response* res, void* user) {
    refreshing = false;
    if (res->ok) printf("feed: %d bytes from %s\n", (int)res->bodyLen, res->url);
    else printf("feed failed: %s\n", res->error);
}

static void refresh(void) {
    refreshing = true;
    net_fetch("{\"url\": \"https://example.com/moments/feed.json\", \"cache\": 600, \"retry\": 2}", on_feed, NULL, NULL);
}

void app_load(const char* arg) { refresh(); }

static void draw_post(const post* p, int i, float x, float y, float w, float h) {
    gfx_rect(x + 8, y, w - 16, h, 14, theme_color("window"));
    gfx_color(theme_color("text"));
    gfx_text(p->user, x + 20, y + 12, 15, "semibold", NULL, 0);
    gfx_color(theme_color("text2"));
    gfx_text(sys_relativeTime(p->time), x + 20, y + 31, 12, NULL, NULL, 0);
    float size = w - 40 < 320 ? w - 40 : 320;
    int iw, ih;
    const char* img = gfx_imageUrl(p->photo, 640, &iw, &ih);   /* a path for gfx_draw, NULL while it loads */
    if (img) gfx_draw(img, x + 20, y + 56, size, size, 10, NULL);
    else gfx_rect(x + 20, y + 56, size, size, 10, theme_color("control"));
    if (p->clip && ui_hit(nxv_fmt("clip%d", i), x + 20, y + 56, size, size).clicked)
        player = media_open(p->clip, "{\"loop\": true, \"autoplay\": true}");
    const char* clicked = NULL;
    gfx_color(theme_color("text"));
    ui_richText(nxv_fmt("cap%d", i), p->caption, x + 20, y + 64 + size, w - 40, 15, NULL, &clicked);
    if (clicked) printf("tapped %s\n", clicked);               /* "link:...", "mention:...", "hashtag:..." */
}

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    if (player) {
        media_draw(player, 0, 0, w, h, "contain");
        if (ui_iconButton("close", w - 56, 8, 44, 44, "#FFFFFF", false, "close")) {
            media_close(player);
            player = 0;
        }
        return;
    }
    nxv_feed f = ui_beginFeed("feed", 0, 0, w, h, count,
                              refreshing ? "{\"itemHeight\": 440, \"refreshing\": true}" : "{\"itemHeight\": 440}");
    for (int i = f.first; i <= f.last; i++) {               /* 0-based */
        float x, y, iw, ih;
        ui_feedItem(i, &x, &y, &iw, &ih);
        draw_post(&posts[i], i, x, y, iw, ih);
    }
    if (ui_endFeed() & 1) refresh();                         /* 1: pulled to refresh, 2: near the end */
}

void app_suspend(void) { if (player) media_pause(player); }

bool app_close(void) {
    if (player) media_close(player);
    return true;
}
```

Squirrel ve Java SDK 1.8'de donduruldu ve bu çağrıların hiçbiri onlarda yok; Lua, JavaScript, Python ya da C kullanın.

## 8. Daha ileri

| İstediğiniz | Nerede |
|---|---|
| İlerleme çubuğuyla fotoğraf ya da video yükleme (`multipart`, `file`, `progress(now, total, "upload")`) | [MAKE_A_SOCIAL_APP.tr.md](MAKE_A_SOCIAL_APP.tr.md), bölüm 7 |
| Tarayıcı penceresinde oturum açma (`net.oauth`, PKCE) ve token'ı saklama | aynı rehber, bölüm 8 |
| WebSocket üzerinden sohbet ve canlı sayaçlar (`net.ws`, `net.wsPoll`) | aynı rehber, bölüm 9 |
| Kaydırarak sayfalanan tam ekran dikey klipler (`ui.pager`) | aynı rehber, bölüm 5; [social-feed](../Samples/lua/social-feed/) örneği |
| Fotoğraf ızgarası (`columns`, `aspect`) | aynı rehber, bölüm 3 |
| Hatırlatmalar ve bir gönderiyi açan bağlantılar (`sys.schedule`, `sys.appUrl`) | aynı rehber, bölüm 10 |

## 9. Denetleme ve yayın

1. `python SDK/Tools/nxv/nxv.py check Moments.nxvapp` (`--sdk <Nexvyn OS kaynak checkout'u>` ile dilin checker'ı da),
   sonra konsolda deneyin (`nxv push`, ya da `sdmc:/NexvynOS/Applications/`'a kopyalayın).
2. Çevrimdışı deneyin: uygulamayı bir kez çevrimiçi açın, sonra Wi-Fi olmadan. Açılmalı, cache'teki gönderileri
   göstermeli ve çevrimdışı olduğunu söylemeli.
3. Sırları konsoldan uzak tutun: pakette yazma yetkili API anahtarı ya da client secret olmaz (herkes bir `.nxvapp`'ı
   açabilir). Oturum açmadan gelen token'lar uygulamanın özel veri klasörü olan `store`'a gider.
4. Mağaza açıklamasında uygulamanın sunucunuza ne gönderdiğini yazın. İzinsiz izleme yok.
5. Mağaza ekran görüntüleri İngilizce arayüzle; yayın adımları: [Publishing/PUBLISHING.tr.md](../Publishing/PUBLISHING.tr.md).

## Ayrıca bakın

[SDK başvurusu](../Reference/SDK.tr.md) (bölüm 8d) · [Sosyal uygulama yapmak](MAKE_A_SOCIAL_APP.tr.md) ·
[AI destekli iş akışı](AI_WORKFLOW.tr.md) · [SDK sürümleri](SDK_VERSIONS.tr.md) ·
Örnek: [social-feed](../Samples/lua/social-feed/) · AI prompt'u: [sosyal uygulama yapmak](../AI/tasks/make-social-app.tr.md)
