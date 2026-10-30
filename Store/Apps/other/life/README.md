# Hayat Oyunu / Game of Life

Conway'in Hayat Oyunu'nu hücre çizerek, klasik desenler yerleştirerek ve farklı kurallarla keşfettiren hücresel otomat uygulaması.
Explore Conway's Game of Life: draw cells, place classic patterns and try other cellular automaton rules.

## Özellikler

- Kenarları birbirine bağlı (toroidal) ızgara: 48×30, 64×40, 96×60 ya da 128×80; hücreler yaşına göre renklenir.
- Dokunarak ya da imleçle sürükleyerek hücre çizme/silme; oynat, adım adım ilerle, rastgele doldur, temizle, geri al.
- Desen kitaplığı: planör, uzay gemisi, pulsar, pentadekatlon, Gosper planör tabancası, R-pentomino, meşe palamudu, dirençli.
- Kurallar: Conway (B3/S23), HighLife (B36/S23), Seeds (B2/S), Day & Night (B3678/S34678).
- Saniyede 1–60 nesil hız ayarı; nesil, nüfus, en yüksek nüfus ve son 160 neslin nüfus grafiği.
- Tahta otomatik kaydedilir; ayrıca menüden 3 kayıt yuvası. Klavye: Boşluk, N, R, C, Ctrl+Z, yukarı/aşağı ok hız.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Hayat Oyunu > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Tahta ve kayıt yuvaları `~/Library/Application Support/com.sonerx7.life/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~394 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/other/life/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
