# Nexvyn OS app SDK 2.0 (1.13) & Native SDK 1.2: context pack for AI assistants

You write apps for **Nexvyn OS**, a desktop shell that runs as Switch homebrew (Atmosphère). Apps are `.nxvapp` bundles that run in
a window of the shell. Use ONLY the API listed here (it is a condensed copy of `SDK/Reference/SDK.md`, the complete
contract). If something is not listed, it does not exist: say so and build it from what exists. Never invent
functions, modules, fields or app.json keys. When the user gives you SDK.md, it wins over this summary. Always answer
in the language the user writes in; code names, app.json keys and file names stay as they are. The app's own texts are
English (required) plus any languages the user asks for. Making a game: follow `SDK/Guides/MAKE_A_GAME.md`,
meet the quality bar of rule 13 and use the kits (`sfx` for sound, `juice` for graphics, UI and feel).

## 1. Bundle

```
MyApp.nxvapp/            folder name ends with .nxvapp (or the folder's contents zipped into MyApp.nxvapp)
  app.json               manifest (required)
  main.lua | main.js | main.py | main.nut | main.c | app.jar (+ src/**/*.java)
  icon.png               256x256 PNG (games and store apps: key art, rule 12)
  lang/en.json           required: {"key": "Text with {0}"}
  lang/<code>.json       optional, one per extra language (de, es, fr, ja, ko, tr, zh)
  models/*.glb           3D models (SDK 1.8; PBR maps drawn by the pbr renderer, SDK 1.9)
  any other files        images, sounds, modules
```

Installed at `sdmc:/NexvynOS/Applications/`. Logs: `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.

### app.json

```json
{
  "id": "com.yourname.myapp",
  "name": {"en": "My App"},
  "description": {"en": "One short sentence"},
  "version": "1.0", "author": "Name", "homepage": "https://github.com/name",
  "category": "utilities",
  "icon": "icon.png",
  "runtime": "lua", "main": "main.lua",
  "minSdk": "1.12", "targetSdk": "2.0",
  "window": {"width": 640, "height": 480, "minWidth": 320, "minHeight": 240, "resizable": true},
  "singleInstance": true, "gamepad": false, "loadingHint": false,
  "fileTypes": [".txt"], "shareTargets": ["text", "url", ".txt"],
  "permissions": []
}
```

- `name` / `description`: a string or a language map; `"en"` is required, other languages are optional.
- `category`: system, productivity, utilities, media, internet, games, developer, other.
- **4 Official Primary Runtimes (`runtime`):**
  1. `"lua"` (default, Lua 5.4.7 with Generational GC)
  2. `"js"` (QuickJS-ng 0.17.0 ES2023)
  3. `"python3"` (or `"python"` with `"targetSdk": "2.0"`, CPython 3.12.16)
  4. `"native"` (devkitA64 GCC AOT `.nxvmod` / `.nro`, `"minNative": "1.2"`, `"minSdk": "1.10"`)
  *(Compatibility runtimes: `"python"` with `targetSdk < 2.0` uses PocketPy; `"c"` uses TinyCC; `"squirrel"` and `"java"` are frozen at SDK 1.8).*
- Minimum `minSdk`: Lua 1.0 (1.2 with `nexvyn.game`), JS 1.1, Python 1.3, Squirrel/C/Java 1.5. Any 1.4 feature
  (share, schedule, permissions API, lifecycle callbacks) needs "1.4"; `fs.unzip`, `sys.games`, `sys.speak`, the
  "python3" runtime "1.6"; `g3d.voxels` (JS) "1.7"; `g3d.model`, `g3d.loadModel`, `g3d.drawMatrix` "1.8"; the pbr renderer (`g3d.renderer`,
  `g3d.rendererInfo`, `g3d.addLight`, `g3d.shadows`, `g3d.postfx`, `g3d.environment`, `g3d.material`,
  `g3d.drawInstanced`, `g3d.caps`), the section 7 SDK 1.9 network calls and the feed / media calls "1.9" (Lua,
  JavaScript, Python, C only), the folder picker, kept-folder and save-backup calls "1.11" (same four), `ui.tokens` / `audio.stopAll` "1.12" (same four), `nxui.*` Retained UI and `loadingHint` "1.13" / "2.0". Use the lowest `minSdk` that has every call the app makes.
- `targetSdk`: the SDK the app was tested on; new N2 apps use `"2.0"` (or `"1.13"`). `loadingHint: true` extends the initial loading watchdog threshold from 5 s to 120 s.
- `window.width/height` is the content size. `gamepad: true` sends the controller to the app (L+R gives the cursor
  back); games set `"gamepad": true, "resizable": true`.
- `shareTargets`: "text", "url", "file", "image" or an extension; the item arrives as `arg` in load/open.

### Permissions (ENFORCED, SDK 1.4)

| Permission | Gates | Without it |
|---|---|---|
| network | `net.*` | callbacks get `error = "permission denied: network"` |
| files | paths outside the app's bundle/data/cache folders | `fs.read` → nil, `fs.write` → false |
| launch | `sys.launch(otherId)`, `sys.open("nxv://...")` | nil (JS/Python false) |
| notifications | `sys.notify`, `sys.schedule` | nil (JS/Python false) |
| games | `sys.games` (SDK 1.6) | the call fails (nil; JS null, Python None) |

Declare exactly what the code uses; `[]` when nothing. Files picked via `ui.openFile`/`ui.saveFile`, opened with or
shared to the app need no permission, and neither does `sys.clipboard`. The user decides once per app at install time
(the install sheet lists the permissions; Install allows them, Customize turns single ones off); only an app with no
stored answer is asked once at first launch, and `sys.requestPermission` is the only prompt at run time. The App
Store build refuses a bundle that calls a gated function without the permission.

## 2. Program structure (Lua shown; other languages in section 9)

```lua
local app = {}
function app.load(arg) end        -- once; arg = file path / URL / "" the app was opened with
function app.open(arg) end        -- asked to open something else while running
function app.update(dt) end       -- every frame (~60 fps)
function app.draw(w, h)           -- every frame: draw AND handle widgets; w,h = content size
  gfx.clear(theme.bg)
