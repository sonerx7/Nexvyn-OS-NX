# Tema yapımı

[English](THEMES.en.md) · **Türkçe**

Tema paketi (`.nxvtheme`) tüm masaüstünü değiştirir: renkler ve vurgu, duvar kâğıtları, pencere biçimi, masaüstü düzeni
(dock ya da görev çubuğu), simge seti ve sistem sesleri. İçinde kod yoktur; yalnızca `theme.json`, resimler ve sesler.
Paketin ayrıntılı kuralları [NXVAPP_FORMAT.tr.md](NXVAPP_FORMAT.tr.md) 9. bölümdedir; bu rehber nasıl yapılacağını
anlatır. Kopyalanacak hazır klasör `SDK/Samples/themes/template/`, denetleyici ve paketleyici
`SDK/Tools/theme/themecheck.py`.

## 1. Klasör

```
MyTheme/                  (MyTheme.nxvtheme olarak zip'lenir; theme.json zip kökünde ya da tek üst klasörde)
├── theme.json            zorunlu
├── wallpaper.jpg         zorunlu, 1280x720 JPG / PNG / WebP
├── wallpaper2.jpg ...    isteğe bağlı ek seçenekler
├── wallpaper-dark.jpg    isteğe bağlı, koyu görünümde gösterilir
├── icons/<app id>.png    isteğe bağlı, 128 px; dosyası olmayan app kendi simgesini korur (en çok 160 dosya)
├── sounds/*.wav          isteğe bağlı: startup click notify error pop key
├── preview.jpg           isteğe bağlı, bitmiş masaüstünün 480x270 resmi (kartlar, yükleyici)
└── README.md
```

