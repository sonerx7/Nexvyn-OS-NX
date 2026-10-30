# Language pack: Java 8 (miniJVM)

**English** · [Türkçe](java.tr.md)

Add this after `system-prompt.en.md` when the app is written in Java. The SDK classes are in `SDK/Reference/java/nexvyn/`.

## Skeleton

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

app.json: `"runtime": "java"`, `"main": "app.jar"`, `"mainClass": "myapp.MyApp"`, `"minSdk": "1.5"`. Build with
`python tools/java_build.py app <bundle>` (JDK 8+). The console only runs `app.jar`.

## Rules

- Classes: `Gfx`, `Ui`, `G3d`, `Fs`, `Store`, `Net`, `Sys`, `Audio`, `Input`, `Timer`, `Tr`, `Theme` (`Theme.bg()`,
  `Theme.get("field")`, `Theme.dark()`), `Json` (`encode`, `decode`), `Record`, `Menu`, `Event`, `Callback`, `Mesh`,
  `SearchResult`. `TR(key, args...)` is inherited from `App`.
- Every SDK function takes `Object...`: optional arguments can be left out. Results are typed (`boolean`, `double`,
  `int`, `String`, `Record`, `List<Object>`, `double[]`, `Mesh`). Numbers arrive as `Double`; maps as `Record`
  (`str`, `num`, `integer`, `bool`, `rec`); arrays (`new String[]{...}`) are accepted where the SDK takes a list.
- Callbacks are `nexvyn.Callback` lambdas with a cast: `Net.json(url, (Callback) a -> show((Record) a[0], a[1]))`,
  `Timer.after(1.5, (Callback) a -> hide())`, `Ui.alert(t, m, new String[]{"OK", "Cancel"}, (Callback) a -> ...)`.
- 0-based indexes; `Ui.textfield` returns the text, `Ui.submitted(id)`; `Ui.hit(...)` returns a `Record`
  (`hit.bool("clicked")`); `Ui.mouse()` returns a `List` (x, y, down, hovering); `Input.stick("left")` returns
  `double[]` (y up positive).
- The class library is miniJVM's: `java.lang`, `java.util` (collections, `Random`, `Calendar`...),
  `java.util.function`, lambdas, `String.format`, reflection, threads. No Swing/AWT, no `java.net` sockets, no
  `Runtime.exec`; some methods are missing (for example `Random.nextBoolean`): the build fails on them, so use
  alternatives (`random.nextInt(2) == 0`).
- `System.out` / `System.err` go to the log. 64 MB heap, 3 s per callback on the main thread, one Java app at a time.
- Override `update(double dt)` only for animation.

## Check

`python tools/rt_check.py <bundle>`: compiles the sources against the console's class library, checks that app.jar
exists and holds the main class, the TR keys and the network permission. Rebuild app.jar after every source change.
