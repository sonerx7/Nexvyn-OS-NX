# Nexvyn OS için DOSBox

Nexvyn OS (`1.3.5+`) için yerel pencere modunda çalışan MS-DOS PC emülatörü portu; **DOSBox Pure** (`1.0-preview8`) ve Nexvyn Native SDK `1.2` (`ABI v1`) ile güçlendirilmiştir.

| Alan | Değer |
|---|---|
| Uygulama Kimliği (ID) | `com.nexvyn.emu.dosbox` |
| Sürüm | `1.0.0` |
| Mağaza Kanalı / Kategori | Beta (`Store/Beta/Emulators/pc/dosbox/` → `Store/beta.json`, `kind: "emulator"`, `emuCategory: "pc"`) |
| Çalışma Zamanı (Runtime) | `native` (`aarch64`, pencereli / tam ekran `.nxvmod`, Native SDK `1.2`, `ABI v1`) |
| En Düşük Native / SDK | `1.2` / `1.13` (hedef `1.13`) |
| İzinler | `files` (dosya seçici veya komut satırından DOS dosyaları, disk imajları ve klasörleri açmak için) |
| Kaynak Kod (Upstream) | [https://codeberg.org/schelling/dosbox-pure](https://codeberg.org/schelling/dosbox-pure) (`1.0-preview8`, commit `519226d15dea41c146048ae43e40bac772b923c4`) |
| Lisans | GNU Genel Kamu Lisansı v2.0 veya üstü (`GPL-2.0-or-later`) |

## Kendi DOS yazılımlarınızı getirin

**Paket içerisinde oyun, BIOS veya ticari yazılım bulunmaz.** Kendi DOS dosyalarınızı veya paketlerinizi `sdmc:/NexvynOS/Roms/dos/` klasörüne kopyalayın, **Oyun / Paket Aç** düğmesiyle bir dosya seçin veya doğrudan etkileşimli bir DOS komut satırına girmek için **MS-DOS Komut Satırını Başlat (C:\>)** düğmesine tıklayın.

- **Desteklenen Biçimler:** `.zip`, `.dosz`, `.exe`, `.com`, `.bat`, `.iso`, `.cue`, `.chd`, `.img`, `.ima`, `.vhd`, `.jrc` ve `.conf`.
- **Doğrudan Arşiv Bağlama:** ZIP ve DOSZ paketleri dışa aktarılmadan doğrudan sanal sürücü olarak bağlanır.
- **Durum Kayıtları:** Duraklatma çekmecesinden veya pencere menüsünden hızlıca kaydedilip yüklenebilen 5 bağımsız yuva.
- **Çoklu Disk Yönetimi:** Disket veya CD disk imajlarını Duraklatma çekmecesinden çalışma anında değiştirme.

## Özellikler ve Nexvyn OS Entegrasyonu

- **Donanım Öykünmesi:** Sound Blaster 16, AdLib/OPL3, Gravis Ultrasound, PC Hoparlörü ve MIDI seslerinin `nxn_audio` üzerinden 44.1 kHz gerçek zamanlı karıştırılması.
- **Dinamik Derleyici ve Yedekleme:** Nexvyn OS üzerinde JIT mevcut olduğunda `nxn_jit_*` recompiler kullanılır; JIT kapalıysa kesintisiz olarak Normal x86 yorumlayıcı çekirdeğine geçilir.
- **Yerel Masaüstü Penceresi:** OpenGL ES 3.2 çizimi, Oranlı Sığdırma (4:3), Tam Piksel Ölçekleme, Pencereyi Doldurma, Keskin ve Yumuşak doku filtreleri, sistem teması uyumu (`nxn_ui_tokens`) ve Türkçe/İngilizce dil desteği (`nxn_tr`).
- **Giriş ve Dokunmatik Desteği:**
  - DOSBox Pure çekirdeği ile otomatik oyun kumandası (Joy-Con / Pro Controller) tuş eşlemesi.
  - Doğrudan Dokunuş ve İzleme Dörtgeni (Trackpad) dokunmatik fare modları.
  - Dahili Ekran Klavyesi ve üst Hızlı Dokunmatik Çubuğu (`Menü`, `Duraklat`, `Klavye`, `Hızlı Tuşlar`, `Hızlı İleri`).
  - USB HID Klavye ve Fare desteği (`F11` tam ekran açıp kapatır, `Ctrl+O` dosya seçiciyi açar).

## Kontroller

| Giriş | Başlatıcı Ekranı | MS-DOS Oturumu |
|---|---|---|
| **Dokunmatik / Fare** | Düğmeleri ve son açılanları seçme | Doğrudan dokunuş veya trackpad fare öykünmesi; üst Hızlı Dokunmatik Çubuğu |
| **Eksi (`-`) / Menü** | Ayarları açma | Duraklatma Çekmecesini aç/kapat (Kayıt 1–5, CD değiştirme, Ayarlar, Çıkış) |
| **Artı (`+`)** | Hakkında penceresi | Ekran Klavyesini aç/kapat |
| **Kumanda Kolları / Tuşları** | Arayüzde gezinme | DOS tuş eşlemesi (yön tuşları, Enter, Boşluk, ateş tuşları) |
| **USB Klavye** | Standart gezinme | Tam 101/104 tuşlu DOS klavyesi; `F11` tam ekran, `Ctrl+O` dosya seçimi |

## Lisans ve Emeği Geçenler

| Parça | Lisans | Kaynak |
|---|---|---|
| DOSBox Pure 1.0-preview8 (öykünme çekirdeği) | GPL-2.0-or-later | https://codeberg.org/schelling/dosbox-pure (commit `519226d15dea41c146048ae43e40bac772b923c4`) |
| DOSBox (temel çekirdek) | GPL-2.0-or-later | https://www.dosbox.com/ (The DOSBox Team) |
| Dear ImGui 1.91.5 (arayüz kütüphanesi) | MIT | https://github.com/ocornut/imgui |
| Simge (Icon) | GPL-2.0-or-later | DOSBox Pure projesinin özgün simgesi (`images/logo.png`) |
| Arayüz ve Nexvyn OS pencere portu | GPL-2.0-or-later | Bu portun Nexvyn OS Native Kit kaynakları |

Tam lisans metinleri `data/licenses/` klasöründe yer almaktadır (`DOSBOX_PURE_LICENSE.txt`, `DOSBOX-AUTHORS.txt`, `DOSBOX-THANKS.txt`, `IMGUI_LICENSE.txt`, `THIRD_PARTY_NOTICES.md`).

## Sürüm Geçmişi

| Sürüm | Tarih | Değişiklikler |
|---|---|---|
| `1.0.0` | 2026-11-11 | Beta kanalında ilk sürüm: pencereli native port, JIT recompiler + yorumlayıcı yedeği, Dokunmatik Çubuk ve Hızlı Tuşlar, Durum Kayıtları, çoklu disk yöneticisi ve özgün DOSBox Pure simgesi. |
