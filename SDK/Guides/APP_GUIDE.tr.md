# Nexvyn OS yerel (native) uygulama rehberi

[English](APP_GUIDE.en.md) · **Türkçe**

Nexvyn OS, Nintendo Switch homebrew'u olarak çalışan bir masaüstü kabuğudur (`NexvynOS.nro`, 1280×720,
SDL2 + libnx, C++17, istisna yok, RTTI yok). Yerleşik uygulamalar NRO'ya derlenmiş C++ sınıflarıdır. Bu rehber, bir
tane yazmak için ihtiyacınız olan her şeydir. Gösterdiği header'larını okuyun; kısa ve açıklamalıdırlar.

## Katkıda bulunanlar için kurallar (insanlar ve yapay zekâ ajanları)

1. **Yalnızca kendi dosyalarınız.** Bir yerel uygulama şuralarda yaşar:
   - `source/apps/app_<id>.cpp` (ön ekliyse daha fazla dosya olabilir: `source/apps/<id>_*.cpp/.h`; nesne dosyaları
     tek klasöre düzleştirildiği için dosya adları tüm depoda benzersiz olmalıdır),
   - `romfs/Applications/<id>.app/` — paket: `app.json` (zaten var; pencere boyutunu, `fileTypes`'ı
     düzenleyebilirsiniz), `icon.png` (var, değiştirmeyin), `lang/en.json` + `lang/tr.json` (metinleriniz), isteğe bağlı
     `resources/`.
   `source/core`, `source/wm`, `source/lua`, `Makefile` ya da başka uygulamalardaki hiçbir şeyi **düzenlemeyin**.
   Çekirdekte bir değişiklik gerekiyorsa bunu kendi uygulama dosyanızda yerel olarak uygulayın ya da son raporunuzda
   anlatın.
2. **Kodunuzu denetleyin**: `tools/check.sh source/apps/app_<id>.cpp` (gerçek devkitA64 derleyicisi, yalnızca sözdizimi
   + tipler, paralel çalıştırmak güvenli). Her hatayı ve uyarıyı düzeltin. `./build.sh` ya da `make` **asla**
   çalıştırmayın — tam derlemeleri yalnızca baş geliştirici yapar (derleme klasörü ortaktır).
3. **Her şey gerçek.** Sahte veri yok, taklit özellik yok. Gerçek Switch servislerini (`sys::`), gerçek dosya
   sistemini, gerçek ağı kullanın. Kullanıcı verilerini değişir değişmez kaydedin (gerçek bir işletim sistemi
   düzenlemeleri asla kaybetmez).
4. **Kullanıcının gördüğü her metin çevrilir** (Türkçe + İngilizce) — bkz. Yerelleştirme.
5. Kod stiline uyun: 4 boşluk, ~120 sütun, seyrek yorum; `namespace` içermeyen uygulama sınıfları sorun değildir.

## Anatomi

```cpp
#include "../wm/app.h"        // App, AppDesc, Menu, os:: servisleri
#include "../wm/registry.h"   // REGISTER_APP, REGISTER_SERVICE
#include "../core/gfx.h"      // çizim
#include "../core/text.h"     // yazı tipleri, simgeler
#include "../core/ui.h"       // widget'lar
#include "../core/theme.h"    // renkler
#include "../core/paths.h"    // standart klasörler
#include "../core/fsutil.h"   // dosya yardımcıları
#include "../core/json.h"

class HelloApp : public App {
public:
    int count = 0;
    void onStart(const std::string& arg) override { /* arg: dosya yolu / URL / "" */ }
    void draw(float w, float h) override {
        const Palette& p = theme::p();
        ui::label(TRF("hello.clicked", std::to_string(count)), 20, 20, 15, p.text);
        if (ui::button(TR("hello.click"), Rect(20, 50, 140, 30), ui::BTN_PRIMARY)) count++;
    }
};
REGISTER_APP("hello", HelloApp)
```

