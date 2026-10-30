# Görev: var olan bir Lua uygulamasını ya da oyununu JavaScript'e taşımak

[English](port-lua-to-js.en.md) · **Türkçe**

`system-prompt.tr.md` + `languages/javascript.tr.md` dosyalarından sonra gönderin (`languages/lua.tr.md` de yardımcı
olur). Lua dosyalarını prompt'un altına yapıştırın. Aynı prompt Python ya da Squirrel için de çalışır: hedefi değiştirip
o dilin language pack'ini ekleyin.

```text
Bu Nexvyn OS uygulamasını Lua'dan JavaScript'e taşı. Davranışı, görünüşü, uygulama kimliğini, lang/*.json
anahtarlarını ve store anahtarlarını aynen koru; böylece mevcut kullanıcıların kayıtlı verileri kalır.

Bunu dikkatle yap:
1. app.json: "main"i "main.js" yap, "minSdk"yı en az "1.1" yap (uygulama gerektiriyorsa daha yüksek değeri koru),
   "permissions"ı olduğu gibi bırak.
2. İndeksler: Lua 1 tabanlı, JavaScript 0 tabanlı. ui.segmented / ui.dropdown seçimlerini, ui.alert düğme
   indekslerini, varsayılan ui.contextMenu id'lerini ve g3d.custom indekslerini dönüştür. Lua ile store'a zaten
   kaydedilmiş değerler (örneğin seçili bir sekme) 1 tabanlıdır: yüklerken dönüştür (ve bunu bir yorumda belirt).
3. Birden çok sonuç diziye dönüşür: local w, h = gfx.size() -> const [w, h] = gfx.size(); ui.mouse,
   ui.beginScroll, sys.battery, input.stick, input.motion, g3d.project için de aynısı.
4. JS'de ui.textfield yalnızca metni döndürür; "text, submitted = ui.textfield(...)" yerine metin artı
   ui.submitted(id) kullan. ui.row 0/1/2 döndürür.
5. nil -> null; tablolar -> diziler/nesneler; mesh:setColor -> mesh.setColor; string.format -> template string'ler;
   # uzunluğu -> .length; string.sub/find -> slice/indexOf (1 tabanlı konumlara dikkat); math.floor Math.floor olur.
6. require("x") -> "./x.js"'ten import; modül tabloları adlandırılmış dışa aktarımlı ES modüllerine dönüşür.
7. callback'ler callback olarak kalabilir; async/await'i yalnızca kodu daha anlaşılır yaptığı yerde, try/catch
   ile kullan.
8. Uygulama nexvyn.game kullanıyorsa (yalnızca Lua) önce bunu söyle: doğrudan taşınamaz; ya Lua'da kalmayı ya da oyun
   döngüsünü JS'de düz gfx/input ile yeniden yazmayı öner.

Her dosyayı eksiksiz ver, sonra davranışın farklı olabileceği her yeri ve bunu node tools/js_check.mjs ile nasıl
doğrulayacağımı listele.
```
