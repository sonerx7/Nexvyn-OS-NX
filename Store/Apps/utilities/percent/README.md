# Yüzde Hesaplayıcı / Percentage Calculator

Günlük yüzde hesaplarını formülüyle birlikte gösteren Nexvyn OS uygulaması.
A Nexvyn OS app for everyday percentage sums, with the formula behind each result.

## Özellikler

- Y'nin %X'i: sonuç ve tutarın bu yüzde kadar artmış ya da azalmış hali.
- X, Y'nin yüzde kaçı: oran ve bütünün içindeki payı gösteren çubuk.
- Yüzde değişim: A'dan B'ye artış ya da azalış, fark ve oran.
- Yüzde ekle / çıkar: KDV, kâr payı ya da indirim; %1, %10, %18, %20 kısayolları.
- Yüzdeden önceki fiyat: KDV dahil ya da indirimli fiyattan asıl fiyatı bulma.
- Her hesapta canlı sonuç, formül satırı ve panoya kopyalama; girilen değerler hatırlanır, temizleme Ctrl+Z ile geri alınır.
- Klavye: Yukarı/Aşağı ya da Ctrl+1…5 hesap seçer, Ctrl+C kopyalar. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Yüzde Hesaplayıcı > Al.

İzinler: yalnızca `clipboard` (sonucu panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.percent/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~450 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/percent/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
