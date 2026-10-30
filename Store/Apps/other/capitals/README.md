# Başkentler / Capitals

150 ülkenin başkentini kıtalara göre öğreten bilgi yarışması uygulaması.
A quiz app that teaches the capitals of 150 countries, continent by continent.

## Özellikler

- 150 ülke ve başkent, Türkçe ve İngilizce adlarıyla (Budapeşte, Varşova, Üsküp, Ulan Batur…); sistem diline göre gösterilir.
- İki soru türü: ülke → başkent ve başkent → ülke; 10 ya da 20 soru; Dünya ya da tek kıta.
- Yanlış seçenekler aynı kıtadan gelir; yanlışta doğru cevap hemen gösterilir.
- "Hatalarım" modu: yanlış yaptığın ülkeler ayrı bir listede toplanır, doğru bildikçe listeden düşer.
- Kıtalara göre en iyi skor grafiği, animasyonlu sonuç halkası, rekor kutlaması ve sonucu panoya kopyalama.
- Göz At: ülke ya da başkente göre arama (Türkçe karakter duyarsız), kıta filtresi, sıralama.
- Klavye: 1–4 cevap seçer, Enter başlatır/tekrarlar, Esc geri döner. Açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Başkentler > Al.

İzinler: yalnızca `clipboard` (sonucu kopyalamak için). Ağ ya da dosya erişimi istemez.
Skorlar ve hata listesi `~/Library/Application Support/com.sonerx7.capitals/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~480 satır, ülke verisi `data.lua`, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/other/capitals/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
