# What can you build with Lua on Nexvyn OS?

[Türkçe](LUA_CAPABILITIES.tr.md) · **English**

This document explains what kinds of programs and games can realistically be built with Nexvyn OS's Lua app environment (`.nxvapp`), where the limits begin and how those limits could be pushed. For the whole API: [`sdk/SDK.en.md`](../Reference/SDK.en.md).

## Short answer

| What do you want to build? | Does it work? | Note |
|---|---|---|
| Desktop programs: notes, budget, kanban, journal, calculator, dictionary, RSS reader, weather | **Yes, easily** | UI widgets, files, JSON, internet (HTTPS) are ready |
| 2D games: cards, puzzles, platformers, shoot 'em ups, tower defense, top-down racing | **Yes, easily** | 60 FPS, touch + controller + keyboard |
| Simple 3D games: low-poly car racing, flight, maze, Rubik's cube, 3D puzzles | **Yes** | Untextured, colored triangles; a few thousand triangles per scene |
| GTA 1 / GTA 2 style (top-down open city) | **Yes** | Fully possible with 2D drawing |
| GTA 3 / GTA V style (3D open world, textured city, physics) | **No** | Needs textures, a depth buffer and GPU shaders (see below) |
| Full-scale programs (office, IDE, media player) | **Partly** | The UI and logic work in Lua; heavy work (video decoding, large document layout) is done in the built-in C++ apps |

**Proof:** the built-in **Racer** (`romfs/Applications/racer.nxvapp`) is a 3D racing game written entirely in Lua: a hilly track, curbs, trees, 3 AI opponents, lap times, a minimap, touch pedals and gyro steering. About 1,200 lines of Lua.

## What does the Lua environment provide?

- **Drawing (`gfx`)**: rectangles, rounded boxes, circles, lines, polygons, gradients, images (PNG/JPG), text (including Turkish characters), Material icons, clipping.
- **UI (`ui`)**: buttons, text fields (the on-screen keyboard opens automatically), sliders, switches, lists, scroll areas, menus. The system look, compatible with the light/dark theme.
- **Input**: touch, controller (buttons, analog sticks, gyro/accelerometer `input.motion()`), USB keyboard/mouse. D-pad navigation between buttons is done automatically by the system.
- **3D (`g3d`)**: cube, sphere, cylinder, cone, torus, plane; loading `.obj` / `.stl` models; your own triangles; lighting, fog, wireframe, camera, 3D→2D projection.
- **Files and data**: an app-specific folder, `store` (settings saved automatically), JSON, user folders (Documents, Pictures…).
- **Internet (`net`)**: HTTPS GET/POST, JSON, file downloads (with progress).
- **Sound**: synthesized tones (sine, square, saw, triangle, noise), WAV/OGG/MP3 effects, music streaming, vibration (HD Rumble).
- **System**: notifications, clipboard, time/date, battery, language, opening other apps, timers, `coroutine`.
- **Multiple languages**: `lang/tr.json`, `lang/en.json` + `TR("key")`.

## Limits (why not GTA 3?)

