# Ton Üretici / Tone Generator

20 Hz ile 20 kHz arasında test tonları ve frekans taramaları çalan, canlı dalga görünümlü ses aracı.
A sound tool that plays test tones and frequency sweeps from 20 Hz to 20 kHz with a live waveform view.

## Özellikler

- Sinüs, kare, testere ve üçgen dalga; 20 Hz – 20 kHz logaritmik kaydırıcı, sayıyla frekans girişi (doğrulamalı).
- İnce ayar düğmeleri (±0,1 / ±1 / ±10 Hz), oktav yukarı/aşağı ve en yakın notaya yuvarlama; nota adı ve cent sapması (A4 = 440 Hz).
- Tarama modu: başlangıç ve bitiş frekansı, 2–60 saniye süre, logaritmik adımlar, tekrar ve ters çevirme.
- Osiloskop benzeri canlı dalga biçimi önizlemesi; hazır tonlar (A4 440 Hz, C4, 1 kHz, 50/100 Hz, 10/15 kHz).
- Yüksek ses, çok tiz ve çok pes frekanslar için uyarılar; ses düzeyi kaydırıcısı.
- Klavye: Boşluk çal/durdur, sol/sağ ok ±1 Hz (Shift ile ±10), yukarı/aşağı oktav, N nota, W dalga biçimi. Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Ton Üretici > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Ayarlar `~/Library/Application Support/com.sonerx7.tonegen/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~414 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/tonegen/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
