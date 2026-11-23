"""Shared helpers for procedural stylized assets in Blender (headless)."""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

PAL = {
    "stone":      ((0.64, 0.60, 0.53), 0.85, 0.0),
    "stone_dark": ((0.40, 0.38, 0.37), 0.9, 0.0),
    "stone_warm": ((0.72, 0.62, 0.48), 0.85, 0.0),
    "wood":       ((0.50, 0.31, 0.17), 0.8, 0.0),
    "wood_dark":  ((0.30, 0.18, 0.10), 0.85, 0.0),
    "plank":      ((0.62, 0.42, 0.24), 0.8, 0.0),
    "roof_red":   ((0.72, 0.16, 0.12), 0.7, 0.0),
    "roof_blue":  ((0.16, 0.30, 0.66), 0.7, 0.0),
    "roof_purple":((0.38, 0.20, 0.62), 0.6, 0.0),
    "roof_green": ((0.20, 0.45, 0.25), 0.7, 0.0),
    "roof_dark":  ((0.22, 0.20, 0.24), 0.7, 0.0),
    "gold":       ((1.00, 0.72, 0.22), 0.35, 1.0),
    "iron":       ((0.30, 0.31, 0.34), 0.45, 0.9),
    "iron_dark":  ((0.16, 0.16, 0.18), 0.5, 0.9),
    "cloth_red":  ((0.78, 0.12, 0.10), 0.9, 0.0),
    "cloth_blue": ((0.14, 0.32, 0.78), 0.9, 0.0),
    "cloth_white":((0.90, 0.88, 0.82), 0.9, 0.0),
    "cloth_purple":((0.50, 0.22, 0.72), 0.9, 0.0),
    "cloth_green":((0.25, 0.55, 0.20), 0.9, 0.0),
    "skin":       ((0.95, 0.72, 0.55), 0.8, 0.0),
    "leaf":       ((0.22, 0.45, 0.14), 0.9, 0.0),
    "leaf_dark":  ((0.11, 0.30, 0.13), 0.9, 0.0),
    "leaf_light": ((0.38, 0.56, 0.16), 0.9, 0.0),
    "leaf_autumn":((0.80, 0.42, 0.12), 0.9, 0.0),
    "rock":       ((0.52, 0.50, 0.50), 0.95, 0.0),
    "rock_moss":  ((0.36, 0.48, 0.26), 0.95, 0.0),
    "dirt":       ((0.48, 0.36, 0.24), 0.95, 0.0),
    "sand":       ((0.82, 0.72, 0.52), 0.95, 0.0),
    "mushroom":   ((0.86, 0.16, 0.12), 0.6, 0.0),
    "black":      ((0.04, 0.04, 0.05), 0.9, 0.0),
    "straw":      ((0.86, 0.70, 0.36), 0.9, 0.0),
}
GLOW = {
    "glow_purple": ((0.70, 0.35, 1.00), 4.0),
    "glow_cyan":   ((0.30, 0.90, 1.00), 4.0),
    "glow_fire":   ((1.00, 0.55, 0.15), 5.0),
    "glow_portal": ((0.55, 0.10, 0.90), 3.0),
    "glow_gold":   ((1.00, 0.80, 0.30), 3.0),
    "glow_window": ((1.00, 0.70, 0.35), 2.5),
}

_mats = {}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()

def _lin(c):
    """Palette is authored in sRGB; Blender node colors are linear."""
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


def mat(name):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if name in PAL:
        c, r, me = PAL[name]
        c = _lin(c)
        bsdf.inputs["Base Color"].default_value = (*c, 1)
        bsdf.inputs["Roughness"].default_value = r
        bsdf.inputs["Metallic"].default_value = me
    elif name in GLOW:
        c, s = GLOW[name]
        c = _lin(c)
        bsdf.inputs["Base Color"].default_value = (*c, 1)
        bsdf.inputs["Emission Color"].default_value = (*c, 1)
        bsdf.inputs["Emission Strength"].default_value = s
        bsdf.inputs["Roughness"].default_value = 0.3
    _mats[name] = m
    return m

