# Langırt / Pinball

Paletli, tamponlu ve çarpanlı dikey bir neon langırt masası.
A portrait neon pinball table with flippers, bumpers and a score multiplier.

## Özellikler

- İki palet, fırlatıcı (basılı tut ve bırak), üç tampon, iki sapan, üç düşen hedef, üç üst şerit ve tek yönlü kapı.
- Hedefleri ya da şeritleri tamamlamak çarpanı 5x'e kadar yükseltir; top kaybında bonus × çarpan eklenir.
- Her fırlatmadan sonra 6 saniyelik top koruması, 3 top; en yüksek puan kaydedilir.
- Alt adımlı top-çizgi fiziği: top duvarlardan ve paletlerden geçmez; paletler hareket hızını topa aktarır.
- Kumanda (L/ZL, R/ZR, A), klavye (oklar, Z / M, Boşluk) ve dokunmatik (ekranın sol/sağ yarısı).
- Kendi kendine oynayan başlık ekranı, kıvılcımlar, ekran sarsıntısı, açılır puan yazıları, arka plan müziği ve
  katmanlı sesler; rekorda konfeti.
- Duraklatma menüsü, ses açma/kapama; Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Langırt > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.pinball/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~800 satır, `fx.lua`, `app.json`, `lang/`). `nexvyn.game` motorunu kullanır.
Denetim:

    python tools/lua_check.py games/arcade/pinball/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
