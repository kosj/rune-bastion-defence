"""High-quality static asset pipeline for VARCO meshes (AI mesh -> game-ready, per the usual
generate-high / reduce / bake workflow):

 1. normalise the high-poly source: scale to the target footprint/height, pivot at bottom centre
 2. reduce a copy to the game triangle budget (quadric edge-collapse keeps the silhouette + UVs)
 3. shading: hard-surface assets get sharp edges above an angle plus face-area weighted normals,
    so flat walls read flat and corners read crisp instead of "melted"
 4. bake a tangent-space normal map from the high-poly (including its own normal map) onto the
    low-poly at 2x resolution, then downsample (falls back to the source map if the bake is bad)
 5. export with lossless, role-named textures (albedo / normal / orm) for role-aware engine import

blender -b -P process_hq.py -- IN_DIR OUT_DIR META_JSON name:mode:size:tris:albedo:normal:style[:orm[:pivot[:yaw]]] ...
  mode  foot|tower|height   style  hard|soft
  ALBEDO_REF=<dir>: match each albedo's colour statistics to <dir>/<name>.glb (regenerated models
        keep the palette of the ones they replace)
  tris  a triangle count, or eN[/cap]: the smallest count whose deviation from the high-poly stays
        under N px at the closest game zoom (PX_PER_M, default 81.7 = 16 m away at 900 px)
"""
import bpy
import bmesh
import json
import math
import os
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import tex_roles  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, META = argv[0], argv[1], argv[2]
specs = argv[3:]
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(META)) if os.path.exists(META) else {}


