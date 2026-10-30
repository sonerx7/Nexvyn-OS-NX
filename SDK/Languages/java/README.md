# Nexvyn OS in Java

**English** · [Türkçe](README.tr.md)

Java apps are compiled on a PC into `app.jar` (Java 8 class files) and run on the console by the miniJVM interpreter.
The SDK is the `nexvyn` package (`Gfx.rect`, `Ui.button`, `Sys.date`...); its sources are in
[SDK/java](../../Reference/README.md). Needs SDK 1.5.

> One Java app runs at a time. Java's own class library (`java.io` files) is not limited by the app's permissions, so
> a Java app installed from the SD card asks the user once before it runs. miniJVM is an interpreter: for
> drawing-heavy games Lua is faster.

## Ready-made template

[`template/`](template/) comes with a compiled `app.jar` and passes the checker. Copy it, or run
`python SDK/Tools/nxv/nxv.py new java "My App" --author yourname`.

## Package and app.json

See the tree above. `mainClass` is the class that extends `nexvyn.App` (public, with a no-argument constructor);
without it the jar manifest's `Main-Class` is used. If you rename the package, update `mainClass` too.

## Program structure

See the code above. Asynchronous callbacks are `Callback` lambdas, passed with a cast:
`Net.json(url, (Callback) a -> show((Record) a[0], a[1]));`

## Building and running

Needs JDK 8 or newer. From the root of the Nexvyn OS source repository:

    python tools/java_build.py app <path>/MyApp.nxvapp      # src/**/*.java -> app.jar
    python tools/java_build.py check <path>/MyApp.nxvapp    # compile only, show the errors

(or `python SDK/Tools/nxv/nxv.py build <path> --sdk <checkout>`). The code is compiled against the console's class
library: an API the console lacks (for example `Random.nextBoolean`) fails on the PC.

- **Studio:** **New Project → Blank Java App** comes with a compiled jar and runs; rebuild the jar on a PC after
  changing the source.
- **Console / Ryujinx:** copy the folder (with the jar) into `NexvynOS/Applications/` (`nxv push` / `nxv install`).

## Checking it on a PC

    python tools/rt_check.py <path>/MyApp.nxvapp

It compiles the sources, checks that `app.jar` exists and holds the main class, the `TR` keys and the `network`
permission for `Net.*`.

## Common pitfalls

- **`src/` changed but `app.jar` is old:** the console runs the jar; rebuild after every change (`nxv check` warns
  about a stale jar).
- **Values are `Object`s:** numbers are `Double`, maps `Record` (`str`, `num`, `integer`, `bool`, `rec`), lists
  `List`. Use `((Number) v).intValue()`, not `(int)`.
- **Cast lambdas to `(Callback)`,** otherwise the `Object...` overload cannot infer the lambda type.
- **Indexes start at 0;** `Ui.textfield` returns only the text, `Ui.submitted("id")` reports Enter.
- **No Swing/AWT, `java.net` sockets or `Runtime.exec`:** use `Net` for the network (`network` permission).
- **Callbacks on the main thread are stopped after 3 seconds;** the Java heap is 64 MB.

## More

- SDK: [SDK.md](../../Reference/SDK.en.md) section 15 · Guide: [JAVA_APPS.md](../../Guides/JAVA_APPS.en.md)
- Samples: [Samples/java](../../Samples/README.md#java) (Hello Java, Dice Roller, Pong)
