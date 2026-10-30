# Romen Rakamları / Roman Numerals

Sayılarla Romen rakamlarını iki yönlü çeviren, kurallarını öğreten ve test eden Nexvyn OS uygulaması.
A Nexvyn OS app that converts numbers and Roman numerals both ways, explains the rules and quizzes you.

## Özellikler

- Yazarken iki yönlü çeviri (1–3999); hatalı yazımda nedenini söyleyen sıkı denetim ve "... mi demek istedin?" önerisi.
- Adım adım döküm: 1994 = M + CM + XC + IV = 1000 + 900 + 90 + 4.
- Başvuru sekmesi: simgeler, çıkarma çiftleri ve dört temel kural; bir simgeye dokununca çeviricide açılır.
- Test: kolay (1–50), orta (1–500), zor (1–3999); seri, en iyi seri ve tüm zamanların skoru kaydedilir, yeni rekorda kutlama.
- Klavye: Ctrl+1/2/3 sekme, testte Enter kontrol eder ve sonraki soruya geçer, Ctrl+C sonucu kopyalar.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Romen Rakamları > Al.

İzinler: yalnızca `clipboard` (sonucu panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.roman/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~560 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/roman/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