1. **Lua is an interpreted language.** Game logic runs on a single core. For the Switch's CPU (4× Cortex-A57, ~1 GHz) that means updating thousands of objects per frame, not tens of thousands.
2. **Every call may take at most 3 seconds.** Long jobs (AI search, puzzle generation) must be split across frames or done piece by piece with `coroutine`. The chess engine works this way.
3. **`g3d` has no textures and no depth buffer.** Triangles are colored and lit, but no picture (texture) can be put on them. Visibility is solved by sorting triangles from far to near (painter's algorithm); errors can show up on large intersecting surfaces. Transformation and lighting are computed on the CPU, drawing is done on the GPU.
4. **Triangle budget**: according to the SDK, a few thousand triangles per frame are drawn at 60 FPS. Measure the figure on real hardware with the system's **Benchmark** app; the result in the emulator may differ.
5. **Native (C/C++) libraries cannot be loaded**, threads cannot be created, and network sockets cannot be reached directly (HTTP/HTTPS only). This is a deliberate choice for security: a `.nxvapp` downloaded from elsewhere cannot break the system.

A GTA 3 style game needs textured buildings, hundreds of thousands of triangles, a depth buffer, shadows, vehicle and character physics, and streaming the world in pieces. None of these exist in the current Lua 3D layer.

## Example 1: a simple 3D car (the camera follows the car)

```lua
local app = {}
local car, wheel, ground
local x, z, yaw, speed = 0, 0, 0, 0

function app.load()
  car = g3d.mesh("box", 1.6, 0.5, 3.2); car:setColor("#E53935")
  wheel = g3d.mesh("cylinder", 0.35, 0.3, 12); wheel:setColor("#222222")
  ground = g3d.mesh("plane", 400, 400, 20); ground:setColor("#3C8D40")
end

function app.update(dt)
  local lx = input.stick("left")                -- left stick: steering
  local gas = input.down("zr") and 1 or 0       -- ZR: throttle, ZL: brake
  local brake = input.down("zl") and 1 or 0
  speed = speed + (gas * 18 - brake * 30 - speed * 0.6) * dt
  speed = math.max(-5, math.min(speed, 40))
  yaw = yaw - lx * dt * 1.8 * math.min(1, math.abs(speed) / 8)
  x = x - math.sin(yaw) * speed * dt
  z = z - math.cos(yaw) * speed * dt
end

function app.draw(w, h)
  gfx.clear("#8EC5FF")
  g3d.begin(0, 0, w, h, 60)
  -- camera: 8 m behind the car, 3 m up
  g3d.camera(x + math.sin(yaw) * 8, 3, z + math.cos(yaw) * 8, x, 0.5, z)
  g3d.light(0.4, 1, 0.2, 0.4)
  g3d.fog("#8EC5FF", 60, 180)
  g3d.draw(ground, 0, 0, 0)
  g3d.draw(car, x, 0.6, z, 0, yaw, 0)
  for _, o in ipairs({{-0.8, 1.1}, {0.8, 1.1}, {-0.8, -1.1}, {0.8, -1.1}}) do
    local wx = x + math.cos(yaw) * o[1] + math.sin(yaw) * o[2]
    local wz = z - math.sin(yaw) * o[1] + math.cos(yaw) * o[2]
    g3d.draw(wheel, wx, 0.35, wz, 0, yaw, math.pi / 2)
  end
  g3d.finish()
  gfx.color("#FFFFFF")
  gfx.text(string.format("%d km/sa", math.floor(math.abs(speed) * 3.6)), 20, 20, 24, "bold")
end

return app
```

From here on: a track (plane strips laid out along a curve), collision (distance to the road's center line), opponents (cars that follow the same curve), a lap counter. The Racer app does exactly these things.

## Example 2: a GTA 1 / GTA 2 style city (top-down)

The first two GTA games were top-down; this style is easy to do on Nexvyn OS with 2D drawing:

- **Map**: a grid (e.g. 200×200 cells), each cell road / building / grass / water. Only the cells on screen are drawn, so the speed stays the same however large the map is.
- **Car physics**: speed, heading, friction, reduced side slip for drifting (the 2D version of the 3D example above).
- **Pedestrians and traffic**: simple "agents" moving along the roads; those off screen are updated less often.
- **Missions**: spots where the phone rings, driving a car from one place to another, a time limit; saving with `store`.
- **Wanted level**, radio (synthesized sounds or `audio.music`), a minimap (a scaled-down drawing with `gfx`).

To show buildings in "fake 3D", drawing each building's roof slightly shifted by its distance from the camera (as in GTA 2) works well. If you like, building blocks can also be drawn with `g3d` boxes: a few hundred boxes are no problem.

## Example 3: a full-scale program

The built-in **Kanban**, **Budget**, **Journal** and **Flashcards** apps were written in Lua. The parts of a typical program:

```lua
local app = {}
local items, kurlar = {}, nil

function app.load()
  items = store.get("items", {})                -- persistent data
  net.json("https://api.example.com/kurlar", function(data, err)
    if data then kurlar = data end              -- data from the internet
  end)
end

function app.draw(w, h)
  ui.label(TR("baslik"), 20, 16, 20)
  local y = 60
  for i, it in ipairs(items) do
    if ui.button(it.ad .. "##" .. i, 20, y, w - 40, 36) then sys.open(it.dosya) end
    y = y + 44
  end
end

function app.menu()                              -- menu bar
  return { { title = TR("dosya"), items = { {label = TR("disa_aktar"), id = 1, shortcut = "Ctrl+E"} } } }
end
function app.onmenu(id)
  if id == 1 then
    fs.write(fs.dir("documents") .. "/liste.json", json.encode(items, true))
    sys.notify(TR("bitti"), TR("kaydedildi"))
  end
end

return app
```

Things that are easy in Lua: forms, lists, charts (bar/pie drawn with `gfx`), tools that fetch data from the internet, gamified apps, educational programs (like the periodic table or the graph plotter). Heavy work (video decoding, large text layout, rendering web pages) is done in the system's built-in C++ apps (Video Player, Browser, Word Processor).

## How do you write one?

- **On the console**: the **Nexvyn OS Studio** app (Developer category). Templates (Empty, Utility, 2D Game, 3D Scene, Network and JSON), live error checking, autocompletion, Run + console, packaging.
- **On a computer**: create a folder (`benim-oyunum.nxvapp/` with `app.json`, `main.lua`, `icon.png`, `lang/` inside), copy it to `sdmc:/NexvynOS/Applications/` on the SD card; the app appears in the Launcher. To have an AI write it, giving it the `sdk/SDK.en.md` file is enough.

## Can the limits be pushed?

Yes, but it needs work on the system side (C++):

| Improvement | What it brings |
|---|---|
| GPU-based drawing + a depth buffer for `g3d` | No more intersection errors, 10× more triangles |
| Textured models (`.obj` + `.png`) | Realistic cars/buildings, a PS1–PS2 era look |
| Built-in physics (collision boxes, vehicle physics) | Solid collision without writing it in Lua |
| Scene partitioning (not drawing invisible areas) | Larger 3D worlds |

Even with these added, the target is not "GTA 3" but at most a 3D city game at **PS1/early PS2 level** (e.g. a simple Crazy Taxi, something like Driver 1). Going further would need the game to be written directly in C++ with an engine that uses the Switch's GPU (e.g. deko3d/OpenGL); that would no longer be a Nexvyn OS app but a separate homebrew game.
