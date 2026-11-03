"""Blender (headless): renders the hero of a store icon from your game's own model, with a dramatic lighting rig, on a
transparent background. The second step, finish_icon.py, builds the key art around it (background, rim glow, bloom,
particles, title, sizes).

    blender -b --factory-startup -P hero_render.py -- --model models/hero.glb --out hero.png
    blender -b --factory-startup -P hero_render.py -- --model models/hero.glb --clip Run --frame 6 --yaw -30 --look ember
    blender -b --factory-startup -P hero_render.py -- --hero crystal --look frost --out hero.png     (no model: a built-in object)

Options:
  --model PATH      .glb / .gltf / .fbx / .obj of the hero (the same file the game loads)
  --hero NAME       a built-in hero instead of a model: crystal, rocket, orb
  --clip NAME       animation clip to pose the hero with (an action pose reads better than the rest pose)
  --frame N         frame of the clip (default 5)
  --yaw DEG         turn the hero (default -28: three-quarter view, more depth than straight on)
  --camera KIND     low (default: slightly from below, heroic), eye, high
  --look NAME       lighting colours: ember, frost, toxic, synth, gold, royal, jungle, noir (as in finish_icon.py)
  --size PX         square render size (default 1024)
  --samples N       render samples (default 64)
  --exposure EV     brighter (> 0) or darker (< 0) render (default 0)
  --out PATH        output PNG with alpha (default hero.png)

The rig: a key light from the front left, two strong rim lights from behind in contrasting colours (the outline that
makes a silhouette pop at 64 px), a weak fill from below in the complementary colour, a dark world. The camera frames
the hero to fill the square; finish_icon.py crops and places it again. Tested with Blender 4.4 and 5.2 (EEVEE)."""
import math
import os
import sys

import bpy
from mathutils import Vector

LOOKS = {   # key, rim 1, rim 2, fill (RGB 0..1)
    "ember": ((1.0, 0.72, 0.48), (1.0, 0.45, 0.12), (0.35, 0.65, 1.0), (0.45, 0.2, 0.6)),
    "frost": ((0.85, 0.93, 1.0), (0.3, 0.95, 1.0), (1.0, 0.45, 0.75), (0.15, 0.3, 0.7)),
    "toxic": ((0.85, 1.0, 0.7), (0.55, 1.0, 0.2), (1.0, 0.25, 0.85), (0.1, 0.35, 0.2)),
    "synth": ((1.0, 0.8, 0.95), (1.0, 0.2, 0.6), (0.1, 0.9, 1.0), (0.35, 0.1, 0.6)),
    "gold": ((1.0, 0.86, 0.6), (1.0, 0.75, 0.25), (0.55, 0.4, 1.0), (0.5, 0.25, 0.1)),
    "royal": ((0.9, 0.85, 1.0), (0.6, 0.4, 1.0), (1.0, 0.75, 0.3), (0.15, 0.1, 0.45)),
    "jungle": ((1.0, 0.92, 0.7), (1.0, 0.7, 0.2), (0.3, 1.0, 0.6), (0.1, 0.35, 0.2)),
    "noir": ((1.0, 1.0, 1.0), (1.0, 0.2, 0.25), (0.8, 0.85, 1.0), (0.1, 0.1, 0.12)),
}


def parse_args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"model": "", "hero": "", "clip": "", "frame": 5, "yaw": -28.0, "camera": "low", "look": "ember",
         "size": 1024, "samples": 64, "exposure": 0.0, "out": "hero.png"}
    i = 0
    while i < len(a):
        k = a[i].lstrip("-")
        if k not in o or i + 1 >= len(a):
            sys.exit("hero_render.py: unknown option or missing value: " + a[i])
        o[k] = type(o[k])(a[i + 1])
        i += 2
    if not o["model"] and not o["hero"]:
        sys.exit("hero_render.py: give --model PATH or --hero crystal|rocket|orb")
    return o


def material(name, color, emit=0.0, metal=0.0, rough=0.4):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit > 0:
        p.inputs["Emission Color"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emit
    return m


def add(obj, mat):
    obj.data.materials.append(mat)
    return obj


def builtin(name):
    """A simple hero for apps without a model: faceted, readable, with an emissive accent."""
    ops = bpy.ops.mesh
    if name == "crystal":
        ops.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(0, 0, 1.3))
        c = bpy.context.active_object
        c.scale = (0.62, 0.62, 1.35)
        add(c, material("Crystal", (0.08, 0.5, 0.95), emit=0.12, rough=0.12))
        for i, (x, s) in enumerate(((-0.75, 0.55), (0.72, 0.45))):
            ops.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x, 0.15, s * 1.05))
            b = bpy.context.active_object
            b.scale = (s * 0.5, s * 0.5, s * 1.1)
            b.rotation_euler = (0, math.radians(18 if x < 0 else -16), 0)
            add(b, material("Shard%d" % i, (0.35, 0.15, 0.9), emit=0.1, rough=0.15))
        ops.primitive_cylinder_add(vertices=8, radius=1.0, depth=0.25, location=(0, 0, 0.12))
        add(bpy.context.active_object, material("Rock", (0.08, 0.09, 0.14), rough=0.8))
    elif name == "rocket":
        parts = []
        ops.primitive_cylinder_add(vertices=16, radius=0.45, depth=1.6, location=(0, 0, 1.2))
        parts.append(add(bpy.context.active_object, material("Hull", (0.55, 0.56, 0.62), metal=0.4, rough=0.3)))
        ops.primitive_cone_add(vertices=16, radius1=0.45, depth=0.8, location=(0, 0, 2.4))
        parts.append(add(bpy.context.active_object, material("Nose", (0.9, 0.08, 0.2), rough=0.3)))
        ops.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.2, location=(0, -0.4, 1.55))
        parts.append(add(bpy.context.active_object, material("Window", (0.3, 0.9, 1.0), emit=3.0)))
        for i in range(3):
            a = i * 2 * math.pi / 3
            ops.primitive_cube_add(size=1, location=(math.sin(a) * 0.55, math.cos(a) * 0.55, 0.55))
            fin = bpy.context.active_object
            fin.scale = (0.06, 0.35, 0.45)
            fin.rotation_euler = (0, 0, -a)
            parts.append(add(fin, material("Fin%d" % i, (0.9, 0.08, 0.2), rough=0.3)))
        ops.primitive_cone_add(vertices=16, radius1=0.32, radius2=0.05, depth=0.9, location=(0, 0, -0.05),
                               rotation=(math.pi, 0, 0))
        parts.append(add(bpy.context.active_object, material("Flame", (1.0, 0.55, 0.1), emit=8.0)))
        bpy.ops.object.empty_add(location=(0, 0, 1.0))
        pivot = bpy.context.active_object
        for p in parts:
            p.parent = pivot
            p.matrix_parent_inverse = pivot.matrix_world.inverted()
        pivot.rotation_euler = (0, math.radians(-40), 0)
    else:  # orb
        ops.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.9, location=(0, 0, 1.1))
        bpy.ops.object.shade_smooth()
        add(bpy.context.active_object, material("Orb", (0.7, 0.1, 0.22), emit=0.12, rough=0.2))
        ops.primitive_torus_add(major_radius=1.35, minor_radius=0.07, location=(0, 0, 1.1),
                                rotation=(math.radians(72), math.radians(18), 0))
        add(bpy.context.active_object, material("Ring", (1.0, 0.85, 0.35), emit=2.5))


