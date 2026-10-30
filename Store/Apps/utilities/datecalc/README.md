# Tarih Hesaplayıcı / Date Calculator

İki tarih arasını hesaplayan, tarihe süre ekleyen ve her günün bilgisini veren Nexvyn OS uygulaması.
A Nexvyn OS app that measures the time between dates, adds time to a date and tells you all about any day.

## Özellikler

- Fark: iki tarih arasındaki gün, hafta + gün, yıl/ay/gün, iş günü (Pzt–Cum) ve saat; bitiş gününü sayma seçeneği, tarihleri değiştirme.
- Ekle / Çıkar: bir tarihe yıl, ay, hafta ve gün ekleme ya da çıkarma (31 Ocak + 1 ay = 28/29 Şubat).
- Tarih bilgisi: haftanın günü, yılın kaçıncı günü, ISO hafta numarası, artık yıl, çeyrek, yıl sonuna kalan gün ve ay takvimi.
- Tarih girişi gün/yıl adımlayıcıları ve ay listesiyle; sayıya dokunup elle yazma ve Bugün düğmesi. 1–9999 yılları arası, tamamen aritmetik takvim hesabı.
- Klavye: Ctrl+1/2/3 sekme, Ctrl+T bugün, Ctrl+C sonucu kopyala; Tarih Bilgisi sekmesinde oklar (ve D-pad) günü değiştirir.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Araçlar > Tarih Hesaplayıcı > Al.

İzinler: yalnızca `clipboard` (sonucu panoya kopyalamak için). Ağ ya da dosya erişimi istemez.
Veriler `~/Library/Application Support/com.sonerx7.datecalc/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (`main.lua` ~590 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/utilities/datecalc/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
