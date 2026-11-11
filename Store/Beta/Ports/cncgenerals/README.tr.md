# C&C Generals: Zero Hour Portu (Nexvyn OS)

*Command & Conquer Generals: Zero Hour* (SAGE Motoru) oyununun Nexvyn OS için yerel AArch64 statik yeniden derleme (static recompilation) portu (Native SDK 1.1 / ABI v1).

| Alan | Değer |
|---|---|
| Uygulama Kimliği | `com.sonerx7.cncgenerals` |
| Mağaza Adı | `C&C Generals: Zero Hour` |
| Kanal / Kategori | Beta (`Beta/Ports/cncgenerals`, `kind: "port"`) |
| Çalışma Zamanı | `native` (`aarch64`, pencereli `.nxvmod`) |
| Min SDK / Native | `1.10` / `1.1` (hedef `1.12`) |
| İzinler | `files` (SD kart oyun veri erişimi) |
| Kaynak | [sp00nznet/pcrecomp](https://github.com/sp00nznet/pcrecomp) (Win32 HLE + D3D8 -> GLES köprüsü) |
| Lisans | MIT (Yeniden derleme motoru ve host köprüsü) |

---

## Önemli Telif Hakkı Uyarısı (Oyun Dosyaları Dahil Değildir)

Bu paket **yalnızca** açık kaynaklı statik yeniden derleme motorunu ve Nexvyn OS yerel host köprüsünü (`cncgenerals.nxvmod`) içerir. **Hiçbir ticari oyun dosyası (`.big`, `game.dat`, `.dll`) pakette yer almaz.** Oyunu oynamak için kendi yasal *Command & Conquer: Generals — Zero Hour* (v1.04) kopyanızdan oyun dosyalarını sağlamanız gerekir.

---

## Adım Adım Kurulum Kılavuzu

### Gerekli Oyun Dosyaları

PC'nizdeki Zero Hour 1.04 kurulum klasöründen şu dosyaları hazırlayın:

1. **Ana Çalıştırılabilir / Veri Dosyası:**
   - `game.dat` (PE Zaman Damgası: `0x4230C05B`, sürüm 1.04)
2. **Temel BIG Arşivleri:**
   - `INIZH.big`, `MapsZH.big`, `MusicZH.big`
   - `Patch1.big` .. `Patch4.big`
   - `SpeechEnglishZH.big` (veya Türkçe/yerel ses arşivi)
   - `TerrainZH.big`, `TexturesZH.big`, `WindowZH.big`
   - `W3DZH.big`
3. **Veri Klasörleri:**
   - `Data/INI/`, `Data/English/`

### Kurulum Adımları

1. Nexvyn OS sisteminize **C&C Generals: Zero Hour** paketini kurun.
2. Nintendo Switch SD kartınızı bilgisayarınıza takın veya Nexvyn OS Dosyalar uygulamasını kullanın.
3. Uygulamanın kurulu olduğu klasöre gidin:
   ```text
   sdmc:/NexvynOS/Applications/com.sonerx7.cncgenerals.nxvapp/gamefiles/
   ```
   *(Alternatif arama konumu: `sdmc:/switch/cncgenerals/`)*
4. Yukarıda listelenen tüm `.big` arşivlerini ve `game.dat` dosyasını bu `gamefiles/` klasörünün içine kopyalayın.
5. Nexvyn OS Başlatıcı veya Masaüstünden oyunu başlatın!

---

## Kontroller

- **Sol Analog Çubuk:** Akıcı fare imleci simülasyonu
- **A / ZR:** Sol fare tıklaması (birlik seçme, emir verme, bina inşa etme)
- **B / ZL:** Sağ fare tıklaması (iptal, seçimi bırakma)
- **D-Pad:** Haritada gezinme (kamera kaydırma)
- **Dokunmatik Ekran:** Doğrudan dokunarak tıklama ve sürükleme
- **Plus (+):** Oyun içi seçenekler / Duraklatma menüsü
