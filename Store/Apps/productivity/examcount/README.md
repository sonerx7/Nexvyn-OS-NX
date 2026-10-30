# Sınav Geri Sayımı / Exam Countdown

Sınavlara kalan süreyi sayan, çalışma süresini ve günlük çalışma serisini takip eden uygulama.
Counts down to your exams and tracks study time and your daily study streak.

## Özellikler

- Birden çok sınav; sıradaki sınav için gün/saat/dakika/saniye sayacı ve ilerleme halkası, yaklaşanlar kırmızı/turuncu.
- Çalışma sayacı (uygulama kapansa da sürer) ve +15/+30/+45/+60 dk hızlı kayıt, sınava göre.
- Günlük hedef, hedefe ulaşınca konfeti; güncel ve en uzun çalışma serisi.
- Son 12 haftanın ısı haritası ve sınav başına çalışma süresi grafiği.
- Sınav silme ve son oturum için geri alma; geçmiş sınavları temizleme.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Sınav Geri Sayımı > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.examcount/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~734 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/examcount/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
