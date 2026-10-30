# Merhaba C

[English](README.md) · **Türkçe**

Yerleşik **Merhaba C** uygulaması: sayaç, zıplayan toplar ve canlı JSON; konsolda TinyCC ile derlenir.

| | |
|---|---|
| Kimlik | `helloc` |
| Dil | C (TinyCC, konsolda derlenir) |
| En düşük SDK | 1.5 |
| İzinler | `network` (ağ) |
| Kumanda | imleç |
| Pencere | 640 × 520, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `helloc`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.helloc` kimliğiyle kurulur.

## Ne öğretir

- İki `.c` dosyası (`main.c`, `balls.c`) ve bir başlık (`balls.h`): hepsi açılışta derlenir
- `ui_textfield` ile `char` tamponu, `store_getStr` / `store_setStr`
- `net_json(url, NULL, on_weather, NULL)` ve `json_pretty` (`network` izni)
- `nxv_fmt` + `TR1`, `ui_segmented`, `ui_alert` ile fonksiyon işaretçisi geri çağırması

**Kontroller:** Sayaç sekmesinde Boşluk: +1 · Toplar sekmesinde tıklama: topları it.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **C:** derleme yok; `.c` dosyaları uygulama açılırken konsolda derlenir. SD karttan kurulan C uygulaması ilk açılışta bir kez onay ister.

Dosyalar (satır): `balls.c` (62), `balls.h` (8), `main.c` (124).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
