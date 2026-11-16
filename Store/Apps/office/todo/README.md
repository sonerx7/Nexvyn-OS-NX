# Yapılacaklar / To-Do

Görevlerini projelere ayıran, öncelik ve son tarih veren, gecikenleri öne çıkaran yapılacaklar listesi.
A to-do list with projects, priorities and due dates that highlights overdue tasks.

## Yenilikler 1.1 / What's new in 1.1

**Türkçe:** Projeler, adımlar, tekrarlar, tarihler.

- Renkli projeler ve Tümü, Bugün, Yaklaşan, Geciken, Tamamlanan listeleri
- İlerlemesi görünen kontrol listesi adımları; günlük, haftalık ya da aylık tekrar
- Dört öncelik düzeyi ve hızlı kısayollu son tarihler
- Hızlı ekleme, anında arama, beş sıralama ve silmeyi geri alma
- Markdown dışa aktarma, JSON yedekleme ve geri yükleme, Hızlı Arama sonuçları
- 7 günlük tamamlama grafiği; açık ve koyu mod

**English:** Projects, steps, repeats and due dates.

- Colour-coded projects plus All, Today, Upcoming, Overdue and Completed
- Checklist steps with progress, and daily, weekly or monthly repeats
- Four priority levels and due dates with quick shortcuts
- Quick add, instant search, five sort orders and undo for deletions
- Markdown export, JSON backup and restore, Quick Search results
- 7-day completion chart; light and dark mode

## Özellikler

- Projeler (renkli, yeniden adlandırılabilir), akıllı listeler: Tümü, Bugün, Yaklaşanlar, Gecikenler, Tamamlananlar.
- Dört öncelik düzeyi, son tarih (YYYY-AA-GG ya da GG.AA.YYYY, Bugün/Yarın/+1 Hafta kısayolları), gecikenler kırmızı.
- Hızlı ekleme alanı, arama (Türkçe İ/ı duyarsız), akıllı/son tarih/öncelik/ad/yeni sıralama.
- Tamamlama ve ekleme animasyonları, silmede 6 saniyelik geri alma, son 7 günde tamamlananlar grafiği.
- Listeyi Markdown kontrol listesi olarak dışa aktarma.
- Klavye: Ctrl+N yeni görev, Ctrl+F ara, ↑/↓ seç, Enter düzenle, Ctrl+Boşluk tamamla, Delete sil, Ctrl+Z geri al.
- Türkçe ve İngilizce; açık ve karanlık mod.

## Kurulum

- **Mağaza:** Uygulama Mağazası > Verimlilik > Yapılacaklar > Al.

İzinler: yok; ağ ya da dosya erişimi istemez (dışa aktarma kullanıcının seçtiği dosyaya yazar).
Veriler `~/Library/Application Support/com.sonerx7.todo/` içinde tutulur.

## Geliştirme

Kaynak `source/` klasöründe (Lua ~869 satır, `app.json`, `lang/`). Denetim:

    python tools/lua_check.py apps/productivity/todo/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
