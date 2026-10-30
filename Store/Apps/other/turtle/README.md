# Kaplumbağa Grafikleri / Turtle Graphics

Kaplumbağaya Türkçe ya da İngilizce komutlar vererek çizim yaptıran, kodlamaya giriş uygulaması (Python SDK).
An introduction to coding: give the turtle Turkish or English commands and watch it draw (Python SDK).

## Özellikler

- Logo benzeri dil: ileri, geri, sağ, sol, kalemkaldır, kalemindir, renk, kalınlık, tekrarla N [ … ], merkez, temizle; İngilizce karşılıkları da çalışır (forward, right, repeat…).
- Yordamlar (`yap AD … son`), iç içe tekrarlar, `sayaç` döngü sayacı ve boşluksuz ifadeler (`ileri sayaç*3`), rastgele renk.
- Satır numaralı açık hata mesajları (ör. "Satır 3: bilinmeyen komut"); hatalı satır kırmızı görünür.
- Switch'e uygun düzenleyici: satıra dokun, alttaki alanda düzenle, Enter yeni satır ekler; satır ekle, sil, yukarı/aşağı taşı.
- Animasyonlu kaplumbağa, 10 kademeli hız, çizim otomatik olarak pencereye sığdırılır.
- Hazır örnekler: Kare, Yıldız, Sarmal, Çiçek, Kar Tanesi, Gökkuşağı Kareler, İngilizce Taç Yapraklar.
- Birden çok program kaydı, yeniden adlandırma, silmeyi geri alma (Ctrl+Z), programı panoya kopyalama. F5 çalıştırır.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Kaplumbağa Grafikleri > Al.

İzinler: yalnızca `clipboard` (programı kopyalamak için). Ağ ya da dosya erişimi istemez.
Programlar `~/Library/Application Support/com.sonerx7.turtle/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.py` ~422 satır, dil yorumlayıcısı `logo.py` ~293 satır, `app.json`, `lang/`). Python için SDK 1.3 gerekir. Denetim:

    python tools/py_check.py apps/other/turtle/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
