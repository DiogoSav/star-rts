"""Folha de contato: importa os .glb (filtro opcional) lado a lado e renderiza um PNG.

blender -b --factory-startup --python art_src/blender/preview.py -- models saida.png [filtro]
"""

import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
flt = args[2] if len(args) > 2 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
files = sorted(f for f in os.listdir(src) if f.endswith(".glb") and flt in f)
cols = max(1, math.ceil(math.sqrt(len(files) * 1.6)))
cell = 3.4
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, f))
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    x = (i % cols) * cell
    y = -(i // cols) * cell
    for r in roots:
        r.location += Vector((x, y, 0))
        if f.startswith("hum_") or f.startswith("rob_") or f.startswith("ins_"):
            if "fighter" in f or "gunship" in f:
                r.location.z += 0.4
            r.scale *= 2.0

rows = math.ceil(len(files) / cols)
cx = (cols - 1) * cell / 2
cy = -(rows - 1) * cell / 2
bpy.ops.mesh.primitive_plane_add(size=200, location=(cx, cy, 0))
ground = bpy.context.object
gm = bpy.data.materials.new("ground")
gm.diffuse_color = (0.2, 0.2, 0.22, 1)
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.15, 0.17, 1)
ground.data.materials.append(gm)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(cols, rows * 1.4) * cell * 1.02
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
d = Vector((1.0, -1.6, 1.5)).normalized()
cam.location = Vector((cx, cy, 0)) + d * 60
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 3.5
sun = bpy.data.objects.new("sun", sun_data)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.38, 0.45, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
scene.world = world

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1800
scene.render.resolution_y = int(1800 * rows * 1.4 / max(cols, rows * 1.4) * 0.75) + 200
scene.render.filepath = os.path.abspath(out)
try:
    scene.eevee.use_bloom = True
except Exception:
    pass
bpy.ops.render.render(write_still=True)
print("render ok", out)
