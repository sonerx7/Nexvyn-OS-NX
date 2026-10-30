# Hareketler Demosu

[English](README.md) · **Türkçe**

İki parmakla yakınlaştırma, döndürme ve kaydırma; parmakların arasındaki nokta sabit kalır. İkinci sekmede konsolu eğerek bilye yuvarlanır, duvara çarpınca HD titreşim verir.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.gestures` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 600, yeniden boyutlanır |

## Ne öğretir

- `"pinch"` (`e.scale`), `"rotate"` (`e.angle`) ve iki parmakla `"scroll"` (`e.dx`, `e.dy`) olayları; parmakların arasındaki nokta etrafında yakınlaştırma ve döndürme
- Aynı görünüm fare ve kumandayla: sürükle, tekerlek, Q / E, çift tıklama
- Köşe noktalarını kendiniz dönüştürerek `gfx.poly` ile döndürülmüş, ölçeklenmiş resim
- `input.motion()`: ivme (G), açısal hız (rad/s) ve birikmiş dönüş, canlı çubuklar ve yapay ufuk
- Çarpma hızına göre güçlü `sys.vibrate`, her 45 derecede hafif "tık" ve zamanlayıcılarla titreşim deseni

**Kullanılan API'ler:** `app.event` (pinch, rotate, scroll, mousedown/move/up), `input.motion`, `input.stick`, `sys.vibrate`, `gfx.poly/clip/alpha`, `timer.after`, `ui.segmented/button`

**Kontroller:** Hareketler: iki parmakla yakınlaştır / döndür / kaydır · fare: sürükle, tekerlek · Q / E döndür · Z / X yakınlaş · çift dokunuş ya da R: sıfırla. Eğme: konsolu eğ (oklar ve sol çubuk da olur) · Ayarla: şu anki duruşu "düz" kabul et.

## Kod parçası

Bir noktanın etrafında yakınlaştırma: o noktadan resmin merkezine giden vektör aynı oranda büyür.

```lua
local function zoomAt(k, sx, sy)
  local nz = max(0.3, min(6, view.zoom * k))
  k = nz / view.zoom
  local ox, oy = sx - canvas.x - canvas.w / 2, sy - canvas.y - canvas.h / 2
  view.panX = ox + (view.panX - ox) * k
  view.panY = oy + (view.panY - oy) * k
  view.zoom = nz
end
function app.event(e)
  if e.type == "pinch" then zoomAt(e.scale, e.x, e.y)
  elseif e.type == "rotate" then rotateAt(e.angle, e.x, e.y)
  elseif e.type == "scroll" and e.touch then view.panX, view.panY = view.panX - e.dx, view.panY - e.dy end
end
```

## Çalıştırma

`source/` klasörünü `GesturesDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (307 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/gestures/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
