# Ay Evresi / Moon Phase

Herhangi bir gün için ayın evresini ve aylık ay takvimini gösteren Nexvyn OS uygulaması.
A Nexvyn OS app that shows the moon's phase for any day and a monthly moon calendar.

## Özellikler

- Seçili gün için aydınlık kısmı doğru çizilen ay, evre adı (8 evre), aydınlanma yüzdesi ve ayın yaşı.
- Sonraki yeni ay ve dolunayın tarihi, saati ve kaç gün kaldığı; zamanlar Meeus düzeltme terimleriyle birkaç dakika hassasiyetinde.
- Her güne küçük bir ay çizen aylık takvim; yeni ay ve dolunay günleri işaretli, altında aylık aydınlanma grafiği.
- Ay ve gün geçişlerinde animasyon, Bugün düğmesi, kuzey/güney yarımküre görünümü.
- Seçili günü ya da ayın evre listesini panoya kopyalama.
- Klavye: sol/sağ gün, yukarı/aşağı hafta, PageUp/PageDown ay, T bugün, Ctrl+C kopyala.
- Türkçe ve İngilizce; açık ve karanlık mod. İnternet gerekmez: her şey tarih aritmetiğiyle hesaplanır.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Ay Evresi > Al.

İzinler: yalnızca `clipboard` (evreleri kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.moon/` içinde tutulur (yalnızca yarımküre tercihi).

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~480 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/moon/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
