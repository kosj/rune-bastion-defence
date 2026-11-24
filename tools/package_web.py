"""Gzip + split the large Web export files so they can be served by any static host with per-file size limits.
The custom HTML shell inflates them in the browser with DecompressionStream.
Usage: package_web.py <export_dir> <out_dir> [--b64] [--build-id ID] [--no-mobile]

Packs: index.pck (desktop textures) and, when present, index_mobile.pck (ETC2 textures, picked by
the shell on phones/tablets). Part URLs carry ?v=<build id> so browser / service-worker caches can
keep them forever and a new deploy is always fetched fresh. PWA files (manifest, service worker,
icons) and the loading-screen art are copied from web/."""
import base64
import gzip
import json
import os
import shutil
import sys
import time

src, dst = sys.argv[1], sys.argv[2]
B64 = "--b64" in sys.argv  # hosts that only accept text/web types: ship base64 text parts
build_id = time.strftime("%Y%m%d%H%M%S")
if "--build-id" in sys.argv:
    build_id = sys.argv[sys.argv.index("--build-id") + 1]
NO_MOBILE = "--no-mobile" in sys.argv  # e.g. the claude.ai artifact copy: one pack for every device
if B64:
    build_id = ""  # text-part hosts serve plain file names (no ?v= cache keys)
CHUNK = (13 if B64 else 15) * 1024 * 1024
os.makedirs(dst, exist_ok=True)
gzmap = {}
for name in sorted(os.listdir(src)):
    p = os.path.join(src, name)
    if NO_MOBILE and name == "index_mobile.pck":
        continue
    if name.endswith((".wasm", ".pck")):
        data = open(p, "rb").read()
        comp = gzip.compress(data, 9)
        parts = []
        for i in range(0, len(comp), CHUNK):
            if B64:
                pn = "%s.gz%d.b64.txt" % (name, i // CHUNK)
                open(os.path.join(dst, pn), "wb").write(base64.b64encode(comp[i:i + CHUNK]))
            else:
                pn = "%s.gz%d.bin" % (name, i // CHUNK)
                open(os.path.join(dst, pn), "wb").write(comp[i:i + CHUNK])
            parts.append(pn)
        gzmap[name] = {"parts": parts, "size": len(data),
                       "mime": "application/wasm" if name.endswith(".wasm") else "application/octet-stream"}
        print(f"{name}: {len(data)/1e6:.1f} MB -> {len(comp)/1e6:.1f} MB gz in {len(parts)} part(s)")
    elif name.endswith(".html"):
        continue
    else:
        shutil.copy(p, os.path.join(dst, name))
# static extras shipped next to the page (loading-screen art, PWA manifest / service worker / icons)
web_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "web")
for extra in ("loading_bg.jpg", "manifest.webmanifest", "sw.js", "icon_192.png", "icon_512.png", "icon_maskable_512.png"):
    if os.path.exists(os.path.join(web_dir, extra)):
        shutil.copy(os.path.join(web_dir, extra), os.path.join(dst, extra))
html = open(os.path.join(src, "index.html"), encoding="utf-8").read()
html = html.replace("$RB_GZ_MAP", json.dumps(gzmap)).replace("$RB_BUILD_ID", build_id)
open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(html)
print("wrote", dst, "build", build_id)
