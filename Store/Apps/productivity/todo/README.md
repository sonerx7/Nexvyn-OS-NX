# Yapılacaklar / To-Do

Görevlerini projelere ayıran, öncelik ve son tarih veren, gecikenleri öne çıkaran yapılacaklar listesi.
A to-do list with projects, priorities and due dates that highlights overdue tasks.

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
