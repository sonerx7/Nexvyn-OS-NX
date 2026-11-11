# RA2 Yuri Port (Command & Conquer: Red Alert 2 & Yuri's Revenge)

*Command & Conquer: Red Alert 2* ve *Yuri's Revenge* oyununun Nexvyn OS için yerel AArch64 statik yeniden derleme (static recompilation) portu (Native SDK 1.1 / ABI v1).

| Alan | Değer |
|---|---|
| Uygulama Kimliği | `com.sonerx7.redalert2` |
| Mağaza Adı | `RA2 Yuri Port` |
| Kanal / Kategori | Beta (`Store/Beta/Ports/redalert2` -> `Store/beta.json`, `kind: "port"`) |
| Çalışma Zamanı | `native` (`aarch64`, pencereli `.nxvmod`) |
| Min SDK / Native | `1.10` / `1.1` (hedef `1.13`) |
| İzinler | `files` (SD kart oyun veri erişimi) |
| Kaynak | [sp00nznet/redalert2-recomp](https://github.com/sp00nznet/redalert2-recomp) & [pcrecomp](https://github.com/sp00nznet/pcrecomp) |
| Lisans | MIT (Yeniden derleme motoru ve host köprüsü) |

---

## Önemli Telif Hakkı Uyarısı (Oyun Dosyaları Dahil Değildir)

Bu paket **yalnızca** açık kaynaklı statik yeniden derleme motorunu ve Nexvyn OS yerel host köprüsünü (`ra2.nxvmod`) içerir. **Hiçbir ticari oyun dosyası (`.mix`, `.exe`, `.dll`) pakette yer almaz.** Oyunu oynamak için kendi yasal *Command & Conquer: Red Alert 2 - Yuri's Revenge* (v1.001, Steam veya EA App) kopyanızdan oyun dosyalarını sağlamanız gerekir.

---

## Adım Adım Kurulum Kılavuzu

### Gerekli Oyun Dosyaları

PC'nizdeki Yuri's Revenge kurulum klasöründen şu dosyaları hazırlayın:

1. **Ana Çalıştırılabilir Dosya:**
   - `gamemd.exe` (PE Zaman Damgası: `0x3BDF544E`, sürüm 1.001)
2. **Temel MIX Arşivleri:**
   - `ra2md.mix`, `ra2.mix`
   - `language.mix`, `langmd.mix` (veya `langmd_eng.mix`)
   - `theme.mix`, `thememd.mix`
   - `multimd.mix`, `multi.mix`
   - `mapsmd03.mix`, `maps01.mix`, `maps02.mix`
   - `expandmd01.mix`
3. **Yapılandırma ve Kütüphaneler:**
   - `ra2md.ini`, `ra2.ini`
   - `Blowfish.dll`, `Binkw32.dll`

### Kurulum Adımları

1. Nexvyn OS App Market uygulamasını açın ve **Beta** sekmesinden **RA2 Yuri Port**'u indirin (Yükle).
2. Nintendo Switch SD kartınızı bilgisayarınıza takın veya Nexvyn OS Dosyalar uygulamasını kullanın.
3. Uygulamanın kurulu olduğu klasöre gidin:
   ```text
   sdmc:/NexvynOS/Applications/com.sonerx7.redalert2.nxvapp/game/
   ```
   *(Alternatif arama konumu: `sdmc:/switch/openra2/`)*
4. Yukarıda listelenen tüm oyun dosyalarını bu `game/` klasörünün içine kopyalayın.
5. Nexvyn OS Başlatıcı veya Masaüstünden **RA2 Yuri Port**'u başlatın!

---

## Kontroller

- **Sol Analog Çubuk:** Akıcı fare imleci simülasyonu
- **A / ZR:** Sol fare tıklaması (birlik seçme, emir verme, bina inşa etme)
- **B / ZL:** Sağ fare tıklaması (iptal, seçimi bırakma)
- **D-Pad:** Haritada gezinme (kamera kaydırma)
- **Dokunmatik Ekran:** Doğrudan dokunarak tıklama ve sürükleme
- **Plus (+):** Oyun içi seçenekler / Duraklatma menüsü
