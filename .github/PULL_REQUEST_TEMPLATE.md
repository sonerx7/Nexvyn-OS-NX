<!-- Nexvyn OS App Market submission. Fill it in in English or Turkish. / İngilizce ya da Türkçe doldurun.
     Guide / Rehber: SDK/Publishing/PUBLISHING.en.md · PUBLISHING.tr.md
     The maintainer reviews every submission with SDK/Publishing/REVIEW.en.md before it is published. -->

## Item / Öğe

- **Name / Ad:**
- **Id / Kimlik:** `com.`
- **Type / Tür:** app · game · theme · font
- **Folder / Klasör:** `Store/Apps/<category>/<slug>/` · `Store/Games/<genre>/<slug>/` · `Store/Themes/<slug>/` · `Store/Fonts/<slug>/`
- **Language / Dil:** Lua · JavaScript · Python · Squirrel · C · Java · (theme / font: —)
- **Version / Sürüm:**
- **New or update? / Yeni mi, güncelleme mi?** new / yeni · update / güncelleme (what changed / ne değişti: )

## What it does / Ne yapar

<!-- Two or three sentences. / İki üç cümle. -->

## Permissions / İzinler

<!-- Why each permission is needed. "None" is an answer too. / Her iznin neden gerektiği. "Yok" da bir cevaptır. -->

| Permission / İzin | Why / Neden |
|---|---|
| | |

## Rights and licenses / Haklar ve lisanslar

- [ ] I made this item or I have the right to publish it. / Bu öğeyi ben yaptım ya da yayımlama hakkım var.
- [ ] Every third-party part (code, images, sounds, fonts) is listed with its author and license in the README. /
      Her üçüncü taraf parça yapanı ve lisansıyla README'de listelendi.
- **License of my code / Kodumun lisansı:**
- **Content note / İçerik notu:** everyone / herkes · teen (mild violence, scary themes / hafif şiddet, korkutucu temalar)

## Checks / Denetimler

- [ ] `python SDK/Tools/nxv/nxv.py check <folder> --sdk <source checkout>` passes / hatasız
- [ ] Language checker / dil denetleyicisi (`lua_check` · `js_check` · `py_check` · `rt_check`) passes / hatasız
- [ ] `python Tools/build_store.py --check` (or the maintainer runs `build_store.py` / ya da bakımcı çalıştırır)
- [ ] Tried on the console or in Ryujinx / konsolda ya da Ryujinx'te denendi (which / hangisi: )
- [ ] Light and dark mode, handheld and TV / açık ve koyu mod, el modu ve TV
- [ ] Touch + cursor (+ controller for games) / dokunmatik + imleç (+ oyunlarda kumanda)
- [ ] `store.json`: `subtitle` + `description` (English at least / en az İngilizce), `kind`, `tags`, `shots`
- [ ] `README.md` English + Turkish, `icon.png` 128 or / ya da 256 px
- [ ] No tracking, ads that harm users, personal data, API keys or passwords /
      izleme, zararlı reklam, kişisel veri, API anahtarı ya da parola yok

## Screenshots / Ekran görüntüleri

<!-- Mention screenshots/ if you added them; otherwise the maintainer makes them from your `shots` script. /
     screenshots/ eklediyseniz belirtin; yoksa bakımcı `shots` betiğinizden üretir. -->
