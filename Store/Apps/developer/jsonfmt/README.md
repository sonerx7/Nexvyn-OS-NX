# JSON Biçimlendirici / JSON Formatter

JSON'u doğrulayan, biçimlendiren, küçülten ve aranabilir bir ağaçta gösteren geliştirici aracı.
A developer tool that validates, formats and minifies JSON and shows it as a searchable tree.

## Özellikler

- Kendi katı JSON ayrıştırıcısı: hatayı satır ve sütunuyla, hatalı satırı işaretleyerek ve anlaşılır bir açıklamayla gösterir (sondaki virgül, tek tırnak, yorum, kapanmamış metin…).
- Biçimlendirme (2 ya da 4 boşluk, sekme) ve küçültme; anahtar sırası ve sayıların yazımı korunur, istenirse anahtarlar sıralanır.
- Açılıp kapanan düğümlerle ağaç görünümü, anahtar ve değerlerde arama, seçilen öğenin yolunu (`$.users[0].name`) ve değerini kopyalama.
- İstatistikler: anahtar sayısı, derinlik, değer türleri grafiği, girdi/biçimli/küçültülmüş boyutlar, yinelenen anahtar uyarısı.
- Yapıştır, `.json` dosyası aç (Dosyalar'da "Birlikte Aç" ile de), kaydet ve panoya kopyala; 2 MB'a kadar belgeler, temizleme geri alınabilir.
- Klavye: Ctrl+V/O/S/C/Z/L, Ctrl+1–4 sekmeler, Ctrl+F arama, Ctrl+E tümünü aç, Tab sekme değiştirir.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Geliştirici > JSON Biçimlendirici > Al.

İzinler: yalnızca `clipboard` (yapıştırma ve kopyalama). Ağ erişimi istemez; dosyalar yalnızca sizin seçtiğiniz yerden okunur ve kaydedilir.
Veriler `~/Library/Application Support/com.sonerx7.jsonfmt/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~770 satır, `jsonlib.lua` ~300 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/developer/jsonfmt/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
