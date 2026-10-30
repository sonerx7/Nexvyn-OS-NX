# Üçüncü taraf bileşenler / Third-party components

Nexvyn OS, **GPL-3.0-or-later** lisansıyla dağıtılır (bkz. [LICENSE](LICENSE)). Aşağıdaki bileşenler Nexvyn OS ikili dosyasına (`NexvynOS.nro`) bağlanır; hepsi GPLv3 ile uyumlu lisanslara sahiptir.

Nexvyn OS is distributed under **GPL-3.0-or-later**. The components below are linked into `NexvynOS.nro`; all of them are under licenses compatible with GPLv3.

| Bileşen / Component | Lisans / License | Kullanım / Use |
|---|---|---|
| libnx (switchbrew) | ISC | Switch sistem servisleri |
| SDL2, SDL2_image, SDL2_ttf, SDL2_mixer | zlib (devkitPro paketi LGPL bileşenler içerebilir / package may include LGPL parts) | Pencere, çizim, ses |
| FFmpeg (devkitPro `switch-ffmpeg`) | GPL | Video / ses çözme |
| dav1d | BSD-2-Clause | AV1 çözme |
| libcurl | curl (MIT tarzı) | HTTP(S), FTP |
| mbed TLS | Apache-2.0 | Şifreleme |
| minizip / zlib | zlib | Zip arşivleri |
| Lua 5.4 | MIT | Uygulama dili |
| QuickJS-ng | MIT | JavaScript motoru |
| pocketpy 2.2.0 (`lib/pocketpy`) | MIT | Python yorumlayıcısı |
| CPython 3.12.16 (`tools/build_cpython.sh`, Python Software Foundation) ve standart kütüphanesi (`romfs/System/Python3/lib.zip`) | PSF-2.0 (Python Software Foundation License Version 2; GPL uyumlu / GPL-compatible) | `"python3"` çalışma ortamı; `tools/cpython_tool.py`'de "Nexvyn OS" işaretli değişiklikler. Kendi içindeki HACL* (MIT/Apache-2.0) ve BLAKE2 (CC0) kodu dahil |
| Squirrel 3.2 (`lib/squirrel`, Alberto Demichelis) | MIT | Squirrel çalışma ortamı (SDK 1.5); `sqvm.cpp`'de işaretli bir değişiklik |
| TinyCC 0.9.28rc (`lib/tinycc`, Fabrice Bellard ve katkıcılar) | LGPL-2.1-or-later | C uygulamalarını konsolda derler (SDK 1.5); `tccrun.c` ve `tcc.h`'de işaretli `__SWITCH__` değişiklikleri, `config.h` bizim |
| miniJVM 2.2.0 (`lib/minijvm`, Gust) | MIT (C kaynakları) | Java çalışma ortamı (SDK 1.5); işaretli `__SWITCH__` değişiklikleri |
| miniJVM sınıf kütüphanesi `romfs/System/Java/minijvm_rt.jar` | GPLv2 + yazarın ikili jar istisnası | 2.2.0 sürümündeki jar olduğu gibi |
| stb_image | MIT / Public Domain | Resim çözme |
| libusbhsfs (ISC yapı) + FatFs | ISC + FatFs lisansı | USB bellek |
| libretro API başlığı | MIT | Retro çekirdek arayüzü |
| eSpeak NG 1.52.0 (`lib/espeak-ng`, Reece H. Dunn, Jonathan Duddington ve katkıcılar) + ucd-tools | GPL-3.0-or-later (Unicode verisi / Unicode data: Unicode lisansı, `COPYING.UCD`) | Metin okuma (TTS) ve Ekran Okuyucu; yalnızca sentezleyici, `config.h`, `Makefile` ve `src/include/compat/endian.h` bizim |
| Inter, JetBrains Mono | SIL OFL 1.1 | Yazı tipleri |
| Material Symbols / Icons | Apache-2.0 | İkonlar |

