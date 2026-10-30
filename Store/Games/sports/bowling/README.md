# Bowling / Bowling

Yukarıdan bakışlı, gerçek puanlamalı on lobutlu bowling.
Top-down ten-pin bowling with real scoring.

## Özellikler

- 10 çerçeve, gerçek puanlama: strike, spare ve 10. çerçevenin bonus atışları; X, / ve - işaretli skor tablosu.
- Atış ayarları: konum, nişan açısı, falso (top pistin sonunda kıvrılır) ve basılı tutularak dolan güç göstergesi;
  yol önizlemesi gösterilir.
- Top-lobut ve lobut-lobut çarpışmaları, yan duvarlardan seken lobutlar, olukta kaybolan toplar ve "lobut kamerası".
- Kumanda, klavye (oklar, Q / E, Boşluk) ve dokunmatik (topu sürükle, pistte geri çek ve bırak, falso düğmeleri).
- Animasyonlu başlık ekranında kendi kendine oynayan pist; STRIKE / SPARE yazıları, konfeti, ekran sarsıntısı ve
  katmanlı sesler.
- Oyun sonunda istatistikler (strike, spare, oluk, ilk atış ortalaması); en iyi oyun kaydedilir, yeni rekorda kutlama.
- Duraklatma menüsü, ses açma/kapama; Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Bowling > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.bowling/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~830 satır, `fx.lua`, `app.json`, `lang/`). `nexvyn.game` motorunu kullanır.
Denetim:

    python tools/lua_check.py games/sports/bowling/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
