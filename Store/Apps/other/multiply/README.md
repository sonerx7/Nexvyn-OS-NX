# Çarpım Tablosu / Times Tables

Çocuklar için 1'den 10'a çarpım tablosunu öğreten ve süreli testlerle yıldız kazandıran Nexvyn OS uygulaması.
A Nexvyn OS app that teaches the times tables from 1 to 10 and awards stars in timed quizzes.

## Özellikler

- Öğrenme ekranı: bir tablo seç, satıra dokununca cevap açılır (Boşluk hepsini gösterir).
- 12 seviye: her tablo için bir seviye, ayrıca Karışık 1–5 ve Karışık 1–10; bir seviyeden yıldız alınca sonraki açılır.
- Her test 10 soru, soru başına 12 saniye; 10 doğru 3 yıldız, 8 doğru 2 yıldız, 6 doğru 1 yıldız.
- İki cevap biçimi: dört büyük seçenek (1–4 tuşları) ya da ekrandaki tuş takımı (rakam tuşları, Enter, Backspace).
- Doğru/yanlış sesleri, titreşim, üst üste doğru serisi; 3 yıldızda konfeti kutlaması.
- İstatistik ekranı: 1–10 her sayı için doğru cevap oranı grafiği ve en çok çalışman gereken sayı.
- Renkli, büyük düğmeler; dokunma, kontrolcü imleci ve klavye ile kullanılır. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Çarpım Tablosu > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Yıldızlar ve ayarlar `~/Library/Application Support/com.sonerx7.multiply/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~459 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/other/multiply/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
