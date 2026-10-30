# Java ile Nexvyn OS

[English](README.md) · **Türkçe**

Java uygulamaları PC'de `app.jar`'a derlenir (Java 8 sınıf dosyaları), konsolda miniJVM yorumlayıcısıyla çalışır.
SDK `nexvyn` paketindedir (`Gfx.rect`, `Ui.button`, `Sys.date`...); kaynakları [SDK/java](../../Reference/README.tr.md).
SDK 1.5 gerekir.

> Aynı anda bir Java uygulaması çalışır. Java'nın kendi sınıf kütüphanesi (`java.io` dosyaları) uygulama izinleriyle
> sınırlanmadığı için SD karttan kurulan bir Java uygulaması ilk açılışta kullanıcıya bir kez sorulur. miniJVM
> yorumlayıcıdır: çizim yoğun oyunlar için Lua daha hızlıdır.

## Hazır şablon

[`template/`](template/) derlenmiş `app.jar` ile gelir ve denetleyiciden geçer. Kopyalayın ya da:

    python SDK/Tools/nxv/nxv.py new java "Benim Uygulamam" --author adiniz

## Paket ve app.json

```
BenimUygulamam.nxvapp/
├── app.json          {"runtime": "java", "main": "app.jar", "mainClass": "app.Main", "minSdk": "1.5", ...}
├── app.jar           PC'de derlenir
├── src/app/Main.java
├── icon.png
└── lang/en.json, lang/tr.json ...
```

`mainClass` `nexvyn.App`'ten türeyen sınıftır (genel, argümansız yapıcısı olmalı); yazılmazsa jar'ın manifest'indeki
`Main-Class` kullanılır. Paket adını değiştirirseniz `mainClass`'ı da güncelleyin.

## Program yapısı

```java
package app;

import java.util.List;
import nexvyn.*;

public class Main extends App {
    private int n;

    @Override public void load(String arg) {
        Object v = Store.get("n", 0);                       // sayılar Double gelir
        n = v instanceof Number ? ((Number) v).intValue() : 0;
    }

    @Override public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        Gfx.color(Theme.text());
        Gfx.text(TR("hello"), 0, h / 2, 24, "bold", "center", w);
        if (Ui.button("+1", w / 2 - 50, h / 2 + 40, 100, 34, "primary")) Store.set("n", ++n);
    }

    @Override public List<Menu> menu() { return Menu.bar(new Menu(TR("app")).item(TR("reset"), 1)); }

    @Override public void onmenu(int id) { if (id == 1) Store.set("n", n = 0); }
}
```

Asenkron geri çağırmalar `Callback` lambdasıdır ve tür dönüşümüyle verilir:
`Net.json(url, (Callback) a -> goster((Record) a[0], a[1]));`

## Derleme ve çalıştırma

JDK 8 veya daha yenisi gerekir. Nexvyn OS kaynak deposunun kökünden:

    python tools/java_build.py app <yol>/BenimUygulamam.nxvapp      # src/**/*.java -> app.jar
    python tools/java_build.py check <yol>/BenimUygulamam.nxvapp    # yalnızca derle, hataları göster

(ya da `python SDK/Tools/nxv/nxv.py build <yol> --sdk <kaynak>`). Kod konsolun sınıf kütüphanesine karşı derlenir:
konsolda olmayan bir API (ör. `Random.nextBoolean`) PC'de hata verir.

- **Studio:** **Yeni Proje → Boş Java uygulaması** derlenmiş jar ile gelir ve çalışır; kaynağı değiştirince jar'ı
  PC'de yeniden derleyin.
- **Konsol / Ryujinx:** klasörü (jar dahil) `NexvynOS/Applications/` içine kopyalayın (`nxv push` / `nxv install`).

## PC'de denetim

    python tools/rt_check.py <yol>/BenimUygulamam.nxvapp

Kaynakları derler, `app.jar`'ın varlığını ve ana sınıfı içerdiğini, `TR` anahtarlarını ve `Net.*` için `network`
iznini denetler.

## Sık yapılan hatalar

- **`src/` değişti ama `app.jar` eski:** konsol jar'ı çalıştırır; her değişiklikten sonra yeniden derleyin
  (`nxv check` eski jar'ı uyarır).
- **Değerler `Object`'tir:** sayılar `Double`, sözlükler `Record` (`str`, `num`, `integer`, `bool`, `rec`),
  listeler `List`. `(int)` yerine `((Number) v).intValue()`.
- **Lambda'yı `(Callback)` ile dönüştürün,** yoksa `Object...` aşırı yüklemesi lambda türünü bilemez.
- **Dizinler 0'dan başlar;** `Ui.textfield` yalnızca metni döndürür, Enter için `Ui.submitted("id")`.
- **Swing/AWT, `java.net` soketleri ve `Runtime.exec` yoktur:** ağ için `Net` (`network` izni).
- **Ana iş parçacığındaki geri çağırmalar 3 saniye sonra durdurulur;** Java yığını 64 MB.

## Daha fazlası

- SDK: [SDK.md](../../Reference/SDK.tr.md) bölüm 15 · Rehber: [JAVA_APPS.md](../../Guides/JAVA_APPS.tr.md)
- Örnekler: [Samples/java](../../Samples/README.tr.md#java) (Merhaba Java, Zar Atıcı, Pong)
