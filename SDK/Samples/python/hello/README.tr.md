# Merhaba Python

[English](README.md) · **Türkçe**

Yerleşik **Merhaba Python** uygulaması: yapılacaklar listesi, analog saat ve canlı hava durumu JSON'u.

| | |
|---|---|
| Kimlik | `hellopy` |
| Dil | Python (pocketpy 2) |
| En düşük SDK | 1.3 |
| İzinler | `network` (ağ) |
| Kumanda | imleç |
| Pencere | 640 × 520, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `hellopy`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.hellopy` kimliğiyle kurulur.

## Ne öğretir

- Uygulama nesnesi olarak sınıf (`app = Hello()`), `from todos import TodoList`
- `net.json(url, geri_cagirma)` ile `(veri, hata)` (`network` izni)
- `store`, `timer.after` ile kısa bildirim, menü ve metot olarak verilen `ui.alert` geri çağırması

**Kontroller:** Üstteki bölümlü seçimle sekme değiştirin.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/python/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `clock.py` (63), `main.py` (216), `todos.py` (49).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/py_check.py <Nexvyn-OS-NX>/SDK/Samples/python/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
