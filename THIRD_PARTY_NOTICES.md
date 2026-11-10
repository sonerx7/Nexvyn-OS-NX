# Üçüncü taraf bileşenler / Third-party components

Nexvyn OS, **GPL-3.0-or-later** lisansıyla dağıtılır (bkz. [LICENSE](LICENSE)). Aşağıdaki bileşenler Nexvyn OS ikili dosyasına (`NexvynOS.nro`) bağlanır; hepsi GPLv3 ile uyumlu lisanslara sahiptir.

Nexvyn OS is distributed under **GPL-3.0-or-later**. The components below are linked into `NexvynOS.nro`; all of them are under licenses compatible with GPLv3.

| Bileşen / Component | Lisans / License | Kullanım / Use |
|---|---|---|
| libnx (switchbrew) | ISC | Switch sistem servisleri |
| SDL2, SDL2_image, SDL2_ttf, SDL2_mixer | zlib (devkitPro paketi LGPL bileşenler içerebilir / package may include LGPL parts) | Pencere, çizim, ses |
| SDL2 (devkitPro Switch fork, Nexvyn OS pencere sürücüleriyle / with the Nexvyn OS window drivers) | zlib (değiştirilmiş kaynak: `sdk/native/sdl2`, `sdk/native/sysroot/patches/sdl2-nexvyn.patch` / altered source) | Native kit: pencerede SDL2 / SDL2 in windows |
| FFmpeg (devkitPro `switch-ffmpeg`) | GPL | Video / ses çözme |
| dav1d | BSD-2-Clause | AV1 çözme |
| libcurl | curl (MIT tarzı) | HTTP(S), FTP |
| mbed TLS | Apache-2.0 | Şifreleme |
| minizip / zlib | zlib | Zip arşivleri |
| Lua 5.4 | MIT | Uygulama dili |
| QuickJS-ng | MIT | JavaScript motoru (tek yama: `JS_ReadRegExp` nesne başvuru tablosuna kaydolur, `lib/quickjs/quickjs.c`) |
| wasm3 (`lib/wasm3`, commit 28ecb9af6d2040e474a70f7cb7f43666740141fb = v0.9.1-beta.1 + 18, Steven Massey, Volodymyr Shymanskyy) | MIT (`lib/wasm3/LICENSE`) | Tarayıcının `WebAssembly` desteği (`web.wasm`) / the browser WebAssembly engine; yalnızca yorumlayıcı çekirdeği alındı (`m3_api_*`, uzantılar, platformlar yok), kendi dosyamız `source/nexvyn_shim.c/.h`, özellik anahtarları Makefile'da (`W3DEFS`), ayrıntı `lib/wasm3/README.nexvyn` |
| pocketpy 2.2.0 (`lib/pocketpy`) | MIT | Python yorumlayıcısı |
| CPython 3.12.16 (`tools/build_cpython.sh`, Python Software Foundation) ve standart kütüphanesi (`romfs/System/Python3/lib.zip`) | PSF-2.0 (Python Software Foundation License Version 2; GPL uyumlu / GPL-compatible) | `"python3"` çalışma ortamı; `tools/cpython_tool.py`'de "Nexvyn OS" işaretli değişiklikler. Kendi içindeki HACL* (MIT/Apache-2.0) ve BLAKE2 (CC0) kodu dahil |
| Squirrel 3.2 (`lib/squirrel`, Alberto Demichelis) | MIT | Squirrel çalışma ortamı (SDK 1.5); `sqvm.cpp`'de işaretli bir değişiklik |
| TinyCC 0.9.28rc (`lib/tinycc`, Fabrice Bellard ve katkıcılar) | LGPL-2.1-or-later | C uygulamalarını konsolda derler (SDK 1.5); `tccrun.c` ve `tcc.h`'de işaretli `__SWITCH__` değişiklikleri, `libtcc.c` ve `tccasm.c`'de işaretli "Nexvyn OS" değişiklikleri (dosya erişimi kontrolü, inline assembly reddi), `config.h` bizim |
| miniJVM 2.2.0 (`lib/minijvm`, Gust) | MIT (C kaynakları) | Java çalışma ortamı (SDK 1.5); işaretli `__SWITCH__` değişiklikleri |
| miniJVM sınıf kütüphanesi `romfs/System/Java/minijvm_rt.jar` | GPLv2 + yazarın ikili jar istisnası | 2.2.0 sürümündeki jar olduğu gibi |
| stb_image | MIT / Public Domain | Resim çözme |
| ufbx 0.23.1 (`lib/ufbx`, Samuli Raivio) | MIT (ya da Public Domain / or Public Domain, `LICENSE`) | `.fbx` 3B model okuma (SDK 1.8, `g3d.model`), değiştirilmedi / unmodified |
| cgltf 1.15 (`lib/cgltf`, Johannes Kuhlmann) | MIT (`LICENSE`) | `.gltf` / `.glb` 3B model okuma (SDK 1.8, `g3d.model`), değiştirilmedi / unmodified; `cgltf_impl.c` bizim |
| libusbhsfs (ISC yapı) + FatFs | ISC + FatFs lisansı | USB bellek |
| libretro API başlığı | MIT | Retro çekirdek arayüzü |
| eSpeak NG 1.52.0 (`lib/espeak-ng`, Reece H. Dunn, Jonathan Duddington ve katkıcılar) + ucd-tools | GPL-3.0-or-later (Unicode verisi / Unicode data: Unicode lisansı, `COPYING.UCD`) | Metin okuma (TTS) ve Ekran Okuyucu; yalnızca sentezleyici, `config.h`, `Makefile` ve `src/include/compat/endian.h` bizim |
| Inter, JetBrains Mono | SIL OFL 1.1 | Yazı tipleri |
| Pixel Operator | CC0 1.0 | Piksel yazı tipi (Classic tema) |
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

