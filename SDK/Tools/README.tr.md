# PC araçları

[English](README.md) · **Türkçe**

Nexvyn OS için bilgisayarda uygulama ve oyun yapanların araçları. Hepsi düz Python 3.8+.

| Araç | Ne yapar | Gerekenler |
|---|---|---|
| [`nxv`](nxv/README.tr.md) | Uygulama yapımcıları için komut satırı: `new` (`SDK/Languages/<dil>/template`'ten proje, Uygulama Mağazası düzeni için `--store`), `check` (manifest, dosyalar, ikon, çeviriler, kullanılıp bildirilmemiş izinler, `store.json` ve `shots` betiği; `--sdk` ile dil checker'ı da), `build` (Java `src/`'den `app.jar`), `pack` (Uygulama Mağazası derlemesiyle aynı `.nxvapp`, imzalamak için `--sign`), `install` (bir SD kart klasörüne kopyalama), `push --host <ip>` (konsolun **PC Bağlantısı** FTP sunucusuna yükleme) | yalnızca Python |
| [`icon/`](icon/README.tr.md) | Oyunun kendi modelinden key-art mağaza ikonları: `hero_render.py` modeli ana ve kenar ışıklarıyla saydam arka planda çizer, `finish_icon.py` arka planı, parlamayı, kenar ışığını, vinyeti ve 256 / 128 / 64 px önizlemeli her boyutu üretir. Stiller `clean` (varsayılan), `bold`, `loud`; başlık yalnızca istenirse | Pillow; `hero_render.py` ücretsiz, açık kaynak bir 3B paketinde komut satırından çalışır (README'sine bakın) |
| [`textures/`](textures/README.tr.md) | pbr renderer (SDK 1.9) için PBR doku setleri: `check` (setler, boyutlar, eksik haritalar), `resize` (haritaları küçültür, özgünleri saklar), `orm` (glTF ORM paketler), `smoothness` (MetallicSmoothness'tan roughness ve metallic), `flipgreen` (-Y'den +Y normal haritası: yeşil aşağıdan yeşil yukarıya) | Pillow |

Alışılmış döngü: `nxv new lua "My Game"` → kodu yazın → `nxv check` → `nxv push` → konsolda deneyin → ikonu `icon/`
ile yapın → pull request açmadan önce yeniden `nxv check` ([Katkı](../../CONTRIBUTING.tr.md)).
