# Kronometre

[English](README.md) · **Türkçe**

Turlu kronometre: en hızlı tur yeşil, en yavaşı kırmızı; süre ve turlar kapatınca da korunur.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.stopwatch` |
| Dil | Squirrel 3.2 |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | imleç |
| Pencere | 480 × 520, yeniden boyutlanır |

## Ne öğretir

- Uygulama olarak sınıf; dizi alanları `load` içinde oluşturulur (sınıf varsayılanları paylaşılır)
- `update(dt)` yalnızca çalışırken her karenin yeniden çizilmesi için vardır
- `store` içinde tablo dizisi (`laps`)
- `ui.beginScroll` listesi, `enabled` ve `shortcut` alanlı menü öğeleri
- `sys.share(metin)` ile tur listesini paylaşma; `suspend`, `autosave`, `close`

**Kontroller:** Boşluk / Enter: başlat-durdur · L: tur · R: sıfırla (dururken).

## Çalıştırma

- **Konsolda:** `source/` klasörünü `stopwatch.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/stopwatch/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.

Dosyalar (satır): `main.nut` (146).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/stopwatch/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
