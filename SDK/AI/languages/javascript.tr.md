# Language pack: JavaScript (QuickJS-ng, ES2023)

[English](javascript.en.md) · **Türkçe**

Uygulama JavaScript ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin.

## İskelet

```js
// main.js (bir ES modülü, strict mode)
import { Model } from "./model.js";      // bundle içinde göreli import'lar; "./data.json" parse edilmiş JSON verir

const model = new Model();

app.load = (arg) => { model.items = store.get("items", []); };
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w);
  if (ui.button(TR("refresh"), 20, 70, 140, 34, "primary")) refresh();   // async, arka planda çalışır
};
app.menu = () => [{ title: TR("app"), items: [{ label: TR("reset"), id: 1 }] }];
app.onmenu = (id) => { if (id === 1) model.reset(); };

async function refresh() {
  try {
    const data = await net.fetchJson("https://example.com/api.json");   // ağ / HTTP / JSON hatalarında reddeder
    model.items = data.items;
  } catch (e) {
    model.error = e.message;
  }
}
```

app.json: `"main": "main.js"` (ya da `"runtime": "js"`), `"minSdk": "1.1"`, `net` kullanılıyorsa
`"permissions": ["network"]`.

## Kurallar

- İndeksler 0 tabanlıdır. nil yerine `null`. Birden çok sonuç dizidir: `const [w, h] = gfx.size()`,
  `const [x, y, down, hovering] = ui.mouse()`, `const [scrollY, scrollX] = ui.beginScroll(...)`.
- `ui.textfield(id, text, ...)` yalnızca yeni metni döndürür; Enter karesinde `ui.submitted(id)` true olur.
  `ui.row(...)` 0, 1 (tıklandı) ya da 2 (çift tıklandı) döndürür.
- Promise'ler: callback alan her SDK çağrısı, callback verilmezse bir Promise döndürür: `await net.get(url)`
  (hiç reddetmez, `res.ok`'u denetle), `await net.json(url)` / `await net.fetchJson(url[, headers])` (başarısızlıkta
  reddeder), `await net.fetch(url, {method, headers, body, contentType})`, `await ui.alert(...)` (0 tabanlı indeks),
  `await ui.prompt(...)`, `await ui.openFile(exts)`, `await ui.saveFile(name)`, `await timer.sleep(s)`.
  İşlenmeyen bir ret hata ekranını açar: her zaman `try`/`catch` kullan.
- Ekstralar: `setTimeout`/`setInterval`/`clearTimeout`/`clearInterval` (ms), `console.log`, `fs.readBytes` →
  `Uint8Array`, `JSON.parse` / `JSON.stringify`, `ui.submitted`, `net.request`.
- Olmayanlar: `window`, `document`, `fetch`, `XMLHttpRequest`, `localStorage`, `require`, `process`, `Intl`.
  Yerel saat için `sys.date()` kullan.
- Mesh'ler: `mesh.setColor(c)` (iki nokta üst üste değil, nokta).

## Denetim

`node tools/js_check.mjs <bundle> --frames 600`: her .js dosyasını modül olarak parse eder, TR anahtarlarını denetler,
uygulamayı iki dilde mock bir SDK'ya karşı çalıştırır ve yakalanmamış hataları ve işlenmemiş retleri bildirir.