## SDK 1.5 çalışma ortamları / SDK 1.5 runtimes

- **TinyCC (LGPL-2.1):** statik bağlanır. LGPL, kullanıcının kütüphaneyi değiştirip uygulamayı yeniden
  bağlayabilmesini ister; Nexvyn OS'un kaynak kodu (TinyCC kaynakları ve yapılan değişiklikler `lib/tinycc` içinde)
  bunu sağlar. Kaynak kapalı bir dağıtımda nesne dosyaları da verilmelidir. / TinyCC is linked statically; LGPL-2.1
  requires that users can modify it and relink: the Nexvyn OS sources (with `lib/tinycc` and its marked changes)
  provide that. A closed-source distribution would have to ship the object files too.
- **miniJVM:** C kaynakları MIT. `minijvm/java` kaynakları GPLv2'dir; yazar, sürümle gelen `minijvm_rt.jar` ikilisinin
  GPL'in bulaşıcılığı olmadan kullanılabileceğini belirtir (depo `LICENSE` dosyası). Nexvyn OS bu jar'ı değiştirmeden
  dağıtır. / The C sources are MIT; the Java class library sources are GPLv2, and the author states that the released
  `minijvm_rt.jar` binary can be used without the GPL's copyleft. Nexvyn OS ships that jar unchanged.
- **Squirrel (MIT)** ve Java SDK'sı `sdk/java` (Nexvyn OS, GPL-3.0-or-later) / and the Java SDK `sdk/java`.

## CPython / CPython

