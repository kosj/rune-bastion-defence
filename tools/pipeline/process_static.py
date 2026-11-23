"""Normalise VARCO static GLBs: scale to target footprint/height, pivot at bottom centre, downsize textures,
measure the top platform height (for tower units) and write tower_meta.json.
blender -b -P process_static.py -- IN_DIR OUT_DIR META_JSON name:mode:size[:albedo_px] ..."""
import bpy, sys, os, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, META = argv[0], argv[1], argv[2]
specs = argv[3:]
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(META)) if os.path.exists(META) else {}


def bounds(objs):
    import numpy as np
    pts = []
    for o in objs:
        co = np.zeros(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", co)
        pts.append(co.reshape(-1, 3))
    a = np.concatenate(pts)
    return Vector(a.min(0)), Vector(a.max(0))


for spec in specs:
    parts = spec.split(":")
    name, mode, size = parts[0], parts[1], float(parts[2])
    albedo_px = int(parts[3]) if len(parts) > 3 else 1024
    max_faces = int(parts[4]) if len(parts) > 4 else 0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(IN, name + ".glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    # flatten hierarchy, apply transforms
    for o in bpy.data.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.active_object
    if max_faces and len(body.data.polygons) > max_faces:
        mod = body.modifiers.new("dec", "DECIMATE")
        mod.ratio = max_faces / len(body.data.polygons)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
    body.name = "Body"
    body.data.name = "Body"
    mn, mx = bounds([body])
    ext = mx - mn
    if mode == "foot":      # scale so the larger horizontal extent == size
        s = size / max(ext.x, ext.y)
    elif mode == "tower":   # footprint == size, but never taller than 1.55 x size
        s = min(size / max(ext.x, ext.y), size * 1.55 / ext.z)
    elif mode == "height":  # scale so height == size
        s = size / ext.z
    else:
        s = size
    # pivot: bottom centre
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    for v in body.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - mn.z) * s))
    body.data.update()
    mn2, mx2 = bounds([body])
    # top platform height: cast rays down near the centre, take the median hit
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hits = []
    for dx, dy in ((0, 0), (0.25, 0), (-0.25, 0), (0, 0.25), (0, -0.25), (0.15, 0.15), (-0.15, -0.15)):
        ok, loc, nrm, idx = body.ray_cast(Vector((dx, dy, mx2.z + 5)), Vector((0, 0, -1)))
        if ok:
            hits.append(loc.z)
    hits.sort()
    top = hits[len(hits) // 2] if hits else mx2.z
    meta[name] = {"top": round(top, 3), "height": round(mx2.z, 3), "width": round(max(mx2.x - mn2.x, mx2.y - mn2.y), 3),
                  "depth_front": round(mx2.y, 3)}
    # textures: albedo at albedo_px, others at half
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        is_base = False
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf and bsdf.inputs["Base Color"].is_linked:
                n = bsdf.inputs["Base Color"].links[0].from_node
                if getattr(n, "image", None) == img:
                    is_base = True
        target = albedo_px if is_base else max(albedo_px // 2, 256)
        if img.size[0] > target:
            img.scale(target, target)
            img.pack()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=False,
                              export_yup=True, export_image_format="JPEG", export_jpeg_quality=88, export_animations=False)
    print("DONE", name, meta[name])

json.dump(meta, open(META, "w"), indent=1)
