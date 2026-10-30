# 3D Labirent / 3D Maze

On birinci şahıs 3D labirentte parlayan çıkışı zamana karşı bulduğun bir keşif oyunu.
A first-person game: find the glowing exit of ten 3D labyrinths against the clock.

## Özellikler

- 5×5'ten 25×25 odaya büyüyen 10 seviye; her seviyenin labirenti sabittir, böylece süreler karşılaştırılabilir.
- Gerçek zamanlı 3D (g3d): tek parça duvar modeli (yan yana yüzeyler birleştirilir), sis, ışık, parlayan çıkış halkası.
- Yumuşak hızlanma ve dönüş, yürürken hafif baş sallanması, adım sesleri, duvara çarpınca kırmızı parlama ve titreşim.
- Keşfettikçe açılan mini harita; Y/M ile büyük harita.
- Başlık ekranı ve seviye seçimi, duraklatma menüsü, seviye sonu ekranı, rekor kutlaması (konfeti) ve seviye başına en iyi süre.
- Kontroller: sol çubuk/yön tuşları/WASD yürür ve döner, sağ çubuk döner, Q/E yana adım, ZR ya da Shift koşar; dokunmatik ekranda ok düğmeleri. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > 3D Labirent > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
En iyi süreler `~/Library/Application Support/com.sonerx7.maze3d/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~518 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py games/racing/maze3d/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
