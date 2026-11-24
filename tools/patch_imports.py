"""Role-aware texture import settings for extracted 3D textures.

Desktop / default build (no VRAM compression, so the web build stays small and works on every
WebGL2 GPU):
  *_albedo.*  lossy WebP, high quality  - colour data tolerates chroma subsampling
  *_normal.*  lossless                  - XYZ in RGB: lossy YUV 4:2:0 would corrupt directions
  *_orm.*     lossless                  - occlusion/roughness/metal in separate channels
  other 3D    lossy WebP (legacy)
All 3D textures get mipmaps.
UI kit (assets/ui/kit, authored at 2x) and the painted world map: lossy WebP + mipmaps so they
minify cleanly when the canvas is drawn below their native size. Other UI images stay lossless.

--mobile  (used on a throw-away copy of the project for index_mobile.pck):
  every 3D texture becomes GPU-compressed (ETC2 / EAC RG11 for normal maps) and is capped by role
  and by how large the model gets on a phone screen, so the textures stay compressed in GPU memory
  (4-8x less than decoded WebP) and the download shrinks too. UI and particle textures unchanged.
"""
import glob
import os
import re
import sys

MOBILE = "--mobile" in sys.argv
# models that fill a lot of the screen keep more texels on phones
BIG = re.compile(r"^(archer|barracks|mage|artillery)_\d|^(castle|portal|plot)_|^(hero|sera|troll|lich|ogre)_")


def mobile_limit(base: str, role: str) -> int:
    big = bool(BIG.match(base))
    if role == "albedo":
        return 1024 if big else 512
    if role == "normal":
        return 512 if big else 256
    if role == "orm":
        return 256
    return 512


changed = 0
for f in glob.glob("assets/**/*.import", recursive=True):
    src = f[:-7]
    if not src.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
        continue
    is_ui = "/ui/" in f or "/fonts/" in f
    base = os.path.basename(src).lower()
    s = open(f).read()
    o = s
    role = "normal" if "_normal" in base else "orm" if "_orm" in base else "albedo" if "_albedo" in base else "other"
    if not is_ui and MOBILE and "/fx/" not in f:
        s = re.sub(r"compress/mode=\d", "compress/mode=2", s)
        s = re.sub(r"compress/high_quality=\w+", "compress/high_quality=false", s)
        s = re.sub(r"process/size_limit=\d+", "process/size_limit=%d" % mobile_limit(base, role), s)
        s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
        s = re.sub(r"compress/normal_map=\d", "compress/normal_map=%d" % (1 if role == "normal" else 0), s)
    elif not is_ui:
        if role in ("normal", "orm"):
            mode, q = 0, None
        elif role == "albedo":
            mode, q = 1, 0.92
        else:
            mode, q = 1, 0.82
        s = re.sub(r"compress/mode=\d", "compress/mode=%d" % mode, s)
        if q is not None:
            s = re.sub(r"compress/lossy_quality=[0-9.]+", "compress/lossy_quality=%.2f" % q, s)
        s = re.sub(r"process/size_limit=\d+", "process/size_limit=0", s)
        s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
        if role == "normal":
            s = re.sub(r"compress/normal_map=\d", "compress/normal_map=1", s)
    elif "/ui/kit/" in f or base.startswith("world_map"):
        q = 0.85 if base.startswith("world_map") else 0.92
        s = re.sub(r"compress/mode=\d", "compress/mode=1", s)
        s = re.sub(r"compress/lossy_quality=[0-9.]+", "compress/lossy_quality=%.2f" % q, s)
        s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
    s = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", s)
    if s != o:
        open(f, "w").write(s)
        changed += 1
print("patched", changed, "import files", "(mobile: ETC2/ASTC + size caps)" if MOBILE else "")
