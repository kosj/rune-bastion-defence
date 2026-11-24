"""Merge VARCO per-animation GLBs into one GLB with multiple named animations, downscale textures.
blender -b -P merge_character.py -- OUT.glb TEX_SIZE name1=file1 name2=file2 ...
(first entry is the base mesh/armature). With a single static file it just downsizes textures."""
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
tex_size = int(argv[1])
pairs = [a.split("=", 1) for a in argv[2:]]

bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


base_name, base_file = pairs[0]
base_objs = import_glb(base_file)
# some rig exports carry an untextured helper sphere next to the body: drop it
for o in list(base_objs):
    if o.type == "MESH" and not any(sl.material for sl in o.material_slots) and len(o.data.polygons) < 200:
        print("DROP helper mesh", o.name)
        base_objs.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
arm = next((o for o in base_objs if o.type == "ARMATURE"), None)
meshes = [o for o in base_objs if o.type == "MESH"]
for m in meshes:
    m.name = "Body"

actions = []
if arm is not None and arm.animation_data and arm.animation_data.action:
    act = arm.animation_data.action
    act.name = base_name
    act.use_fake_user = True
    actions.append(act)

for name, path in pairs[1:]:
    objs = import_glb(path)
    a2 = next((o for o in objs if o.type == "ARMATURE"), None)
    if a2 and a2.animation_data and a2.animation_data.action:
        act = a2.animation_data.action
        act.name = name
        act.use_fake_user = True
        actions.append(act)
        a2.animation_data.action = None
    for o in objs:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Armature):
                bpy.data.armatures.remove(data)

# purge orphan materials/images from the extra imports
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)
for mat in list(bpy.data.materials):
    if mat.users == 0:
        bpy.data.materials.remove(mat)

TRIM = {"attack": (0.62, 0.42)}  # seconds before/after the fastest hand movement


def hand_peak(act):
    """Frame where the hands move fastest (= impact moment)."""
    arm.animation_data.action = act
    if hasattr(act, "slots") and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    scn = bpy.context.scene
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    prev = None
    best, best_f = -1.0, f0
    speeds = []
    for f in range(f0 + 6, f1 - 2):
        scn.frame_set(f)
        pts = []
        for bn in ("RightHand", "LeftHand"):
            if bn in arm.pose.bones:
                pts.append(arm.matrix_world @ arm.pose.bones[bn].head)
        if prev is not None and pts:
            sp = max((a - b).length for a, b in zip(pts, prev))
            speeds.append((round(f / bpy.context.scene.render.fps, 2), round(sp, 4)))
            if sp > best:
                best, best_f = sp, f
        prev = pts
    top = sorted(speeds, key=lambda x: -x[1])[:6]
    print("SPEEDS", act.name, top)
    return best_f


if arm is not None:
    if arm.animation_data is None:
        arm.animation_data_create()
    fps = bpy.context.scene.render.fps
    ranges = {}
    for act in actions:
        r = (act.frame_range[0], act.frame_range[1])
        if act.name in TRIM:
            pk = hand_peak(act)
            b, a = TRIM[act.name]
            r = (max(act.frame_range[0], pk - b * fps), min(act.frame_range[1], pk + a * fps))
            print("TRIM", act.name, "peak", pk / fps, "range", r[0] / fps, r[1] / fps)
        ranges[act.name] = r
    arm.animation_data.action = None
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)
    for act in actions:
        r = ranges[act.name]
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        st = tr.strips.new(act.name, int(r[0]), act)
        if hasattr(act, "slots") and len(act.slots) and hasattr(st, "action_slot"):
            st.action_slot = act.slots[0]
        st.action_frame_start = r[0]
        st.action_frame_end = r[1]
        st.frame_end = r[0] + (r[1] - r[0])
        st.name = act.name
        tr.mute = False

# downscale textures by role and keep them lossless (role-aware compression happens on engine import)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import tex_roles  # noqa: E402
NORMAL_PX = int(os.environ.get("NORMAL_PX", max(tex_size // 2, 256)))
ORM_PX = int(os.environ.get("ORM_PX", 256))
if arm is not None:
    arm.data.pose_position = "REST"
body = [o for o in bpy.data.objects if o.type == "MESH"]
from mathutils import Vector  # noqa: E402
_zs = [(o.matrix_world @ Vector(c)).z for o in body for c in o.bound_box]
hgt = (max(_zs) - min(_zs)) if _zs else 1.0
ao_img = tex_roles.bake_ao(body, 512, hgt * 0.15) if body else None
if arm is not None:
    arm.data.pose_position = "POSE"
tex_roles.finalize_images({"albedo": tex_size, "normal": NORMAL_PX, "orm": ORM_PX}, ao=ao_img)

print("ACTIONS:", [a.name for a in actions], "IMAGES:", [(i.name, tuple(i.size)) for i in bpy.data.images])
kw = dict(filepath=out, export_format="GLB", export_yup=True, export_apply=False,
          export_image_format="AUTO", export_tangents=True)
if arm is not None and actions:
    kw.update(export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
              export_optimize_animation_size=True)
else:
    kw.update(export_animations=False)
bpy.ops.export_scene.gltf(**kw)
print("WROTE", out, os.path.getsize(out))
