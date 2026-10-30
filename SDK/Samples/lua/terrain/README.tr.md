# Arazi Demosu

[English](README.md) · **Türkçe**

Değer gürültüsü ve fBm ile üretilen ada; yüksekliğe ve eğime göre renklenir, saydam deniz, sis, mini harita, otopilot ve uçuş kamerası vardır.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.terrain` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | uygulamaya gider (L+R: imleç) |
| Pencere | 860 × 520, yeniden boyutlanır |

## Ne öğretir

- Tohumlu değer gürültüsü ve fraktal Brown hareketi (birkaç oktav gürültünün toplamı); kenarlara doğru alçalan ada maskesi
- Yükseklik ızgarasından köşe başına renkli tek bir `g3d.custom` modeli
- `mesh:flat` ile düşük poligon ya da yumuşak gölgelendirme (yeniden üretmeden)
- Yaw ve pitch'ten ileri/sağ vektörler, çubuk + klavye + dokunmatik uçuş, araziyle çarpışma (çift doğrusal örnekleme)
- `timer.after` + `timer.cancel` ile pahalı işi geciktirme: kaydırıcı bırakılınca ada bir kez üretilir
- `g3d.gpu()` ile ızgara boyutunu seçmek (GPU'da ~18 bin, CPU'da ~2 bin üçgen)

**Kullanılan API'ler:** `g3d.custom` (renkler / colours), `g3d.mesh("plane")`, `mesh:flat`, `g3d.fog`, `input.stick/down`, `ui.hit` (basılı tut / hold), `timer.after/cancel`, `ui.slider/toggle/button/spinner`, `store`

**Kontroller:** Sol çubuk / WASD: uç · sağ çubuk / oklar / sürükle: bak · ZR ZL / E Q: yukarı aşağı · ekrandaki oklar: ileri geri · F: düşük poligon · Y: panel. 6 saniye dokunmazsanız otopilot başlar.

## Kod parçası

fBm: her oktav frekansı ikiye katlar, genliği pürüzlülükle çarpar.

```lua
local function fbm(x, y, octaves, rough)
  local sum, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves do
    sum = sum + noise(x * freq, y * freq) * amp
    norm = norm + amp
    amp, freq = amp * rough, freq * 2
  end
  return sum / norm
end
-- sliders call scheduleBuild(); only the last call within 0.35 s rebuilds
if rebuildTimer then timer.cancel(rebuildTimer) end
rebuildTimer = timer.after(0.35, function() rebuildTimer = nil; build() end)
```

## Çalıştırma

`source/` klasörünü `TerrainDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (373 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/terrain/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
