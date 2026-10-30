# Bahşiş Bölüşücü (C)

[English](README.md) · **Türkçe**

Hesabı, bahşişi ve kişi başı payı hesaplayan, sonucu paylaşabilen küçük bir araç.

| | |
|---|---|
| Kimlik | `com.sonerx7.sample.tipcalc` |
| Dil | C (TinyCC, konsolda derlenir) |
| En düşük SDK | 1.5 |
| İzinler | yok |
| Kumanda | imleç |
| Pencere | 520 × 410, sabit |

## Ne öğretir

- `numeric` bayrağıyla `char` tamponunu yerinde düzenleyen `ui_textfield`; ondalık virgül desteği ve `strtod`
- Etiketleri döngüde kurulan `ui_segmented`, `ui_slider`, `ui_toggle`, `ui_iconButton`
- `ui_group` + `ui_separator` ile ayar satırları, `math.h` `ceil`
- `store_setStr/Num/Bool` ile son değerler, `TR3` + `sys_share`

**Kontroller:** Dokunma, imleç ya da klavye.

## Çalıştırma

- **Konsolda:** `source/` klasörünü `tipcalc.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın (ya da `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/tipcalc/source --host <konsol-ip>`) ve Launcher'dan açın. Nexvyn OS Studio'da klasörü açıp **Çalıştır** (Ctrl+R) ile de deneyebilirsiniz.
- **Ryujinx'te:** aynı klasörü emülatörün SD kart klasöründe `NexvynOS/Applications/` içine kopyalayın.
- **C:** derleme yok; `.c` dosyaları uygulama açılırken konsolda derlenir. SD karttan kurulan C uygulaması ilk açılışta bir kez onay ister.

Dosyalar (satır): `main.c` (139).

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/tipcalc/source

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
