# Hayat Oyunu (C)

[English](README.md) · **Türkçe**

Conway'in Hayat Oyunu: hücre çiz, çalıştır, adım adım ilerlet; tahta kapatınca kaydedilir.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.life` |
| Dil | C (TinyCC, konsolda derlenir) |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | imleç |
| Pencere | 720 × 520, yeniden boyutlanır |

## Ne öğretir

- Statik diziler ve kenarları saran komşu sayımı
- `app_update` içinde sabit adım (saniyede 1-30 nesil, `ui_slider`)
- `ui_hit` + `ui_mouse` ile boyama: ilk hücre çizme mi silme mi olduğunu belirler
- Dönen metinler 15 SDK çağrısı yaşar: `theme_color` döngüden önce `snprintf` ile kopyalanır
- `app_menu`, `app_suspend`, `app_autosave` / `app_close` içinde `store_setStr`

**Kontroller:** Boşluk: oynat / duraklat · N: adım · R: rastgele · C: temizle · sürükle: hücre çiz / sil.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `life.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/life/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **C:** derleme yok; `.c` dosyaları uygulama açılırken konsolda derlenir. SD karttan kurulan C uygulaması ilk açılışta bir kez onay ister.

Dosyalar (satır): `main.c` (173).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/life/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
