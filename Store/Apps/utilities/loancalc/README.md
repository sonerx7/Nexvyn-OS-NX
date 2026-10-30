# Kredi Hesapla / Loan Calculator

Kredinin taksitini, toplam maliyetini ve ödeme planını çıkaran Nexvyn OS uygulaması.
A Nexvyn OS app that works out a loan's monthly payment, total cost and payment plan.

## Özellikler

- Kredi tutarı, faiz oranı ve vade; faiz yıllık ya da aylık (bankaların verdiği gibi) girilebilir, vade ay ya da yıl.
- Eşit taksitli (anüite) aylık ödeme, toplam geri ödeme ve toplam faiz; %0 faiz de desteklenir.
- Anapara ve faiz payını gösteren halka grafik, aylık oranın yıllık nominal ve efektif karşılığı, son taksit tarihi.
- Ay ay ya da yıl yıl kaydırılabilir ödeme tablosu (taksit, anapara, faiz, kalan borç); CSV olarak dışa aktarma.
- Özeti panoya kopyalama; sıfırlama Ctrl+Z ile geri alınır.
- Klavye: PageUp/PageDown tablo görünümü, Ctrl+C kopyala, Ctrl+E dışa aktar, Ctrl+R sıfırla.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Kredi Hesapla > Al.

İzinler: yalnızca `clipboard` (özeti panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.loancalc/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~480 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/loancalc/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
