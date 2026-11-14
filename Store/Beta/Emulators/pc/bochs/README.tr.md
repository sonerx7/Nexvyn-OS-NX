# Nexvyn OS için Bochs x86 / x86-64 PC Emülatörü

[English](README.md) · **Türkçe**

Konsol (`Cortex-A57`, `-O3 -fno-strict-aliasing`) için optimize edilmiş Dear ImGui + OpenGL 4.3 Core arayüzlü **Bochs `REL_3_1_FINAL`** yerel AArch64 pencere modu portu (`runtime: "native"`, `mode: "window"`, Native SDK `1.2`, Store Beta kanalı `Store/Beta/Emulators/pc/bochs/` -> `Store/beta.json`, `kind: "emulator"`, `emuCategory: "pc"`).

| Alan | Değer |
|---|---|
| Uygulama Kimliği (ID) | `com.nexvyn.emu.bochs` |
| Sürüm | `3.1.1` |
| Mağaza Kanalı / Kategori | Beta (`Store/Beta/Emulators/pc/bochs/`, `emuCategory: "pc"`) |
| Çalışma Alanı Konumu | `Beta/Emulators/pc/bochs/` |
| Çalışma Zamanı (Runtime) | `native` (`aarch64`, pencereli `.nxvmod`) |
| Asgari Native / SDK | `1.2` / `1.10` (hedef `1.13`) |
| İzinler | `files` (disk/ISO/disket/.bxrc kalıplarını açma, sanal disk oluşturma ve profil/checkpoint saklama), `network` (isteğe bağlı SLIRP kullanıcı modu ağ) |
| Kaynak Proje | [bochs-emu/Bochs](https://github.com/bochs-emu/Bochs) (`REL_3_1_FINAL`, commit `30cfd566ecc8deb33e56e801e32b444a7041b6d2`) |
| Lisans | LGPL-2.1-or-later (Bochs ve LGPL VGABIOS), LGPL-3.0 / GPL-3.0 (SeaBIOS), MIT (Dear ImGui) |

## Özellikler
- **x86 / x86-64 İşlemci Emülasyonu & Konsol Profilleri:** i386 ile Core i7 arası seçilebilir işlemciler; MS-DOS/FreeDOS, Win9x (`pentium`, PIIX3/ISA kararlılığı), WinXP (`p3_katmai`, `512 MB`, `fastboot`, `imps2`, ES1370/NE2000), ReactOS (`core_duo_t2400_yonah`), hafif Linux (`core2_penryn_t9600`, E1000) ve Win7/10 Lite (`corei7_sandy_bridge_2600k`, `640 MB`, E1000) için hazır ayarlar.
- **Dahili Açık Kaynak BIOS & VGABIOS:** Paket içinde açık kaynak `BIOS-bochs-latest`, `BIOS-bochs-legacy`, `SeaBIOS 1.16` (`bios.bin-1.16.0`) ve LGPL VGA BIOS ROM'ları (`VGABIOS-lgpl-latest.bin`, `Cirrus`, `Voodoo Banshee`) gelir; harici ROM seçimi de desteklenir. Ticari veya telifli hiçbir BIOS ya da işletim sistemi kalıbı içermez.
- **Depolama, Büyüyen Diskler ve Veri Güvenliği:** Çalışırken takılıp çıkarılabilen çift disket sürücüsü, otomatik CHS geometrili birincil/ikincil ATA diskler ve CD-ROM'lar; anında oluşturulan 32 GB'a kadar Bochs `growing` (büyüyen) diskler ve 4095 MB'a kadar iptal edilebilir `flat` RAW disk oluşturucu; `.bochsrc` içe/dışa aktarma, silme onayları ve profil/checkpoint'leri sistem güncellemelerinden koruyan harici kalıcı klasör (`NXN_PICK_FOLDER | NXN_PICK_REMEMBER`) desteği.
- **Ses ve Ağ:** `Sound Blaster 16`, `Ensoniq ES1370` ve dahili PC hoparlörü (`nxn_audio_*`); `SLIRP` NAT ve yalıtılmış `VNET` sanal ağları (`e1000`, `ne2000`, `pcipnic`).
- **Nexvyn OS Bütünleşmesi ve Kontroller:** Yerel menü çubuğu (`nxn_menu_*`), açık/koyu sistem teması, iki dilli EN/TR arayüz, OS dosya/klasör seçicisi (`nxn_pick`), tam kontrolcü gezintisi (`L1`/`R1` sekme geçişi, D-Pad/sol çubuk odak, `A`/`B` onay/iptal), hassas dokunmatik ekran kontrolü ve tuval ayrımı, fiziksel USB klavye + fare yakalama ve ekran PC klavyesi (`Minus` veya araç çubuğu).

## Klasör Düzeni (`STORE_STRUCTURE.md`)
- `source/` — Mağazaya hazır paket içeriği (`app.json`, `bochs.nxvmod`, `icon.png`, `lang/`, `data/`)
- `store.json` — Mağaza Beta metaverisi (`kind: "emulator"`, `emuCategory: "pc"`, `beta: true`)
- `screenshots/` — 1.png .. 4.png (İngilizce arayüz ekran görüntüleri)
- `tests/` — `nxvtest` otomatik test senaryoları (`tests/start.json`)
