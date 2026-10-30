# Sayaç / Tally Counter

Birden çok adlandırılmış sayaçla her şeyi saymanı sağlayan Nexvyn OS uygulaması.
A Nexvyn OS app for counting anything with several named counters.

## Özellikler

- 60'a kadar sayaç: ad, renk, adım boyu (+1…+100) ve isteğe bağlı hedef.
- Karta dokunmak sayacı artırır; büyük +/- düğmeleri, hedefler için ilerleme halkası ve hedefe ulaşınca kutlama.
- Her sayacın son 60 değişikliği: geri alma, değer grafiği ve son değişikliğin saati; sıfırlama ve silme onaylı ve geri alınabilir.
- Arama, elle/ada/değere göre sıralama, yukarı/aşağı taşıma ve tüm sayaçların toplamı.
- Dışa aktarma: tüm sayaçları panoya kopyalama ya da CSV dosyası olarak kaydetme.
- Klavye: Boşluk/yukarı artırır, aşağı azaltır, sol/sağ sayaç seçer, Backspace geri alır, R sıfırlar, Ctrl+N yeni sayaç.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Sayaç > Al.

İzinler: yalnızca `clipboard` (sayaçları kopyalamak için). Ağ ya da dosya erişimi istemez; CSV yalnızca senin seçtiğin
dosyaya yazılır.
Veriler `~/Library/Application Support/com.sonerx7.tally/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~565 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/tally/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
