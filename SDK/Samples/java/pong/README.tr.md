# Pong (Java)

[English](README.md) · **Türkçe**

Konsola karşı Pong, 7 sayıya kadar; her pencere boyutuna ölçeklenen saha.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.pong` |
| Dil | Java 8 (miniJVM) |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | uygulamaya gider (L+R: imleç) |
| Pencere | 800 × 450, yeniden boyutlanır |

## Ne öğretir

- `"gamepad": true`, her karede `Input.stick("left")` ve `Input.down("up")`
- `keydown` / `keyup` olaylarından tutulan tuş durumu
- `Ui.mouse()` ve `Ui.hit` ile sürükleyerek raket
- 640×360 sanal saha, `Gfx.push` ve ölçek çarpanı
- `suspend()` ve `focus(false)` ile duraklatma, `Store` ile galibiyet sayısı

**Kontroller:** Çubuk / yön tuşları / oklar / W-S: raket · A, Enter, Boşluk, dokunma: servis · +, Esc, P: duraklat.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `pong.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/pong/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **Java:** `src/` değişince `app.jar`'ı PC'de yeniden derleyin: `python tools/java_build.py app SDK/Samples/java/pong/source` (JDK 8+; ya da `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/pong/source`).

Dosyalar (satır): `src/pong/PongApp.java` (202).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/pong/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
