# Karar Çarkı / Decision Wheel

Kendi seçeneklerinle renkli bir çark çevirip karar vermeni sağlayan Nexvyn OS uygulaması.
A Nexvyn OS app that helps you decide by spinning a colorful wheel of your own options.

## Özellikler

- Birden çok kayıtlı çark (ör. "Yemek", "Kim yapacak?"); yeni çark, yeniden adlandırma ve onaylı silme.
- 2–24 seçenek: ekleme, yeniden adlandırma, geri alınabilir kaldırma, A–Z sıralama ve karıştırma.
- Yavaşlayarak duran gerçekçi dönüş, her dilimde tık sesi ve titreyen ibre; çarkı parmakla sürükleyip fırlatarak da çevirebilirsin.
- Kazanan afişi ve konfeti; isteğe bağlı olarak kazanan bir sonraki çevirişte çarktan çıkar.
- Sonuçlar sekmesi: her çark için kazanma sayıları çubuk grafikle; kazananı ve sonuçları panoya kopyalama.
- Klavye: Boşluk/Enter çevirir, A seçenek ekler, sol/sağ çark değiştirir, Esc afişi kapatır, Ctrl+Z kaldırmayı geri alır.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Karar Çarkı > Al.

İzinler: yalnızca `clipboard` (kazananı ve sonuçları kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.wheel/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~640 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/wheel/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
