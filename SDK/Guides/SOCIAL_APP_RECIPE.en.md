# Social app recipe: a photo and clip feed in one file (SDK 1.9)

**English** · [Türkçe](SOCIAL_APP_RECIPE.tr.md)

A complete small feed app, from `app.json` to the last callback: **Moments** loads posts from a JSON address, shows
them in a virtualized list with pull to refresh and "load more", downloads avatars and photos as thumbnails, formats
captions with links, mentions and hashtags, writes "5m" style times, plays a clip in a full-window viewer and keeps
working offline from the cache. The full program is here in Lua and in JavaScript; Python and C follow as shorter
programs with the calls that differ.

This page is the short recipe. The deep guide, with uploads, sign-in, WebSockets, the swipe pager for short videos,
notifications and a performance checklist, is [MAKE_A_SOCIAL_APP.en.md](MAKE_A_SOCIAL_APP.en.md); the larger sample
with a grid and a video pager is [social-feed](../Samples/lua/social-feed/). Every program on this page passed the SDK
checkers (`lua_check.py`, `js_check.mjs`, `py_check.py`, `rt_check.py`) exactly as printed; every function is in the
[SDK reference](../Reference/SDK.en.md), section 8d.

## Contents

1. [What you build](#1-what-you-build)
2. [The feed your server sends](#2-the-feed-your-server-sends)
3. [The bundle](#3-the-bundle)
4. [main.lua](#4-mainlua)
5. [How it works](#5-how-it-works)
6. [JavaScript](#6-javascript)
7. [Python and C](#7-python-and-c)
8. [Going further](#8-going-further)
9. [Check and publish](#9-check-and-publish)

## 1. What you build

| Part of the app | SDK 1.9 call |
|---|---|
| The feed as JSON, decoded off the main thread, retried, cached for 10 minutes and kept for offline use | `net.request{responseType = "json", retry, cache}` |
| A list that draws only the visible posts, pull to refresh, "load more" at the end | `ui.beginFeed` / `ui.feedItem` / `ui.endFeed` |
| Avatars (96 px) and photos (640 px) as thumbnails, a placeholder while they load | `gfx.imageUrl(url, maxSize)` |
| Captions with `**bold**`, links, `@mentions` and `#hashtags`, measured once per post | `ui.richText`, `ui.measureRichText` |
| "now", "5m", "3h", "2d" in the user's language | `sys.relativeTime` |
| A clip in a full-window viewer with mute, buffering spinner and progress | `media.open` / `media.draw` / `media.info` / `media.set` / `media.close` |
| Likes kept between runs | `store` |

The only permission is `"network"`. The app is an OS-style app: it uses `theme` colours and `ui` widgets, so it looks
right in light and dark mode.

## 2. The feed your server sends

```json
{
  "posts": [
    {"id": "p1", "user": "mira", "avatar": "https://.../mira.jpg", "time": 1762160400, "likes": 12,
     "photo": "https://.../p1.jpg", "clip": "https://.../p1.mp4", "caption": "Text with **bold**, @names and #tags"}
  ],
  "next": "https://.../feed.json?page=2"
}
```

`time` is a Unix time in seconds, `next` is the address of the next page or `null` at the end, and `avatar` and `clip`
are optional. Keep pages to 20-50 posts. Clips can be MP4, WebM, MKV or HLS (`.m3u8`). Point `FEED_URL` at your server.
Until you do (or when the first load fails with nothing in the cache), the app shows `sample-feed.json` from its bundle,
so it is never an empty screen.

## 3. The bundle

```
Moments.nxvapp/
├── app.json
├── main.lua
├── icon.png              256 x 256, a picture of your app
├── sample-feed.json      shown until FEED_URL answers
└── lang/en.json          English is required; add lang/<code>.json for more languages
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

`sample-feed.json` (the pictures and the clip are CC0 media of the public Social Feed sample):

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

## 5. How it works

**One request does the network work.** `responseType = "json"` decodes the answer on a worker thread (`res.data`).
`retry = 2` tries again on no answer, 408, 429 or 5xx with a backoff. `cache = 600` answers from the disk cache for 10
minutes, revalidates with `ETag` / `Last-Modified` after that, and when the network fails returns the last good answer
with `res.stale = true`: the app then says it is offline and still shows the posts.

**Load more.** `ev.more` comes once per list length when the last posts are on screen. The app loads `next` and sets
`loadingMore` meanwhile, which shows the spinner at the end and stops further `more` events.

**Heights are measured once.** Posts have different heights because captions differ, so the feed gets a `heights`
list. Each post is measured once with `ui.measureRichText` when it arrives, and the list is measured again only when
the column width changes.

**Pictures at the drawn size.** `gfx.imageUrl(url, 96)` for avatars and `640` for photos stores thumbnails on the SD
card, not originals; a picture that scrolls away before it arrives is skipped. Until it is ready the call returns
`nil` and the app draws a placeholder.

**Taps in captions.** `ui.richText` returns `clicked` on the frame a link, mention or hashtag was tapped. Moments shows
it in a toast; a real app opens a profile or a search. Opening a link in the Browser with `sys.launch("browser", url)`
needs the `"launch"` permission.

**The clip viewer.** `media.open(url, {loop = true, autoplay = true})` starts a player; `media.draw` draws its current
frame every frame. While the viewer is open the feed is not drawn, so its widgets cannot take the taps. `media.info`
gives the state for the spinner (`"opening"`, `buffering`), the error text (`"failed"`) and the progress line. Closing
the viewer closes the player: at most 3 players per app.

**Lifecycle.** `app.suspend` pauses the clip (HOME menu, sleep), `app.resume` plays it again and refreshes the feed
(there is no background feed check, so the app catches up when it comes back), and `app.close` closes the player.

## 6. JavaScript

The same app in `main.js`. Set `"main": "main.js"` in `app.json`; `lang/en.json` and `sample-feed.json` are the same
files.

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

What differs from Lua:

- Feed indexes are **0-based**: `for (let i = f.first; i <= f.last; i++)`.
- `gfx.imageUrl` returns `null` while loading (`gfx.imageState(url, size)` tells `"loading"`, `"ready"` or
  `"error: ..."`).
- `import sampleFeed from "./sample-feed.json"` gives the parsed JSON; no file reading needed.
- `net.request(options, callback)` returns the request id; without a callback it returns a Promise of the response
  (which cannot be cancelled).

## 7. Python and C

Both call the same functions. The programs below are complete (they pass `py_check.py` and `rt_check.py`) but small:
one request, the feed, pictures, rich text, relative time and the clip.

**Python** (`main.py`, `"main": "main.py"`). Options are dicts; `net.request(options, callback)` calls
`callback(res)`; responses are records (`res.ok`, `res.get("data")`); feed indexes are 0-based
(`range(f.first, f.last + 1)`); `gfx.imageUrl` returns `None` while loading.

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

**C** (`main.c`, `"runtime": "c"`). Options are **JSON text**; `net_fetch(options, fn, progress, user)` calls
`fn(const nxv_response*, user)` with the body as text (`res->body`, `res->bodyLen`); `nexvyn.h` has no JSON parser, so
turning the answer into posts is your code (the program below keeps two posts in an array). `res->stale` is true
when the answer came from the offline cache because the network failed (`res->fromCache` for any cached answer). `gfx_imageUrl(url, size,
&w, &h)` returns a path for `gfx_draw` or `NULL`; `ui_beginFeed` returns an `nxv_feed`, `ui_feedItem(i, &x, &y, &w,
&h)` gives the rectangle, `ui_endFeed()` returns 1 for a refresh and 2 for "load more" (both bits can be set);
`ui_richText(..., &clicked)` sets `clicked` to `"link:..."`, `"mention:..."` or `"hashtag:..."`.

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

Squirrel and Java are frozen at SDK 1.8 and have none of these calls; use Lua, JavaScript, Python or C.

## 8. Going further

| You want | Where |
|---|---|
| Upload a photo or a video with a progress bar (`multipart`, `file`, `progress(now, total, "upload")`) | [MAKE_A_SOCIAL_APP.en.md](MAKE_A_SOCIAL_APP.en.md), section 7 |
| Sign in in a Browser window (`net.oauth`, PKCE) and keep the token | same guide, section 8 |
| Chat and live counters over a WebSocket (`net.ws`, `net.wsPoll`) | same guide, section 9 |
| Full-screen vertical clips with swipe paging (`ui.pager`) | same guide, section 5; the [social-feed](../Samples/lua/social-feed/) sample |
| A photo grid (`columns`, `aspect`) | same guide, section 3 |
| Reminders and links that open a post (`sys.schedule`, `sys.appUrl`) | same guide, section 10 |

## 9. Check and publish

1. `python SDK/Tools/nxv/nxv.py check Moments.nxvapp` (with `--sdk <Nexvyn OS source checkout>` also the language
   checker), then try it on the console (`nxv push`, or copy it to `sdmc:/NexvynOS/Applications/`).
2. Test offline: start the app once online, then without Wi-Fi. It must open, show the cached posts and say it is
   offline.
3. Keep secrets off the console: no API keys with write access, no client secrets in the bundle (anyone can unzip a
   `.nxvapp`). Tokens from a sign-in go to `store`, which is the app's private data folder.
4. In the store description, say what the app sends to your server. No tracking without consent.
5. Store screenshots with the English interface; publishing steps: [Publishing/PUBLISHING.en.md](../Publishing/PUBLISHING.en.md).

## See also

[SDK reference](../Reference/SDK.en.md) (section 8d) · [Make a social app](MAKE_A_SOCIAL_APP.en.md) ·
[AI-assisted workflow](AI_WORKFLOW.en.md) · [SDK versions](SDK_VERSIONS.en.md) ·
Sample: [social-feed](../Samples/lua/social-feed/) · AI prompt: [make a social app](../AI/tasks/make-social-app.en.md)
