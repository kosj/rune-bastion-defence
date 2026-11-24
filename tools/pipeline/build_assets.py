"""Builds all tower / environment GLBs procedurally.  Run: blender -b -P build_assets.py -- OUTDIR [only]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from blender_lib import *

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/assets"
ONLY = argv[1].split(",") if len(argv) > 1 else None
os.makedirs(OUT, exist_ok=True)


def unparent(root):
    out = []
    for c in list(root.children):
        apply_parent_transforms(c)
        out.append(c)
    bpy.data.objects.remove(root, do_unlink=True)
    return out


def set_origin(obj, pivot):
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


def finalize(name, groups, pivots=None, ao=True):
    """groups: dict name -> list of objects. Joins, bakes AO, exports."""
    pivots = pivots or {}
    final = []
    for gname, objs in groups.items():
        flat = []
        for o in objs:
            if o is None:
                continue
            if o.type == "EMPTY":
                flat += unparent(o)
            else:
                flat.append(o)
        j = join(flat, gname)
        if j is None:
            continue
        merge_by_distance(j)
        if gname in pivots:
            set_origin(j, pivots[gname])
        final.append(j)
    if ao:
        bake_ao(final)
    export(os.path.join(OUT, name + ".glb"), final)


def scene(name):
    if ONLY and name not in ONLY:
        return False
    reset()
    random.seed(hash(name) & 0xffff)
    return True

# ---------------------------------------------------------------- plot

def build_plot():
    if not scene("plot"):
        return
    g = [cyl(1.75, 0.12, 20, (0, 0, 0), m="stone_dark", bevel=0.04)]
    g += [cyl(1.45, 0.05, 20, (0, 0, 0.1), m="dirt", bevel=0.02)]
    rnd = random.Random(4)
    n = 16
    for i in range(n):
        a = i * 2 * math.pi / n
        r = 1.6
        g.append(box(0.34, 0.6, 0.22 * rnd.uniform(0.8, 1.15), (math.cos(a) * r, math.sin(a) * r, 0.05),
                     (0, 0, a + rnd.uniform(-0.1, 0.1)), m=rnd.choice(["stone", "stone_warm"]), bevel=0.06))
    # little sign post
    g.append(cyl(0.05, 0.7, 6, (1.15, -1.15, 0), m="wood_dark", bevel=0))
    g.append(box(0.06, 0.42, 0.3, (1.15, -1.15, 0.45), (0, 0, math.radians(45)), m="plank", bevel=0.02))
    finalize("plot", {"Body": g})

# ---------------------------------------------------------------- archer

def archer_units(z, count, r=0.45, scale=1.0):
    units = {}
    for i in range(count):
        a = i * 2 * math.pi / count + 0.6
        root = figure((math.cos(a) * r, math.sin(a) * r, z), body="cloth_green", hood="cloth_green", weapon="bow",
                      scale=scale, name="u")
        units["Unit%d" % (i + 1)] = ([root], (math.cos(a) * r, math.sin(a) * r, z))
    return units


def build_archer(level):
    name = "archer_%d" % level
    if not scene(name):
        return
    body = []
    if level == 1:
        h = 2.5
        for sx in (-1, 1):
            for sy in (-1, 1):
                body.append(cyl(0.13, h + 0.4, 7, (sx * 0.85, sy * 0.85, 0), (sy * 0.06, -sx * 0.06, 0), m="wood", bevel=0.02))
        for i, (a, b) in enumerate([((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]):
            mx, my = (a[0] + b[0]) * 0.42, (a[1] + b[1]) * 0.42
            rotz = 0 if a[1] == b[1] else math.pi / 2
            body.append(box(0.1, 1.8, 0.12, (mx, my, 0.9), (math.radians(28), 0, rotz), m="wood_dark", bevel=0.01))
        body.append(box(2.3, 2.3, 0.18, (0, 0, h), m="plank", bevel=0.03))
        for s in range(4):
            a = s * math.pi / 2
            for k in range(-3, 4):
                x, y = 1.05, k * 0.3
                c, sn = math.cos(a), math.sin(a)
                body.append(box(0.08, 0.24, 0.55, (c * x - sn * y, sn * x + c * y, h + 0.15), (0, 0, a), m="plank", bevel=0.01))
        body += banner((-0.95, -0.95, h), 1.3, "cloth_green", 0.4, 0.6)
        body.append(cyl(0.9, 0.12, 10, (0, 0, 0), m="stone_dark", bevel=0.03))
        top = h + 0.18
        units = archer_units(top, 2, 0.42)
    elif level == 2:
        body += stone_ring(1.15, 1.8, rows=4, per_row=11, mats=["stone", "stone_warm"], seed=2)
        h = 1.8
        body.append(cyl(1.25, 0.2, 12, (0, 0, h), m="stone_dark", bevel=0.03))
        for sx in (-1, 1):
            for sy in (-1, 1):
                body.append(cyl(0.11, 1.0, 7, (sx * 0.85, sy * 0.85, h + 0.2), m="wood", bevel=0.02))
        body.append(box(2.3, 2.3, 0.16, (0, 0, h + 0.2), m="plank", bevel=0.03))
        for s in range(4):
            a = s * math.pi / 2
            c, sn = math.cos(a), math.sin(a)
            body.append(box(0.1, 2.25, 0.45, (c * 1.08, sn * 1.08, h + 0.36), (0, 0, a), m="wood", bevel=0.02))
        body.append(cone(1.75, 1.2, 4, (0, 0, h + 1.2), (0, 0, math.radians(45)), m="roof_red", bevel=0.03))
        body.append(sphere(0.1, (0, 0, h + 2.45), m="gold", sub=1))
        body += banner((0, 0, h + 2.3), 0.8, "cloth_red", 0.45, 0.5)
        top = h + 0.36
        units = archer_units(top, 2, 0.45)
    else:
        body += stone_ring(1.3, 2.7, rows=6, per_row=12, taper=0.1, mats=["stone", "stone_warm", "stone"], seed=5)
        h = 2.7
        body.append(cyl(1.42, 0.22, 14, (0, 0, h), m="stone_dark", bevel=0.04))
        body.append(torus(1.38, 0.05, (0, 0, h + 0.2), m="gold", maj=28, mino=6))
        body += crenels(1.42, h + 0.22, 10, w=0.42, h=0.45, d=0.32, m="stone")
        for i in range(4):
            a = i * math.pi / 2 + math.pi / 4
            body.append(box(0.5, 0.45, 2.3, (math.cos(a) * 1.2, math.sin(a) * 1.2, 0), (0, 0, a), m="stone_dark", bevel=0.06))
        # small corner turret with spire
        tx, ty = -0.95, -0.95
        body.append(cyl(0.38, 1.1, 10, (tx, ty, h + 0.2), m="stone_warm", bevel=0.03))
        body.append(cone(0.55, 1.2, 8, (tx, ty, h + 1.3), m="roof_red", bevel=0.02))
        body.append(sphere(0.09, (tx, ty, h + 2.5), m="gold", sub=1))
        body += banner((tx, ty, h + 2.45), 0.7, "cloth_red", 0.5, 0.5)
        for i in range(3):
            a = i * 2 * math.pi / 3 + 0.4
            body += [box(0.08, 0.5, 0.8, (math.cos(a) * 1.33, math.sin(a) * 1.33, 1.3), (0, 0, a), m="cloth_red", bevel=0.0)]
            body.append(box(0.06, 0.18, 0.18, (math.cos(a) * 1.38, math.sin(a) * 1.38, 1.65), (0, 0, a), m="gold", bevel=0.02))
        body.append(box(0.12, 0.45, 0.7, (1.31, 0, 0.0), m="wood_dark", bevel=0.03))
        top = h + 0.22
        units = archer_units(top, 3, 0.55)
    groups = {"Body": body}
    piv = {}
    for k, (objs, p) in units.items():
        groups[k] = objs; piv[k] = p
    finalize(name, groups, piv)

# ---------------------------------------------------------------- mage

def build_mage(level):
    name = "mage_%d" % level
    if not scene(name):
        return
    body = []
    if level == 1:
        body += stone_ring(0.95, 1.6, rows=4, per_row=10, mats=["stone", "stone_dark"], seed=8)
        body.append(cyl(1.0, 0.18, 10, (0, 0, 1.6), m="stone_dark", bevel=0.03))
        body.append(cyl(0.7, 0.9, 8, (0, 0, 1.78), m="stone", bevel=0.04, r2=0.45))
        body.append(cyl(0.55, 0.12, 8, (0, 0, 2.68), m="iron", bevel=0.02))
        for i in range(4):
            a = i * math.pi / 2 + math.pi / 4
            body.append(box(0.3, 0.22, 0.75, (math.cos(a) * 1.35, math.sin(a) * 1.35, 0), (0.1, 0, a), m="stone_dark", bevel=0.05))
            body.append(box(0.05, 0.1, 0.25, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.35), (0.1, 0, a), m="glow_purple", bevel=0))
        crystal_z = 3.35
        cr = [crystal(0.28, 0.55, (0, 0, crystal_z), m="glow_purple")]
        groups = {"Body": body, "Crystal": cr}
        piv = {"Crystal": (0, 0, crystal_z)}
        unit_z = None
    elif level == 2:
        body += stone_ring(1.05, 2.4, rows=6, per_row=11, taper=0.15, mats=["stone", "stone_dark"], seed=9)
        body.append(cyl(1.15, 0.2, 12, (0, 0, 2.4), m="stone_dark", bevel=0.03))
        body.append(torus(1.08, 0.05, (0, 0, 2.6), m="gold", maj=24, mino=6))
        for i in range(8):
            a = i * 2 * math.pi / 8
            body.append(cyl(0.07, 0.5, 6, (math.cos(a) * 0.95, math.sin(a) * 0.95, 2.6), m="stone", bevel=0.01))
        body.append(cone(1.3, 2.2, 10, (0, 0, 3.1), m="roof_purple", bevel=0.03))
        body.append(torus(1.0, 0.07, (0, 0, 3.15), m="gold", maj=24, mino=6))
        for i in range(3):
            a = i * 2 * math.pi / 3
            body.append(box(0.12, 0.35, 0.5, (math.cos(a) * 1.02, math.sin(a) * 1.02, 1.3), (0, 0, a), m="glow_window", bevel=0.02))
        crystal_z = 5.75
        cr = [crystal(0.3, 0.6, (0, 0, crystal_z), m="glow_purple")]
        groups = {"Body": body, "Crystal": cr}
        piv = {"Crystal": (0, 0, crystal_z)}
    else:
        body += stone_ring(1.25, 3.0, rows=7, per_row=13, taper=0.25, mats=["stone", "stone_dark", "stone"], seed=10)
        for i in range(5):
            a = i * 2 * math.pi / 5
            body.append(box(0.35, 0.4, 2.4, (math.cos(a) * 1.15, math.sin(a) * 1.15, 0), (0.08 * math.cos(0), 0, a), m="stone_dark", bevel=0.05))
            body.append(crystal(0.12, 0.35, (math.cos(a) * 1.35, math.sin(a) * 1.35, 2.5), m="glow_purple"))
        body.append(cyl(1.25, 0.22, 14, (0, 0, 3.0), m="stone_dark", bevel=0.04))
        body.append(torus(1.2, 0.06, (0, 0, 3.22), m="gold", maj=28, mino=6))
        body.append(cyl(0.85, 0.7, 10, (0, 0, 3.22), m="stone", bevel=0.03, r2=0.75))
        body.append(cone(1.05, 2.6, 10, (0, 0, 3.9), m="roof_purple", bevel=0.03))
        body.append(torus(0.82, 0.07, (0, 0, 3.95), m="gold", maj=24, mino=6))
        body.append(sphere(0.12, (0, 0, 6.5), m="gold", sub=1))
        for i in range(4):
            a = i * math.pi / 2 + 0.4
            body.append(box(0.12, 0.3, 0.55, (math.cos(a) * 1.2, math.sin(a) * 1.2, 1.4), (0, 0, a), m="glow_window", bevel=0.02))
        crystal_z = 7.2
        cr = [crystal(0.38, 0.75, (0, 0, crystal_z), m="glow_purple")]
        ring = [torus(0.75, 0.04, (0, 0, crystal_z), (math.radians(70), 0, 0), m="glow_gold", maj=28, mino=5)]
        for i in range(3):
            a = i * 2 * math.pi / 3
            ring.append(crystal(0.08, 0.16, (math.cos(a) * 0.75, 0, crystal_z + math.sin(a) * 0.75 * math.sin(math.radians(20))), m="glow_cyan"))
        groups = {"Body": body, "Crystal": cr, "Ring": ring}
        piv = {"Crystal": (0, 0, crystal_z), "Ring": (0, 0, crystal_z)}
    finalize(name, groups, piv)

# ---------------------------------------------------------------- artillery

def mortar(z, scale=1.0, big=False):
    s = scale
    objs = []
    objs.append(cyl(0.5 * s, 0.25 * s, 10, (0, 0, z), m="wood_dark", bevel=0.03))
    objs.append(box(0.2 * s, 0.9 * s, 0.4 * s, (0.0, 0.0, z + 0.2 * s), m="wood", bevel=0.03))
    L = (1.3 if big else 0.95) * s
    R = (0.36 if big else 0.32) * s
    ang = math.radians(-35)
    base_z = z + 0.45 * s
    objs.append(cyl(R, L, 12, (0, 0, base_z), (ang, 0, 0), m="iron_dark", bevel=0.03, r2=R * 1.15))
    dy, dz = math.sin(-ang), math.cos(ang)
    for t in (0.12, 0.6, 0.97):
        objs.append(torus(R * (1.04 + t * 0.15), 0.045 * s, (0, dy * L * t, base_z + dz * L * t), (ang, 0, 0),
                          m="gold" if big else "iron", maj=14, mino=4))
    objs.append(sphere(R * 0.75, (0, -0.05 * s, base_z), m="iron_dark", sub=1))
    return objs


def build_artillery(level):
    name = "artillery_%d" % level
    if not scene(name):
        return
    body = []
    if level == 1:
        body += stone_ring(1.4, 0.9, rows=2, per_row=13, mats=["stone", "stone_warm"], seed=12)
        body.append(cyl(1.42, 0.14, 14, (0, 0, 0.9), m="plank", bevel=0.03))
        body += crenels(1.45, 1.04, 8, w=0.5, h=0.35, d=0.3, m="stone")
        for i in range(3):
            a = i * 2.1 + 0.3
            body.append(cyl(0.2, 0.45, 8, (math.cos(a) * 1.7, math.sin(a) * 1.7, 0), m="wood", bevel=0.02))
        body.append(sphere(0.15, (1.0, 0.6, 1.2), m="iron_dark", sub=1))
        body.append(sphere(0.15, (1.2, 0.35, 1.2), m="iron_dark", sub=1))
        top = 1.04
        b = mortar(top, 0.9)
    elif level == 2:
        body += stone_ring(1.5, 1.3, rows=3, per_row=14, mats=["stone", "stone_dark"], seed=13)
        body.append(cyl(1.52, 0.16, 14, (0, 0, 1.3), m="stone_dark", bevel=0.03))
        body += crenels(1.55, 1.46, 10, w=0.48, h=0.4, d=0.32, m="stone")
        body.append(torus(1.52, 0.06, (0, 0, 0.65), m="iron", maj=28, mino=6))
        for i in range(5):
            a = i * 2 * math.pi / 5 + 0.3
            body.append(sphere(0.22, (math.cos(a) * 1.75, math.sin(a) * 1.75, 0.16), m="straw", sub=1, scale=(1.3, 1, 0.65)))
        for i, p in enumerate([(0.9, 0.7), (1.1, 0.4), (1.0, 0.55)]):
            body.append(sphere(0.15, (p[0], p[1], 1.6 + (0.2 if i == 2 else 0)), m="iron_dark", sub=1))
        body += banner((-1.2, -0.8, 1.46), 1.2, "cloth_red", 0.4, 0.55)
        top = 1.46
        b = mortar(top, 1.05)
    else:
        body += stone_ring(1.6, 1.6, rows=4, per_row=15, mats=["stone_warm", "stone"], seed=14)
        for i in range(6):
            a = i * 2 * math.pi / 6
            body.append(box(0.45, 0.5, 1.5, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0), (0, 0, a), m="stone_dark", bevel=0.06))
        body.append(cyl(1.65, 0.18, 16, (0, 0, 1.6), m="stone_dark", bevel=0.03))
        body.append(torus(1.62, 0.07, (0, 0, 1.78), m="gold", maj=32, mino=6))
        body += crenels(1.68, 1.78, 12, w=0.45, h=0.45, d=0.32, m="stone_warm")
        body.append(cyl(0.22, 1.2, 8, (-1.0, 0.9, 1.78), m="stone_dark", bevel=0.02))
        body.append(cyl(0.28, 0.15, 8, (-1.0, 0.9, 2.95), m="iron", bevel=0.02))
        for i, p in enumerate([(1.0, 0.8), (1.25, 0.5), (1.15, 0.68)]):
            body.append(sphere(0.17, (p[0], p[1], 1.95 + (0.22 if i == 2 else 0)), m="iron_dark", sub=1))
        body += banner((-1.25, -0.9, 1.78), 1.5, "cloth_red", 0.5, 0.6)
        body += banner((1.25, -0.9, 1.78), 1.5, "cloth_red", 0.5, 0.6)
        top = 1.78
        b = mortar(top, 1.25, big=True)
    finalize(name, {"Body": body, "Barrel": b}, {"Barrel": (0, 0, top)})

# ---------------------------------------------------------------- barracks

def build_barracks(level):
    name = "barracks_%d" % level
    if not scene(name):
        return
    body = []
    w, d = (2.4, 1.8) if level == 1 else ((2.8, 2.0) if level == 2 else (3.0, 2.2))
    wall_h = 1.0 if level == 1 else 1.25
    found = "stone_dark"
    body.append(box(w + 0.3, d + 0.3, 0.3, (0, 0, 0), m=found, bevel=0.05))
    wall_m = "plank" if level == 1 else "stone_warm"
    if level == 1:
        body.append(box(w, d, wall_h, (0, 0, 0.3), m="plank", bevel=0.03))
        for sx in (-1, 1):
            for sy in (-1, 1):
                body.append(box(0.18, 0.18, wall_h + 0.1, (sx * w / 2, sy * d / 2, 0.3), m="wood_dark", bevel=0.02))
    else:
        rnd = random.Random(level)
        rows = 4
        for r in range(rows):
            for side in range(4):
                L = w if side % 2 == 0 else d
                n = int(L / 0.45)
                for k in range(n):
                    t = (k + 0.5 + (r % 2) * 0.5) / n - 0.5
                    if abs(t) > 0.5:
                        continue
                    sw = L / n * 0.95
                    zz = 0.3 + r * wall_h / rows
                    if side == 0:
                        loc, rz = (t * L, -d / 2, zz), 0
                    elif side == 1:
                        loc, rz = (w / 2, t * L, zz), math.pi / 2
                    elif side == 2:
                        loc, rz = (t * L, d / 2, zz), 0
                    else:
                        loc, rz = (-w / 2, t * L, zz), math.pi / 2
                    body.append(box(sw, 0.25, wall_h / rows * 0.93, loc, (0, 0, rz), m=rnd.choice(["stone_warm", "stone"]), bevel=0.04))
        body.append(box(w - 0.2, d - 0.2, wall_h, (0, 0, 0.3), m="stone_dark", bevel=0))
    roof_m = "roof_red" if level == 1 else "roof_blue"
    rz0 = 0.3 + wall_h
    body.append(prism_roof(w, d, 1.0 + 0.15 * level, (0, 0, rz0), m=roof_m, overhang=0.28))
    body.append(gable_wall(d * 0.98, 0.95 + 0.15 * level, (w / 2 - 0.05, 0, rz0), (0, 0, math.pi / 2), m="plank"))
    body.append(gable_wall(d * 0.98, 0.95 + 0.15 * level, (-w / 2 + 0.05, 0, rz0), (0, 0, math.pi / 2), m="plank"))
    # door on -y side
    body.append(box(0.7, 0.12, 0.95, (0, -d / 2 - 0.08, 0.3), m="wood_dark", bevel=0.03))
    body.append(box(0.8, 0.14, 0.12, (0, -d / 2 - 0.1, 1.25), m="iron", bevel=0.02))
    for sx in (-1, 1):
        body.append(box(0.38, 0.1, 0.32, (sx * w * 0.3, -d / 2 - 0.06, 0.75), m="glow_window", bevel=0.02))
    # shields on wall
    for sx in (-1, 1):
        body.append(cyl(0.22, 0.06, 12, (sx * w * 0.3, -d / 2 - 0.1, 0.4), (math.radians(90), 0, 0), m="cloth_blue", bevel=0.01))
    # banners
    body += banner((w / 2 + 0.35, -d / 2 - 0.3, 0), 2.3 + level * 0.3, "cloth_blue", 0.5, 0.8)
    if level >= 2:
        body += banner((-w / 2 - 0.35, -d / 2 - 0.3, 0), 2.3 + level * 0.3, "cloth_blue", 0.5, 0.8)
        body.append(box(0.6, 0.35, 0.4, (w / 2 + 0.2, d / 2 - 0.2, 0), m="plank", bevel=0.03))
        body.append(cyl(0.22, 0.55, 8, (-w / 2 - 0.1, d / 2 - 0.1, 0), m="wood", bevel=0.02))
    if level == 3:
        for sx in (-1, 1):
            body.append(cyl(0.42, 2.0, 10, (sx * (w / 2 + 0.1), d / 2, 0), m="stone", bevel=0.03))
            body.append(cone(0.6, 1.0, 8, (sx * (w / 2 + 0.1), d / 2, 2.0), m="roof_blue", bevel=0.02))
            body.append(sphere(0.08, (sx * (w / 2 + 0.1), d / 2, 3.05), m="gold", sub=1))
        body.append(box(w + 0.6, 0.08, 0.1, (0, -d / 2 - 0.12, 1.3), m="gold", bevel=0.01))
        body.append(sphere(0.25, (0, -d / 2 - 0.15, 1.55), m="gold", sub=1, scale=(1, 0.3, 1)))
    finalize(name, {"Body": body})

# ---------------------------------------------------------------- environment

def build_castle():
    if not scene("castle"):
        return
    body = []
    for sx in (-1, 1):
        x = sx * 3.2
        body += stone_ring(1.6, 4.5, rows=8, per_row=14, loc=(x, 0, 0), mats=["stone", "stone_warm"], seed=20 + sx)
        body.append(cyl(1.75, 0.25, 14, (x, 0, 4.5), m="stone_dark", bevel=0.04))
        body += crenels(1.75, 4.75, 10, w=0.5, h=0.5, d=0.35, loc=(x, 0, 0), m="stone")
        body.append(cyl(1.2, 1.2, 12, (x, 0, 4.75), m="stone_warm", bevel=0.03))
        body.append(cone(1.6, 2.4, 12, (x, 0, 5.95), m="roof_blue", bevel=0.03))
        body.append(sphere(0.12, (x, 0, 8.4), m="gold", sub=1))
        body += banner((x, 0, 8.3), 1.0, "cloth_blue", 0.6, 0.6)
        for k in range(3):
            body.append(box(0.15, 0.3, 0.5, (x + 1.55 * math.cos(-1.2 + k * 0.6), 1.55 * math.sin(-1.2 + k * 0.6) - 0.0, 2.5), (0, 0, -1.2 + k * 0.6), m="glow_window", bevel=0.02))
    # wall with gate
    for sx in (-1, 1):
        body.append(box(1.6, 1.2, 3.6, (sx * 1.35, 0, 0), m="stone", bevel=0.06))
    body.append(box(4.3, 1.2, 1.3, (0, 0, 2.7), m="stone_warm", bevel=0.06))
    body += [box(0.45, 1.25, 0.5, (x, 0, 4.0), m="stone", bevel=0.05) for x in (-1.9, -1.0, 0, 1.0, 1.9)]
    body.append(box(1.1, 0.2, 2.6, (0, -0.4, 0), m="black", bevel=0.0))
    for k in range(5):
        body.append(box(0.07, 0.1, 2.4, (-0.4 + k * 0.2, -0.62, 0.05), m="iron", bevel=0))
    for k in range(4):
        body.append(box(1.1, 0.1, 0.07, (0, -0.62, 0.4 + k * 0.55), m="iron", bevel=0))
    body.append(box(4.6, 0.2, 0.25, (0, -0.65, 2.65), m="gold", bevel=0.02))
    body.append(box(1.2, 0.12, 1.0, (0, -0.66, 2.95), m="cloth_blue", bevel=0.0))
    body.append(sphere(0.28, (0, -0.75, 3.35), m="gold", sub=1, scale=(1, 0.35, 1)))
    finalize("castle", {"Body": body})


def build_portal():
    if not scene("portal"):
        return
    body = []
    rnd = random.Random(7)
    for i in range(13):
        t = i / 12
        a = math.pi * t
        x, z = math.cos(a) * 2.2, math.sin(a) * 2.9
        r = 0.75 + rnd.uniform(-0.1, 0.25) + (0.25 if i in (0, 12) else 0)
        body.append(sphere(r, (x, rnd.uniform(-0.2, 0.2), z + 0.2), m=rnd.choice(["rock", "rock", "stone_dark"]), sub=1,
                           flat=True, noise=0.22, seed=i, scale=(1, 0.8, 1)))
    for i in range(6):
        body.append(crystal(0.18, 0.5, (rnd.uniform(-2.8, 2.8), rnd.uniform(-1.0, 0.8), 0.2), (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0), m="glow_portal"))
    for i in range(2):
        sx = (-1, 1)[i]
        body.append(cyl(0.08, 1.4, 6, (sx * 2.9, -1.0, 0), m="wood_dark", bevel=0))
        body.append(sphere(0.16, (sx * 2.9, -1.0, 1.5), m="glow_fire", sub=1))
        body.append(sphere(0.18, (sx * 2.9, -1.0, 1.75), m="iron_dark", sub=1, scale=(1, 1, 0.4)))
    # portal disc
    disc = [cyl(1.85, 0.08, 24, (0, 0.0, 1.95), (math.radians(90), 0, 0), m="glow_portal", bevel=0, name="disc")]
    disc[0].scale = (1, 1.35, 1)
    finalize("portal", {"Body": body, "Vortex": disc}, {"Vortex": (0, 0, 1.95)})


def build_trees():
    for v in range(3):
        nm = "tree_pine_%d" % v
        if scene(nm):
            rnd = random.Random(30 + v)
            g = [cyl(0.18, 1.0, 7, (0, 0, 0), m="wood_dark", bevel=0.02, r2=0.12)]
            h = 0.8
            layers = 3 + v % 2
            for i in range(layers):
                r = 1.25 - i * 0.28 + rnd.uniform(-0.05, 0.05)
                g.append(cone(r, 1.3, 9, (0, 0, h), (0, 0, rnd.uniform(0, 1)), m=["leaf_dark", "leaf"][i % 2 if v != 2 else 0], bevel=0.04))
                h += 0.75
            finalize(nm, {"Body": g})
    for v in range(3):
        nm = "tree_round_%d" % v
        if scene(nm):
            rnd = random.Random(40 + v)
            leaf = ["leaf", "leaf_light", "leaf_autumn"][v]
            g = [cyl(0.2, 1.6, 7, (0, 0, 0), m="wood", bevel=0.02, r2=0.14)]
            g.append(cyl(0.07, 0.8, 5, (0, 0, 1.1), (0.6, 0, 0.5), m="wood", bevel=0))
            for i in range(5):
                a = i * 2 * math.pi / 5 + rnd.uniform(-0.3, 0.3)
                rr = 0.45 if i else 0
                g.append(sphere(rnd.uniform(0.75, 0.95), (math.cos(a) * rr, math.sin(a) * rr, 2.0 + rnd.uniform(-0.1, 0.5)),
                                m=leaf, sub=2, flat=True, noise=0.12, seed=i + v * 10))
            g.append(sphere(0.8, (0, 0, 2.75), m=leaf, sub=2, flat=True, noise=0.12, seed=99 + v))
            finalize(nm, {"Body": g})


def build_props():
    for v in range(3):
        nm = "rock_%d" % v
        if scene(nm):
            rnd = random.Random(50 + v)
            g = []
            for i in range(1 + v):
                g.append(sphere(rnd.uniform(0.5, 0.9) * (1.0 if i == 0 else 0.6), (rnd.uniform(-0.6, 0.6) * i, rnd.uniform(-0.6, 0.6) * i, 0.2),
                                m="rock", sub=1, flat=True, noise=0.25, seed=v * 7 + i, scale=(1.2, 1, 0.75)))
            g.append(sphere(0.35, (0.1, 0.05, 0.62), m="rock_moss", sub=1, flat=True, noise=0.2, seed=v, scale=(1.6, 1.3, 0.35)))
            finalize(nm, {"Body": g})
    if scene("bush"):
        g = [sphere(0.5, (x, y, 0.3), m=m, sub=1, flat=True, noise=0.15, seed=i)
             for i, (x, y, m) in enumerate([(0, 0, "leaf"), (0.45, 0.1, "leaf_dark"), (-0.35, 0.2, "leaf_light"), (0.1, -0.35, "leaf")])]
        g += [sphere(0.07, (0.2, -0.4, 0.55), m="mushroom", sub=1), sphere(0.07, (-0.3, -0.1, 0.65), m="mushroom", sub=1)]
        finalize("bush", {"Body": g})
    if scene("fence"):
        g = []
        for i in range(4):
            g.append(box(0.14, 0.14, 0.85, (i * 0.9 - 1.35, 0, 0), (0, 0, 0.1 * (i % 2)), m="wood", bevel=0.02))
        for z in (0.35, 0.65):
            g.append(box(2.9, 0.08, 0.12, (0, 0.08, z), m="plank", bevel=0.02))
        finalize("fence", {"Body": g})
    if scene("crystals"):
        rnd = random.Random(61)
        g = [sphere(0.45, (0, 0, 0.05), m="rock", sub=1, flat=True, noise=0.2, seed=3, scale=(1.3, 1, 0.5))]
        for i in range(6):
            g.append(crystal(rnd.uniform(0.1, 0.2), rnd.uniform(0.4, 0.9), (rnd.uniform(-0.35, 0.35), rnd.uniform(-0.3, 0.3), 0.2),
                             (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 3)), m="glow_cyan"))
        finalize("crystals", {"Body": g})
    if scene("lamp"):
        g = [cyl(0.08, 2.2, 6, (0, 0, 0), m="wood_dark", bevel=0.01), cyl(0.25, 0.15, 8, (0, 0, 0), m="stone_dark", bevel=0.02),
             box(0.6, 0.06, 0.06, (0.25, 0, 2.1), m="iron", bevel=0), cyl(0.15, 0.32, 6, (0.5, 0, 1.75), m="iron_dark", bevel=0.01),
             sphere(0.1, (0.5, 0, 1.9), m="glow_fire", sub=1), cone(0.22, 0.18, 6, (0.5, 0, 2.07), m="iron_dark", bevel=0)]
        finalize("lamp", {"Body": g})
    if scene("house"):
        g = [box(2.6, 2.0, 0.25, (0, 0, 0), m="stone_dark", bevel=0.05), box(2.3, 1.8, 1.3, (0, 0, 0.25), m="cloth_white", bevel=0.03)]
        for sx in (-1, 1):
            for sy in (-1, 1):
                g.append(box(0.16, 0.16, 1.35, (sx * 1.1, sy * 0.85, 0.25), m="wood_dark", bevel=0.02))
        g.append(box(2.3, 0.14, 0.14, (0, -0.95, 1.0), m="wood_dark", bevel=0.01))
        g.append(prism_roof(2.3, 1.8, 1.2, (0, 0, 1.55), m="straw", overhang=0.3, thick=0.2))
        g.append(gable_wall(1.75, 1.15, (1.1, 0, 1.55), (0, 0, math.pi / 2), m="cloth_white"))
        g.append(gable_wall(1.75, 1.15, (-1.1, 0, 1.55), (0, 0, math.pi / 2), m="cloth_white"))
        g.append(box(0.55, 0.1, 0.85, (0.4, -0.95, 0.25), m="wood", bevel=0.02))
        g.append(box(0.4, 0.1, 0.35, (-0.5, -0.95, 0.8), m="glow_window", bevel=0.02))
        g.append(box(0.3, 0.3, 0.8, (-0.6, 0.4, 2.0), m="stone_dark", bevel=0.03))
        finalize("house", {"Body": g})
    if scene("barrels"):
        g = [cyl(0.32, 0.75, 10, (0, 0, 0), m="wood", bevel=0.03, r2=0.32), torus(0.33, 0.03, (0, 0, 0.18), m="iron", maj=12, mino=4),
             torus(0.33, 0.03, (0, 0, 0.57), m="iron", maj=12, mino=4), box(0.6, 0.6, 0.6, (0.7, 0.1, 0), (0, 0, 0.3), m="plank", bevel=0.04),
             cyl(0.32, 0.75, 10, (0.15, 0.7, 0), m="wood", bevel=0.03)]
        finalize("barrels", {"Body": g})
    if scene("flowers"):
        rnd = random.Random(77)
        g = []
        for i in range(9):
            x, y = rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6)
            g.append(cyl(0.015, 0.3, 4, (x, y, 0), m="leaf_dark", bevel=0))
            g.append(sphere(0.07, (x, y, 0.32), m=rnd.choice(["cloth_white", "mushroom", "gold", "cloth_purple"]), sub=1, flat=True))
        finalize("flowers", {"Body": g}, ao=False)
    if scene("bridge"):
        g = []
        for i in range(9):
            g.append(box(1.0, 3.2, 0.12, (-2.0 + i * 0.5, 0, 0.25 + 0.15 * math.sin(i / 8 * math.pi)), m=["plank", "wood"][i % 2], bevel=0.02))
        for sx in (-1, 1):
            for i in range(5):
                g.append(cyl(0.07, 0.9, 6, (-2.0 + i, sx * 1.55, 0.2 + 0.15 * math.sin(i / 4 * math.pi)), m="wood_dark", bevel=0))
            g.append(box(4.2, 0.08, 0.1, (0, sx * 1.55, 1.0), m="wood", bevel=0.01))
        finalize("bridge", {"Body": g})


def build_weapons():
    """Projectiles only. The held weapons (w_sword, w_axe, w_club, w_dagger), the artillery mortar,
    the meteor boulder and the crystals are VARCO meshes now (rebuild_assets.sh, "held props")."""
    # projectiles
    if scene("p_arrow"):
        g = [cyl(0.02, 0.9, 5, (0, 0, -0.45), m="wood", bevel=0), cone(0.05, 0.14, 4, (0, 0, 0.45), m="iron"),
             box(0.12, 0.01, 0.16, (0, 0, -0.45), m="cloth_white", bevel=0), box(0.01, 0.12, 0.16, (0, 0, -0.45), m="cloth_white", bevel=0)]
        finalize("p_arrow", {"Arrow": g}, ao=False)
    if scene("p_bomb"):
        g = [sphere(0.22, (0, 0, 0), m="iron_dark", sub=2), cyl(0.06, 0.08, 6, (0, 0, 0.2), m="iron", bevel=0),
             sphere(0.05, (0, 0, 0.32), m="glow_fire", sub=1)]
        finalize("p_bomb", {"Bomb": g}, ao=False)


if __name__ == "__main__":
    build_weapons()
    build_plot()
    for lv in (1, 2, 3):
        build_archer(lv); build_mage(lv); build_artillery(lv); build_barracks(lv)
    build_castle(); build_portal(); build_trees(); build_props()
    print("ALL DONE")
