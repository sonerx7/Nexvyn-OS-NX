# Efekt Demosu

[English](README.md) · **Türkçe**

Yalnızca `gfx.rect`, `gfx.line` ve renklerle çizilen üç klasik demo sahnesi efekti: plazma, tünel ve yıldız alanı; dört palet ve hücre boyutu ayarı.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.effects` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 560, yeniden boyutlanır |

## Ne öğretir

- "Piksel" ızgarası: pencere 4-16 px hücrelere bölünür, her hücre bir `gfx.rect`; hücre boyutu netlik ile hız arasında seçim yaptırır
- Arama tabloları (LUT): zamanla değişmeyen her şey (açılar, uzaklıklar, paletler) pencere boyutu başına bir kez hesaplanır
- Trigonometri özdeşlikleri: sin(a + b) = sin a cos b + cos a sin b ile sütun ve satır tablolarını paylaşmak
- Koşu birleştirme: bir satırda aynı renkteki komşu hücreler tek, daha geniş bir dikdörtgen olarak çizilir
- Yıldız alanı: x / z izdüşümlü 3B noktalar, hızlıyken iz çizgileri
- Tamsayıyla indekslenen ve zamanla döndürülen paletler

**Kullanılan API'ler:** `gfx.rect/color/line/clear`, `gfx.size`, `sys.time/fps`, `ui.segmented/dropdown/slider/checkbox`, `store`

**Kontroller:** Sürükle: yönlendir · 1 2 3: efekt · C: renk döngüsü.

## Kod parçası

Koşu birleştirme: aynı renkteki komşu hücreler tek `gfx.rect` olur; az renkli palet daha uzun koşular demektir.

```lua
local function flushRow(y, cols, cell)
  local c = 0
  while c < cols do
    local k, s = rowIdx[c], rowShade[c]
    local run = 1
    while c + run < cols and rowIdx[c + run] == k and rowShade[c + run] == s do run = run + 1 end
    gfx.color(floor(PR[k] * s), floor(PG[k] * s), floor(PB[k] * s))
    gfx.rect(c * cell, y, run * cell, cell)       -- one rectangle for the whole run
    c = c + run
  end
end
```

## Çalıştırma

`source/` klasörünü `EffectsDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (283 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/effects/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
