# Parçacık Demosu

[English](README.md) · **Türkçe**

Beş hazır yayıcı (ateş, fıskiye, kıvılcım, kar, büyü), dokunarak patlamalar ve parmakla yerleştirilen çekim kuyuları.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.particles` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.2 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 800 × 450, yeniden boyutlanır |

## Ne öğretir

- `game.emitter` seçenekleri: `rate`, `life`, `speed`, `angle`, `spread`, `gravity`, `damping`, `size`, `colors`, `shape`, `offset`
- Sürekli yayıcı (`rate` + `start` + `moveTo`) ile patlama (`emit(n, x, y)`) farkı
- Kendi kuvvetinizi eklemek: yayıcı parçacıkları düz dizilerde (`px`, `py`, `vx`, `vy`, `t`, `life`) tutar; tablo üretmeden döngüyle çekim uygulanır
- `game.input.pointer` ile dokunma, sürükleme ve bir nesneyi tutup taşıma
- `game.width` / `game.height` ile her pencere boyutuna uyan dokunmatik düğmeler (`game.ui.button`)

**Kullanılan API'ler:** `game.emitter`, `emitter:emit/start/stop/moveTo/update/draw/clear`, `game.input.pointer`, `game.ui.button/text`, `game.gfx`, `game.toast`, `audio.tone`

**Kontroller:** Üret: dokun = patlama, sürükle = akış · Çek / İt: dokunduğun yere kuyu koyar; kuyuyu sürükleyerek taşı, dokunarak kaldır · 1-5: hazır ayar · C: kuyuları temizle.

## Kod parçası

Çekim kuyusu: kuvvet uzaklığın karesiyle azalır; merkeze ulaşan parçacık `t = life` yapılarak geri dönüştürülür.

```lua
local px, py, vx, vy, t, life = em.px, em.py, em.vx, em.vy, em.t, em.life
for i = 1, em.count do
  local dx, dy = wx - px[i], wy - py[i]
  local d2 = dx * dx + dy * dy + 300            -- "softening": finite force in the middle
  local s = k / (d2 * sqrt(d2))                  -- k / d^2 times the unit vector (dx, dy) / d
  vx[i], vy[i] = vx[i] + dx * s, vy[i] + dy * s
  if well.power > 0 and d2 < 340 then t[i] = life[i] end   -- absorbed
end
```

## Çalıştırma

`source/` klasörünü `ParticlesDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (238 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/particles/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
