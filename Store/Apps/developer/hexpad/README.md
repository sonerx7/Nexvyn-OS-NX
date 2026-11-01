# Hexpad

A hex editor for any file. Her dosya için onaltılık düzenleyici.

Hexpad opens any file from the SD card and shows its bytes in hex and as text side by side. Edit in place or insert, find byte patterns with wildcards, and read values at the cursor with the data inspector.

• Overwrite and insert modes with unlimited undo and redo
• Find hex (DE AD ?? EF) or text, go to offset, bookmarks per file
• Inspector for integers, floats, Unix time and UTF-8, little or big endian, editable
• Selection, copy as hex, text or a C array, paste bytes, fill
• Hex keypad for touch and controller; files up to 16 MB

## Türkçe

Hexpad SD karttaki her dosyayı açar ve baytlarını onaltılık ve metin olarak yan yana gösterir. Yerinde düzenle ya da ekle, joker karakterlerle bayt dizileri ara ve imleçteki değerleri veri denetçisiyle oku.

• Sınırsız geri al/yinele ile üzerine yazma ve ekleme kipleri
• Onaltılık (DE AD ?? EF) ya da metin arama, konuma git, dosya başına yer imleri
• Tamsayı, ondalık, Unix zamanı ve UTF-8 için düzenlenebilir denetçi, little ya da big endian
• Seçim; onaltılık, metin ya da C dizisi olarak kopyalama; bayt yapıştırma, doldurma
• Dokunmatik ve kontrolcü için onaltılık tuş takımı; 16 MB'a kadar dosyalar

## Install / Kurulum

App Market > Developer > Hexpad. Permissions / İzinler: none / yok.
Data / Veri: `~/Library/Application Support/com.sonerx7.hexpad/`.

## Development / Geliştirme

Source in `source/` (main.js, `lang/` in 8 languages). Check:

    node tools/js_check.mjs Store/Apps/developer/hexpad/source

| Version / Sürüm | Changes / Değişiklik |
|---|---|
| 1.0 | First release / İlk sürüm |
