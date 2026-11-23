"""Shared helpers for Blender pipeline scripts: find each material's texture roles and export them
losslessly with role-based names (albedo / normal / orm), so the Godot import step can compress each
role appropriately (lossy for colour, lossless for data maps whose channels must not be mixed).

Data-map clean-up (AI generators emit plausible-looking but physically wrong PBR channels):
  * ORM.R  occlusion was a constant 1.0  -> replaced by an AO bake of the game mesh itself
  * ORM.B  metallic was mid-grey (0.2-0.5) on stone, wood and cloth -> only confident metal survives
  * ORM.G  roughness ~0.55 everywhere (plastic sheen) -> dielectrics get a matte floor
  * normal.B is ignored by Godot (Z is rebuilt from XY), so it is flattened to 1.0 to compress better
"""
import bpy
import numpy as np


def _upstream_image(sock, depth=0):
    """Follow links upstream from a socket until an Image Texture node is found."""
    if depth > 6 or not sock.is_linked:
        return None
    node = sock.links[0].from_node
    if node.type == "TEX_IMAGE":
        return node
    for inp in node.inputs:
        n = _upstream_image(inp, depth + 1)
        if n is not None:
            return n
    return None


def material_roles(mat):
    """{'albedo': ImageNode, 'normal': ImageNode, 'orm': ImageNode} for a glTF-imported material."""
    roles = {}
    if mat is None or not mat.use_nodes:
        return roles
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return roles
    for key, sock in (("albedo", "Base Color"), ("normal", "Normal"), ("orm", "Roughness"), ("orm", "Metallic")):
        if key in roles or sock not in bsdf.inputs:
            continue
        n = _upstream_image(bsdf.inputs[sock])
        if n is not None and n.image is not None:
            roles[key] = n
    return roles


def bake_ao(objs, size, distance, samples=48):
    """Cycles ambient-occlusion bake of the given objects (only what is visible in the scene occludes)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    if sc.world is None:
        sc.world = bpy.data.worlds.new("bake_world")
    sc.world.light_settings.distance = distance
    img = bpy.data.images.new("bake_ao", size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    temp = []
    for o in objs:
        for slot in o.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            nt = mat.node_tree
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = img
            for n in nt.nodes:
                n.select = False
            tn.select = True
            nt.nodes.active = tn
            temp.append((nt, tn))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    try:
        bpy.ops.object.bake(type="AO", margin=8, use_clear=True, use_selected_to_active=False)
        ok = True
    except Exception as ex:
        print("AO BAKE FAILED", ex)
        ok = False
    for nt, tn in temp:
        nt.nodes.remove(tn)
    if not ok:
        bpy.data.images.remove(img)
        return None
    a = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)[:, 0]
    print("AO mean %.3f p5 %.3f" % (a.mean(), np.percentile(a, 5)))
    return img


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fix_orm(img, ao=None, metal_lo=0.58, metal_hi=0.8, rough_floor=0.7):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    m = _smoothstep(metal_lo, metal_hi, px[:, 2])
    r = px[:, 1]
    px[:, 1] = np.maximum(r, rough_floor) * (1.0 - m) + np.clip(r, 0.3, 0.6) * m
    px[:, 2] = m
    if ao is not None:
        if tuple(ao.size) != (w, h):
            ao.scale(w, h)
        a = np.array(ao.pixels[:], dtype=np.float32).reshape(-1, 4)[:, 0]
        px[:, 0] = np.clip(a, 0.0, 1.0)
    img.pixels.foreach_set(px.ravel())
    print("ORM fixed: metal>0.5 %.3f rough mean %.2f ao mean %.2f" % (np.mean(m > 0.5), px[:, 1].mean(), px[:, 0].mean()))


def flatten_normal_z(img):
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    px[:, 2] = 1.0
    img.pixels.foreach_set(px.ravel())


def finalize_images(sizes, prefix="", ao=None, clean_data=True):
    """Rename used images by role, downscale to sizes[role] and mark them PNG (lossless in the GLB).
    With clean_data, ORM channels are repaired (+ baked AO if given) and normal maps packed for XY use."""
    done = set()
    for mat in bpy.data.materials:
        if mat.users == 0:
            continue
        for role, node in material_roles(mat).items():
            img = node.image
            if img.name in done:
                continue
            target = sizes.get(role, 1024)
            if img.size[0] > target:
                img.scale(target, target)
            if clean_data and role == "orm":
                fix_orm(img, ao)
            elif clean_data and role == "normal":
                flatten_normal_z(img)
            img.name = (prefix + "_" if prefix else "") + role
            img.file_format = "PNG"
            img.pack()
            done.add(img.name)
    return done
