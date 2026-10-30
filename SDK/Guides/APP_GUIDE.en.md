# Nexvyn OS native app guide

**English** · [Türkçe](APP_GUIDE.tr.md)

Nexvyn OS is a desktop shell that runs as a Nintendo Switch homebrew (`NexvynOS.nro`, 1280×720, SDL2 + libnx,
C++17, no exceptions, no RTTI). Built-in apps are C++ classes compiled into the NRO. This guide is everything you need
to write one. Read the headers it points to; they are short and commented.

## Rules for contributors (humans and AI agents)

1. **Your files only.** A native app lives in:
   - `source/apps/app_<id>.cpp` (more files allowed if prefixed: `source/apps/<id>_*.cpp/.h`; file names must be
     unique across the whole repo because object files are flattened),
   - `romfs/Applications/<id>.app/` — the bundle: `app.json` (already exists; you may edit window size, `fileTypes`),
     `icon.png` (exists, do not change), `lang/en.json` + `lang/tr.json` (your strings), optional `resources/`.
   Do **not** edit anything in `source/core`, `source/wm`, `source/lua`, `Makefile`, or other apps. If you need a core
   change, implement it locally in your app file or describe it in your final report.
2. **Check your code** with `tools/check.sh source/apps/app_<id>.cpp` (real devkitA64 compiler, syntax + types only,
   safe to run in parallel). Fix every error and warning. **Never** run `./build.sh` or `make` — only the lead does full
   builds (the build directory is shared).
3. **Everything real.** No fake data, no simulated features. Use the real Switch services (`sys::`), the real file
   system, the real network. Persist user data immediately when it changes (a real OS never loses edits).
4. **Every user-visible string is translated** (Turkish + English) — see Localization.
5. Match the code style: 4 spaces, ~120 columns, sparse comments, `namespace`-free app classes are fine.

## Anatomy

```cpp
#include "../wm/app.h"        // App, AppDesc, Menu, os:: services
#include "../wm/registry.h"   // REGISTER_APP, REGISTER_SERVICE
#include "../core/gfx.h"      // drawing
#include "../core/text.h"     // fonts, icons
#include "../core/ui.h"       // widgets
#include "../core/theme.h"    // colors
#include "../core/paths.h"    // standard folders
#include "../core/fsutil.h"   // file helpers
#include "../core/json.h"

class HelloApp : public App {
public:
    int count = 0;
    void onStart(const std::string& arg) override { /* arg: file path / URL / "" */ }
    void draw(float w, float h) override {
        const Palette& p = theme::p();
        ui::label(TRF("hello.clicked", std::to_string(count)), 20, 20, 15, p.text);
        if (ui::button(TR("hello.click"), Rect(20, 50, 140, 30), ui::BTN_PRIMARY)) count++;
    }
};
REGISTER_APP("hello", HelloApp)
```

`App` (see `source/wm/app.h`):
- `onStart(arg)` once; `onOpen(arg)` when a single-instance app is asked to open something else.
- `update(dt)` every frame, even while minimized. Keep it cheap.
- `draw(w, h)` every frame: render **and** handle input (immediate-mode UI). Local coordinates; (0,0) is the top-left
  of the content area. By default the window manager draws a 30 px title bar above it.
- `setUnified(toolbarH)` in `onStart` → no title bar; you draw a toolbar of `toolbarH` px (use `ui::toolbarBg`), leave
  the left `trafficLightsWidth()` (84 px) free for the close/minimize/zoom buttons. The top `toolbarH` px drag the
  window wherever no widget is under the pointer. Use this for file-manager, browser and settings windows.
- `onEvent(const InputEvent&)` raw input in local coordinates (before draw): games, paint canvases.
- `menus()` returns the app's menu-bar menus (`Menu{title, items}`); `onMenu(id)` handles picks. Use ids < 9000.
  `standardEditMenu()` gives Undo/Redo/Cut/Copy/Paste/Select All that drive the focused text widget automatically.
