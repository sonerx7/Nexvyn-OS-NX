# Task: the store icon (key art)

**English** · [Türkçe](store-icon.tr.md)

Games and apps made with the SDK need an App Market icon that is **key art of the item itself**, made like the icon
of a best-selling game: an exaggerated, flashy, high-appeal hero (or main object) in dramatic light with a strong rim
light, a saturated palette, depth, glow and particles, a tight crop that may break the frame, the name as a bold
logo; readable at 64 px and unlike every other icon in the store. A flat symbol on a gradient is not accepted.
Rules: 256 x 256 PNG (`source/icon.png`), made at 1024 x 1024 and scaled down, filled edge to edge, subject and logo
inside the central 80 %. Details: `SDK/Guides/MAKE_A_GAME.en.md`, *Store icon and key art*.

## 1. Make it with the icon tool (recommended)

`SDK/Tools/icon` renders the icon from the model your game already loads, in two commands
([README](../../Tools/icon/README.md)):

```sh
blender -b --factory-startup -P SDK/Tools/icon/hero_render.py -- --model models/hero.glb --clip Run --frame 6 --look ember
python SDK/Tools/icon/finish_icon.py hero.png --title "SKY HOP" --look ember --fill 1.0 --out art/
```

`hero_render.py` poses the hero and lights it (key light, two coloured rim lights, a fill) on a transparent
background; `finish_icon.py` adds the background with light rays, a glow behind the hero, an edge rim, sparks, bloom,
a vignette and the title as an outlined, gradient-filled logo, and writes `icon.png` (256), `icon_512.png`,
`keyart_1024.png` and `preview.png` (the icon at 256 / 128 / 64 px and in grey). Examples, one of them made from Ember
Field's `pip.glb`: `SDK/Tools/icon/examples/`. Ask the assistant for the commands with the right options for your
game:

```text
Here is my Nexvyn OS game "<NAME>": <one paragraph>. Palette <colours>, mood <words>. Hero model: <file>, clips
<names>, model:info() size <w x h x d>. Using SDK/Tools/icon (hero_render.py options: --model --hero --clip --frame
--yaw --camera low|eye|high --look --exposure; finish_icon.py options: --title --look --fill --x --y --frame --rays
--sparks --tilt --seed --mask), give me the two commands for the most dramatic, readable icon: the clip and frame
with the strongest pose, the yaw and camera, the look closest to my palette (and the colour changes to its LOOKS
entries so it matches exactly), the fill and position (crop tight, let a part break the frame), a one- or two-word
title. Then tell me what to check in preview.png.
```

## 2. Prompt for an image generator

Use a generator whose terms allow you to publish the output, and attach a render or a screenshot of your hero as the
reference image so the icon matches the game. Most generators follow English best.

```text
Square game store icon, 1:1, key art for a game called "<NAME>". Hero: <your hero, from the reference image>,
<dynamic pose / action>, huge in the frame, tight crop, three-quarter view from slightly below, part of it breaking
out of the frame. Lighting: dramatic <key colour> key light, very strong <contrasting colour> rim light outlining the
silhouette, glowing <accent colour> highlights. Background: <your world in a few words>, a radial burst of light
behind the hero, depth (blurred elements in front and behind), floating <sparks / embers / magic particles>, bloom
and glow. Palette: <3-4 saturated colours of your game>, deep shadows, high contrast. Style: <your art direction,
e.g. stylised low-poly 3D render, painterly, cel-shaded>, polished, premium, exaggerated, eye-catching.
Logo "<NAME>" in bold chunky letters with a thick dark outline, a gradient fill and a glow, at the bottom, slightly
tilted. Readable at 64 px. No other text, no interface, no border, no watermark.
```

Generators often get the logo letters wrong: generate without the logo line if needed and add the title with
`finish_icon.py` (pass the generated picture as the hero only if it has a transparent background) or an image editor.

## 3. Ask any assistant for a plan

```text
I need the App Market icon for my Nexvyn OS game "<NAME>". It must look like the icon of a best-selling game, not a
symbol on a gradient: an exaggerated hero in dramatic light with a strong rim light, saturated colours, depth, glow
and particles, a tight crop, a bold logo. 256 x 256 PNG (made at 1024 x 1024), filled edge to edge, hero and logo
inside the central 80 %, readable at 64 px.

The game: <one paragraph>. Art direction: palette <colours>, mood <words>, typography <style>, camera <style>.
Hero: <describe it, or say "see the attached render / screenshot">. Models I have: <files>. Tools I have: <Blender
and SDK/Tools/icon / an image generator / an image editor / only the game>.

Give me:
1. Three different, bold composition ideas (hero pose, camera angle, lighting colours, background, particles, where
   the name goes), each in two sentences, and say which reads best at 64 px.
2. For the best one, exact steps with my tools (SDK/Tools/icon commands, or an in-game key-art mode I can screenshot,
   written only with the Nexvyn OS SDK).
3. The image-generator prompt above, filled in for my game.
4. A checklist to compare the result with the other icons in the store.
```

## Check before you submit

- It is clearly this game (same hero, same colours as the screenshots).
- It is exaggerated enough: the hero is big and lit dramatically, there is a rim light, glow and depth, the colours
  are saturated; next to other store icons it does not look flat or quiet.
- It reads at 64 px: one subject, strong value contrast (check the grey version in `preview.png`), at most one or two
  words.
- It differs from the other icons in its store category.
- You own it or may publish it; name the tool or artist in the README.
