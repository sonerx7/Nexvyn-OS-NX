# Merhaba JS

[English](README.md) · **Türkçe**

Yerleşik **Merhaba JS** uygulaması: yapılacaklar listesi, analog saat ve canlı hava durumu JSON'u.

| | |
|---|---|
| Kimlik | `hellojs` |
| Dil | JavaScript (QuickJS-ng) |
| En düşük SDK | 1.1 |
| İzinler | `network` (ağ) |
| Kumanda | imleç |
| Pencere | 640 × 520, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `hellojs`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.hellojs` kimliğiyle kurulur.

## Ne öğretir

- ES modülleri: `todos.js` ve `clock.js` `import` ile yüklenir
- `await net.fetchJson(url)` ve `try`/`catch` ile hata yönetimi (`network` izni)
- `ui.textfield` + `ui.submitted`, `ui.checkbox`, `ui.beginScroll` listesi
- `setTimeout` / `clearTimeout` ile kısa bildirim (toast)
- `app.menu` / `app.onmenu`, `ui.alert` Promise'i

**Kontroller:** Üstteki bölümlü seçimle sekme değiştirin.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/javascript/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `clock.js` (59), `main.js` (195), `todos.js` (47).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    node tools/js_check.mjs <Nexvyn-OS-NX>/SDK/Samples/javascript/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
