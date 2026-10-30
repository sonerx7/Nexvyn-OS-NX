# Metin Araçları / Text Tools

Türkçe İ/ı kurallarına uygun büyük/küçük harf dönüşümü, temizleme, sıralama ve sayım yapan metin aracı.
Case conversion with Turkish İ/ı rules, clean-up, line sorting, duplicate removal and word/character counts.

## Özellikler

- Çok satırlı düzenleyici (satır numaraları, imleç, geri al/yinele) ve konsol klavyesiyle satır ekleme alanı.
- BÜYÜK, küçük, Baş Harfler Büyük, Cümle düzeni, ters çevirme; Türkçe kurallar açıkken i↔İ ve ı↔I doğru dönüşür.
- Boşluk kırpma, boş satır silme, tekrarları kaldırma (büyük/küçük harf duyarsız), satırları birleştirme.
- A→Z / Z→A (Türk alfabesi sırası: ç, ğ, ı, ö, ş, ü doğru yerde), uzunluğa göre sıralama, ters çevirme, karıştırma, numaralama.
- Canlı istatistik: kelime, karakter, satır, cümle, paragraf, okuma süresi, en sık geçen 5 kelime grafiği.
- Dosya aç/kaydet (.txt, .md, .csv…), panoya kopyala/yapıştır; Dosyalar'da “Birlikte Aç” ile açılabilir.
- Kısayollar: Ctrl+Z/Y, Ctrl+O, Ctrl+S, Ctrl+C/V, Ctrl+U büyük harf, Ctrl+L küçük harf.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Metin Araçları > Al.

İzinler: `clipboard` (Kopyala/Yapıştır için). Ağ erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.texttools/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~914 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/texttools/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