def bounds(o):
    co = np.zeros(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    a = co.reshape(-1, 3)
    return Vector(a.min(0)), Vector(a.max(0))


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


# Screen-space error budget: the game's closest zoom (camera 16 m away, fov 38, 900 px tall view)
# shows 81.7 px per metre. A tris field "e1.0" asks for the smallest mesh whose deviation from the
# high-poly (99th percentile, both directions) stays under 1.0 px there; "e1.0/12000" also caps it.
PX_PER_M = float(os.environ.get("PX_PER_M", "81.7"))


def _sample(o, n):
    co = np.zeros(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if len(co) > n:
        co = co[np.random.default_rng(7).choice(len(co), n, replace=False)]
    return co


def deviation_px(high, high_bvh, high_pts, low):
    """p99 surface deviation of `low` from `high` in screen px at the closest zoom (both ways)."""
    dg = bpy.context.evaluated_depsgraph_get()
    lb = BVHTree.FromObject(low, dg)
    d1 = [lb.find_nearest(Vector(v))[3] for v in high_pts]
    d2 = [high_bvh.find_nearest(Vector(v))[3] for v in _sample(low, 6000)]
    d1 = [d for d in d1 if d is not None]
    d2 = [d for d in d2 if d is not None]
    return max(float(np.percentile(d1, 99)), float(np.percentile(d2, 99))) * PX_PER_M


def weld(o):
    """Join the vertices the glTF export split along UV seams (UVs stay per corner). Decimating the
    split mesh lets both sides of every seam drift apart: hairline cracks, and the engine's LOD
    generator sees so many borders that it gives up."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4 * max(o.dimensions))
    bm.to_mesh(o.data)
    bm.free()


def decimate_to(low, tris):
    t = tri_count(low)
    if t > tris:
        only(low)
        mod = low.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = tris / t
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")


def budget_for_error(high, target_px, cap):
    """Smallest reduction of `high` (within 8 %) whose deviation stays under target_px, trying the
    seam-welded and the split mesh: returns (requested tris, welded?, actual tris, error px).
    Welding wins unless it needs over 10 % more triangles (some AI props are open shells that
    collapse badly once welded). With a cap that stops both short of the target, welding wins
    unless its error is over 15 % larger."""
    dg = bpy.context.evaluated_depsgraph_get()
    hb = BVHTree.FromObject(high, dg)
    pts = _sample(high, 12000)
    src = tri_count(high)

    def err_at(n, welded):
        c = high.copy()
        c.data = high.data.copy()
        bpy.context.collection.objects.link(c)
        if welded:
            weld(c)
        decimate_to(c, n)
        e = deviation_px(high, hb, pts, c)
        t = tri_count(c)
        me = c.data
        bpy.data.objects.remove(c, do_unlink=True)
        bpy.data.meshes.remove(me)
        return e, t

    out = []
    for welded in (True, False):
        hi = min(src, cap)
        lo = max(200, hi // 40)
        e, t = err_at(hi, welded)
        if e <= target_px:
            while hi / lo > 1.08:
                mid = int(math.sqrt(hi * lo))
                e2, t2 = err_at(mid, welded)
                if e2 <= target_px:
                    hi, e, t = mid, e2, t2
                else:
                    lo = mid
        out.append((hi, welded, t, e))
        print("BUDGET", "welded" if welded else "split", "tris", t, "err_px %.2f" % e)
    w, sp = out
    ok_w, ok_s = w[3] <= target_px, sp[3] <= target_px
    if ok_w and (not ok_s or w[2] <= sp[2] * 1.1):
        return w
    if ok_s:
        return sp
    # both capped short of the target: keep the crack-free welded mesh unless it is clearly worse
    return w if w[3] <= sp[3] * 1.15 else sp



def _srgb_to_lab(rgb):
    a = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = a @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], 1)


def _lab_to_srgb(lab):
    fy = (lab[:, 0] + 16) / 116
    fx = fy + lab[:, 1] / 500
    fz = fy - lab[:, 2] / 200
    f = np.stack([fx, fy, fz], 1)
    xyz = np.where(f > 0.2069, f ** 3, (f - 16.0 / 116.0) / 7.787) * np.array([0.9505, 1.0, 1.089])
    m = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    a = np.clip(xyz @ m.T, 0.0, 1.0)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)


def glb_albedo_pixels(path):
    """sRGB pixels (N x 3, 0..1) of the base colour texture of a GLB, read without importing it."""
    import struct
    import tempfile
    with open(path, "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(n))
        f.read(8)
        binc = f.read()
    tex = js["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    im = js["images"][js["textures"][tex]["source"]]
    bv = js["bufferViews"][im["bufferView"]]
    data = binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    tmp.write(data)
    tmp.close()
    img = bpy.data.images.load(tmp.name)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)[:, :3]
    bpy.data.images.remove(img)
    os.unlink(tmp.name)
    return px


def match_albedo(img, ref_px):
    """Keep an established palette when a model is regenerated: move the new albedo's colour
    statistics (mean / spread of L, a, b) onto those of the asset it replaces."""
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    lab = _srgb_to_lab(px[:, :3].astype(np.float64))
    ref = _srgb_to_lab(ref_px.astype(np.float64))
    mu, sd = lab.mean(0), lab.std(0) + 1e-6
    rmu, rsd = ref.mean(0), ref.std(0)
    lab = (lab - mu) / sd * rsd + rmu
    px[:, :3] = _lab_to_srgb(lab)
    img.pixels.foreach_set(px.ravel())
    img.update()
    print("ALBEDO matched: L %.1f -> %.1f, a %.1f -> %.1f, b %.1f -> %.1f" % (mu[0], rmu[0], mu[1], rmu[1], mu[2], rmu[2]))


for spec in specs:
    p = spec.split(":")
    name, mode, size = p[0], p[1], float(p[2])
    tris_spec, albedo_px, normal_px, style = p[3], int(p[4]), int(p[5]), p[6]
    orm_px = int(p[7]) if len(p) > 7 else 512
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(IN, name + ".glb"))
    for o in bpy.data.objects:
        o.select_set(True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
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
    high = bpy.context.active_object
    high.name = "High"

    # 1. normalise
    if len(p) > 9 and float(p[9]) != 0.0:
        # optional yaw (degrees) so a held prop's blade / a cannon's muzzle faces the engine's convention
        a = math.radians(float(p[9]))
        co = np.zeros(len(high.data.vertices) * 3)
        high.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        x, y = co[:, 0].copy(), co[:, 1].copy()
        co[:, 0] = x * math.cos(a) - y * math.sin(a)
        co[:, 1] = x * math.sin(a) + y * math.cos(a)
        high.data.vertices.foreach_set("co", co.ravel())
        high.data.update()
    mn, mx = bounds(high)
    ext = mx - mn
    if mode == "foot":
        s = size / max(ext.x, ext.y)
    elif mode == "tower":
        s = min(size / max(ext.x, ext.y), size * 1.55 / ext.z)
    elif mode == "height":
        s = size / ext.z
    else:
        s = size
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    co = np.zeros(len(high.data.vertices) * 3)
    high.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if len(p) > 8 and mode == "height":
        # held props: centre on the handle (lowest fifth), not on the bounding box an axe head skews
        low_band = co[co[:, 2] < mn.z + 0.2 * ext.z]
        if len(low_band) > 10:
            cx = (low_band[:, 0].min() + low_band[:, 0].max()) / 2
            cy = (low_band[:, 1].min() + low_band[:, 1].max()) / 2
    co[:, 0] = (co[:, 0] - cx) * s
    co[:, 1] = (co[:, 1] - cy) * s
    co[:, 2] = (co[:, 2] - mn.z) * s
    if len(p) > 8:
        # optional pivot height as a fraction of the height (held props: the grip sits at the origin)
        co[:, 2] -= float(p[8]) * ext.z * s
    high.data.vertices.foreach_set("co", co.ravel())
    high.data.update()
    src_tris = tri_count(high)

    # 2. reduce a copy (to a fixed budget, or to the smallest one meeting a screen-space error)
    err_px = None
    welded = False
    if tris_spec.startswith("e"):
        tgt, _, cap = tris_spec[1:].partition("/")
        tris, welded, _, err_px = budget_for_error(high, float(tgt), int(cap) if cap else 10 ** 9)
    else:
        tris = int(tris_spec)
    low = high.copy()
    low.data = high.data.copy()
    low.name = "Body"
    low.data.name = "Body"
    bpy.context.collection.objects.link(low)
    if welded:
        weld(low)
    decimate_to(low, tris)
    only(low)

    # 3. shading
    if low.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth()
    if style == "hard":
        bm = bmesh.new()
        bm.from_mesh(low.data)
        lim = math.radians(46.0)
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim:
                e.smooth = False
        bm.to_mesh(low.data)
        bm.free()
        wn = low.modifiers.new("wn", "WEIGHTED_NORMAL")
        wn.mode = "FACE_AREA"
        wn.weight = 50
        wn.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier="wn")

    # 4. bake high -> low normal map
    high_mat = high.active_material
    low_mat = high_mat.copy()
    low.data.materials.clear()
    low.data.materials.append(low_mat)
    roles = tex_roles.material_roles(low_mat)
    baked_ok = False
    if "normal" in roles or True:
        W = normal_px * 2
        bake = bpy.data.images.new("bake_normal", W, W, alpha=False)
        bake.colorspace_settings.name = "Non-Color"
        nt = low_mat.node_tree
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = bake
        for n in nt.nodes:
            n.select = False
        tn.select = True
        nt.nodes.active = tn
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = 4
        bpy.ops.object.select_all(action="DESELECT")
        high.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        dim = max(low.dimensions)
        # adaptive cage: how far does the high surface stick out of the low one?  (high verts vs low BVH)
        dg = bpy.context.evaluated_depsgraph_get()
        bvh = BVHTree.FromObject(low, dg)
        hv = np.zeros(len(high.data.vertices) * 3)
        high.data.vertices.foreach_get("co", hv)
        hv = hv.reshape(-1, 3)
        step = max(1, len(hv) // 40000)
        outs = []
        for v in hv[::step]:
            loc, nrm, idx, dist = bvh.find_nearest(Vector(v))
            if loc is not None and (Vector(v) - loc).dot(nrm) > 0:
                outs.append(dist)
        dev = float(np.percentile(outs, 99.5)) if outs else dim * 0.01
        cage = min(max(dev * 1.25, dim * 0.004), dim * 0.03)
        ray = cage * 3.0
        try:
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True,
                                cage_extrusion=cage, max_ray_distance=ray, margin=8,
                                use_clear=True)
            px = np.array(bake.pixels[:], dtype=np.float32).reshape(-1, 4)
            n = px[:, :3] * 2.0 - 1.0
            inward = float(np.mean(n[:, 2] < -0.1))
            # tame grazing / back-facing hits (projection artefacts on decimated-away detail):
            # blend them towards the low-poly normal instead of letting them shade black
            t = np.clip((0.35 - n[:, 2]) / 0.6, 0.0, 1.0)[:, None]
            n = n * (1.0 - t) + np.array([0.0, 0.0, 1.0]) * t
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
            px[:, :3] = n * 0.5 + 0.5
            bake.pixels.foreach_set(px.ravel())
            mean = px[:, :3].mean(0)
            baked_ok = inward < 0.10 and abs(mean[0] - 0.5) < 0.08 and abs(mean[1] - 0.5) < 0.08 and mean[2] > 0.8
            print("BAKE", name, "cage %.4f dev %.4f" % (cage, dev), "inward %.3f" % inward, "mean",
                  np.round(mean, 3), "ok", baked_ok)
            if os.environ.get("HQ_DEBUG"):
                dbg = bake.copy()
                dbg.filepath_raw = os.path.join(OUT, "debug_%s_normal.png" % name)
                dbg.file_format = "PNG"
                dbg.save()
        except Exception as ex:  # keep going with the source map
            print("BAKE FAILED", name, ex)
        if os.environ.get("HQ_NOBAKE"):
            baked_ok = False
        nt.nodes.remove(tn)
        if baked_ok:
            bake.scale(normal_px, normal_px)
            if "normal" in roles:
                roles["normal"].image = bake
            else:
                # source had no normal map: wire the bake in
                bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
                nm = nt.nodes.new("ShaderNodeNormalMap")
                it = nt.nodes.new("ShaderNodeTexImage")
                it.image = bake
                nt.links.new(it.outputs["Color"], nm.inputs["Color"])
                nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])

    # meta (top platform height for tower units)
    bpy.data.objects.remove(high, do_unlink=True)
    bpy.data.materials.remove(high_mat)
    mn2, mx2 = bounds(low)
    hits = []
    for dx, dy in ((0, 0), (0.25, 0), (-0.25, 0), (0, 0.25), (0, -0.25), (0.15, 0.15), (-0.15, -0.15)):
        ok, loc, nrm, idx = low.ray_cast(Vector((dx, dy, mx2.z + 5)), Vector((0, 0, -1)))
        if ok:
            hits.append(loc.z)
    hits.sort()
    top = hits[len(hits) // 2] if hits else mx2.z
    meta[name] = {"top": round(top, 3), "height": round(mx2.z, 3), "width": round(max(mx2.x - mn2.x, mx2.y - mn2.y), 3),
                  "depth_front": round(mx2.y, 3)}

    # 5. ambient occlusion of the game mesh (stored in ORM.R; the generator left it blank)
    ao_img = tex_roles.bake_ao([low], max(orm_px * 2, 512), max(low.dimensions) * 0.18)

    # 6. export
    tex_roles.finalize_images({"albedo": albedo_px, "normal": normal_px, "orm": orm_px}, ao=ao_img)
    ref = os.path.join(os.environ.get("ALBEDO_REF", ""), name + ".glb")
    if os.environ.get("ALBEDO_REF") and os.path.exists(ref):
        alb = bpy.data.images.get("albedo")
        if alb is not None:
            match_albedo(alb, glb_albedo_pixels(ref))
            alb.pack()
    only(low)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_image_format="AUTO", export_tangents=True,
                              export_animations=False)
    print("DONE", name, "src_tris", src_tris, "tris", tri_count(low), "err_px", None if err_px is None else round(err_px, 2), "welded", welded,
          "baked", baked_ok, meta[name])

json.dump(meta, open(META, "w"), indent=1)
