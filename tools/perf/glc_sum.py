#!/usr/bin/env python3
"""Summarise a shader_compiles.sh log: GL programs linked per first-time event.

The test runner (newlog=1) prints "NEWTHING t=<s> <what>" when something shows for the first time
(an enemy kind, a tower level, a wave); the GL shim prints "GLC link <ms>" per program. Programs
are counted against the last NEWTHING line before them. "In battle" is everything after the
warm-up (after-warmup), or after loading when the run had no warm-up.

usage: glc_sum.py <log> [<GLSHIM_DUMP dir>]
With the shader sources (GLSHIM_DUMP), it also counts the programs compiled with the default
specialization: the native editor compiles them when a shader is first bound, the game's web
engine does not (tools/engine/patches/gles3-lazy-shader-variants.patch), so the web pays only for
the rest.
"""
import re
import sys

log = sys.argv[1]
cur = "load"
agg = {"load": [0, 0.0]}
order = ["load"]
for line in open(log, errors="ignore"):
    m = re.match(r"NEWTHING t=([\d.]+) (.*)", line)
    if m:
        cur = "t=%s %s" % (m.group(1), m.group(2).strip())
        if cur not in agg:
            order.append(cur)
            agg[cur] = [0, 0.0]
        continue
    m = re.match(r"GLC (link|compile) ([\d.]+)", line)
    if m:
        if m.group(1) == "link":
            agg[cur][0] += 1
        agg[cur][1] += float(m.group(2))
warm = any("after-warmup" in k for k in order)
in_battle = False
n = 0
ms = 0.0
for k in order:
    if (warm and "after-warmup" in k) or (not warm and k != "load" and "warmup" not in k):
        in_battle = True
    if agg[k][0]:
        print("%-40s programs %3d  %7.0f ms" % (k, agg[k][0], agg[k][1]))
    if in_battle:
        n += agg[k][0]
        ms += agg[k][1]
print("in battle: %d programs, %.0f ms (%s)" % (n, ms, "after the warm-up" if warm else "no warm-up"))
for line in open(log, errors="ignore"):
    if "RB_WARMUP" in line or line.startswith("RESULT"):
        print(line.strip())
if len(sys.argv) > 2:
    import os
    d = sys.argv[2]
    srcs, progs = [], []
    for line in open(log, errors="ignore"):
        m = re.match(r"GLC src (\w+)", line)
        if m:
            srcs.append(m.group(1))
        elif line.startswith("GLC link") and srcs:
            progs.append(srcs[-1])
    default = 0
    for h in progs:
        f = os.path.join(d, h + ".glsl")
        if not os.path.exists(f):
            continue
        defs = set(re.findall(r"^#define (\w+)", open(f, errors="ignore").read(), re.M))
        if {"BASE_PASS", "USE_RADIANCE_MAP", "APPLY_TONEMAPPING", "DISABLE_REFLECTION_PROBE"} <= defs and not defs & {"DISABLE_LIGHTMAP", "DISABLE_FOG", "RENDER_SHADOWS", "DISABLE_LIGHT_OMNI"}:
            default += 1
    print("default-specialization programs (not compiled by the web engine): %d of %d" % (default, len(progs)))