end
function app.event(e) end         -- raw input
function app.menu() return { {title = TR("file"), items = { {label = TR("new"), id = 1, shortcut = "Ctrl+N"}, "-" }} } end
function app.onmenu(id) end
function app.close() return true end   -- false keeps the window open
-- SDK 1.4: app.search(query) -> {{title, subtitle, icon, arg}}, app.suspend(), app.resume(), app.focus(focused),
--          app.autosave(), app.unsaved() -> bool
return app
```

Coordinates: pixels, (0,0) top-left of the content, y down. Angles: radians, 0 = right, clockwise. Colors: "#RRGGBB",
"#RRGGBBAA", `{r,g,b[,a]}` (0-255) or numbers where noted.

## 3. Hard rules

1. **3 seconds / 10 seconds:** a callback that runs longer than 3 s is stopped; the main file's top level and
   `app.load` get 10 s. With `"targetSdk": "1.8"` or newer the app then ends with the error screen; older apps get a
   "not responding" question (Wait / Close). Load models with `g3d.loadModel` (background thread), split long work
   across frames, timers or a coroutine resumed a few ms per frame. C has no such guard (after 12 s the user gets
   Force Quit / Wait): every C loop must be bounded.
2. **64 MB** script memory per window; `sys.memory()` → used, limit.
3. **60 fps:** `app.draw` runs every frame. Never load images, read files, build large tables/strings or call `net`
   in draw. Load images once in `load` (`gfx.image` caches), precompute, reuse. Create `g3d` meshes once.
4. **Immediate-mode UI:** call widgets every frame inside `draw`; ids/labels must be unique per window (`"Del##3"`).
5. **All visible text through `TR("key", ...)`** with every key in `lang/en.json` (required). Add `lang/<code>.json`
   for each other language the user wants; missing keys fall back to English. `{0}`, `{1}` are replaced by the extra
   arguments. System keys like `TR("common.ok")` exist.
6. **Apps: use `theme` colors** so light and dark mode work. Touch targets ≥ 28 px tall; 16-20 px margins; 13-15 px
   body text. Games do not: see rule 11.
7. **Save immediately** with `store.set` / `fs.write`; `store` is flushed on suspend/autosave too.
8. **Check `sys.online()`** before network work and show a friendly offline message.
9. No `io`, `os.execute`, `debug`, `package`, `dofile`, `loadfile` in Lua; no browser/Node API in JS; no `open()`/`os`
   in Python. Use `fs`, `store`, `net`.
10. Games: support D-pad/stick + A/B, keyboard and touch where possible, show the controls, pause on + and in
    `suspend` / `focus(false)`.
11. **Games get their own art direction.** Before writing menus, decide and write down (as a comment): the feeling,
    a palette (not `theme.*`), typography (system font styles, spacing, a logo image or bitmap font), camera
    language, motion style, sound palette and UI shape language. Draw the title, HUD and pause screens yourself with
    `gfx` / `g3d`; never build game UI from `ui.*` widgets (they are the OS's look) and never copy a sample's or
    another game's menu layout, colours or title composition. Two games must not look alike.
12. **Store icon = key art.** A game's (or store app's) `icon.png` is 256x256 key art of the game itself: its hero,
    world and lighting, readable at 64 px, subject inside the central 80 %. Never a flat placeholder glyph on a
    gradient. The style is the maker's choice: ask for it (or follow what the maker said); when nothing is said, make
    it clean: a polished picture of the game's own subject, restrained glow, no text, no extra effects. Make it with
    the icon tool (`SDK/Tools/icon`: `hero_render.py` renders the game's own model, `finish_icon.py` builds the key
    art and sizes; `--style clean|bold|loud`, `--title` only when wanted) or an image generator
    (`SDK/AI/tasks/store-icon.md` has the prompt).
13. **Games meet the quality bar** (`SDK/Guides/GAME_FEEL.md` section 8, `SDK/Guides/SOUND_DESIGN.md`):
    - every player and menu action has audio and visual feedback on the same frame (particles, flash, shake or
      hit-stop scaled to the event, a layered sound);
    - sound: layered effects with 3-4 variants each, no raw unfiltered square or saw at full volume, music plus an
      ambience bed, mixed levels (music under the effects, ducked on big moments), volume settings;
    - colour: a palette of 4-6 colours with roles; no flat single-colour backgrounds (gradients, glow, vignette,
      texture, parallax, light);
    - type: a type scale of 3-4 sizes; the title is a styled logo (outline, shadow, two tones, glow, spacing, or an
      image), never default text at default size;
    - UI: one shape language; panels with depth (shadow, slab, highlight); buttons with hover, press, focus and
      disabled states; transitions between screens; something alive on the title screen;
    - camera: smoothed follow; in 3D, fog in the sky colour and a coloured key light.
    Use the kits instead of writing these from scratch: copy `SDK/Languages/<lua|javascript>/kits/sfx.*` and
    `juice.*` into the bundle (`require("sfx")`, `require("juice")`; JS `import sfx from "./sfx.js"`). Their API is in
    section 7a. Other languages: build the same blocks from the SDK calls.
14. **Themes are original.** When asked for a theme pack (`.nxvtheme`, see `SDK/Guides/THEMES.md` and `SDK/AI/tasks/make-theme.md`), build it in the requested style with your own wallpapers, icons and sounds. Never copy or imitate another product's logos, icons, wallpapers, startup sounds or names; use generic names, a reverse-domain `id`, and palette pairs with WCAG AA contrast (4.5:1 for text). Only the documented `theme.json` fields and `settings` keys exist.

## 4. gfx (drawing)

`gfx.color(c)` / `gfx.color(r,g,b[,a])` · `gfx.clear([c])` · `gfx.rect(x,y,w,h[,radius[,c]])` ·
`gfx.rectLine(x,y,w,h[,radius[,thickness]])` · `gfx.circle(x,y,r[,c])` · `gfx.circleLine(x,y,r[,t])` ·
`gfx.line(x1,y1,x2,y2[,t])` · `gfx.lines({x1,y1,...}[,t[,closed]])` · `gfx.poly({x1,y1,...}[,c])` (convex) ·
`gfx.arc(x,y,r,a0,a1[,t])` · `gfx.pie(x,y,r,a0,a1)` · `gfx.gradient(x,y,w,h,c1,c2[,horizontal[,radius]])` ·
`gfx.shadow(x,y,w,h[,radius[,blur[,dy]]])` (before the shape) ·
`gfx.text(s,x,y[,size[,font[,align,width]]])` → width (y = top; fonts "sans","medium","semibold","bold","italic",
"mono","monobold"; align "left"/"center"/"right" within width) · `gfx.textWidth(s[,size[,font]])` ·
`gfx.textHeight([size[,font]])` · `gfx.wrap(s,x,y,w[,size[,font[,align[,lineSpacing]]]])` → height ·
`gfx.measureWrap(s,w[,size[,font]])` · `gfx.icon(name,cx,cy[,size[,c]])` (Material Icons Round names: "favorite",
"play_arrow", "settings", "delete", "star", "refresh"...) · `gfx.image(path)` → img {width,height} or nil
("bundle:/img/x.png" for bundle files; relative = data folder) · `gfx.draw(img,x,y[,w,h[,radius[,tint]]])` ·
`gfx.drawRegion(img,sx,sy,sw,sh,x,y,w,h[,angleDeg])` · `gfx.push(dx,dy)`/`gfx.pop()` · `gfx.clip(x,y,w,h)`/`gfx.unclip()`
· `gfx.alpha(a)`/`gfx.unalpha()` · `gfx.size()` → w,h.

`theme`: `dark` (bool), `bg`, `window`, `sidebar`, `text`, `text2`, `text3`, `separator`, `control`, `field`,
`selection`, `hover`, `accent`, `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `gray`.

## 5. ui (widgets, immediate mode, inside draw)

