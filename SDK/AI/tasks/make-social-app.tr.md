# Görev: sosyal uygulama yapmak (akış, fotoğraf, kısa video, sohbet)

[English](make-social-app.en.md) · **Türkçe**

Bağlam paketinden sonra gönderin (`system-prompt.tr.md` + dil paketi). Başka bir platformdan uygulama mı
taşıyorsunuz? Ekranlarını ve API açıklamasını "App" altına yapıştırın. Prompt'un kendisi İngilizcedir (AI yine sizin
dilinizde yanıt verir).

```text
Write a complete Nexvyn OS app for a feed, photo, short-video or chat service, on SDK 1.9.

App: <what it shows, the 3-5 screens (feed, profile, post detail, upload, clips, chat...)>
Language: <Lua | JavaScript | Python | C>
App id: com.<yourname>.<app>   Name: <name>
Languages of the app: English<, plus any others>
Server API: <base URL, endpoints with request / response JSON, how sign-in works (OAuth with PKCE, device code,
            token header), WebSocket URL if any>

Requirements:
- app.json: "minSdk": "1.9", "targetSdk": "1.9", ONLY the permissions the code uses ("network"; "notifications" for
  sys.schedule; "launch" for sys.launch / sys.appUrl links). No secrets in the bundle.
- Data with net.request: responseType = "json", retry = 2 for GETs, cache = 300 for the first feed page (show
  "offline" when res.stale), headers from one auth() helper, every error shown in a small toast. Uploads with
  multipart (files streamed) and an upload progress bar from progress(now, total, "upload").
- Lists with ui.beginFeed / ui.feedItem / ui.endFeed: heights measured once per post (ui.measureRichText for
  captions), pull-to-refresh (refreshing) and infinite scroll (more + loadingMore), grids with columns.
- Pictures with gfx.imageUrl(url, maxSize) at the drawn size (avatars 96, grid 256, full width 640) and a placeholder
  while loading.
- Clips with ui.pager + media.open / media.draw: only the current and the next player open, pause in app.suspend and
  when leaving the screen, a spinner while buffering, an error with a retry button when a player fails.
- Captions and comments with ui.richText (handle clicked: mention -> profile, hashtag -> search, link -> show it);
  times with sys.relativeTime.
- Sign-in with net.oauth (pkce = true, redirect http://localhost/callback) and a device-code fallback when it reports
  an error; tokens in store.
- Real time (if the service has it): net.ws + net.wsPoll in app.update, reconnect with backoff and after app.resume.
- Links into the app: sys.appUrl(sys.appid(), "post:<id>") in sys.share texts, handled in app.load / app.open.
- Layout from the window size, a readable column on wide screens, theme colors, touch + cursor + keyboard.
- Every visible text through TR() with lang/en.json (+ the other languages).
- Keep app.draw cheap: no file reads or JSON parsing per frame.

Deliver every file in full, a short description of what the app sends to the server (for the store description),
then how to check it on a PC and run it on the console, and any assumption you made.
```
