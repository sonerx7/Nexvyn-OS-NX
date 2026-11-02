"""Blender (headless): the two models of the "Ember Field" sample game (Studio template ember3d, SDK/Samples/lua/ember-field).
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P art/make_models.py -- source/models
Writes:
  pip.glb   the hero, a round courier bird about 1.2 m tall with its feet at the origin, facing -Y in Blender (+Z in
            glTF, towards the default g3d camera). One mesh of rigid parts, each weighted 1.0 to one bone of a 7-bone
            armature (Root, Body, Head, Lamp, Leg.L, Leg.R, Wing.L, Wing.R); "Lamp" has no vertices and is the
            attachment point at the tip of the antenna. Clips "Idle" and "Run" (loops) and "Hop" (one shot).
            Flat colours plus an emissive antenna tip and eyes, no textures, so the file stays a few KB.
  rock.glb  a flat-shaded boulder (a displaced ico sphere, 1 m wide).
The script is the recipe for your own models: build at real size in metres, feet on the ground, name the bones and
the actions, export glTF binary with +Y up (the exporter's default) and the animations as separate actions."""
import bpy, math, os, random, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, emission=None, strength=2.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = color
    p.inputs["Roughness"].default_value = 0.6
    if emission:
        p.inputs["Emission Color"].default_value = emission
        p.inputs["Emission Strength"].default_value = strength
    return m


def part(kind, name, loc, scale, m, bone, rot=(0, 0, 0), seg=16):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=0.5, depth=1, location=loc, rotation=rot)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=0.5, depth=1, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=0.5, location=loc,
                                             rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(m)
    o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    return o


def export(path, objects, animations):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_animations=animations, export_animation_mode="ACTIONS",
                              export_texcoords=False)


# ------------------------------------------------------------------ pip.glb
reset()
plume = mat("Plume", (0.93, 0.42, 0.22, 1))        # warm orange body
cream = mat("Belly", (0.98, 0.9, 0.74, 1))
ink = mat("Ink", (0.08, 0.09, 0.14, 1))
leather = mat("Satchel", (0.36, 0.2, 0.12, 1))
lamp = mat("Lamp", (1.0, 0.75, 0.3, 1), emission=(1.0, 0.7, 0.25, 1), strength=4.0)
eye = mat("Eye", (0.6, 0.95, 1.0, 1), emission=(0.5, 0.9, 1.0, 1))
parts = [
    part("sph", "body", (0, 0, 0.62), (0.62, 0.56, 0.58), plume, "Body", seg=14),
    part("sph", "belly", (0, -0.16, 0.58), (0.44, 0.3, 0.42), cream, "Body", seg=12),
    part("box", "satchel", (0.3, 0.1, 0.52), (0.12, 0.3, 0.24), leather, "Body"),
    part("sph", "head", (0, -0.05, 1.0), (0.4, 0.38, 0.38), plume, "Head", seg=14),
    part("cone", "beak", (0, -0.3, 0.98), (0.14, 0.14, 0.2), ink, "Head", rot=(math.pi / 2, 0, 0), seg=8),
    part("sph", "eye.L", (-0.11, -0.2, 1.06), (0.08, 0.05, 0.1), eye, "Head", seg=8),
    part("sph", "eye.R", (0.11, -0.2, 1.06), (0.08, 0.05, 0.1), eye, "Head", seg=8),
    part("cyl", "antenna", (0, 0.02, 1.27), (0.03, 0.03, 0.22), ink, "Head", seg=6),
    part("sph", "lamp", (0, 0.02, 1.4), (0.11, 0.11, 0.11), lamp, "Head", seg=10),
]
for side, sx in (("L", -1), ("R", 1)):
    parts += [
        part("cyl", "leg." + side, (sx * 0.16, 0, 0.18), (0.06, 0.06, 0.3), ink, "Leg." + side, seg=6),
        part("box", "foot." + side, (sx * 0.16, -0.06, 0.03), (0.14, 0.22, 0.06), ink, "Leg." + side),
        part("sph", "wing." + side, (sx * 0.34, 0.04, 0.66), (0.12, 0.34, 0.3), plume, "Wing." + side, seg=8),
    ]
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
pip = bpy.context.active_object
pip.name = "Pip"

