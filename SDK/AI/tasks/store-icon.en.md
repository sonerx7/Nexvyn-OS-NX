# Task: the store icon (key art)

**English** · [Türkçe](store-icon.tr.md)

Games and apps made with the SDK need an App Market icon that is **key art of the item itself**: its hero or main
object, its world, its lighting, its name; bold, readable at 64 px and unlike every other icon in the store. A flat
symbol on a gradient is not accepted. Rules: 256 x 256 PNG (`source/icon.png`), made at 1024 x 1024 and scaled down,
filled edge to edge, subject and logo inside the central 80 %. Details: `SDK/Guides/MAKE_A_GAME.en.md`, *Store icon
and key art*.

## 1. Ask the assistant for a plan (any assistant)

```text
I need the App Market icon for my Nexvyn OS game "<NAME>". It must be key art of the game itself, not a symbol on a
gradient: 256 x 256 PNG (I will make it at 1024 x 1024), filled edge to edge, hero and logo inside the central 80 %,
readable at 64 px.

The game: <one paragraph>. Art direction: palette <colours>, mood <words>, typography <style>, camera <style>.
Hero: <describe it, or say "see the attached render / screenshot">. Models I have: <files>. Tools I have: <a 3D tool /
an image generator / an image editor / only the game>.

Give me:
1. Three different composition ideas (hero pose, camera angle, lighting, background, where the name goes), each
   in two sentences, and say which reads best at 64 px.
2. For the best one, exact steps with my tools: either a render from my models (pose frame, camera, key light, rim
   light, background, logo) or an in-game key-art mode I can screenshot (code using only the Nexvyn OS SDK).
3. A prompt for an image generator (below), filled in for my game.
4. A checklist to compare the result with the other icons in the store.
```

## 2. Prompt for an image generator

Use a generator whose terms allow you to publish the output, and attach a render or a screenshot of your hero as the
reference image so the icon matches the game. Most generators follow English best.

```text
Square video game key art, 1:1, for a game called "<NAME>". Subject: <your hero, from the reference image>,
<pose / action>, large in the frame, three-quarter view, seen from slightly below. Setting: <your world in a few
words>. Lighting: <key light colour> key light, strong <contrasting colour> rim light, <time of day>. Palette:
<your 3-4 palette colours>. Style: <your art direction words, e.g. low-poly faceted, painterly, pixel art>.
Bold silhouette, high contrast, readable at small size, subject and logo inside the central 80 %. Title "<NAME>"
in a <your typography> logo at the bottom. No other text, no frame, no watermark.
```

## 3. Render it yourself from the game's models

The sample `SDK/Samples/lua/ember-field` renders its icon with `art/make_keyart.py` (Blender, headless):
`blender -b --factory-startup -P make_keyart.py -- models/pip.glb keyart.png 1024`. Copy it and change the pose,
lights, colours and the name for your game.

## Check before you submit

- It is clearly this game (same hero, same colours as the screenshots).
- It reads at 64 px: one subject, strong contrast, at most one or two words.
- It differs from the other icons in its store category.
- You own it or may publish it; name the tool or artist in the README.