- `canClose()` → return false to veto (e.g. show "Save changes?" via `os::alert`, then call `close()` yourself).
- `setTitle()`, `close()`, `dataDir()` (= `~/Library/Application Support/<id>`, created).
- `wantsPad()` (or `"gamepad": true` in app.json): the window captures the controller while focused; you get
  `EV_PAD_DOWN/UP` events and `input::padHeld()`, `input::stickL()`. L+R gives the cursor back.
- **Async lifetime:** the App is deleted when its window closes. In any callback that can run later (net, dialogs,
  timers) capture `auto alive = aliveToken();` and `if (!*alive) return;` first.

## Drawing (`source/core/gfx.h`, `text.h`, `theme.h`)

- Shapes are anti-aliased: `gfx::rect`, `roundRect(r, radius, color)`, `roundRectGrad`, `roundRectOutline`,
  `roundRectCorners`, `circle`, `circleOutline`, `arc` (radians, 0 = +x, clockwise), `pie`, `line(x1,y1,x2,y2,c,t)`,
  `polyline`, `polygon` (convex), `gradient`, `shadow(r, radius, blur, color, dy)`.
- `gfx::pushOffset/popOffset`, `pushClip/popClip` (clip is intersected), `pushAlpha/popAlpha`.
- Images: `gfx::image(path)` cached by path (png/jpg/webp/bmp/gif), `drawImage`, `drawImageFit(img, box, cover, radius)`,
  `drawImageRounded`. For thumbnails of big files decode once with `gfx::loadImageSurface`, scale down
  (`SDL_BlitScaled` into a small surface) and register with `gfx::imageFromSurface(key, surface)`.
  `gfx::createTarget(w,h)` gives an offscreen canvas texture (paint apps). Render into it **only in `update()`**
  (`gfx::setTarget(canvas); ...; gfx::setTarget(nullptr);`) — during `draw()` the window's own texture is the target
  and switching would break the window. Show it in `draw()` with `gfx::drawTexture(canvas, nullptr, rect)`.
  To sample screen colors read the last composed frame in `update()`: `gfx::setTarget(gfx::sceneTexture());
  SDL_RenderReadPixels(...); gfx::setTarget(nullptr);` (desktop + windows, without overlays).
- Text: `text::draw(s, x, y_top, size, color, font)` returns width; `drawIn(s, rect, size, color, font, align, valign)`
  ellipsizes; `drawWrapped`, `measureWrapped`, `wrapLines`, `width`, `lineHeight`, `ellipsize`, `indexAtX`.
  Fonts: `text::SANS, SANS_MED, SANS_SEMI, SANS_BOLD, SANS_ITALIC, MONO, MONO_BOLD`.
- Icons: Material Icons Round by name — `text::iconCentered("folder", cx, cy, size, color)`. Names:
  `romfs/System/Fonts/Icons.codepoints` (e.g. `wifi`, `search`, `delete`, `play_arrow`, `settings`, `add`, `close`).
- Colors: `const Palette& p = theme::p();` → `p.text, p.text2, p.text3, p.accent, p.windowBg, p.contentBg,
  p.sidebarBg, p.separator, p.controlBg, p.fieldBg, p.selection, p.hover, p.rowAlt, p.red, p.green, p.blue ...`.
  Always use the palette (light & dark mode). `p.dark` tells which.

## Widgets (`source/core/ui.h`, `textarea.h`)

Immediate mode: a widget draws and returns its interaction in the same call. Ids come from the label (or
`"Label##id"`) plus `ui::pushId(i)/popId()` — use `pushId` inside loops.