`App` (bkz. `source/wm/app.h`):
- `onStart(arg)` bir kez; `onOpen(arg)` tek örnekli bir uygulamadan başka bir şeyi açması istendiğinde.
- `update(dt)` her karede, simge durumundayken bile. Hafif tutun.
- `draw(w, h)` her karede: çizer **ve** girdiyi işler (immediate mode arayüz). Yerel koordinatlar; (0,0) içerik alanının
  sol üst köşesidir. Varsayılan olarak pencere yöneticisi bunun üstüne 30 px'lik bir başlık çubuğu çizer.
- `onStart` içinde `setUnified(toolbarH)` → başlık çubuğu yok; `toolbarH` px'lik bir araç çubuğunu siz çizersiniz
  (`ui::toolbarBg` kullanın), soldaki `trafficLightsWidth()` (84 px) alanı kapat/simge durumuna küçült/yakınlaştır
  düğmeleri için boş bırakın. Üstteki `toolbarH` px, işaretçinin altında widget olmayan her yerde pencereyi sürükler.
  Bunu dosya yöneticisi, tarayıcı ve ayarlar pencereleri için kullanın.
- `onEvent(const InputEvent&)` yerel koordinatlarda ham girdi (draw'dan önce): oyunlar, boyama tuvalleri.
- `menus()` uygulamanın menü çubuğu menülerini döndürür (`Menu{title, items}`); `onMenu(id)` seçimleri işler. 9000'den
  küçük id'ler kullanın. `standardEditMenu()`, odaktaki metin bileşenini kendiliğinden yöneten Geri Al/Yinele/Kes/
  Kopyala/Yapıştır/Tümünü Seç verir.
- `canClose()` → engellemek için false döndürün (ör. `os::alert` ile "Değişiklikler kaydedilsin mi?" gösterin, sonra
  `close()`'u kendiniz çağırın).
- `setTitle()`, `close()`, `dataDir()` (= `~/Library/Application Support/<id>`, oluşturulmuş).
- `wantsPad()` (ya da app.json içinde `"gamepad": true`): pencere odaktayken kumandayı yakalar; `EV_PAD_DOWN/UP`
  event'lerini ve `input::padHeld()`, `input::stickL()` değerlerini alırsınız. L+R imleci geri verir.
- **Async yaşam süresi:** App, penceresi kapandığında silinir. Daha sonra çalışabilecek her callback'te (ağ,
  iletişim kutuları, timer'lar) `auto alive = aliveToken();` yakalayın ve önce `if (!*alive) return;` yazın.

## Çizim (`source/core/gfx.h`, `text.h`, `theme.h`)

- Şekiller anti-aliased çizilir: `gfx::rect`, `roundRect(r, radius, color)`, `roundRectGrad`, `roundRectOutline`,
  `roundRectCorners`, `circle`, `circleOutline`, `arc` (radyan, 0 = +x, saat yönü), `pie`, `line(x1,y1,x2,y2,c,t)`,
  `polyline`, `polygon` (dışbükey), `gradient`, `shadow(r, radius, blur, color, dy)`.
- `gfx::pushOffset/popOffset`, `pushClip/popClip` (kırpma kesiştirilir), `pushAlpha/popAlpha`.
- Görseller: yola göre önbelleğe alınan `gfx::image(path)` (png/jpg/webp/bmp/gif), `drawImage`,
  `drawImageFit(img, box, cover, radius)`, `drawImageRounded`. Büyük dosyaların küçük resimleri için
  `gfx::loadImageSurface` ile bir kez çözün, küçültün (küçük bir yüzeye `SDL_BlitScaled`) ve
  `gfx::imageFromSurface(key, surface)` ile kaydedin. `gfx::createTarget(w,h)` ekran dışı bir tuval texture'ı verir
  (boyama uygulamaları). İçine **yalnızca `update()` içinde** çizin (`gfx::setTarget(canvas); ...; gfx::setTarget(nullptr);`)
  — `draw()` sırasında hedef pencerenin kendi dokusudur ve değiştirmek pencereyi bozar. `draw()` içinde
  `gfx::drawTexture(canvas, nullptr, rect)` ile gösterin. Ekran renklerini örneklemek için son birleştirilmiş kareyi
  `update()` içinde okuyun: `gfx::setTarget(gfx::sceneTexture()); SDL_RenderReadPixels(...); gfx::setTarget(nullptr);`
  (masaüstü + pencereler, üst katmanlar olmadan).
- Metin: `text::draw(s, x, y_top, size, color, font)` genişliği döndürür; `drawIn(s, rect, size, color, font, align, valign)`
  sığmayanı üç noktayla kısaltır; `drawWrapped`, `measureWrapped`, `wrapLines`, `width`, `lineHeight`, `ellipsize`,
  `indexAtX`. Yazı tipleri: `text::SANS, SANS_MED, SANS_SEMI, SANS_BOLD, SANS_ITALIC, MONO, MONO_BOLD`.
- Simgeler: ada göre Material Icons Round — `text::iconCentered("folder", cx, cy, size, color)`. Adlar:
  `romfs/System/Fonts/Icons.codepoints` (ör. `wifi`, `search`, `delete`, `play_arrow`, `settings`, `add`, `close`).
- Renkler: `const Palette& p = theme::p();` → `p.text, p.text2, p.text3, p.accent, p.windowBg, p.contentBg,
  p.sidebarBg, p.separator, p.controlBg, p.fieldBg, p.selection, p.hover, p.rowAlt, p.red, p.green, p.blue ...`.
  Her zaman paleti kullanın (açık ve koyu mod). `p.dark` hangisi olduğunu söyler.

## Widget'lar (`source/core/ui.h`, `textarea.h`)

Immediate mode: bir widget aynı çağrıda çizer ve etkileşimini döndürür. Id'ler etiketten (ya da `"Label##id"`) artı
`ui::pushId(i)/popId()`'den gelir — döngülerin içinde `pushId` kullanın.

`button(label, rect, BTN_DEFAULT|BTN_PRIMARY|BTN_DESTRUCTIVE|BTN_PLAIN|BTN_TOOLBAR|BTN_LINK, icon, enabled)`,
`iconButton(icon, rect, tint, active, enabled, idSuffix)`, `toggle(id, &bool, rect)` (38×22), `checkbox`, `radio`,
`slider(id, &float, min, max, rect, step)`, `segmented(id, items, &sel, rect)`, `popup(id, items, &sel, rect)`
(açılır liste), `stepper`, `colorWell`, `textField(id, std::string&, rect, placeholder, TF_SEARCH|TF_PASSWORD|TF_NUMERIC|
TF_READONLY|TF_SELECT_ALL|TF_NOFRAME, fontSize)` + `ui::submitted()` (Enter), `ui::focus(id)`,
`label/labelIn`, `separator`, `progress(rect, v or -1)`, `spinner`, `groupBox` (ayarlar tarzı yuvarlak bölüm),
`toolbarBg`, `sidebarBg`, `sidebarItem(label, icon, rect, selected)`, `sectionHeader`, `listRow(id, rect, selected,
&doubleClicked)`, `disclosure`, `badge`, `avatar`.

Kaydırma: `ui::beginScroll(id, viewport, contentH, contentW)` … alt öğeleri içerik koordinatlarında çizin (0,0 =
içeriğin üstü) … `ui::endScroll()`. Dokunarak sürükleme, eylemsizlik, sağ çubuk ve kaydırma çubuğunu sürükleme sizin
için işlenir. `ui::scrollState(id)` kaydırma konumunu verir; `scrollIntoView`.

Özel widget'lar için genel isabet testi: `ui::Hit h = ui::interact(ui::makeId("name"), rect);` → `hovered, held,
pressed, clicked, rightClicked, doubleClicked, drag`. Ham durum: `ui::in()` (`mouse, pressed, released, down,
scroll, keys, text, mods, touch`), `ui::mouse()` (geçerli kaydırma koordinatlarında işaretçi), `ui::hovered(rect)`.

Bağlam menüleri: `h.rightClicked` olduğunda `ui::contextMenu({MenuItem(label, id), MenuItem::sep(), ...}, [this,
alive](int id){ ... })` çağırın. Sağ tıklama = X düğmesi, dokunmatikte uzun basma ya da farenin sağ düğmesi. Bir
noktada açılır menü: `ui::menuAt(localPos, items, cb)`.

Çok satırlı metin: `ui::TextArea ta;` → `ta.draw("id", rect)` metin değiştiğinde true döndürür. Alanlar: `wrap,
lineNumbers, readOnly, autoIndent, fontSize, font, highlight` (sözdizimi aralıkları callback'i), `setText/text`,
`find`, `replaceAll`, `undo/redo`, `selection`, `wordCount`.

Pano: `ui::clipboard()`, `ui::setClipboard()`.

## Yerelleştirme (`source/core/i18n.h`)

- Metinlerinizi `romfs/Applications/<id>.app/lang/en.json` ve `tr.json` içine düz ya da iç içe bir nesne olarak koyun.
  Uygulama id'siyle ad alanına alınırlar: `notes.app` içindeki `{"save_title": "..."}` → `TR("notes.save_title")`.
- `TR("key")` `const char*` döndürür; `TRF("key", a, b)` `{0}`, `{1}` yerlerini doldurur. Ortak sistem metinleri
  vardır: `common.ok/cancel/save/open/close/delete/rename/new/edit/copy/cut/paste/undo/redo/select_all/search/done/yes/no/
  back/next/add/remove/refresh/settings/name/size/date/kind/loading/error/retry/none/unknown/on/off/quit/about/help/
  file/view/window/go/untitled/dont_save/replace/find/share/info/items/install/uninstall/update/play/pause/stop/reset/
  start/apply/more/no_internet/choose/folder`, `places.*` (home, desktop, documents, downloads, pictures, music,
  movies, applications, sdcard, system, trash, favorites, locations, recents, screenshots, album), `date.months.N`,
  `date.days.N` (0 = Pazar) ya da `i18n::monthName/weekdayName/dateLong/dateShort`, `cat.*`, `color.*`, `sys.*`.
- Kullandığınız her anahtar iki dosyada da bulunmalıdır. `python tools/lang_check.py` bunu doğrular.
- Türkçe metin doğru karakterlerle (ç ğ ı İ ö ş ü) düzgün Türkçe olmalıdır.

## Dosyalar ve veriler (`paths.h`, `fsutil.h`, `json.h`, `settings.h`)

- Standart klasörler: `paths::home(), desktop(), documents(), downloads(), pictures(), screenshots(), music(), movies(),
  trash(), appSupport(id), caches(id)`; sistem: `paths::APPS` (kurulu uygulamalar), `paths::SYS_APPS` (yerleşik),
  `"sdmc:/"` (SD kökü), `"romfs:/"` (salt okunur sistem). Nintendo ekran görüntüleri: `sdmc:/Nintendo/Album/`.
- `fsx::readFile/writeFile` (atomik), `list(dir, showHidden)` (sıralı, önce klasörler), `exists/isDir/fileSize/mtime`,
  `mkdirs`, `copyAll(from, to, progress)`, `move`, `removeAll`, `moveToTrash`, `putBack`, `dirSize`, `diskSpace`,
  `join/parent/filename/stem/ext/uniqueName`, `kindOf`, `iconFor(path, isDir)` (dosya türü simgesi png yolu),
  `isReadOnly`.
- `Json::load(path)`, `j.save(path)`, `Json::parse(text, &err)`, `j["key"].str()/num()/integer()/boolean()`,
  `Json::array()/object()`, `push`, `elements()`, `items()`.
- Sistem ayarları (tema, dock, saat biçimi…): `settings::i/f/b/s("dotted.key", def)`, `settings::set(key, Json)`.
- **Ortak veri biçimleri** (masaüstü/Bildirim Merkezi widget'ları bunları okur — tam olarak koruyun):
  - Hava durumu `appSupport("weather")/cache.json`: `{"city":"İstanbul","temp":21.5,"code":3,"high":24,"low":15,
    "updated":<epoch>}` (`code` = open-meteo'dan WMO hava kodu).
  - Notlar `appSupport("notes")/notes.json`: `{"notes":[{"id":"…","title":"…","body":"…","folder":"…",
    "modified":<epoch>,"created":<epoch>,"pinned":false}]}`.
  - Anımsatıcılar `appSupport("reminders")/reminders.json`: `{"lists":[{"name":"…","color":"#hex","items":[{"title":"…",
    "done":false,"due":<epoch or 0>,"notes":""}]}]}`.
  - Takvim `appSupport("calendar")/events.json`: `{"events":[{"id":"…","title":"…","start":<epoch>,"end":<epoch>,
    "allDay":false,"color":"#hex","notes":"","alert":<minutes before or -1>}]}`.
  - Saat `appSupport("clock")/alarms.json`: `{"alarms":[{"id":"…","hour":7,"minute":30,"label":"…","enabled":true,
    "repeat":[1,2,3,4,5]}],"cities":["Europe/London",…]}`.
  - Kişiler `appSupport("contacts")/contacts.json`: `{"contacts":[{"id","first","last","phone","email","company",
    "birthday":"YYYY-MM-DD","notes"}]}`.

## Sistem servisleri (`app.h` içinde `os::`)

`os::launch(appId, arg)`, `openPath(path)` (uygulamayı türe göre seçer; klasörler Dosyalar'da açılır), `appsForPath`,
`notify(appId, title, body, onClick)`, `alert(title, msg, {buttons}, cb(index), iconPath)` (ilk düğme = varsayılan),
`prompt(title, msg, initial, cb(ok, text))`, `openFileDialog(title, {".txt"}, cb(path), startDir)`,
`saveFileDialog(title, defaultName, cb(path), startDir)`, `chooseFolderDialog`, `systemKeyboard(initial, guide,
cb(ok, text))` (Nintendo klavyesi), `setWallpaper`, `screenshot(mode 0 full/1 window, delay)`, `lockScreen`,
`exitToHomebrewMenu`, `showLauncher/QuickSearch/Overview/ControlCenter/NotificationCenter`,
`requestSettingsPane("network")`, `windows()`, `frontWindow()`, `uptime()`, `fps()`, `recentAdd(path)`, `recents()`,
`launchNro(path, args)`.

Uygulamanız kapalıyken çalışması gereken arka plan işleri (alarmlar, anımsatıcılar): uygulama dosyanızda
`REGISTER_SERVICE(name, [](float dt){})`. Hafif tutun: saati saniyede bir denetleyin, JSON'unuzu yalnızca mtime'ı
değiştiğinde yeniden yükleyin.

Uygulama kayıt defteri (`registry.h`): `registry::all()`, `find(id)`, `installPackage(path, &err)`,
`uninstall(id, &err)`, `rescanExternal()`, `revision()`.

## Donanım ve Horizon servisleri (`source/core/sysinfo.h`)

Yalnızca gerçek veriler: `sys::localTime()` (year, month 1-12, day, hour, minute, second, wday, yday, epoch,
utcOffset içeren `DateTime`), `epoch()`, `toLocal(epoch)`, `timeZoneName()`, `formatTime(t, h24, seconds)`, pil
(`batteryPercent, charging, chargerConnected, chargerTypeKey, batteryHealth`), ağ (`online, wifi, wifiBars, ssid,
ip, gateway, subnet, dns`), cihaz (`firmware, nickname, serial, modelName, region, systemLanguageCode, docked,
appletMode, atmosphereVersion, realHardware, socTemperature`), kullanıcı (`userName, userAvatarJpeg`), ekran
(`brightnessAvailable, brightness, setBrightness`), bellek (`memUsed, memTotal`), güç (`reboot, powerOff,
sleepConsole`), `vibrate(strength, ms)`.

Bu katmanın kapsamadığı servisler için libnx'i doğrudan çağırabilirsiniz (`#include <switch.h>`) (ns, pdm, hid, pl,
nifm...). **Ryujinx, uygulanmamış servis komutlarında durur**; bu yüzden olağan dışı her şeyi `sys::realHardware()`
ile koruyun ve aksi hâlde anlaşılır bir "bu ortamda kullanılamıyor" durumu gösterin. `Result`'ları her zaman
`R_SUCCEEDED` ile denetleyin.

## Ağ ve ses

`net::request(Request{url, method, body, headers, saveTo, userAgent, timeout}, cb(Response), progress(now, total))`,
`net::get(url, cb)`. Callback'ler ana thread'de çalışır. `Response{status, body, headers, error, url,
contentType, ok()}`. HTTPS çalışır (Horizon SSL). `net::urlEncode/urlDecode/resolveUrl`.

`audio::play("click"|"notify"|"alarm"|path, volume, loops)` → kanal, `audio::stop(ch)`, `audio::ui(name)`,
`audio::tone(freq, seconds, volume, wave)`, müzik akışı `audio::musicLoad/Play/Pause/Resume/Stop/Seek/Position/
Duration/Finished/SetVolume`, `audio::fileDuration(path)`.

İfadeler: `expr::eval(text, out, degrees, &err)` (`source/core/expr.h`).

## Tasarım dili

Tipik yapılar:
- Kenar çubuklu uygulamalar: `setUnified(52)`; `ui::sidebarBg` ile 200–230 px kenar çubuğu (y=0'dan çizin, trafik
  ışıkları üstünde durur), `ui::sectionHeader` ile bölümler, `ui::sidebarItem` ile öğeler; `p.contentBg` ile içerik
  alanı; içeriğin üstünde araç çubuğu (başlık 15–17 px `SANS_BOLD`, araç çubuğu düğmeleri `ui::iconButton` 28×28).
- Ayarlar tarzı formlar: `ui::groupBox` içinde satırlar, solda etiket (14 px), sağda denetim, satırlar arasında
  ayraçlar.
- Tipografi: büyük başlıklar 22–28 `SANS_BOLD`, başlıklar 15–17 `SANS_SEMI`, gövde 13–14 `SANS`, ikincil `p.text2`.
- 4/8 px ızgarada boşluklar; köşe yarıçapı 6 (denetimler), 10 (kartlar), 12+ (paneller).
- Dokunmaya uygun: satırlar ≥ 30 px, düğmeler ≥ 28 px yüksekliğinde. Her şey kumanda imleciyle de çalışmalıdır
  (A = tıklama, X = sağ tıklama, sağ çubuk = kaydırma, D-pad = ok tuşları, B = Escape).
- Küçük durum değişikliklerini `approach(cur, target, speed, dt)` (`common.h`) ile canlandırın.

## Şimdiye kadar öğrenilen tuzaklar

- `Color()` **opak siyahtır**. İsteğe bağlı bir renk tonu alan widget'lar `Color(0, 0, 0, 0)`'ı "varsayılanı kullan"
  olarak yorumlar.
- Uygulamalar tek bir ikili dosyaya bağlanır: yinelenen simgelerden kaçınmak için yardımcıları ve uygulama
  sınıflarını adsız bir ad alanına koyun.
- Bir kare dışındaki `ui::` çağrıları (menü/iletişim kutusu callback'leri) zararsızdır ama işe yarar bir şey
  yapmaz; bunun yerine bir bayrak ayarlayın ve sonraki `draw()` içinde harekete geçin. `os::launch` `draw()` içinden
  çağrılabilir ama yine de en iyi yer `update()`'tir.
- Odaktaki bir `ui::textField` / `TextArea` ekran klavyesini kendiliğinden açar; ek kod gerekmez.

## Performans

`draw()` 1 GHz'lik bir ARM işlemcide 60 fps çalışır. Klasörleri listelemeyi, dosya ayrıştırmayı ya da görsel çözmeyi
asla her karede yapmayın — değişiklikte yapın ve önbelleğe alın. `gfx::image` cache'ini kullanın. Kare başına
allocationlarını küçük tutun.
