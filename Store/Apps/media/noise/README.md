# Beyaz Gürültü / White Noise

Odaklanmak ve uyumak için yalnızca sentezlenmiş tonlardan üretilen sakinleştirici sesler.
Calming sounds for focus and sleep, built entirely from synthesized tones.

## Özellikler

- Altı ses: beyaz, pembe ve kahverengi gürültü, yağmur (rastgele damlalar), okyanus (yaklaşık 8 saniyede bir yükselen dalgalar) ve şömine çıtırtısı.
- Kesintisiz çalma: üst üste binen kısa parçalar zamanında yeniden başlatılır; doku sesleri her seferinde rastgele ses düzeyiyle çalınır.
- Uyku zamanlayıcısı (15/30/45/60/90 dk): son dakikada ses yavaşça azalır, oynat düğmesinin çevresindeki halka kalan süreyi gösterir.
- Her sese özel sakin animasyon: düşen damlalar, dalgalar, yükselen kıvılcımlar, nefes alan halkalar.
- Ses düzeyi, seçilen ses ve zamanlayıcı hatırlanır; durdurunca ve pencere kapanınca tüm sesler susar.
- Klavye: Boşluk/Enter oynat ve durdur, sol/sağ ok ses değiştir, yukarı/aşağı ok ses düzeyi, T zamanlayıcı.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Medya > Beyaz Gürültü > Al.

İzinler: yok; ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.noise/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~440 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/media/noise/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