def _finish(obj, m, bevel=0.0, segs=2, smooth_angle=40, flat=False):
    if m:
        obj.data.materials.clear()
        obj.data.materials.append(mat(m))
    if bevel > 0:
        mod = obj.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
    set_smooth(obj, smooth_angle, flat)
    return obj

def set_smooth(obj, angle=40, flat=False):
    me = obj.data
    for p in me.polygons:
        p.use_smooth = not flat
    if not flat:
        bm = bmesh.new(); bm.from_mesh(me)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                a = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0)
                e.smooth = a < math.radians(angle)
            else:
                e.smooth = False
        bm.to_mesh(me); bm.free()

def link(obj, parent=None):
    if obj.name not in bpy.context.scene.collection.objects:
        try:
            bpy.context.scene.collection.objects.link(obj)
        except RuntimeError:
            pass
    if parent:
        obj.parent = parent
    return obj

def _new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def box(sx, sy, sz, loc=(0, 0, 0), rot=(0, 0, 0), m="stone", bevel=0.04, name="box", segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, sz / 2), verts=bm.verts)  # origin at bottom
    o = _new_obj(name, bm)
    o.location = loc; o.rotation_euler = rot
    return _finish(o, m, bevel, segs)

def cyl(r, h, verts=12, loc=(0, 0, 0), rot=(0, 0, 0), m="stone", bevel=0.03, r2=None, name="cyl", cap=True, segs=2, smooth=40):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts,
                          radius1=r, radius2=(r if r2 is None else r2), depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    o = _new_obj(name, bm)
    o.location = loc; o.rotation_euler = rot
    return _finish(o, m, bevel, segs, smooth)

def cone(r, h, verts=8, loc=(0, 0, 0), rot=(0, 0, 0), m="roof_red", bevel=0.02, name="cone", r2=0.0):
    return cyl(r, h, verts, loc, rot, m, bevel, r2=r2, name=name, smooth=30)

def sphere(r, loc=(0, 0, 0), m="leaf", sub=2, name="sph", scale=(1, 1, 1), flat=False, noise=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    if noise > 0:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co *= 1.0 + rnd.uniform(-noise, noise)
    o = _new_obj(name, bm)
    o.location = loc; o.scale = scale
    return _finish(o, m, 0, 2, 50, flat)

def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), m="gold", maj=24, mino=8, name="torus"):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mino,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    return _finish(o, m, 0, 2, 60)

def crystal(r, h, loc=(0, 0, 0), rot=(0, 0, 0), m="glow_purple", sides=6, name="crystal"):
    bm = bmesh.new()
    top = bm.verts.new((0, 0, h)); bot = bm.verts.new((0, 0, -h * 0.45))
    ring = [bm.verts.new((r * math.cos(a), r * math.sin(a), 0)) for a in
            [i * 2 * math.pi / sides for i in range(sides)]]
    for i in range(sides):
        a, b = ring[i], ring[(i + 1) % sides]
        bm.faces.new((a, b, top)); bm.faces.new((b, a, bot))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _new_obj(name, bm)
    o.location = loc; o.rotation_euler = rot
    return _finish(o, m, 0, 2, 10, True)

def prism_roof(w, d, h, loc=(0, 0, 0), m="roof_red", overhang=0.25, thick=0.12, name="roof"):
    """Gabled roof along X axis."""
    bm = bmesh.new()
    hw, hd = w / 2 + overhang, d / 2 + overhang
    pts = [(-hw, -hd, 0), (hw, -hd, 0), (hw, 0, h), (-hw, 0, h)]
    pts2 = [(-hw, hd, 0), (hw, hd, 0), (hw, 0, h), (-hw, 0, h)]
    v1 = [bm.verts.new(p) for p in pts]
    v2 = [bm.verts.new(p) for p in pts2]
    f1 = bm.faces.new(v1); f2 = bm.faces.new(v2[::-1])
    bm.verts.ensure_lookup_table()
    r = bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thick)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _new_obj(name, bm)
    o.location = loc
    return _finish(o, m, 0.02, 1, 30)

