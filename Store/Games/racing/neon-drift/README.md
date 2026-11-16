# Neon Drift

A night-city arcade racer for Nexvyn OS. Race through rain-soaked streets on three circuits: the tight downtown
Midnight Grid, the Dockside Run along the harbour and the Neon Expressway with its raised highway and long tunnel. Hold
a drift through the bends to fill the nitro, burn it on the straights and beat up to five rivals.

| Property | Value |
|---|---|
| Id | `com.sonerx7.neondrift` |
| Version | 1.0.0 |
| Runtime | Lua, g3d pbr renderer, `phys` collision |
| Minimum SDK | 1.15 |
| Permissions | none (`[]`) |
| Licence | GPL-3.0-or-later (code); see Assets |

## Controls

| Action | Controller | Keyboard | Touch |
|---|---|---|---|
| Accelerate | ZR | W / Up | automatic |
| Brake, reverse | ZL | S / Down | Brake button |
| Steer | Left stick, D-pad | A D / Left Right | hold the left or right side |
| Drift | R or B (hold while turning) | Space | Drift button |
| Nitro | A | E | Nitro button |
| Camera | Y or X | C | pause menu |
| Pause | + | Esc | pause icon |

## Features

- Three night circuits built at load time from a spline: road, barriers with neon tubes, sidewalks, gantries, a
  tunnel, a raised deck on pillars, container stacks and cranes, kit-bashed city blocks with lit windows and neon signs.
- Arcade car physics with drift (charges the nitro, mini boost on release), nitro, wall and car contacts.
- 3 to 5 rivals with a racing line, braking for corners, overtaking and nitro; Easy, Normal and Hard.
- 2, 3 or 5 laps, countdown lamps, lap and checkpoint rules, wrong-way warning, results, best lap and best race records.
- Wet asphalt reflections, rain, tyre smoke, spray, sparks and nitro flames; HDR bloom.
- Synthwave music with a speed layer, six engine tiers and full sound effects.
- Graphics setting (Quality / Performance), rain, music, sound and vibration switches; 8 languages.

## Assets

- City pieces: the project owner's own kits (`LowPolyCityBuildingsPack_A`, `LowPolyStreetPropsPack_A`,
  `RooftopPropsKit_A`, `ShopFrontsAwningsKit_A`), only the pieces this game uses, reduced (decimated meshes, 512 px
  ETC2 textures). Distributed by the owner's decision for this game only; not a free asset licence.
- Car, textures, sky, signs, music and sound: made for this game by its own scripts (`neondrift_car_blender.py`,
  `neondrift_assets.py`, `neondrift_audio.py`).
- No downloaded assets, no fonts, no network, no tracking.

## Install

Open `neon-drift.nxvapp` in Nexvyn OS Files, or install it from the App Market.
