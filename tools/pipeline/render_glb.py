"""Quick look-dev renders of GLB assets (Cycles CPU) for before/after comparisons.

blender -b -P render_glb.py -- OUT.png SIZE ELEV_DEG YAW_DEG a.glb [b.glb ...]
Each GLB is rendered in its own cell with the same camera framing (scaled to its bounds)
and laid out left-to-right into OUT.png.
"""
import bpy
import math
import os
import sys

import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, SIZE, ELEV, YAW = argv[0], int(argv[1]), float(argv[2]), float(argv[3])
files = argv[4:]
cells = []

for i, f in enumerate(files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.render.resolution_x = SIZE
    sc.render.resolution_y = SIZE
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.5, 0.62, 1)
    bg.inputs[1].default_value = 0.55
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in sc.objects if o.type == "MESH"]
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn[k], w[k]) for k in range(3)))
            mx = Vector((max(mx[k], w[k]) for k in range(3)))
    centre = (mn + mx) / 2
    rad = (mx - mn).length / 2
    # ground
    bpy.ops.mesh.primitive_plane_add(size=rad * 8, location=(centre.x, centre.y, mn.z))
    g = sc.objects[-1] if sc.objects[-1].type == "MESH" else bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.23, 0.3, 0.16, 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    bpy.context.active_object.data.materials.append(gm)
    # sun
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.95, 0.86)
    so = bpy.data.objects.new("sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(42), 0, math.radians(-35))
    # camera
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    e, y = math.radians(ELEV), math.radians(YAW)
    d = rad / math.tan(math.radians(36) / 2) * 1.02
    direction = Vector((math.sin(y) * math.cos(e), -math.cos(y) * math.cos(e), math.sin(e)))
    co.location = centre + direction * d
    co.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    path = OUT + ".cell%d.png" % i
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    cells.append(path)

# stitch
imgs = [bpy.data.images.load(p) for p in cells]
w = sum(im.size[0] for im in imgs)
h = max(im.size[1] for im in imgs)
canvas = np.zeros((h, w, 4), dtype=np.float32)
x = 0
for im in imgs:
    a = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
    canvas[:im.size[1], x:x + im.size[0]] = a
    x += im.size[0]
out = bpy.data.images.new("out", w, h, alpha=True)
out.pixels = canvas.ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
for p in cells:
    os.remove(p)
print("RENDERED", OUT)
