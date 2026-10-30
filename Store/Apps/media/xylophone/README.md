# Ksilofon / Xylophone

Dokunarak ya da klavyeyle çalınan, melodi kaydeden ve şarkı öğreten renkli bir ksilofon.
A colourful xylophone you play by touch or keyboard, with melody recording and a song-learning mode.

## Özellikler

- 8 (Do5–Do6) ya da 15 (Do5–Do7) renkli tuş; tahta tını için sentezlenmiş üçgen dalga ve parlak üst ton.
- Dokunma, kontrolcü imleci ya da klavye: 1–8 ilk sekiz tuş, Q–U üst tuşlar; vuruşta sekme ve dalga halkası animasyonu.
- Kayıt: Kaydet (Boşluk) ile çaldığını zamanlamasıyla kaydet; kayıtları dinle, yeniden adlandır, sil (Ctrl+Z ile geri al).
- Hazır şarkılar: Parla Parla Küçük Yıldız, Neşeye Övgü, Ali Baba'nın Çiftliği, İyi ki Doğdun, Tembel Çocuk.
- Öğrenme modu: sıradaki tuş yanıp söner, doğru tuşa vurdukça ilerlersin; sonunda isabet yüzdesi.
- Çalma hızı ×0,5–×2. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Ksilofon > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Kayıtlar `~/Library/Application Support/com.sonerx7.xylophone/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~386 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/xylophone/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
