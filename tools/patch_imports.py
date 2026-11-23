"""Role-aware texture import settings for extracted 3D textures (no VRAM auto-compression, so the
web build stays small and works on every WebGL2 / mobile GPU):

  *_albedo.*  lossy WebP, high quality  - colour data tolerates chroma subsampling
  *_normal.*  lossless                  - XYZ in RGB: lossy YUV 4:2:0 would corrupt directions
  *_orm.*     lossless                  - occlusion/roughness/metal in separate channels
  other 3D    lossy WebP (legacy)
All 3D textures get mipmaps; UI images are left alone apart from detect_3d.
"""
import glob
import os
import re

changed = 0
for f in glob.glob("assets/**/*.import", recursive=True):
    src = f[:-7]
    if not src.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
        continue
    is_ui = "/ui/" in f or "/fonts/" in f
    base = os.path.basename(src).lower()
    s = open(f).read()
    o = s
    if not is_ui:
        if "_normal" in base or "_orm" in base:
            mode, q = 0, None
        elif "_albedo" in base:
            mode, q = 1, 0.92
        else:
            mode, q = 1, 0.82
        s = re.sub(r"compress/mode=\d", "compress/mode=%d" % mode, s)
        if q is not None:
            s = re.sub(r"compress/lossy_quality=[0-9.]+", "compress/lossy_quality=%.2f" % q, s)
        s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
        if "_normal" in base:
            s = re.sub(r"compress/normal_map=\d", "compress/normal_map=1", s)
    s = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", s)
    if s != o:
        open(f, "w").write(s)
        changed += 1
print("patched", changed, "import files")
