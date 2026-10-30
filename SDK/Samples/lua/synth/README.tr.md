# Synth Demosu

[English](README.md) · **Türkçe**

Ekran piyanosu (2-3 oktav), dört dalga biçimi, zamanlayıcılarla yapılan ADSR zarfı, akorlar ve tel tel çalma, zarf grafiği ve osiloskop.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.synth` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 640, yeniden boyutlanır |

## Ne öğretir

- `audio.tone(frekans, saniye, ses, dalga)` ve nota frekansı: f = 440 · 2^((n − 69) / 12)
- `timer.every` ile ADSR: `audio.tone` sesi başlarken sabitlenir, bu yüzden basılı nota zarfın o anki seviyesinde kısa, üst üste binen "tanecikler" olarak çalınır
- `timer.after` ile tel tel akor (her nota bir öncekinden birkaç milisaniye sonra)
- Ses listesiyle çok seslilik ve tuşlar üzerinde kaydırma (mousedown / mousemove / mouseup)
- Veri çizimi: zarf eğrisi, seslerin eğrideki yeri ve `gfx.lines` ile osiloskop

**Kullanılan API'ler:** `audio.tone`, `timer.every/after`, `ui.segmented/slider/checkbox/button/group`, `gfx.lines/circle/rect`, `store`

**Kontroller:** Dokun / tıkla / sürükle: çal · A W S E D F T G Y H U J K O L: piyano tuşları · Z / X: oktav · Esc: tüm notaları sustur.

Not: zarf 50 ms'lik adımlarla ilerler; tanecikler üst üste bindiği için ses biraz "tanecikli" duyulabilir. Bu, sesi çalarken değiştirmeye izin vermeyen `audio.tone` ile yapılabilecek en yakın yaklaşımdır.

## Kod parçası

Zarf saati: saniyede 20 kez her ses ilerler ve zarfın o anki seviyesinde bir tanecik çalar.

```lua
local function level(v)
  if v.held then
    if v.t < set.a then return v.t / max(set.a, 0.001) end                   -- attack
    local dt = v.t - set.a
    if dt < set.d then return 1 - (1 - set.s) * dt / max(set.d, 0.001) end  -- decay
    return set.s                                                             -- sustain
  end
  return v.relFrom * max(0, 1 - v.relT / max(set.r, 0.001))                  -- release
end
local function playGrain(v)
  local l = level(v)
  if l > 0.005 then audio.tone(v.freq, GRAIN_LEN, l * l * set.vol, WAVES[set.wave]) end
end
timer.every(GRAIN, tick)   -- tick() advances every voice and calls playGrain
```

## Çalıştırma

`source/` klasörünü `SynthDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (345 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/synth/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
