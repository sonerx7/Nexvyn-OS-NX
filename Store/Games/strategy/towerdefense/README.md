# Kule Savunması / Tower Defense

Yol boyunca kuleler kurup geliştirerek 15 düşman dalgasını üssüne ulaşmadan durdurduğun bir strateji oyunu.
A strategy game: build and upgrade towers along the road and stop 15 waves of enemies before they reach your base.

## Özellikler

- Üç kule türü: hızlı makineli, alan hasarlı top ve düşmanları yavaşlatan buz kulesi; her biri iki kez geliştirilebilir, satılınca harcamanın %70'i geri gelir.
- 15 dalga: normal, hızlı ve zırhlı düşmanlar, son dalgada patron; dalga arası bonus para, her dalgada daha dayanıklı düşmanlar.
- Dalgayı istediğin zaman başlat, 2x hız düğmesiyle hızlandır; menzil önizlemesi, can ve para göstergeleri, sallanan ekran ve parçacık efektleri.
- Kumanda: yön tuşlarıyla imleç, A kur, L/R kule türü, X geliştir, Y sat, ZR sonraki dalga, ZL hız, + duraklat; klavye: oklar, Enter, 1-3, U, X, N, F.
- Dokunmatik ve fare: hücreye dokun, aynı hücreye bir daha dokununca kule kurulur; sağ paneldeki düğmelerle geliştir, sat, dalga başlat.
- En iyi sonuç (temizlenen dalga, zafer sayısı) saklanır, rekorda konfeti; Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Kule Savunması > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.towerdefense/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~1050 satır, `nexvyn.game` motoru, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py games/strategy/towerdefense/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
