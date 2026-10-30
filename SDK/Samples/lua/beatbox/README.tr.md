# Ritim Kutusu Demosu

[English](README.md) · **Türkçe**

16 adımlı davul makinesi: altı sentezlenmiş davul, tempo, swing, vurgular, susturma, hazır ritimler ve otomatik kayıt.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.beatbox` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 560, yeniden boyutlanır |

## Ne öğretir

- Basit tonlardan davul sentezi: kick = kısa tiz tık + uzun pes sinüs, trampet = gürültü + gövde tonu, el çırpma = `timer.after` ile üç gürültü patlaması
- Kaymayan sıralayıcı saati: sonraki adım zamanı "şimdi"den değil, tam bir adım eklenerek hesaplanır (`nextAt = nextAt + adım`)
- Swing: ikinci on altılıklar biraz geç çalınır, çift adımların toplam süresi aynı kalır
- `ui.hit` ped ızgarası, satır susturma, vurgu (kapalı → açık → vurgulu), hazır ritimler ve `store` ile kayıt
- Oynatma çizgisi, yanıp sönen pedler ve sönümlenen seviye çubukları; boyutlar pencereden hesaplanır

**Kullanılan API'ler:** `audio.tone` (sine, triangle, noise), `timer.after`, `sys.time`, `ui.hit/button/dropdown/slider`, `store`

**Kontroller:** Pede dokun: açık → vurgulu → kapalı · çalgı adına dokun: sustur · Boşluk: çal/durdur · 1-6: satır sustur.

## Kod parçası

Kaymayan saat ve swing: tek adımdan sonra uzun, çift adımdan sonra kısa bir aralık; çift adımın toplamı hep iki adımdır.

```lua
function app.update(dt)
  if not playing then return end
  local now = sys.time()
  if now - nextAt > 0.5 then nextAt = now end      -- after a long pause: skip, do not burst
  while now >= nextAt do
    step = step % STEPS + 1
    playStep(step)
    local len = 60 / bpm / 4                       -- one sixteenth note
    if step % 2 == 1 then nextAt = nextAt + len * (1 + swing)
    else nextAt = nextAt + len * (1 - swing) end
  end
end
```

## Çalıştırma

`source/` klasörünü `BeatboxDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (262 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/beatbox/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
