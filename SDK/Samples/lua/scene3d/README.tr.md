# 3B Sahne Demosu

[English](README.md) · **Türkçe**

UV koordinatlı `g3d.custom` modeller (sandık, sekizgen kaide, kavisli tuğla duvar, döşeme zemin), gün saatine göre hareket eden güneş, sis, parlayan lamba haleleri ve yörünge kamerası.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.scene3d` |
| Dil | Lua 5.4 |
| En düşük SDK | 1.0 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 860 × 520, yeniden boyutlanır |

## Ne öğretir

- `g3d.custom(köşeler, indisler, renkler, flat, uv)` ile kendi modelinizi kurmak; dörtgen yardımcı fonksiyonu
- Dışarıdan bakınca saat yönünün tersine (CCW) sıralama ve arka yüz ayıklama
- 1'den büyük UV dokuyu tekrarlar (zemin); duvarda UV yay uzunluğunu izler, tuğlalar bozulmaz
- Temel şekillerde `mesh:setTexture`; dokusuz (CPU) yolda `setColor` rengi
- `g3d.light` (yön, ortam, renk) ve gökyüzüne uydurulmuş `g3d.fog`
- Yörünge kamerası (sürükle, tekerlek, iki parmak), `"glow"` ile halo, `g3d.project` ile 3B noktaların üstünde 2B etiketler

**Kullanılan API'ler:** `g3d.custom`, `g3d.mesh`, `mesh:setTexture/setColor`, `g3d.begin/camera/light/fog/draw/point/project/finish`, `g3d.gpu`, `ui.slider/toggle/iconButton`, `store`

**Kontroller:** Sürükle: döndür · tekerlek ya da iki parmak: yakınlaş · oklar: döndür · T: dokular · W: tel kafes · Tab: panel.

## Kod parçası

Her yüzüne ayrı UV verilmiş bir küp: köşeler paylaşılmaz, her dörtgen dışarıdan bakınca CCW sıralanır.

```lua
-- quad(b, bottomLeft, bottomRight, topRight, topLeft, u0, v0, u1, v1)
local function makeCrate(s)
  local b = builder()
  local n, p = -s, s
  quad(b, {n, n, p}, {p, n, p}, {p, p, p}, {n, p, p}, 0, 0, 1, 1)   -- front  (+z)
  quad(b, {p, n, n}, {n, n, n}, {n, p, n}, {p, p, n}, 0, 0, 1, 1)   -- back   (-z)
  -- ... right, left, top, bottom
  return g3d.custom(b.V, b.I, nil, true, b.UV)                     -- flat shading, UVs
end
crate = makeCrate(0.45)
if crate.setTexture then crate:setTexture("bundle:/tex/crate.png") end
```

## Çalıştırma

`source/` klasörünü `3DSceneDemo.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.lua` (366 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`, `tex/*.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/scene3d/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