`ui.button(label,x,y,w,h[,style[,icon[,enabled]]])` → clicked (style "default","primary","destructive","plain",
"toolbar","link") · `ui.iconButton(icon,x,y,w,h[,tint[,active[,idSuffix]]])` · `ui.toggle(id,value,x,y[,w,h])` → bool ·
`ui.checkbox(label,value,x,y)` → bool · `ui.radio(label,selected,x,y)` → clicked ·
`ui.slider(id,value,min,max,x,y,w[,step])` → number · `ui.textfield(id,text,x,y,w[,h[,placeholder[,flags]]])` →
newText, submitted (flags "search","password","numeric","readonly") · `ui.segmented(id,{items},selected,x,y,w[,h])` ·
`ui.dropdown(id,{items},selected,x,y,w[,h])` (Lua 1-based) · `ui.label(text,x,y[,size[,color[,font]]])` ·
`ui.progress(value,x,y,w[,h])` (0..1, -1 indeterminate) · `ui.spinner(x,y[,radius])` ·
`ui.row(id,x,y,w,h,selected)` → clicked, doubleClicked · `ui.group(x,y,w,h)` · `ui.separator(x1,y,x2)` ·
`ui.beginScroll(id,x,y,w,h,contentHeight[,contentWidth])` → scrollY, scrollX … `ui.endScroll()` (children in content
coordinates) · `ui.hit(id,x,y,w,h)` → {hovered,held,pressed,clicked,rightClicked,doubleClicked,dx,dy} ·
`ui.mouse()` → x,y,down,hovering · `ui.focus(id)` · `ui.contextMenu({{label,id,icon},"-"}, fn(id))` ·
`ui.alert(title,msg,{"OK","Cancel"},fn(index))` · `ui.prompt(title,msg,default,fn(textOrNil))` ·
`ui.openFile(fn(pathOrNil),{".txt"}[,title])` · `ui.saveFile(fn(pathOrNil),"name.txt"[,title])` ·
`ui.keyboard(initial,fn(textOrNil)[,guide])`.
SDK 1.11 (`"minSdk": "1.11"`; Lua, JavaScript, Python, C): `ui.chooseFolder({title, remember}, fn(pathOrNil, err))` (a cancel gives nil, nil; `remember = true` keeps the folder across runs) · `fs.folderGrants()` · `fs.folderGranted(path)` · `fs.revokeFolder(path)` · `fs.savePath()` · `fs.saveBackup(slot, fn(ok, err))` · `fs.saveRestore(slot, fn)` · `fs.saveDeleteBackup(slot, fn)` · `fs.saveBackups()`. No permission needed: the user picks the folder. Slot names are 1-48 characters of `A-Z a-z 0-9 . _ -`.

SDK 1.12 (`"minSdk": "1.12"`; Lua, JavaScript, Python, C): `ui.tokens()` (C: `ui_tokens()`, a JSON text) returns the system look as one table: `dark`, `highContrast`, `boldText`, `textScale`, `colors` (hex strings: `accent`, `windowBg`, `contentBg`, `text`, `textSecondary`, `separator`, `error`, `success`, ...), `cornerRadius`, `spacing`, `controlHeight`, `fontSmall`, `fontBody`, `fontLarge`, `fontTitle` (apps may read it; games keep their own look, rule 11). `audio.stopAll()` stops every sound the app started (not its music). C also has `input_action(name)`.

## 5a. nxui (Retained & Semantic UI Engine, SDK 1.13 / 2.0)

Available in Lua, JavaScript, Python (`nxui.*`) and Native C/C++ (`nxn_nxui_*` in `<nexvyn/nxn_nxui.h>`). Prefer `nxui` for structured desktop apps, utilities, settings, tables and forms (no manual pixel math needed):
- Frame: `nxui.begin([w, h])` ... `nxui.endFrame()` · `nxui.tokens()` → `{space1..space6, radiusSm/Md/Lg, fontSm/Body/Title/Hero, scale, dark, highContrast, reducedMotion, bgPrimary, bgSecondary, bgCard, fgPrimary, fgMuted, accent, danger, success, warning, border}`.
- Containers: `nxui.row(id[, gap])` … `nxui.rowEnd()` · `nxui.column(id[, gap])` … `nxui.columnEnd()` · `nxui.card(id)` … `nxui.cardEnd()` · `nxui.scrollBegin(id, w, h[, scrollY])` → `newScrollY` … `nxui.scrollEnd()` · `nxui.canvasBegin(id, w, h)` → `x, y, w, h` (JS/Py: `{x, y, w, h}`) … `nxui.canvasEnd()` · `nxui.spacer([size])`.
- Controls: `nxui.label(id, text[, role])` (`"body"|"title"|"hero"|"muted"|"small"`) · `nxui.badge(id, text[, rgba])` · `nxui.button(id, label[, variant])` → `clicked` (`"primary"|"secondary"|"ghost"|"danger"`) · `nxui.toggle(id, checked)` → `newChecked[, changed]` · `nxui.slider(id, val, min, max)` → `newVal[, changed]` · `nxui.textfield(id, text[, placeholder])` → `newText[, changed]` · `nxui.dropdown(id, options, selected)` → `newSel[, changed]` (Lua 1-based; JS/Py/C 0-based) · `nxui.tabs(id, labels, active)` → `newActive[, changed]` (Lua 1-based; JS/Py/C 0-based) · `nxui.table(id, cols, rows, selectedRow)` → `newRow, clicked` (JS/Py `{selected, clicked}`) · `nxui.virtuallist(id, items, rowH, viewH, selectedRow)` → `newRow, clicked` (JS/Py `{selected, clicked}`) · `nxui.dialog(id, title, msg, confirm[, cancel])` → `0|1|2`.
- Focus: `nxui.moveFocus("up"|"down"|"left"|"right")` · `nxui.activateFocused()`.

## 6. Input

`app.event(e)`: `e.type` "mousedown","mouseup","mousemove","scroll","keydown","keyup","text","paddown","padup",
"pinch","rotate". Fields: `x,y` (local), `button` ("left"/"right"), `clicks`, `dx,dy`, `key` ("a".."z","0".."9",
"left","right","up","down","enter","escape","backspace","delete","tab","space","home","end","pageup","pagedown","f1"…),
`text`, `pad` ("a","b","x","y","l","r","zl","zr","plus","minus","up","down","left","right","lstick","rstick"),
`touch`, `shift`, `ctrl`, `cancel`, `scale` (pinch, multiply zoom by it), `angle` (rotate, radians delta).
Pad events arrive only with `"gamepad": true`. Controller cursor: A = click, X = right click, right stick = scroll,
D-pad = arrow keys, B = Escape.
Polling: `input.down(b)`, `input.pressed(b)`, `input.released(b)`, `input.stick("left"|"right")` → x,y (-1..1, y up
positive), `input.key(name)`, `input.touch()`, `input.motion()` → ax,ay,az,gx,gy,gz,pitch,roll,yaw.

**Every game and app must support all input methods** (`Guides/INPUT_AND_PLAY_MODES.md`):
- touch (targets of at least 44 px, no hover-only actions; `pinch` / `rotate` / two-finger `scroll` where zoom or pan makes sense),
  controller (`"gamepad": true` for games; confirm / back through `input.action`; a single Joy-Con has one stick),
  keyboard and mouse;
- docked mode has no touch: nothing may need a touch, the pad works from the first screen; show button glyphs when
  `input.touch()` is false;
