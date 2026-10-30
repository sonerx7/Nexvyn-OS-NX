# Okuma Listesi / Reading List

Okunacak, okunan ve bitirilen kitapları sayfa ilerlemesiyle takip eden bir Nexvyn OS uygulaması (Lua SDK).
A Nexvyn OS app (Lua SDK) that tracks the books you want to read, are reading and have finished.

## Özellikler

- Kitap kartları: ad, yazar, toplam ve şu anki sayfa, durum (Okunacak / Okunuyor / Bitti), 1–5 yıldız puan ve notlar.
- Durum sekmeleri, ad/yazar araması ve sıralama (önce okunanlar, ada, yazara, ilerlemeye, puana göre).
- Sayfa −/+ düğmeleri ya da "Sayfaya Git" penceresi; son sayfaya gelince kitap otomatik olarak bitti sayılır ve konfeti patlar.
- Yıllık okuma hedefi halkası (animasyonlu), bu yıl okunan sayfa sayısı, şu an okunan kitaplar ve ortalama puan.
- Silinen kitap geri alınabilir (Ctrl+Z); liste panoya kopyalanır (Ctrl+C) ya da CSV olarak dışa aktarılır (Ctrl+S).
- Klavye: oklar seçer, sol/sağ sayfa değiştirir (Shift ile 10'ar), Enter düzenler, P sayfaya gider, Tab filtre değiştirir. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Okuma Listesi > Al.

İzinler: yalnızca `clipboard` (listeyi kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.reading/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~730 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/reading/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
