# Görev: bir uygulamaya arayüz dili eklemek

[English](add-language.en.md) · **Türkçe**

Nexvyn OS uygulamaları metinlerini `TR("key", ...)` ile `lang/<kod>.json` dosyasından okur; sistemin dilleri arasında
İngilizce (`en`), Türkçe (`tr`), Almanca (`de`), Fransızca (`fr`) ve İspanyolca (`es`) vardır. `TR` önce İngilizceye,
sonra sistem metinlerine, sonra anahtarın kendisine düşer. Prompt'u, altına `lang/en.json` (ve bağlam için
`lang/tr.json`) yapıştırarak gönderin. Bu görev için SDK context pack gerekmez.

```text
Bu Nexvyn OS uygulamasının lang/en.json dosyasını <dil adı> diline (kod "<xx>") çevir ve lang/<xx>.json olarak döndür.

Kurallar:
- Aynı anahtarlar, aynı sıra, geçerli JSON (UTF-8, yorum yok, sondaki virgül yok).
- Yer tutucuları tam olarak koru: {0}, {1}, ... cümle içinde yer değiştirebilir ama hepsi kalmalı. "\n" satır
  sonlarını koru.
- Uzunluğu İngilizce metne yakın tut: bu metinler 1280x720 bir ekranda düğmelerde ve dar panellerde durur.
  Bir çeviri çok daha uzun olmak zorundaysa daha kısa bir ifade bul.
- Uygulama adlarını, marka adlarını, birimleri ve tuş adlarını (Ctrl+R, A, B, ZL), dilin standart bir biçimi yoksa
  olduğu gibi bırak.
- Modern bir konsol/masaüstü arayüzünün tonunu kullan: kısa emir kipinde etiketler ("Kaydet", "Sil"), yalnızca ilk
  harf büyük.
- "game." ile başlayan anahtarlar nexvyn.game motorunun metinlerini geçersiz kılar; onları da çevir.

Ayrıca app.json için "name" ve "description" metinlerini o dilde ver; store.json'u yapıştırırsam onun "subtitle" ve
"description" alanlarını da o dilde ver.
```

Sonra: dosyayı `lang/` içine koyun, dili `app.json` `name` / `description` alanlarına ve `store.json`'a ekleyin ve
uygulamanın dilinin checkersini çalıştırın (okuduğu her lang dosyasını doğrular).
