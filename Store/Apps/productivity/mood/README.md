# Ruh Hali Günlüğü / Mood Journal

Her günün ruh halini, etiketlerini ve kısa bir notunu tutan bir Nexvyn OS günlük uygulaması (Lua SDK).
A Nexvyn OS journal app (Lua SDK) that records your mood, tags and a short note for every day.

## Özellikler

- Günde bir kayıt: beş yüz ifadesiyle ruh hali (Çok kötü – Harika), iş, aile, arkadaşlar, spor, uyku gibi 10 etiket ve bir not.
- Ruh haline göre renklenen aylık takvim; ay geçişleri kayan animasyonla, bugün ve seçili gün vurgulu.
- İstatistik sekmesi: ortalama ruh hali, kaydedilen gün sayısı, günlük seri, ayın grafiği (çizgi), animasyonlu dağılım çubukları ve en sık etiketlerin ortalama ruh hali.
- Silinen kayıt geri alınabilir; ay özeti panoya kopyalanır (Ctrl+C), tüm kayıtlar CSV olarak dışa aktarılır (Ctrl+S).
- Klavye: oklar gün seçer, 1–5 ruh halini belirler, PgUp/PgDn ay değiştirir, T bugüne döner, Tab sekme değiştirir, Delete kaydı siler.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Ruh Hali Günlüğü > Al.

İzinler: yalnızca `clipboard` (ay özetini kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.mood/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~680 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/mood/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
