# Alışveriş Listesi / Shopping List

Reyonlara göre gruplanan, birden çok listeyi yöneten bir Nexvyn OS alışveriş listesi uygulaması (Lua SDK).
A Nexvyn OS shopping list app (Lua SDK) with several lists, grouped by aisle.

## Özellikler

- Birden çok liste (Market, Ev, Parti…): kenar çubuğundan seç, yeniden adlandır, sil; PgUp/PgDn ile listeler arasında geç.
- Ürünler miktar ve birimle (adet, kg, g, L, paket) ve kategoriyle eklenir: Meyve-Sebze, Süt Ürünleri, Et ve Balık, Fırın, Kuru Gıda, İçecek, Temizlik, Diğer.
- Liste kategorilere göre gruplanır; sepete atılan ürünler animasyonla işaretlenir, soluklaşır ve en alttaki "Sepette" bölümüne iner.
- Geçmişten hızlı öneriler: yazdıkça eşleşen ürünler çıkar, tek dokunuşla yeniden eklenir; aynı ürün tekrar eklenince miktarı artar.
- Ürüne dokununca düzenleme penceresi, sağ tık / X ile bağlam menüsü; "Alınanları Temizle" ve silmeler geri alınabilir (Ctrl+Z).
- Listeyi panoya kopyala (Ctrl+C) ya da metin dosyası olarak kaydet (Ctrl+S).
- Klavye: Enter ekler, ok tuşları seçer, Boşluk işaretler, E düzenler, Delete siler. Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Alışveriş Listesi > Al.

İzinler: yalnızca `clipboard` (listeyi panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.shopping/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~850 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/shopping/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