`button(label, rect, BTN_DEFAULT|BTN_PRIMARY|BTN_DESTRUCTIVE|BTN_PLAIN|BTN_TOOLBAR|BTN_LINK, icon, enabled)`,
`iconButton(icon, rect, tint, active, enabled, idSuffix)`, `toggle(id, &bool, rect)` (38×22), `checkbox`, `radio`,
`slider(id, &float, min, max, rect, step)`, `segmented(id, items, &sel, rect)`, `popup(id, items, &sel, rect)`
(dropdown), `stepper`, `colorWell`, `textField(id, std::string&, rect, placeholder, TF_SEARCH|TF_PASSWORD|TF_NUMERIC|
TF_READONLY|TF_SELECT_ALL|TF_NOFRAME, fontSize)` + `ui::submitted()` (Enter), `ui::focus(id)`,
`label/labelIn`, `separator`, `progress(rect, v or -1)`, `spinner`, `groupBox` (settings-style rounded section),
`toolbarBg`, `sidebarBg`, `sidebarItem(label, icon, rect, selected)`, `sectionHeader`, `listRow(id, rect, selected,
&doubleClicked)`, `disclosure`, `badge`, `avatar`.

Scrolling: `ui::beginScroll(id, viewport, contentH, contentW)` … draw children at content coordinates (0,0 = top of
content) … `ui::endScroll()`. Touch-drag, inertia, right-stick and scrollbar dragging are handled for you.
`ui::scrollState(id)` exposes the offset; `scrollIntoView`.

Generic hit testing for custom widgets: `ui::Hit h = ui::interact(ui::makeId("name"), rect);` → `hovered, held,
pressed, clicked, rightClicked, doubleClicked, drag`. Raw state: `ui::in()` (`mouse, pressed, released, down,
scroll, keys, text, mods, touch`), `ui::mouse()` (pointer in current offset coordinates), `ui::hovered(rect)`.

Context menus: on `h.rightClicked` call `ui::contextMenu({MenuItem(label, id), MenuItem::sep(), ...}, [this,
alive](int id){ ... })`. Right click = X button, long-press on touch, or mouse right button. Dropdown at a spot:
`ui::menuAt(localPos, items, cb)`.

Multi-line text: `ui::TextArea ta;` → `ta.draw("id", rect)` returns true when the text changed. Fields: `wrap,
lineNumbers, readOnly, autoIndent, fontSize, font, highlight` (syntax spans callback), `setText/text`, `find`,
`replaceAll`, `undo/redo`, `selection`, `wordCount`.

Clipboard: `ui::clipboard()`, `ui::setClipboard()`.

## Localization (`source/core/i18n.h`)

- Put your strings in `romfs/Applications/<id>.app/lang/en.json` and `tr.json` as a flat or nested object. They are
  namespaced by the app id: `{"save_title": "..."}` in `notes.app` → `TR("notes.save_title")`.
- `TR("key")` returns `const char*`; `TRF("key", a, b)` fills `{0}`, `{1}`. Shared system strings exist:
  `common.ok/cancel/save/open/close/delete/rename/new/edit/copy/cut/paste/undo/redo/select_all/search/done/yes/no/
  back/next/add/remove/refresh/settings/name/size/date/kind/loading/error/retry/none/unknown/on/off/quit/about/help/
  file/view/window/go/untitled/dont_save/replace/find/share/info/items/install/uninstall/update/play/pause/stop/reset/
  start/apply/more/no_internet/choose/folder`, `places.*` (home, desktop, documents, downloads, pictures, music,
  movies, applications, sdcard, system, trash, favorites, locations, recents, screenshots, album), `date.months.N`,
  `date.days.N` (0 = Sunday) or `i18n::monthName/weekdayName/dateLong/dateShort`, `cat.*`, `color.*`, `sys.*`.
- Every key you use must exist in both files. `python tools/lang_check.py` verifies this.
- Turkish text must be proper Turkish with correct characters (ç ğ ı İ ö ş ü).

## Files and data (`paths.h`, `fsutil.h`, `json.h`, `settings.h`)

