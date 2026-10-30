# Mini Golf / Mini Golf

Duvarlı, kumlu ve sulu dokuz özenle tasarlanmış delikte yukarıdan bakışlı mini golf.
Top-down mini golf on nine hand-made holes with banks, sand, water and a windmill.

## Özellikler

- 9 delik (toplam par 28): açılı duvarlar, direkler, kum (topu yavaşlatır), su (1 ceza vuruşu, top son vuruş
  yerine döner) ve dönen yel değirmeni pervanesi.
- Dokunmatik ya da fareyle sapan gibi geri çekip bırakarak vuruş; kumanda ve klavyede çubuk / yön tuşları / oklarla
  nişan, A ya da Boşluk'u basılı tutarak güç göstergesi.
- Her delikten sonra ve tur sonunda skor kartı: par, vuruşların, her deliğin en iyisi ve toplam.
- En iyi tur ve her deliğin en iyi skoru kaydedilir; yeni rekorda konfeti ve kutlama müziği.
- Animasyonlu başlık ekranı, parçacık efektleri, ekran sarsıntısı, "Birdie!" gibi açılır yazılar, katmanlı sesler.
- Duraklatma menüsü (Devam Et / Baştan Başla / Ana menü / Çıkış) ve ses açma/kapama.
- Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Mini Golf > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.minigolf/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~820 satır, `fx.lua`, `app.json`, `lang/`). `nexvyn.game` motorunu kullanır.
Denetim:

    python tools/lua_check.py games/sports/minigolf/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
