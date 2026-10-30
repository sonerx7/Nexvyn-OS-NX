# Görev: bir lua_check hatasını (ya da herhangi bir checker hatasını) düzeltmek

[English](fix-lua-check.en.md) · **Türkçe**

`system-prompt.tr.md` + language pack'ten sonra gönderin. Checker'ın çıktısının tamamını ve adını verdiği dosyaları
yapıştırın.

```text
Nexvyn OS checkersi uygulamam için aşağıdaki sorunları bildiriyor. Uygulamanın yaptığı işi değiştirmeden düzelt.

Checker çıktısı:
<python tools/lua_check.py ... (ya da js_check / py_check / rt_check / nxv check) çıktısının tamamını yapıştırın>

Dosyalar:
<app.json'u, çıktıda adı geçen dosyaları ve lang/en.json + lang/tr.json'u yapıştırın>

Çıktı nasıl okunur:
- "lang/en.json missing: <key>" / "TR(...) missing": anahtarı lang/en.json VE lang/tr.json'a (ve diğer lang
  dosyalarına) ekle ya da TR() çağrısındaki yazım hatasını düzelt. Checker yorumları da tarar: yorumdaki bir
  TR("...") örneği de sayılır.
- "unknown icon names (not in Icons.codepoints, nothing is drawn)": Material Icons Round'dan bir ad kullan
  (ör. "settings", "delete", "add").
- "expected number for argument N": bir gfx çağrısı nil ya da metin aldı; o karede hangi değişkenin nil olduğunu bul.
- Bir Lua stack trace ("main.lua:123: attempt to index a nil value"): mock SDK callback'lerini rastgele tıklamalar,
  tuşlar, kumanda basışları, menüler ve yaşam döngüsü callback'leriyle (suspend, resume, focus, autosave, unsaved,
  close) çalıştırdı. Kodu bu çağrıların her sırasına karşı güvenli yap (ör. veri yüklenmeden draw, her id ile onmenu,
  herhangi bir anda close).
- "uses net.* but app.json permissions has no network": "permissions"'a "network" ekle.
- "does not compile" (C) ya da "Java sources do not compile": bildirilen satırı düzelt; Java'da API, miniJVM'in sınıf
  kütüphanesinde olmayabilir.
- "app.jar missing" / "is not in app.jar": python tools/java_build.py app <bundle> ile yeniden derle.

Değişen her dosyayı eksiksiz döndür ve her sorun için nedenini söyleyen bir satır yaz.
```

Sonra checkeryi yeniden çalıştırın. Aynı hata geri gelirse yeni çıktıyı gönderin; asistandan denetimi "atlamasını"
istemeyin.
