# Görev: tema paketi yap

[English](make-theme.en.md) · **Türkçe**

Context pack'ten (`system-prompt.tr.md`) sonra gönderin ve asistana `SDK/Guides/THEMES.tr.md` dosyasını verin.

```text
Eksiksiz bir Nexvyn OS tema paketi (.nxvtheme) yaz.

Stil: <görünüm birkaç kelimeyle, örn. "sakin mavi görev çubuklu masaüstü, camsı paneller", "sıcak kâğıt, serif hissi", "yeşil fosfor terminal">
Id: com.<adiniz>.theme.<ad>   Ad: <genel bir ad>   Yazar: <ad>
Görünüm: <light | dark | auto>   Düzen: <dock | taskbar>   Pencere biçimi: <default | bevel | flat | glass | mono>
Ekler: <ek duvar kâğıtları, koyu duvar kâğıdı, simge seti, sistem sesleri: hangileri>

Gereksinimler:
- Yalnızca SDK/Guides/THEMES.tr.md içindeki alanları ve ayar anahtarlarını kullan. Anahtar uydurma.
- Her şey özgün: duvar kâğıtlarını (1280x720 JPG) çizen, simgeleri (app id'siyle adlandırılmış 128 px PNG, yalnızca
  değiştirdiklerin) yeniden biçimlendiren ya da çizen ve kısa sesleri (startup, click, notify, error, pop, key; her biri 2 sn
  altı, startup 4 sn altı) sentezleyen bir script yaz (Python, Pillow ve numpy, sesler için standart wave modülü). Sabit rastgele tohumlar.
- Mevcut hiçbir ürünün logosunu, simgesini, duvar kâğıdını, pencere çizimini, açılış sesini ya da adını kopyalama, çizip
  geçme ya da taklit etme. İlhamı yalnızca bir dönemden ya da havadan al. Genel bir ad kullan; id'de, metinlerde ve dosya
  adlarında marka sözcüğü olmasın.
- Okunur kontrast seç: "palette"te ayarladığın her yazı/arka plan çifti en az 4,5:1 (WCAG AA) olsun (windowBg, contentBg ve
  sidebarBg üstünde text, menuBg üstünde menuText, selection üstünde selectionText). Ölçtüğün oranları yaz.
- Paket shell.layout ya da taskbar ayarı yapıyorsa "full": true koy. name, subtitle ve description'ı en ve tr olarak ver
  (istenirse daha çok dil).
- Sınırlar içinde kal: 160 dosya, 32 MB, dosya başına 12 MB, yalnızca izinli uzantılar.

Teslim: theme.json tam, üretici script tam, klasör düzeni; sonra denetleme ve paketleme komutları
(python SDK/Tools/theme/themecheck.py <klasör> --pack), deneme adımları (.nxvtheme'i Dosyalar'da aç, Kur ve Uygula, açık ve koyu
görünümü, Geri al ve Varsayılanlara dön'ü dene) ve yaptığın varsayımlar.
```

Store için ayrıca `store.json` (8 dil), 256x256 `icon.png` ve bir önizleme sesi isteyin; İngilizce arayüzle beş ekran görüntüsü alın (bkz. `SDK/Guides/THEMES.tr.md` 5. bölüm).
