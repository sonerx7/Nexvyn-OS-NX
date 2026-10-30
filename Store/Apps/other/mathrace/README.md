# Matematik Yarışı / Math Race

60 saniyede olabildiğince çok işlem çözüp arabanı bitiş çizgisine sürdüğün hızlı bir zihinden hesap oyunu.
A quick mental-arithmetic game: solve as many sums as you can in 60 seconds and drive your car to the finish line.

## Özellikler

- Üç zorluk: Kolay (20'ye kadar + −), Orta (50'ye kadar + − ×), Zor (100'e kadar + − × ÷, bölmeler hep tam sayı).
- Cevap yeterli rakam girilince kendiliğinden denetlenir; ekrandaki büyük tuş takımı, klavye rakamları, Backspace.
- Üst üste doğrular puan çarpanını ×5'e kadar yükseltir; doğru cevapta parçacıklar, yanlışta sarsıntı ve titreşim.
- 3-2-1 geri sayım, son 5 saniyede uyarı sesi, Esc ile duraklatma menüsü.
- Sonuç ekranı: doğru/yanlış, isabet, soru başına süre, son 12 turun grafiği, rekor kutlaması, sonucu panoya kopyalama.
- Zorluk başına rekor ve geçmiş saklanır. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Matematik Yarışı > Al.

İzinler: yalnızca `clipboard` (sonucu kopyalamak için). Ağ ya da dosya erişimi istemez.
Rekorlar `~/Library/Application Support/com.sonerx7.mathrace/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~376 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/other/mathrace/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
