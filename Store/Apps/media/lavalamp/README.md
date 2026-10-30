# Lav Lambası / Lava Lamp

Mum damlalarının ısınıp yükseldiği, birleştiği ve soğuyup indiği rahatlatıcı bir lav lambası animasyonu.
A relaxing lava lamp animation where wax blobs warm up, rise, melt together and sink again.

## Özellikler

- Basit ısı fiziği: damlalar altta ısınıp yükselir, üstte soğuyup iner; yaklaşan damlalar yumuşakça birleşir.
- Beş renk teması: Klasik, Okyanus, Limon, Mor ve renkleri yavaşça değişen Gökkuşağı; lambanın etrafında ışıma.
- Hız ve damla sayısı (3–12) ayarı, "Lambayı Salla" ile damlaları yeniden dağıtma.
- İsteğe bağlı yumuşak fokurtu sesleri (varsayılan kapalı).
- Gece lambası modu: birkaç saniye sonra kontroller gizlenir, köşede saat görünür; dokununca kontroller geri gelir.
- Klavye: Boşluk gece modu, sol/sağ ok tema, yukarı/aşağı ok hız. Ayarlar hatırlanır. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Lav Lambası > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Ayarlar `~/Library/Application Support/com.sonerx7.lavalamp/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~246 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/lavalamp/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