- Standard folders: `paths::home(), desktop(), documents(), downloads(), pictures(), screenshots(), music(), movies(),
  trash(), appSupport(id), caches(id)`; system: `paths::APPS` (installed apps), `paths::SYS_APPS` (built-in),
  `"sdmc:/"` (SD root), `"romfs:/"` (read-only system). Nintendo screenshots: `sdmc:/Nintendo/Album/`.
- `fsx::readFile/writeFile` (atomic), `list(dir, showHidden)` (sorted, dirs first), `exists/isDir/fileSize/mtime`,
  `mkdirs`, `copyAll(from, to, progress)`, `move`, `removeAll`, `moveToTrash`, `putBack`, `dirSize`, `diskSpace`,
  `join/parent/filename/stem/ext/uniqueName`, `kindOf`, `iconFor(path, isDir)` (file-type icon png path),
  `isReadOnly`.
- `Json::load(path)`, `j.save(path)`, `Json::parse(text, &err)`, `j["key"].str()/num()/integer()/boolean()`,
  `Json::array()/object()`, `push`, `elements()`, `items()`.
- System settings (theme, dock, clock format…): `settings::i/f/b/s("dotted.key", def)`, `settings::set(key, Json)`.
- **Shared data formats** (the desktop/Notification Center widgets read these — keep them exactly):
  - Weather `appSupport("weather")/cache.json`: `{"city":"İstanbul","temp":21.5,"code":3,"high":24,"low":15,
    "updated":<epoch>}` (`code` = WMO weather code from open-meteo).
  - Notes `appSupport("notes")/notes.json`: `{"notes":[{"id":"…","title":"…","body":"…","folder":"…",
    "modified":<epoch>,"created":<epoch>,"pinned":false}]}`.
  - Reminders `appSupport("reminders")/reminders.json`: `{"lists":[{"name":"…","color":"#hex","items":[{"title":"…",
    "done":false,"due":<epoch or 0>,"notes":""}]}]}`.
  - Calendar `appSupport("calendar")/events.json`: `{"events":[{"id":"…","title":"…","start":<epoch>,"end":<epoch>,
    "allDay":false,"color":"#hex","notes":"","alert":<minutes before or -1>}]}`.
  - Clock `appSupport("clock")/alarms.json`: `{"alarms":[{"id":"…","hour":7,"minute":30,"label":"…","enabled":true,
    "repeat":[1,2,3,4,5]}],"cities":["Europe/London",…]}`.
  - Contacts `appSupport("contacts")/contacts.json`: `{"contacts":[{"id","first","last","phone","email","company",
    "birthday":"YYYY-MM-DD","notes"}]}`.

## System services (`os::` in `app.h`)

`os::launch(appId, arg)`, `openPath(path)` (picks the app by type; folders open Files), `appsForPath`,
`notify(appId, title, body, onClick)`, `alert(title, msg, {buttons}, cb(index), iconPath)` (first button = default),
`prompt(title, msg, initial, cb(ok, text))`, `openFileDialog(title, {".txt"}, cb(path), startDir)`,
`saveFileDialog(title, defaultName, cb(path), startDir)`, `chooseFolderDialog`, `systemKeyboard(initial, guide,
cb(ok, text))` (Nintendo keyboard), `setWallpaper`, `screenshot(mode 0 full/1 window, delay)`, `lockScreen`,
`exitToHomebrewMenu`, `showLauncher/QuickSearch/Overview/ControlCenter/NotificationCenter`,
`requestSettingsPane("network")`, `windows()`, `frontWindow()`, `uptime()`, `fps()`, `recentAdd(path)`, `recents()`,
`launchNro(path, args)`.

Background work that must run while your app is closed (alarms, reminders): `REGISTER_SERVICE(name, [](float dt){})`
in your app file. Keep it cheap: check the clock once per second, reload your JSON only when its mtime changes.

App registry (`registry.h`): `registry::all()`, `find(id)`, `installPackage(path, &err)`, `uninstall(id, &err)`,
`rescanExternal()`, `revision()`.

