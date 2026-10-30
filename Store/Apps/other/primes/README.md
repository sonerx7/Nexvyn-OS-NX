# Asal Sayılar / Primes

Asal sayıları adım adım kalbur, Ulam sarmalı ve çarpan ağacıyla keşfettiren bir uygulama.
An app for exploring prime numbers with an animated sieve, the Ulam spiral and a factor tree.

## Özellikler

- Eratosthenes kalburu: 100, 400 ya da 1000 sayılık ızgarada her adımda bir kat silinir; her asalın katları kendi rengiyle işaretlenir, son işaretler parlayıp söner. Oynat/duraklat, tek adım, sıfırla ve hız ayarı.
- Ulam sarmalı: 40.000 sayıya kadar; sürükleyerek kaydırma, tekerlek, iki parmak ya da düğmelerle yumuşak yakınlaştırma, ikiz asalları vurgulama, üzerine gelinen sayının asal mı yoksa çarpanlarının ne olduğu.
- Çarpanlara ayırma: 10^12'ye kadar her tam sayı; üslü asal çarpanlar, bölen sayısı ve toplamı, mükemmel/bol/eksik sayı türü, önceki ve sonraki asal (dokununca onları da ayrıştırır), tüm bölenler ve adım adım beliren çarpan ağacı.
- Büyük sayılar bile pencereyi dondurmaz: bölme denemeleri her karede küçük parçalar halinde yapılır; asallık Miller-Rabin ile anında sınanır.
- Asal listesini ve ayrıştırma sonucunu `.txt` dosyası olarak kaydetme.
- Klavye: Ctrl+1/2/3 sekmeler, Boşluk oynat/duraklat, sağ ok tek adım, R sıfırla, +/- ve 0 yakınlaştırma, T ikiz asallar, Esc hesaplamayı durdurur; menü çubuğu.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Diğer > Asal Sayılar > Al.

İzinler: yok; ağ erişimi istemez. Dışa aktarılan dosyaları siz seçtiğiniz yere kaydeder.
Veriler `~/Library/Application Support/com.sonerx7.primes/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~920 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/other/primes/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
