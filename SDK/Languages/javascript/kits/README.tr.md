# JavaScript için oyun kitleri

[English](README.md) · **Türkçe**

Oyununuzun `main.js` dosyasının yanına kopyalanacak, bağımlılığı olmayan iki ES modülü ve ikisini kullanan bir demo
app ("Signal"). Görmek ve duymak için bu klasörü app olarak çalıştırın (Studio: klasörü açın, **Çalıştır**; ya da
`sdmc:/NexvynOS/Applications/KitDemoJS.nxvapp/` konumuna kopyalayın). [`../../lua/kits`](../../lua/kits/README.tr.md)
içindeki Lua kitleriyle aynıdır; Lua'da iki değer döndüren fonksiyonlar burada dizi döndürür.

| Dosya | Ne verir | Rehber |
|---|---|---|
| [`sfx.js`](sfx.js) | Ses tasarımı: veri klasöründe bir kez WAV dosyasına (`Uint8Array` olarak yazılır) üretilen katmanlı prosedürel tarifler, varyantlar, bus'lar, ducking, ambiyans, müzik döngüleri | [SOUND_DESIGN.tr.md](../../../Guides/SOUND_DESIGN.tr.md) |
| [`juice.js`](juice.js) | Grafik, arayüz ve his: tween, yaylar, sarsıntı, hit-stop, parçacıklar, üretilen dokular, gradyanlar, paletler, başlıklar, paneller, düğmeler, geçişler, kameralar, 3D ışık atmosferleri | [GAME_FEEL.tr.md](../../../Guides/GAME_FEEL.tr.md) |
| `main.js`, `app.json`, `lang/`, `icon.png` | demo | |

```js
import sfx from "./sfx.js";
import J from "./juice.js";
app.load = () => {
  J.init(); sfx.init();
  sfx.define("hit", sfx.recipes.impact({ weight: 0.7 }), { variants: 4, duck: ["music", 0.45, 0.25] });
};
app.update = (dt) => { sfx.update(dt); J.update(dt); };
// vuruşta: sfx.play("hit"); J.burst(x, y, "sparks"); J.shake(0.4); J.hitstop(0.05);
```

`minSdk` 1.1 (JavaScript). Oyununuzu Nexvyn OS kaynak deposunda `node tools/js_check.mjs MyGame.nxvapp` ya da
`nxv check --sdk` ile denetleyin. Demo yapı taşlarının bir örneğidir, kopyalanacak bir menü değildir.
