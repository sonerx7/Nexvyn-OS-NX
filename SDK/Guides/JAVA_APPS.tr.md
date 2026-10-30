# Java ile Nexvyn OS uygulaması

**Türkçe** · [English](JAVA_APPS.en.md)

Java uygulamaları PC'de derlenir (`app.jar`), konsolda miniJVM yorumlayıcısıyla çalışır. SDK `nexvyn` paketindedir
(`Gfx.rect`, `Ui.button`, `Sys.date`...). Tam başvuru `sdk/SDK.tr.md` bölüm 15, SDK kaynakları `sdk/java/nexvyn`, çalışan
örnek `romfs/Applications/hellojava.nxvapp` ("Merhaba Java"). SDK 1.5 gerekir.

## Paket

```
Sayac.nxvapp/
├── app.json      {"runtime": "java", "main": "app.jar", "mainClass": "sayac.SayacApp", "minSdk": "1.5", ...}
├── app.jar       PC'de derlenir (aşağıya bakın)
├── src/sayac/SayacApp.java
├── icon.png
└── lang/tr.json, lang/en.json
```

`mainClass` `nexvyn.App`'ten türeyen sınıftır; yazılmazsa jar'ın manifest'indeki `Main-Class` kullanılır.

## Derleme (PC)

JDK 8 veya daha yenisi gerekir:

```
python tools/java_build.py app Sayac.nxvapp      # src/**/*.java -> app.jar
python tools/java_build.py check Sayac.nxvapp    # yalnızca derle, hataları göster
```

Kod konsolun sınıf kütüphanesine (`romfs/System/Java/minijvm_rt.jar`) karşı derlenir: konsolda olmayan bir API PC'de
hata verir. Studio'daki **Boş Java uygulaması** şablonu derlenmiş bir `app.jar` ile gelir; kaynağı değiştirdikten sonra
jar'ı PC'de yeniden derleyin.

## En küçük uygulama

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

## Kurallar

- SDK fonksiyonları `Object...` alır; isteğe bağlı argümanları yazmayabilirsiniz. Sayılar `Double`, sözlükler `Record`
  (`str`, `num`, `integer`, `bool` yardımcılarıyla), listeler `List` olarak gelir; indeksler 0'dan başlar.
- Asenkron geri çağırmalar `Callback` lambdasıdır ve tür dönüşümüyle verilir:
  `Net.json(url, (Callback) a -> goster((Record) a[0], a[1]));`
- Menü: `return Menu.bar(new Menu(TR("app")).item(TR("sifirla"), 1));`
- `System.out.println` uygulama günlüğüne yazar.

## Sınırlar

Aynı anda bir Java uygulaması çalışır. Java yığını 64 MB; ana iş parçacığındaki geri çağırmalar 3 saniye sonra
durdurulur. Java'nın kendi sınıf kütüphanesi uygulama izinleriyle sınırlanmadığı için SD karttan kurulan bir Java
uygulaması ilk açılışta kullanıcıya bir kez sorulur. Java soketleri yoktur, ağ için `Net` kullanın (`network` izni).
miniJVM yorumlayıcıdır: çizim yoğun oyunlar için Lua daha hızlıdır.

PC'de denetim: `python tools/rt_check.py Sayac.nxvapp`.
