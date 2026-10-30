# Language pack: Lua 5.4

[English](lua.en.md) · **Türkçe**

Uygulama Lua ile yazılıyorsa bunu `system-prompt.tr.md` dosyasından sonra ekleyin.

## İskelet

```lua
-- main.lua
local app = {}
local state = {}                    -- modül düzeyindeki durum pencere açık kaldıkça yaşar

function app.load(arg)
  state.count = store.get("count", 0)
  state.logo = gfx.image("bundle:/logo.png")   -- resimleri bir kez yükle
end

function app.update(dt) end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 0, 24, 24, "bold", "center", w)
  if ui.button(TR("add"), w / 2 - 60, 80, 120, 34, "primary") then
    state.count = state.count + 1
    store.set("count", state.count)
  end
end

function app.menu() return {{title = TR("app"), items = {{label = TR("reset"), id = 1}}}} end
function app.onmenu(id) if id == 1 then state.count = 0; store.set("count", 0) end end

return app
```

app.json: `"main": "main.lua"` (`runtime` gerekmez), `"minSdk": "1.0"` (`nexvyn.game` ile `"1.2"`; paylaşım /
zamanlama / izin API'si / yaşam döngüsü callback'leriyle `"1.4"`).

## Kurallar

- İndeksler 1 tabanlıdır: `ui.segmented`, `ui.dropdown`, `ui.alert` düğme indeksi, `g3d.custom` indeksleri,
  varsayılan `ui.contextMenu` id'leri.
- Birden çok sonuç: `local text, submitted = ui.textfield(...)`, `local w, h = gfx.size()`,
  `local x, y = input.stick("left")`, `local clicked, double = ui.row(...)`.
- Kullanılabilenler: `string`, `table`, `math`, `utf8`, `coroutine`, `os.time/clock/date/difftime`, `pcall`.
  Kullanılamayanlar: `io`, `debug`, `package`, `dofile`, `loadfile`, `os.execute`.
- `require("name")` önce bundle'dan `name.lua` dosyasını yükler (`require("a.b")` → `a/b.lua`), sonra sistem
  kütüphanesine bakar (`require("nexvyn.game")`).
- Model method'ları `:` ile çağrılır: `mesh:setColor(c)`, `mesh:setTexture("bundle:/wood.png")`.
- `nexvyn.game` ile oyunlar: `main.lua`, `return game.run{width = 480, height = 270, scene = Play}` ile biter; sanal
  birimlerde `game.gfx` ile çiz, HUD'u `scene:ui()` içinde çiz, girdiyi `game.input` ile al.
- Checker yorumları da tarar: yorumlara var olmayan anahtarlar için `TR("...")` örnekleri yazma.

## Denetim

`python tools/lua_check.py <bundle> --frames 600` (`pip install lupa` gerekir): her dosyayı derler, TR anahtarlarını
(en + tr) denetler, uygulamayı rastgele girdi, menüler ve yaşam döngüsü callback'leriyle mock bir SDK'ya karşı
çalıştırır.
