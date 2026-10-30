# Nexvyn OS App SDK (.nxvapp)

**English** · [Türkçe](SDK.tr.md)

> **TR — Özet:** Nexvyn OS uygulamaları Lua 5.4 ile yazılır. Bir uygulama, içinde `app.json`, `main.lua` ve
> `icon.png` bulunan `Adı.nxvapp` klasörüdür. Klasörü (veya zip'lenmiş `.nxvapp` dosyasını) SD karttaki
> `sdmc:/NexvynOS/Applications/` içine koyun; uygulama Başlatıcı'da ve Hızlı Arama'da görünür ve çalışır.
> Hata olursa pencerede satır numaralı hata ekranı çıkar ve log `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` dosyasına yazılır.
> Aynı SDK JavaScript, Python, Squirrel, C ve Java ile de kullanılabilir (bölüm 11–15; `app.json` içinde `"runtime"`).
> Bu belge İngilizcedir; bir yapay zekâya "Bu SDK ile Nexvyn OS için ... uygulaması yaz" demeniz yeterlidir.

This document is the complete contract for third-party Nexvyn OS apps. It is written so that a developer **or an AI
assistant** can produce a working app from it alone. Everything listed here exists; nothing else does.

## 1. Package layout

```
MyApp.nxvapp/              ← folder name ends with .nxvapp (or zip the folder's contents into MyApp.nxvapp)
├── app.json              ← manifest (required)
├── main.lua              ← entry point (required)
├── icon.png              ← 128×128 or 256×256 PNG with transparency (recommended)
├── lang/en.json          ← translations (optional): {"hello": "Hello"}
├── lang/tr.json          ←                          {"hello": "Merhaba"}
└── anything else          (images, sounds, more .lua modules loaded with require("name"))
```

Install: copy the folder, or a zip of it renamed to `.nxvapp`, into **`sdmc:/NexvynOS/Applications/`** and reopen
the Launcher (zips are extracted automatically at boot or via *App Market → Install from File*). Opening a `.nxvapp` file
in Files shows the install sheet (details, permissions, file check) with **Run** and **Install**. To publish, pack the
folder with `python tools/nxvapp_pack.py MyApp.nxvapp` (adds `manifest.sha256`); add `--sign key.pem` (a key from
`python tools/nxvapp_keygen.py`) so the install sheet shows **Signed by <fingerprint>** and warns users when an update
comes from another key. The full package format, signing, the permission rules and the repository index are in
`docs/NXVAPP_FORMAT.en.md`.

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

- `id` must be unique (reverse-domain style). `name`/`description` may be plain strings.
- `runtime` picks the language when `main` does not: `"lua"` (default), `"js"` (section 11), `"python"` (12),
  `"python3"` (12, CPython), `"squirrel"` (13), `"c"` (14) or `"java"` (15, with `"mainClass"`). A `.js`, `.py`,
  `.nut`, `.c` or `.jar` main file selects it too (`.py` means `"python"`).
- `author` and `homepage` (optional, a web or GitHub address) are shown in the app's About window and the App Market.
- `category`: `system`, `productivity`, `utilities`, `media`, `internet`, `games`, `developer`, `other`.
- `window.width/height` is the **content** size (the title bar is added by the system).
- `gamepad: true` → while the window is focused the controller goes to the app instead of moving the cursor
  (games). The user presses **L+R** to get the cursor back. Touch always works.
- `fileTypes` → the app appears in "Open With" and receives the file path in `app.load(arg)` / `app.open(arg)`.
- `minSdk` → the oldest SDK version the app works with (see *SDK versions* below). Nexvyn OS does not install an app
  that needs a newer SDK; it says the app needs a newer Nexvyn OS. Omit it for apps that only use SDK 1.0.
- `targetSdk` → the SDK version you built and tested the app on (default: `minSdk`, else `"1.0"`). Later systems keep
  behaving the way that SDK did for your app (see *Compatibility* below). Studio writes the current SDK into new
  projects. `runtimeVersion` (optional) records the engine version you tested on, e.g. `"2.2"` for pocketpy.
- `shareTargets` → what the app accepts from `sys.share` (section 8a): `"text"` (any text), `"url"` (text starting
  with `http://`, `https://` or `nxv://`), `"file"` (any file), `"image"` (.png .jpg .jpeg .bmp .gif .webp) or a file
  extension such as `".txt"`. The shared item arrives like a file the app was opened with: `app.load(arg)` when the
  app was not running, `app.open(arg)` when it was.
- `permissions` → what the app needs beyond its own folders. **Every permission is enforced** for apps installed on
  the SD card (SDK 1.4; before, only `network` and `files` were):

  | Permission | Gates | Without it |
  |---|---|---|
  | `"network"` | `net.*` | callbacks report `error = "permission denied: network"` |
  | `"files"` | paths outside the app's bundle, data and cache folders | `fs.read` → nil, `fs.write` → false, absolute `fs.path` → `""` |
  | `"launch"` | `sys.launch(otherId)`, `sys.open("nxv://...")` | returns nil, `"permission denied: launch"` (JS/Python: `false`) |
  | `"notifications"` | `sys.notify`, `sys.schedule` | returns nil, `"permission denied: notifications"` (JS/Python: `false`) |
  | `"games"` | `sys.games` (the list of installed games, SDK 1.6) | returns nil, `"permission denied: games"` (JS: `null`, Python: `None`) |

  `sys.clipboard` needs no permission (since 1.0.0): every app may read and write the clipboard. An older app.json
  that still lists `"clipboard"` keeps working; the name is accepted and ignored (the pack and check tools warn).

  **When the user decides.** Once per app, never at the moment of a call. The install sheet (App Market or App
  Installer) lists the declared permissions and installing allows them; a *Customize* link lets the user turn some
  off first. An update that declares a new permission shows only that one on the update confirmation; permissions
  the user already answered are not asked again. An app that reaches its first start without an answer (copied to
  the SD card by hand, a legacy bundle) is asked once in one combined dialog. Apps you run from Studio or Code get
  what they declare without a question, and built-in apps are trusted. The answers can be changed later in
  System Settings > Privacy & Permissions. A permission that is not in the array is never granted, and every denial
  is written to the app's log with the reason ("declare it in app.json" or "the user did not allow it"). Files the
  user picks in `ui.openFile`/`ui.saveFile`, opens the app with or shares with it are always allowed. A bundle
  without a `permissions` array is asked about all of them. Leave the array empty when the app needs nothing.
  `sys.hasPermission(name)` and `sys.requestPermission(name, fn)` (the only way to bring the question back, for a
  permission the user turned off) are in section 8a.

### SDK versions

`sys.sdkVersion()` returns the version this system provides (`"1.6"`). Bump `minSdk` when you use something newer.

| SDK | Nexvyn OS adds |
|-----|-------------|
| 1.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | JavaScript runtime (section 11) with the same modules and Promises; `g3d` textures on the GPU |
| 1.2 | `nexvyn.game` engine (section 8c), `sys.sdkVersion()`, app.json `minSdk` and `permissions`, single-file `.nxvapp` v2 with `manifest.sha256` |
| 1.3 | Python runtime (section 12, pocketpy) with the same modules; asynchronous calls take callbacks |
| 1.4 | every permission enforced; `sys.share`, `sys.schedule` / `unschedule` / `scheduled`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `nxv://` links in `sys.open`; callbacks `app.search`, `app.suspend`, `app.resume`, `app.focus`, `app.autosave`, `app.unsaved`; app.json `shareTargets`; signed packages; 64 MB limit for Lua apps too |
| 1.5 | Squirrel (section 13), C compiled on the console (section 14) and Java (section 15) runtimes on one shared implementation; app.json `"runtime"` values `"squirrel"`, `"c"`, `"java"` and `"mainClass"`; Python system library (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |
| 1.6 | `fs.unzip` (unpacks a zip in the background with progress) and `sys.games` (installed games) with the new `"games"` permission, in Lua, JavaScript, Python and Squirrel; `sys.speak` / `sys.stopSpeaking` (text to speech, no permission) in every runtime; the `"python3"` runtime (CPython 3.12, section 12) |

### Compatibility: targetSdk and deprecation

The full contract is in `docs/COMPATIBILITY.en.md`. In short:

- **Nothing is removed.** Every function listed here keeps working in every later Nexvyn OS. A function that gets a
  replacement becomes *deprecated*: it still works, and the first call in a run writes
  `deprecated: <name> still works; use <replacement>` to your app's log (Studio's console shows it). Deprecated today:
  `require("snx.*")` → `require("nexvyn.*")`; the `"clipboard"` permission is accepted and ignored.
- **Behaviour changes are opt-in.** If a later SDK changes how an existing function behaves, only apps whose
  `targetSdk` is that SDK get the new behaviour; the reference marks it "for apps that target SDK x". Raise `targetSdk`
  after testing on the new system.
- **Newer apps on older systems.** An app whose `minSdk` is above the system's SDK, or whose `"runtime"` the system
  does not have, is shown as needing a newer Nexvyn OS: it is not installed, the App Market never offers it as an
  update, and a copy already on the SD card opens a window that says so. Unknown app.json fields and unknown
  permissions are ignored.
- **Runtimes stay.** A language runtime is never removed while apps use it; a new engine version must pass the app
  compatibility suite (`tools/compat_check.py`, every store app, game and sample) before it ships.

### Themes (.nxvtheme)

Themes are not apps: a `.nxvtheme` is a zip with `theme.json` and pictures (optionally UI sounds), no code. It sets
the appearance (`"light"`/`"dark"`/`"auto"`), the accent color (`"#RRGGBB"`), the wallpaper (1280×720, plus an
optional `wallpaperDark`) and a few whitelisted settings (`dock.size`, `appearance.reduceTransparency`, ...):

```json
{"id": "com.you.theme.dusk", "name": {"en": "Dusk", "tr": "Alacakaranlık"}, "version": "1.0", "author": "You",
 "appearance": "auto", "accent": "#FF7A59", "wallpaper": "wallpaper.jpg", "wallpaperDark": "wallpaper-dark.jpg"}
```

Opening the file in Files offers **Install** / **Install and Apply**; installed themes live in `~/Library/Themes/<id>/`
and are managed in *System Settings > Appearance > Themes*. Full format, limits and the settings keys:
`docs/NXVAPP_FORMAT.en.md` section 9.

## 2. Program structure

`main.lua` returns a table of callbacks. All callbacks are optional.

```lua
local app = {}

function app.load(arg)            -- once; arg = file path / URL / "" that the app was opened with
end

function app.open(arg)            -- the app was asked to open something else while running
end

function app.update(dt)           -- every frame (~60 fps), dt in seconds
end

function app.draw(w, h)           -- every frame: draw AND handle widgets; w,h = content size in pixels
  gfx.clear(theme.bg)
end

function app.event(e)             -- raw input (see §5)
end

function app.menu()               -- optional menu-bar menus
  return { { title = TR("game"), items = { {label = TR("new"), id = 1, shortcut = "Ctrl+N"}, "-", {label = "...", id = 2} } } }
end

function app.onmenu(id) end

function app.close()              -- return false to keep the window open (e.g. ask to save first)
  return true
end

-- SDK 1.4 (all optional)
function app.search(query)        -- Quick Search asks running apps; return at most a few items
  return { {title = "Note: " .. query, subtitle = "My App", icon = "description", arg = "note:42"} }
end                               -- picking an item calls app.open(arg) (or app.load(arg) if the app was closed)
function app.suspend() end        -- Nexvyn OS goes to the background (HOME menu, sleep): pause, save
function app.resume() end         -- back in the foreground / the console woke up (the network may have dropped)
function app.focus(focused) end   -- the window gained (true) / lost (false) keyboard focus
function app.autosave() end       -- periodic save point and before quit / restart / power off: save quietly
function app.unsaved()            -- true while work would be lost; the shell lists such apps before quitting
  return false
end

return app
```

Coordinates are pixels with (0,0) at the top-left of the window content; y grows downwards. Angles are radians,
0 = pointing right, increasing clockwise. Colors are hex strings `"#RRGGBB"` / `"#RRGGBBAA"`, tables
`{r,g,b[,a]}` (0–255), or 3–4 numbers where noted.

Errors: if any callback raises an error, the window shows the message with a traceback and a **Reload** button;
`print()`/`sys.log()` output and errors go to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`. A callback that runs for more
than 3 seconds is aborted (infinite loop protection). Every app may use up to **64 MB** of script memory (Lua since
SDK 1.4, like JavaScript and Python): past it the app stops with `MemoryError: out of memory (the app used more than
64 MB)` and an out-of-memory screen; the rest of the system keeps running. `sys.memory()` tells how close you are.
`store` is written to disk on `app.suspend` / `app.autosave` too, so a sleeping console does not lose it.

Available standard Lua: `string`, `table`, `math`, `utf8`, `coroutine`, `os.time/os.clock/os.date/os.difftime`,
`pcall`, `select`, `ipairs`/`pairs`, `tostring`… (`io`, `debug`, `package`, `dofile`, `loadfile` are not available —
use `fs`). `require("name")` loads `name.lua` from your bundle; `require("a.b")` loads `a/b.lua`. Modules that are not
in the bundle come from the system Lua library `romfs:/System/Lua/` (for example `require("nexvyn.game")`, see 8c).

## 3. Drawing — `gfx`

| Function | Description |
|---|---|
| `gfx.color(c)` / `gfx.color(r,g,b[,a])` | current color for following draw calls |
| `gfx.clear([c])` | fill the whole content area |
| `gfx.rect(x,y,w,h[,radius[,c]])` | filled (rounded) rectangle |
| `gfx.rectLine(x,y,w,h[,radius[,thickness]])` | outline |
| `gfx.circle(x,y,r[,c])`, `gfx.circleLine(x,y,r[,t])` | filled / outline circle |
| `gfx.line(x1,y1,x2,y2[,thickness])` | anti-aliased line |
| `gfx.lines({x1,y1,x2,y2,...}[,thickness[,closed]])` | polyline |
| `gfx.poly({x1,y1,...}[,c])` | filled **convex** polygon |
| `gfx.arc(x,y,r,a0,a1[,thickness])`, `gfx.pie(x,y,r,a0,a1)` | arc / filled sector |
| `gfx.gradient(x,y,w,h,c1,c2[,horizontal[,radius]])` | gradient (vertical by default) |
| `gfx.shadow(x,y,w,h[,radius[,blur[,dy]]])` | soft drop shadow (draw before the shape) |
| `gfx.text(s,x,y[,size[,font[,align,width]]])` → width | `y` is the top of the line. font: `"sans"`,`"medium"`,`"semibold"`,`"bold"`,`"italic"`,`"mono"`,`"monobold"`. align `"left"`/`"center"`/`"right"` within `width` |
| `gfx.textWidth(s[,size[,font]])`, `gfx.textHeight([size[,font]])` | measuring |
| `gfx.wrap(s,x,y,w[,size[,font[,align[,lineSpacing]]]])` → height | word-wrapped paragraph |
| `gfx.measureWrap(s,w[,size[,font]])` → height | |
| `gfx.icon(name,cx,cy[,size[,c]])` | Material Icons Round glyph centered at cx,cy (e.g. `"favorite"`, `"play_arrow"`, `"settings"`, `"delete"`, `"star"`, `"refresh"`) |
| `gfx.image(path)` → img or nil | load PNG/JPG/WEBP/BMP/GIF (cached). Relative paths are in your data folder; use `"bundle:/img/x.png"` for files shipped in the app |
| `img.width`, `img.height` | |
| `gfx.draw(img,x,y[,w,h[,radius[,tint]]])` | draw (scaled) |
| `gfx.drawRegion(img,sx,sy,sw,sh,x,y,w,h[,angleDeg])` | draw part of an image (sprite sheets) |
| `gfx.push(dx,dy)` / `gfx.pop()` | translate following drawing |
| `gfx.clip(x,y,w,h)` / `gfx.unclip()` | restrict drawing (nestable) |
| `gfx.alpha(a)` / `gfx.unalpha()` | multiply opacity (nestable) |
| `gfx.size()` → w,h | content size |

`theme` holds the system colors as hex strings and updates live with light/dark mode:
`theme.dark` (bool), `theme.bg`, `theme.window`, `theme.sidebar`, `theme.text`, `theme.text2`, `theme.text3`,
`theme.separator`, `theme.control`, `theme.field`, `theme.selection`, `theme.hover`, `theme.accent`, and
`theme.red/orange/yellow/green/blue/purple/pink/gray`. Use them so the app looks right in both modes.

## 4. Widgets — `ui`

Immediate mode: call the widget every frame inside `app.draw`; it draws itself and returns what happened.
Widgets are identified by their label or `id` string — keep ids unique within the window (append `"##suffix"` to
a label to make it unique without showing the suffix).

| Function | Returns |
|---|---|
| `ui.button(label,x,y,w,h[,style[,icon[,enabled]]])` style: `"default"`,`"primary"`,`"destructive"`,`"plain"`,`"toolbar"`,`"link"` | `true` when clicked |
| `ui.iconButton(icon,x,y,w,h[,tint[,active[,idSuffix]]])` | clicked |
| `ui.toggle(id,value,x,y[,w,h])` | new boolean |
| `ui.checkbox(label,value,x,y)` | new boolean |
| `ui.radio(label,selected,x,y)` | clicked |
| `ui.slider(id,value,min,max,x,y,w[,step])` | new number |
| `ui.textfield(id,text,x,y,w[,h[,placeholder[,flags]]])` flags: `"search"`, `"password"`, `"numeric"`, `"readonly"` (combine with spaces) | `newText, submitted` (Enter) |
| `ui.segmented(id,{items},selected,x,y,w[,h])` (1-based) | new index |
| `ui.dropdown(id,{items},selected,x,y,w[,h])` (1-based) | new index |
| `ui.label(text,x,y[,size[,color[,font]]])` | |
| `ui.progress(value,x,y,w[,h])` (0..1, or -1 = indeterminate) | |
| `ui.spinner(x,y[,radius])` | |
| `ui.row(id,x,y,w,h,selected)` list row with hover/selection | `clicked, doubleClicked` |
| `ui.group(x,y,w,h)` rounded settings-style section, `ui.separator(x1,y,x2)` | |
| `ui.beginScroll(id,x,y,w,h,contentHeight[,contentWidth])` → scrollY, scrollX … `ui.endScroll()` | children are drawn in content coordinates (0,0 = top of the content); drag/touch/stick scrolling built in |
| `ui.hit(id,x,y,w,h)` custom clickable area | table `{hovered, held, pressed, clicked, rightClicked, doubleClicked, dx, dy}` |
| `ui.mouse()` | `x, y, down, hovering` (pointer in local coordinates) |
| `ui.focus(id)` | focus a text field |
| `ui.contextMenu({ {label=..., id=1, icon="..."}, "-", ... }, function(id) end)` | opens at the pointer |
| `ui.alert(title, message, {"OK","Cancel"}, function(buttonIndex) end)` (1-based) | system dialog |
| `ui.prompt(title, message, default, function(textOrNil) end)` | text input dialog |
| `ui.openFile(function(pathOrNil) end, {".txt",".md"}[, title])` | system open dialog |
| `ui.saveFile(function(pathOrNil) end, "name.txt"[, title])` | system save dialog |
| `ui.keyboard(initial, function(textOrNil) end[, guide])` | Nintendo system keyboard |

The on-screen keyboard appears automatically when a text field is focused.

## 5. Input — `app.event`, `input`

`app.event(e)`: `e.type` is one of `"mousedown"`, `"mouseup"`, `"mousemove"`, `"scroll"`, `"keydown"`, `"keyup"`,
`"text"`, `"paddown"`, `"padup"`. Fields: `e.x, e.y` (local), `e.button` (`"left"`/`"right"`), `e.clicks`,
`e.dx, e.dy` (scroll pixels), `e.key` (`"a"`…`"z"`, `"0"`…`"9"`, `"left"`,`"right"`,`"up"`,`"down"`,`"enter"`,
`"escape"`,`"backspace"`,`"delete"`,`"tab"`,`"space"`,`"home"`,`"end"`,`"pageup"`,`"pagedown"`,`"f1"`…), `e.text`
(typed UTF-8), `e.pad` (`"a"`,`"b"`,`"x"`,`"y"`,`"l"`,`"r"`,`"zl"`,`"zr"`,`"plus"`,`"minus"`,`"up"`,`"down"`,`"left"`,
`"right"`,`"lstick"`,`"rstick"`), `e.touch`, `e.shift`, `e.ctrl`, `e.cancel` (mouseup that must not count as a click).

Two-finger gestures on the touch screen also send `"pinch"` and `"rotate"` (`e.touch` is true, `e.x, e.y` is the
point between the fingers):

- `"pinch"`: `e.scale` is the change in finger distance since the previous pinch event (> 1 = apart, < 1 =
  together). Multiply your zoom by it: `zoom = zoom * e.scale`.
- `"rotate"`: `e.angle` is the change in angle since the previous rotate event, in radians (positive = clockwise).
- Both start only after the fingers moved a little, so a plain two-finger drag stays a `"scroll"`. Two-finger
  `"scroll"` events keep arriving during a pinch or rotate, so you can pan and zoom at the same time.

```lua
function app.event(e)
  if e.type == "pinch" then zoom = math.max(0.25, math.min(8, zoom * e.scale))
  elseif e.type == "rotate" then angle = angle + e.angle end
end
```

Pointer input arrives from touch, the controller cursor (A = click, X = right click, right stick = scroll,
D-pad = arrow keys, B = Escape) and USB mouse/keyboard. Pad events (`paddown`/`padup`) only arrive when
`"gamepad": true`.

Polling: `input.down(button)`, `input.pressed(button)` / `input.released(button)` (this frame),
`input.stick("left"|"right")` → x, y in -1..1 (y up = positive), `input.key(name)` (pressed this frame),
`input.touch()` (the user is on the touch screen).

## 6. Files — `fs`

Relative paths live in the app's private data folder (`~/Library/Application Support/<id>/`, created for you).
`"bundle:/..."` reads files shipped in your package. Absolute paths (`"sdmc:/..."`, `"romfs:/..."`) work too.

`fs.read(path)` → string or nil,err · `fs.write(path, data)` → ok · `fs.append(path, data)` ·
`fs.exists(path)` · `fs.isdir(path)` · `fs.list(path[, showHidden])` → `{ {name, path, dir, size, mtime}, ... }`
(folders first) · `fs.mkdir(path)` · `fs.remove(path[, permanently])` (default: to the Trash) ·
`fs.rename(a, b)` · `fs.copy(a, b)` · `fs.path(relative)` → absolute ·
`fs.dir(which)` → absolute folder for `"data"`, `"bundle"`, `"cache"`, `"home"`, `"documents"`, `"desktop"`,
`"downloads"`, `"pictures"`, `"music"`.

`fs.unzip(zipPath, destDir[, done[, progress]])` (SDK 1.6) unpacks a zip on a background thread; the window keeps
drawing. `done(ok, errOrCount)` runs once at the end: `true` and the number of files written, or `false` and a
message. `progress(doneBytes, totalBytes)` runs at most once a frame while it works. Folders are created, existing
files are overwritten, and entries with absolute paths, drive letters, backslashes or `..` are skipped (zip slip).
A zip with more than 20000 files or more than 1 GB unpacked is refused before anything is written. Both paths
follow the `fs.write` rules: outside the app's own folders they need the `"files"` permission (a refused path comes
back as `done(false, "permission denied: files")`).

```lua
fs.unzip("bundle:/patch.zip", "sdmc:/atmosphere/contents", function(ok, r)
  status = ok and (r .. " files") or ("failed: " .. r)
end, function(done, total) pct = total > 0 and done / total or 0 end)
```

Simple persistence: `store.get(key[, default])`, `store.set(key, value)` (any JSON-like value; saved
automatically within a second and on close), `store.save()`.

JSON: `json.decode(text)` → value or nil,err · `json.encode(value[, pretty])` → text.

## 7. Network — `net`

All requests are asynchronous; the callback runs later on the main thread. HTTPS is supported.

```lua
net.get("https://api.example.com/x", function(res)
  if res.ok then print(res.body) else print(res.status, res.error) end
end)
net.get(url, {["Accept"]="application/json"}, callback)          -- extra headers
net.post(url, body[, contentType], callback)                      -- default x-www-form-urlencoded
net.json(url, function(data, err) end)                            -- GET + json.decode
net.download(url, "files/x.zip", function(ok, pathOrError) end, function(now, total) end)
net.encode("a b&c")                                               -- URL-encode
```

`res`: `ok` (2xx/3xx), `status`, `body`, `error`, `url` (after redirects), `headers` (lowercase names).
Check `sys.online()` first and show a friendly message when offline.

## 8. System — `sys`, `audio`, `timer`, `TR`

`sys.time()` seconds (monotonic, for animation) · `sys.epoch()` Unix time · `sys.date([epoch])` →
`{year, month, day, hour, min, sec, wday (0=Sunday), yday, epoch}` in the console's local time ·
`sys.battery()` → percent, charging · `sys.online()` · `sys.lang()` (`"tr"`, `"en"`, …) · `sys.username()` ·
`sys.model()` · `sys.firmware()` · `sys.notify(title, body)` (notification banner) · `sys.open(path)` (opens with the
right app) · `sys.launch(appId[, arg])` · `sys.clipboard([text])` get/set (no permission needed) · `sys.log(...)` / `print(...)` ·
`sys.title(text)` window title · `sys.exit()` close the window · `sys.fps()` · `sys.vibrate([strength 0..1[, ms]])`
(HD rumble) · `sys.appid()` · `sys.sdkVersion()` → `"1.6"` (see *SDK versions*). `sys.notify`, `sys.launch` (of
another app), `sys.games` and `nxv://` links need their permissions (section 1).

`sys.speak(text[, lang])` (SDK 1.6, no permission) reads text aloud with the built-in voice, after whatever is being
said; the call returns at once. `lang` is `"en"`, `"tr"`, `"de"`, `"fr"`, `"es"`, `"ja"` or `"ko"` (default: the voice
chosen in Settings > Accessibility > Screen Reader, else the interface language; other languages are read with the
English voice). Rate, pitch and volume follow the same settings. `sys.stopSpeaking()` stops the speech and drops
what is queued (the Screen Reader's sentence too). C: `sys_speak(text, lang)` (`lang` may be `NULL`),
`sys_stopSpeaking()`; Java: `Sys.speak(text[, lang])`, `Sys.stopSpeaking()`.

`sys.games([function(list) end])` (SDK 1.6, permission `"games"`) → the games installed on the console:
`{ {id = "0100ABCD12340000", name, version, publisher}, ... }`, most recently played first. `id` is the title id
(16 upper-case hex digits, the folder name under `atmosphere/contents`), `version` the display version of the
installed update (`""` when unknown). The list comes from a cache; the first call in a session starts a scan of the
console, so pass a function to get the complete list once the scan is done (the return value is the list known
right now and may be empty the very first time). On emulators the list is empty.

```lua
sys.games(function(list)
  games = list
  for _, g in ipairs(list) do print(g.id, g.name, g.version) end
end)
```

`audio.tone(freq, seconds[, volume[, wave]])` synthesized note; wave `"sine"`,`"square"`,`"saw"`,`"triangle"`,
`"noise"` → channel · `audio.play(nameOrPath[, volume[, loops]])` system sounds `"click"`,`"pop"`,`"notify"`,
`"alarm"`,`"trash"`,`"shutter"`,`"error"`,`"key"`,`"volume"`,`"startup"` or a `.wav/.ogg/.mp3` file
(`loops = -1` repeats) → channel · `audio.stop(channel)` · `audio.music(path)` stream a song ·
`audio.musicPause(true|false)` · `audio.musicStop()`.

`timer.after(seconds, fn)` → id · `timer.every(seconds, fn)` → id · `timer.cancel(id)`.

`TR(key, ...)` → translated text from your `lang/<code>.json` (falls back to English, then to system strings such as
`TR("common.ok")`, then to the key). `{0}`, `{1}` are replaced by the extra arguments: `TR("score", 42)`.

## 8a. Links, sharing, scheduled notifications, permissions (SDK 1.4)

**Links.** `nxv://` addresses open apps and system places. `sys.open(url)` follows them (needs `"launch"`):

| Link | Opens |
|---|---|
| `nxv://app/<id>?arg=<text>` | the app (brought forward if running) with `<text>` in `app.load(arg)` / `app.open(arg)`; an app that is not installed offers its App Market page |
| `nxv://store/<id>` | the app's page in the App Market |
| `nxv://settings/<pane>` | System Settings at a pane |

`sys.appUrl(id[, arg])` → `"nxv://app/<id>?arg=<percent-encoded arg>"`, a link to put in a note, a QR code or a share.
Text from a link is never treated as a file the user handed over (it grants no file access).
Built-in ids: the file manager is `files`, the app grid `launcher`; the ids earlier builds used for them still work
in `sys.launch`, `nxv://` links and shortcuts.

**Sharing.** `sys.share(textOrPath)` → true · opens the share sheet: a preview, **Copy**, and every app whose
app.json `shareTargets` accepts the item (for files also the built-in apps that open that type). A string with `":/"`
(`"sdmc:/..."`, `"data:/notes.txt"`, `"bundle:/a.png"`) is shared as a file (the app must be allowed to read it;
otherwise nil, `"permission denied: files"` / `"file not found"`), anything else as text. The receiving app gets the
text or path as `arg` (see `shareTargets` in section 1).

**Scheduled notifications** (need `"notifications"`). They are kept on the SD card and posted by the system at the
time, also while the app is closed and after a restart; tapping one starts the app with `arg`.
`sys.schedule(epoch, title[, body[, arg]])` → id, or nil + error (`"time is in the past"`, more than 400 days ahead,
more than 64 pending per app) · `sys.unschedule(id)` → true if it was pending · `sys.scheduled()` →
`{ {id, at, title, body, arg}, ... }` sorted by time. Example: `sys.schedule(sys.epoch() + 25 * 60, TR("break"), TR("time_for_a_break"))`.

**Permissions at run time.** `sys.hasPermission(name)` → true when the call it gates would work now ·
`sys.requestPermission(name[, fn(granted)])` asks the user again for a permission the app declares but the user
refused (at most once per permission and session; without a declaration, or when already answered this session,
`fn(false)` runs at once). It is the only question an app can cause while it runs: gated calls never ask, they fail.
Call it from a button the user pressed ("Turn on network access"), not at start-up.

**Memory.** `sys.memory()` → bytes used, limit (64 MB) of this window's script heap.

**Search.** Define `app.search(query)` (section 2) to answer searches while the app runs: return a list of
`{title, subtitle, icon, arg}` tables (or plain strings: title = arg). Keep it fast; at most 5 items per app are shown.

## 8b. 3D — `g3d`

A small real-time 3D renderer. It runs on the GPU: a real depth buffer, per-pixel lighting, fog and textures, and
30–60k triangles per frame at 60 fps. Meshes are uploaded to the GPU once and stay there, so create them in
`app.load` and reuse them every frame. If the GPU path is unavailable (or the system setting `g3d.gpu` is `false`),
the same calls fall back to the older CPU renderer: depth-sorted colored triangles, no textures, a few thousand
triangles per frame. `g3d.gpu()` tells you which one is active. Right-handed coordinates: x right, y up, z towards
the viewer; angles in radians.

```lua
local cube, ball
function app.load()
  cube = g3d.mesh("cube", 1)          -- also: "box",w,h,d  "sphere",r,seg,rings  "plane",w,d,div
  cube:setColor(theme.accent)         --       "cylinder",r,h,seg  "cone",r,h,seg  "torus",R,r,seg,sides
  ball = g3d.mesh("sphere", 0.5, 32, 20)
end
function app.draw(w, h)
  gfx.clear("#101418")
  local t = sys.time()
  g3d.begin(0, 0, w, h, 60)                       -- viewport x,y,w,h [, fovDeg [, near [, far]]]
  g3d.camera(math.sin(t) * 4, 2, math.cos(t) * 4, 0, 0, 0)   -- eye xyz, target xyz [, up xyz]
  g3d.light(0.5, 1, 0.3, 0.35)                    -- direction to the light [, ambient 0..1 [, color]]
  g3d.fog("#101418", 6, 20)                       -- optional: color, start, end distance
  g3d.draw(cube, 0, 0, 0, t, t * 0.7, 0)          -- mesh, x,y,z [, rx,ry,rz [, sx[,sy,sz] [, tint [, "wire unlit nocull glow"]]]]
  g3d.draw(ball, 1.6, 0, 0, 0, 0, 0, 1, 1, 1, theme.orange)
  g3d.line(0, -1, 0, 0, 2, 0, "#FFFFFF", 2)       -- 3D line
  g3d.point(0, 2.2, 0, 6, theme.yellow)           -- 3D dot (size in pixels)
  local tris = g3d.finish()                       -- sorts and renders everything; returns triangle count
  local sx, sy = g3d.project(0, 2.2, 0)           -- world -> screen (nil if behind the camera), call before finish
end
```

| Function | Description |
|---|---|
| `g3d.mesh(kind, ...)` | primitive mesh (see above); all primitives come with texture coordinates |
| `g3d.load(path[, size])` → mesh or nil,err | load a `.obj` (v/vn/vt/f, optional vertex colors `v x y z r g b`) or `.stl` (binary/ASCII) file, centered and scaled to `size` (default 2). If the `.obj` names a material library (`mtllib`) whose material has a diffuse map (`map_Kd`), that image becomes the mesh texture |
| `g3d.custom({x,y,z,...}, {i1,i2,i3,...}[, {colors per vertex}[, flat[, {u1,v1,u2,v2,...}]]])` | your own triangles (1-based, counter-clockwise when seen from outside), optionally with texture coordinates per vertex |
| `mesh:setColor(c)`, `mesh:flat(true)`, `mesh:triangles()` | |
| `mesh:setTexture(path)` → exists | image (png/jpg/webp/bmp) mapped with the mesh's texture coordinates; `nil` removes it. Paths resolve like `fs` paths (`"bundle:/wood.png"` for a file in your bundle). `mesh:texture()` returns the current path |
| `g3d.gpu()` → bool | `true` when 3D renders on the GPU |
| `g3d.begin`, `g3d.camera`, `g3d.light`, `g3d.fog`, `g3d.draw`, `g3d.line`, `g3d.point`, `g3d.project`, `g3d.finish` | as shown above; draw calls are collected between `begin` and `finish` |

Textures: `u, v` run from 0 to 1 across the image, `(0, 0)` is its top-left corner and values outside 0..1 repeat
the image. A textured mesh shows the image instead of its `setColor` color; per-vertex colors and the draw tint still
multiply it, and lighting and fog apply as usual. Texture pixels with alpha below 50% are cut out (leaves, fences);
for see-through surfaces use a tint or colors with alpha. Textures need the GPU path; the CPU fallback draws the mesh
color instead.

Notes: translucent meshes (tint, mesh or vertex colors with alpha below 255) are drawn after the opaque ones,
sorted back to front per mesh. Geometry beyond `far` is clipped, so pass a `far` that covers your scene. `"wire"`
draws every triangle edge as a 1-pixel line.

Glow: the `"glow"` flag adds the mesh's color to whatever is behind it instead of covering it (additive blending), so
overlapping parts get brighter: stars, sparks, light trails, lamp halos. Glow meshes are drawn after everything else,
are hidden by solid geometry in front of them but do not hide anything themselves, and fog fades them out. Use dark
colors for faint light and combine with `"unlit nocull"`; a texture whose edges fade to black gives soft round
sprites. The CPU fallback draws glow meshes as normal meshes.

Native apps (C++) also get `g3d::append(dst, src, matrix, color)`, which merges a transformed copy of a mesh into
another one (cheap instancing: hundreds of objects, one draw), `DrawOpts::additive` (the `"glow"` flag) and
`g3d::lastDrawCalls()` next to `g3d::lastTriangles()`.

Motion controls: `input.motion()` → `ax, ay, az` (acceleration in G), `gx, gy, gz` (angular velocity in rad/s),
`pitch, roll, yaw` (accumulated rotation in radians) from the Joy-Con / Pro Controller / handheld gyroscope.

## 8c. 2D oyun motoru (nexvyn.game)

`nexvyn.game` is a small 2D engine written in Lua on top of `gfx`, `input`, `audio` and `store`. It ships with the
system in `romfs:/System/Lua/nexvyn/`, so any app can `require("nexvyn.game")` (§2: `require` looks in the bundle first,
then in the system library). Tutorial: `docs/GAME_ENGINE.en.md`. Samples: `pixelrun.nxvapp` (platformer) and
`spacearena.nxvapp` (arena shooter) in `romfs/Applications/`.

### First game (30 lines)

```lua
local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui

local Play = {controls = true}               -- controls: on-screen stick/buttons after a touch
function Play:enter()
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
function Play:update(dt)
  local mx, my = I.vector()                  -- stick, d-pad, arrows/WASD or the touch stick
  self.hero.ax, self.hero.ay = mx * 900, my * 900
  self.world:update(dt)
end
function Play:draw() self.world:draw() end
function Play:ui() U.text(TR("score", self.score), 8, 6, 14) end
function Play:restart() self:enter() end      -- adds "Restart" to the pause menu

return game.run{width = 480, height = 270, scene = Play, background = "#1B2A41"}
```

Games should set `"gamepad": true` and `"resizable": true` in app.json (resizable games open full screen).

### Engine loop: `game.run(config)` returns the app table

`main.lua` ends with `return game.run{...}`. Fields: `width`, `height` (design size of the virtual screen), `scale`
(`"expand"` (default): the design size always fits and the longer side grows, no bars; `"fit"`: fixed size with bars;
`"pixel"`: like fit with a whole-number scale; `"none"`: 1 unit = 1 pixel), `scene`, `params`, `title` (the pause menu
offers "Main menu"), `background`, `border` (bar colour), `step` (fixed update step, default 1/60), `gamepad` (match
app.json, default true), `debug`, `controls` (actions the player may rebind from the pause menu: names or
`{action, label}`), `load(arg)`, `update(realDt)`, `menu()`, `onmenu(id)`, `close()`.

Updates run in fixed steps; drawing happens once per frame. The pause menu opens on **+**, **Esc**, **P**, the touch
pause button, or when the window seems unfocused (the SDK has no focus query: a controller press that does not reach
the app, or a window that stops being drawn, counts as unfocused). Live values: `game.width`, `game.height` (virtual
size), `game.scale`, `game.time`, `game.realTime`, `game.dt`, `game.paused`, `game.focused`, `game.debug` (F3).
`game.toVirtual(px, py)` converts window pixels. `game.pause()`, `game.resume()`. Helpers: `game.class(parent)`,
`game.clamp`, `game.lerp`, `game.approach`, `game.sign`, `game.dist`, `game.angle`, `game.rand(a, b)`, `game.choose(t)`,
`game.smooth(f, dt)`, `game.rgba(color)`, `game.chance(percent)`, `game.randInt(a, b)`,
`game.weighted({{value, weight}, ...})`, `game.flash(color[, sec[, alpha]])` (full-screen colour that fades out),
`game.str(key)` (engine texts in Turkish and English; an app overrides them
with `game.<key>` entries in its lang files: `paused`, `resume`, `restart`, `sound`, `on`, `off`, `touch`, `auto`,
`menu`, `quit`, `controls`, `press_key`, `reset_controls`, `controls_reset`, `back`).

### Scenes

| Call / field | |
|---|---|
| `game.switch(scene[, params[, {fade = 0.3, color}]])` | replace the stack (fade out, enter, fade in) |
| `game.push(scene[, params[, opts]])`, `game.pop([result])` | overlays; `pop` passes `result` to `resume` |
| `game.current()` | top scene |
| `opts.transition` | `"fade"` (default), `"slide"` (`opts.dir = "left"`, `"right"`, `"up"`, `"down"`), `"wipe"`, `"circle"` (iris), `"blinds"`, `"pixels"`; `opts.fade` is the duration of each half; `game.scene.defaultTransition` changes the default |
| methods | `enter(params)`, `leave()`, `pause()`, `resume(result)`, `update(dt)`, `draw()`, `ui()` (HUD, after draw), `event(e)` (raw SDK event plus `e.vx, e.vy` in virtual units), `restart()` |
| fields | `transparent` (draw scenes below), `updateBelow`, `controls` (touch controls), `pausable = false` (title screens), `background`; the engine adds `scene.tweens` |

### Drawing: `game.gfx`

The `gfx` calls in game units through the current transform (virtual screen, then camera): `color`,
`rect(x, y, w, h[, r[, c]])`, `rectLine`, `circle`, `circleLine`, `line`, `gradient`, `poly(pts[, c])`,
`lines(pts[, t[, closed]])`, `polyT(pts, x, y, angle, sx, sy[, c])` and `linesT(...)` (a local shape rotated, scaled and
moved without creating tables), `text(s, x, y[, size[, font[, align, width]]])`, `textWidth`, `icon`,
`image(img, x, y[, w, h[, tint]])`, `region(img, sx, sy, sw, sh, x, y, w, h[, deg])`, `alpha(a)`/`unalpha()`,
`clip`/`unclip`, `push(dx, dy[, s])`/`pop()`, `transform()`, `toScreen`, `fromScreen`, `visible(x, y, w, h)`.

### Sprites and animation

| Call | |
|---|---|
| `game.sheet(path, frameW, frameH[, {margin, spacing, count, flipped, scale}])` | sprite sheet; `flipped` = a mirrored copy of the image for `flipX`; `scale` = world units per image pixel (store pixel art at 4x and use 0.25) |
| `game.animations{name = {frames = "1-4,6" or {1, 2}, fps = 10, loop = true}}` | |
| `game.sprite{...}`, `game.Sprite` (class) | `x, y` (origin = hitbox centre), `ox, oy` (0..1, default 0.5), `rotation`, `sx, sy`, `flipX`, `alpha`, `tint`, `z`, `visible`, `dx, dy` (draw offset), `sheet` or `image`, `frame`, `anims`; shape sprites: `shape = "rect"/"circle"`, `color` |
| `sprite:play(name[, restart])`, `sprite.onAnimEnd`, `sprite.animSpeed` | |
| override `sprite:render()` | custom drawing with `game.gfx` (alpha already applied) |

Subclass: `local Enemy = game.class(game.Sprite)`, `function Enemy:init(o) game.Sprite.init(self, o) ... end`,
`Enemy{x = 10, y = 20}`. SDK limits: image regions cannot be mirrored or tinted, so `flipX` needs the `flipped` image,
and `tint` only works for single images drawn without rotation.

### World, groups, physics, collision

| Call | |
|---|---|
| `game.world{gravity = 900 or {x, y}, map = tilemap, camera = cam, cell = 64}` | |
| `world:add(e, "group", ...)`, `world:remove(e)` or `e.dead = true` | entity hooks `e:update(dt)`, `e:draw()`, `e:added(w)`, `e:removed()`; `e.active = false` freezes it |
| `world:group(name)` | `group.n`, `group[i]`, `:add`, `:remove`, `:has`, `:each(fn)`, `:count()`, `:nearest(x, y[, max])` |
| `world:collide(a, b, fn[, separate])` | a, b = entity, group or group name; `fn(ea, eb)` on overlap; groups use a spatial hash; `separate` pushes boxes apart |
| `world:trigger{x, y, w, h or entity = e, filter, onEnter, onExit, onStay}` | zones |
| `world:query(x, y, w, h[, group])` | overlapping entities (reused list with `.n`) |
| `world:addEmitter(em)`, `world:update(dt)`, `world:draw()`, `world:clear()` | draw = map, entities by z (camera-culled), emitters, map layers marked `above`, debug colliders |

Bodies (`body = true`): `vx, vy, ax, ay`, `gravity` (scale), `dragX, dragY`, `damping`, `maxVx, maxVy`, `bounce`,
`collideMap`, `dropThrough`, `immovable`, `static`; hitbox `w, h` or `r`. After each step: `onFloor`, `onCeiling`,
`onWall` (-1/0/1), `hitX`, `hitY`. `game.physics`: `aabb`, `circles`, `circleRect`, `pointIn`, `overlap(a, b)`,
`separate(a, b)`, `moveAndCollide(e, dx, dy, map)`, `integrate`, `hash(cell)` with `:insert(e)`, `:clear()`,
`:query(x, y, w, h, out)`.

### Tilemaps: `game.tilemap`

| Call | |
|---|---|
| `game.tilemap{tileSize, width, height, tileset = sheet, tiles = {[id] = {solid, oneway, color, draw, ...}}, layers = {{name, data, collide, above, parallax, alpha}}, objects, edges}` | ids are 1-based tileset frames, 0 = empty |
| `game.tilemap.fromStrings(rows, legend[, {tileSize, tileset, tiles, edges}])` | `legend["#"] = 1`, `legend.o = {object = "coin"[, tile = id]}` |
| `game.tilemap.fromJSON(textOrTableOrPath[, baseDir])` | simple JSON format (see `nexvyn/game/tilemap.lua`) |
| `game.tilemap.fromTiled(pathOrTable[, {baseDir, tiles, edges}])` | Tiled JSON export: orthogonal, CSV layers, first tileset, object layers, properties `solid`, `oneway`, `collide`, `above` |
| `map:path(x0, y0, x1, y1[, {diagonal, maxNodes, cost, avoid}])` | A* from the tile of (x0, y0) to the tile of (x1, y1): `{x1, y1, ...}` world points (tile centres) or nil; solid tiles block, one-way tiles do not; `avoid(tx, ty)` blocks more tiles, `cost(tx, ty)` adds a cost, `maxNodes` (default 6000) caps the search |
| `game.path.find(w, h, passable, sx, sy, gx, gy[, opts])` | A* on any grid: `passable(tx, ty)` → bool; returns `{tx1, ty1, ...}` (0-based tiles, start excluded) or nil |
| `map:get/set(tx, ty[, layer])`, `map:solid(tx, ty)` (0 empty, 1 solid, 2 one-way), `map:toTile`, `map:toWorld`, `map:tileAt(x, y)`, `map:findTile(x, y, w, h, flag)`, `map:objectsOf(type)`, `map:draw(cam[, "above"])`, `map:rebuild()` | `map.pixelWidth`, `map.pixelHeight`, `map.objects` |

Visual editors in Nexvyn OS Studio: open a `.png` for the sprite editor (frames, palette, onion skin, preview; the frame
size goes to `<name>.sprite.json`, and `<name>_flip.png` is rewritten on save when it exists), a `.map.json` for the
tilemap editor (writes the `fromJSON` format: tileset, `tiles` flags, layers, objects) and a `.scene.json` for the
scene editor. Load a scene with `game.loadScene(path[, {world, types = {type = Class}, baseDir, groups}])` → `level`
with `width`, `height`, `grid`, `background`, `entities`, `byName`, `level:ofType(type)`; each entry becomes
`types[type](o)` or `game.sprite(o)` (`x, y` centre, `rotation` stored in degrees, `props` copied as fields) and is
added to `world` in a group named after its type. Format: `romfs/System/Lua/nexvyn/game/loader.lua`.

### Camera: `game.camera{x, y, zoom, lerp, deadzone = {w, h}, offsetX, offsetY, bounds, round}`

`cam:follow(target[, lerp[, dzW, dzH]])`, `cam:setBounds(x, y, w, h)`, `cam:clearBounds()`, `cam:shake(amount, sec)`,
`cam:lookAt(x, y)`, `cam:snap()`, `cam:update(dt)`, `cam:attach([parallax])` / `cam:detach()`, `cam:view()` (x, y, w, h),
`cam:toWorld(vx, vy)`, `cam:toView(wx, wy)`, `cam:screenToWorld(px, py)`, `cam:zoomTo(z, sec[, ease])`,
`cam:panTo(x, y, sec[, ease])` (the target is not followed during the pan), `cam:animating()`, `cam:kick(dx, dy)`
(a push that springs back: recoil, landings), `cam:visible(x, y, w, h[, margin])` (culling for custom drawing).

### Lights: `game.lights{ambient, color, cell, levels}`

A darkness overlay with soft light holes. `ambient` (0..1) is the darkness where no light reaches, `color` its
colour, `cell` the cell size in virtual units (default 8), `levels` the darkness steps (default 12). `lights:add{x, y,
radius, intensity, flicker, on}` → light (change its fields any time), `lights:remove(l)`, `lights:clear()`,
`lights:setColor(c)`, `lights:draw([cam])` (after the world, before the HUD; positions are world units when a camera is
given). Equal neighbouring cells of a row are drawn as one rectangle.

### Input actions: `game.input`

`bind(name, {pad = {...}, key = {...}, axis = {"lx-", "ly+", "rx+", ...}, touch = {"stick:up", "button:id"}}[, add])`,
`unbind`, `down(name)`, `pressed(name)`, `released(name)` (per update step), `anyPressed()`, `axis(neg, pos)`,
`vector()` (move vector, y down), `aim()` (right stick), `sticks()`, `reset()`, `pointer` (`x, y` in virtual units,
`down`, `pressed`, `released`, `framePressed`, `frameReleased`, `downX, downY`, `touch`),
`touchControls{stick = true, pause = true, buttons = {{id, icon, label, action}}}`, `setTouchMode("auto"|"on"|"off")`,
`touchVisible()`. Rebinding: `setBinding(name, "key"|"pad", value)` (replaces the first key / pad button and survives
a later `bind` of the action), `binding(name, kind)`, `bindingLabel(name)` (`"Space / A"`),
`listen(fn[, sec])` (the next key or pad press calls `fn(kind, value)` instead of reaching the game; Escape or the
timeout calls `fn(nil)`), `listening()`, `cancelListen()`, `resetBindings()`, `saveBindings(slot)`,
`loadBindings(slot)` (the engine loads and saves them with its settings). Default actions: `left`, `right`, `up`, `down`, `confirm`, `back`, `pause`. The touch controls
appear after the screen is touched and hide when a button or key is used. The SDK reports one pointer, so the stick
and a button cannot be held together: bind important actions to stick directions too (`"stick:up"` for jump).

### Tweens and timers: `game.tween`

`game.tween.to(target, sec, {field = value}[, ease or {ease, delay, onComplete, onUpdate}])` returns a tween with
`:ease`, `:delay`, `:oncomplete`, `:onupdate`, `:after(target, sec, props[, ease])` (chain), `:call(fn)`, `:cancel()`.
`game.tween.after(sec, fn)`, `game.tween.every(sec, fn[, count])`. Easings in `game.tween.ease`: `linear`,
`inQuad`, `outQuad`, `inOutQuad`, `inCubic`, `outCubic`, `inOutCubic`, `inQuart`, `outQuart`, `inSine`, `outSine`,
`inOutSine`, `inExpo`, `outExpo`, `inOutExpo`, `inBack`, `outBack`, `inOutBack`, `inElastic`, `outElastic`,
`inOutElastic`, `inBounce`, `outBounce`, `inOutBounce`, `inOutQuart`, `inQuint`, `outQuint`, `inOutQuint`, `inCirc`,
`outCirc`, `inOutCirc`, `smoothstep`; `game.tween.steps(n)` is a staircase easing. `tween:loop([count[, yoyo]])`
repeats (`count` more times, nil or 0 = forever; `yoyo` plays every other pass backwards).
`game.tween.from(target, sec, props[, ease])` jumps to `props` and tweens back to the current values. Tweens belong
to the top scene and stop while it is paused.

### Particles: `game.emitter{...}`

Options: `x, y, max, rate, life = {min, max}, speed = {min, max}, angle, spread, gravity, gravityX, damping,
size = {start, end}, sizeVar, colors = {...}` (interpolated over life, `#RRGGBBAA`), `shape = "circle"|"square"|"line"`,
`lineScale`, `offset`. Methods: `emit(n[, x, y[, angle]])`, `start()`, `stop()`, `moveTo(x, y)`, `setColors(list)`,
`update(dt)`, `draw()`, `clear()`; `em.count`. `area = {w, h}` spawns anywhere in a box centred on x, y.
Presets: `game.particles.preset(name[, overrides])` → emitter, with `name` one of `"explosion"`, `"smoke"`,
`"sparkle"`, `"rain"`, `"snow"`, `"fire"`, `"confetti"`, `"dust"`, `"blood"`, `"magic"`;
`game.particles.burst(world, name, x, y[, n[, angle]])` emits through one shared emitter per preset and world.

### Audio, UI, save, debug

- `game.audio`: `define(name, {notes = "E6:0.05 B6:0.12" or {{freq, sec}}, wave, volume})`, `play(nameOrFile[, vol])`
  (built-in effects `jump`, `coin`, `hit`, `explode`, `shoot`, `power`, `select`, `confirm`, `lose`, `win`, system
  sounds or files), `tone`, `music(path)`, `stopMusic`, `pauseMusic`, `song{notes, bass, bpm, div, wave, volume}`
  (looping synth tune), `stopSong`, `setMuted(b)`, `muted`, `freq("A4")`.
- `game.ui`: `text(s, x, y[, size[, color[, align, width[, font[, shadow]]]]])`, `panel`, `bar(x, y, w, h, value[, c])`,
  `pixelText(s, x, y[, px[, color[, align, width]]])` (3x5 pixel font), `pixelWidth`,
  `score(n, x, y[, px[, color[, digits[, align]]]])`, `button(label, x, y, w, h)` (true when tapped),
  `menu{items = {{label, action, enabled, left, right}}, width, itemHeight, size, title, onBack}` with `:update()`
  (pad, keys and pointer) and `:draw(cx, y)`; `game.toast(text[, sec])`;
  `hearts(n, max, x, y[, size[, color[, icon]]])` (partial icons for fractions), `slider(value, x, y, w, h[, color])`
  → 0..1, `toggle(on, x, y[, w, h[, color]])` → bool, `iconButton(icon, cx, cy[, size[, color]])` → tapped,
  `dialog{title, text, buttons, onClose(index), width, color}` (modal scene; back = index 0),
  `dialogue{lines = {"text" or {who, text}}, speed, onDone, height, color, blip}` with `:update(dt)`, `:draw()`,
  `.done` (typewriter box; confirm or a tap completes the line, then advances).
- `game.save`: `game.save.open(name)` with `:get(k, default)`, `:set(k, v)`, `:inc(k[, n])`, `:best(k, v[, lower])`
  (true for a new record), `:reset()`, `:exists()`, `:delete()`, `:stamp([summary])`, `:copyTo(slot)`;
  `game.save:get/set` use the default slot. Numbered slots: `game.save.slot(i)`, `game.save.slots(n)` → list of
  `{index, used, summary, savedAt, when, save}`. Data is kept in the app's `store`.
- Debug overlay: F3 or `game.debug = true`: FPS, steps, update and draw time, entities, bodies, particles, colliders,
  a graph of the last 90 frame times, the pointer in virtual and world units, and `game.watch(name, value)` entries
  (`game.unwatch(name)`).

## 9. Design guidelines

- Use `theme` colors, rounded corners (6–12 px), the `ui` widgets, `"semibold"`/`"bold"` for headings, 13–15 px body
  text. Leave 16–20 px margins.
- Make every interactive element at least 28 px tall — the console is used with fingers and a stick cursor.
- Games: set `"gamepad": true`, support D-pad/stick + A/B, and also touch where possible; show controls on screen.
- Save user data with `store` or `fs` as soon as it changes.
- Keep `app.draw` fast: avoid creating big tables every frame; load images once.

## 10. Complete example

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

function app.load()
  count = store.get("count", 0)
end

function app.draw(w, h)
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

function app.event(e)
  if e.type == "keydown" and e.key == "space" then count = count + 1; store.set("count", count) end
end

return app
```

## 11. JavaScript

> **TR — Özet:** Uygulamalar Lua yerine JavaScript ile de yazılabilir: `app.json` içinde `"main": "main.js"` yazın.
> API aynıdır (`gfx`, `ui`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `TR`, `g3d`); farklar
> aşağıdaki tablodadır: diziler 0'dan başlar, `nil` yerine `null`, çoklu dönüş değerleri dizi olarak gelir, geri
> çağırma (callback) vermezseniz asenkron fonksiyonlar Promise döndürür (`await net.fetchJson(url)`), dosyalar
> arasında `import` kullanılır. Türkçe kısa rehber: `docs/JS_APPS.en.md`. Örnek: `romfs/Applications/hellojs.nxvapp`.

Everything in sections 1–10 applies to JavaScript apps too; this section lists only what is different.

### Choosing JavaScript

Set `"main": "main.js"` in `app.json` (any `.js`/`.mjs` file works, or keep another name and add `"runtime": "js"`).
The bundle layout is the same: `app.json`, `icon.png`, `lang/*.json`, your `.js` files and assets.

The engine is QuickJS-ng: modern JavaScript (ES2023: `let`/`const`, classes, arrow functions, destructuring, spread,
template strings, `async`/`await`, generators, `Map`/`Set`, typed arrays, `BigInt`, `RegExp`, `JSON`, `Math`, `Date`).
Each window runs its own engine with a **64 MB** heap limit; a callback that runs longer than **3 seconds** is
stopped, and errors open the same error screen as Lua (message, stack trace with `file.js:line:column`, **Reload**).
There is no browser or Node.js API: no `window`, `document`, `fetch`, `XMLHttpRequest`, `localStorage`, `require`,
`process` or `Intl` — use the SDK modules. `Date` works; for the console's local time zone use `sys.date()`.

### Program structure

`main.js` is an **ES module** (strict mode). Assign your callbacks to the global `app` object — or
`export default` an object with them. The callbacks and their arguments are the ones from section 2.

```js
import { formatScore } from "./util.js";   // other files of the bundle; also "./data.json" (default export)

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
app.close = () => true;                    // return false to keep the window open
```

Modules: `import` paths are relative to the importing file and stay inside the bundle (`"./x.js"`, `"../lib/y.js"`;
a bare `"util"` means `util.js` at the bundle root). `import data from "./levels.json"` gives the parsed JSON.
Dynamic `import()` works too. Top-level `await` is allowed in `main.js`; `app.load` runs when it has finished.
Promise jobs (`await`, `.then`) run every frame.

### Differences from Lua

| Topic | Lua | JavaScript |
|---|---|---|
| Indexes | 1-based | **0-based**: `ui.segmented` / `ui.dropdown` selected index, `ui.alert` button index, `g3d.custom` vertex indices, default `ui.contextMenu` ids |
| No value | `nil` | `null`: `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` return `null` on failure; `store.get(key)` of a missing key without default returns `undefined` |
| Several results | `local w, h = gfx.size()` | an array: `const [w, h] = gfx.size()`. Same for `ui.mouse()` → `[x, y, down, hovering]`, `ui.beginScroll(...)` → `[scrollY, scrollX]`, `sys.battery()` → `[percent, charging]`, `input.stick()` → `[x, y]`, `input.motion()` → `[ax, ay, az, gx, gy, gz, pitch, roll, yaw]`, `g3d.project(...)` → `[sx, sy, depth]` or `null` |
| `ui.textfield` | `text, submitted = ui.textfield(...)` | returns the new text only: `text = ui.textfield("name", text, x, y, w)`; `ui.submitted("name")` is `true` on the frame Enter was pressed in that field |
| `ui.row` | `clicked, doubleClicked` | a number: `0` nothing, `1` clicked, `2` double-clicked (`if (ui.row(...))` works) |
| Colors | `"#hex"`, `{r,g,b[,a]}`, numbers | `"#hex"`, `[r, g, b, a]`, `{r, g, b, a}`, or 3–4 numbers where noted |
| Tables | `{1, 2}`, `{key = v}` | arrays `[1, 2]` and objects `{key: v}` (`gfx.poly([x1, y1, x2, y2, ...])`) |
| Meshes | `mesh:setColor(c)` | `mesh.setColor(c)`, `mesh.flat(true)`, `mesh.triangles()`, `mesh.setTexture(path)`, `mesh.texture()` |
| Images | `img.width` | `img.width`, `img.height`, `img.path`; `gfx.draw` also accepts a path string |
| Printing | `print(...)` | `console.log/info/warn/error(...)`, `print(...)`, `sys.log(...)`: arguments joined with spaces, objects written as JSON |
| Timers | `timer.after/every/cancel` (seconds) | the same, plus `setTimeout`/`setInterval`/`clearTimeout`/`clearInterval` (milliseconds) and `await timer.sleep(seconds)` |
| JSON | `json.encode/decode` | the same (`json.decode` returns `null` for invalid text); `JSON.parse`/`JSON.stringify` work too |
| Modules | `require("name")` | `import ... from "./name.js"` |
| Async errors | — | a rejected Promise that nobody handles is reported like a thrown error (error screen) — wrap `await` in `try`/`catch` |

### Promises

Every SDK function that takes a callback returns a **Promise** when you leave the callback out:

| Callback form | Promise form | Resolves with |
|---|---|---|
| `net.get(url[, headers], cb)` | `await net.get(url[, headers])` | `res` (never rejects — check `res.ok`) |
| `net.post(url, body[, contentType][, headers], cb)` | `await net.post(url, body[, contentType][, headers])` | `res` |
| `net.json(url, (data, err) => {})` | `await net.json(url)` or `await net.fetchJson(url[, headers])` | the parsed data; **rejects** with an `Error` (`e.message`: network error, `"HTTP 404"`, `"invalid JSON: ..."`) |
| `net.download(url, path, (ok, pathOrError) => {}[, progress])` | `await net.download(url, path[, null, progress])` | the absolute path; rejects on failure |
| `fs.unzip(zip, dest, (ok, errOrCount) => {}[, progress])` | `await fs.unzip(zip, dest[, null, progress])` | the number of files written; rejects on failure |
| — | `await net.fetch(url, {method, headers, body, contentType})` | `res`; an object `body` is sent as JSON |
| `ui.alert(title, msg, buttons, (i) => {})` | `await ui.alert(title, msg, buttons)` | button index (0-based) |
| `ui.prompt(title, msg, initial, (text) => {})` | `await ui.prompt(title, msg, initial)` | text or `null` |
| `ui.openFile(cb, exts[, title])` | `await ui.openFile(exts[, title])` | path or `null` |
| `ui.saveFile(cb, name[, title])` | `await ui.saveFile(name[, title])` | path or `null` |
| `ui.keyboard(initial, cb[, guide])` | `await ui.keyboard(initial, null[, guide])` | text or `null` |
| `ui.contextMenu(items, (id) => {})` | `await ui.contextMenu(items)` | item id (never settles if the menu is dismissed — prefer the callback) |
| `timer.after(seconds, fn)` | `await timer.sleep(seconds)` | — |

`net.request({url, method, body, contentType, headers}[, cb])` is the general form behind `net.fetch`. `res` has
`ok`, `status`, `body`, `error`, `url`, `headers` and `contentType`.

```js
let weather = null, error = "";
async function refresh() {
  try {
    const data = await net.fetchJson("https://api.open-meteo.com/v1/forecast?latitude=41&longitude=29&current=temperature_2m");
    weather = data.current;
  } catch (e) {
    error = e.message;          // offline, HTTP error or invalid JSON
  }
}
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  if (ui.button(TR("refresh"), 20, 20, 140, 32, "primary")) refresh();   // runs in the background
  gfx.color(error ? theme.red : theme.text);
  gfx.text(error || (weather ? `${weather.temperature_2m}°` : "…"), 20, 70, 24);
};
```

### SDK 1.4 in JavaScript

`app.search = (q) => [{ title, subtitle, icon, arg }]`, `app.suspend`, `app.resume`, `app.focus = (focused) => {}`,
`app.autosave`, `app.unsaved = () => dirty` work like in Lua. `sys.memory()` → `[used, limit]`.
`sys.requestPermission(name)` returns a `Promise<boolean>` without a callback (`if (await sys.requestPermission("network")) ...`).
Gated calls without their permission return `false`; `sys.schedule` returns the
id and throws a `RangeError` for a time in the past, too far ahead or over the quota. `sys.share`, `sys.unschedule`,
`sys.scheduled()` (array of `{id, at, title, body, arg}`), `sys.hasPermission`, `sys.appUrl` and `sys.open("nxv://...")`
are as in section 8a.

SDK 1.6: `sys.games([callback])` returns an array of `{id, name, version, publisher}` (`null` without the `"games"`
permission); the callback gets the complete array after the console scan. `fs.unzip` is in the Promise table above.

### JavaScript-only extras

`fs.readBytes(path)` → `Uint8Array` or `null`; `fs.write`, `fs.append` and `net.post` also accept a `Uint8Array`
or `ArrayBuffer`. `ui.submitted(id)`. `net.fetch`, `net.fetchJson`, `net.request`. `timer.sleep`.

### Complete example

`Counter.nxvapp/app.json`: the manifest from section 10 plus `"main": "main.js"`. Same `lang/*.json`.
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

A larger example (to-do list with `store`, a clock drawn with `gfx`, `await net.fetchJson`, ES modules) is
`romfs/Applications/hellojs.nxvapp`. Check a bundle on the PC with `node tools/js_check.mjs path/to/App.nxvapp`.

## 12. Python

> **TR — Özet:** Uygulamalar Python ile de yazılabilir: `app.json` içinde `"main": "main.py"` ve `"minSdk": "1.3"`
> yazın. API aynıdır (`gfx`, `ui`, `fs`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `theme`, `json`, `TR`,
> `g3d`) ve `import` gerekmez. Farklar: indeksler JS gibi 0'dan başlar, boş değer `None`, çoklu dönüş değerleri
> demet (tuple) olur, isteğe bağlı argümanlar adıyla verilebilir (`gfx.text("Hi", 10, 10, size=20)`), asenkron
> çağrılar geri çağırma (callback) alır. Türkçe kısa rehber: `docs/PY_APPS.en.md`. Örnek:
> `romfs/Applications/hellopy.nxvapp`.

Everything in sections 1–10 applies to Python apps too; this section lists only what is different. Python needs
SDK 1.3: put `"minSdk": "1.3"` in `app.json`.

### Choosing Python

Set `"main": "main.py"` in `app.json` (any `.py` file works, or keep another name and add `"runtime": "python"`).
The bundle layout is the same: `app.json`, `icon.png`, `lang/*.json`, your `.py` files and assets.

The interpreter is pocketpy 2 (Python 3 syntax: classes, comprehensions, f-strings, lambdas, `*args`/`**kwargs`,
decorators, generators with `yield`, `with`, `match`, the walrus operator). Standard modules: `math`, `random`, `time`,
`json`, `collections`, `functools`, `heapq`, `bisect`, `dataclasses`, `datetime`, `operator`, `typing`. There is no
`os`, `open()`, `socket` or `threading` — use the SDK modules. Each window runs its own interpreter (at most 16
Python windows at a time) with a **64 MB** memory limit; a callback that runs longer than **3 seconds** is stopped.
Errors open the same error screen as Lua and JavaScript: the exception line first, then the traceback
(`File "main.py", line 12, in draw`), with **Reload** and **Copy**.

Interpreter differences from CPython that matter in practice (`tools/py_check.py` reports them with line numbers):
no generator expressions (`sum(x for x in a)` → `sum([x for x in a])`), no implicit string concatenation
(`"a" "b"` → `"a" + "b"`), no `nonlocal`, no `try ... finally`, no `async`/`await`, no `*x` inside a list display
(`[*a, 1]` → `list(a) + [1]`), and some built-ins take no keyword arguments (`dict(a=1)` → `{"a": 1}`).

### Program structure

The SDK modules are built in (no `import`). Give the callbacks of section 2 either as methods of a module-level
**`app`** object, or as plain functions in `main.py` when there is no `app`:

```python
from util import format_score   # other files of the bundle: util.py, or pkg/__init__.py for `import pkg`


class Game:
    def load(self, arg):
        self.count = store.get("count", 0)

    def update(self, dt):          # define update only for animation: the window is then redrawn every frame
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
        return True                # return False to keep the window open


app = Game()                       # `app = Game` works too: a class is instantiated
```

`import` loads `.py` files from the bundle only (compiled `.pyc` files are not loaded). `print(...)` and
`sys.log(...)` write to the app's log. `exit()` / `sys.exit()` close the app's window; `input()` returns `""`.

### Differences from Lua

| Topic | Lua | Python |
|---|---|---|
| Indexes | 1-based | **0-based**: `ui.segmented` / `ui.dropdown` selected index, `ui.alert` button index, `g3d.custom` vertex indices, default `ui.contextMenu` ids |
| No value | `nil` | `None`: `fs.read`, `json.decode`, `gfx.image`, `g3d.load`, `g3d.project` return `None` on failure; `store.get(key)` of a missing key returns the default (or `None`) |
| Several results | `local w, h = gfx.size()` | a tuple: `w, h = gfx.size()`. Same for `ui.mouse()` → `(x, y, down, hovering)`, `ui.beginScroll(...)` → `(scroll_y, scroll_x)`, `sys.battery()` → `(percent, charging)`, `input.stick()` → `(x, y)`, `input.motion()` → 9 numbers, `g3d.project(...)` → `(sx, sy, depth)` or `None` |
| Optional arguments | positional | positional or **by name**, with the names below: `gfx.text("Hi", 10, 10, size=20, font="bold")`, `ui.button("OK", x, y, 90, 30, style="primary")`. `None` means "use the default" |
| Records | tables (`e.type`) | events, `sys.date()`, `ui.hit()`, network responses, `fs.list()` entries and `gfx.image()` are records: attributes (`e.type`, `d.hour`, `res.ok`) that can also be read like a dict (`e["key"]`, `res.get("body")`) |
| `ui.textfield` | `text, submitted = ui.textfield(...)` | returns the new text only; `ui.submitted("name")` is `True` on the frame Enter was pressed in that field |
| `ui.row` | `clicked, doubleClicked` | an int: `0` nothing, `1` clicked, `2` double-clicked |
| Colors | `"#hex"`, `{r,g,b[,a]}`, numbers | `"#hex"`, a tuple/list `(r, g, b[, a])`, a dict `{"r": .., "g": .., "b": ..}`; `gfx.color(r, g, b[, a])` |
| Tables | `{1, 2}`, `{key = v}` | lists `[1, 2]` and dicts `{"key": v}`; `menu()` returns a list of dicts, `"-"` is a separator |
| Meshes | `mesh:setColor(c)` | `mesh.setColor(c)`, `mesh.flat(True)`, `mesh.triangles()`, `mesh.setTexture(path)`, `mesh.texture()` |
| Bytes | strings | `fs.readBytes(path)` → `bytes`; `fs.write`, `fs.append` and `net.post` take `str` or `bytes` |
| `sys` | SDK only | merged with Python's `sys` (`sys.platform`, `sys.argv` are there too); `import sys` gives the same module |
| JSON | `json.encode/decode` | the same (`json.encode(v, True)` pretty-prints, `json.decode` returns `None` for invalid text); `json.dumps/loads` work too |
| Modules | `require("name")` | `import name` / `from name import f` |

Function names are the SDK's (`textWidth`, `beginScroll`, `iconButton`, `sdkVersion`...). Argument names used for
keywords: `gfx.rect(x, y, w, h, r, color)`, `gfx.text(s, x, y, size, font, align, w)`,
`gfx.wrap(s, x, y, w, size, font, align, spacing)`, `gfx.draw(img, x, y, w, h, r, tint)`,
`ui.button(label, x, y, w, h, style, icon, enabled)`, `ui.iconButton(icon, x, y, w, h, tint, active, id)`,
`ui.textfield(id, text, x, y, w, h, placeholder, flags)`, `ui.slider(id, value, lo, hi, x, y, w, step)`,
`ui.segmented(id, items, selected, x, y, w, h)`, `ui.label(s, x, y, size, color, font)`,
`g3d.draw(mesh, x, y, z, rx, ry, rz, sx, sy, sz, tint, flags)`, `audio.tone(freq, sec, volume, wave)`,
`store.get(key, default)`. `python tools/py_check.py` checks every call against the real signatures.

### Callbacks instead of Promises

Asynchronous functions take a callback; without one the call still runs and its result is dropped. The callback
runs on a later frame, inside the app (errors in it open the error screen).

| Call | Callback gets |
|---|---|
| `net.get(url, callback, headers)` | `res` (`ok`, `status`, `body`, `error`, `url`, `headers`, `contentType`) |
| `net.post(url, body, callback, contentType, headers)` | `res` |
| `net.request({"url", "method", "body", "contentType", "headers"}, callback)` | `res` |
| `net.json(url, callback, headers)` | `(data, error)`: the parsed JSON and `None`, or `None` and a message (`"HTTP 404"`, `"invalid JSON"`, network error) |
| `net.download(url, path, callback, progress)` | `(ok, path_or_error)`; `progress(now, total)` while it runs |
| `fs.unzip(zip_path, dest_dir, callback, progress)` | `(ok, error_or_count)`; `progress(done_bytes, total_bytes)` while it runs (SDK 1.6) |
| `sys.games(callback)` | the list of games after the console scan (SDK 1.6); the call itself returns the list known now |
| `ui.alert(title, message, buttons, callback)` | button index (0-based) |
| `ui.prompt(title, message, text, callback)` / `ui.keyboard(text, callback, guide)` | text or `None` |
| `ui.openFile(callback, exts, title)` / `ui.saveFile(callback, name, title)` | path or `None` |
| `ui.contextMenu(items, callback)` | item id |
| `timer.after(sec, fn)` / `timer.every(sec, fn)` | — (returns an id for `timer.cancel(id)`) |

For `net.get`, `net.post` and `net.json` the optional arguments after the required ones may come in any order: a
function is the callback, a dict the headers, a string the content type. `network` and `files` permissions apply
exactly as for Lua and JavaScript (section 1).

```python
class Weather:
    def __init__(self):
        self.temp = None
        self.error = ""

    def refresh(self):
        url = "https://api.open-meteo.com/v1/forecast?latitude=41&longitude=29&current=temperature_2m"
        net.json(url, self.on_data)          # runs in the background

    def on_data(self, data, error):
        if error is not None:
            self.error = error               # offline, HTTP error or invalid JSON
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

### SDK 1.4 in Python

Define `search(query)`, `suspend()`, `resume()`, `focus(focused)`, `autosave()` and `unsaved()` like the other
callbacks (module functions or methods of `app`). `sys.memory()` → `(used, limit)`. `sys.requestPermission(name,
callback=None)` calls `callback(granted)`. Gated calls without their permission return `False`;
`sys.schedule(epoch, title, body=None, arg=None)` returns the id and raises `ValueError` for a time in
the past, too far ahead or over the quota; `sys.scheduled()` is a list of records (`it.id`, `it.at`, `it.title`,
`it.body`, `it.arg`). `sys.share(item)`, `sys.unschedule(id)`, `sys.hasPermission(name)`, `sys.appUrl(id, arg=None)`
and `sys.open("nxv://...")` are as in section 8a.

SDK 1.6: `sys.games(callback=None)` returns a list of records (`g.id`, `g.name`, `g.version`, `g.publisher`), or
`None` without the `"games"` permission. `fs.unzip` is in the callback table above.

### System library (SDK 1.5)

`import` looks in the bundle first, then in the system library `romfs:/System/Python`, which adds pure-Python versions
of modules pocketpy lacks, with the CPython APIs: `itertools` (`count`, `cycle`, `chain`, `islice`, `accumulate`,
`groupby`, `product`, `permutations`, `combinations`, `zip_longest`, `pairwise`...), `string` (constants, `capwords`,
`Template`), `textwrap` (`wrap`, `fill`, `shorten`, `dedent`, `indent`), `copy` (`copy`, `deepcopy`), `statistics`
(`mean`, `median`, `mode`, `stdev`, `variance`, `quantiles`...), `base64` (standard and URL-safe) and `colorsys` (RGB ↔
HSV/HLS/YIQ, plus `to_hex` / `from_hex` for gfx colors). A module of the same name in the bundle wins. `itertools.chain`
is iterable (`for`, `list()`), not an iterator (`next()`).

### Limits

| Limit | What happens |
|---|---|
| 3 seconds per callback | `TimeoutError: script took too long (possible infinite loop)`; catching the exception does not stop it |
| 64 MB per window | `MemoryError: out of memory (the app used more than 64 MB)`; `sys.memory()` shows the use |
| 16 Python windows | the 17th shows "too many Python apps are open" |
| recursion | `RecursionError: maximum recursion depth exceeded` |

### CPython (`"runtime": "python3"`)

`"runtime": "python3"` runs the app on **CPython 3.12** instead of pocketpy: the whole language (generator
expressions, `try`/`finally`, `nonlocal`, `async`...) and the standard library as `.pyc` files in
`romfs:/System/Python3/lib.zip`. A `.py` main file alone still means `"python"` (pocketpy), so existing apps do not
change. The callbacks, the `app` object and the SDK are the ones above; the differences:

- The SDK is also the module `nexvyn`: `from nexvyn import gfx, ui` or `import nexvyn`. The modules stay builtins, the
  SDK `sys` functions are on Python's `sys` and `json` is the standard `json` with `json.encode` / `json.decode` added.
  Optional arguments can be passed by name with the SDK's parameter names (section 3: `gfx.text("Hi", 20, 20,
  size=18)`, `fs.unzip(zipPath, destDir, ...)`). Records are `dict`s whose keys also read as attributes.
- `open()` and `os` work, with the same permission as `fs.*`: the app's bundle and data folder
  (`fs.path("notes.txt")`) are always allowed, other paths need `"files"`; `romfs:/` is read-only. Raw sockets
  (`socket`) need `"network"`; for HTTP(S) use `net.*` (there is no `ssl`). Threads, `subprocess`, `os.system`,
  `os.chdir` and the environment are not available. Use absolute paths ("sdmc:/...", or `fs.path`).
- `sys.exit()` / `exit()` close the window (`SystemExit`); `print` goes to the app's log.
- Built-in C modules: `math`, `cmath`, `_struct`, `_json`, `_datetime`, `array`, `select`, `_socket`, `_random`,
  `_bisect`, `_heapq`, `_statistics`, `_contextvars`, `_queue`, `_pickle`, `_csv`, `binascii`, `zlib`, `_md5`,
  `_sha1`, `_sha2`, `_sha3`, `_blake2` plus the core ones. Not included: `unicodedata`, `_decimal` (`decimal` uses the
  pure-Python `_pydecimal`), `ctypes`, `ssl`, `sqlite3`, `bz2`, `lzma`, `asyncio`, `multiprocessing`, `tkinter`,
  `email`, `http`, `xml`. `pip` packages with C code cannot be loaded (no `dlopen`); pure-Python packages can be
  copied into the bundle and imported.
- Every window gets its own interpreter (a CPython subinterpreter): at most **4** python3 apps at once, 64 MB and
  3 seconds per callback as above. Not available in applet mode (too little memory). `sys.platform` is `"switch"`.
- Builds without CPython (`tools/build_cpython.sh` not run) show "does not include Python 3" for these apps.
- Check on the PC with `python tools/py_check.py <bundle>` (the `"python3"` runtime is detected; `--cpython` forces
  it). Sample: `romfs/Applications/hellopy3.nxvapp`.

### Complete example

`Counter.nxvapp/app.json`: the manifest from section 10 plus `"main": "main.py"` and `"minSdk": "1.3"`. Same
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

A larger example (to-do list with `store`, a clock drawn with `gfx`, `net.json` with a callback, several modules) is
`romfs/Applications/hellopy.nxvapp`. Check a bundle on the PC with `python tools/py_check.py path/to/App.nxvapp`.

## 13. Squirrel

> **TR — Özet:** Uygulamalar C++'a benzeyen küçük bir dil olan Squirrel 3.2 ile de yazılabilir: `app.json` içinde
> `"runtime": "squirrel"`, `"main": "main.nut"` ve `"minSdk": "1.5"`. API ve kurallar Python'unkiyle aynıdır (0 tabanlı
> indeksler, çoklu sonuçlar dizi, asenkron çağrılar geri çağırma alır). Türkçe rehber: `docs/SQUIRREL_APPS.en.md`, örnek:
> `romfs/Applications/hellosq.nxvapp`.

Set `"runtime": "squirrel"` (or a `.nut` main file) and `"minSdk": "1.5"`. Squirrel 3.2 has C++-like syntax: classes
with inheritance, closures, lambdas (`@(x) x * 2`), generators, `foreach`, integers and floats (`5 / 2` is `2`,
`5 / 2.0` is `2.5`), tables `{a = 1}` and arrays `[1, 2]`. Standard library: math (`sin`, `sqrt`, `floor`, `rand`,
`PI`...) and string (`format`, `split`, `strip`, `regexp`...); no io/system (use `fs`, `sys`).

```squirrel
class Counter {
    count = 0;                       // tables/arrays as defaults are shared by every instance: create them in load()
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
return Counter();                    // or define load/draw/... as global functions and return nothing
```

- **Program**: `main.nut` returns the app (a table or class instance whose methods are the callbacks of section 2) or
  defines the callbacks as global functions. `import("util")` runs `util.nut` once and returns its result
  (`import("a.b")` loads `a/b.nut`). `print(x)` writes to the app's log.
- **SDK**: the modules of sections 3–8b are global tables (`gfx.rect(...)`, `ui.button(...)`, `TR(...)`, `theme.bg`).
  Values and results follow section 12 (Python): 0-based indexes, several results as an array (`local s = gfx.size();
  s[0], s[1]`), `ui.textfield` returns the text and `ui.submitted(id)` reports Enter, `ui.row` returns 0/1/2, records
  are tables (`e.type`, `res.ok`), `null` means no value.
- **Callbacks** (timers, `net`, dialogs) are functions; they run with `this` = the app, so fields and methods work in
  them: `net.json(url, function(data, err) { weather = data; })`. The arguments are those of the Python table in
  section 12.
- **Meshes** are `Mesh` instances: `m.setColor(c)`, `m.flat(true)`, `m.triangles()`, `m.setTexture(p)`, `m.free()`.
- **Limits**: 64 MB per window, 3 seconds per callback (checked on every loop; catching the error does not help).
  Errors open the error screen with a traceback (`draw() main.nut:12`).
- Check a bundle on the PC: `python tools/rt_check.py path/to/App.nxvapp` (SDK names, argument counts, brackets,
  translations).

## 14. C

> **TR — Özet:** Uygulamalar düz C ile de yazılabilir; paketteki `.c` dosyaları uygulama açılırken konsolda TinyCC ile
> derlenir (PC'de derleme adımı yok). `app.json`: `"runtime": "c"`, `"main": "main.c"`, `"minSdk": "1.5"`. SDK
> `#include <nexvyn.h>` ile gelir: `gfx.rect` → `gfx_rect`. C kodu korumalı alanda çalışmaz; SD karttan kurulan C
> uygulamaları ilk açılışta bir kez sorulur. Rehber: `docs/C_APPS.en.md`, örnek: `romfs/Applications/helloc.nxvapp`.

Set `"runtime": "c"` (or a `.c` main file) and `"minSdk": "1.5"`. When the window opens, every `.c` file of the bundle
(subfolders included) is compiled by TinyCC into memory and the app's callbacks are called directly. The SDK header is
`<nexvyn.h>` (`romfs:/System/C/include`); next to it is a small C library bound to the system's newlib: `stdio.h`
(`printf`/`puts` write to the app's log, `snprintf`, `sscanf`; no `FILE`), `stdlib.h` (counted `malloc`, `qsort`,
`strtod`, `rand`...), `string.h`, `math.h`, `ctype.h`, `stdint.h`, `limits.h`, `assert.h`, `stdbool.h`, `stdarg.h`.

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

- **Callbacks** are functions with fixed names, all optional: `app_load(const char*)`, `app_open`, `app_update(float)`,
  `app_draw(float, float)`, `app_event(const nxv_event*)`, `app_menu(void)` (build with `menu_begin` / `menu_item` /
  `menu_separator`), `app_onmenu(int)`, `bool app_close(void)`, `app_search(const char*)` (answer with
  `search_result(title, subtitle, icon, arg)`), `app_suspend`, `app_resume`, `app_focus(bool)`, `app_autosave`,
  `bool app_unsaved(void)`.
- **SDK functions** are the SDK's names with an underscore: `gfx_rect`, `ui_iconButton`, `sys_schedule`... Optional
  numbers are `0` and optional strings `NULL` for "the default". Colors are strings (`"#RRGGBB"`, `theme_color("accent")`,
  `rgba(r, g, b, a)`). Several results come through pointers (`gfx_size(&w, &h)`, `ui_mouse(&x, &y, &down, &hover)`),
  records as structs (`nxv_hit`, `nxv_date`, `nxv_entry`, `nxv_response`). `ui_textfield` edits a `char` buffer in place.
  `fs_read` returns a `malloc`'d buffer (free it). Images are drawn by path (`gfx_draw("bundle:/a.png", ...)`), meshes
  are `int` ids. Returned strings stay valid for the next 15 SDK calls: copy them to keep them. `nxv_fmt` formats into
  such a string: `TR1("score", nxv_fmt("%d", n))`. The whole list is in `nexvyn.h`.
- **Callbacks for async calls** are function pointers with a `void* user` argument:
  `net_json(url, NULL, on_data, NULL)` with `void on_data(const char* json, const char* error, void* user)`;
  `timer_after(1.0, on_tick, NULL)`; `ui_alert(title, msg, buttons, 2, on_button, NULL)`. `net_json` hands over the
  JSON text (`json_pretty` formats it; `store_getJson` / `store_setJson` keep JSON values).
- **Memory**: `malloc` is counted against 64 MB (NULL past it); whatever is left is freed when the window closes.
- **Native code**: C apps are not sandboxed and an endless loop or a crash cannot be stopped (no 3 second limit). A C
  app installed on the SD card runs only after the user agreed once. C apps need JIT code memory (Atmosphère's
  homebrew loader provides it); without it the error screen says so.
- Compile errors show on the error screen with file and line. Check on the PC with `python tools/rt_check.py` (compiles
  with devkitA64's gcc against the same headers).

## 15. Java

> **TR — Özet:** Uygulamalar Java ile de yazılabilir: kaynaklar PC'de `python tools/java_build.py app Uygulama.nxvapp`
> ile `app.jar`'a derlenir (JDK gerekir), konsolda miniJVM çalıştırır. `app.json`: `"runtime": "java"`,
> `"main": "app.jar"`, `"mainClass": "paket.Sinif"`, `"minSdk": "1.5"`. SDK `nexvyn` paketindedir (`Gfx.rect`,
> `Ui.button`, `Sys.date`...). Aynı anda bir Java uygulaması çalışır. Rehber: `docs/JAVA_APPS.en.md`, örnek:
> `romfs/Applications/hellojava.nxvapp`.

Set `"runtime": "java"`, `"main": "app.jar"`, `"mainClass"` (a class that extends `nexvyn.App`; optional when the
jar's manifest has `Main-Class`) and `"minSdk": "1.5"`. Put the sources in `src/` and build the jar on a PC with a JDK:
`python tools/java_build.py app MyApp.nxvapp` (Java 8 class files, compiled against the class library the console has,
`romfs/System/Java/minijvm_rt.jar`, and the SDK `nexvyn.jar`). The console runs it on miniJVM (an interpreter):
`java.lang`, `java.util` (collections, `Random`, `Calendar`...), `java.util.function`, lambdas, `String.format`,
reflection and threads are there; Swing/AWT, `java.net` sockets and `Runtime.exec` are not.

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

- **Callbacks** are the overridable methods of `nexvyn.App`: `load`, `open`, `update(double dt)` (override it only for
  animation), `draw(double w, double h)`, `event(Event e)` (`e.type`, `e.x`, `e.key`, `e.is("keydown")`...), `menu()`
  (`Menu.bar(new Menu(title).item(label, id, shortcut).separator())`), `onmenu`, `close`, `search` (a list of
  `SearchResult`), `suspend`, `resume`, `focus`, `autosave`, `unsaved`.
- **SDK classes** mirror the modules: `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`
  (`App.TR(key, args...)`), `Theme` (`Theme.bg()`, `Theme.get("accent")`, `Theme.dark()`) and `Json`
  (`Json.encode(v)`, `Json.decode(text)`). Every function takes `Object...`, so optional arguments can be left out
  (`Gfx.rect(x, y, w, h)`, `Gfx.rect(x, y, w, h, 8, Theme.accent())`). Results are typed (`boolean`, `double`, `int`,
  `String`, `Record`, `List<Object>`, `double[]` for several numbers, `Mesh`). Values follow section 12: 0-based
  indexes, numbers arrive as `Double`, maps as `Record` (a `LinkedHashMap` with `str/num/integer/bool` getters), lists
  as `List`. Arrays (`new String[]{...}`, `double[]`) are accepted where the SDK takes a list.
- **Async callbacks** are `nexvyn.Callback` lambdas with `Object... args`; cast the lambda when passing it:
  `Net.json(url, (Callback) a -> show((Record) a[0], a[1]))`, `Timer.after(1.5, (Callback) a -> hide())`.
- `System.out` and `System.err` go to the app's log.
- **Limits**: 64 MB Java heap; callbacks on the main thread are stopped after 3 seconds (`VMStopException`, checked on
  every loop). Only one Java app runs at a time. Java's own class library (`java.io` files, `sun.misc.Unsafe`) is not
  limited by the app's permissions, so a Java app installed on the SD card runs only after the user agreed once.
- Check on the PC: `python tools/rt_check.py MyApp.nxvapp` (compiles the sources, checks the jar and main class).
  The Java SDK sources are in `sdk/java`; `python tools/gen_java_sdk.py` regenerates the SDK classes from the system's
  function table.

## 16. Packages with `"native"` (internal, not for third-party apps)

> **TR — Özet:** Nexvyn OS'un kendi C++ uygulamalarından bazıları NRO'ya gömülmek yerine App Market'dan yerel modül
> (`.nxvmod`) olarak kurulur. Bu yalnızca bir iç mekanizmadır: modül Nexvyn OS kaynaklarıyla aynı derleyici ve
> bayraklarla, her sürümle birlikte derlenir ve yalnızca aynı yapının ABI kimliğiyle çalışır. Üçüncü taraf uygulamalar
> Lua, JavaScript veya Python ile yazılır. Ayrıntılar: `docs/NATIVE_MODULES.en.md`.

Third-party apps are written in Lua, JavaScript or Python (sections 1-13); that is the app platform. You may meet
packages of Nexvyn OS's own optional C++ apps in the App Market, so this section only explains what they are.

A `.nxvapp` may carry a C++ app instead of a script: `"native": "<id>.nxvmod"` (an AArch64 shared object) and
`"abi"` (the 16-hex-digit ABI id of the Nexvyn OS build it was compiled against). The module is built from the Nexvyn
OS source tree with `tools/build_modules.py` (listed in `tools/modules.json`; `./build.sh` builds the modules, leaves
those apps out of `NexvynOS.nro` and writes `build/modules/<id>.nxvapp`). It is the app's ordinary C++ source: a class
derived from `App` and `REGISTER_APP("<id>", Class)`. Nexvyn OS maps the module into JIT code memory on the first
launch, binds it to the symbols the NRO exports and runs its constructors. A module made for another build is refused
("rebuilt for Nexvyn OS x.y needed"); the App Market only offers modules that match the running build. Native code is
not sandboxed, so the user is asked once before it runs (`apps.trustedNative`); `"permissions"` is informational.
This is not a third-party SDK: the C++ API is Nexvyn OS's internal one and changes with every build, and the modules
are rebuilt by the release pipeline together with each NexvynOS.nro.
