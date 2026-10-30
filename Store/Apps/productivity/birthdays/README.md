# Doğum Günleri / Birthdays

Yaklaşan doğum günlerini kalan gün ve gireceği yaşla gösteren, bir gün önceden hatırlatan bir Nexvyn OS uygulaması (Lua SDK).
A Nexvyn OS app (Lua SDK) that lists upcoming birthdays with days left and the age they turn, and reminds you a day early.

## Özellikler

- Kişiler ad, gün ve ay ile (yıl ve not isteğe bağlı) eklenir; dokununca düzenlenir, sağ tık / X ile bağlam menüsü açılır.
- Yaklaşanlar listesi kalan güne göre sıralanır ve Bugün / Bu hafta / Bir ay içinde / Daha sonra diye gruplanır; gireceği yaş ve haftanın günü yazar.
- Bugün doğum günü olanlar için hareketli bir "Bugün!" bandı; uygulama açılınca bugün ve yarın olan doğum günleri için günde bir kez bildirim.
- 29 Şubat doğumluların doğum günü artık yıl olmayan yıllarda 28 Şubat'ta gösterilir; tarihler gün/ay/yıl doğrulamasından geçer.
- Aylara göre görünüm: 12 ay kartı, içinde bulunulan ay vurgulu.
- Ad araması, silmeyi geri alma (Ctrl+Z), yaklaşanları panoya kopyalama (Ctrl+C) ve takvim uygulamaları için `.ics` dışa aktarma (Ctrl+S).
- Klavye: Ctrl+N yeni kişi, oklar seçer, Enter düzenler, Delete siler, Tab görünüm değiştirir. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Doğum Günleri > Al.

İzinler: `notifications` (doğum günü hatırlatmaları) ve `clipboard` (listeyi kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.birthdays/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~670 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/birthdays/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
