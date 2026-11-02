"""Blender (headless): the store icon of the "Ember Field" sample, rendered from the game's own model.
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P art/make_keyart.py -- source/models/pip.glb keyart.png [size]
Key art, not a glyph: the hero big and low in the frame, a warm rim light against a dusk sky, an ember, the game's
name. Renders a square PNG (default 1024 px; scale it down to 256 x 256 for icon.png with a good filter).
The recipe for your own icon: import your .glb, pose it (pick a frame of a clip), light it like your game, frame it
tight (the hero fills about two thirds of the square), keep the logo and the face inside the central 80 %."""
import bpy, math, sys

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
SIZE = int(args[2]) if len(args) > 2 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

bpy.ops.import_scene.gltf(filepath=SRC)
for o in bpy.context.scene.objects:                      # pose: a frame of the "Run" clip reads as motion
    if o.type == "ARMATURE" and o.animation_data:
        act = bpy.data.actions.get("Run")
        if act:
            o.animation_data.action = act
        o.rotation_euler[2] = math.radians(-25)     # three-quarter view: more depth than straight on
scene.frame_set(5)


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = color
    p.inputs["Emission Color"].default_value = color
    p.inputs["Emission Strength"].default_value = strength
    return m


# ground: a dark mound the hero stands on
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=3, location=(0, 0, -2.85))
mound = bpy.context.active_object
mound.data.materials.append(emissive("Mound", (0.03, 0.07, 0.08, 1), 0.0))
# embers floating around
for i, (x, z, r) in enumerate(((0.75, 1.35, 0.09), (-0.8, 0.55, 0.06), (0.55, 0.25, 0.05))):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=r, location=(x, -0.3, z))
    bpy.context.active_object.data.materials.append(emissive("Ember%d" % i, (1.0, 0.45, 0.1, 1), 4.0))
# the name, big and bold, in front of the feet
bpy.ops.object.text_add(location=(0, -0.9, 0.02), rotation=(math.radians(90), 0, 0))
title = bpy.context.active_object
title.data.body = "EMBER"
title.data.align_x = "CENTER"
title.data.size = 0.34
title.data.extrude = 0.06
title.data.materials.append(emissive("Title", (1.0, 0.93, 0.82, 1), 1.5))

# sky: a dusk gradient on a backdrop behind the hero (bottom warm, top deep violet), a dim world for fill light
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 4, 1.5), rotation=(math.radians(90), 0, 0))
sky = bpy.context.active_object
m = bpy.data.materials.new("Sky")
m.use_nodes = True
nt = m.node_tree
out = nt.nodes["Material Output"]
emit = nt.nodes.new("ShaderNodeEmission")
ramp = nt.nodes.new("ShaderNodeValToRGB")
coord = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp.color_ramp.elements[0].position = 0.35
ramp.color_ramp.elements[0].color = (0.9, 0.32, 0.16, 1)
ramp.color_ramp.elements[1].position = 0.75
ramp.color_ramp.elements[1].color = (0.05, 0.03, 0.12, 1)
nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
sky.data.materials.append(m)
world = bpy.data.worlds.new("Dusk")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.04, 0.1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4

# lights: a warm key from the front-left, a strong cool rim from behind
bpy.ops.object.light_add(type="AREA", location=(-2.2, -2.6, 2.4))
key = bpy.context.active_object
key.data.energy, key.data.size, key.data.color = 320, 2.0, (1.0, 0.78, 0.6)
key.rotation_euler = (math.radians(55), 0, math.radians(-40))
bpy.ops.object.light_add(type="AREA", location=(1.6, 2.4, 2.2))
rim = bpy.context.active_object
rim.data.energy, rim.data.size, rim.data.color = 520, 1.2, (0.55, 0.75, 1.0)
rim.rotation_euler = (math.radians(-55), 0, math.radians(150))

# camera: low and close, slightly from below, the hero fills the frame
bpy.ops.object.camera_add(location=(0, -3.0, 0.85), rotation=(math.radians(84), 0, 0))
cam = bpy.context.active_object
cam.data.lens = 50
scene.camera = cam

for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
if scene.render.engine == "CYCLES":
    scene.cycles.samples = 64
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"     # punchy colours; a filmic transform washes them out
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("keyart ok", scene.render.engine, OUT)