def gable_wall(w, h, loc=(0, 0, 0), rot=(0, 0, 0), m="plank", thick=0.15, name="gable"):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in [(-w / 2, 0, 0), (w / 2, 0, 0), (0, 0, h)]]
    bm.faces.new(vs)
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thick)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _new_obj(name, bm)
    o.location = loc; o.rotation_euler = rot
    return _finish(o, m, 0.01, 1, 30)

def stone_ring(radius, height, rows=4, per_row=12, loc=(0, 0, 0), m="stone", core_m="stone_dark",
               taper=0.0, seed=1, jitter=0.06, block_depth=0.35, mats=None):
    """Masonry cylinder made of individual bevelled blocks around a core."""
    rnd = random.Random(seed)
    objs = [cyl(radius - block_depth * 0.5, height, 16, loc, m=core_m, bevel=0, name="core")]
    rh = height / rows
    for row in range(rows):
        z = loc[2] + row * rh
        rr = radius - taper * (row / max(rows - 1, 1))
        off = (row % 2) * 0.5
        circ = 2 * math.pi * rr
        bw = circ / per_row
        for i in range(per_row):
            a = (i + off) * 2 * math.pi / per_row
            sw = bw * rnd.uniform(0.88, 0.98)
            sh = rh * rnd.uniform(0.86, 0.96)
            sd = block_depth * rnd.uniform(0.85, 1.1)
            cx = loc[0] + math.cos(a) * (rr - sd / 2 + rnd.uniform(-jitter, jitter) * 0.3)
            cy = loc[1] + math.sin(a) * (rr - sd / 2 + rnd.uniform(-jitter, jitter) * 0.3)
            mm = m if not mats else rnd.choice(mats)
            b = box(sd, sw, sh, (cx, cy, z + (rh - sh) / 2), (rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), a + rnd.uniform(-0.04, 0.04)),
                    m=mm, bevel=min(0.05, sh * 0.18), name="blk")
            objs.append(b)
    return objs

def crenels(radius, z, count=10, w=0.32, h=0.38, d=0.3, m="stone", loc=(0, 0, 0), seed=3):
    rnd = random.Random(seed)
    out = []
    for i in range(count):
        a = i * 2 * math.pi / count
        out.append(box(d, w, h * rnd.uniform(0.92, 1.05),
                       (loc[0] + math.cos(a) * (radius - d / 2), loc[1] + math.sin(a) * (radius - d / 2), z),
                       (0, 0, a), m=m, bevel=0.04, name="cren"))
    return out

def banner(loc, height=1.6, color="cloth_red", w=0.5, l=0.9, rot_z=0.0, pole_m="wood_dark", tip="gold"):
    out = [cyl(0.05, height, 6, loc, m=pole_m, bevel=0, name="pole")]
    out.append(sphere(0.08, (loc[0], loc[1], loc[2] + height + 0.04), m=tip, sub=1, name="tip"))
    # pennant flag: thin box hanging from top, slight wave
    bm = bmesh.new()
    segs = 6
    verts = []
    for s in range(segs + 1):
        t = s / segs
        x = 0.06 + t * w
        wave = math.sin(t * 3.0) * 0.06
        top = loc[2] + height - 0.05
        bottom = top - l * (1 - 0.35 * t)
        verts.append((bm.verts.new((x, wave, top)), bm.verts.new((x, wave, bottom))))
    for s in range(segs):
        bm.faces.new((verts[s][0], verts[s + 1][0], verts[s + 1][1], verts[s][1]))
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.03)
    o = _new_obj("flag", bm)
    o.location = (loc[0], loc[1], 0)
    o.rotation_euler = (0, 0, rot_z)
    # rotate about pole: set origin offset
    _finish(o, color, 0, 1, 60)
    out.append(o)
    return out

