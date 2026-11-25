"""Fail if the game uses a class that the size-optimized web template leaves out.
Usage: check_classes.py <godot source dir> [project dir] [advanced|fallback]

Reads tools/engine/web_template.env, collects the classes registered by every switched-off module
(module_<name>_enabled=no) and by every switched-off feature (disable_physics_3d=yes ->
the #ifndef PHYSICS_3D_DISABLED blocks of the engine's register files), and looks for them in
the exported scripts, scenes and resources and in the imported scenes. A script that names such a
class would fail to compile in the web build; a scene that contains one would fail to load."""
import os
import re
import sys

src = sys.argv[1]
proj = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
env_txt = open(os.path.join(proj, "tools", "engine", "web_template.env"), encoding="utf-8").read()
flags = " ".join(re.findall(r'SCONS_FLAGS="([^"]*)"', env_txt, re.S)[0].split())
text_server = sys.argv[3] if len(sys.argv) > 3 else ("fallback" if re.search(r"^TEXT_SERVER=fallback", env_txt, re.M) else "advanced")
if text_server == "fallback":
    flags += " module_text_server_adv_enabled=no"

REG = re.compile(r"(?:GDREGISTER_[A-Z_]*CLASS|register_(?:abstract_|virtual_|internal_|runtime_)?class)\s*(?:<\s*([A-Za-z0-9_]+)\s*>|\(\s*([A-Za-z0-9_]+)\s*\))")


def reg_names(text):
    return {a or b for a, b in REG.findall(text)}


classes = {}  # class -> why
for m in re.findall(r"module_(\w+)_enabled=no", flags):
    d = os.path.join(src, "modules", m)
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith(".cpp"):
                for c in reg_names(open(os.path.join(root, f), encoding="utf-8", errors="replace").read()):
                    classes.setdefault(c, "module " + m)
macros = {
    "disable_physics_2d": "PHYSICS_2D_DISABLED", "disable_physics_3d": "PHYSICS_3D_DISABLED",
    "disable_navigation_2d": "NAVIGATION_2D_DISABLED", "disable_navigation_3d": "NAVIGATION_3D_DISABLED",
    "disable_xr": "XR_DISABLED",
}
for opt, macro in macros.items():
    if opt + "=yes" not in flags:
        continue
    for f in ("scene/register_scene_types.cpp", "servers/register_server_types.cpp"):
        lines = open(os.path.join(src, f), encoding="utf-8").read().splitlines()
        depth = 0
        inside = []
        for line in lines:
            s = line.strip()
            if s.startswith("#if"):
                inside.append(s == "#ifndef " + macro)
            elif s.startswith("#endif") and inside:
                inside.pop()
            elif s.startswith("#else") and inside:
                inside[-1] = False
            elif any(inside):
                for c in reg_names(s):
                    classes.setdefault(c, opt)
# classes every build keeps even when their feature is off (the engine registers them outside
# the guarded blocks too); none expected, but a name that is also registered elsewhere is not
# really gone
core_text = ""
for f in ("scene/register_scene_types.cpp", "servers/register_server_types.cpp", "core/register_core_types.cpp"):
    core_text += open(os.path.join(src, f), encoding="utf-8").read()

# the game's own files only (CI checks the Godot source out inside the workspace), minus what the
# export leaves out (export_presets.cfg exclude_filter)
keep = re.compile(r"^(scripts/|scenes/|assets/|\.godot/imported/|[^/]+\.(tscn|tres)$)")
skip = re.compile(r"^(scripts/tools/|scenes/test_runner|scenes/icon_render|scenes/pose_test)")
hits = []
pat = re.compile(r"\b(" + "|".join(sorted(map(re.escape, classes), key=len, reverse=True)) + r")\b")
for root, dirs, files in os.walk(proj):
    rel_root = os.path.relpath(root, proj)
    dirs[:] = [d for d in dirs if not (d.startswith(".") and d != ".godot") and d not in ("build",)]
    for f in files:
        rel = os.path.normpath(os.path.join(rel_root, f)).replace(os.sep, "/")
        if not keep.match(rel) or skip.match(rel):
            continue
        if f.endswith((".gd", ".tscn", ".tres")) and not rel.startswith(".godot/"):
            text = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
            text = re.sub(r"#[^\n]*", "", text) if f.endswith(".gd") else text  # comments don't count
        elif rel.startswith(".godot/imported/") and f.endswith((".scn", ".res")):
            text = open(os.path.join(root, f), "rb").read().decode("latin-1")
        else:
            continue
        for m in set(pat.findall(text)):
            hits.append("%s: %s (%s)" % (rel, m, classes[m]))
print("check_classes: %d classes switched off in tools/engine/web_template.env" % len(classes))
if hits:
    sys.exit("check_classes: the game uses classes the web template leaves out:\n  " + "\n  ".join(sorted(hits)))
print("check_classes: none of them is used")
