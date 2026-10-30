# Hesap Bölüş / Split Bill

Restoran hesabını kim neyi paylaştı, kim ödedi bilgisine göre adilce bölen uygulama.
Splits a bill fairly by who shared which item and who paid, then shows who owes whom.

## Özellikler

- Kişiler (en fazla 12) ve kalemler: adet, birim fiyat, ödeyen kişi ve paylaşanlar.
- Bahşiş (%0–25, hızlı düğmeler) ve servis/vergi yüzdesi; tutarlar kuruş hassasiyetinde, toplamlar her zaman tutar.
- Kişi başı pay, ödenen ve bakiye tablosu; animasyonlu pasta grafik.
- Ödeşme için en az transferi bulan “Kim kime ödeyecek” listesi.
- Özeti panoya kopyalama ya da metin dosyası olarak kaydetme; silmede geri alma.
- ₺, $, €, £ para birimleri; Türkçe ve İngilizce sayı biçimi, açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Hesap Bölüş > Al.

İzinler: `clipboard` (özeti kopyalamak için). Ağ erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.splitbill/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~762 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/splitbill/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
