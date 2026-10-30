# Ritim / Rhythm

Düşen notalara tam zamanında basarak melodiyi kendin çaldığın dört şeritli bir ritim oyunu.
A four-lane rhythm game where you play the melody yourself by hitting the falling notes on time.

## Özellikler

- Üç hazır şarkı: Neşeye Övgü (Beethoven), Korobeyniki (Rus halk şarkısı) ve özgün beste Neon Gece; her birinde aynı melodiden türetilen Kolay ve Zor bölüm.
- Müzik notaların kendisi: bastığın her nota melodiyi çalar; bas hattı ve vuruşlar oyun saatine bağlıdır, duraklatınca şarkı da durur ve 3-2-1 sayımıyla kaldığı yerden sürer.
- Zamanlama değerlendirmesi (Mükemmel ±45 ms, Harika ±90 ms, İyi ±135 ms, Kaçtı), kombo çarpanı (x2'ye kadar), isabet yüzdesi ve S/A/B/C/D notu.
- Her şarkı ve zorluk için rekor puan ve not kaydı; yeni rekorda konfeti ve fanfar.
- Kontroller: yön tuşları ya da Y B X A (aynı dizilim), ZL L R ZR, klavyede D F J K ya da ok tuşları, dokunmatik ekranda şeride dokunma; + ya da Esc ile duraklatma.
- Ayarlanabilir nota hızı (0.75x-2x), ses açma/kapama, parçacık efektleri, ekran sarsıntısı ve yumuşak sahne geçişleri.
- Türkçe ve İngilizce.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Oyunlar > Ritim > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.rhythm/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~820 satır, `app.json`, `lang/`). `nexvyn.game` motorunu kullanır (SDK 1.2). Denetim:

    python tools/lua_check.py games/arcade/rhythm/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