- handheld 1280x720 and docked 1920x1080, window and full screen: lay out from `gfx.size()` each frame, never hard-code
  a resolution; scale text with `ui.tokens().textScale`;
- sound: moderate volume, system mixer only, pause in `app.focus(false)` / `app.suspend()`, save in `app.suspend()` and
  `app.close()`; no frame over 16.6 ms.

## 7. Data, network, system

- `fs` (relative paths = the app's data folder; "bundle:/..." = shipped files): `read(p)` → string or nil,err ·
  `write(p,data)` · `append` · `exists` · `isdir` · `list(p[,hidden])` → {{name,path,dir,size,mtime}} · `mkdir` ·
  `remove(p[,permanently])` (Trash by default) · `rename(a,b)` · `copy(a,b)` · `path(rel)` · `dir(which)` ("data",
  "bundle","cache","home","documents","desktop","downloads","pictures","music").
- `store.get(key[,default])`, `store.set(key,value)` (JSON-like values, auto-saved), `store.save()`.
- `json.decode(text)` → value or nil,err · `json.encode(value[,pretty])`.
- `net` (async, HTTPS, needs "network"): `net.get(url[,headers],fn(res))`, `net.post(url,body[,contentType],fn)`,
  `net.json(url,fn(data,err))`, `net.download(url,path,fn(ok,pathOrErr)[,progress(now,total)])`, `net.encode(s)`.
  `res`: ok, status, body, error, url, headers. SDK 1.9 (needs "minSdk": "1.9"): `net.request({url, method, headers,
  json|form|multipart|file|body, saveTo, responseType="json", cache=seconds, retry=n, cookies=true, timeout}, fn(res)[,
  progress(now,total,phase)])` → id, `net.cancel(id)`, `net.clearCookies()`, `net.clearCache()`; res adds data,
  fromCache, stale, path. WebSocket: `net.ws(url[, {headers, protocols}])` → id, poll `net.wsPoll(id)` every frame
  ({type="open"|"message"|"error"|"close", data, binary, code, reason}), `net.wsSend(id, text)`, `net.wsClose(id)`,
  `net.wsState(id)`. Sign-in: `net.oauth({url, redirect="http://localhost/cb", pkce=true}, fn(result, err))` →
  result.code / result.verifier (opens in a Browser window of Nexvyn OS; `err` is "cancelled" if the user closes it). Never put client secrets in an app.
- `sys`: `time()` (monotonic s), `epoch()`, `date([epoch])` → {year,month,day,hour,min,sec,wday,yday,epoch},
  `battery()` → percent,charging, `online()`, `lang()`, `username()`, `model()`, `firmware()`, `notify(title,body)`,
  `open(pathOrUrl)`, `launch(appId[,arg])`, `clipboard([text])`, `log(...)`, `title(text)`, `exit()`, `fps()`,
  `vibrate([strength[,ms]])`, `appid()`, `sdkVersion()` → "1.12". SDK 1.4: `share(textOrPath)`,
  `schedule(epoch,title[,body[,arg]])` → id or nil,err, `unschedule(id)`, `scheduled()`, `hasPermission(name)`,
  `requestPermission(name[,fn(granted)])`, `memory()`, `appUrl(id[,arg])`. Links: `nxv://app/<id>?arg=...`,
  `nxv://store/<id>`, `nxv://settings/<pane>`.
- SDK 1.9 feeds and media: `gfx.imageUrl(url, maxSize)` → image or nil while loading (call every frame, ask for the
  drawn size; `gfx.imageState(url, maxSize)`); `media.open(src, {loop, muted, autoplay, audioOnly, start})` → id,
  `media.draw(id, x, y, w, h, "cover"|"contain"|"stretch")`, `media.play/pause/seek/set/info/close` (at most 3
  players: keep the current and next one open); `ui.beginFeed(id, x, y, w, h, count, {itemHeight|heights, columns,
  gap, refreshing, loadingMore})` → {first, last}, `ui.feedItem(i)` → {x, y, w, h}, `ui.endFeed()` → {refresh, more};
  `ui.pager(id, x, y, w, h, count)` → {page, pos, changed} (draw page i at y + (i - pos) * h); `ui.richText(id, text,
  x, y, w, size)` → {height, clicked} (bold, links, @mentions, #hashtags), `ui.measureRichText(text, w, size)`;
  `sys.relativeTime(epoch)`. Guide: SDK/Guides/MAKE_A_SOCIAL_APP.md.
- `audio.tone(freq,seconds[,volume[,wave]])` (wave "sine","square","saw","triangle","noise") → channel ·
  `audio.play(nameOrPath[,volume[,loops]])` (system "click","pop","notify","alarm","trash","shutter","error","key",
  "volume","startup" or .wav/.ogg/.mp3; loops -1 = repeat) · `audio.stop(ch)` · `audio.music(path)` ·
  `audio.musicPause(bool)` · `audio.musicStop()`.
- `timer.after(sec,fn)` → id · `timer.every(sec,fn)` → id · `timer.cancel(id)`.
- `TR(key, ...)`.

## 7a. Game kits (files in the SDK, copied into the bundle; Lua shown, JS the same with arrays and objects)

- `sfx` (sound): `sfx.init()`, `sfx.define(name, recipe, {bus, vol, variants, vary, maxVoices, cooldown, duck =
  {bus, level, sec}})`, `sfx.song(name, sfx.recipes.song{bpm, root, scale, chords, bass, arp, arpRate, drums},
  {mode = "loop"|"bars"})`, `sfx.update(dt)` every frame (renders WAVs a few ms per frame, cached in the data folder),
  `sfx.ready()`, `sfx.progress()`, `sfx.play(name[, {vol}])`, `sfx.music(name)`, `sfx.stopMusic()`,
  `sfx.ambience(name, {details, every})`, `sfx.setBus(bus, vol)`, `sfx.duck(bus, level, sec)`. Recipes
  `sfx.recipes`: `ui{kind = "tick"|"confirm"|"back"|"error"|"open"}`, `coin`, `jump{weight}`, `laser{length}`,
  `impact{weight, bright}`, `explosion{size}`, `powerup{root}`, `hurt`, `whoosh{length}`, `footstep{surface =
  "grass"|"stone"|"wood"|"snow"|"metal"}`, `jingle{notes, step}`, `detail{kind = "bird"|"drip"|"crackle"|"cricket"|
  "creak"}`, `ambience{kind = "wind"|"rain"|"night"|"cave"|"ocean"|"hum"|"fire"}`, `song{...}`; or your own
  `{layers = {{wave, freq, to, glide, at, len, a, d, s, r, vol, lp/hp/bp = {cut, to, q}, fm, vib, trem}}, echo, room,
  drive}`. Buses: master, music, sfx, ui, amb.
- `juice` (graphics, UI, feel; `J = require("juice")`): `J.init()`, `J.update(dt)`, `J.dt(dt)` (0 during hit-stop),
  `J.event(e)`, `J.endFrame()`; `J.ease.*`, `J.tween(obj, sec, props, ease, {delay, done, loop, yoyo})`,
  `J.damp(a, b, rate, dt)`, `J.spring(state, target, dt, hz, damping)`; `J.shake(amount)`, `J.shakeOffset(px)` →
  dx, dy, `J.hitstop(sec)`, `J.slowmo(scale, sec)`, `J.flash(color, sec, alpha)`; `J.burst(x, y, "sparks"|"embers"|
  "dust"|"smoke"|"confetti"|"magic"|"hit", {n, angle, spread})`, `J.drawParticles()`, `J.floatText(s, x, y, color,
  size)`, `J.drawFloaters()`; `J.glow(x, y, r, color, alpha)`, `J.vignette(w, h, strength, color)`, `J.grain(w, h,
  alpha)`, `J.blob(x, y, w, h, alpha)`, `J.rays(x, y, len, count, color, alpha, t)`, `J.gradient(x, y, w, h,
  {c1, c2, ...})`; `J.palettes.<ember|frost|toxic|synth|jungle|paper|noir|candy>` (deep, bg, mid, ink, accent,
  accent2, light), `J.mix`, `J.shade`, `J.alpha`; `J.scale(base, ratio)`, `J.spaced(s, x, y, size, font, spacing,
  align, w)`, `J.title(s, x, y, size, {fill, fill2, outline, outlineW, shadow, glow, spacing, align, w})`, `J.fit`;
  `J.panel(x, y, w, h, {shape = "round"|"pill"|"cut"|"slant"|"tab", fill, fill2, border, shadow, depth, highlight})`,
  `J.button(id, label, x, y, w, h, {focused, activate, shape, fill, fillHover, ink, glow, depth})` → clicked, `J.onUi`;
  `J.transition("fade"|"iris"|"wipe"|"blinds"|"pixels", sec, onMiddle, color)`, `J.overlay(w, h)`;
  `J.camera{lag, lead, dead, bounds}` with `:follow(x, y, vx, vy, dt)`, `:offset(w, h, shakePx)`;
  `J.cam3d{dist, height, lookHeight, lag, fov}` with `:follow(x, y, z, yaw, dt)`, `:apply()`, `:fov()`, `:kick(deg)`;
  `J.looks.<dusk|noon|night|toxic|frost|desert|abyss|synth>`, `J.sky(w, h, look)`, `J.light3d(look, far)`.
  JavaScript returns several values as arrays (`const [dx, dy] = J.shakeOffset(12)`).

## 8. 3D and the 2D engine (summaries; see SDK.md 8b / 8c for the full lists)

- `g3d` (GPU, CPU fallback): `g3d.mesh(kind,...)` ("cube",s · "box",w,h,d · "sphere",r,seg,rings · "plane",w,d,div ·
  "cylinder",r,h,seg · "cone",r,h,seg · "torus",R,r,seg,sides), `g3d.load(path[,size])` (.obj/.stl),
  `g3d.custom(verts, indices[, colors[, flat[, uvs]]])`, `mesh:setColor(c)`, `mesh:flat(b)`, `mesh:triangles()`,
  `mesh:setTexture(path)`, `mesh:texture()`, `g3d.gpu()`; per frame: `g3d.begin(x,y,w,h[,fov[,near[,far]]])`,
  `g3d.camera(ex,ey,ez,tx,ty,tz[,ux,uy,uz])`, `g3d.light(dx,dy,dz[,ambient[,color]])`, `g3d.fog(color,start,end)`,
  `g3d.draw(mesh,x,y,z[,rx,ry,rz[,sx[,sy,sz][,tint[,"wire unlit nocull glow"]]]])`, `g3d.line(...)`, `g3d.point(...)`,
  `g3d.project(x,y,z)` (before finish), `g3d.finish()` → triangle count. Create meshes once in load.
- `g3d` models (SDK 1.8): `g3d.loadModel(path[,size], fn(model, err))` loads `.glb`/`.gltf`/`.fbx`/`.obj`/`.stl` on a
  background thread (JS: returns a Promise without the callback; Python `g3d.loadModel(path, size=None,
  callback=None)`); `g3d.model(path[,size])` → model or nil,err (blocks: tiny files only). Without `size` the model
  keeps its authored size (metres, +Y up, faces +Z); with `size` its largest side is `size`, standing on y = 0.
  `g3d.draw(model, x,y,z, rx,ry,rz, sx,sy,sz, tint, flags)`, `g3d.drawMatrix(meshOrModel, m16[, tint[, flags]])`,
  `model:info()` → {format, triangles, vertices, meshes, nodes, bones, materials, textures, skinning, size={w,h,d},
  min, max, animations={{name, duration}}}, `model:play(clip[, {loop, speed, fade}])` → bool (JS `{loop, speed,
  fade}`, Python `play(clip, loop, speed, fade)`), `model:stop([fade])`, `model:update(dt)` (every frame),
  `model:time([t])`, `model:clip()`, `model:playing()`, `model:node(name, x..sz)` → x,y,z,
  `model:nodeMatrix(name, x..sz)` → 16 numbers (attachments), `model:triangles()`, `model:free()`. The basic
  renderer draws the base colour texture (an emissive colour draws unlit); the pbr renderer draws every map of the
  file: glTF base colour, normal, metallic-roughness + occlusion (ORM) and emissive; FBX the same. When an FBX uses an
  external base colour file, metallic, roughness and AO maps the FBX does not link are also found in files next to it,
  named like it (`X_BaseColor.png` -> `X_MetallicSmoothness.png`: metallic R, smoothness A; `X_Metallic.png`,
  `X_Roughness.png`, `X_AO.png`). Normal and emissive maps are never found this way: link them in the FBX (or embed
  them in a .glb). Budgets: a hero 3-8k triangles, 30-60k per frame, 8-16 skinned characters at 60 fps.
- pbr renderer (NexGFX, SDK 1.9, opt-in per app; settings stay until changed, set them in load):
  `g3d.rendererInfo()` → {name="NexGFX", version, backend, renderer};
  `g3d.renderer("pbr")` → "pbr" or "basic" (no GLES 3: the same calls draw with the basic renderer, without
  lights / shadows / post effects; never assume "pbr"); `g3d.caps()` → {gpu, pbr, hdr, shadows, instancing, msaa,
  maxLights, maxLightsPerDraw, maxTextureSize, gl, glsl, device};
  `g3d.addLight({type="point"|"spot"|"directional", x,y,z, dx,dy,dz, color, intensity, range, inner, outer, shadow})`
  → id (16 per scene, 8 nearest per object; intensity 1 = full colour at 1 m, rooms 5-20), `g3d.updateLight(id,
  {fields})`, `g3d.removeLight(id)`, `g3d.clearLights()`, `g3d.lights()`; the sun is `g3d.light(...)`;
  `g3d.shadows({enabled, quality="low"|"medium"|"high", distance, bias})` (sun + one spot with shadow=true);
  `g3d.postfx({exposure, tonemap="aces"|"filmic"|"none", bloom, threshold, msaa=0|2|4|8, hdr})`;
  `g3d.environment({sky, ground, intensity, sun, cubemap={6 paths +X -X +Y -Y +Z -Z}})`;
  `g3d.material(meshOrModel, {metallic, roughness, emissive, emissiveStrength, normalMap, metalRoughMap,
  metallicMap, roughnessMap, metalSmoothMap, occlusionMap, emissiveMap, normalScale, occlusionStrength,
  transmission, ior, clearcoat, clearcoatRoughness}[, name])` (nil = back to the file's values; `transmission` =
  thin glass); `g3d.drawInstanced(meshOrModel, {x,y,z,rx,ry,rz,s, ...}[, tint[, flags[, stride 7|16]]])`. Emission
  above 1 blooms. Budget: start with msaa 0, shadows "medium", textures <= 1024 px; each game picks its own light
  colours, exposure and bloom (part of its art direction, rule 13).
- `nexvyn.game` (Lua only, `minSdk` 1.2): `local game = require("nexvyn.game")`, `return game.run{width, height,
  scene = Scene, background}`. Scenes (`enter`, `update(dt)`, `draw`, `ui`, `event`, `restart`), `game.switch/push/pop`,
  `game.world{gravity}` with `add`, `collide`, `trigger`, `query`; `game.sprite{x,y,r|w,h, body = true}`,
  `game.sheet`, `game.animations`, `game.tilemap` (`fromStrings`, `fromJSON`, `fromTiled`, `map:path`),
  `game.camera`, `game.lights`, `game.input` (`bind`, `down`, `pressed`, `vector`, `touchControls`), `game.tween`,
  `game.emitter` / `game.particles.preset`, `game.audio` (`define`, `play`, `song`), `game.ui` (`text`, `bar`,
  `button`, `menu`, `dialog`, `hearts`), `game.save.open(name)`. Draw with `game.gfx` (virtual units). Use only the
  names in SDK.md 8c.

## 9. Language differences

| | Lua | JavaScript | Python | Squirrel | C | Java |
|---|---|---|---|---|---|---|
| main | main.lua returns `app` table | main.js ES module, set `app.load = ...` or `export default {...}` | module-level `app` object (class instance) or plain functions | main.nut returns a class instance/table | functions `app_load`, `app_draw`... | class extends `nexvyn.App`, `mainClass` |
| indexes | 1-based | 0-based | 0-based | 0-based | 0-based | 0-based |
| no value | nil | null | None | null | NULL / 0 | null |
| several results | `local w, h = gfx.size()` | array `[w, h]` | tuple | array | pointers `gfx_size(&w,&h)` | `double[]` / `List` |
| `ui.textfield` | text, submitted | text; `ui.submitted(id)` | text; `ui.submitted(id)` | text; `ui.submitted(id)` | edits `char buf[]` in place, returns changed | text; `Ui.submitted(id)` |
| `ui.row` | clicked, double | 0/1/2 | 0/1/2 | 0/1/2 | 0/1/2 | int |
| async | callbacks | Promise when no callback (`await net.fetchJson(url)`, `await ui.alert(...)`, `await timer.sleep(s)`) | callbacks | callbacks (`this` = app) | fn pointer + `void* user` | `(Callback) a -> ...` |
| modules | `require("x")` | `import {f} from "./x.js"` | `import x` | `import("x")` | all .c files compiled; `#include "x.h"` | Java packages in src/ |
| names | `gfx.rect` | `gfx.rect` | `gfx.rect` (+ keyword args) | `gfx.rect` | `gfx_rect`, `theme_color("bg")` | `Gfx.rect`, `Theme.bg()` |
| sandbox | yes | yes | yes (16 windows max) | yes | **no** (consent once, needs JIT; with targetSdk 1.8 `#include` only reads the app's own files and SDK headers, inline `asm` is refused) | partly (consent once, one Java app at a time) |
| new APIs | yes | yes | yes | frozen at 1.8 | yes | frozen at 1.8 |

Per-language rules: `SDK/AI/languages/<lang>.md`.

## 10. Store publishing (when asked to prepare a store submission)

Item folder `Store/Apps/<category>/<slug>/` (games: `Store/Games/<genre>/<slug>/`) with `source/` (the bundle),
`README.md` (English; more languages optional), `store.json`:

```json
{"kind": "app", "features": ["offline", "touch"], "tags": ["..."],
 "subtitle": {"en": "..."},
 "description": {"en": "..."},
 "shots": [["wait 3"], ["wclick 0.5 0.3", "wait 1.5"], ["key right", "wait 1"], ["hold right 1.5", "wait 1"],
           ["dark 1", "wait 1.5"]]}
```

English is required in `subtitle` / `description`; add other languages as more keys (`"de": "..."`).
`kind`: app, game, demo, port, emulator, template. `features` (fill it for every game and app, from what the code really does): 3d, online, multiplayer, coop, offline, touch, controller, keyboard; games with `multiplayer` or `coop` also get `players` ("2" or "1-4"); themes get `themeStyle` (retro, modern, phone, dark, light, nature, minimal). Subtitle at most 45 characters. `source/icon.png` is key art (rule 12). `shots`: 3-5 lists (5 recommended, the coolest
moments) of steps: `wait S`, `wclick FX FY` / `wmove FX FY` (0..1 fractions of the window content), `key NAME`,
`hold KEY S`, `dpad DIR`, `text STRING`,
`dark 0|1`.

## 11. Golden Copy-Pasteable Templates (Zero-Hallucination Starters for Any AI Model)

When building a new app or game, start from one of these verified skeletons and expand it. Every call in these templates is 100% real and verified on Nexvyn OS N2.

### Template A — Modern NXUI Desktop / Utility App (Lua 5.4.7)
```lua
-- main.lua ("runtime": "lua", "minSdk": "1.13", "targetSdk": "2.0")
local app = {}
local items = {}
local inputText = ""
local selectedRow = 1
local activeTab = 1
local notificationsOn = true

function app.load(arg)
  items = store.get("items", {
    {" Write documentation", "High", "Pending"},
    {" Ship v1.0 release", "Normal", "Done"}
  })
  notificationsOn = store.get("notificationsOn", true)
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  nxui.begin(w, h)
  nxui.column("root", 12)

  activeTab = nxui.tabs("nav_tabs", {TR("tab_tasks"), TR("tab_settings")}, activeTab)

  if activeTab == 1 then
    nxui.card("add_card")
    nxui.label("hdr", TR("title"), "title")
    nxui.row("input_row", 8)
    inputText = nxui.textfield("task_in", inputText, TR("placeholder"))
    if nxui.button("add_btn", TR("add"), "primary") and #inputText > 0 then
      table.insert(items, {inputText, "Normal", "Pending"})
      inputText = ""
      store.set("items", items)
      audio.play("pop")
    end
    nxui.rowEnd()
    nxui.cardEnd()

    selectedRow, clicked = nxui.table("tasks_tbl", {TR("col_task"), TR("col_priority"), TR("col_status")}, items, selectedRow)
    if clicked and items[selectedRow] then
      items[selectedRow][3] = (items[selectedRow][3] == "Done") and "Pending" or "Done"
      store.set("items", items)
      audio.play("click")
    end
  else
    nxui.card("settings_card")
    nxui.label("set_hdr", TR("tab_settings"), "title")
    local newNotif, changed = nxui.toggle("notif_toggle", notificationsOn)
    if changed then
      notificationsOn = newNotif
      store.set("notificationsOn", notificationsOn)
    end
    nxui.cardEnd()
  end

  nxui.columnEnd()
  nxui.endFrame()
end

function app.event(e)
  if e.type == "paddown" then
    if e.pad == "up" or e.pad == "down" or e.pad == "left" or e.pad == "right" then
      nxui.moveFocus(e.pad)
    elseif e.pad == "a" then
      nxui.activateFocused()
    end
  end
end

return app
```

### Template B — 60 FPS Arcade / Action Game with Controller + Touch + Audio (Lua 5.4.7)
```lua
-- main.lua ("runtime": "lua", "gamepad": true, "minSdk": "1.12", "targetSdk": "2.0")
-- Art Direction: Cyber-Amber palette (#0D0E15 deep void, #FFB000 amber hero, #FF3366 hazard, #00F0FF energy)
local app = {}
local state = "title" -- "title", "play", "paused", "gameover"
local px, py, vx, vy = 320, 240, 0, 0
local score, best = 0, 0
local orbs = {}
local shakeT = 0

local function spawnOrb(w, h)
  table.insert(orbs, {x = math.random(40, w - 40), y = math.random(60, h - 40), r = 10, pulse = 0})
end

function app.load()
  best = store.get("best", 0)
end

function app.focus(focused)
  if not focused and state == "play" then state = "paused" end
end

function app.suspend()
  store.set("best", best)
end

function app.update(dt)
  if shakeT > 0 then shakeT = math.max(0, shakeT - dt) end
  if state ~= "play" then return end

  local w, h = gfx.size()
  local sx, sy = input.stick("left")
  local dx, dy = sx, -sy
  if input.down("left") or input.key("left") or input.key("a") then dx = -1 end
  if input.down("right") or input.key("right") or input.key("d") then dx = 1 end
  if input.down("up") or input.key("up") or input.key("w") then dy = -1 end
  if input.down("down") or input.key("down") or input.key("s") then dy = 1 end

  local speed = (input.down("a") or input.key("space")) and 420 or 260
  px = math.max(20, math.min(w - 20, px + dx * speed * dt))
  py = math.max(50, math.min(h - 20, py + dy * speed * dt))

  for i = #orbs, 1, -1 do
    local o = orbs[i]
    o.pulse = o.pulse + dt * 5
    local dist2 = (px - o.x)^2 + (py - o.y)^2
    if dist2 < (16 + o.r)^2 then
      table.remove(orbs, i)
      score = score + 10
      if score > best then best = score; store.set("best", best) end
      shakeT = 0.12
      audio.tone(520 + (score % 400), 0.08, 0.35, "triangle")
      sys.vibrate(0.25, 35)
      spawnOrb(w, h)
    end
  end
end

function app.draw(w, h)
  gfx.gradient(0, 0, w, h, "#0D0E15", "#181B28", false)
  local ox = (shakeT > 0) and math.random(-4, 4) or 0
  local oy = (shakeT > 0) and math.random(-4, 4) or 0
  gfx.push(ox, oy)

  if state == "title" then
    gfx.text(TR("game_title"), 0, h * 0.32, 36, "bold", "center", w)
    gfx.color("#FFB000")
    gfx.text(TR("press_start"), 0, h * 0.52, 18, "semibold", "center", w)
  else
    for _, o in ipairs(orbs) do
      gfx.circle(o.x, o.y, o.r + math.sin(o.pulse) * 2, "#00F0FF")
    end
    gfx.circle(px, py, 16, "#FFB000")
    gfx.color("#FFFFFF")
    gfx.text(TR("score_fmt", score, best), 20, 14, 16, "semibold")
    if state == "paused" then
      gfx.rect(0, 0, w, h, 0, "#000000AA")
      gfx.color("#FFFFFF")
      gfx.text(TR("paused"), 0, h * 0.45, 28, "bold", "center", w)
    end
  end
  gfx.pop()
end

function app.event(e)
  local w, h = gfx.size()
  if (e.type == "paddown" and (e.pad == "a" or e.pad == "plus")) or (e.type == "keydown" and e.key == "enter") or e.type == "mousedown" then
    if state == "title" then
      state = "play"; score = 0; orbs = {}; px, py = w * 0.5, h * 0.5
      for i = 1, 5 do spawnOrb(w, h) end
      audio.play("pop")
    elseif state == "paused" then
      state = "play"
    elseif e.type == "paddown" and e.pad == "plus" then
      state = "paused"
    end
  end
  if e.type == "mousemove" and state == "play" and e.touch then
    px, py = e.x, e.y
  end
end

return app
```

### Template C — Native C / C++ Windowed Module (`.nxvmod`, Native SDK 1.2)
```c
/* src/main.c ("runtime": "native", "main": "myapp.nxvmod", "minNative": "1.2", "minSdk": "1.10", "targetSdk": "2.0") */
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_nxui.h>
#include <glad/glad.h>

static int app_main(int argc, char** argv) {
    (void)argc; (void)argv;
    nxn_display* disp = NULL;
    if (nxn_display_open(NULL, &disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "Failed to open display");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);

    uint32_t w = 960, h = 540;
    nxn_display_size(disp, &w, &h);
    int counter = 0;
    bool toggle_on = true;

    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && nxn_display_resize(disp, ev.width, ev.height) == NXN_OK) {
                nxn_display_size(disp, &w, &h);
                glViewport(0, 0, (GLsizei)w, (GLsizei)h);
            }
            ev.size = sizeof(ev);
        }

        glClearColor(0.08f, 0.10f, 0.14f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        nxn_nxui_begin((float)w, (float)h);
        nxn_nxui_column_begin("main_col", 12.0f);
        nxn_nxui_card_begin("hero_card");
            nxn_nxui_label("title_lbl", nxn_tr("title"), NXN_TYPO_TITLE);
            if (nxn_nxui_button("inc_btn", nxn_tr("increment"), NXN_BTN_PRIMARY)) {
                counter++;
            }
            nxn_nxui_toggle("opt_tog", &toggle_on);
        nxn_nxui_card_end();
        nxn_nxui_column_end();
        nxn_nxui_end();

        nxn_display_swap(disp);
    }

    nxn_display_close(disp);
    return 0;
}

int main(int argc, char** argv) {
    return nxn_run(argc, argv, app_main, NULL);
}
```

### Template D — JavaScript ES2023 Network + NXUI App
```json
// app.json
{
  "id": "com.example.jsnews",
  "name": {"en": "JS Feed"},
  "description": {"en": "Async network app using QuickJS-ng ES2023 and NXUI"},
  "version": "1.0.0",
  "runtime": "js",
  "main": "main.js",
  "minSdk": "1.13",
  "targetSdk": "2.0",
  "window": {"width": 680, "height": 460, "resizable": true},
  "permissions": ["network"]
}
```
```js
// main.js (ES module)
let status = "Ready";
let items = store.get("cached_items", []);
let loading = false;

async function refresh() {
  if (!sys.online()) { status = TR("offline"); return; }
  loading = true;
  status = TR("loading");
  try {
    const data = await net.fetchJson("https://jsonplaceholder.typicode.com/posts?_limit=15");
    items = data.map(p => [String(p.id), p.title.slice(0, 42)]);
    store.set("cached_items", items);
    status = TR("loaded", items.length);
  } catch (e) {
    status = e.message;
  } finally {
    loading = false;
  }
}

app.load = () => { if (items.length === 0) refresh(); };
app.draw = (w, h) => {
  const t = nxui.tokens();
  gfx.clear(t.windowBg);
  nxui.begin(w, h);
  nxui.column("root", t.space3);
    nxui.row("hdr", t.space3);
      nxui.label("title", TR("title"), "title");
      nxui.spacer(0);
      if (nxui.button("btn_ref", loading ? "..." : TR("refresh"), "primary") && !loading) refresh();
    nxui.rowEnd();
    nxui.label("st", status, "caption");
    nxui.table("tbl", ["ID", "Title"], items, 0);
  nxui.columnEnd();
  nxui.endFrame();
};
```
```json
// lang/en.json
{"title": "JS Feed", "refresh": "Refresh", "loading": "Loading...", "offline": "You are offline.", "loaded": "Loaded {0} items"}
```

### Template E — Python 3.12 (`"runtime": "python3"`) Data / Utility App
```json
// app.json
{
  "id": "com.example.pydata",
  "name": {"en": "Unit Converter"},
  "description": {"en": "CPython 3.12 utility with NXUI retained layout"},
  "version": "1.0.0",
  "runtime": "python3",
  "main": "main.py",
  "minSdk": "1.13",
  "targetSdk": "2.0",
  "window": {"width": 520, "height": 380, "resizable": true},
  "permissions": []
}
```
```python
# main.py (built-in gfx, ui, nxui, store, sys, TR — no import needed)
class App:
    def load(self, arg):
        self.celsius = store.get("celsius", 22.0)
        self.mode = 0  # 0-based

    def draw(self, w, h):
        t = nxui.tokens()
        gfx.clear(t["windowBg"])
        nxui.begin(w, h)
        nxui.column("col", t["space3"])
        nxui.label("hdr", TR("title"), "title")
        self.mode = nxui.tabs("tabs", [TR("temp"), TR("dist")], self.mode)
        nxui.card("card")
        if self.mode == 0:
            self.celsius = nxui.slider("c_sld", self.celsius, -40.0, 100.0)
            fahr = self.celsius * 9.0 / 5.0 + 32.0
            nxui.label("res", f"{self.celsius:.1f} C = {fahr:.1f} F", "headline")
        else:
            km = max(0.0, self.celsius)
            nxui.label("res_d", f"{km:.1f} km = {km * 0.621371:.2f} mi", "headline")
        nxui.cardEnd()
        nxui.columnEnd()
        nxui.endFrame()

    def autosave(self):
        store.set("celsius", self.celsius)

app = App()
```
```json
// lang/en.json
{"title": "Quick Converter", "temp": "Temperature", "dist": "Distance"}
```

### Template F — 3D PBR Scene (`g3d.renderer("pbr")`, Lua 5.4.7)
```lua
-- main.lua ("runtime": "lua", "minSdk": "1.9", "targetSdk": "2.0", "gamepad": true)
local app = {}
local ground, box, t = nil, nil, 0

function app.load()
  g3d.renderer("pbr")
  g3d.shadows({enabled = true, quality = "medium", distance = 24})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.08, threshold = 1.0})
  g3d.environment({sky = "#9DB8E8", ground = "#4A4038", intensity = 1.0, sun = 2.4})

  ground = g3d.mesh("plane", 24, 24, 1)
  ground:setColor("#5A626A")
  g3d.material(ground, {metallic = 0.0, roughness = 0.85})

  box = g3d.mesh("box", 1.2, 1.2, 1.2)
  box:setColor("#E0A84B")
  g3d.material(box, {metallic = 0.85, roughness = 0.25})

  g3d.addLight({type = "point", x = 2.5, y = 2.2, z = 2.0, color = "#FF9A3C", intensity = 8, range = 10})
end

function app.update(dt)
  t = t + dt
end

function app.draw(w, h)
  gfx.clear("#0E1116")
  g3d.begin(0, 0, w, h, 55, 0.1, 100)
  g3d.camera(math.sin(t * 0.4) * 5.0, 2.8, math.cos(t * 0.4) * 5.0, 0, 0.6, 0)
  g3d.light(0.5, 0.8, 0.4, 0.3, "#FFF2DF")
  g3d.fog("#0E1116", 20, 60)
  g3d.draw(ground, 0, 0, 0)
  g3d.draw(box, 0, 0.6, 0, 0, t * 0.8, 0)
  g3d.finish()
end

return app
```

### Top 10 AI Mistakes to NEVER Make
1. **Never use `io.open`, `os.execute`, `require("socket")` or `love.*` in Lua.** Use `fs.read`, `fs.write`, `store.get`/`set`, `net.*`, and `gfx.*`.
2. **Never use `document`, `window`, `fetch()`, or `localStorage` in JS.** Use `gfx.*`, `nxui.*`, `await net.fetchJson(url)`, and `store.get`/`set`.
3. **Never use `open()`, `os.*`, `pygame`, or `tkinter` in Python.** Use `fs.*`, `store.*`, `gfx.*`, and `nxui.*`.
4. **Never load images (`gfx.image`) or models (`g3d.loadModel`) or read files (`fs.read`) inside `app.draw(w, h)`** unless using `gfx.imageUrl(url, maxSize)` which is explicitly designed for per-frame streaming cache lookup.
5. **Never hardcode `1280, 720`.** Always use the `w, h` passed into `app.draw(w, h)` or call `gfx.size()`.
6. **Never forget `lang/en.json`.** Every `TR("key")` call in your code must have a matching `"key"` in `lang/en.json`.
7. **Never use `net.*` without `"permissions": ["network"]` in `app.json`.** The App Store builder and runtime enforce permissions strictly.
8. **Never build game menus with `ui.button` or `theme.*` colors.** Games must have their own custom art direction and color palette (Rule 11 & 13).
9. **Never write an infinite `while` loop.** Nexvyn OS is event- and frame-driven (`app.update(dt)`, `app.draw(w, h)`). Any callback running > 3 seconds is terminated by the watchdog.
10. **Never omit `nxui.endFrame()` after `nxui.begin(w, h)`, or `ui.endScroll()` after `ui.beginScroll(...)`, or `g3d.finish()` after `g3d.begin(...)`.**

## 12. How to answer

Give complete files (app.json, every source file, lang/en.json and a lang file for every other language the user
wants), not fragments. Then tell
the user how to check it on a PC (`python tools/lua_check.py`, `node tools/js_check.mjs`, `python tools/py_check.py`,
`python tools/rt_check.py` from the Nexvyn OS source repository, or `python SDK/Tools/nxv/nxv.py check <folder> --sdk <checkout>`)
and how to run it (copy to `sdmc:/NexvynOS/Applications/<Name>.nxvapp/`, or open it in Nexvyn OS Studio and press Run).
Follow `SDK/AI/checklist.md` before answering.
