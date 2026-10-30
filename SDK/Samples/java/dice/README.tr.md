# Zar Atıcı (Java)

[English](README.md) · **Türkçe**

d4'ten d20'ye bir ile altı zar at, bazılarını tut, son on iki atışı gör.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.dice` |
| Dil | Java 8 (miniJVM) |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | imleç |
| Pencere | 560 × 520, yeniden boyutlanır |

## Ne öğretir

- `update()` yalnızca atış animasyonu sırasında iş yapar
- `java.util.Random`, diziler, `String[]` ile `Ui.segmented`
- `Ui.hit(...)` → `Record`; `hit.bool("clicked")`
- `Store` içinde `Record` listesi (geçmiş)
- Kapalı öğeli `Menu.bar`, `Audio.tone`, `Sys.vibrate`

**Kontroller:** Boşluk / Enter: at · zara dokun: tut / bırak.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `dice.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/dice/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **Java:** `src/` değişince `app.jar`'ı PC'de yeniden derleyin: `python tools/java_build.py app SDK/Samples/java/dice/source` (JDK 8+; ya da `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/dice/source`).

Dosyalar (satır): `src/dice/DiceApp.java` (175).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/dice/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
