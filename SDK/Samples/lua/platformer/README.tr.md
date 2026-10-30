# Platform Demosu

[English](README.md) · **Türkçe**

nexvyn.game motoruyla küçük ama eksiksiz bir platform bölümü: kodla çizilen döşemeler, kamera, animasyon, tek yönlü platformlar ve altınlar.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.platformer` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.2 |
| İzinler | yok |
| Kumanda | uygulamaya gider (L+R: imleç) |
| Pencere | 800 × 450, yeniden boyutlanır |

## Ne öğretir

- Metin satırlarından `game.tilemap.fromStrings` ile harita; döşemeler resim dosyası yerine `draw` geri çağırmasıyla çizilir
- `oneway` döşemeler: alttan zıplayıp üstüne çıkılır, aşağı + zıpla ile `dropThrough` ile inilir
- `game.camera`: yumuşak takip, ölü bölge, sınırlar, sarsıntı; `cam:attach(oran)` ile paralaks arka plan
- `game.animations` yalnızca `frame` numarasını ilerletir; kahraman bu numaraya göre şekillerle çizilir (sprite sayfası gerekmez)
- `game.tween` ile ezilip uzama, coyote süresi ve zıplama tamponu
- Harita nesnelerinden altınlar, `world:collide`, `game.emitter` parçacıkları, `world:trigger` bayrağı, `game.save` rekoru

**Kullanılan API'ler:** `require("nexvyn.game")`, `game.run`, `game.tilemap.fromStrings`, `game.world`, `game.camera`, `game.class(game.Sprite)`, `game.animations`, `game.tween`, `game.emitter`, `game.input.bind/touchControls/vector`, `game.ui`, `game.save`, `game.audio`, `sys.vibrate`

**Kontroller:** Sol çubuk / oklar: yürü · A, B, Boşluk: zıpla (bırakınca kısa zıplar) · aşağı + zıpla: tahtadan in · R / −: yeniden başla · F3: çarpışma kutuları. Dokunmatik ekranda çubuk ve zıplama düğmesi çıkar.

## Kod parçası

Animasyon yalnızca bir sayıdır: oyun motoru `self.frame` değerini ilerletir, `render` her kare için başka bir poz çizer.

```lua
local HERO_ANIMS = game.animations{
  idle = {frames = "1,1,1,2", fps = 3},
  run = {frames = "3-6", fps = 12},          -- frames 3, 4, 5, 6 at 12 fps
  jump = {frames = {7}, loop = false},
}
-- in Hero:update(): pick the animation from the physics state
if self.onFloor then
  self:play(abs(self.vx) > 15 and "run" or "idle")   -- play() restarts only when the name changes
else
  self:play(self.vy < 0 and "jump" or "fall")
end
-- in Hero:render(): legs and body bob depend on self.frame
local leg = LEGS[self.frame]
G.rect(x + leg[1] * d - 1.5, feet - 4 - leg[2], 3, 4, 1, "#2B2F4A")
```

## Çalıştırma

`source/` klasörünü `PlatformerDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (377 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/platformer/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