bpy.ops.object.armature_add(location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "PipRig"
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
eb.remove(eb[0])


def bone(name, head, tail, parent=None):
    b = eb.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent:
        b.parent = eb[parent]


bone("Root", (0, 0, 0.3), (0, 0, 0.45))
bone("Body", (0, 0, 0.45), (0, 0, 0.8), "Root")
bone("Head", (0, 0, 0.8), (0, 0, 1.2), "Body")
bone("Lamp", (0, 0.02, 1.4), (0, 0.02, 1.5), "Head")
for side, sx in (("L", -1), ("R", 1)):
    bone("Leg." + side, (sx * 0.16, 0, 0.34), (sx * 0.16, 0, 0.02), "Root")
    bone("Wing." + side, (sx * 0.24, 0, 0.8), (sx * 0.44, 0, 0.6), "Body")
bpy.ops.object.mode_set(mode="OBJECT")
pip.parent = arm
pip.modifiers.new("Armature", "ARMATURE").object = arm

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "XYZ"


def key(f, name, rx=0.0, ry=0.0, rz=0.0, up=None):
    b = pb[name]
    b.rotation_euler = (rx, ry, rz)
    b.keyframe_insert("rotation_euler", frame=f)
    if up is not None:  # vertical bones: local Y is world up
        b.location = (0, up, 0)
        b.keyframe_insert("location", frame=f)


def action(name):
    arm.animation_data_create()
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    arm.animation_data.action = a
    return a


ALL = ("Root", "Body", "Head", "Leg.L", "Leg.R", "Wing.L", "Wing.R")
idle = action("Idle")
for i, f in enumerate((1, 25, 49)):
    c = 1 if i == 1 else 0
    for n in ALL:
        key(f, n)
    key(f, "Body", rx=0.04 * c, up=-0.02 * c)
    key(f, "Head", rz=0.18 * c, rx=-0.06 * c)
    key(f, "Wing.L", ry=0.12 * c)
    key(f, "Wing.R", ry=-0.12 * c)
run = action("Run")
for i, f in enumerate((1, 5, 9, 13, 17)):
    s = math.sin(i * math.pi / 2)
    b = abs(math.cos(i * math.pi / 2))
    key(f, "Leg.L", rx=0.75 * s)
    key(f, "Leg.R", rx=-0.75 * s)
    key(f, "Root", up=0.06 * b)
    key(f, "Body", rx=0.22, rz=0.05 * s)
    key(f, "Head", rx=-0.18, rz=-0.05 * s)
    key(f, "Wing.L", ry=0.5 + 0.3 * b)
    key(f, "Wing.R", ry=-0.5 - 0.3 * b)
hop = action("Hop")
for f, lift, tuck, flap in ((1, 0.0, 0.0, 0.2), (4, 0.05, 0.6, 1.2), (8, 0.35, 0.9, 0.3), (12, 0.1, 0.4, 1.0),
                            (15, 0.0, 0.0, 0.2)):
    key(f, "Root", up=lift)
    key(f, "Leg.L", rx=-tuck)
    key(f, "Leg.R", rx=-tuck)
    key(f, "Body", rx=-0.1 * tuck)
    key(f, "Head", rx=0.1 * tuck)
    key(f, "Wing.L", ry=flap)
    key(f, "Wing.R", ry=-flap)
bpy.ops.object.mode_set(mode="OBJECT")
arm.animation_data.action = idle
scene = bpy.context.scene
scene.render.fps = 24
scene.frame_set(1)
print("pip tris", sum(len(p.vertices) - 2 for p in pip.data.polygons))
export(os.path.join(OUT, "pip.glb"), [pip, arm], True)

# ------------------------------------------------------------------ rock.glb
reset()
random.seed(7)
stone = mat("Stone", (0.42, 0.4, 0.5, 1))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0, 0, 0.36))
rock = bpy.context.active_object
rock.name = "Rock"
for v in rock.data.vertices:
    v.co *= 0.82 + random.random() * 0.3
    v.co.z *= 0.75
rock.data.materials.append(stone)
for p in rock.data.polygons:
    p.use_smooth = False
print("rock tris", len(rock.data.polygons))
export(os.path.join(OUT, "rock.glb"), [rock], False)
print("ember models ok")
