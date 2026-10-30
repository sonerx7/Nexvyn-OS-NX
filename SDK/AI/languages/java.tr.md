# Language pack: Java 8 (miniJVM)

[English](java.en.md) · **Türkçe**

Uygulama Java ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin. SDK sınıfları
`SDK/Reference/java/nexvyn/` içindedir.

## İskelet

```java
// src/myapp/MyApp.java
package myapp;

import java.util.List;
import nexvyn.*;

public class MyApp extends App {
    private int count;

    @Override public void load(String arg) {
        Object v = Store.get("count", 0);
        count = v instanceof Number ? ((Number) v).intValue() : 0;
    }

    @Override public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        Gfx.color(Theme.text());
        Gfx.text(TR("title"), 0, 24, 24, "bold", "center", w);
        if (Ui.button(TR("add"), w / 2 - 60, 80, 120, 34, "primary")) Store.set("count", ++count);
    }

    @Override public void event(Event e) {
        if (e.is("keydown") && "space".equals(e.key)) Store.set("count", ++count);
    }

    @Override public List<Menu> menu() { return Menu.bar(new Menu(TR("app")).item(TR("reset"), 1)); }

    @Override public void onmenu(int id) { if (id == 1) Store.set("count", count = 0); }
}
```

app.json: `"runtime": "java"`, `"main": "app.jar"`, `"mainClass": "myapp.MyApp"`, `"minSdk": "1.5"`. Build:
`python tools/java_build.py app <bundle>` (JDK 8+). Konsol yalnızca `app.jar`'ı çalıştırır.

## Kurallar

- Sınıflar: `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`, `Theme` (`Theme.bg()`,
  `Theme.get("field")`, `Theme.dark()`), `Json` (`encode`, `decode`), `Record`, `Menu`, `Event`, `Callback`, `Mesh`,
  `SearchResult`. `TR(key, args...)` `App`'ten miras gelir.
- Her SDK function'ı `Object...` alır: isteğe bağlı argument'lar yazılmayabilir. Sonuçlar tiplidir
  (`boolean`, `double`, `int`, `String`, `Record`, `List<Object>`, `double[]`, `Mesh`). Sayılar `Double` olarak gelir;
  eşlemeler `Record` olarak (`str`, `num`, `integer`, `bool`, `rec`); SDK'nın liste aldığı yerlerde diziler
  (`new String[]{...}`) kabul edilir.
- callback'ler tür dönüşümlü `nexvyn.Callback` lambda'larıdır: `Net.json(url, (Callback) a -> show((Record) a[0], a[1]))`,
  `Timer.after(1.5, (Callback) a -> hide())`, `Ui.alert(t, m, new String[]{"OK", "Cancel"}, (Callback) a -> ...)`.
- 0 tabanlı indeksler; `Ui.textfield` metni döndürür, `Ui.submitted(id)`; `Ui.hit(...)` bir `Record` döndürür
  (`hit.bool("clicked")`); `Ui.mouse()` bir `List` döndürür (x, y, down, hovering); `Input.stick("left")` `double[]`
  döndürür (yukarı y pozitif).
- Sınıf kütüphanesi miniJVM'inkidir: `java.lang`, `java.util` (koleksiyonlar, `Random`, `Calendar`...),
  `java.util.function`, lambda'lar, `String.format`, reflection, thread'ler. Swing/AWT yok, `java.net` soketleri yok,
  `Runtime.exec` yok; bazı method'lar eksiktir (örneğin `Random.nextBoolean`): build bunlarda başarısız olur, bu
  yüzden alternatif kullan (`random.nextInt(2) == 0`).
- `System.out` / `System.err` log'a gider. 64 MB yığın, ana thread'de callback başına 3 sn, aynı anda tek
  Java uygulaması.
- `update(double dt)`'yi yalnızca animasyon için geçersiz kıl.

## Denetim

`python tools/rt_check.py <bundle>`: kaynakları konsolun class library'sine karşı derler; app.jar'ın var olduğunu ve
ana sınıfı içerdiğini, TR anahtarlarını ve ağ iznini denetler. Her kaynak değişikliğinden sonra app.jar'ı yeniden
derle.
