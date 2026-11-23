"""Gzip + split the large Web export files so they can be served by any static host with per-file size limits.
The custom HTML shell inflates them in the browser with DecompressionStream.
Usage: package_web.py <export_dir> <out_dir> [--raw]"""
import gzip, json, os, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
raw = "--raw" in sys.argv
B64 = "--b64" in sys.argv  # hosts that only accept text/web types: ship base64 text parts
CHUNK = (13 if B64 else 15) * 1024 * 1024
os.makedirs(dst, exist_ok=True)
gzmap = {}
for name in os.listdir(src):
    p = os.path.join(src, name)
    if name.endswith((".wasm", ".pck")) and not raw:
        data = open(p, "rb").read()
        comp = gzip.compress(data, 9)
        parts = []
        for i in range(0, len(comp), CHUNK):
            if B64:
                import base64
                pn = "%s.gz%d.b64.txt" % (name, i // CHUNK)
                open(os.path.join(dst, pn), "wb").write(base64.b64encode(comp[i:i + CHUNK]))
            else:
                pn = "%s.gz%d.bin" % (name, i // CHUNK)
                open(os.path.join(dst, pn), "wb").write(comp[i:i + CHUNK])
            parts.append(pn)
        gzmap[name] = {"parts": parts, "mime": "application/wasm" if name.endswith(".wasm") else "application/octet-stream"}
        print(f"{name}: {len(data)/1e6:.1f} MB -> {len(comp)/1e6:.1f} MB gz in {len(parts)} part(s)")
    elif name.endswith(".html"):
        continue
    else:
        shutil.copy(p, os.path.join(dst, name))
# static extras shipped next to the page (loading-screen art)
web_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "web")
for extra in ("loading_bg.jpg",):
    if os.path.exists(os.path.join(web_dir, extra)):
        shutil.copy(os.path.join(web_dir, extra), os.path.join(dst, extra))
html = open(os.path.join(src, "index.html"), encoding="utf-8").read()
html = html.replace("$RB_GZ_MAP", json.dumps(gzmap))
open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(html)
print("wrote", dst)
