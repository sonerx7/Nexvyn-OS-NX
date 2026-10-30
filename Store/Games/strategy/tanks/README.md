# Tank Düellosu / Tank Duel

Yıkılabilir arazide, rüzgârı hesaba katarak rakip tankı vurmaya çalıştığın sıra tabanlı bir topçu oyunu.
A turn-based artillery game: read the wind, set angle and power and blast the other tank off the destructible hills.

## Özellikler

- Her raunt yeni rastgele arazi; patlamalar krater açar, üstteki toprak çöker, tanklar yeni zemine düşer (yüksekten düşmek hasar verir).
- Her turda değişen rüzgâr (ok ve güçle gösterilir), mermi izi ve bir önceki atışının soluk izi; mesafeye göre hasar, tam isabete ek hasar.
- İki mod: tek konsolda iki oyuncu ya da Kolay / Normal / Zor bilgisayar (atışı hesaplar, zorluğa göre sapar).
- 3 raundu alan maçı kazanır; maç sonunda atış, isabet oranı, tam isabet ve hasar istatistikleri, rekorlarda konfeti.
- Kumanda: sol/sağ açı, yukarı/aşağı güç, A veya ZR ateş, + duraklat; klavye: oklar, Boşluk/Enter; dokunmatik: alanda sürükleyerek nişan al, ATEŞ düğmesine dokun.
- Galibiyet/yenilgi kayıtları ve bilgisayara karşı en uzun seri saklanır; Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Tank Düellosu > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.tanks/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~940 satır, `nexvyn.game` motoru, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py games/strategy/tanks/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
