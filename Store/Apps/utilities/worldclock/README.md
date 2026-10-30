# Dünya Saatleri / World Clock

80 şehrin saatini analog mini saatlerle gösteren, görüşme saati planlamaya yardım eden dünya saati.
Shows the time in 80 cities with analog mini clocks and helps you find a time to meet.

## Özellikler

- 80 şehir, sabit UTC farkları ve basit yaz saati kuralları (AB, ABD, Avustralya, Yeni Zelanda, Mısır).
- Gece/gündüz renkli analog saat kartları, dijital saat, gün farkı ve size göre saat farkı, YAZ SAATİ rozeti.
- Zaman yolculuğu kaydırıcısı: tüm saatleri ±12 saat ileri/geri alın.
- Planlayıcı: 24 saatlik çizelgede mesai, sabah/akşam ve gece saatleri; herkesin mesaide olduğu saatler yıldızla işaretlenir.
- Şehir arama (Türkçe adlarla), sıralama, yukarı/aşağı taşıma, kaldırmada geri alma; 12/24 saat biçimi.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Dünya Saatleri > Al.

İzinler: yok; ağ erişimi istemez. Saat dilimi verisi uygulamanın içindedir.
Veriler `~/Library/Application Support/com.sonerx7.worldclock/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~754 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/worldclock/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
