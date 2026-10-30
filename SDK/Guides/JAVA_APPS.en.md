# A Nexvyn OS app in Java

[Türkçe](JAVA_APPS.tr.md) · **English**

Java apps are compiled on the PC (`app.jar`) and run on the console with the miniJVM interpreter. The SDK is in the
`nexvyn` package (`Gfx.rect`, `Ui.button`, `Sys.date`...). Full reference: `sdk/SDK.en.md` section 15; SDK sources:
`sdk/java/nexvyn`; working sample: `romfs/Applications/hellojava.nxvapp` ("Hello Java"). Requires SDK 1.5.

## Bundle

```
Sayac.nxvapp/
├── app.json      {"runtime": "java", "main": "app.jar", "mainClass": "sayac.SayacApp", "minSdk": "1.5", ...}
├── app.jar       built on the PC (see below)
├── src/sayac/SayacApp.java
├── icon.png
└── lang/tr.json, lang/en.json
```

`mainClass` is the class that extends `nexvyn.App`; when it is left out, the `Main-Class` from the jar's manifest is
used.

## Building (PC)

JDK 8 or newer is required:

```
python tools/java_build.py app Sayac.nxvapp      # src/**/*.java -> app.jar
python tools/java_build.py check Sayac.nxvapp    # compile only, show the errors
```

The code is compiled against the console's class library (`romfs/System/Java/minijvm_rt.jar`): an API the console
does not have fails on the PC already. Studio's **Empty Java app** template comes with a compiled `app.jar`; after
changing the source, rebuild the jar on the PC.

## The smallest app

```java
package sayac;

import nexvyn.*;

public class SayacApp extends App {
    private int sayi;

    @Override public void load(String arg) {
        Object v = Store.get("sayi", 0);
        sayi = v instanceof Number ? ((Number) v).intValue() : 0;
    }

    @Override public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        Gfx.color(Theme.text());
        Gfx.text(String.valueOf(sayi), 0, 60, 48, "bold", "center", w);
        if (Ui.button("+1", w / 2 - 50, 140, 100, 34, "primary")) Store.set("sayi", ++sayi);
    }
}
```

## Rules

- SDK functions take `Object...`, so you may leave out optional arguments. Numbers arrive as `Double`, maps as
  `Record` (with the `str`, `num`, `integer`, `bool` helpers), lists as `List`; indexes start at 0.
- Asynchronous callbacks are `Callback` lambdas, passed with a cast:
  `Net.json(url, (Callback) a -> goster((Record) a[0], a[1]));`
- Menu: `return Menu.bar(new Menu(TR("app")).item(TR("sifirla"), 1));`
- `System.out.println` writes to the app's log.

## Limits

One Java app runs at a time. The Java heap is 64 MB; callbacks on the main thread are stopped after 3 seconds. Java's
own class library is not limited by the app's permissions, so a Java app installed from the SD card asks the user
once, on its first launch. There are no Java sockets; use `Net` for networking (`network` permission). miniJVM is an
interpreter: for drawing-heavy games Lua is faster.

Checking on the PC: `python tools/rt_check.py Sayac.nxvapp`.