## Native SDK kiti / Native SDK kit

Native SDK kitindeki (`sdk/native/`) üçüncü parti kod Nexvyn OS'a bağlanmaz; yalnızca geliştiricinin kendi
app'ine derlenir.

Third-party code in the Native SDK kit (`sdk/native/`) is not linked into Nexvyn OS; it is only compiled into the
developer's own app.

- **Dear ImGui** 1.91.5 (`sdk/native/sysroot/vendor/imgui/`) — MIT License, Copyright (c) 2014-2024 Omar Cornut.
  https://github.com/ocornut/imgui

Sysroot kütüphaneleri (`sdk/native/sysroot/build.py` ile statik derlenir, kit arşivinde kaynak sürümü ve lisans dosyası
yer alır) / Sysroot libraries (built as static libraries by `sdk/native/sysroot/build.py`; the kit archive carries each
version and licence file):

- **zstd** 1.5.6 — BSD-3-Clause (Meta Platforms). https://facebook.github.io/zstd/
- **LZ4** 1.10.0 (kütüphane / library) — BSD-2-Clause (Yann Collet). https://lz4.org/
- **SQLite** 3.47.2 — kamu malı / public domain. https://www.sqlite.org/
- **libarchive** 3.7.7 — BSD-2-Clause (Tim Kientzle ve katkıda bulunanlar / and contributors). https://libarchive.org/
- **OpenAL Soft** 1.23.1 — LGPL-2.0-or-later (Chris Robinson ve katkıda bulunanlar / and contributors).
  https://openal-soft.org/ — statik bağlama notu: `docs/NATIVE_KIT.*` / static linking note: `docs/NATIVE_KIT.*`.
- **GNU libiconv** 1.17 (kütüphane / library) — LGPL-2.1-or-later (Free Software Foundation).
  https://www.gnu.org/software/libiconv/ — statik bağlama notu: `docs/NATIVE_KIT.*` / static linking note: `docs/NATIVE_KIT.*`.
- **pixman** 0.43.4 — MIT. https://www.pixman.org/
- **GLib** 2.78.6 (glib, gobject, gthread, gmodule) — LGPL-2.1-or-later (GNOME Project). https://www.gtk.org/ —
  statik bağlama notu: `docs/NATIVE_KIT.*` / static linking note: `docs/NATIVE_KIT.*`.
- **PCRE2** 10.44 (GLib bağımlılığı / GLib dependency) — BSD-3-Clause, PCRE2 istisnasıyla / with the PCRE2 exception
  (Philip Hazel). https://github.com/PCRE2Project/pcre2
- **libffi** 3.4.6 (GLib bağımlılığı / GLib dependency) — MIT (Anthony Green, Red Hat ve katkıda bulunanlar / and
  contributors). https://libffi.github.io/

Sysroot'taki küçük yardımcı kaynaklar (`sysroot/shims/`, `sysroot/vendor/proxy-libintl/`, `sysroot/patches/`) Nexvyn
projesinin kendi kodudur (GPL-3.0-or-later); yamalar yalnızca ilgili kütüphanenin kendi lisansı altındaki dosyalara küçük
değişiklikler getirir. / The small helper sources in the sysroot (`sysroot/shims/`, `sysroot/vendor/proxy-libintl/`,
`sysroot/patches/`) are the Nexvyn project's own code (GPL-3.0-or-later); the patches only make small changes to files
that stay under their library's own licence.

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

## three.js (browser WebGL test page)

`romfs/Applications/browser.app/test/three.min.js` is three.js r149 (official build), MIT License, Copyright 2010-2023
three.js authors, https://github.com/mrdoob/three.js. It is only the test page `webgl_cube.html` of the built-in browser;
the license text is the header of the file.

## Port app'ler (App Market) / Ports (App Market)

Bu üç program App Market'ten ayrı kurulan, ayrı programlardır; Nexvyn OS'a bağlanmaz. Her paket kendi lisans metinlerini
(`data/licenses/`) ve kaynak bağlantılarını taşır. Pakette ticari oyun verisi, BIOS ya da firmware yoktur.

