# Balık Tut / Go Fishing

Oltayı atıp vuruşu beklediğin, sonra misinayı koparmadan balığı çektiğin rahatlatıcı bir balık tutma oyunu.
A relaxed fishing game: cast, wait for the bite, then reel the fish in without snapping the line.

## Özellikler

- Basılı tutup güç topla ve bırak ya da ekranda sapan gibi geri çekerek at; uzun atışlar nadir balık şansını artırır.
- Gerçek vuruşu küçük kıpırdamalardan ayır ve zamanında bas; çekerken gerginlik işaretini hareket eden yeşil alanda tut: fazla gerginlik misinayı koparır, gevşek kalırsa balık kaçar.
- 19 tür (yaygından efsaneviye beş nadirlik), her biri rastgele ağırlık ve boyla; üç yer (Göl, Nehir, Deniz) ve üç zaman dilimi (gündüz, akşamüstü, gece) farklı balıklar getirir.
- Koleksiyon defteri: yakalanan/yakalanmayan türler, kaç kez yakalandığı ve en ağır balık rekoru; yeni türde ve rekorda konfeti.
- Altın kazan; yeni yerlerin kilidini aç ve oltanı geliştir. Her av 8 atış sürer ve sonunda özet ekranı çıkar.
- Kontroller: A / Boşluk / Enter at, kanca at ve çek; B oltayı toplar; + ya da Esc duraklatır; her şey dokunmatik ekranla da oynanır.
- Kuş ve cırcır böceği sesleri, sıçrayan balıklı canlı başlık ekranı, parçacıklar, ekran sarsıntısı; Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Balık Tut > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.fishing/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~1070 satır, `app.json`, `lang/`). `nexvyn.game` motorunu kullanır (SDK 1.2). Denetim:

    python tools/lua_check.py games/casual/fishing/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
