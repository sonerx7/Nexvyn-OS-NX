# Yılan (Squirrel)

[English](README.md) · **Türkçe**

Klasik yılan oyunu: kumanda, klavye ve dokunmatikle; kenarlar karşıdan devam eder, en iyi puan kaydedilir.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.snake` |
| Dil | Squirrel 3.2 |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | uygulamaya gider (L+R: imleç) |
| Pencere | 640 × 480, yeniden boyutlanır |

## Ne öğretir

- `"gamepad": true` ve `paddown` olayları; klavyede oklar ve WASD
- `update(dt)` içinde sabit adımlı oyun döngüsü, sıraya alınan dönüşler
- `rand()` / `srand()`, `const`, dosya düzeyinde `local` tablo
- `ui.hit` + `ui.mouse` ile dokunarak yön verme
- `audio.tone`, `sys.vibrate`, `suspend` ve `focus` ile duraklatma

**Kontroller:** Yön tuşları / oklar / WASD: yön · A, + , Enter, Boşluk: başla / devam · + , Esc, P: duraklat · dokunma: başın yanına dokun.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `snake.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/snake/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `main.nut` (171).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/snake/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