These three programs are installed on their own from the App Market; they are not linked into Nexvyn OS. Each package carries
its own licence texts (`data/licenses/`) and source links. No commercial game data, BIOS or firmware is included.

| Bileşen / Component | Lisans / License | Kaynak / Source |
|---|---|---|
| **Chocolate Doom** 3.1.0 (`Store/Games/action/chocolate-doom`) | GPL-2.0-or-later | https://github.com/chocolate-doom/chocolate-doom (etiket / tag `chocolate-doom-3.1.0`); Nexvyn OS yamaları pakette `data/licenses/patches/` / patches in the package |
| **Freedoom** 0.13.0, `freedoom1.wad` (Chocolate Doom paketinde / in the Chocolate Doom package) | BSD-3-Clause | https://github.com/freedoom/freedoom (v0.13.0) |
| **Ironwail** 0.8.0 (`Store/Games/action/ironwail`) | GPL-2.0-or-later | https://github.com/andrei-drexler/ironwail (commit `08d578136ff4`) |
| **LibreQuake** v0.09-beta lite (Ironwail paketinde / in the Ironwail package) | BSD-3-Clause (`progs.dat`, `pop.lmp`: GPL-2.0) | https://github.com/lavenderdotpet/LibreQuake |
| Tremor (libvorbisidec) ve / and libogg (yalnızca Ironwail'e bağlı / linked into Ironwail only) | BSD-3-Clause | https://gitlab.xiph.org/xiph/tremor , https://gitlab.xiph.org/xiph/ogg |
| **mGBA** 0.10.5 (`Store/Games/arcade/mgba`) | MPL-2.0 (değiştirilmemiş / unmodified) | https://github.com/mgba-emu/mgba (etiket / tag `0.10.5`) |
| blip_buf (mGBA içinde / inside mGBA) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (mGBA içinde / inside mGBA) | BSD-3-Clause | https://github.com/benhoyt/inih |
| mGBA project icon (`res/mgba-1024.png`, store icon of the mGBA package / mGBA paketinin simgesi) | MPL-2.0 (ölçeklendi / scaled) | https://github.com/mgba-emu/mgba/tree/master/res |
| **FCEUmm** (libretro, `Store/Games/arcade/fceumm`) | GPL-2.0-or-later (değiştirilmemiş / unmodified; copyright Xodnizel and contributors) | https://github.com/libretro/libretro-fceumm (commit `e0f3086a8104`) |
| **Gambatte** (libretro, `Store/Games/arcade/gambatte`) | GPL-2.0-only (değiştirilmemiş / unmodified; copyright Sindre Aamas and contributors) | https://github.com/libretro/gambatte-libretro (commit `77f2567d718b`) |
| **Genesis Plus GX** (libretro, `Store/Games/arcade/genesis-plus-gx`) | Özel, ticari olmayan / custom non-commercial licence (copyright Charles MacDonald, Eke-Eke, MAME team); paket ücretsiz / package is free | https://github.com/libretro/Genesis-Plus-GX (commit `b9c231644197`) |
| **Snes9x** (libretro, `Store/Games/arcade/snes9x`) | Özel, ticari olmayan / custom non-commercial licence (copyright Gary Henderson, Jerremy Koot and contributors); paket ücretsiz / package is free | https://github.com/libretro/snes9x (commit `fae2fea08f74`) |

Bu dört çekirdek ayrı kurulan, ayrı programlardır; OS'a link edilmez ve her paket lisans metnini, kaynak bağlantısını ve telif sahiplerini About sayfasında gösterir. Arayüz ve port: sonerx7, GPL-3.0-or-later. / These four cores are separate programs installed on their own, not linked into the OS; each package shows its licence text, source link and copyright holders on its About page. Frontend and port: sonerx7, GPL-3.0-or-later.

SDL2 ve SDL2_mixer (zlib) bu port app'lere yalnızca kendi paketlerinde bağlıdır / SDL2 and SDL2_mixer (zlib) are linked
into these port apps only, in their own packages.

## Çalışma ortamları ve kütüphaneler (App Market) / Runtimes & Libraries (App Market)

App Market'in "Çalışma Ortamları ve Kütüphaneler" kategorisindeki bileşenler `NexvynOS.nro`'ya bağlanmaz; kullanıcının
kurduğu, ayrı paketlerdir. Her biri kendi lisans metnini (`LICENSE` / `COPYING`) pakette ve SPDX lisansı ile kaynak kod
bağlantısını kartında taşır; bu dosyaya bileşen eklenmez, kendi paketinde durur. Şu an listelenen bileşen yok.

Components in the App Market's "Runtimes & Libraries" category are not linked into `NexvynOS.nro`; they are separate
packages the user installs. Each one carries its own licence text (`LICENSE` / `COPYING`) in its package and its SPDX
licence and source link on its card; they are not added to this file, they stay with their own package. No component is
listed at the moment.

