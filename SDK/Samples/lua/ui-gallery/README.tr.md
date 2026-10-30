# Arayüz Galerisi

[English](README.md) · **Türkçe**

SDK'daki tüm `ui.*` bileşenleri canlı olarak, her birinin yanında onu çizen Lua kodu: düğmeler, anahtarlar, metin alanları, seçimler, geri bildirim, listeler, işaretçi ve iletişim kutuları.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.ui-gallery` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 960 × 620, yeniden boyutlanır |

## Ne öğretir

- Anlık mod (immediate mode): her bileşen her karede çağrılır ve ne olduğunu döndürür
- Tüm `ui` fonksiyonları: button (altı stil, simge, devre dışı), iconButton, toggle, checkbox, radio, slider, textfield (bayraklar, Enter), focus, keyboard, segmented, dropdown, label, progress, spinner, row, group, separator, beginScroll/endScroll (iç içe), hit, mouse, contextMenu, alert, prompt, openFile, saveFile
- Veriyle kurulan düzen: sayfa, kartlardan oluşan bir listedir {başlık, yükseklik, demo fonksiyonu, kod}; içerik yüksekliği kart yüksekliklerinin toplamıdır
- Duyarlı düzen: geniş pencerede kenar çubuğu ve kod yanda, dar pencerede açılır liste ve kod altta

**Kullanılan API'ler:** `ui.*` (hepsi / all), `gfx.shadow/rect/text`, `fs.write` (kullanıcının seçtiği yol / a user-picked path), `store`

**Kontroller:** Kenar çubuğundan ya da açılır listeden sayfa seçin · Page Up / Page Down: sayfa değiştir.

## Kod parçası

Bir kart: canlı bileşeni çizen fonksiyon ve yanında gösterilen kod aynı tabloda durur.

```lua
{title = "ui.hit", desc = "desc_hit", h = 150, demo = function(x, y, w)
  local hit = ui.hit("box", x + S.boxX, y + S.boxY, 90, 60)
  if hit.held then                          -- dx, dy: how far the pointer moved this frame
    S.boxX = max(0, min(w - 90, S.boxX + hit.dx))
    S.boxY = max(0, min(80, S.boxY + hit.dy))
  end
  if hit.doubleClicked then S.boxX, S.boxY = 40, 20 end
  ...
end, code = 'local h = ui.hit("box", bx, by, 90, 60)\n...'},
```

## Çalıştırma

`source/` klasörünü `UIGallery.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (370 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/ui-gallery/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