def figure(loc, body="cloth_green", hood="cloth_green", weapon="bow", scale=1.0, name="Unit"):
    """Tiny stylized tower unit (archer/mage/gunner) built from primitives; returns parent empty."""
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = loc
    parts = []
    s = scale
    parts.append(cyl(0.17 * s, 0.42 * s, 10, (0, 0, 0), m=body, bevel=0.02, r2=0.12 * s, name="body"))
    parts.append(sphere(0.13 * s, (0, 0, 0.52 * s), m="skin", sub=2, name="head"))
    parts.append(cone(0.16 * s, 0.30 * s, 10, (0, -0.01 * s, 0.50 * s), m=hood, name="hood"))
    parts.append(box(0.06 * s, 0.30 * s, 0.06 * s, (0.0, 0.0, 0.38 * s), m="wood_dark", bevel=0.01, name="belt"))
    if weapon == "bow":
        t = torus(0.2 * s, 0.018 * s, (0.17 * s, 0, 0.35 * s), (0, math.radians(90), 0), m="wood", maj=12, mino=4, name="bow")
        t.scale = (1, 0.45, 1)
        parts.append(t)
    elif weapon == "staff":
        parts.append(cyl(0.025 * s, 0.75 * s, 6, (0.18 * s, 0, 0), m="wood_dark", bevel=0, name="staff"))
        parts.append(crystal(0.05 * s, 0.1 * s, (0.18 * s, 0, 0.78 * s), m="glow_purple", name="gem"))
    elif weapon == "torch":
        parts.append(cyl(0.025 * s, 0.4 * s, 6, (0.18 * s, 0, 0.1 * s), m="wood_dark", bevel=0, name="t"))
        parts.append(sphere(0.06 * s, (0.18 * s, 0, 0.52 * s), m="glow_fire", sub=1, name="flame"))
    for p in parts:
        p.parent = root
    return root

def join(objs, name):
    objs = [o for o in objs if o and o.type == "MESH"]
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # apply modifiers first
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=md.name)
            except Exception as e:
                print("modifier apply fail", e)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    j = bpy.context.active_object
    j.name = name
    j.data.name = name
    return j

def apply_parent_transforms(obj):
    """Bake world matrix into mesh data keeping hierarchy root at origin."""
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def merge_by_distance(obj, d=0.0005):
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=d)
    bm.to_mesh(obj.data); bm.free()

def bake_ao(objs, ground=True, samples=24, tint_seed=0):
    """Bake ambient occlusion into a color attribute and multiply with subtle per-island tint."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples
    gp = None
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.001))
        gp = bpy.context.active_object
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        me = o.data
        for a in list(me.color_attributes):
            me.color_attributes.remove(a)
        ca = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = 0
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    scn.render.bake.target = "VERTEX_COLORS"
    scn.world.light_settings.distance = 1.2
    try:
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    except Exception as e:
        print("AO bake failed:", e)
    # remap AO: lift shadows (stylized), slight warm tint
    for o in meshes:
        me = o.data
        ca = me.color_attributes["Col"]
        for d in ca.data:
            ao = d.color[0]
            v = 0.42 + 0.58 * (ao ** 0.8)
            d.color = (min(1, v * 1.0), min(1, v * 0.985), min(1, v * 0.96), 1)
    if gp:
        bpy.data.objects.remove(gp, do_unlink=True)

def export(path, objs=None):
    bpy.ops.object.select_all(action="DESELECT")
    if objs:
        for o in objs:
            o.select_set(True)
            for c in o.children_recursive:
                c.select_set(True)
    kw = dict(filepath=path, export_format="GLB", use_selection=bool(objs), export_apply=True,
              export_yup=True, export_texcoords=False, export_normals=True, export_animations=False,
              export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(export_colors=True, **kw)
    print("exported", path)
