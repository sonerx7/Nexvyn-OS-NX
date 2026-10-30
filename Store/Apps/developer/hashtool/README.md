# Base64 ve Hash / Base64 & Hash

Metni Base64, onaltılık ve URL biçimlerinde kodlayıp çözen, metin ve dosyaların sağlama toplamlarını hesaplayan geliştirici aracı.
A developer tool that encodes and decodes text as Base64, hex and URL, and computes checksums of text and files.

## Özellikler

- Base64, URL güvenli Base64, onaltılık (hex) ve URL yüzde kodlaması; her biri için kodlama ve çözme. Geçersiz girdide neyin yanlış olduğunu söyleyen hata mesajı.
- Saf Lua ile CRC32, Adler-32, FNV-1a 32, MD5, SHA-1 ve SHA-256; bilinen test vektörleriyle doğrulandı.
- 1 MB'a kadar bir dosyanın özetini alma ve beklenen özeti yapıştırıp hangi algoritmayla eşleştiğini görme.
- UTF-8 uyumlu sayaçlar (karakter, bayt, satır); ikili çözme sonuçları onaltılık gösterilir ve dosyaya olduğu gibi kaydedilir.
- Pano: yapıştır, sonucu ya da tüm özetleri kopyala; sonucu tek dokunuşla girdiye taşı. Temizleme geri alınabilir.
- Klavye: Ctrl+V/C/S/O/L/Z/U, Tab sekme, sol/sağ ok biçim, yukarı/aşağı ok kodla/çöz, Enter yazmaya başla.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Geliştirici > Base64 ve Hash > Al.

İzinler: yalnızca `clipboard` (yapıştırma ve kopyalama). Ağ erişimi istemez; dosyalar yalnızca sizin seçtiğiniz yerden okunur ve kaydedilir.
Veriler `~/Library/Application Support/com.sonerx7.hashtool/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~530 satır, `codec.lua` ~220 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/developer/hashtool/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
