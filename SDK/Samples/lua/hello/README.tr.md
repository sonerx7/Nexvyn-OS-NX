# Merhaba SDK

[English](README.md) · **Türkçe**

Yerleşik **Merhaba SDK** uygulaması: üç sekmede canlı bileşenler, canlı çizim ve sistem bilgisi.

| | |
|---|---|
| Kimlik | `hello` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | `notifications` (bildirimler), `launch` (başlatma) |
| Kumanda | imleç |
| Pencere | 560 × 420, sabit |

> Bu, Nexvyn OS ile gelen örnek uygulamanın kopyasıdır (kimliği `hello`). SD karta kurarsanız sistemdeki kopyanın yanına `ext.hello` kimliğiyle kurulur.

## Ne öğretir

- `ui.textfield` (Enter = gönderildi), `ui.slider`, `ui.toggle`, `ui.segmented`, `ui.button`
- `ui.alert` geri çağırması ve `sys.notify` (`notifications` izni)
- `gfx.gradient`, `gfx.shadow`, `gfx.arc`, `gfx.icon` ile her karede canlanan çizim
- `sys.date`, `sys.battery`, `sys.online`, `sys.model`, `sys.firmware`, `sys.lang`
- `store` ile tıklama sayısı ve ad; menüden `sys.launch` (`launch` izni)

**Kontroller:** Sol / sağ ok: sekme değiştir.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `hello.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/lua/hello/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `main.lua` (122).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/hello/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
