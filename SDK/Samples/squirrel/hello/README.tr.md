# Merhaba Squirrel

[English](README.md) · **Türkçe**

Yerleşik **Merhaba Squirrel** uygulaması: yapılacaklar listesi, analog saat ve canlı hava durumu JSON'u.

| | |
|---|---|
| Kimlik | `hellosq` |
| Dil | Squirrel 3.2 |
| En düşük SDK | 1.5 |
| İzinler | `network` (ağ) |
| Kumanda | imleç |
| Pencere | 640 × 520, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `hellosq`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.hellosq` kimliğiyle kurulur.

## Ne öğretir

- `main.nut` bir sınıf örneği döndürür; `import("clock")` ikinci dosyayı yükler
- `net.json(url, function(veri, hata) {...})`; geri çağırmada `this` uygulamadır (`network` izni)
- `foreach`, lambdalar (`@(i, t) !t.done`), `todos.filter`
- `timer.after` / `timer.cancel`, menü, `ui.alert`

**Kontroller:** Üstteki bölümlü seçimle sekme değiştirin.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `clock.nut` (32), `main.nut` (179).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