def main():
    o = parse_args()
    look = LOOKS.get(o["look"], LOOKS["ember"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    if o["model"]:
        path = os.path.abspath(o["model"])
        ext = os.path.splitext(path)[1].lower()
        if ext in (".glb", ".gltf"):
            bpy.ops.import_scene.gltf(filepath=path)
        elif ext == ".fbx":
            bpy.ops.import_scene.fbx(filepath=path)
        elif ext == ".obj":
            bpy.ops.wm.obj_import(filepath=path)
        else:
            sys.exit("hero_render.py: unsupported model type " + ext)
        if o["clip"]:
            want = o["clip"].lower()
            act = bpy.data.actions.get(o["clip"]) or next(
                (a for a in bpy.data.actions if a.name.lower() == want or a.name.lower().endswith("|" + want)), None)
            if not act:
                print("hero_render: no clip named", o["clip"], "- rest pose")
            for ob in scene.objects:
                if ob.type == "ARMATURE" and act:
                    if not ob.animation_data:
                        ob.animation_data_create()
                    ob.animation_data.action = act
        scene.frame_set(int(o["frame"]))
    else:
        builtin(o["hero"])

    # turn everything on a pivot (a clip may key the rig's own rotation, which would undo a turn of the rig itself)
    roots = [ob for ob in scene.objects if ob.parent is None]
    bpy.ops.object.empty_add(location=(0, 0, 0))
    pivot = bpy.context.active_object
    for ob in roots:
        ob.parent = pivot
    pivot.rotation_euler[2] = math.radians(o["yaw"])
    scene.frame_set(scene.frame_current)
    bpy.context.view_layer.update()

    # bounds of every mesh in the posed state
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for ob in scene.objects:
        if ob.type != "MESH" or not ob.visible_get() or ob.hide_render:
            continue   # e.g. the bone shapes the glTF importer keeps in a hidden collection
        ev = ob.evaluated_get(dg)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            p = ev.matrix_world @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
        ev.to_mesh_clear()
    if lo.x > hi.x:
        sys.exit("hero_render.py: the scene has no meshes")
    centre = (lo + hi) / 2
    S = max(hi.x - lo.x, hi.z - lo.z, (hi.y - lo.y) * 0.6)

    def area(loc, color, energy, size):
        bpy.ops.object.light_add(type="AREA", location=centre + Vector(loc) * S)
        li = bpy.context.active_object
        li.data.energy = energy * S * S
        li.data.size = size * S
        li.data.color = color
        li.rotation_euler = (centre - li.location).to_track_quat("-Z", "Y").to_euler()

    area((-1.1, -1.4, 0.9), look[0], 50, 0.9)     # key: front left, above
    area((1.0, 1.0, 0.7), look[1], 260, 0.4)      # rim 1: behind right
    area((-1.1, 0.9, 0.1), look[2], 200, 0.4)     # rim 2: behind left, lower
    area((0.4, -1.3, -0.9), look[3], 25, 1.2)     # fill: front, from below
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (look[3][0] * 0.25, look[3][1] * 0.25, look[3][2] * 0.25, 1)
    bg.inputs["Strength"].default_value = 0.35

    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.lens = 50
    fov = 2 * math.atan(18 / 50)
    dist = (S / 2) / math.tan(fov / 2) * 1.1
    tilt = {"low": -0.18, "eye": 0.0, "high": 0.35}.get(o["camera"], -0.18)
    cam.location = centre + Vector((0, -dist, tilt * dist))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = int(o["samples"])
    elif hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = int(o["samples"])
    scene.render.resolution_x = scene.render.resolution_y = int(o["size"])
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"      # punchy colours; finish_icon.py grades the rest
    scene.view_settings.exposure = float(o["exposure"])
    try:
        scene.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = os.path.abspath(o["out"])
    bpy.ops.render.render(write_still=True)
    print("hero_render ok", scene.render.engine, scene.render.filepath)


main()
