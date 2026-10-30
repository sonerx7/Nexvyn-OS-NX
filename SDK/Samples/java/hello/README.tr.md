# Merhaba Java

[English](README.md) · **Türkçe**

Yerleşik **Merhaba Java** uygulaması: yapılacaklar listesi, analog saat ve canlı hava durumu JSON'u.

| | |
|---|---|
| Kimlik | `hellojava` |
| Dil | Java 8 (miniJVM) |
| En düşük SDK | 1.5 |
| İzinler | `network` (ağ) |
| Kumanda | imleç |
| Pencere | 640 × 520, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `hellojava`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.hellojava` kimliğiyle kurulur.

## Ne öğretir

- `nexvyn.App`'ten türeyen `hello.HelloApp`; kaynak `src/`, derlenmiş hâli `app.jar`
- `Net.json(url, (Callback) a -> ...)` (`network` izni)
- `Record` (`str`, `num`, `integer`, `bool`, `rec`), `Store` içinde `List`
- `Menu.bar(new Menu(...).item(...).separator())`, `Timer.after`, `Ui.alert`

**Kontroller:** Üstteki bölümlü seçimle sekme değiştirin.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **Java:** `src/` değişince `app.jar`'ı PC'de yeniden derleyin: `python tools/java_build.py app SDK/Samples/java/hello/source` (JDK 8+; ya da `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/hello/source`).

Dosyalar (satır): `src/hello/HelloApp.java` (238).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
