# Task: the store icon (key art)

**English** · [Türkçe](store-icon.tr.md)

Games and apps made with the SDK need an App Market icon that **shows the item itself**: its hero, main object or
world, readable at 64 px. A flat placeholder symbol on a gradient is not accepted. **The style is the maker's
choice.** The assistant asks for it, or follows what the maker said; when nothing is said it makes a **clean**
icon: a polished, attractive picture of the game's own subject, soft light, restrained glow, a calm colour grade, no
text, no frame-breaking. Rules: 256 x 256 PNG (`source/icon.png`), made at 1024 x 1024 and scaled down, filled edge
to edge, the subject inside the central 80 %. Details: `SDK/Guides/MAKE_A_GAME.en.md`, *Store icon and key art*.

## 1. Make it with the icon tool (recommended)

`SDK/Tools/icon` renders the icon from the model your game already loads, in two commands
([README](../../Tools/icon/README.md)):

```sh
blender -b --factory-startup -P SDK/Tools/icon/hero_render.py -- --model models/hero.glb --clip Idle --frame 10 --look ember
python SDK/Tools/icon/finish_icon.py hero.png --look ember --out art/
```

That is the default **clean** style. `--style bold` or `--style loud` (in both scripts) adds contrast, light rays,
sparks and bloom; `--title "NAME"` adds a title logo. Use them only when the maker wants them. Outputs: `icon.png`
(256), `icon_512.png`, `keyart_1024.png` and `preview.png` (the icon at 256 / 128 / 64 px and in grey). Examples,
one of them made from Ember Field's `pip.glb`: `SDK/Tools/icon/examples/`. Ask the assistant for the commands:

```text
Here is my Nexvyn OS game "<NAME>": <one paragraph>. Palette <colours>, mood <words>. Hero model: <file>, clips
<names>, model:info() size <w x h x d>. Icon style I want: <clean (default) / bold / loud / my own words>; title text:
<none / the name>. Using SDK/Tools/icon (hero_render.py options: --model --hero --clip --frame --yaw --camera
low|eye|high --look --style --exposure; finish_icon.py options: --style --title --look --fill --x --y --frame --rays
--sparks --tilt --seed --mask), give me the two commands for a readable icon in that style: the clip and frame with a
good pose, the yaw and camera, the look closest to my palette (and the colour changes to its LOOKS entries so it
matches exactly), the fill and position. Then tell me what to check in preview.png.
```

## 2. Prompt for an image generator

Use a generator whose terms allow you to publish the output, and attach a render or a screenshot of your hero as the
reference image so the icon matches the game. Most generators follow English best. The default (clean):

```text
Square app icon, 1:1, for a game called "<NAME>". Subject: <your hero or main object, from the reference image>,
<a calm, characteristic pose>, centred, three-quarter view, filling most of the frame. Soft key light, a subtle rim
light, a simple softly lit background in <your 2-3 palette colours>, gentle depth. Style: <your art direction, e.g.
stylised low-poly 3D render, painterly, flat-shaded>, clean, polished, appealing, readable at 64 px. No text, no
interface, no border, no watermark.
```

If the maker wants a louder icon, add to it: `dramatic lighting, strong coloured rim light, saturated colours, a burst
of light behind the subject, floating particles, glow` and, for a title, `the name "<NAME>" as a bold logo at the
bottom` (generators often misspell it: adding the title with `finish_icon.py --title` is safer).

## 3. Ask any assistant for a plan

```text
I need the App Market icon for my Nexvyn OS game "<NAME>". It must show the game itself (hero, main object or
world), not a symbol on a gradient: 256 x 256 PNG (made at 1024 x 1024), filled edge to edge, subject inside the
central 80 %, readable at 64 px. Style: <clean, calm and polished (default) / bold / loud / describe it>.

The game: <one paragraph>. Art direction: palette <colours>, mood <words>, camera <style>.
Hero: <describe it, or say "see the attached render / screenshot">. Models I have: <files>. Tools I have: <Blender
and SDK/Tools/icon / an image generator / an image editor / only the game>.

Give me:
1. Three composition ideas in my style (pose, camera angle, light, background), each in two sentences, and say
   which reads best at 64 px.
2. For the best one, exact steps with my tools (SDK/Tools/icon commands, or an in-game key-art mode I can screenshot,
   written only with the Nexvyn OS SDK).
3. The image-generator prompt above, filled in for my game and my style.
4. A short checklist for the result.
```

## Check before you submit

- It is clearly this game (same hero, same colours as the screenshots).
- It is in the style the maker chose (clean when nothing was said).
- It reads at 64 px: one subject, enough value contrast (check the grey version in `preview.png`).
- It is not a flat placeholder glyph on a gradient.
- You own it or may publish it; name the tool or artist in the README.