Sınırlar: en çok 160 dosya, toplam 32 MB, dosya başına 12 MB; yalnızca `.json .jpg .jpeg .png .webp .wav .md .txt`
uzantıları; mutlak yol ya da `..`, `:`, `\` içeren yol paketin tamamını reddettirir. Sınırlar hiçbir şey açılmadan
önce denetlenir.

## 2. theme.json

```json
{
  "id": "com.yourname.theme.harbor",
  "name": {"en": "Harbor", "tr": "Liman"},
  "subtitle": {"en": "Calm blue-grey desktop with a bottom taskbar", "tr": "Sakin mavi-gri masaüstü, altta görev çubuğu"},
  "description": {"en": "A quiet desktop in cool blues.", "tr": "Serin mavilerde sakin bir masaüstü."},
  "version": "1.0",
  "author": "Your Name",
  "full": true,
  "appearance": "dark",
  "accent": "#3C8DBC",
  "wallpaper": "wallpaper.jpg",
  "wallpapers": ["wallpaper.jpg", "wallpaper2.jpg"],
  "sounds": "sounds",
  "icons": "icons",
  "preview": "preview.jpg",
  "settings": {"shell.layout": "taskbar", "taskbar.size": "medium", "start.sidePanel": true, "window.chrome": "flat"},
  "palette": {"windowBg": "1B2430", "text": "ECF1F6", "selection": "3C8DBC", "selectionText": "FFFFFF"}
}
```

| Alan | Anlamı |
|---|---|
| `id` | En az bir noktalı ters alan adı (`com.siz.theme.ad`). Güncellemeler bununla eşleşir; Store kaydı da aynı id'yi kullanır. |
| `name`, `description`, `subtitle` | Metin ya da dil tablosu (`en` yedektir; Store metinleri için 8 dil önerilir). |
| `version`, `author` | Noktalı sürüm (Güncelle / Yeniden kur için karşılaştırılır) ve adınız. |
| `full` | `true`: paket düzen ve çubuk ayarlarına da sahip olur. Uygulanırken önce bunlar sıfırlanır, paketler arası geçişte artık kalmaz. `shell.layout` ayarlayan paketlerde kullanın. |
| `appearance` | `light`, `dark` ya da `auto`. Yoksa kullanıcının seçimi kalır. |
| `accent` | `#RRGGBB`. Sekiz sistem renginden biriyse onun indeksi, değilse özel renk. |
| `wallpaper`, `wallpapers`, `wallpaperDark` | Zorunlu ilk duvar kâğıdı, ek seçenekler (ilki `wallpaper`; Ayarlar > Görünüm > Özelleştir'de seçilir) ve koyu görünüm resmi. |
| `sounds`, `icons`, `preview` | Paket içindeki klasör adları ve önizleme dosyası. |

### Ayar anahtarları

Yalnızca şu anahtarlar okunur. Diğerleri yok sayılır, sayılar aralığa kırpılır.

| Anahtar | Değerler |
|---|---|
| `shell.layout` | `dock` (dock ve menü çubuğu) ya da `taskbar` (başlat menülü alt çubuk) |
| `taskbar.size` | `small`, `medium`, `large` |
| `start.sidePanel` | `true` ya da `false` (taskbar düzeni) |
| `window.chrome` | `default`, `bevel`, `flat`, `glass`, `mono` (pencere çerçevesi ve düğmeleri) |
| `appearance.themeBold` | `true` ya da `false` (kalın sistem yazısı) |
| `appearance.themeScale` | 0,85 - 1,2 (arayüz ölçeği) |
| `appearance.reduceTransparency` | `true` ya da `false` |
| `appearance.darkFrom`, `appearance.darkTo` | 0 - 23, `auto` görünümün koyu saatleri |
| `dock.size` | 40 - 80 |
| `dock.magnify`, `dock.magnification` | `true` ya da `false`; 1,0 - 2,0 |
| `desktop.iconSize` | 0 küçük, 1 orta, 2 büyük |
| `screensaver.style` | 0 şekiller, 1 yıldız yolculuğu, 2 saat |

### Palet

`palette` tek tek renkleri `RRGGBB` ya da `RRGGBBAA` olarak değiştirir. Bilinmeyen adlar yok sayılır. Adlar: `windowBg
titlebar titlebarInactive contentBg sidebarBg text text2 text3 controlBg controlBorder controlHover fieldBg
fieldBorder selection selectionText menuBg menuText panelTint menubarTint menubarText separator accentText`. Yalnızca
gerekeni ayarlayın; gerisi görünüm ve vurguyu izler.

### Simge seti

`icons/<app id>.png`: app'in id'siyle adlandırılmış 128 px PNG dosyaları (`appstore.png`, `aichat.png`, ...). Yalnızca
değiştirmek istediğiniz simgeleri yeniden biçimlendirin; diğerleri sistem görünümünde kalır. Kendi çizimlerinizle ve
araçlarınızla üretin (pikselleştirme, kabartma, düzleştirme, çift ton, çerçeve). Başka bir ürünün simgelerini asla
çizip geçmeyin ya da düzenlemeyin.

### Sesler

`sounds/` içinde `startup`, `click`, `notify`, `error`, `pop`, `key` adlı `.wav` dosyaları olabilir. Eksik olan sistem
sesini çalar. Her dosyayı kısa tutun (2 saniyenin altı, açılış sesi 4'ün altı) ve varsayılanlardan yüksek yapmayın.

## 3. Kurallar

1. **Yalnızca özgün içerik.** Duvar kâğıtları, simgeler ve sesler sizin yaptığınız (çizilmiş, render edilmiş, sentezlenmiş)
   ya da CC0 olmalı. Başka bir sistemin duvar kâğıdını, simgesini, logosunu, açılış sesini ya da pencere çizimini
   kopyalamayın. Bir dönemden ya da havadan ilham alınabilir ("90'lar bej", "2000'ler camsı"); ama her dosya sizin işiniz.
2. **Marka adı yok.** Başka bir ürünün adını, logosunu ya da sloganını id'de, adda, metinde ya da resimde kullanmayın.
   Genel adlar seçin ("Classic", "Glass", "Terminal Blue").
3. **Okunur renkler (WCAG AA).** Yazı, arka planına karşı en az 4,5:1 kontrast oranına sahip olmalı (büyük yazı ve
   simgelerde 3:1). Bu `windowBg`, `contentBg`, `sidebarBg` üstündeki `text`, `menuBg` üstündeki `menuText`,
   `selection` üstündeki `selectionText` ve `accentText`'in göründüğü yüzeyler için geçerlidir. `themecheck.py` ölçer.
4. **Duvar kâğıdı arayüzü gizlemez.** Masaüstü simge etiketleri yoğun alanlarda okunur kalır.
5. **Kişisel veri yok**; haklarına sahip olmadığınız resim ya da yazı yok.
6. Paket tanımadığı app'lerle de çalışmalı: ayarlamadığınız her şey varsayılana kalır.

## 4. Deneme

1. `python SDK/Tools/theme/themecheck.py MyTheme` hataları ve uyarıları (biçim, sınırlar, kontrast) listeler.
2. `python SDK/Tools/theme/themecheck.py MyTheme --pack` klasörün yanına `MyTheme.nxvtheme` yazar.
3. `.nxvtheme` dosyasını konsolun SD kartına kopyalayın, Dosyalar'da açın, **Kur ve Uygula**'yı seçin.
4. *Sistem Ayarları > Görünüm > Temalar*'da kart doğru görünmeli; **Geri al** ve **Varsayılanlara dön** çalışmalı.
   Açık ve koyu görünümde birkaç app, bir metin alanı, bir menü, başlat menüsü ya da dock'u deneyin, sesleri çalın.
5. Görünüm masaüstünü bozarsa Nexvyn OS açılırken L + R + ZL + ZR'ye basılı tutun: varsayılan görünüm döner.

## 5. Store'da yayın

Temalar App Market'e app'ler gibi gider: `Store/Themes/<slug>/` ekleyen bir pull request
([Yayın](../Publishing/PUBLISHING.tr.md)).

```
Store/Themes/<slug>/
├── source/               yukarıdaki paket klasörü (theme.json, duvar kâğıdı, icons/, sounds/, preview.jpg)
├── store.json            {"subtitle": {...}, "description": {...}}  (8 dil önerilir: en tr de fr es ja zh ko)
├── icon.png              256x256 kart simgesi (masaüstünün yuvarlatılmış kırpması iyi durur)
├── preview.wav           isteğe bağlı kısa ses örneği: Store'daki "audio" alanı bundan doldurulur ve
│                         "Sesleri dinle" düğmesini çalıştırır
└── screenshots/          5 ekran görüntüsü önerilir (en az 3), İngilizce arayüz
```

Ekran görüntüleri: en güzel açılardan beş tane (masaüstü, bir pencere, başlat menüsü ya da dock, simge seti, bir tane
daha); sistem dili İngilizce iken çekilir. Pull request için imzalama adımı gerekmez: paketi, SHA-256'sını ve katalog
kaydını bakımcılar üretir (`Tools/build_store.py`). Kopyalanmış içerik ya da marka adı olan tema reddedilir.

## 6. Çok sayıda görünüm

`Store/Themes/*/source` yayımlanmış paketleri içerir; birini çalışan örnek olarak açın. Bir paket takımının tamamı
script ile üretilebilir (prosedürel duvar kâğıtları, temaya göre simge dönüşümleri, sentezlenmiş sesler, sabit
tohumlar); böylece sonuç yeniden üretilebilir ve her dosya sizin olur.
