# Make a social app

**English** · [Türkçe](MAKE_A_SOCIAL_APP.tr.md)

How to build a photo feed, a short video app or a chat on Nexvyn OS with the SDK 1.9 functions (reference:
`sdk/SDK.en.md` section 8d). Everything here works in Lua, JavaScript, Python and C; the examples are Lua with the
JavaScript spelling where it differs. A complete app that uses all of it is the **Social Feed** sample
(`SDK/Samples/lua/social-feed`).

## 1. Before you start

- **app.json:** `"minSdk": "1.9"`, `"permissions": ["network"]` (add `"notifications"` for reminders, `"launch"` if
  you open other apps or the Browser). Ask for nothing else.
- **Your server is yours.** The console talks to it over HTTPS like any client: JSON APIs, signed upload URLs,
  WebSockets. Keep secrets (client secrets, API keys with write access) on the server, never in the bundle: anyone can
  unzip a `.nxvapp`.
- **Design for a window.** Apps open maximized but users resize them; lay out from `w, h` of `app.draw` and keep a
  readable column (about 560 px) on wide screens.
- **Every call is asynchronous.** Nothing blocks the frame; results come back in callbacks. A callback that runs longer
  than 3 seconds is stopped, so parse big JSON on the server side or page it.

## 2. The feed: data

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
    if res.stale then toast(TR("offline")) end  -- the cached first page while offline
    done()
  end)
