# Hava Hokeyi / Air Hockey

Konsola karşı ya da bir arkadaşınla oynanan hızlı bir hava hokeyi oyunu (Python SDK).
A fast air hockey game against the console or a friend (Python SDK).

## Özellikler

- Konsola karşı üç zorluk (Kolay, Normal, Zor): savunma, pakın arkasına dolanma ve hedefli vuruş yapan yapay zekâ.
- 2 oyuncu: konsolu masaya koyun, kırmızı sol çubuk/WASD, mavi sağ çubuk/ok tuşlarıyla oynar; dokunmatik ekranda parmak kendi yarısındaki tokmağı sürer (SDK tek dokunuş bildirdiği için aynı anda tek parmak).
- Gerçekçi pak fiziği: sürtünme, duvar sekmesi, tokmak hızının paka aktarılması, hız sınırı, takılan pakın yeniden oyuna girmesi.
- Efektler: pak izi, vuruş parçacıkları, gol patlaması, ekran sarsıntısı, titreşim ve sentez sesler.
- 7 golü atan kazanır; başlık ekranı, duraklatma menüsü (+ / Esc), sonuç ekranında vuruş sayısı ve en yüksek pak hızı, galibiyet kutlaması.
- Zorluk başına galibiyet istatistiği ve en farklı galibiyet rekoru. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Hava Hokeyi > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
İstatistikler `~/Library/Application Support/com.sonerx7.airhockey/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.py` ~592 satır, `app.json`, `lang/`). Python için SDK 1.3 gerekir. Denetim:

    python tools/py_check.py games/arcade/airhockey/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