- **PSF-2.0:** Python Software Foundation lisansı GPL ile uyumludur ve değişikliklerin özetlenmesini ister: CPython
  3.12.16 newlib + libnx için derlenir, değişiklikler `tools/cpython_tool.py` (yol, rastgele sayı, saat dilimi) ve
  `lib/cpython/pyconfig_switch.h` içindedir. Lisans metni: kaynak arşivindeki `LICENSE`
  (<https://docs.python.org/3.12/license.html>). / The PSF license is GPL-compatible and asks for a summary of the
  changes: CPython 3.12.16 is built for newlib + libnx; the changes are in `tools/cpython_tool.py` (paths, random
  numbers, time zone names) and `lib/cpython/pyconfig_switch.h`. License text: `LICENSE` in the source archive.

## Veri / Data

| Veri / Data | Kaynak / Source | Lisans / License | Kullanım / Use |
|---|---|---|---|
| `romfs/System/Keyboard/words_tr.txt`, `words_en.txt`, `words_de.txt`, `words_fr.txt`, `words_es.txt` | [FrequencyWords](https://github.com/hermitdave/FrequencyWords) (Hermit Dave), OpenSubtitles 2018 sıklık listeleri / frequency lists | CC BY-SA 4.0 (veri / content), MIT (kod / code) | Ekran klavyesinin kelime önerileri / on-screen keyboard word suggestions |
| `romfs/System/Speech/espeak-ng-data` (phontab, phonindex, phondata, intonations, `en`/`tr`/`de`/`fr`/`es`/`ja`/`ko` sözlükleri / dictionaries, `lang/` dosyaları / files) | [eSpeak NG 1.52.0](https://github.com/espeak-ng/espeak-ng/releases/tag/1.52.0): derlenmiş veri resmi `espeak-ng.msi` sürüm paketinden, `lang/` dosyaları kaynak arşivinden (`gmw/en-US` küçük harfle `en-us` adıyla) / compiled data from the official release MSI, `lang/` files from the source archive (`gmw/en-US` stored lower-case as `en-us`) | GPL-3.0-or-later | Metin okuma sesleri / text-to-speech voices |

Listeler `tools/gen_wordlist.py` ile üretilir: en sık 20 000 Türkçe ve 15'er bin İngilizce, Almanca, Fransızca ve İspanyolca kelime, yalnızca harflerden oluşanlar, kaba sözler çıkarılmış. Almanca, Fransızca ve İspanyolca listeler ayrıca LibreOffice Hunspell sözlükleriyle süzülür (yalnızca filtre olarak; sözlüklerden hiçbir şey kopyalanmaz). Uyarlanmış bu veri de CC BY-SA 4.0 altındadır; CC BY-SA 4.0, GPLv3 ile tek yönlü uyumludur (Creative Commons, 2015).

The lists are made by `tools/gen_wordlist.py`: the 20,000 most frequent Turkish words and the 15,000 most frequent English, German, French and Spanish words, letters only, vulgar words removed. The German, French and Spanish lists are also filtered with the LibreOffice Hunspell dictionaries (used only as a filter; nothing is copied from them). This adapted data is also under CC BY-SA 4.0, which is one-way compatible with GPLv3 (Creative Commons, 2015).

Ses verisi değiştirilmeden kopyalandı; kaynağı (`phsource/`, `dictsource/`) eSpeak NG 1.52.0 kaynak arşivindedir. Çince (`cmn_dict`, 1,5 MB) boyutu nedeniyle eklenmedi.

The voice data is copied unchanged; its source (`phsource/`, `dictsource/`) is in the eSpeak NG 1.52.0 source archive. Chinese (`cmn_dict`, 1.5 MB) is left out for its size.

## İsteğe bağlı: retro çekirdekleri / Optional: retro cores

`tools/build_retro_cores.sh` ile derlenip eklenirler. Yalnızca GPLv3 uyumlu çekirdekler seçildi.

They are built and linked with `tools/build_retro_cores.sh`; only GPLv3-compatible cores are used.

| Çekirdek / Core | Sistem / System | Lisans / License |
|---|---|---|
| FCEUmm | NES | GPL-2.0-or-later |
| SameBoy | Game Boy / Color | MIT |
| mGBA | Game Boy Advance | MPL-2.0 |
| Supafaust (Mednafen) | SNES | GPL-2.0-or-later |
| ClownMDEmu | Mega Drive / Genesis | AGPL-3.0-or-later (GPLv3 §13 ile birleştirilebilir / combinable under GPLv3 §13) |
| BlastEm (yedek / fallback) | Mega Drive / Genesis | GPL-3.0 |

Kullanılmayanlar / Not used: "ticari olmayan" lisanslı çekirdekler (Snes9x 2010, Genesis Plus GX, PicoDrive) ve yalnızca GPLv2 olanlar (Gambatte). Bunlar GPLv3 ile birleştirilemez.

## Ayrı programlar / Separate programs

Nexvyn OS'un indirip kurabildiği homebrew uygulamalar (CorkDeck, Autorun, Moonlight vb.) Nexvyn OS'a **bağlanmaz**; kendi lisanslarıyla ayrı programlar olarak çalışırlar.

Homebrew apps that Nexvyn OS can download and install (CorkDeck, Autorun, Moonlight, …) are **not** linked into Nexvyn OS; they run as separate programs under their own licenses.

## YamaNX

`romfs/Applications/yamanx.app` YamaNX'in Nexvyn OS'a Lua ile yapılmış port'udur. Orijinal: **YamaNX — SertAy**,
https://github.com/sertay1/YamaNX. Kendi lisansıyla (SertAy, ticari olmayan kullanım, atıf zorunlu) ayrı bir program
olarak gelir; Nexvyn OS koduna bağlanmaz. Lisans metni ve yapılan değişiklikler: `yamanx.app/LICENSE`, `yamanx.app/NOTICE.md`.

`romfs/Applications/yamanx.app` is a Lua port of YamaNX to Nexvyn OS. Original: **YamaNX by SertAy**,
https://github.com/sertay1/YamaNX. It ships as a separate program under its own license (SertAy, non-commercial,
attribution required) and is not linked into Nexvyn OS. License text and the list of modifications:
`yamanx.app/LICENSE`, `yamanx.app/NOTICE.md`.
