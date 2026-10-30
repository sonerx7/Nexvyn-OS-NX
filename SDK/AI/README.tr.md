# Yapay zekâ ile Nexvyn OS uygulaması

[English](README.md) · **Türkçe**

Bu klasör, Claude, ChatGPT, Gemini ya da yerel modellerle (LM Studio, Ollama...) Nexvyn OS uygulaması yazmak için
hazır context pack'ler ve prompt'lar içerir. Asistan SDK'yı bilmez; bu dosyaları vermezseniz var olmayan function'lar
uydurur. Context pack'ler `SDK/Reference/SDK.tr.md` ile aynı bilgiyi taşır, yalnızca daha kısadır.

## Dosyalar

Her dosyanın iki sürümü vardır: İngilizce `X.en.md` ve Türkçe `X.tr.md`. İkisi aynı bilgiyi ve aynı kuralları taşır.

| Dosya (Türkçe · İngilizce) | Ne için |
|---|---|
| [system-prompt.tr.md](system-prompt.tr.md) · [system-prompt.en.md](system-prompt.en.md) | Ana context pack (~5 bin token): bundle düzeni, `app.json`, zorunlu izinler, program yapısı, kurallar (3 sn, 64 MB, 60 fps, `TR()`), tüm API'nin özeti, dil farkları, store biçimi |
| [languages/](languages/) | Language pack'ler: [lua](languages/lua.tr.md), [javascript](languages/javascript.tr.md), [python](languages/python.tr.md), [squirrel](languages/squirrel.tr.md), [c](languages/c.tr.md), [java](languages/java.tr.md) (İngilizceleri `.en.md`): iskelet kod, dile özgü kurallar, checker |
| [tasks/](tasks/) | Task prompt'ları: [oyun yap](tasks/make-game.tr.md), [araç uygulaması yap](tasks/make-utility.tr.md), [Lua oyununu JS'ye taşı](tasks/port-lua-to-js.tr.md), [arayüz dili ekle](tasks/add-language.tr.md), [store.json ve ekran görüntüsü betiği yaz](tasks/store-listing.tr.md), [checker hatasını düzelt](tasks/fix-lua-check.tr.md) (İngilizceleri `.en.md`) |
| [checklist.tr.md](checklist.tr.md) · [checklist.en.md](checklist.en.md) | Asistanın yanıt vermeden önce geçmesi gereken liste |

## Hangi dili kullanmalı?

- **Asistanla Türkçe konuşacaksanız** `.tr.md` dosyalarını verin: talimatlar, örnekler ve task prompt'ları Türkçedir,
  asistan da Türkçe yanıt verir.
- **İngilizce konuşacaksanız** ya da küçük bir yerel model kullanıyorsanız İngilizce dosyaları verin (küçük modeller
  İngilizce talimatlara genellikle daha sıkı uyar). İki system prompt da modele "kullanıcının yazdığı dilde yanıt
  ver" der; İngilizce bağlamla Türkçe soru sorarsanız yanıt yine Türkçe gelir.
- Dilleri karıştırmayın: system prompt, language pack, task prompt ve checklist aynı dilden olsun.
- API adları, `app.json` anahtarları, dosya adları ve checker komutları iki sürümde de aynıdır. Uygulamanın
  kendisi her durumda `lang/en.json` ve `lang/tr.json` ile iki dilli olur.

## Nasıl kullanılır

1. **Bağlamı verin.** `system-prompt.tr.md` (ya da `system-prompt.en.md`) + kullandığınız programlama dilinin language pack'i:
   - **Claude:** bir Proje açın ve iki dosyayı *Project knowledge*'a ekleyin (ya da ilk mesaja yapıştırın).
     Uzun bağlam yeterlidir; isterseniz `SDK/Reference/SDK.tr.md` dosyasının tamamını da ekleyin.
   - **ChatGPT:** bir GPT ya da Proje oluşturup dosyaları yükleyin, ya da ilk mesaja yapıştırın.
   - **Gemini:** Gem talimatlarına ya da ilk mesaja yapıştırın; uzun bağlamla `SDK.tr.md`'yi de ekleyebilirsiniz.
   - **Yerel modeller (7-14B):** system prompt alanına yalnızca system prompt + language pack'i koyun, bağlam uzunluğunu
     en az 8k (tercihen 16k) yapın. Küçük modeller dil farklarını karıştırır: Lua ya da JavaScript seçin ve her yanıtı denetleyin.
   - **Konsolda:** Nexvyn OS Studio'daki **Yapay zekâya sor** paneli AI Sohbet'teki API anahtarlarıyla çalışır; soruya
     ilgili dosyayı ekleyin. Panel dosyalarınızı kendisi değiştirmez.
2. **Görevi isteyin.** `tasks/` içinden bir prompt'u kopyalayıp `<...>` yerlerini doldurun.
3. **İsteğin sonuna** "Yanıt vermeden önce checklist.tr.md listesinden geç" ekleyin (ya da `checklist.tr.md`'yi
   bağlama koyun).
4. **Denetleyin.** Asistanın kodu her zaman checker'dan geçmeli:
   `python SDK/Tools/nxv/nxv.py check <klasör> --sdk <Nexvyn OS kaynak klasörü>`. Hata çıkarsa çıktıyı
   [tasks/fix-lua-check.tr.md](tasks/fix-lua-check.tr.md) prompt'uyla geri verin.
5. **Konsolda deneyin.** Checker'lar mock bir SDK kullanır; asıl deneme konsol ya da Ryujinx'tir.

Güvenlik: asistana API anahtarı, parola ya da kişisel veri vermeyin; bu tür değerleri koda gömmesine izin vermeyin.
Store incelemesi gizli veri toplayan uygulamaları geri çevirir.
