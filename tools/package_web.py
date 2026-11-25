"""Compress + split the large Web export files so they can be served by any static host with per-file
size limits. The custom HTML shell inflates them in the browser with DecompressionStream.
Usage: package_web.py <export_dir> <out_dir> [--b64] [--build-id ID] [--no-mobile] [--no-br]

Packs: index.pck (desktop textures) and, when present, index_mobile.pck (ETC2 textures, picked by
the shell on phones/tablets); each comes with its download chunks <pack>_<chunk>.pck
(tools/split_pck.py, scripts/data/pack_chunks.gd) that the shell fetches one after another once
the core pack is in. Every file is gzip'd; files that Brotli shrinks by 5 % or more (the engine:
6.9 MB instead of 10.2 MB) also get Brotli parts, used by browsers that inflate Brotli natively
(Safari 18.4+, Firefox 147+). Brotli needs the `brotli` Python module or Node.js; results are cached
by content hash in ~/.cache/rb_brotli. Part URLs carry ?v=<build id> so browser / service-worker
caches can keep them forever and a new deploy is always fetched fresh. PWA files (manifest,
service worker, icons) and the loading-screen art are copied from web/."""
import base64
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from split_pck import load_manifest  # noqa: E402


def brotli_compress(data):
    """Brotli quality 11 / 16 MB window, or None when no encoder is available."""
    cache = os.path.expanduser("~/.cache/rb_brotli")
    key = os.path.join(cache, hashlib.sha256(data).hexdigest() + ".br")
    if os.path.exists(key):
        return open(key, "rb").read()
    out = None
    try:
        import brotli
        out = brotli.compress(data, quality=11, lgwin=24)
    except ImportError:
        if shutil.which("node"):
            with tempfile.TemporaryDirectory() as td:
                i, o = os.path.join(td, "in"), os.path.join(td, "out")
                open(i, "wb").write(data)
                js = ("const z=require('zlib'),fs=require('fs');const d=fs.readFileSync(process.argv[1]);"
                      "fs.writeFileSync(process.argv[2],z.brotliCompressSync(d,{params:{"
                      "[z.constants.BROTLI_PARAM_QUALITY]:11,[z.constants.BROTLI_PARAM_LGWIN]:24,"
                      "[z.constants.BROTLI_PARAM_SIZE_HINT]:d.length}}));")
                subprocess.run(["node", "-e", js, i, o], check=True)
                out = open(o, "rb").read()
    if out is not None:
        os.makedirs(cache, exist_ok=True)
        open(key, "wb").write(out)
    return out


def write_parts(name, comp, ext):
    parts = []
    for i in range(0, len(comp), CHUNK):
        if B64:
            pn = "%s.%s%d.b64.txt" % (name, ext, i // CHUNK)
            open(os.path.join(dst, pn), "wb").write(base64.b64encode(comp[i:i + CHUNK]))
        else:
            pn = "%s.%s%d.bin" % (name, ext, i // CHUNK)
            open(os.path.join(dst, pn), "wb").write(comp[i:i + CHUNK])
        parts.append(pn)
    return parts


src, dst = sys.argv[1], sys.argv[2]
B64 = "--b64" in sys.argv  # hosts that only accept text/web types: ship base64 text parts
build_id = time.strftime("%Y%m%d%H%M%S")
if "--build-id" in sys.argv:
    build_id = sys.argv[sys.argv.index("--build-id") + 1]
NO_MOBILE = "--no-mobile" in sys.argv  # e.g. the claude.ai artifact copy: one pack for every device
NO_BR = "--no-br" in sys.argv  # quick local packaging
if B64:
    build_id = ""  # text-part hosts serve plain file names (no ?v= cache keys)
CHUNK = (13 if B64 else 15) * 1024 * 1024
os.makedirs(dst, exist_ok=True)
gzmap = {}
for name in sorted(os.listdir(src)):
    p = os.path.join(src, name)
    if NO_MOBILE and name.startswith("index_mobile"):
        continue
    if name.endswith((".wasm", ".pck")):
        data = open(p, "rb").read()
        comp = gzip.compress(data, 9, mtime=0)
        parts = write_parts(name, comp, "gz")
        gzmap[name] = {"parts": parts, "size": len(data), "gz": len(comp),
                       "mime": "application/wasm" if name.endswith(".wasm") else "application/octet-stream"}
        note = ""
        if not NO_BR and len(comp) < 0.8 * len(data):  # only compressible files are worth trying
            br = brotli_compress(data)
            if br is not None and len(br) <= 0.95 * len(comp):
                gzmap[name]["br"] = {"parts": write_parts(name, br, "br"), "gz": len(br)}
                note = f", {len(br)/1e6:.1f} MB br"
            elif br is None:
                note = " (no Brotli encoder)"
        print(f"{name}: {len(data)/1e6:.1f} MB -> {len(comp)/1e6:.1f} MB gz in {len(parts)} part(s){note}")
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
man = load_manifest(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "data", "pack_chunks.gd"))
chunks = [c for c in man["order"] if c != "core"]
html = (html.replace("$RB_GZ_MAP", json.dumps(gzmap)).replace("$RB_BUILD_ID", build_id)
        .replace("$RB_CHUNKS", json.dumps(chunks)))
open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(html)
print("wrote", dst, "build", build_id)
