# Şekiller JS Demosu

[English](README.md) · **Türkçe**

JavaScript ile yedi g3d temel şekli bir döner tabla üzerinde: dokular, tel kafes, tıklanabilir etiketler ve async/await ile oynayan bir giriş.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.shapes-js` |
| Dil | JavaScript |
| En düşük SDK | 1.1 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 560, yeniden boyutlanır |

## Ne öğretir

- ES modülleri: paketteki başka dosyadan `import` (shapes.js)
- Her temel şekil için `g3d.mesh`, `mesh.setTexture(yol | null)` ve `mesh.triangles()`
- `async`/`await timer.sleep(sn)`: şekilleri sırayla gösteren ve yeniden başlatılınca temizce iptal olan giriş
- `setInterval`/`clearInterval` (milisaniye) ile doku döngüsü, `setTimeout` ile kısa sekme; `app.close` içinde temizlik
- `g3d.project` → `[sx, sy, derinlik]` ya da `null`; 3B nesnelerin üstünde `ui.hit` ile tıklanabilir etiketler
- Lua'dan farklar: `ui.segmented` 0'dan başlar, çok değerli dönüşler dizi olur

**Kullanılan API'ler:** `import`, `g3d.mesh`, `mesh.setTexture/setColor/triangles`, `g3d.project`, `timer.sleep`, `setInterval/clearInterval/setTimeout`, `ui.segmented/checkbox/button/hit`, `store`, `audio.tone`

**Kontroller:** Sürükle: döndür · tekerlek ya da iki parmak: yakınlaş · etikete dokun: seç · sol/sağ ok: seç · Boşluk: giriş.

## Kod parçası

Yeniden başlatılabilen async giriş: her çalıştırma bir numara alır; eski çalıştırma bir sonraki `await` sonrasında durur.

```js
async function intro() {
  const run = ++introRun;             // a newer intro makes this one stop at its next await
  for (const s of shapes) s.target = 0;
  await timer.sleep(0.45);
  for (const s of shapes) {
    if (run !== introRun) return;
    s.target = 1;                     // app.update eases s.scale towards s.target
    await timer.sleep(0.16);
  }
}
autoTimer = setInterval(() => applyTexture((texIndex + 1) % TEXTURES.length), 2500);
```

## Çalıştırma

`source/` klasörünü `ShapesJSDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.js` (231 satır), `shapes.js` (16 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`, `tex/*.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    node tools/js_check.mjs <Nexvyn-OS-NX>/SDK/Samples/javascript/shapes-js/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
