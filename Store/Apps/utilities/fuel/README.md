# Yakıt Hesaplayıcı / Fuel Calculator

100 km'de yakıt tüketimini ve yol masrafını hesaplayan, dolum kaydı tutan uygulama.
Calculates litres per 100 km and trip costs and keeps a fill-up log.

## Özellikler

- Tüketim: gidilen km ve litreden L/100 km, km/L, MPG (ABD/İngiltere), km başı maliyet; animasyonlu gösterge.
- Yol masrafı: mesafe, tüketim, litre fiyatı, gidiş-dönüş, yolcu sayısına bölme ve CO₂ tahmini (benzin/dizel/LPG).
- Dolum kaydı: ortalama, toplam km/litre/harcama, son 12 dolumun grafiği ve ortalama çizgisi.
- Kayıtları sıralama, silmede geri alma ve CSV olarak dışa aktarma.
- Girişler doğrulanır (virgüllü sayılar kabul edilir); değerler kapatınca kaybolmaz.
- ₺, $, €, £; Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Yakıt Hesaplayıcı > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.fuel/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~572 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/fuel/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
