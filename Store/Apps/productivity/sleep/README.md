# Uyku Takibi / Sleep Tracker

Yatış ve kalkış saatini, uyku kalitesini kaydeden ve haftalık grafikle gösteren bir Nexvyn OS uygulaması (Lua SDK).
A Nexvyn OS app (Lua SDK) that logs bedtime, wake time and sleep quality and charts your week.

## Özellikler

- Tek dokunuşla "Yatıyorum" ve "Uyandım": sabah süre otomatik hesaplanır, kaliteyi seçip kaydedersin.
- Elle kayıt ekleme ve düzenleme: tarih, yatış ve kalkış saati (±15 dk / ±1 sa adımlarla, gece yarısını geçen uykular doğru hesaplanır), 1–5 yıldız kalite.
- Son 7 gecenin animasyonlu çubuk grafiği ve kesikli hedef çizgisi; hedef 4–12 saat arasında 30 dakikalık adımlarla ayarlanır.
- Özet kartları: son gece, 7 gece ortalaması, ortalama yatış saati ve sapması (düzenlilik), ortalama kalite, hedefe ulaşılan gece sayısı ve uyku borcu.
- Geceler listesi: süre çubuğu ve kalite yıldızlarıyla; silinen kayıt geri alınabilir, CSV dışa aktarma (Ctrl+S) ve hafta özetini panoya kopyalama (Ctrl+C).
- Klavye: B yatış, W kalkış, Ctrl+N yeni kayıt, Tab sekme değiştirir, oklar/Enter/Delete listede gezinir. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Uyku Takibi > Al.

İzinler: yalnızca `clipboard` (hafta özetini kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.sleep/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~670 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/sleep/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
