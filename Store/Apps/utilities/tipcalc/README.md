# Bahşiş Hesapla / Tip Calculator

Hesabı, bahşişi ve kişi başı payı saniyeler içinde hesaplayan Nexvyn OS uygulaması.
A Nexvyn OS app that works out the tip, the total and each person's share in seconds.

## Özellikler

- Hesap tutarı, hızlı bahşiş seçenekleri (%5, %10, %15, %18, %20, %25), 0–50 arası kaydırıcı ya da 0–100 arası özel oran.
- Hesabı 1–50 kişiye bölme; kişi başı ödeme ve kişi başı bahşiş ayrı gösterilir.
- Yuvarlama: yok, toplamı yukarı yuvarla ya da her kişinin payını yukarı yuvarla; fark bahşişe eklenir ve gerçek bahşiş oranı gösterilir.
- Para birimi seçimi (₺, $, €, £); bütün ayarlar hatırlanır, sıfırlama Ctrl+Z ile geri alınabilir.
- Sonucu panoya kopyalama ya da metin dosyası olarak kaydetme.
- Klavye: Yukarı/Aşağı kişi sayısı, PageUp/PageDown bahşiş, Ctrl+C kopyala, Ctrl+S kaydet, Ctrl+R sıfırla.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Bahşiş Hesapla > Al.

İzinler: yalnızca `clipboard` (sonucu panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.tipcalc/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~420 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/tipcalc/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
