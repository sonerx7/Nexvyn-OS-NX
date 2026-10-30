# Zar ve Yazı Tura / Dice & Coin

Bir ile altı arasında zar (d4–d20) atan ya da yazı tura atan, geçmişi ve istatistikleri tutan Nexvyn OS uygulaması.
A Nexvyn OS app that rolls one to six dice (d4–d20) or flips a coin and keeps a history and statistics.

## Özellikler

- 1–6 zar; d6 noktalarla, d4/d8/d10/d12/d20 numaralı şekillerle çizilir; yuvarlanma ve zıplama animasyonu, toplam ve aralık.
- Zara dokunarak sabitleme (kilitli zarlar yeniden atılmaz); masaya dokunmak, Boşluk ya da Enter zar atar.
- Havada dönen ve yatayda daralan para animasyonuyla yazı tura; tura/yazı sayıları ve yüzdeleri.
- İstatistik sekmesi: seçili zar türü için tüm zamanların yüz dağılımı grafiği, hilesiz zar çizgisi ve yazı tura oranı.
- Son 50 atışın geçmişi; son sonucu panoya kopyalama, geçmişi CSV olarak kaydetme, temizlemeyi geri alma.
- İsteğe bağlı ses ve titreşim. Klavye: Boşluk/Enter at, C para at, yukarı/aşağı zar sayısı, sol/sağ sekme, Esc sabitlemeyi bırakır.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Zar ve Yazı Tura > Al.

İzinler: yalnızca `clipboard` (son sonucu kopyalamak için). Ağ ya da dosya erişimi istemez; CSV yalnızca senin
seçtiğin dosyaya yazılır.
Veriler `~/Library/Application Support/com.sonerx7.dice/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~620 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/dice/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
