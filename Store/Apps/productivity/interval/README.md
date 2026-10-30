# Aralıklı Zamanlayıcı / Interval Timer

HIIT ve Tabata antrenmanları için renkli, sesli ve titreşimli aralık zamanlayıcısı.
A color-coded interval timer with beeps and vibration for HIIT and Tabata workouts.

## Özellikler

- Hazır antrenmanlar (Tabata 20/10×8, HIIT 30/30, HIIT 40/20 × 3 set, Sprint 15/45, Başlangıç 20/40) ve tamamen özel ayar: ısınma, çalışma, dinlenme, tur, set, setler arası dinlenme, soğuma.
- Aşama rengini alan büyük dairesel geri sayım; tur ve set bilgisi, sıradaki aşama, kalan toplam süre ve tüm antrenmanın renkli zaman çizelgesi.
- Son 3 saniyede bip, aşama değişiminde farklı ton ve titreşim (ikisi de kapatılabilir); duraklat, sürdür, atla, onaylı durdur.
- Kendi antrenmanlarını adıyla kaydetme ve onaylı silme; değerlere dokunup süreyi `1:30` gibi elle yazma.
- Son 7 günde yapılan antrenmanların grafiği, bitişte kutlama ekranı.
- Klavye: Boşluk/Enter başlat ve duraklat, sağ ok atla, Esc durdur, yukarı/aşağı ok antrenman seç.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Aralıklı Zamanlayıcı > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.interval/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~630 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/interval/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
