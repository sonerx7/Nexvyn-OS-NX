# Verlet Fizik Demosu

[English](README.md) · **Türkçe**

Verlet entegrasyonuyla halatlar, halat köprü ve yırtılabilen kumaş; noktaları tutup sürükleyin, bağları kesin, iğneleyin, rüzgârı açın.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.physics` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.2 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 800 × 450, yeniden boyutlanır |

## Ne öğretir

- Verlet entegrasyonu: nokta şimdiki ve önceki konumunu tutar, aradaki fark hızıdır
- Uzaklık kısıtlarının birkaç geçişte gevşetilmesi; ters kütle (0 = sabit, küçük = ağır) ile ağır ağırlıklar hafif halatı çeker
- Yırtılma (fazla uzayan bağ kopar) ve kesme (sürükleme çizgisinin kestiği bağ kopar, doğru parçası kesişimi)
- Parmağın altındaki en yakın noktayı seçip işaretçiyle taşımak
- Nesne yerine düz diziler ve her üçgen için yeniden kullanılan tek tablo: kare başına çöp yok

**Kullanılan API'ler:** `game.run` (sabit 60 Hz adım / fixed 60 Hz step), `game.input.pointer`, `game.ui.button`, `game.gfx.poly/line/circle`, `store`, `audio.tone`

**Kontroller:** Tut: herhangi bir noktayı sürükle · Kes: bağların üzerinden kaydır · İğnele: noktaya dokunarak sabitle/bırak · Rüzgâr, Yırtılma, Sıfırla düğmeleri · W rüzgâr, R sıfırla, 1-3 araçlar.

## Kod parçası

Bir adımın kalbi: konum farkından hız, ardından her bağ için ters kütleye göre paylaştırılan düzeltme.

```lua
-- integrate: new = now + (now - previous) * damping + gravity * dt^2
local vx, vy = (px - ox[i]) * 0.995, (py - oy[i]) * 0.995
ox[i], oy[i] = px, py
x[i], y[i] = px + vx, py + vy + gdt
-- relax one link a-b towards its rest length
local dx, dy = x[b] - x[a], y[b] - y[a]
local d = sqrt(dx * dx + dy * dy)
local k = (d - len[c]) / (d * (im[a] + im[b]))
x[a], y[a] = x[a] + dx * k * im[a], y[a] + dy * k * im[a]
x[b], y[b] = x[b] - dx * k * im[b], y[b] - dy * k * im[b]
```

## Çalıştırma

`source/` klasörünü `VerletPhysicsDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (384 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/physics/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
