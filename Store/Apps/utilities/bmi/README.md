# Vücut Kitle İndeksi / BMI

Boy ve kiloyla vücut kitle indeksini hesaplayıp gidişatı izleyen Nexvyn OS uygulaması.
A Nexvyn OS app that calculates your body mass index and tracks it over time.

## Özellikler

- Metrik (cm, kg) ya da imparatorluk (ft, in, lb) birimleri; birim değişince girilen değerler çevrilir.
- VKİ değeri, DSÖ kategorisi (zayıf, normal, fazla kilolu, obez I–III) ve kayan işaretçili renkli gösterge.
- Boyuna göre sağlıklı kilo aralığı ve aralığa ne kadar uzak olduğun.
- Ölçüm geçmişi: VKİ ya da kilo için gidişat grafiği, sağlıklı bant, sıralama, geri alınabilir silme ve CSV dışa aktarma.
- Klavye: Enter ölçümü kaydeder, Ctrl+1/2 sekme değiştirir, Ctrl+U birim, Ctrl+E dışa aktar, Ctrl+Z silmeyi geri al.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Vücut Kitle İndeksi > Al.

İzinler: yok; ağ ya da dosya erişimi istemez (CSV yalnızca seçtiğin konuma kaydedilir).
Veriler `~/Library/Application Support/com.sonerx7.bmi/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~590 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/bmi/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
