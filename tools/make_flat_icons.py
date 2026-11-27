"""Flat heraldic icons drawn in code (the UI look: solid tinctures, an ink outline, no gloss):
the star (a mullet in or, its right-hand facets a shade darker) and the empty star slot.
Run from the repository root: python3 tools/make_flat_icons.py"""
import math
from PIL import Image, ImageDraw

S = 4  # supersampling
N = 128
OR = (247, 185, 42)
OR_DARK = (226, 158, 24)
SABLE = (19, 20, 28)
SLOT = (52, 58, 80)
SLOT_DARK = (40, 45, 64)

def star_points(cx, cy, r_out, r_in, rot=-math.pi / 2):
    pts = []
    for k in range(10):
        r = r_out if k % 2 == 0 else r_in
        a = rot + k * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def draw(out, fill, dark, outline):
    n = N * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = n / 2, n / 2 + n * 0.035
    r_out, r_in = n * 0.47, n * 0.47 * 0.47
    # the ink outline: the star drawn fat, then the face inside it
    w = n * 0.055
    outer = star_points(cx, cy, r_out, r_in)
    d.polygon(outer, fill=outline)
    # round the outline's joints a little
    for p in outer:
        d.ellipse([p[0] - w * 0.2, p[1] - w * 0.2, p[0] + w * 0.2, p[1] + w * 0.2], fill=outline)
    inner = star_points(cx, cy, r_out - w * 1.9, r_in - w * 0.75)
    d.polygon(inner, fill=fill)
    # facets: the triangles from the centre to each point, darker on the right-hand side
    for k in range(10):
        a, b = inner[k], inner[(k + 1) % 10]
        mx = (a[0] + b[0]) / 2
        if mx > cx + 1:
            tri = [(cx, cy), a, b]
            # each point is two triangles; shade the half that faces right-down
            if k % 2 == 0:
                d.polygon(tri, fill=dark)
    im = im.resize((N, N), Image.LANCZOS)
    im.save(out)
    print("wrote", out)

draw("assets/ui/star.png", OR, OR_DARK, SABLE)
draw("assets/ui/star_empty.png", SLOT, SLOT_DARK, SABLE)