end
```

- `responseType = "json"` decodes on a worker thread and gives `res.data`.
- `cache = 300` keeps the first page on the SD card: the app opens instantly and still shows posts offline
  (`res.stale = true`). The cache revalidates with `ETag` / `Last-Modified`, so an unchanged feed costs a 304.
- `retry = 2` survives a dropped Wi-Fi link (backoff 0.5 s, 1 s, plus jitter; `Retry-After` is honoured).
- JavaScript: `net.request({...}, (res) => {...})` returns the id; without a callback it returns a Promise.

## 3. The feed: drawing

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

- Only items `first..last` are drawn: a feed of thousands of posts costs what one screen costs.
- **Heights.** Posts of different sizes need `heights` (one number per post). Measure once when a post arrives (and
  again when the width changes): header + photo height + `ui.measureRichText(caption, w - 24, 15)` + actions.
- **Grid.** `columns = 3, gap = 2` makes a photo grid with square cells (`aspect` for other shapes).
- **Pull to refresh** is reported once when the user lets go; show `refreshing = true` until your request ends.
- **Infinite scroll:** `more` comes once per list length; set `loadingMore` while loading so it does not repeat.

## 4. Pictures

```lua
local img = gfx.imageUrl(post.photoUrl, 640)     -- nil while loading
if img then gfx.draw(img, x, y, w, w, 10) else gfx.rect(x, y, w, w, 10, theme.control) end
```

- Call it every frame, like `gfx.image`. The download, decoding and scaling run in the background; pictures that
  scroll away before they arrive are skipped.
- **Ask for the size you draw.** `maxSize = 640` for a full-width photo, `256` for grid cells, `96` for avatars: the
  thumbnail is stored on the SD card, so the next start loads a small file instead of a 4000 px original.
- 96 MB of pictures per app stay on the SD card (the oldest downloads go first); `net.clearCache()` empties it.
- JavaScript / Python: `gfx.imageUrl` returns `null` / `None` while loading; `gfx.imageState(url, size)` tells
  `"loading"`, `"ready"` or `"error: ..."` (show a retry icon on errors).

## 5. Short videos

```lua
local pg = ui.pager("reels", 0, 0, w, h, #clips)
for i = math.max(1, math.floor(pg.pos)), math.min(#clips, math.floor(pg.pos) + 1) do
  media.draw(player(i), 0, (i - pg.pos) * h, w, h, "cover")
end
if pg.changed then keepOnly(pg.page, pg.page + 1); media.play(player(pg.page)) end
```

- `ui.pager` does the swipe: one page per fling, rubber band at the ends, D-pad and wheel too. Draw page `i` at
  `(i - pos) * h`.
- `media.open(url, {loop = true, autoplay = false})` streams MP4 or HLS (`.m3u8`) with the console's video decoder.
  At most 3 players per app: keep the current and the next clip open (the next one starts instantly), close the rest.
- Show a spinner while `media.info(p).buffering` or `state == "opening"`; on `"failed"` show `info.error` and a
  retry button.
- Pause in `app.suspend` and when the user leaves the tab; resume in `app.resume`.
- Sound only (podcasts, voice notes): `media.open(url, {audioOnly = true})`.

## 6. Captions and comments

```lua
local r = ui.richText("c" .. post.id, post.caption, x, y, w, 15)
if r.clicked and r.clicked.type == "hashtag" then openTag(r.clicked.value) end
gfx.text(sys.relativeTime(post.createdAt), x, y + r.height + 4, 12)
```

`**bold**`, links, `@mentions` and `#hashtags` are found for you; the tap tells you which. `maxLines = 3` cuts long
captions with "…" (show the whole text on a tap). `sys.relativeTime` writes "5m", "3h", "2d" in the user's language.

## 7. Posting: uploads

```lua
net.request({url = API .. "/posts", method = "POST", headers = auth(), responseType = "json",
  multipart = {{name = "caption", value = caption}, {name = "photo", file = path, type = "image/jpeg"}}},
  function(res) if res.ok then addPost(res.data) else toast(res.error) end end,
  function(now, total, phase) if phase == "upload" then progress = now / total end end)
```

- Files are streamed from the SD card, never loaded whole: a 200 MB video upload uses almost no memory.
- For storage services that hand out signed upload URLs: `net.request({url = signedUrl, file = path,
  contentType = "video/mp4"}, ...)` (a `PUT` of the raw file).
- The file must be readable by the app: its data folder, or a file the user picked with `ui.openFile` (the picker
  grants access), or the `"files"` permission.
- Do not retry a POST automatically unless your server deduplicates it (send an idempotency key header).

## 8. Signing in

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

- The sign-in page opens in the console's web browser, so passwords never pass through your app. `state` is checked
  for you; use `pkce = true` (public clients must).
- Register `http://localhost/callback` (or `nxv://app/<your id>/callback`) as the redirect address at your provider.
- The browser needs a real console with Nexvyn OS started as an application. Elsewhere `err` explains why; offer a
  **device code** login then: your server shows a short code, the user enters it on a phone, the app polls your
  server with `net.request` every few seconds.
- Keep the access token with `store.set` (the app's private data folder) and refresh it before it expires. Session
  cookies work too: `cookies = true` on every request uses the app's own cookie jar.

## 9. Real time: chat and live counters

```lua
sock = net.ws(WS_URL, {headers = auth()})
function app.update(dt)
  for _, ev in ipairs(net.wsPoll(sock)) do
    if ev.type == "message" then onMessage(json.decode(ev.data))
    elseif ev.type == "close" then timer.after(backoff(), connect) end
  end
end
```

- Poll every frame: events queue up between frames (a socket closes itself when 16 MB stay unread).
- Reconnect with a growing delay after a `close` (1, 2, 4 ... 30 s) and after `app.resume` (sockets end while the
  console sleeps).
- At most 4 sockets per app; one is usually enough (multiplex channels on your server).

## 10. Notifications and links

- **Reminders and digests:** `sys.schedule(epoch, title, body, "inbox")` posts a notification while the app is closed;
  tapping it starts the app with `arg = "inbox"`. There is no background code: fetch new items when the app opens and
  in `app.resume`.
- **Sharing:** `sys.share(text)` opens the share sheet (copy, other apps). Put a link to the post in it:
  `sys.appUrl(sys.appid(), "post:" .. id)` opens your app at that post (`app.load(arg)` / `app.open(arg)`).

## 11. Performance and memory checklist

- Thumbnails at the drawn size (`maxSize`), never full originals in a list.
- Heights measured once per post, not every frame.
- At most two video players open; close players and sockets you no longer need.
- Pages of 20–50 items; long JSON parsed with `responseType = "json"` (off the main thread).
- `sys.memory()` stays well under 64 MB for scripts; pictures and video live outside the script heap.
- Test offline (airplane mode): the app opens, shows the cached feed and says it is offline.

## 12. Porting from other platforms

| Idea elsewhere | Nexvyn OS |
|---|---|
| list view with cell reuse | `ui.beginFeed` (only visible items are drawn; nothing to recycle by hand) |
| image loading library with a disk cache | `gfx.imageUrl(url, maxSize)` |
| video view / player | `media.open` + `media.draw` |
| page view controller, vertical paging | `ui.pager` |
| attributed text with tappable links | `ui.richText` |
| HTTP client with interceptors | a small function that adds headers and calls `net.request` |
| WebSocket class with callbacks | `net.ws` + `net.wsPoll` in `app.update` |
| sign-in with a system browser session | `net.oauth` |
| push notifications | not available: `sys.schedule` for local reminders, refresh on open / resume |

## 13. Before you publish

- Store screenshots in English (5 recommended): add a `"shots"` script to `store.json` (Publishing guide, section 6).
- `python SDK/Tools/nxv/nxv.py check <bundle> --sdk <source checkout>` must pass; the language checkers know the SDK
  1.9 functions.
- Describe what your app sends to your server in the store description. No tracking without consent.