## Hardware and Horizon services (`source/core/sysinfo.h`)

Real data only: `sys::localTime()` (`DateTime` with year, month 1-12, day, hour, minute, second, wday, yday, epoch,
utcOffset), `epoch()`, `toLocal(epoch)`, `timeZoneName()`, `formatTime(t, h24, seconds)`, battery
(`batteryPercent, charging, chargerConnected, chargerTypeKey, batteryHealth`), network (`online, wifi, wifiBars, ssid,
ip, gateway, subnet, dns`), device (`firmware, nickname, serial, modelName, region, systemLanguageCode, docked,
appletMode, atmosphereVersion, realHardware, socTemperature`), user (`userName, userAvatarJpeg`), display
(`brightnessAvailable, brightness, setBrightness`), memory (`memUsed, memTotal`), power (`reboot, powerOff,
sleepConsole`), `vibrate(strength, ms)`.

You may call libnx directly (`#include <switch.h>`) for services this layer does not cover (ns, pdm, hid, pl, nifm...).
**Ryujinx aborts on unimplemented service commands**, so guard anything unusual with `sys::realHardware()` and show a
friendly "not available in this environment" state otherwise. Always check `Result`s with `R_SUCCEEDED`.

## Networking and audio

`net::request(Request{url, method, body, headers, saveTo, userAgent, timeout}, cb(Response), progress(now, total))`,
`net::get(url, cb)`. Callbacks run on the main thread. `Response{status, body, headers, error, url, contentType,
ok()}`. HTTPS works (Horizon SSL). `net::urlEncode/urlDecode/resolveUrl`.

`audio::play("click"|"notify"|"alarm"|path, volume, loops)` → channel, `audio::stop(ch)`, `audio::ui(name)`,
`audio::tone(freq, seconds, volume, wave)`, music stream `audio::musicLoad/Play/Pause/Resume/Stop/Seek/Position/
Duration/Finished/SetVolume`, `audio::fileDuration(path)`.

Expressions: `expr::eval(text, out, degrees, &err)` (`source/core/expr.h`).

## Design language

Typical structures:
- Sidebar apps: `setUnified(52)`; sidebar 200–230 px with `ui::sidebarBg` (draw it from y=0, traffic lights sit on
  it), sections via `ui::sectionHeader`, items via `ui::sidebarItem`; content area with `p.contentBg`; toolbar over the
  content (title 15–17 px `SANS_BOLD`, toolbar buttons `ui::iconButton` 28×28).
- Settings-style forms: rows inside `ui::groupBox`, label left (14 px), control right, separators between rows.
- Typography: large titles 22–28 `SANS_BOLD`, headers 15–17 `SANS_SEMI`, body 13–14 `SANS`, secondary `p.text2`.
- Spacing on an 4/8 px grid; corner radius 6 (controls), 10 (cards), 12+ (panels).
- Touch friendly: rows ≥ 30 px, buttons ≥ 28 px tall. Everything must also work with the controller cursor
  (A = click, X = right click, right stick = scroll, D-pad = arrow keys, B = Escape).
- Animate small state changes with `approach(cur, target, speed, dt)` (`common.h`).

## Pitfalls learned so far

- `Color()` is **opaque black**. Widgets that take an optional tint treat `Color(0, 0, 0, 0)` as "use the default".
- Apps link into one binary: put helpers and app classes in an anonymous namespace to avoid duplicate symbols.
- `ui::` calls outside a frame (menu/dialog callbacks) are harmless but do nothing useful; set a flag and act in the
  next `draw()` instead. `os::launch` may be called from `draw()`, but `update()` is still the better place.
- A focused `ui::textField` / `TextArea` makes the on-screen keyboard appear automatically; no extra code needed.

## Performance

`draw()` runs at 60 fps on a 1 GHz ARM CPU. Never list directories, parse files or decode images every frame — do it
on change and cache. Use `gfx::image` caching. Keep per-frame allocations small.
