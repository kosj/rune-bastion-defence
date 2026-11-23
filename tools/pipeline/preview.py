import bpy, sys, math, os
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
out = argv[0]; files = [a for a in argv[1:] if not a.startswith('--')]
bpy.ops.wm.read_factory_settings(use_empty=True)
x = 0.0
for f in files:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    # bounds
    mins = Vector((1e9,)*3); maxs = Vector((-1e9,)*3)
    for o in new:
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mins = Vector(map(min, mins, w)); maxs = Vector(map(max, maxs, w))
    size = maxs - mins
    print(os.path.basename(f), "size", tuple(round(v,3) for v in size), "min", tuple(round(v,3) for v in mins))
    s = 2.0 / max(size.z, 0.001) if '--norm' not in argv else 1
    for r in roots:
        r.scale = (s, s, s)
        r.location = (x - (mins.x+maxs.x)/2*s, -(mins.y+maxs.y)/2*s, -mins.z*s)
    x += max(size.x, size.y) * s + 0.4
scn = bpy.context.scene
scn.render.engine = 'CYCLES'; scn.cycles.samples = 24; scn.cycles.device='CPU'
scn.render.resolution_x = 1600; scn.render.resolution_y = 500
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scn.collection.objects.link(cam); scn.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(x, 6.5)
cam.location = (x/2 - 0.2, -10, 1.2 + 1.5); cam.rotation_euler = (math.radians(82), 0, 0)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30)); scn.collection.objects.link(sun)
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55,0.6,0.7,1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scn.render.filepath = out
bpy.ops.render.render(write_still=True)
