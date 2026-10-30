# Su Sıralama / Water Sort

Renkli sıvı katmanlarını tüpler arasında dökün: üstteki renk yalnızca boş bir tüpe ya da aynı renkle biten ve yeri olan bir tüpe dökülebilir. Her tüpte tek renk kalınca seviye biter. Seviyeler 3 renkten 12 renge kadar zorlaşır ve her biri bir çözücüyle çözülebilir olduğu denetlenerek üretilir; sınırsız geri alma, yeniden başlatma, seviye başına bir ek tüp, çözücüden ipucu ve istatistikler. Nexvyn OS'un JavaScript çalışma ortamıyla yazılmıştır (ES modülleri, üreteç fonksiyonları).
Pour coloured liquid layers between tubes: the top colour can only go into an empty tube or onto the same colour with room left. The level is done when every tube holds one colour. Levels grow from 3 to 12 colours and every one is generated and checked with a solver; unlimited undo, restart, one extra tube per level, hints from the solver and statistics. Written with the Nexvyn OS JavaScript runtime (ES modules, generator functions).

## Kontroller / Controls

- **Dokunmatik / Touch:** kaynak tüpe, sonra hedef tüpe dokunun / tap the source tube, then the target tube.
- **Kumanda / Controller:** D-pad tüp seçer, A al/dök, B iptal/geri al, Y ipucu, X yeniden başlat, - ek tüp, + duraklat /
  D-pad selects a tube, A picks up/pours, B cancel/undo, Y hint, X restart, - extra tube, + pause.
- **Klavye / Keyboard:** oklar + Enter/Boşluk, 1–9 ve 0 tüp seçer, Z geri al, H ipucu, R yeniden başlat, T ek tüp, Esc duraklat /
  arrows + Enter/Space, 1–9 and 0 pick a tube, Z undo, H hint, R restart, T extra tube, Esc pause.

Kurulum: Uygulama Mağazası > Oyunlar
